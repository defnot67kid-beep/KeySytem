--==================================================--
-- RSQ KEY SYSTEM — PREMIUM EDITION (FIXED)
--==================================================--

-- SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local MarketplaceService = game:GetService("MarketplaceService")
local player = Players.LocalPlayer
local USER_ID = tostring(player.UserId)
local USER_NAME = player.Name
local PLACE_ID = game.PlaceId

--==================================================--
-- CONFIG
--==================================================--
local JSONBIN_URL = "https://api.jsonbin.io/v3/b/6952cbcdd0ea881f4047f5ff/latest"
local JSON_KEY = "$2a$10$f6r4B1gP.MfB1k49kq2m7eEzyesjD9KWP5zCa6QtJKW5ZBhL1M0/O"
local GET_KEY_URL = "https://realscripts-q.github.io/KEY-JSONHandler/"
local DISCORD_WEBHOOK = "https://webhook.lewisakura.moe/api/webhooks/1453515343833338017/7VwwcpKDpSvIYr0PA3Ceh8YgMwIEba47CoyISHCZkvdaF2hUsvyUYw3zNV_TbYyDFTMy"

local SCRIPT_URLS = {
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/D.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/I.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/N.lua",
}
local CHECK_INTERVAL = 1

-- File saving paths
local LOCAL_FOLDER = "RSQ_KeySystem"
local KEY_STATUS_FILE = "key_status.json"

-- GUI Colors
local COLOR_PALETTE = {
    primary = Color3.fromRGB(79, 124, 255),
    secondary = Color3.fromRGB(124, 77, 255),
    accent = Color3.fromRGB(0, 200, 255),
    success = Color3.fromRGB(46, 204, 113),
    warning = Color3.fromRGB(255, 140, 0),
    danger = Color3.fromRGB(255, 59, 48),
    dark = {
        bg1 = Color3.fromRGB(10, 12, 20),
        bg2 = Color3.fromRGB(15, 18, 30),
        bg3 = Color3.fromRGB(20, 24, 40),
        bg4 = Color3.fromRGB(25, 30, 50)
    },
    light = {
        text = Color3.fromRGB(240, 240, 245),
        subtext = Color3.fromRGB(180, 180, 190),
        border = Color3.fromRGB(60, 65, 85)
    }
}

-- Animation Settings
local ANIMATION_SETTINGS = {
    entryDuration = 0.5,
    exitDuration = 0.4,
    hoverDuration = 0.2,
    pressDuration = 0.1,
    glowPulseSpeed = 3
}

--==================================================--
-- STATE & PRE-FETCH
--==================================================--
local CurrentKey = nil
local KeyActive = false
local LastNotifTime = 0
local CachedData = nil
local GamesList = {}
local IsGuiOpen = false
local OpenButton = nil
local CurrentGUI = nil
local IsInitializing = true
local HasShownGUIAlready = false

-- Function to get data folder
local function getDataFolder()
    if writefile and isfolder then
        if not isfolder(LOCAL_FOLDER) then
            makefolder(LOCAL_FOLDER)
        end
        return LOCAL_FOLDER
    end
    return nil
end

-- Function to save key status
local function saveKeyStatus()
    local folder = getDataFolder()
    if not folder then return end
    
    local status = {
        key = CurrentKey,
        active = KeyActive,
        userId = USER_ID,
        timestamp = os.time()
    }
    
    local success, err = pcall(function()
        writefile(folder .. "/" .. KEY_STATUS_FILE, HttpService:JSONEncode(status))
    end)
    
    if not success then
        warn("[RSQ] Failed to save key status:", err)
    end
end

-- Function to load key status
local function loadKeyStatus()
    local folder = getDataFolder()
    if not folder then return false end
    
    local filePath = folder .. "/" .. KEY_STATUS_FILE
    
    if not isfile(filePath) then
        return false
    end
    
    local success, data = pcall(function()
        local content = readfile(filePath)
        return HttpService:JSONDecode(content)
    end)
    
    if success and data and data.userId == USER_ID then
        if data.active and data.key then
            CurrentKey = data.key
            KeyActive = true
            return true
        end
    end
    
    return false
end

-- Function to clear saved key status
local function clearKeyStatus()
    local folder = getDataFolder()
    if not folder then return end
    
    local filePath = folder .. "/" .. KEY_STATUS_FILE
    
    if isfile(filePath) then
        delfile(filePath)
    end
end

-- Function to check if GUI is already loaded
local function isGUILoaded()
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" then
            return true
        end
    end
    
    if player.PlayerGui then
        for _, gui in pairs(player.PlayerGui:GetChildren()) do
            if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" then
                return true
            end
        end
    end
    
    return false
end

-- Function to create simple open button
local function createOpenButton()
    if OpenButton and OpenButton.Parent then
        OpenButton:Destroy()
        OpenButton = nil
    end
    
    OpenButton = Instance.new("ScreenGui")
    OpenButton.Name = "RSQ_OpenButton"
    OpenButton.IgnoreGuiInset = true
    OpenButton.ResetOnSpawn = false
    OpenButton.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    OpenButton.Parent = CoreGui
    
    local button = Instance.new("TextButton", OpenButton)
    button.Name = "ToggleButton"
    button.Size = UDim2.new(0, 50, 0, 50)
    button.Position = UDim2.new(1, -60, 0, 20)
    button.Text = IsGuiOpen and "✕" or "☰"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 20
    button.TextColor3 = COLOR_PALETTE.light.text
    button.BackgroundColor3 = COLOR_PALETTE.primary
    button.BackgroundTransparency = 0.2
    button.BorderSizePixel = 0
    Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
    
    -- Add border
    local border = Instance.new("UIStroke", button)
    border.Color = COLOR_PALETTE.primary
    border.Thickness = 2
    border.Transparency = 0.3
    
    -- Simple toggle function
    button.MouseButton1Click:Connect(function()
        if IsGuiOpen then
            -- Close all RSQ GUIs
            for _, gui in pairs(CoreGui:GetChildren()) do
                if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or 
                   gui.Name:find("RSQ_TeleportConfirm") or gui.Name:find("RSQ_Notifications") then
                    gui:Destroy()
                end
            end
            
            IsGuiOpen = false
            CurrentGUI = nil
            button.Text = "☰"
            button.BackgroundColor3 = COLOR_PALETTE.primary
        else
            -- Check if GUI is already loaded
            if isGUILoaded() then
                createNotify("⚠️ GUI is already open!", COLOR_PALETTE.warning)
                return
            end
            
            -- Open appropriate GUI
            if KeyActive and CurrentKey then
                showAdvancedGamesGUI()
            else
                showKeyGUI()
            end
            IsGuiOpen = true
            button.Text = "✕"
            button.BackgroundColor3 = COLOR_PALETTE.danger
        end
    end)
    
    -- Hover effects
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(ANIMATION_SETTINGS.hoverDuration), {
            Size = UDim2.new(0, 55, 0, 55),
            BackgroundTransparency = 0
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(ANIMATION_SETTINGS.hoverDuration), {
            Size = UDim2.new(0, 50, 0, 50),
            BackgroundTransparency = 0.2
        }):Play()
    end)
    
    -- Make draggable
    local dragging = false
    local dragStart, startPos
    
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X,
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Entry animation
    button.Position = UDim2.new(1, 100, 0, 20)
    TweenService:Create(button, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -60, 0, 20)
    }):Play()
    
    return OpenButton
end

-- Function to create close button
local function createCloseButton(parent, onClose)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0, 5)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = COLOR_PALETTE.light.text
    closeBtn.BackgroundColor3 = COLOR_PALETTE.danger
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        if onClose then
            onClose()
        end
    end)
    
    closeBtn.Parent = parent
    return closeBtn
end

-- Function to make frame draggable
local function makeDraggable(frame, dragHandle)
    local dragging = false
    local dragStart, startPos
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X,
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Function to fetch data with better error handling
local function fetchDataWithRetry()
    for attempt = 1, 3 do
        local ok, res = pcall(function()
            local response = game:HttpGet(JSONBIN_URL, true, {["X-Master-Key"] = JSON_KEY})
            return HttpService:JSONDecode(response)
        end)
        
        if ok and res and res.record then
            CachedData = res.record
            GamesList = {}
            
            if res.record.games and type(res.record.games) == "table" then
                for _, game in pairs(res.record.games) do
                    if type(game) == "table" and game.id and game.name then
                        table.insert(GamesList, game)
                    end
                end
                print("[RSQ] Loaded " .. #GamesList .. " games")
            end
            return CachedData
        end
        
        warn("[RSQ] Fetch attempt " .. attempt .. " failed")
        task.wait(1)
    end
    return CachedData
end

-- Start downloading the database immediately
task.spawn(function()
    fetchDataWithRetry()
end)

--==================================================--
-- WEBHOOK SYSTEM
--==================================================--
local function sendWebhook(type, key, expires)
    if not DISCORD_WEBHOOK or DISCORD_WEBHOOK == "" then return end
    
    local thumb = "https://www.roblox.com/headshot-thumbnail/image?userId="..USER_ID.."&width=420&height=420&format=png"
    local time = os.date("!%Y-%m-%dT%H:%M:%SZ")
    
    local payload = {
        ["embeds"] = {{
            ["timestamp"] = time,
            ["thumbnail"] = { ["url"] = thumb }
        }}
    }

    if type == "JOIN" then
        payload.embeds[1].title = "📥 Player Joined System"
        payload.embeds[1].color = 16776960 
        payload.embeds[1].description = string.format("**User:** %s\n**ID:** %s\n**Game ID:** %s", USER_NAME, USER_ID, tostring(PLACE_ID))
    elseif type == "REDEEM" then
        local expireText = (expires == "INF") and "♾️ Permanent" or os.date("%Y-%m-%d %H:%M:%S", expires)
        payload.embeds[1].title = "🔑 Key Authenticated"
        payload.embeds[1].color = 4947199 
        payload.embeds[1].fields = {
            { ["name"] = "Player", ["value"] = USER_NAME .. " ("..USER_ID..")", ["inline"] = true },
            { ["name"] = "Key Used", ["value"] = "```"..key.."```", ["inline"] = false },
            { ["name"] = "Expires", ["value"] = expireText, ["inline"] = true }
        }
    end

    pcall(function()
        HttpService:PostAsync(DISCORD_WEBHOOK, HttpService:JSONEncode(payload))
    end)
end

sendWebhook("JOIN")

--==================================================--
-- HELPERS
--==================================================--
local function string_trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function fetchData()
    return fetchDataWithRetry()
end

local function kickBanned(reason)
    pcall(function() setclipboard(GET_KEY_URL) end)
    local kickMsg = "🛑 [RSQ RESTRICTION]\n\nReason: " .. (reason or "Blacklisted")
    while true do player:Kick(kickMsg) task.wait(0.5) end
end

-- Simple notification function
local function createNotify(msg, color)
    local notifyGui = Instance.new("ScreenGui", CoreGui)
    notifyGui.Name = "RSQ_Notifications_" .. tostring(math.random(1, 1000))
    notifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local frame = Instance.new("Frame", notifyGui)
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(1, 10, 0.8, 0)
    frame.BackgroundColor3 = COLOR_PALETTE.dark.bg3
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local accent = Instance.new("Frame", frame)
    accent.Size = UDim2.new(0, 5, 1, 0)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.Text = msg
    label.TextColor3 = COLOR_PALETTE.light.text
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left

    frame:TweenPosition(UDim2.new(1, -310, 0.8, 0), "Out", "Back", 0.5)
    task.delay(5, function()
        pcall(function()
            frame:TweenPosition(UDim2.new(1, 10, 0.8, 0), "In", "Sine", 0.5)
            task.wait(0.5)
            notifyGui:Destroy()
        end)
    end)
end

-- Function to show teleport confirmation
local function showTeleportConfirmation(gameId, gameName)
    local teleportGui = Instance.new("ScreenGui", CoreGui)
    teleportGui.Name = "RSQ_TeleportConfirm"
    teleportGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local overlay = Instance.new("Frame", teleportGui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    
    local confirmFrame = Instance.new("Frame", teleportGui)
    confirmFrame.Size = UDim2.new(0, 350, 0, 200)
    confirmFrame.Position = UDim2.new(0.5, -175, 0.5, -100)
    confirmFrame.BackgroundColor3 = COLOR_PALETTE.dark.bg3
    confirmFrame.BackgroundTransparency = 0.1
    confirmFrame.BorderSizePixel = 0
    Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(confirmFrame, confirmFrame)
    
    -- Title bar with close button
    local titleBar = Instance.new("Frame", confirmFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = COLOR_PALETTE.dark.bg4
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "⚠️ Teleport Required"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = COLOR_PALETTE.warning
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close button
    createCloseButton(titleBar, function()
        createNotify("Teleport cancelled", COLOR_PALETTE.danger)
        teleportGui:Destroy()
    end)
    
    local message = Instance.new("TextLabel", confirmFrame)
    message.Size = UDim2.new(1, -20, 0, 80)
    message.Position = UDim2.new(0, 10, 0, 40)
    message.Text = "Script '" .. gameName .. "' requires Game ID: " .. gameId .. "\n\nDo you want to teleport to the correct game?"
    message.Font = Enum.Font.Gotham
    message.TextSize = 14
    message.TextColor3 = COLOR_PALETTE.light.text
    message.BackgroundTransparency = 1
    message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Buttons container
    local buttonContainer = Instance.new("Frame", confirmFrame)
    buttonContainer.Size = UDim2.new(1, -20, 0, 50)
    buttonContainer.Position = UDim2.new(0, 10, 1, -60)
    buttonContainer.BackgroundTransparency = 1
    
    -- Yes button
    local yesBtn = Instance.new("TextButton", buttonContainer)
    yesBtn.Size = UDim2.new(0.48, -5, 1, 0)
    yesBtn.Position = UDim2.new(0, 0, 0, 0)
    yesBtn.Text = "✅ YES, Teleport"
    yesBtn.Font = Enum.Font.GothamBold
    yesBtn.TextSize = 14
    yesBtn.TextColor3 = COLOR_PALETTE.light.text
    yesBtn.BackgroundColor3 = COLOR_PALETTE.success
    yesBtn.BackgroundTransparency = 0.2
    yesBtn.BorderSizePixel = 0
    Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 8)
    
    -- No button
    local noBtn = Instance.new("TextButton", buttonContainer)
    noBtn.Size = UDim2.new(0.48, -5, 1, 0)
    noBtn.Position = UDim2.new(0.52, 5, 0, 0)
    noBtn.Text = "❌ NO, Cancel"
    noBtn.Font = Enum.Font.GothamBold
    noBtn.TextSize = 14
    noBtn.TextColor3 = COLOR_PALETTE.light.text
    noBtn.BackgroundColor3 = COLOR_PALETTE.danger
    noBtn.BackgroundTransparency = 0.2
    noBtn.BorderSizePixel = 0
    Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 8)
    
    -- Button events
    yesBtn.MouseButton1Click:Connect(function()
        createNotify("Teleporting to Game ID: " .. gameId, COLOR_PALETTE.success)
        teleportGui:Destroy()
        
        local gameIdNumber = tonumber(gameId)
        if gameIdNumber then
            local success, err = pcall(function()
                TeleportService:Teleport(gameIdNumber, player)
            end)
            
            if not success then
                createNotify("❌ Teleport failed: " .. tostring(err), COLOR_PALETTE.danger)
            end
        else
            createNotify("❌ Invalid Game ID format", COLOR_PALETTE.danger)
        end
    end)
    
    noBtn.MouseButton1Click:Connect(function()
        createNotify("Teleport cancelled", COLOR_PALETTE.danger)
        teleportGui:Destroy()
    end)
    
    -- Animation
    confirmFrame.BackgroundTransparency = 1
    TweenService:Create(confirmFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
end

--==================================================--
-- VALIDATION LOGIC
--==================================================--
local function validate(keyToVerify, skipFetch)
    local data = skipFetch and CachedData or fetchData()
    if not data then return false, "Connection Error" end

    if data.bans and (data.bans[USER_NAME] or data.bans[USER_ID]) then
        kickBanned((data.bans[USER_NAME] or data.bans[USER_ID]).reason)
        return false, "Banned"
    end

    if data.notifications and data.notifications[USER_NAME] then
        local n = data.notifications[USER_NAME]
        if n.time > LastNotifTime then
            LastNotifTime = n.time
            if n.type == "DELETED" then createNotify("⚠️ Admin has revoked your key!", COLOR_PALETTE.danger)
            elseif n.type == "RENEWED" then createNotify("✅ Key renewed by Admin!", COLOR_PALETTE.success)
            elseif n.type == "INFINITE" then createNotify("💎 Key is now PERMANENT!", COLOR_PALETTE.accent)
            end
        end
    end

    if not keyToVerify then return false, "" end

    local entry = data.keys and data.keys[keyToVerify]
    if not entry then return false, "❌ Invalid Key" end
    if tostring(entry.rbx) ~= USER_ID then return false, "❌ ID Mismatch" end
    if entry.exp ~= "INF" and os.time() > tonumber(entry.exp) then return false, "❌ Expired" end

    return true, entry
end

--==================================================--
-- ADVANCED GAMES GUI (SMALLER SIZE)
--==================================================--
local function showAdvancedGamesGUI()
    if isGUILoaded() then
        createNotify("⚠️ GUI is already open!", COLOR_PALETTE.warning)
        return
    end
    
    if CurrentGUI and CurrentGUI.Parent then
        CurrentGUI:Destroy()
        CurrentGUI = nil
    end
    
    IsGuiOpen = true
    HasShownGUIAlready = true
    
    if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
        OpenButton.ToggleButton.Text = "✕"
        OpenButton.ToggleButton.BackgroundColor3 = COLOR_PALETTE.danger
    end
    
    print("[RSQ] Showing Advanced Games GUI")
    
    -- Create main GUI
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_AdvancedGamesGUI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui
    CurrentGUI = gui

    -- Main container (smaller size)
    local mainFrame = Instance.new("Frame", gui)
    mainFrame.Size = UDim2.new(0, 400, 0, 450) -- Smaller size
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -225)
    mainFrame.BackgroundColor3 = COLOR_PALETTE.dark.bg2
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(mainFrame, mainFrame)
    
    -- Title bar
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = COLOR_PALETTE.dark.bg4
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "🎮 RSQ GAMES LIBRARY"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = COLOR_PALETTE.primary
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close button
    createCloseButton(titleBar, function()
        IsGuiOpen = false
        if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
            OpenButton.ToggleButton.Text = "☰"
            OpenButton.ToggleButton.BackgroundColor3 = COLOR_PALETTE.primary
        end
        gui:Destroy()
        CurrentGUI = nil
    end)

    -- Content area
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 40)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ClipsDescendants = true

    -- Search bar
    local searchContainer = Instance.new("Frame", contentFrame)
    searchContainer.Size = UDim2.new(1, 0, 0, 35)
    searchContainer.BackgroundTransparency = 1
    
    local searchBox = Instance.new("TextBox", searchContainer)
    searchBox.Size = UDim2.new(1, 0, 1, 0)
    searchBox.PlaceholderText = "🔍 Search games..."
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.TextColor3 = COLOR_PALETTE.light.text
    searchBox.BackgroundColor3 = COLOR_PALETTE.dark.bg4
    searchBox.BackgroundTransparency = 0.1
    searchBox.BorderSizePixel = 0
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 8)
    
    -- Games container
    local gamesContainer = Instance.new("Frame", contentFrame)
    gamesContainer.Size = UDim2.new(1, 0, 1, -45)
    gamesContainer.Position = UDim2.new(0, 0, 0, 40)
    gamesContainer.BackgroundTransparency = 1
    
    -- Scrolling frame
    local scrollFrame = Instance.new("ScrollingFrame", gamesContainer)
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarImageColor3 = COLOR_PALETTE.primary
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    -- Games list layout
    local gamesListLayout = Instance.new("UIListLayout", scrollFrame)
    gamesListLayout.Padding = UDim.new(0, 8)
    gamesListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    -- VARIABLES FOR GAME DATA
    local currentGameData = nil
    local currentScriptsFrame = nil
    
    -- Function to create game card
    local function createGameCard(gameData, parent)
        local card = Instance.new("Frame", parent)
        card.Size = UDim2.new(1, 0, 0, 70) -- Smaller card
        card.BackgroundColor3 = COLOR_PALETTE.dark.bg4
        card.BackgroundTransparency = 0.2
        card.BorderSizePixel = 0
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
        
        -- Border
        local border = Instance.new("UIStroke", card)
        border.Color = COLOR_PALETTE.light.border
        border.Thickness = 1
        border.Transparency = 0.5
        
        -- Game icon
        local icon = Instance.new("TextLabel", card)
        icon.Size = UDim2.new(0, 40, 0, 40)
        icon.Position = UDim2.new(0, 10, 0.5, -20)
        icon.Text = "🎯"
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 20
        icon.TextColor3 = COLOR_PALETTE.primary
        icon.BackgroundTransparency = 1
        
        -- Game info
        local infoFrame = Instance.new("Frame", card)
        infoFrame.Size = UDim2.new(0.5, 0, 1, 0)
        infoFrame.Position = UDim2.new(0, 60, 0, 0)
        infoFrame.BackgroundTransparency = 1
        
        local gameName = Instance.new("TextLabel", infoFrame)
        gameName.Size = UDim2.new(1, -10, 0, 25)
        gameName.Position = UDim2.new(0, 0, 0, 10)
        gameName.Text = gameData.name
        gameName.Font = Enum.Font.GothamBold
        gameName.TextSize = 13
        gameName.TextColor3 = COLOR_PALETTE.light.text
        gameName.TextXAlignment = Enum.TextXAlignment.Left
        gameName.BackgroundTransparency = 1
        
        local gameId = Instance.new("TextLabel", infoFrame)
        gameId.Size = UDim2.new(1, -10, 0, 20)
        gameId.Position = UDim2.new(0, 0, 0, 35)
        gameId.Text = "🆔 ID: " .. gameData.id
        gameId.Font = Enum.Font.Gotham
        gameId.TextSize = 11
        gameId.TextColor3 = COLOR_PALETTE.light.subtext
        gameId.TextXAlignment = Enum.TextXAlignment.Left
        gameId.BackgroundTransparency = 1
        
        -- Scripts button
        local scriptsBtn = Instance.new("TextButton", card)
        scriptsBtn.Size = UDim2.new(0, 100, 0, 30)
        scriptsBtn.Position = UDim2.new(1, -110, 0.5, -15)
        scriptsBtn.Text = "📜 View Scripts"
        scriptsBtn.Font = Enum.Font.GothamBold
        scriptsBtn.TextSize = 11
        scriptsBtn.TextColor3 = COLOR_PALETTE.light.text
        scriptsBtn.BackgroundColor3 = COLOR_PALETTE.primary
        scriptsBtn.BackgroundTransparency = 0.2
        scriptsBtn.BorderSizePixel = 0
        Instance.new("UICorner", scriptsBtn).CornerRadius = UDim.new(0, 6)
        
        local btnBorder = Instance.new("UIStroke", scriptsBtn)
        btnBorder.Color = COLOR_PALETTE.primary
        btnBorder.Thickness = 1
        btnBorder.Transparency = 0.3
        
        -- Button events
        scriptsBtn.MouseButton1Click:Connect(function()
            print("[RSQ] View Scripts clicked for:", gameData.name)
            showGameScripts(gameData)
        end)
        
        -- Hover effects
        card.MouseEnter:Connect(function()
            TweenService:Create(card, TweenInfo.new(ANIMATION_SETTINGS.hoverDuration), {
                BackgroundTransparency = 0.1
            }):Play()
            TweenService:Create(border, TweenInfo.new(ANIMATION_SETTINGS.hoverDuration), {
                Transparency = 0
            }):Play()
        end)
        
        card.MouseLeave:Connect(function()
            TweenService:Create(card, TweenInfo.new(ANIMATION_SETTINGS.hoverDuration), {
                BackgroundTransparency = 0.2
            }):Play()
            TweenService:Create(border, TweenInfo.new(ANIMATION_SETTINGS.hoverDuration), {
                Transparency = 0.5
            }):Play()
        end)
        
        return card
    end
    
    -- Function to show scripts for a specific game
    local function showGameScripts(gameData)
        print("[RSQ] showGameScripts called for:", gameData.name)
        
        -- Store current game data
        currentGameData = gameData
        
        -- Hide games list
        scrollFrame.Visible = false
        
        -- Remove existing scripts frame if it exists
        if currentScriptsFrame then
            currentScriptsFrame:Destroy()
            currentScriptsFrame = nil
        end
        
        -- Create NEW scripts frame
        currentScriptsFrame = Instance.new("Frame", gamesContainer)
        currentScriptsFrame.Name = "RSQ_ScriptsFrame"
        currentScriptsFrame.Size = UDim2.new(1, 0, 1, 0)
        currentScriptsFrame.BackgroundTransparency = 1
        
        -- Back button
        local backBtn = Instance.new("TextButton", currentScriptsFrame)
        backBtn.Size = UDim2.new(0, 80, 0, 25)
        backBtn.Position = UDim2.new(0, 0, 0, 0)
        backBtn.Text = "← Back"
        backBtn.Font = Enum.Font.GothamBold
        backBtn.TextSize = 12
        backBtn.TextColor3 = COLOR_PALETTE.light.text
        backBtn.BackgroundColor3 = COLOR_PALETTE.dark.bg4
        backBtn.BackgroundTransparency = 0.2
        backBtn.BorderSizePixel = 0
        Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 6)
        
        backBtn.MouseButton1Click:Connect(function()
            currentScriptsFrame:Destroy()
            currentScriptsFrame = nil
            scrollFrame.Visible = true
        end)
        
        -- Title
        local scriptsTitle = Instance.new("TextLabel", currentScriptsFrame)
        scriptsTitle.Size = UDim2.new(1, -90, 0, 25)
        scriptsTitle.Position = UDim2.new(0, 85, 0, 0)
        scriptsTitle.Text = "📜 Scripts - " .. gameData.name
        scriptsTitle.Font = Enum.Font.GothamBold
        scriptsTitle.TextSize = 14
        scriptsTitle.TextColor3 = COLOR_PALETTE.primary
        scriptsTitle.BackgroundTransparency = 1
        scriptsTitle.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Scrolling frame for scripts
        local scriptsScroll = Instance.new("ScrollingFrame", currentScriptsFrame)
        scriptsScroll.Size = UDim2.new(1, 0, 1, -30)
        scriptsScroll.Position = UDim2.new(0, 0, 0, 30)
        scriptsScroll.BackgroundTransparency = 1
        scriptsScroll.ScrollBarImageColor3 = COLOR_PALETTE.primary
        scriptsScroll.ScrollBarThickness = 4
        scriptsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        
        local scriptsLayout = Instance.new("UIListLayout", scriptsScroll)
        scriptsLayout.Padding = UDim.new(0, 8)
        scriptsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        
        -- Add scripts
        local scripts = gameData.scripts or {}
        
        if #scripts == 0 then
            local emptyLabel = Instance.new("TextLabel", scriptsScroll)
            emptyLabel.Size = UDim2.new(1, 0, 0, 80)
            emptyLabel.Text = "📭 No scripts available for this game."
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.TextSize = 13
            emptyLabel.TextColor3 = COLOR_PALETTE.light.subtext
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.TextWrapped = true
        else
            for index, scriptData in ipairs(scripts) do
                if scriptData and scriptData.name and scriptData.url then
                    -- Script card
                    local scriptCard = Instance.new("Frame", scriptsScroll)
                    scriptCard.Size = UDim2.new(1, 0, 0, 65)
                    scriptCard.BackgroundColor3 = COLOR_PALETTE.dark.bg4
                    scriptCard.BackgroundTransparency = 0.2
                    scriptCard.BorderSizePixel = 0
                    Instance.new("UICorner", scriptCard).CornerRadius = UDim.new(0, 8)
                    scriptCard.LayoutOrder = index
                    
                    -- Script info
                    local scriptName = Instance.new("TextLabel", scriptCard)
                    scriptName.Size = UDim2.new(0.7, -10, 0, 25)
                    scriptName.Position = UDim2.new(0, 10, 0, 5)
                    scriptName.Text = scriptData.name
                    scriptName.Font = Enum.Font.GothamBold
                    scriptName.TextSize = 12
                    scriptName.TextColor3 = COLOR_PALETTE.light.text
                    scriptName.TextXAlignment = Enum.TextXAlignment.Left
                    scriptName.BackgroundTransparency = 1
                    
                    local urlPreview = Instance.new("TextLabel", scriptCard)
                    urlPreview.Size = UDim2.new(0.7, -10, 0, 20)
                    urlPreview.Position = UDim2.new(0, 10, 0, 30)
                    urlPreview.Text = "📎 " .. string.sub(scriptData.url, 1, 20) .. "..."
                    urlPreview.Font = Enum.Font.Gotham
                    urlPreview.TextSize = 10
                    urlPreview.TextColor3 = COLOR_PALETTE.light.subtext
                    urlPreview.TextXAlignment = Enum.TextXAlignment.Left
                    urlPreview.BackgroundTransparency = 1
                    
                    -- Execute button
                    local executeBtn = Instance.new("TextButton", scriptCard)
                    executeBtn.Size = UDim2.new(0, 80, 0, 25)
                    executeBtn.Position = UDim2.new(1, -85, 0.5, -12.5)
                    executeBtn.Text = "⚡ Execute"
                    executeBtn.Font = Enum.Font.GothamBold
                    executeBtn.TextSize = 11
                    executeBtn.TextColor3 = COLOR_PALETTE.light.text
                    executeBtn.BackgroundColor3 = COLOR_PALETTE.success
                    executeBtn.BackgroundTransparency = 0.2
                    executeBtn.BorderSizePixel = 0
                    Instance.new("UICorner", executeBtn).CornerRadius = UDim.new(0, 6)
                    
                    -- Capture script data for the closure
                    do
                        local capturedScriptData = {
                            name = scriptData.name,
                            url = scriptData.url
                        }
                        local capturedGameId = gameData.id
                        
                        executeBtn.MouseButton1Click:Connect(function()
                            -- Check if player is in the right game
                            if tostring(capturedGameId) == tostring(PLACE_ID) then
                                createNotify("Executing script: " .. capturedScriptData.name, COLOR_PALETTE.success)
                                
                                -- Execute the script
                                task.spawn(function()
                                    local success, errorMsg = pcall(function()
                                        local scriptContent = game:HttpGet(capturedScriptData.url)
                                        loadstring(scriptContent)()
                                    end)
                                    
                                    if not success then
                                        createNotify("❌ Script failed: " .. errorMsg, COLOR_PALETTE.danger)
                                    end
                                end)
                            else
                                -- Not in the right game, show notification and teleport confirmation
                                createNotify("❌ Cannot run script - Wrong Game ID", COLOR_PALETTE.warning)
                                
                                -- Wait 1 second then show teleport confirmation
                                task.wait(1)
                                showTeleportConfirmation(capturedGameId, capturedScriptData.name)
                            end
                        end)
                    end
                end
            end
        end
        
        -- Update canvas size
        task.wait(0.1)
        local totalHeight = 0
        for _, child in ipairs(scriptsScroll:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + scriptsLayout.Padding.Offset
            end
        end
        scriptsScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
    end

    -- Function to load and display games
    local function loadGames()
        -- Clear existing games
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        print("[RSQ] Loading games from GamesList:", #GamesList)
        
        -- Check if games exist
        if not GamesList or #GamesList == 0 then
            print("[RSQ] No games found in GamesList")
            local emptyLabel = Instance.new("TextLabel", scrollFrame)
            emptyLabel.Size = UDim2.new(1, 0, 0, 80)
            emptyLabel.Text = "📭 No games available\nCheck back later!"
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.TextSize = 13
            emptyLabel.TextColor3 = COLOR_PALETTE.light.subtext
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.TextWrapped = true
            emptyLabel.LayoutOrder = 1
            return
        end
        
        print("[RSQ] Found " .. #GamesList .. " games to display")
        
        -- Add games
        for _, gameData in ipairs(GamesList) do
            if gameData and gameData.id and gameData.name then
                local card = createGameCard(gameData, scrollFrame)
                card.LayoutOrder = _
            end
        end
        
        -- Update canvas size
        task.wait(0.1)
        local totalHeight = 0
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + gamesListLayout.Padding.Offset
            end
        end
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    -- Refresh button
    local refreshBtn = Instance.new("TextButton", mainFrame)
    refreshBtn.Size = UDim2.new(0, 100, 0, 30)
    refreshBtn.Position = UDim2.new(0.5, -50, 1, -40)
    refreshBtn.Text = "🔄 Refresh"
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.TextColor3 = COLOR_PALETTE.light.text
    refreshBtn.BackgroundColor3 = COLOR_PALETTE.primary
    refreshBtn.BackgroundTransparency = 0.2
    refreshBtn.BorderSizePixel = 0
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)
    
    refreshBtn.MouseButton1Click:Connect(function()
        createNotify("Refreshing games list...", COLOR_PALETTE.primary)
        fetchDataWithRetry() -- Refresh data
        print("[RSQ] After refresh, GamesList count:", #GamesList)
        loadGames() -- Reload games
    end)
    
    -- Load games initially
    loadGames()
    
    -- Animation
    mainFrame.BackgroundTransparency = 1
    TweenService:Create(mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
end

--==================================================--
-- KEY GUI
--==================================================--
local function showKeyGUI()
    if isGUILoaded() then
        createNotify("⚠️ GUI is already open!", COLOR_PALETTE.warning)
        return
    end
    
    if CurrentGUI and CurrentGUI.Parent then
        CurrentGUI:Destroy()
        CurrentGUI = nil
    end
    
    IsGuiOpen = true
    HasShownGUIAlready = true
    
    if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
        OpenButton.ToggleButton.Text = "✕"
        OpenButton.ToggleButton.BackgroundColor3 = COLOR_PALETTE.danger
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_KeySystem"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui
    CurrentGUI = gui

    local card = Instance.new("Frame", gui)
    card.Size = UDim2.new(0, 350, 0, 250)
    card.Position = UDim2.new(0.5, -175, 0.5, -125)
    card.BackgroundColor3 = COLOR_PALETTE.dark.bg3
    card.BackgroundTransparency = 0.1
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(card, card)

    -- Title bar
    local titleBar = Instance.new("Frame", card)
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = COLOR_PALETTE.dark.bg4
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "🔐 RSQ Key System"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = COLOR_PALETTE.light.text
    title.BackgroundTransparency = 1
    
    -- Close button
    createCloseButton(titleBar, function()
        IsGuiOpen = false
        if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
            OpenButton.ToggleButton.Text = "☰"
            OpenButton.ToggleButton.BackgroundColor3 = COLOR_PALETTE.primary
        end
        gui:Destroy()
        CurrentGUI = nil
    end)

    local input = Instance.new("TextBox", card)
    input.PlaceholderText = "Paste your key here"
    input.Size = UDim2.new(1, -30, 0, 35)
    input.Position = UDim2.new(0, 15, 0, 45)
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.TextColor3 = COLOR_PALETTE.light.text
    input.BackgroundColor3 = COLOR_PALETTE.dark.bg4
    input.BackgroundTransparency = 0.1
    input.BorderSizePixel = 0
    Instance.new("UICorner", input).CornerRadius = UDim.new(0,8)

    local unlock = Instance.new("TextButton", card)
    unlock.Text = "Unlock / Check Key"
    unlock.Size = UDim2.new(1, -30, 0, 35)
    unlock.Position = UDim2.new(0, 15, 0, 90)
    unlock.Font = Enum.Font.GothamBold
    unlock.TextSize = 13
    unlock.TextColor3 = COLOR_PALETTE.light.text
    unlock.BackgroundColor3 = COLOR_PALETTE.primary
    unlock.BackgroundTransparency = 0.2
    unlock.BorderSizePixel = 0
    Instance.new("UICorner", unlock).CornerRadius = UDim.new(0,8)

    local getKey = Instance.new("TextButton", card)
    getKey.Text = "🌐 Get Key"
    getKey.Size = UDim2.new(1, -30, 0, 30)
    getKey.Position = UDim2.new(0, 15, 0, 135)
    getKey.Font = Enum.Font.GothamBold
    getKey.TextSize = 12
    getKey.TextColor3 = COLOR_PALETTE.light.text
    getKey.BackgroundColor3 = COLOR_PALETTE.warning
    getKey.BackgroundTransparency = 0.2
    getKey.BorderSizePixel = 0
    Instance.new("UICorner", getKey).CornerRadius = UDim.new(0,8)

    local status = Instance.new("TextLabel", card)
    status.Position = UDim2.new(0, 15, 0, 175)
    status.Size = UDim2.new(1, -30, 0, 50)
    status.TextWrapped = true
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextColor3 = COLOR_PALETTE.light.subtext
    status.BackgroundTransparency = 1
    status.Text = "Enter your key to continue"

    TweenService:Create(card, TweenInfo.new(0.4), {BackgroundTransparency = 0.1}):Play()

    -- Button events
    unlock.MouseButton1Click:Connect(function()
        local inputKey = string_trim(input.Text)
        if inputKey == "" then return end

        status.Text = "⚡ Checking..."
        status.TextColor3 = COLOR_PALETTE.primary
        
        -- Try local validation first for instant response
        local ok, res = validate(inputKey, true) 
        
        -- If cache was empty or invalid, try one more time with a fresh fetch
        if not ok then
            ok, res = validate(inputKey, false)
        end

        if ok then
            CurrentKey = inputKey
            KeyActive = true
            status.Text = "✅ Success! Loading..."
            status.TextColor3 = COLOR_PALETTE.success
            
            sendWebhook("REDEEM", inputKey, res.exp)
            
            -- Save key status
            saveKeyStatus()
            
            TweenService:Create(card, TweenInfo.new(0.3), {BackgroundTransparency = 1, Size = UDim2.new(0,0,0,0)}):Play()
            task.delay(0.3, function() 
                gui:Destroy() 
                CurrentGUI = nil
                IsGuiOpen = false
                showAdvancedGamesGUI()
            end)

            -- Execute main scripts
            for _, url in ipairs(SCRIPT_URLS) do
                task.spawn(function()
                    pcall(function() 
                        loadstring(game:HttpGet(url))()
                    end)
                end)
            end
        else
            status.Text = res
            status.TextColor3 = COLOR_PALETTE.danger
            -- Clear saved key if validation fails
            if res == "❌ Expired" or res == "❌ Invalid Key" then
                clearKeyStatus()
                CurrentKey = nil
                KeyActive = false
            end
        end
    end)

    getKey.MouseButton1Click:Connect(function()
        setclipboard(GET_KEY_URL)
        status.Text = "📋 Link Copied!"
        status.TextColor3 = COLOR_PALETTE.accent
    end)
end

--==================================================--
-- INITIALIZE
--==================================================--
task.spawn(function()
    IsInitializing = true
    
    local hasSavedKey = loadKeyStatus()
    if hasSavedKey then
        createNotify("🔑 Loading saved key...", COLOR_PALETTE.primary)
        
        local ok, res = validate(CurrentKey, false)
        if ok then
            createNotify("✅ Key validated successfully!", COLOR_PALETTE.success)
            createOpenButton()
            task.wait(1)
            showAdvancedGamesGUI()
            
            for _, url in ipairs(SCRIPT_URLS) do
                task.spawn(function()
                    pcall(function() 
                        loadstring(game:HttpGet(url))()
                    end)
                end)
            end
        else
            createNotify("❌ Saved key invalid: " .. res, COLOR_PALETTE.danger)
            clearKeyStatus()
            CurrentKey = nil
            KeyActive = false
            createOpenButton()
            showKeyGUI()
        end
    else
        createOpenButton()
        showKeyGUI()
    end
    
    IsInitializing = false
end)

--==================================================--
-- SECURITY LOOPS
--==================================================--
task.spawn(function()
    while true do
        task.wait(CHECK_INTERVAL)
        if KeyActive and CurrentKey then
            local ok, res = validate(CurrentKey, false)
            if not ok then
                createNotify("❌ Key is no longer valid: " .. res, COLOR_PALETTE.danger)
                KeyActive = false
                CurrentKey = nil
                clearKeyStatus()
                
                if CurrentGUI and CurrentGUI.Parent then
                    CurrentGUI:Destroy()
                    CurrentGUI = nil
                end
                
                IsGuiOpen = false
                if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
                    OpenButton.ToggleButton.Text = "☰"
                    OpenButton.ToggleButton.BackgroundColor3 = COLOR_PALETTE.primary
                end
                
                showKeyGUI()
            end
        end
    end
end)
