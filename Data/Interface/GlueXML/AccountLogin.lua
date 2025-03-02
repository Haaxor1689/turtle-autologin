Autologin_Table = {}
Autologin_SelectedIdx = nil;
Autologin_CurrentPage = 0;
Autologin_PageSize = 4;
Autologin_LimitReached = false;

-- local has_superwow = SetAutoloot and true or false
local _,_,superwow_version_major,superwow_version_minor = string.find(SUPERWOW_VERSION or "", "(%d+)%.(%d+)")
superwow_version_major = tonumber(superwow_version_major) or -1
superwow_version_minor = tonumber(superwow_version_minor) or -1

if not (superwow_version_major >= 1 and superwow_version_minor >= 4) then
  -- show popup saying this won't work
end

-- A simple pure-Lua XOR function for two numbers.
local function bitXor(a, b)
  local r, bitVal = 0, 1
  while a > 0 or b > 0 do
    local aBit = math.mod(a, 2)
    local bBit = math.mod(b, 2)
    if aBit ~= bBit then
      r = r + bitVal
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bitVal = bitVal * 2
  end
  return r
end

local function simpleXOREncryptDecrypt(text, key)
  local keyLen = string.len(key)
  local result = {}
  for i = 1, string.len(text) do
    local textByte = string.byte(text, i)
    local keyByte  = string.byte(key, (math.mod((i - 1), keyLen)) + 1)
    result[i] = string.char(bitXor(textByte, keyByte))
  end
  return table.concat(result)
end


LoginManager = {}
LoginManager.cy_s = "simple"
LoginManager.loaded_from_account_name = false

-- No-ops right now, it's more useful to have a plaintext
function LoginManager:Encrypt(data)
  -- simpleXOREncryptDecrypt(data,self.cy_s)
  return data
end

function LoginManager:Decrypt(data)
  -- simpleXOREncryptDecrypt(data,self.cy_s)
  return data
end

-- Strangely when you login and cancel the program scrubs the string you used for the password from _anywhere_ it finds it.
-- Essentially it deletes the immutable string itself. We avoid this by storing the password string in memory with a
-- leading : and clip the : at use-time
function LoginManager:LoadAccounts()
  local login_data = ImportFile("logins")
  if login_data then
    login_data = self:Decrypt(login_data)
    for label,account,password,character,auto,last in string.gfind(login_data, "label:(%S*) account:(%S+) password(:%S+) character:(%S*) auto:(%S*) last:(%S*)\n") do
      local label = label
      local account = account
      local password = password
      local character = character
      local auto = auto
      local last = last
      table.insert(Autologin_Table, { label = label, account = account, password = password, character = character, auto = auto, last = last })
      -- ExportFile("faf",(ImportFile("faf") or "") .. ("load  : "..account .. " "..(password or "none") .. "\n"))
    end
  end
  -- no saved passwords? check the old style account string storage
  if not next(Autologin_Table) then
    local val = GetSavedAccountName()
    for n, p, c in string.gfind(val, "(%S+) (%S+) *(%d*);") do
      if (c == "") then c = "-" end

      -- Decompress duplicate passwords
      if (string.find(p, "~%d") == 1) then
        p = Autologin_Table[tonumber(string.sub(p, 2, 3))].password;
      end

      table.insert(Autologin_Table, { account = n, password = p });
    end
  end
end
-- LoginManager:LoadAccounts()

function LoginManager:SaveAccounts(by_login)
  if by_login then
    local account = AccountLoginAccountEdit:GetText();
    local label = AccountLoginLabelEdit:GetText()
    local password = AccountLoginPasswordEdit:GetText()
    label = label ~= "" and label or nil
    -- ExportFile("faf",(ImportFile("faf") or "") .. ("pasbox: "..account .. " "..(password or "none") .. "\n"))
    
    -- only try to overwrite a password when there is one to overwrite!
    if (account and account ~= "" and password and password ~= "") then
      local exists = false;
      for i = 1, table.getn(Autologin_Table) do
        if (Autologin_Table[i].account == account) then
          local l = label
          local p = password
          exists = true;
          Autologin_Table[i].label = l;
          Autologin_Table[i].password = ":"..p;
          -- ExportFile("faf",(ImportFile("faf") or "") .. ("exists: "..account .. " "..(password or "none") .. "\n"))
          break
        end
      end
      if (not exists) then
        -- ExportFile("faf",(ImportFile("faf") or "") .. ("notexists: "..account .. " "  ..(password or "none") .. "\n"))

        table.insert(Autologin_Table, { label = label, account = account, password = ":"..password });
      end
    end
  end

  local login_data = ""
  for ix,data in pairs(Autologin_Table) do
    -- local p = string.lower(data.password)
    local copy = string.format("%s", data.password)
    login_data = login_data .. format("label:%s account:%s password%s character:%s auto:%s last:%s\n", data.label or "", data.account, copy, data.character or "", data.auto or "false", data.last or "false")
    -- ExportFile("faf",(ImportFile("faf") or "") .. ("relod: ".. data.label .. " " .. data.account .. " "..(data.password or "none") .. "\n"))
  end
  ExportFile("logins",self:Encrypt(login_data))
  -- if self.loaded_from_account_name then
  --   local _,_,name = string.find(GetSavedAccountName(), "(%S+)")
  --   SetSavedAccountName(name)
  -- end
end

function Autologin_SelectAccount(idx)
  local i = Autologin_CurrentPage * Autologin_PageSize + idx;
  local act = Autologin_Table[i].account
  local lbl = Autologin_Table[i].label
  local pwd = Autologin_Table[i].password
  local tmp = pwd
  -- ExportFile("tmp.txt",password)
  -- local scratch_password = ImportFile("tmp.txt")

  AccountLoginAccountEdit:SetText(act);
  AccountLoginLabelEdit:SetText(lbl or "");
  AccountLoginPasswordEdit:SetText(string.sub(tmp,2));
  -- Autologin_Table[i].password = Autologin_Table[i].swap
end

function Autologin_OnNameUpdate(name)
  Autologin_SelectedIdx = nil;
  for i = 1, table.getn(Autologin_Table) do
    if (Autologin_Table[i].account == name) then Autologin_SelectedIdx = i; end
  end
  if (Autologin_SelectedIdx) then
    Autologin_CurrentPage = math.floor((Autologin_SelectedIdx - 1) /
                                           Autologin_PageSize);
  end
  Autologin_UpdateUI();
end

function Autologin_UpdateUI()
  local skip = Autologin_CurrentPage * Autologin_PageSize;
  for i = 1, Autologin_PageSize do
    getglobal("AutologinAccountButton" .. i):UnlockHighlight();
    if (skip + i > table.getn(Autologin_Table)) then
      getglobal("AutologinAccountButton" .. i):Hide();
    else
      local r = Autologin_Table[skip + i];
      getglobal("AutologinAccountButton" .. i):Show();
      getglobal("AutologinAccountButton" .. i .. "ButtonTextName"):SetText(
          'Account:  ' .. r.account);
      getglobal("AutologinAccountButton" .. i .. "ButtonTextLabel"):SetText(
          r.label or "");
      getglobal("AutologinAccountButton" .. i .. "ButtonTextPassword"):SetText(
          'Password: ' .. string.rep("*", string.len(r.password)));

      local autochar = r.auto == "true" and "|cffffff00" or ""
      getglobal("AutologinAccountButton" .. i .. "ButtonTextCharacter"):SetText(
          'Character: ' .. ((r.character and (autochar .. r.character)) or ""));

      if (Autologin_SelectedIdx == skip + i) then
        getglobal("AutologinAccountButton" .. i):LockHighlight();
      end
    end
  end

  if (Autologin_LimitReached) then
    getglobal("AutologinSizeWarning"):Show();
  else
    getglobal("AutologinSizeWarning"):Hide();
  end
end

function Autologin_OnLogin()
  local name = AccountLoginAccountEdit:GetText();
  local password = AccountLoginPasswordEdit:GetText();
  
  -- if not next(Autologin_Table) then LoginManager:LoadAccounts() end

  -- Autologin OnLogin
  -- Autologin_Save(name, password);
  LoginManager:SaveAccounts(true)
  Autologin_OnNameUpdate(name);
  DefaultServerLogin(name, password);
  -- Autologin_Load();
  -- Autologin_UpdateUI();
end

function AutologinAccountButton_OnClick(button)
  if button == "LeftButton" then
    Autologin_SelectAccount(this:GetID());
  elseif button == "RightButton" then
    local i = Autologin_CurrentPage * Autologin_PageSize + this:GetID();
    if Autologin_Table[i] then
      if Autologin_Table[i].auto == "true" then
        Autologin_Table[i].auto = "false"
      elseif Autologin_Table[i].auto == "false" then
        Autologin_Table[i].auto = "true"
      end
    end
    Autologin_UpdateUI();
  end
end

function AutologinAccountButton_OnDoubleClick()
  Autologin_SelectAccount(this:GetID());
  AccountLogin_Login();
end

function Autologin_RemoveAccount()
  if not next(AutoLoginAccounts) or not Autologin_SelectedIdx then return end

  table.remove(Autologin_Table, Autologin_SelectedIdx);
  -- Autologin_Save();
  LoginManager:SaveAccounts()
  AccountLoginAccountEdit:SetText("");
  AccountLoginLabelEdit:SetText("");
  AccountLoginPasswordEdit:SetText("");

  if (Autologin_CurrentPage > 0 and Autologin_CurrentPage * Autologin_PageSize >
      table.getn(Autologin_Table) - 1) then
    Autologin_CurrentPage = Autologin_CurrentPage - 1;
  end

  Autologin_UpdateUI();
end

function Autologin_NextPage()
  if ((Autologin_CurrentPage + 1) * Autologin_PageSize >
      table.getn(Autologin_Table) - 1) then return end
  Autologin_CurrentPage = Autologin_CurrentPage + 1;
  Autologin_UpdateUI();
end

function Autologin_PrevPage()
  if (Autologin_CurrentPage == 0) then return end
  Autologin_CurrentPage = Autologin_CurrentPage - 1;
  Autologin_UpdateUI();
end

-- Vanilla code

FADE_IN_TIME = 2;
DEFAULT_TOOLTIP_COLOR = { 0.8, 0.8, 0.8, 0.09, 0.09, 0.09 };
MAX_PIN_LENGTH = 10;

function AccountLogin_OnLoad()
  this:SetSequence(0);
  this:SetCamera(0);

  this:RegisterEvent("SHOW_SERVER_ALERT");
  this:RegisterEvent("SHOW_SURVEY_NOTIFICATION");

  local versionType, buildType, version, internalVersion, date = GetBuildInfo();
  AccountLoginVersion:SetText(format(TEXT(VERSION_TEMPLATE), versionType,
                                     version, internalVersion, buildType, date));

  -- Color edit box backdrops
  local backdropColor = DEFAULT_TOOLTIP_COLOR;
  AccountLoginAccountEdit:SetBackdropBorderColor(backdropColor[1],
                                                 backdropColor[2],
                                                 backdropColor[3]);
  AccountLoginAccountEdit:SetBackdropColor(backdropColor[4], backdropColor[5],
                                           backdropColor[6]);
  AccountLoginLabelEdit:SetBackdropBorderColor(backdropColor[1],
                                               backdropColor[2],
                                               backdropColor[3]);
  AccountLoginLabelEdit:SetBackdropColor(backdropColor[4], backdropColor[5],
                                         backdropColor[6]);
  AccountLoginPasswordEdit:SetBackdropBorderColor(backdropColor[1],
                                                  backdropColor[2],
                                                  backdropColor[3]);
  AccountLoginPasswordEdit:SetBackdropColor(backdropColor[4], backdropColor[5],
                                            backdropColor[6]);
end

function AccountLogin_OnShow()
  CurrentGlueMusic = "Sound\\Music\\GlueScreenMusic\\wow_main_theme.mp3";

  AcceptTOS();
  AcceptEULA();
  local serverName = GetServerName();
  if (serverName) then
    AccountLoginRealmName:SetText(serverName);
  else
    AccountLoginRealmName:Hide()
  end

  if not next(Autologin_Table) then LoginManager:LoadAccounts() end

  if (table.getn(Autologin_Table) ~= 0) then Autologin_SelectAccount(1); end
  Autologin_UpdateUI();

  if (GetSavedAccountName() == "") then
    AccountLogin_FocusAccountName();
  else
    AccountLogin_FocusPassword();
  end
end

function AccountLogin_FocusPassword() AccountLoginPasswordEdit:SetFocus(); end

function AccountLogin_FocusLabel() AccountLoginLabelEdit:SetFocus(); end

function AccountLogin_FocusAccountName() AccountLoginAccountEdit:SetFocus(); end

function AccountLogin_OnChar() end

function AccountLogin_OnKeyDown()
  if (arg1 == "ESCAPE") then
    if (ConnectionHelpFrame:IsVisible()) then
      ConnectionHelpFrame:Hide();
      AccountLoginUI:Show();
    elseif (SurveyNotificationFrame:IsVisible()) then
      -- do nothing
    else
      AccountLogin_Exit();
    end

  elseif (arg1 == "ENTER") then
    if (not TOSAccepted()) then
      return;
    elseif (TOSFrame:IsVisible() or ConnectionHelpFrame:IsVisible()) then
      return;
    elseif (SurveyNotificationFrame:IsVisible()) then
      AccountLogin_SurveyNotificationDone(1);
    end
    AccountLogin_Login();
  elseif (arg1 == "PRINTSCREEN") then
    Screenshot();
  end
end

function AccountLogin_OnEvent(event)
  if (event == "SHOW_SERVER_ALERT") then
    ServerAlertText:SetText(arg1);
    ServerAlertScrollFrame:UpdateScrollChildRect();
    ServerAlertFrame:Show();
  elseif (event == "SHOW_SURVEY_NOTIFICATION") then
    AccountLogin_ShowSurveyNotification();
  end
end

function AccountLogin_Login()
  PlaySound("gsLogin");
  -- LoginManager:SaveAccounts()
  Autologin_OnLogin();
end

function AccountLogin_Turtle_Armory_Website()
  PlaySound("gsLoginNewAccount");
  LaunchURL(TURTLE_ARMORY_WEBSITE);
end

function AccountLogin_Turtle_Website()
  PlaySound("gsLoginNewAccount");
  LaunchURL(AUTH_TURTLE_WEBSITE);
end

function AccountLogin_Turtle_Knowledge_Database()
  PlaySound("gsLoginNewAccount");
  LaunchURL(TURTLE_KNOWLEDGE_DATABASE_WEBSITE);
end

function AccountLogin_Turtle_Community_Forum()
  PlaySound("gsLoginNewAccount");
  LaunchURL(TURTLE_COMMUNITY_FORUM_WEBSITE);
end

function AccountLogin_Turtle_Discord()
  PlaySound("gsLoginNewAccount");
  LaunchURL(TURTLE_DISCORD_WEBSITE);
end

function AccountLogin_Credits()
  if (not GlueDialog:IsVisible()) then
    PlaySound("gsTitleCredits");
    SetGlueScreen("credits");
  end
end

function AccountLogin_Cinematics()
  if (not GlueDialog:IsVisible()) then
    PlaySound("gsTitleIntroMovie");
    SetGlueScreen("movie");
  end
end

function AccountLogin_Options() PlaySound("gsTitleOptions"); end

function AccountLogin_Exit()
  PlaySound("gsTitleQuit");
  QuitGame();
end

function AccountLogin_ShowSurveyNotification()
  GlueDialog:Hide();
  AccountLoginUI:Hide();
  SurveyNotificationAccept:Enable();
  SurveyNotificationDecline:Enable();
  SurveyNotificationFrame:Show();
end

function AccountLogin_SurveyNotificationDone(accepted)
  SurveyNotificationFrame:Hide();
  SurveyNotificationAccept:Disable();
  SurveyNotificationDecline:Disable();
  SurveyNotificationDone(accepted);
  AccountLoginUI:Show();
end

-- Virtual keypad functions
function VirtualKeypadFrame_OnEvent(event)
  if (event == "PLAYER_ENTER_PIN") then
    for i = 1, 10 do
      getglobal("VirtualKeypadButton" .. i):SetText(getglobal("arg" .. i));
    end
  end
  -- Randomize location to prevent hacking (yeah right)
  local xPadding = 5;
  local yPadding = 10;
  local xPos = random(xPadding, GlueParent:GetWidth() -
                          VirtualKeypadFrame:GetWidth() - xPadding);
  local yPos = random(yPadding, GlueParent:GetHeight() -
                          VirtualKeypadFrame:GetHeight() - yPadding);
  VirtualKeypadFrame:SetPoint("TOPLEFT", GlueParent, "TOPLEFT", xPos, -yPos);

  VirtualKeypadFrame:Show();
  VirtualKeypad_UpdateButtons();
end

function VirtualKeypadButton_OnClick()
  local text = VirtualKeypadText:GetText();
  if (not text) then text = ""; end
  VirtualKeypadText:SetText(text .. "*");
  VirtualKeypadFrame.PIN = VirtualKeypadFrame.PIN .. this:GetID();
  VirtualKeypad_UpdateButtons();
end

function VirtualKeypadOkayButton_OnClick()
  local PIN = VirtualKeypadFrame.PIN;
  local numNumbers = strlen(PIN);
  local pinNumber = {};
  for i = 1, MAX_PIN_LENGTH do
    if (i <= numNumbers) then
      pinNumber[i] = strsub(PIN, i, i);
    else
      pinNumber[i] = nil;
    end
  end
  PINEntered(pinNumber[1], pinNumber[2], pinNumber[3], pinNumber[4],
             pinNumber[5], pinNumber[6], pinNumber[7], pinNumber[8],
             pinNumber[9], pinNumber[10]);
  VirtualKeypadFrame:Hide();
end

function VirtualKeypad_UpdateButtons()
  local numNumbers = strlen(VirtualKeypadFrame.PIN);
  if (numNumbers >= 4 and numNumbers <= MAX_PIN_LENGTH) then
    VirtualKeypadOkayButton:Enable();
  else
    VirtualKeypadOkayButton:Disable();
  end
  if (numNumbers == 0) then
    VirtualKeypadBackButton:Disable();
  else
    VirtualKeypadBackButton:Enable();
  end
  if (numNumbers >= MAX_PIN_LENGTH) then
    for i = 1, MAX_PIN_LENGTH do
      getglobal("VirtualKeypadButton" .. i):Disable();
    end
  else
    for i = 1, MAX_PIN_LENGTH do
      getglobal("VirtualKeypadButton" .. i):Enable();
    end
  end
end
