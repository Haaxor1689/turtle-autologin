-- Encryption key (this should be changed to something unique and kept secret)
local ENCRYPTION_KEY = "your_secret_key_here"

Autologin_Table = {}
Autologin_SelectedIdx = nil
Autologin_CurrentPage = 0
Autologin_PageSize = 4
Autologin_LimitReached = false
Autologin_CurrentAccount = ""
Autologin_AutoEnterWorldAsCharacter = false

FADE_IN_TIME = 2
DEFAULT_TOOLTIP_COLOR = { 0.8, 0.8, 0.8, 0.09, 0.09, 0.09 }
MAX_PIN_LENGTH = 10

-- Alphanumeric character set
local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

-- Function to find index of a character in CHARS
local function findIndex(char)
    for i = 1, string.len(CHARS) do
        if string.sub(CHARS, i, i) == char then
            return i
        end
    end
    return 1  -- Default to first character if not found
end

-- Simple substitution cipher using only alphanumeric characters
local function simpleCipher(str, key, encrypt)
    local result = ""
    local keyIndex = 1
    for i = 1, string.len(str) do
        local charIndex = findIndex(string.sub(str, i, i))
        local keyCharIndex = findIndex(string.sub(key, keyIndex, keyIndex))
        
        local newIndex
        if encrypt then
            newIndex = charIndex + keyCharIndex
            if newIndex > 62 then
                newIndex = newIndex - 62
            end
        else
            newIndex = charIndex - keyCharIndex
            if newIndex < 1 then
                newIndex = newIndex + 62
            end
        end
        
        result = result .. string.sub(CHARS, newIndex, newIndex)
        
        keyIndex = keyIndex + 1
        if keyIndex > string.len(key) then
            keyIndex = 1
        end
    end
    return result
end

-- Function to encrypt a string
local function encrypt(str)
    return simpleCipher(str, ENCRYPTION_KEY, true)
end

-- Function to decrypt a string
local function decrypt(str)
    return simpleCipher(str, ENCRYPTION_KEY, false)
end

function Autologin_Load()
    Autologin_Table = {}
    local val = GetSavedAccountName()
    for n, p, c in string.gfind(val, "(%S+) (%S+) *(%S*);") do
        if c == "" then 
            c = "-" 
        end
        table.insert(Autologin_Table, { name = n, password = p, character = c })
    end
end

function Autologin_Save(name, password)
    -- Encrypt the password before saving
    local encryptedPassword = encrypt(password)
    
    -- Add/update name and encrypted password in table
    if name and name ~= "" and encryptedPassword and encryptedPassword ~= "" then
        local exists = false
        for i = 1, table.getn(Autologin_Table) do
            if Autologin_Table[i].name == name then
                exists = true
                Autologin_Table[i].password = encryptedPassword
                break
            end
        end
        if not exists then
            table.insert(Autologin_Table, { name = name, password = encryptedPassword, character = "-" })
        end
    end

    -- If table is empty, reset saved var
    if table.getn(Autologin_Table) == 0 then
        SetSavedAccountName("")
        return
    end

    -- Serialize table to saved var
    local savedVar = ""
    for i = 1, table.getn(Autologin_Table) do
        local r = Autologin_Table[i]
        savedVar = savedVar .. r.name .. " " .. r.password
        if r.character == "-" then
            savedVar = savedVar .. ";"
        else
            savedVar = savedVar .. " " .. r.character .. ";"
        end
    end

    Autologin_LimitReached = string.len(savedVar) > 128
    SetSavedAccountName(savedVar)
end

function Autologin_SelectAccount(idx)
    local i = Autologin_CurrentPage * Autologin_PageSize + idx
    if Autologin_Table[i] then
        AccountLoginAccountEdit:SetText(Autologin_Table[i].name)
        AccountLoginPasswordEdit:SetText("") -- Don't set the password for security
    end
end

function Autologin_OnNameUpdate(name)
    Autologin_SelectedIdx = nil
    for i = 1, table.getn(Autologin_Table) do
        if Autologin_Table[i].name == name then 
            Autologin_SelectedIdx = i
            break
        end
    end
    if Autologin_SelectedIdx then
        Autologin_CurrentPage = math.floor((Autologin_SelectedIdx - 1) / Autologin_PageSize)
    end
    Autologin_UpdateUI()
end

function Autologin_UpdateUI()
    local skip = Autologin_CurrentPage * Autologin_PageSize
    for i = 1, Autologin_PageSize do
        local button = getglobal("AutologinAccountButton" .. i)
        button:UnlockHighlight()
        if skip + i > table.getn(Autologin_Table) then
            button:Hide()
        else
            local r = Autologin_Table[skip + i]
            button:Show()
            getglobal("AutologinAccountButton" .. i .. "ButtonTextName"):SetText(r.name)
            getglobal("AutologinAccountButton" .. i .. "ButtonTextPassword"):SetText("Password: ********")

            local characterText = getglobal("AutologinAccountButton" .. i .. "ButtonTextCharacter")
            if r.character == "-" then
                characterText:SetText("")
            else
                characterText:SetText("Character: " .. r.character)
            end

            if Autologin_SelectedIdx == skip + i then
                button:LockHighlight()
            end
        end
    end

    if Autologin_LimitReached then
        getglobal("AutologinSizeWarning"):Show()
    else
        getglobal("AutologinSizeWarning"):Hide()
    end
end

function Autologin_OnLogin()
    local name = AccountLoginAccountEdit:GetText()
    local password = AccountLoginPasswordEdit:GetText()

    -- Find the account and verify the password
    local accountFound = false
    for i = 1, table.getn(Autologin_Table) do
        if Autologin_Table[i].name == name then
            accountFound = true
            local decryptedPassword = decrypt(Autologin_Table[i].password)
            if decryptedPassword then
                if not Autologin_Table[i].character then
                    Autologin_AutoEnterWorldAsCharacter = false
                end
                DefaultServerLogin(name, decryptedPassword)
                Autologin_CurrentAccount = name
                break
            else
                DefaultServerLogin(name, password)
                return
            end
        end
    end

    if not accountFound then
        -- This is a new account, save it
        Autologin_Save(name, password)
    end

    Autologin_OnNameUpdate(name)
    Autologin_Load()
    Autologin_UpdateUI()
end

function AutologinAccountButton_OnClick()
    Autologin_SelectAccount(this:GetID())
end

function AutologinAccountButton_OnDoubleClick()
    Autologin_SelectAccount(this:GetID())
    AccountLogin_Login()
end

function Autologin_RemoveAccount()
    if not Autologin_SelectedIdx then return end

    table.remove(Autologin_Table, Autologin_SelectedIdx)
    Autologin_Save()
    AccountLoginAccountEdit:SetText("")
    AccountLoginPasswordEdit:SetText("")

    if Autologin_CurrentPage > 0 and Autologin_CurrentPage * Autologin_PageSize > table.getn(Autologin_Table) - 1 then
        Autologin_CurrentPage = Autologin_CurrentPage - 1
    end

    Autologin_UpdateUI()
end

function Autologin_ClearCharacter()
    if not Autologin_SelectedIdx then return end

    Autologin_Table[Autologin_SelectedIdx].character = "-"
    Autologin_Save()
    Autologin_UpdateUI()
end

function Autologin_NextPage()
    if (Autologin_CurrentPage + 1) * Autologin_PageSize <= table.getn(Autologin_Table) - 1 then
        Autologin_CurrentPage = Autologin_CurrentPage + 1
        Autologin_UpdateUI()
    end
end

function Autologin_PrevPage()
    if Autologin_CurrentPage > 0 then
        Autologin_CurrentPage = Autologin_CurrentPage - 1
        Autologin_UpdateUI()
    end
end

function AccountLogin_OnLoad()
    this:SetSequence(0)
    this:SetCamera(0)

    this:RegisterEvent("SHOW_SERVER_ALERT")
    this:RegisterEvent("SHOW_SURVEY_NOTIFICATION")

    local versionType, buildType, version, internalVersion, date = GetBuildInfo()
    AccountLoginVersion:SetText(format(TEXT(VERSION_TEMPLATE), versionType, version, internalVersion, buildType, date))

    -- Color edit box backdrops
    local backdropColor = DEFAULT_TOOLTIP_COLOR
    AccountLoginAccountEdit:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3])
    AccountLoginAccountEdit:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6])
    AccountLoginPasswordEdit:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3])
    AccountLoginPasswordEdit:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6])
end

function AccountLogin_OnShow()
    CurrentGlueMusic = "Sound\\Music\\GlueScreenMusic\\wow_main_theme.mp3"

    AcceptTOS()
    AcceptEULA()
    local serverName = GetServerName()
    if serverName then
        AccountLoginRealmName:SetText(serverName)
    else
        AccountLoginRealmName:Hide()
    end

    -- Autologin OnShow
    Autologin_Load()
    if table.getn(Autologin_Table) ~= 0 then 
        Autologin_SelectAccount(1)
    end
    Autologin_UpdateUI()

    if GetSavedAccountName() == "" then
        AccountLogin_FocusAccountName()
    else
        AccountLogin_FocusPassword()
    end
end

function AccountLogin_FocusPassword()
    AccountLoginPasswordEdit:SetFocus()
end

function AccountLogin_FocusAccountName()
    AccountLoginAccountEdit:SetFocus()
end

function AccountLogin_OnChar() end

function AccountLogin_OnKeyDown()
    if arg1 == "ESCAPE" then
        if ConnectionHelpFrame:IsVisible() then
            ConnectionHelpFrame:Hide()
            AccountLoginUI:Show()
        elseif SurveyNotificationFrame:IsVisible() then
            -- do nothing
        else
            AccountLogin_Exit()
        end
    elseif arg1 == "ENTER" then
        if not TOSAccepted() then
            return
        elseif TOSFrame:IsVisible() or ConnectionHelpFrame:IsVisible() then
            return
        elseif SurveyNotificationFrame:IsVisible() then
            AccountLogin_SurveyNotificationDone(1)
        end
        AccountLogin_Login()
    elseif arg1 == "PRINTSCREEN" then
        Screenshot()
    end
end

function AccountLogin_OnEvent(event)
    if event == "SHOW_SERVER_ALERT" then
        ServerAlertText:SetText(arg1)
        ServerAlertScrollFrame:UpdateScrollChildRect()
        ServerAlertFrame:Show()
    elseif event == "SHOW_SURVEY_NOTIFICATION" then
        AccountLogin_ShowSurveyNotification()
    end
end

function AccountLogin_Login()
    PlaySound("gsLogin")
    Autologin_OnLogin()
end

function AccountLogin_Turtle_Armory_Website()
    PlaySound("gsLoginNewAccount")
    LaunchURL(TURTLE_ARMORY_WEBSITE)
end

function AccountLogin_Turtle_Website()
    PlaySound("gsLoginNewAccount")
    LaunchURL(AUTH_TURTLE_WEBSITE)
end

function AccountLogin_Turtle_Knowledge_Database()
    PlaySound("gsLoginNewAccount")
    LaunchURL(TURTLE_KNOWLEDGE_DATABASE_WEBSITE)
end

function AccountLogin_Turtle_Community_Forum()
    PlaySound("gsLoginNewAccount")
    LaunchURL(TURTLE_COMMUNITY_FORUM_WEBSITE)
end

function AccountLogin_Turtle_Discord()
    PlaySound("gsLoginNewAccount")
    LaunchURL(TURTLE_DISCORD_WEBSITE)
end

function AccountLogin_Credits()
    if not GlueDialog:IsVisible() then
        PlaySound("gsTitleCredits")
        SetGlueScreen("credits")
    end
end

function AccountLogin_Cinematics()
    if not GlueDialog:IsVisible() then
        PlaySound("gsTitleIntroMovie")
        SetGlueScreen("movie")
    end
end

function AccountLogin_Options()
    PlaySound("gsTitleOptions")
end

function AccountLogin_Exit()
    PlaySound("gsTitleQuit")
    QuitGame()
end

function AccountLogin_ShowSurveyNotification()
    GlueDialog:Hide()
    AccountLoginUI:Hide()
    SurveyNotificationAccept:Enable()
    SurveyNotificationDecline:Enable()
    SurveyNotificationFrame:Show()
end

function AccountLogin_SurveyNotificationDone(accepted)
    SurveyNotificationFrame:Hide()
    SurveyNotificationAccept:Disable()
    SurveyNotificationDecline:Disable()
    SurveyNotificationDone(accepted)
    AccountLoginUI:Show()
end

-- Virtual keypad functions
function VirtualKeypadFrame_OnEvent(event)
    if event == "PLAYER_ENTER_PIN" then
        for i = 1, 10 do
            getglobal("VirtualKeypadButton" .. i):SetText(getglobal("arg" .. i))
        end
    end
    -- Randomize location to prevent hacking (yeah right)
    local xPadding = 5
    local yPadding = 10
    local xPos = random(xPadding, GlueParent:GetWidth() - VirtualKeypadFrame:GetWidth() - xPadding)
    local yPos = random(yPadding, GlueParent:GetHeight() - VirtualKeypadFrame:GetHeight() - yPadding)
    VirtualKeypadFrame:SetPoint("TOPLEFT", GlueParent, "TOPLEFT", xPos, -yPos)

    VirtualKeypadFrame:Show()
    VirtualKeypad_UpdateButtons()
end

function VirtualKeypadButton_OnClick()
    local text = VirtualKeypadText:GetText()
    if not text then text = "" end
    VirtualKeypadText:SetText(text .. "*")
    VirtualKeypadFrame.PIN = VirtualKeypadFrame.PIN .. this:GetID()
    VirtualKeypad_UpdateButtons()
end

function VirtualKeypadOkayButton_OnClick()
    local PIN = VirtualKeypadFrame.PIN
    local numNumbers = strlen(PIN)
    local pinNumber = {}
    for i = 1, MAX_PIN_LENGTH do
        if i <= numNumbers then
            pinNumber[i] = strsub(PIN, i, i)
        else
            pinNumber[i] = nil
        end
    end
    PINEntered(pinNumber[1], pinNumber[2], pinNumber[3], pinNumber[4],
               pinNumber[5], pinNumber[6], pinNumber[7], pinNumber[8],
               pinNumber[9], pinNumber[10])
    VirtualKeypadFrame:Hide()
end

function VirtualKeypad_UpdateButtons()
    local numNumbers = strlen(VirtualKeypadFrame.PIN)
    if numNumbers >= 4 and numNumbers <= MAX_PIN_LENGTH then
        VirtualKeypadOkayButton:Enable()
    else
        VirtualKeypadOkayButton:Disable()
    end
    if numNumbers == 0 then
        VirtualKeypadBackButton:Disable()
    else
        VirtualKeypadBackButton:Enable()
    end
    if numNumbers >= MAX_PIN_LENGTH then
        for i = 1, MAX_PIN_LENGTH do
            getglobal("VirtualKeypadButton" .. i):Disable()
        end
    else
        for i = 1, MAX_PIN_LENGTH do
            getglobal("VirtualKeypadButton" .. i):Enable()
        end
    end
end
