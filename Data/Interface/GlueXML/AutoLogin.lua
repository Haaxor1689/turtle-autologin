--------
-- setup
--------

local _G = _G or getfenv(0)

LoginManager = {}
LoginManager.State = {}
LoginManager.SelectedAcct = nil
LoginManager.CurrentPage = 0
LoginManager.PageSize = 6
LoginManager.LimitReached = false
LoginManager.from_login_screen = false

LoginManager.has_superwow = false

if SUPERWOW_VERSION and tonumber(SUPERWOW_VERSION) >= 1.4 then
  has_superwow = true
end

if not has_superwow then
  GlueDialogTypes["AL_NO_SWOW"] = {
    text = "|cff77ff00Turtle AutoLogin|r requires SuperWoW 1.4 or newer to operate.",
    button1 = TEXT(OKAY),
    showAlert = 1,
  }

  GlueDialog_Show("AL_NO_SWOW")
  -- AutologinAccountsFrame:Hide()
  return
end
--------

-------
-- util
-------

-- Move the element at 'index' upward by one position.
local function moveIndexUp(list, index)
  if index > 1 then
    local item = table.remove(list, index)
    table.insert(list, index - 1, item)
  end
end

-- Move the element at 'index' downward by one position.
local function moveIndexDown(list, index)
  if list[index] and list[index+1] then
    local item = table.remove(list, index)
    table.insert(list, index + 1, item)
  end
end
-------

---------
-- serial
---------
local Serialize = {
  serializeValue = function (self,val,indent)
    local t = type(val)
    if t == "string" then
      return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
      return tostring(val)
    elseif t == "table" then
      return self:serializeTable(val,indent)
    else
      return '"<unsupported type>"'
    end
  end,
  serializeTable = function (self,tbl,indent)
    indent = indent or ""
    local nextIndent = indent .. "  "
    local result = {}
    table.insert(result, "{\n")
    for k, v in pairs(tbl) do
      local key
      if type(k) == "string" and string.find(k, "^[_%a][_%w]*$") then
        key = k
      else
        key = "[" .. self:serializeValue(k, nextIndent) .. "]"
      end
      table.insert(result, nextIndent .. key .. " = " .. self:serializeValue(v, nextIndent) .. ",\n")
    end
    table.insert(result, indent .. "}")
    return table.concat(result)
  end,
}
---------

---------------
-- LoginManager
---------------

function LoginManager:ToFile(file,value)
  local v = Serialize:serializeValue(value)
  if v ~= '"<unsupported type>"' then
    ExportFile(file, Serialize:serializeValue(value,"  "))
    return true
  end
  return false
end

function LoginManager:FromFile(file)
  local contents = ImportFile(file)
  if contents then
    local chunk,err = loadstring("return " .. contents)
    if not err then
      return chunk()
    end
  end
  return false
end


function LoginManager:MakeExtraAccountButtons()
  -- make account up/down/lock buttons
  local button_size = 26
  for i=1,self.PageSize do
    local acctButton = _G["AutologinAccountButton"..i]
    if not acctButton.up then
      -- Create the Up button
      local upButton = CreateFrame("Button", acctButton:GetName().."Up", acctButton)
      upButton:SetWidth(button_size)
      upButton:SetHeight(button_size)
      upButton:SetPoint("TOPRIGHT", acctButton, "TOPRIGHT", -30, 1)
      upButton:SetHitRectInsets(1, 1, 1, 1)
      upButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
      upButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
      upButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
      upButton:SetScript("OnClick", function()
        moveIndexUp(self.State.accounts, this:GetParent():GetID())
        LoginManager:UpdateUI()
      end)
      upButton:SetScript("OnEnter", function()
        this:GetParent():LockHighlight()
      end)
      upButton:SetScript("OnLeave", function()
        if this:GetParent():GetID() ~= self.SelectedAcct then
          this:GetParent():UnlockHighlight()
        end
      end)
      acctButton.up = upButton
    end
  
    if not acctButton.down then
      -- Create the Down button
      local downButton = CreateFrame("Button", acctButton:GetName().."Down", acctButton)
      downButton:SetWidth(button_size)
      downButton:SetHeight(button_size)
      downButton:SetPoint("TOP", acctButton.up, "BOTTOM", 0, 8)
      downButton:SetHitRectInsets(1, 1, 1, 1)
      downButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
      downButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
      downButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
      downButton:SetScript("OnClick", function()
        moveIndexDown(self.State.accounts, this:GetParent():GetID())
        LoginManager:UpdateUI()
      end)
      downButton:SetScript("OnEnter", function()
        this:GetParent():LockHighlight()
      end)
      downButton:SetScript("OnLeave", function()
        if this:GetParent():GetID() ~= self.SelectedAcct then
          this:GetParent():UnlockHighlight()
        end
      end)
      acctButton.down = downButton
    end
  end

  local quitButton = _G["AccountLoginExitButton"]
  if not quitButton.lock then
    -- Create the Lock button
    local lockButton = CreateFrame("Button", "ButtonAccountButtonsLock", quitButton, "GlueButtonSmallTemplate")
    lockButton:SetWidth(150)
    lockButton:SetHeight(35)
    lockButton:SetPoint("RIGHT", quitButton, "LEFT", 4, 0)
    lockButton:SetText("Lock Accounts")
  
    lockButton:SetScript("OnClick", function()
      LoginManager.State.account_buttons_locked = not LoginManager.State.account_buttons_locked
      this:Show()

      LoginManager:UpdateUI()
    end)
    quitButton.lock = lockButton
  end
end

-- Strangely when you login and cancel the program scrubs the string you used for the password from _anywhere_ it finds it.
-- Essentially it deletes the immutable string itself. We avoid this by storing the password string in memory with a
-- leading : and clip the : at use-time. Trying other things like string.lower caused program hangs.
function LoginManager:LoadAccounts()
  self.State.accounts = {}
  self.State.last = nil

  local login_data = ImportFile("logins")
  local file = self:FromFile("logins")
  if file then
    if file.accounts then self.State.accounts = file.accounts end
    if file.last then self.State.last = file.last end
    if file.account_buttons_locked then self.State.account_buttons_locked = file.account_buttons_locked end
    return true
  elseif login_data then -- old format
    for label,account,password,character,auto,last in string.gfind(login_data, "label:(%S*) account:(%S+) password(:%S+) character:(%S*) auto:(%S*) last:(%S*)\n") do
      if auto == "true" then auto = true else auto = false end
      table.insert(self.State.accounts, { --[[ label = label, ]] account = account, password = password, character = character, auto = auto })
    end
    return true
  end
  -- no saved passwords? check the old style account string storage
  if not next(self.State.accounts) then
    local val = GetSavedAccountName()
    for n, p, c in string.gfind(val, "(%S+) (%S+) *(%d*);") do
      if (c == "") then c = "-" end

      -- Decompress duplicate passwords
      if (string.find(p, "~%d") == 1) then
        p = self.State.accounts[tonumber(string.sub(p, 2, 3))].password
      end

      table.insert(self.State.accounts, { account = n, password = p })
    end
    return true
  end
  return false
end

function LoginManager:SaveAccounts(by_login)
  if by_login then
    local account = AccountLoginAccountEdit:GetText()
    local password = AccountLoginPasswordEdit:GetText()

    -- only try to overwrite a password when there is one to overwrite!
    if (account and account ~= "" and password and password ~= "") then
      local exists = false
      for i = 1, table.getn(self.State.accounts) do
        if (self.State.accounts[i].account == account) then
          exists = true
          self.State.accounts[i].password = ":"..password
          break
        end
      end
      if (not exists) then
        table.insert(self.State.accounts, { account = account, password = ":"..password })
      end
    end
  end

  return self:ToFile("logins",self.State)
end

function LoginManager:SaveLabel()
  self:SaveAccounts(true)
  self:UpdateUI()
end

function LoginManager:SelectAccount(idx)
  local i = self.CurrentPage * self.PageSize + idx;
  local act = self.State.accounts[i].account
  local pwd = self.State.accounts[i].password

  AccountLoginAccountEdit:SetText(act)
  AccountLoginPasswordEdit:SetText(string.sub(pwd,2))
  LoginManager:OnNameUpdate(act)
end

function LoginManager:OnNameUpdate(name)
  self.SelectedAcct = nil
  for i = 1, table.getn(self.State.accounts) do
    if (self.State.accounts[i].account == name) then self.SelectedAcct = i end
  end
  if (self.SelectedAcct) then
    self.CurrentPage = math.floor((self.SelectedAcct - 1) / self.PageSize)
  end
  self:UpdateUI()
end

function LoginManager:UpdateUI()
  if AccountLoginUI:IsVisible() then
    self:MakeExtraAccountButtons()
    AccountLoginSaveAccountName:Hide()
    self:UpdateLoginUI()
  elseif CharacterSelectUI:IsVisible() then
    self:UpdateCharacterUI()
  end
end

function LoginManager:UpdateLoginUI()
  local total = table.getn(self.State.accounts)
  local pageIndices = {}
  local skip = self.CurrentPage * self.PageSize;

  for i = 1, self.PageSize do
    local button = _G["AutologinAccountButton" .. i]
    local acct_id = skip + i
    button:UnlockHighlight()
    if (acct_id > total) then
      button:Hide()
    else
      local r = self.State.accounts[acct_id]
      _G["AutologinAccountButton" .. i .. "ButtonTextName"]:SetText(r.account)

      local autochar = ""
      for realm,data in pairs(self.State.accounts[acct_id].characters or {}) do
        if data.auto then
          autochar = "|cffffff00"
          break
        end
      end

      _G["AutologinAccountButton" .. i .. "ButtonTextCharacter"]:SetText(
        'Last character: ' .. (autochar .. (r.character or ""))
      )

      if self.State.account_buttons_locked or acct_id == table.getn(self.State.accounts) then
        button.down:Hide()
      else
        button.down:Show()
      end
      if self.State.account_buttons_locked or acct_id == 1 then
        button.up:Hide()
      else
        button.up:Show()
      end
      
      if (self.SelectedAcct == acct_id) then
        button:LockHighlight()
      end
      button:Show()
      
    end
  end

  local lockButton = _G["ButtonAccountButtonsLock"]
  if lockButton then
    if self.State.account_buttons_locked then
      lockButton:GetNormalTexture():SetVertexColor(0.5,0.5,0.5)
      lockButton:SetTextColor(0.5,0.5,0.5)
    else
      lockButton:GetNormalTexture():SetVertexColor(1,1,1)
      lockButton:SetTextColor(1,0.78,0)
    end
  end
end

function LoginManager:UpdateCharacterUI()
  local numChars = GetNumCharacters()
  local index = 1
  for _,char in ipairs(LoginManager.realm_chars) do
    local zone = char.zone

    local button = _G["CharSelectCharacterButton"..index]
    if ( not char.name ) then
      button:SetText("ERROR - Tell Jeremy")  
    else
      button:UnlockHighlight()
      if ( not char.zone ) then
        zone = ""  
      end
      _G["CharSelectCharacterButton"..index.."ButtonTextName"]:SetText(char.name)  
      _G["CharSelectCharacterButton"..index.."ButtonTextInfo"]:SetText(
          format(TEXT(char.ghost and CHARACTER_SELECT_INFO_GHOST or CHARACTER_SELECT_INFO), char.level, char.class))  
      _G["CharSelectCharacterButton"..index.."ButtonTextLocation"]:SetText(zone)  
    end
    
    if (char.id == CharacterSelect.selectedIndex) then
      button:LockHighlight()
    end

    if char.id == LoginManager.auto_char then
      button.auto:SetChecked(1)
      _G["CharSelectCharacterButton"..index.."ButtonTextName"]:SetTextColor(0,1,1)
    else
      button.auto:SetChecked(nil)
      _G["CharSelectCharacterButton"..index.."ButtonTextName"]:SetTextColor(1,0.78,0)
    end

    if LoginManager.char_buttons_locked then
      button.up:Hide()
      button.down:Hide()
      button.auto:Hide()
    else
      button.up:Show()
      button.down:Show()
      button.auto:Show()
    end

    index = index + 1
    if ( index > MAX_CHARACTERS_DISPLAYED ) then
      break  
    end
  end

  local lockButton = _G["ButtonCharButtonsLock"]
  if lockButton then
    if self.char_buttons_locked then
      lockButton:GetNormalTexture():SetVertexColor(0.5,0.5,0.5)
      lockButton:SetTextColor(0.5,0.5,0.5)
    else
      lockButton:GetNormalTexture():SetVertexColor(1,1,1)
      lockButton:SetTextColor(1,0.78,0)
    end
  end
end

function LoginManager:OnLogin()
  local name = AccountLoginAccountEdit:GetText()
  local password = AccountLoginPasswordEdit:GetText()
  
  self.State.last = self.SelectedAcct
  self:SaveAccounts(true)
  self:OnNameUpdate(name)
  self.from_login_screen = true
  DefaultServerLogin(name, password)
end

function LoginManager:RemoveAccount()
  if not next(LoginManager.State.accounts) or not LoginManager.SelectedAcct then return end

  table.remove(LoginManager.State.accounts, LoginManager.SelectedAcct)
  LoginManager:SaveAccounts()
  AccountLoginAccountEdit:SetText("")
  AccountLoginPasswordEdit:SetText("")

  if (LoginManager.CurrentPage > 0 and LoginManager.CurrentPage * LoginManager.PageSize >
      table.getn(LoginManager.State) - 1) then
    LoginManager.CurrentPage = LoginManager.CurrentPage - 1
  end

  LoginManager:UpdateUI()
end

function LoginManager:NextPage()
  if ((self.CurrentPage + 1) * self.PageSize >
      table.getn(self.State.accounts) - 1) then return end
  self.CurrentPage = self.CurrentPage + 1
  self:UpdateUI()
end

function LoginManager:PrevPage()
  if (self.CurrentPage == 0) then return end
  self.CurrentPage = self.CurrentPage - 1
  self:UpdateUI()
end

function LoginManager:OnCharactersLoad()

  self:LoadAccounts()

  -- make up/down/auto buttons
  for i=1,10 do
    local charButton = _G["CharSelectCharacterButton"..i]
    if not charButton.up then
      -- Create the Up button
      local upButton = CreateFrame("Button", charButton:GetName().."Up", charButton)
      upButton:SetWidth(32)
      upButton:SetHeight(32)
      upButton:SetPoint("TOPRIGHT", charButton, "TOPRIGHT", -30, 0)
      upButton:SetHitRectInsets(1, 1, 1, 1)
      upButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
      upButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
      upButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
      upButton:SetScript("OnClick", function()
        moveIndexUp(LoginManager.realm_chars, this:GetParent():GetID())
        LoginManager:UpdateUI()
      end)
      upButton:SetScript("OnEnter", function()
        this:GetParent():LockHighlight()
      end)
      upButton:SetScript("OnLeave", function()
        if this:GetParent():GetID() ~= CharacterSelect.selectedIndex then
          this:GetParent():UnlockHighlight()
        end
      end)
      charButton.up = upButton
    end
  
    if not charButton.down then
      -- Create the Down button
      local downButton = CreateFrame("Button", charButton:GetName().."Down", charButton)
      downButton:SetWidth(32)
      downButton:SetHeight(32)
      downButton:SetPoint("TOP", charButton.up, "BOTTOM", 0, 8)
      downButton:SetHitRectInsets(1, 1, 1, 1)
      downButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
      downButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
      downButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
      downButton:SetScript("OnClick", function()
        moveIndexDown(LoginManager.realm_chars, this:GetParent():GetID())
        LoginManager:UpdateUI()
      end)
      downButton:SetScript("OnEnter", function()
        this:GetParent():LockHighlight()
      end)
      downButton:SetScript("OnLeave", function()
        if this:GetParent():GetID() ~= CharacterSelect.selectedIndex then
          this:GetParent():UnlockHighlight()
        end
      end)
      charButton.down = downButton
    end

    if not charButton.auto then
      -- Create the Down button
      local autoButton = CreateFrame("CheckButton", charButton:GetName().."AutoLogin", charButton)
      autoButton:SetWidth(32)
      autoButton:SetHeight(32)
      autoButton:SetPoint("RIGHT", charButton.up, "LEFT", 0, 0)
      autoButton:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
      autoButton:SetPushedTexture("IInterface\\Buttons\\UI-CheckBox-Down")
      autoButton:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
      autoButton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
      autoButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Disabled")
    
      autoButton:SetScript("OnClick", function()
        local id = this:GetParent():GetID()
        local sorted_id = LoginManager.realm_chars[id].id
        if LoginManager.auto_char == sorted_id then
          LoginManager.auto_char = nil
        else
          LoginManager.auto_char = sorted_id
        end
        LoginManager:UpdateUI()
      end)
      autoButton:SetScript("OnEnter", function()
        this:GetParent():LockHighlight()
        GlueTooltip_SetOwner(nil, nil, -250, -5);
        GlueTooltip_SetText("Automatically log into this character.", nil, 1.0, 1.0, 1.0);
      end)
      autoButton:SetScript("OnLeave", function()
        this:GetParent():UnlockHighlight()
        GlueTooltip:Hide()
      end)
      charButton.auto = autoButton
    end
  end

  local addonsButton = _G["CharacterSelectAddonsButton"]
  if not addonsButton.lock then
    -- Create the Lock button
    local lockButton = CreateFrame("Button", "ButtonCharButtonsLock", addonsButton, "GlueButtonSmallTemplate")
    lockButton:SetWidth(150)
    lockButton:SetHeight(35)
    lockButton:SetPoint("LEFT", addonsButton, "RIGHT", 4, 0)
    lockButton:SetText("Lock Characters")
  
    lockButton:SetScript("OnClick", function()
      LoginManager.char_buttons_locked = not LoginManager.char_buttons_locked
      this:Show()

      LoginManager:UpdateUI()
    end)
    addonsButton.lock = lockButton
  end

  self.realm = GetServerName()
  self.realm_chars = {}
  for c = 1, GetNumCharacters() do
    local name, race, class, level, zone, fileString, gender, ghost = GetCharacterInfo(c)
    self.realm_chars[c] = { id = c, name = name, race = race, class = class, level = level, zone = zone, fileString = fileString, gender = gender, ghost = ghost }
  end

  if not self.from_login_screen then
    -- handle case that we came from a char logout, iow determine what account we're using based on characters
    -- this matters when we're multiboxing or have auto-login enabled
    local function SetIdx()
      for i,account in ipairs(self.State.accounts) do
        for saved_realm,saved_chars in pairs(account.characters or {}) do
          if saved_realm == self.realm then
            for _,schar in pairs(saved_chars.order) do
              for _,rchar in pairs(self.realm_chars) do
                if schar.name == rchar.name then
                  self.SelectedAcct = i
                  return
                end
              end
            end
          end
        end
      end
    end
    SetIdx()
  end

  -- reconcile given chars with saved chars
  local acct = self.State.accounts[self.SelectedAcct]
  if acct and acct.characters then
    for saved_realm,saved_chars in pairs(acct.characters or {}) do
      if saved_realm == self.realm then
        self.auto_char = saved_chars.auto
        self.char_buttons_locked = saved_chars.char_buttons_locked

        local orderRank = {}
        local rank = 1
        for _, item in ipairs(saved_chars.order or {}) do
          orderRank[item.id] = rank
          rank = rank + 1
        end

        -- Reorder primaryList in place using table.sort with a custom comparator.
        table.sort(LoginManager.realm_chars, function(a, b)
          local ra = orderRank[a.id] or 10000
          local rb = orderRank[b.id] or 10000
          return ra < rb
        end)

        break
      end
    end
  end

  if self.auto_char and self.auto_char > 0 and self.from_login_screen then
    CharacterSelect_SelectCharacter(self.auto_char)
    EnterWorld()
  end

  self:UpdateUI()
end

function LoginManager:EnterWorld()
  -- save live state

  if self.realm and self.SelectedAcct and self.State.accounts[self.SelectedAcct] then
    local acct = self.State.accounts[self.SelectedAcct]
    acct.characters = acct.characters or {}
    acct.characters[self.realm] = acct.characters[self.realm] or {}

    local chars = acct.characters[self.realm]
    chars.last = CharacterSelect.selectedIndex or 1
    chars.order = {}
    for i,char in ipairs(LoginManager.realm_chars) do
      table.insert(chars.order, { id = char.id, name = char.name })
    end
    chars.auto = self.auto_char or nil
    chars.char_buttons_locked = self.char_buttons_locked or nil
    acct.character = GetCharacterInfo(chars.last)
  end
  self:SaveAccounts()

  EnterWorld()
end

---------------

----------
-- buttons
----------
function AutologinAccountButton_OnClick(button)
  if button == "LeftButton" then
    LoginManager:SelectAccount(this:GetID())
  end
end

function AutologinAccountButton_OnDoubleClick()
  LoginManager:SelectAccount(this:GetID())
  AccountLogin_Login()
end

function AutologinRemoveAccountButton_OnClick()
  LoginManager:RemoveAccount()
end
----------

--------
-- hooks
--------
local orig_AccountLogin_OnLoad = AccountLogin_OnLoad
AccountLogin_OnLoad = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  if orig_AccountLogin_OnLoad then orig_AccountLogin_OnLoad(a1,a2,a3,a4,a5,a6,a7,a8,a9) end

  LoginManager:LoadAccounts()
end

local orig_AccountLogin_OnShow = AccountLogin_OnShow
AccountLogin_OnShow = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)

  if orig_AccountLogin_OnShow then orig_AccountLogin_OnShow(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
  
  if not LoginManager.State.accounts then LoginManager:LoadAccounts() end
  
  if LoginManager.State.last and LoginManager.State.accounts[LoginManager.State.last] then
    LoginManager:SelectAccount(LoginManager.State.last)
  end
  
  LoginManager:UpdateUI()
end

local orig_AccountLoginAccountEdit_OnTextChanged = AccountLoginAccountEdit:GetScript("OnTextChanged")
AccountLoginAccountEdit:SetScript("OnTextChanged", function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  orig_AccountLoginAccountEdit_OnTextChanged(a1,a2,a3,a4,a5,a6,a7,a8,a9)
  LoginManager:OnNameUpdate(this:GetText())
end)

local orig_AccountLogin_Login = AccountLogin_Login
AccountLogin_Login = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  LoginManager:OnLogin()
  -- if we got this far it's our show, take over
  -- if orig_AccountLogin_Login then orig_AccountLogin_Login(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
end

--------

local orig_CharacterSelectButton_OnClick = CharacterSelectButton_OnClick
CharacterSelectButton_OnClick = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  -- orig_CharacterSelectButton_OnClick(a1,a2,a3,a4,a5,a6,a7,a8,a9)
  local id = this:GetID()
  local sorted_id = LoginManager.realm_chars[id].id
  CharacterSelect_SelectCharacter(sorted_id)
  LoginManager:UpdateUI()
end

local orig_CharacterSelectButton_OnDoubleClick = CharacterSelectButton_OnDoubleClick
CharacterSelectButton_OnDoubleClick = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  -- orig_CharacterSelectButton_OnDoubleClick(a1,a2,a3,a4,a5,a6,a7,a8,a9)
  local id = this:GetID()
  local sorted_id = LoginManager.realm_chars[id].id
  if ( sorted_id ~= CharacterSelect.selectedIndex ) then
    CharacterSelect_SelectCharacter(sorted_id)
  end
  CharacterSelect_EnterWorld()
end

local orig_CharacterSelect_OnKeyDown = CharacterSelect_OnKeyDown
CharacterSelect_OnKeyDown = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  local numChars = GetNumCharacters()  
  local button_index
  for i,char in ipairs(LoginManager.realm_chars) do
    if char.id == this.selectedIndex then
      button_index = i
      break
    end
  end

  if ( arg1 == "UP" or arg1 == "LEFT" ) then
    if ( numChars > 1 ) then
      if ( button_index > 1 ) then
        _G["CharSelectCharacterButton" .. (button_index - 1)]:Click()
      else
        _G["CharSelectCharacterButton" .. numChars]:Click()
      end
    end
  elseif ( arg1 == "DOWN" or arg1 == "RIGHT" ) then
    if ( numChars > 1 ) then
      if ( button_index < GetNumCharacters() ) then
        _G["CharSelectCharacterButton" .. (button_index + 1)]:Click()
      else
        _G["CharSelectCharacterButton" .. 1]:Click()
      end
    end
  else
    orig_CharacterSelect_OnKeyDown(a1,a2,a3,a4,a5,a6,a7,a8,a9)
  end
end

local orig_CharacterSelect_OnEvent = CharacterSelect_OnEvent
CharacterSelect_OnEvent = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  if orig_CharacterSelect_OnEvent then orig_CharacterSelect_OnEvent(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
  if event == "CHARACTER_LIST_UPDATE" then
    LoginManager:OnCharactersLoad()
  end
end

local orig_CharacterSelect_EnterWorld = CharacterSelect_EnterWorld
CharacterSelect_EnterWorld = function (a1,a2,a3,a4,a5,a6,a7,a8,a9)
  LoginManager:EnterWorld()
end
--------
