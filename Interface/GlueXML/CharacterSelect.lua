function Autologin_OnCharactersLoad()
  Autologin_Load();
  local selected = Autologin_Table[Autologin_SelectedIdx];
  if (not selected) then
    AutologinSaveCharacterButton:Hide();
    return;
  end

  AutologinSaveCharacterButton:Show();
  if (selected.character == '-') then return end

  -- Get id from the character name
  for i = 1, GetNumCharacters() do
    local name = GetCharacterInfo(i);
    if (name == selected.character) then
      SelectCharacter(i);
      EnterWorld();
    end
  end
end

function Autologin_EnterWorld()
  -- Update autologin character if checkbox is checked
  if (Autologin_SelectedIdx and AutologinSaveCharacterButton:GetChecked()) then
    local name = GetCharacterInfo(CharacterSelect.selectedIndex);
    Autologin_Table[Autologin_SelectedIdx].character = name;
    Autologin_Save();
  end

  EnterWorld();
end

-- Vanilla code

CHARACTER_SELECT_ROTATION_START_X = nil;
CHARACTER_SELECT_INITIAL_FACING = nil;

CHARACTER_ROTATION_CONSTANT = 0.6;

MAX_CHARACTERS_DISPLAYED = 10;
MAX_CHARACTERS_PER_REALM = 10;

function CharacterSelect_OnLoad()
  this:SetSequence(0);
  this:SetCamera(0);

  this.createIndex = 0;
  this.selectedIndex = 0;
  this.selectLast = 0;
  this.currentModel = "";
  this:RegisterEvent("ADDON_LIST_UPDATE");
  this:RegisterEvent("CHARACTER_LIST_UPDATE");
  this:RegisterEvent("UPDATE_SELECTED_CHARACTER");
  this:RegisterEvent("SELECT_LAST_CHARACTER");
  this:RegisterEvent("SELECT_FIRST_CHARACTER");
  this:RegisterEvent("SUGGEST_REALM");
  this:RegisterEvent("FORCE_RENAME_CHARACTER");

  CharacterSelect:SetModel("Interface\\Glues\\Models\\UI_Orc\\UI_Orc.mdx");

  local fogInfo = CharModelFogInfo["ORC"];
  CharacterSelect:SetFogColor(fogInfo.r, fogInfo.g, fogInfo.b);
  CharacterSelect:SetFogNear(0);
  CharacterSelect:SetFogFar(fogInfo.far);

  SetCharSelectModelFrame("CharacterSelect");
  -- CharSelectModel:SetLight(1, 0, 0, -0.707, -0.707, 0.7, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 0.8);

  -- Color edit box backdrops
  local backdropColor = DEFAULT_TOOLTIP_COLOR;
  CharacterSelectCharacterFrame:SetBackdropBorderColor(backdropColor[1],
                                                       backdropColor[2],
                                                       backdropColor[3]);
  CharacterSelectCharacterFrame:SetBackdropColor(backdropColor[4],
                                                 backdropColor[5],
                                                 backdropColor[6], 0.85);

end

function CharacterSelect_OnShow()
  CurrentGlueMusic = "Sound\\Music\\GlueScreenMusic\\wow_main_theme.mp3";

  UpdateAddonButton();

  local serverName, isPVP, isRP = GetServerName();
  local connected = IsConnectedToServer();
  local serverType = "";
  if (serverName) then
    if (not connected) then
      serverName = serverName .. "\n(" .. TEXT(SERVER_DOWN) .. ")";
    end
    if (isPVP) then
      if (isRP) then
        serverType = RPPVP_PARENTHESES;
      else
        serverType = PVP_PARENTHESES;
      end
    elseif (isRP) then
      serverType = RP_PARENTHESES;
    end
    CharSelectRealmName:SetText(serverName .. " " .. serverType);
    CharSelectRealmName:Show();
  else
    CharSelectRealmName:Hide();
  end

  if (connected) then
    GetCharacterListUpdate();
  else
    UpdateCharacterList();
  end

  -- Gameroom billing stuff (For Korea and China only)
  if (SHOW_GAMEROOM_BILLING_FRAME) then
    local paymentPlan, hasFallBackBillingMethod, isGameRoom = GetBillingPlan();
    if (paymentPlan == 0) then
      -- No payment plan
      GameRoomBillingFrame:Hide();
    else
      local billingTimeLeft = GetBillingTimeRemaining();
      -- Set default text for the payment plan
      local billingText = getglobal("BILLING_TEXT" .. paymentPlan);
      if (paymentPlan == 1) then
        -- Recurring account
        billingTimeLeft = ceil(billingTimeLeft / (60 * 24));
        if (billingTimeLeft == 1) then
          billingText = BILLING_TIME_LEFT_LAST_DAY;
        end
      elseif (paymentPlan == 2) then
        -- Free account
        if (billingTimeLeft < (24 * 60)) then
          billingText = format(BILLING_FREE_TIME_EXPIRE,
                               billingTimeLeft .. " " ..
                                   GetText("MINUTES_ABBR", nil, billingTimeLeft));
        end
      elseif (paymentPlan == 3) then
        -- Fixed but not recurring
        if (isGameRoom == 1) then
          if (billingTimeLeft <= 30) then
            billingText = BILLING_GAMEROOM_EXPIRE;
          else
            billingText = format(BILLING_FIXED_IGR,
                                 MinutesToTime(billingTimeLeft, 1));
          end
        else
          -- personal fixed plan
          if (billingTimeLeft < (24 * 60)) then
            billingText = BILLING_FIXED_LASTDAY;
          else
            billingText = format(billingText, MinutesToTime(billingTimeLeft));
          end
        end
      elseif (paymentPlan == 4) then
        -- Usage plan
        if (isGameRoom == 1) then
          -- game room usage plan
          if (billingTimeLeft <= 600) then
            billingText = BILLING_GAMEROOM_EXPIRE;
          else
            billingText = BILLING_IGR_USAGE;
          end
        else
          -- personal usage plan
          if (billingTimeLeft <= 30) then
            billingText = BILLING_TIME_LEFT_30_MINS;
          else
            billingText = format(billingText, billingTimeLeft);
          end
        end
      end
      -- If fallback payment method add a note that says so
      if (hasFallBackBillingMethod == 1) then
        billingText = billingText .. "\n\n" .. BILLING_HAS_FALLBACK_PAYMENT;
      end
      GameRoomBillingFrameText:SetText(billingText);
      GameRoomBillingFrame:SetHeight(GameRoomBillingFrameText:GetHeight() + 26);
      GameRoomBillingFrame:Show();
    end
  end

  -- fadein the character select ui
  GlueFrameFadeIn(CharacterSelectUI, CHARACTER_SELECT_FADE_IN)
end

function CharacterSelect_OnHide()
  CharacterDeleteDialog:Hide();
  CharacterRenameDialog:Hide();
end

function CharacterSelect_OnKeyDown()
  if (arg1 == "ESCAPE") then
    CharacterSelect_Exit();
  elseif (arg1 == "ENTER") then
    CharacterSelect_EnterWorld();
  elseif (arg1 == "PRINTSCREEN") then
    Screenshot();
  elseif (arg1 == "UP" or arg1 == "LEFT") then
    local numChars = GetNumCharacters();
    if (numChars > 1) then
      if (this.selectedIndex > 1) then
        CharacterSelect_SelectCharacter(this.selectedIndex - 1);
      else
        CharacterSelect_SelectCharacter(numChars);
      end
    end
  elseif (arg1 == "DOWN" or arg1 == "RIGHT") then
    local numChars = GetNumCharacters();
    if (numChars > 1) then
      if (this.selectedIndex < GetNumCharacters()) then
        CharacterSelect_SelectCharacter(this.selectedIndex + 1);
      else
        CharacterSelect_SelectCharacter(1);
      end
    end
  end
end

function CharacterSelect_OnEvent()
  if (event == "ADDON_LIST_UPDATE") then
    UpdateAddonButton();
  elseif (event == "CHARACTER_LIST_UPDATE") then
    UpdateCharacterList();
    CharSelectCharacterName:SetText(GetCharacterInfo(this.selectedIndex));

    Autologin_OnCharactersLoad();

  elseif (event == "UPDATE_SELECTED_CHARACTER") then
    if (arg1 == 0) then
      CharSelectCharacterName:SetText("");
    else
      CharSelectCharacterName:SetText(GetCharacterInfo(arg1));
      this.selectedIndex = arg1;
    end
    UpdateCharacterSelection();
  elseif (event == "SELECT_LAST_CHARACTER") then
    this.selectLast = 1;
  elseif (event == "SELECT_FIRST_CHARACTER") then
    CharacterSelect_SelectCharacter(1, 1);
  elseif (event == "SUGGEST_REALM") then
    local name = GetRealmInfo(arg1, arg2);
    RealmWizard.suggestedRealmName = name;
    RealmWizard.suggestedCategory = arg1;
    RealmWizard.suggestedID = arg2;
    GlueDialog_Show("SUGGEST_REALM");
  elseif (event == "FORCE_RENAME_CHARACTER") then
    CharacterRenameDialog:Show();
    CharacterRenameText1:SetText(getglobal(arg1));
  end
end

function CharacterSelect_UpdateModel()
  UpdateSelectionCustomizationScene();
  this:AdvanceTime();
end

function UpdateCharacterSelection()
  for i = 1, MAX_CHARACTERS_DISPLAYED, 1 do
    getglobal("CharSelectCharacterButton" .. i):UnlockHighlight();
  end

  local index = this.selectedIndex;
  if ((index > 0) and (index <= MAX_CHARACTERS_DISPLAYED)) then
    getglobal("CharSelectCharacterButton" .. index):LockHighlight();
  end
end

function UpdateCharacterList()
  local numChars = GetNumCharacters();
  local index = 1;
  local coords;
  for i = 1, numChars, 1 do
    local name, race, class, level, zone, fileString, gender, ghost =
        GetCharacterInfo(i);
    if (gender == 0) then
      gender = "MALE";
    else
      gender = "FEMALE";
    end
    local button = getglobal("CharSelectCharacterButton" .. index);
    if (not name) then
      button:SetText("ERROR - Tell Jeremy");
    else
      if (not zone) then zone = ""; end
      getglobal("CharSelectCharacterButton" .. index .. "ButtonTextName"):SetText(
          name);
      if (ghost) then
        getglobal("CharSelectCharacterButton" .. index .. "ButtonTextInfo"):SetText(
            format(TEXT(CHARACTER_SELECT_INFO_GHOST), level, class));
      else
        getglobal("CharSelectCharacterButton" .. index .. "ButtonTextInfo"):SetText(
            format(TEXT(CHARACTER_SELECT_INFO), level, class));
      end
      getglobal("CharSelectCharacterButton" .. index .. "ButtonTextLocation"):SetText(
          zone);
    end
    button:Show();

    index = index + 1;
    if (index > MAX_CHARACTERS_DISPLAYED) then break end
  end

  if (numChars == 0) then
    CharacterSelectDeleteButton:Disable();
    CharSelectEnterWorldButton:Disable();
  else
    CharacterSelectDeleteButton:Enable();
    CharSelectEnterWorldButton:Enable();
  end

  CharacterSelect.createIndex = 0;
  CharSelectCreateCharacterButton:Hide();

  local connected = IsConnectedToServer();
  for i = index, MAX_CHARACTERS_DISPLAYED, 1 do
    local button = getglobal("CharSelectCharacterButton" .. index);
    if ((CharacterSelect.createIndex == 0) and
        (numChars < MAX_CHARACTERS_PER_REALM)) then
      CharacterSelect.createIndex = index;
      if (connected) then
        -- If can create characters position and show the create button
        CharSelectCreateCharacterButton:SetID(index);
        -- CharSelectCreateCharacterButton:SetPoint("TOP", button, "TOP", 0, -5);
        CharSelectCreateCharacterButton:Show();
      end
    end
    button:Hide();
    index = index + 1;
  end

  if (numChars == 0) then
    CharacterSelect.selectedIndex = 0;
    return;
  end

  if (CharacterSelect.selectLast == 1) then
    CharacterSelect.selectLast = 0;
    CharacterSelect_SelectCharacter(numChars, 1);
    return;
  end

  if ((CharacterSelect.selectedIndex == 0) or
      (CharacterSelect.selectedIndex > numChars)) then
    CharacterSelect.selectedIndex = 1;
  end
  CharacterSelect_SelectCharacter(CharacterSelect.selectedIndex, 1);
end

function CharacterSelect_OnChar() end

function CharacterSelectButton_OnClick()
  local id = this:GetID();
  if (id ~= CharacterSelect.selectedIndex) then
    CharacterSelect_SelectCharacter(id);
  end
end

function CharacterSelectButton_OnDoubleClick()
  local id = this:GetID();
  if (id ~= CharacterSelect.selectedIndex) then
    CharacterSelect_SelectCharacter(id);
  end
  CharacterSelect_EnterWorld();
end

function CharacterSelect_TabResize()
  local buttonMiddle = getglobal(this:GetName() .. "Middle");
  local buttonMiddleDisabled = getglobal(this:GetName() .. "MiddleDisabled");
  local width = this:GetTextWidth() - 8;
  local leftWidth = getglobal(this:GetName() .. "Left"):GetWidth();
  buttonMiddle:SetWidth(width);
  buttonMiddleDisabled:SetWidth(width);
  this:SetWidth(width + (2 * leftWidth));
end

function CharacterSelect_SelectCharacter(id, noCreate)
  if (id == CharacterSelect.createIndex) then
    if (not noCreate) then
      PlaySound("gsCharacterSelectionCreateNew");
      -- ResetRaceSelect();
      -- UpdateSelectedRace(nil);
      SetGlueScreen("charcreate");
    end
  else
    local name, race, class, level, zone, fileString = GetCharacterInfo(id);

    if (fileString ~= CharacterSelect.currentModel) then
      CharacterSelect.currentModel = fileString;
      SetBackgroundModel(CharacterSelect, fileString);
    end
    SelectCharacter(id);
  end
end

function CharacterDeleteDialog_OnShow()
  local name, race, class, level = GetCharacterInfo(
                                       CharacterSelect.selectedIndex);
  CharacterDeleteText1:SetText(format(TEXT(CONFIRM_CHAR_DELETE), name, level,
                                      class));
  CharacterDeleteBackground:SetHeight(16 + CharacterDeleteText1:GetHeight() +
                                          CharacterDeleteText2:GetHeight() + 23 +
                                          CharacterDeleteEditBox:GetHeight() + 8 +
                                          CharacterDeleteButton1:GetHeight() +
                                          16);
  CharacterDeleteButton1:Disable();
end

function CharacterSelect_EnterWorld()
  PlaySound("gsCharacterSelectionEnterWorld");
  Autologin_EnterWorld();
end

function CharacterSelect_Exit()
  PlaySound("gsCharacterSelectionExit");
  DisconnectFromServer();
  SetGlueScreen("login");
end

function CharacterSelect_AccountOptions()
  PlaySound("gsCharacterSelectionAcctOptions");
end

function CharacterSelect_TechSupport()
  PlaySound("gsCharacterSelectionAcctOptions");
  LaunchURL(TEXT(TECH_SUPPORT_URL));
end

function CharacterSelect_Delete()
  PlaySound("gsCharacterSelectionDelCharacter");
  if (CharacterSelect.selectedIndex > 0) then CharacterDeleteDialog:Show(); end
end

function CharacterSelect_ChangeRealm()
  PlaySound("gsLoginChangeRealmSelect");
  RequestRealmList(1);
end

function CharacterSelectFrame_OnMouseDown(button)
  if (button == "LeftButton") then
    CHARACTER_SELECT_ROTATION_START_X = GetCursorPosition();
    CHARACTER_SELECT_INITIAL_FACING = GetCharacterSelectFacing();
  end
end

function CharacterSelectFrame_OnMouseUp(button)
  if (button == "LeftButton") then CHARACTER_SELECT_ROTATION_START_X = nil end
end

function CharacterSelectFrame_OnUpdate()
  if (CHARACTER_SELECT_ROTATION_START_X) then
    local x = GetCursorPosition();
    local diff = (x - CHARACTER_SELECT_ROTATION_START_X) *
                     CHARACTER_ROTATION_CONSTANT;
    CHARACTER_SELECT_ROTATION_START_X = GetCursorPosition();
    SetCharacterSelectFacing(GetCharacterSelectFacing() + diff);
  end
end

function CharacterSelectRotateRight_OnUpdate()
  if (this:GetButtonState() == "PUSHED") then
    SetCharacterSelectFacing(GetCharacterSelectFacing() +
                                 CHARACTER_FACING_INCREMENT);
  end
end

function CharacterSelectRotateLeft_OnUpdate()
  if (this:GetButtonState() == "PUSHED") then
    SetCharacterSelectFacing(GetCharacterSelectFacing() -
                                 CHARACTER_FACING_INCREMENT);
  end
end

function CharacterSelect_ManageAccount()
  PlaySound("gsCharacterSelectionAcctOptions");
  LaunchURL(TEXT(AUTH_NO_TIME_URL));
end
