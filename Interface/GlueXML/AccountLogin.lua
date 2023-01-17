FADE_IN_TIME = 2;
DEFAULT_TOOLTIP_COLOR = { 0.8, 0.8, 0.8, 0.09, 0.09, 0.09 };
MAX_PIN_LENGTH = 10;

Autologin_Table = {}
Autologin_SelectedIdx = nil;

function Autologin_Load()
  Autologin_Table = {};
  for name, password, character in string.gfind(GetSavedAccountName(),
                                                "(%S+) (%S+) (%S+);") do
    table.insert(Autologin_Table,
                 { name = name, password = password, character = character });
  end
end

function Autologin_Save(name, password)
  -- Add/update name and password in table
  if (name ~= nil and name ~= "" and password ~= nil and password ~= "") then
    local exists = false;
    for i = 1, table.getn(Autologin_Table) do
      if (Autologin_Table[i].name == name) then
        exists = true;
        Autologin_Table[i].password = password;
      end
    end
    if (not exists) then
      table.insert(Autologin_Table,
                   { name = name, password = password, character = "-" });
    end
  end

  -- If table is empty, reset saved var
  if (table.getn(Autologin_Table) == 0) then
    SetSavedAccountName('');
    return;
  end

  -- Serialize table to saved var
  local savedVar = "";
  for i = 1, table.getn(Autologin_Table) do
    savedVar = savedVar .. Autologin_Table[i].name .. ' ' ..
                   Autologin_Table[i].password .. ' ' ..
                   Autologin_Table[i].character .. ';';
  end
  SetSavedAccountName(savedVar);
end

function Autologin_SelectAccount(idx)
  AccountLoginAccountEdit:SetText(Autologin_Table[idx].name);
  AccountLoginPasswordEdit:SetText(Autologin_Table[idx].password);
end

function Autologin_OnNameUpdate(name)
  local idx;
  for i = 1, table.getn(Autologin_Table) do
    if (Autologin_Table[i].name == name) then
      getglobal("AutologinAccountButton" .. i):LockHighlight();
      idx = i;
    else
      getglobal("AutologinAccountButton" .. i):UnlockHighlight();
    end
  end
  Autologin_SelectedIdx = idx;
end

function Autologin_UpdateUI()
  for i = 1, table.getn(Autologin_Table) do
    local r = Autologin_Table[i];
    getglobal("AutologinAccountButton" .. i):Show();
    getglobal("AutologinAccountButton" .. i .. "ButtonTextName"):SetText(r.name);
    getglobal("AutologinAccountButton" .. i .. "ButtonTextPassword"):SetText(
        'Password: ' .. string.rep("*", string.len(r.password)));

    if (r.character == '-') then
      getglobal("AutologinAccountButton" .. i .. "ButtonTextCharacter"):SetText(
          "");
    else
      getglobal("AutologinAccountButton" .. i .. "ButtonTextCharacter"):SetText(
          'Character: ' .. r.character);
    end
  end
  for i = table.getn(Autologin_Table) + 1, 9 do
    getglobal("AutologinAccountButton" .. i):Hide();
  end
end

function Autologin_OnLogin()
  local name = AccountLoginAccountEdit:GetText();
  local password = AccountLoginPasswordEdit:GetText();

  -- Autologin OnLogin
  Autologin_Save(name, password);
  Autologin_OnNameUpdate(name);
  DefaultServerLogin(name, password);
  Autologin_Load();
  Autologin_UpdateUI();
end

function AutologinAccountButton_OnClick() Autologin_SelectAccount(this:GetID()); end

function AutologinAccountButton_OnDoubleClick()
  Autologin_SelectAccount(this:GetID());
  AccountLogin_Login();
end

function Autologin_RemoveAccount()
  if (not Autologin_SelectedIdx) then return end
  table.remove(Autologin_Table, Autologin_SelectedIdx);
  Autologin_Save();
  Autologin_UpdateUI();
  AccountLoginAccountEdit:SetText("");
  AccountLoginPasswordEdit:SetText("");
end

function Autologin_ClearCharacter()
  if (not Autologin_SelectedIdx) then return end

  Autologin_Table[Autologin_SelectedIdx].character = '-';
  Autologin_Save();
  Autologin_UpdateUI();
end

-- Vanilla code

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

  local accountName = GetSavedAccountName();

  -- Autologin OnShow
  Autologin_Load();
  if (table.getn(Autologin_Table) ~= 0) then Autologin_SelectAccount(1); end
  Autologin_UpdateUI();

  if (accountName == "") then
    AccountLogin_FocusAccountName();
  else
    AccountLogin_FocusPassword();
  end
end

function AccountLogin_FocusPassword() AccountLoginPasswordEdit:SetFocus(); end

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
