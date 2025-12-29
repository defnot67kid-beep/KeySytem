--==================================================--
-- RSQ KEY SYSTEM — FULL LOCAL SCRIPT (ULTRA-FAST UPDATE)
--==================================================--

-- SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer
local USER_ID = tostring(player.UserId)
local USER_NAME = player.Name
local PLACE_ID = game.PlaceId

--==================================================--
-- CONFIG
--==================================================--
local JSONBIN_URL = "https://api.jsonbin.io/v3/b/694c4aefae596e708faef157/latest"
local GET_KEY_URL = "https://realscripts-q.github.io/KEY-JSONHandler/"
local DISCORD_WEBHOOK = "https://webhook.lewisakura.moe/api/webhooks/1453515343833338017/7VwwcpKDpSvIYr0PA3Ceh8YgMwIEba47CoyISHCZkvdaF2hUsvyUYw3zNV_TbYyDFTMy"

local SCRIPT_URLS = {
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/D.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/I.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/N.lua",
}
local CHECK_INTERVAL = 1 -- Reduced to 1 second for faster background checks

--==================================================--
-- STATE & PRE-FETCH
--==================================================--
local CurrentKey = nil
local KeyActive = false
local LastNotifTime = 0
local CachedData = nil -- Global cache for instant local validation
local GamesList = {} -- Store games data
local CurrentGameData = nil -- Store current game's data from database

-- Start downloading the database immediately on execution
task.spawn(function()
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(JSONBIN_URL))
    end)
    if ok and res.record then
        CachedData = res.record
        if CachedData.games and type(CachedData.games) == "table" then
            GamesList = CachedData.games
            -- Find current game data
            for _, gameData in ipairs(GamesList) do
                if tostring(gameData.id) == tostring(PLACE_ID) then
                    CurrentGameData = gameData
                    break
                end
            end
        end
    end
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
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(JSONBIN_URL))
    end)
    if ok and res.record then
        CachedData = res.record
        if CachedData.games and type(CachedData.games) == "table" then
            GamesList = CachedData.games
            -- Update current game data
            CurrentGameData = nil
            for _, gameData in ipairs(GamesList) do
                if tostring(gameData.id) == tostring(PLACE_ID) then
                    CurrentGameData = gameData
                    break
                end
            end
        end
        return CachedData
    end
    return CachedData
end

local function kickBanned(reason)
    pcall(function() setclipboard(GET_KEY_URL) end)
    local kickMsg = "🛑 [RSQ RESTRICTION]\n\nReason: " .. (reason or "Blacklisted")
    while true do player:Kick(kickMsg) task.wait(0.5) end
end

local function createNotify(msg, color)
    local notifyGui = Instance.new("ScreenGui", player.PlayerGui)
    notifyGui.Name = "RSQ_Notifications_" .. tostring(math.random(1, 1000))
    
    local frame = Instance.new("Frame", notifyGui)
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(1, 10, 0.8, 0)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local accent = Instance.new("Frame", frame)
    accent.Size = UDim2.new(0, 5, 1, 0)
    accent.BackgroundColor3 = color
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.Text = msg
    label.TextColor3 = Color3.new(1, 1, 1)
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

--==================================================--
-- TELEPORT CONFIRMATION GUI
--==================================================--
local function showTeleportConfirmation(targetPlaceId)
    local gui = Instance.new("ScreenGui", player.PlayerGui)
    gui.Name = "RSQ_TeleportConfirm"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    
    local overlay = Instance.new("Frame", gui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    
    local dialog = Instance.new("Frame", gui)
    dialog.Size = UDim2.new(0, 400, 0, 200)
    dialog.Position = UDim2.new(0.5, -200, 0.5, -100)
    dialog.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 12)
    
    local title = Instance.new("TextLabel", dialog)
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.new(0, 20, 0, 20)
    title.Text = "🚀 Teleport to Correct Game"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    
    local message = Instance.new("TextLabel", dialog)
    message.Size = UDim2.new(1, -40, 0, 60)
    message.Position = UDim2.new(0, 20, 0, 60)
    message.Text = "Do you want to teleport to the correct game ID to run scripts?"
    message.Font = Enum.Font.Gotham
    message.TextSize = 14
    message.TextColor3 = Color3.fromRGB(200, 200, 200)
    message.BackgroundTransparency = 1
    message.TextWrapped = true
    
    local buttonFrame = Instance.new("Frame", dialog)
    buttonFrame.Size = UDim2.new(1, -40, 0, 40)
    buttonFrame.Position = UDim2.new(0, 20, 1, -60)
    buttonFrame.BackgroundTransparency = 1
    
    local yesButton = Instance.new("TextButton", buttonFrame)
    yesButton.Size = UDim2.new(0.5, -5, 1, 0)
    yesButton.Position = UDim2.new(0, 0, 0, 0)
    yesButton.Text = "✅ Yes"
    yesButton.Font = Enum.Font.GothamBold
    yesButton.TextSize = 14
    yesButton.TextColor3 = Color3.new(1, 1, 1)
    yesButton.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    Instance.new("UICorner", yesButton).CornerRadius = UDim.new(0, 8)
    
    local noButton = Instance.new("TextButton", buttonFrame)
    noButton.Size = UDim2.new(0.5, -5, 1, 0)
    noButton.Position = UDim2.new(0.5, 5, 0, 0)
    noButton.Text = "❌ No"
    noButton.Font = Enum.Font.GothamBold
    noButton.TextSize = 14
    noButton.TextColor3 = Color3.new(1, 1, 1)
    noButton.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    Instance.new("UICorner", noButton).CornerRadius = UDim.new(0, 8)
    
    -- Button actions
    yesButton.MouseButton1Click:Connect(function()
        createNotify("Teleporting to correct game...", Color3.fromRGB(40, 200, 80))
        TeleportService:Teleport(targetPlaceId, player)
    end)
    
    noButton.MouseButton1Click:Connect(function()
        gui:Destroy()
        createNotify("Staying in current game", Color3.fromRGB(255, 140, 0))
    end)
    
    -- Animation
    dialog.BackgroundTransparency = 1
    TweenService:Create(dialog, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
end

--==================================================--
-- VALIDATION LOGIC
--==================================================--
local function validate(keyToVerify, skipFetch)
    local data = skipFetch and CachedData or fetchData()
    if not data then return false, "Connection Error" end

    -- Ban Logic
    if data.bans and (data.bans[USER_NAME] or data.bans[USER_ID]) then
        kickBanned((data.bans[USER_NAME] or data.bans[USER_ID]).reason)
        return false, "Banned"
    end

    -- Notifications
    if data.notifications and data.notifications[USER_NAME] then
        local n = data.notifications[USER_NAME]
        if n.time > LastNotifTime then
            LastNotifTime = n.time
            if n.type == "DELETED" then createNotify("⚠️ Admin has revoked your key!", Color3.fromRGB(255, 50, 50))
            elseif n.type == "RENEWED" then createNotify("✅ Key renewed by Admin!", Color3.fromRGB(50, 255, 50))
            elseif n.type == "INFINITE" then createNotify("💎 Key is now PERMANENT!", Color3.fromRGB(0, 200, 255))
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
-- ADVANCED GAMES GUI (MODIFIED)
--==================================================--
local function showAdvancedGamesGUI()
    -- Check if current game has scripts
    if not CurrentGameData then
        createNotify("❌ No scripts available for this game", Color3.fromRGB(255, 50, 50))
        
        -- Find first game with scripts
        local targetGame = nil
        for _, gameData in ipairs(GamesList) do
            if gameData.scripts and #gameData.scripts > 0 then
                targetGame = gameData
                break
            end
        end
        
        if targetGame then
            task.wait(1) -- Wait 1 second as requested
            showTeleportConfirmation(targetGame.id)
        else
            createNotify("❌ No games with scripts found", Color3.fromRGB(255, 50, 50))
        end
        return
    end
    
    -- Check if current game has scripts
    if not CurrentGameData.scripts or #CurrentGameData.scripts == 0 then
        createNotify("❌ No scripts available for this game", Color3.fromRGB(255, 50, 50))
        
        -- Find first game with scripts
        local targetGame = nil
        for _, gameData in ipairs(GamesList) do
            if gameData.id ~= PLACE_ID and gameData.scripts and #gameData.scripts > 0 then
                targetGame = gameData
                break
            end
        end
        
        if targetGame then
            task.wait(1) -- Wait 1 second as requested
            showTeleportConfirmation(targetGame.id)
        else
            createNotify("❌ No other games with scripts found", Color3.fromRGB(255, 50, 50))
        end
        return
    end

    -- Create main GUI (only show if current game has scripts)
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_AdvancedGamesGUI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    -- Main container (centered, not full screen)
    local mainFrame = Instance.new("Frame", gui)
    mainFrame.Size = UDim2.new(0, 600, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 12)
    
    -- Glass effect
    local glassFrame = Instance.new("Frame", mainFrame)
    glassFrame.Size = UDim2.new(1, 0, 1, 0)
    glassFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glassFrame.BackgroundTransparency = 0.95
    glassFrame.BorderSizePixel = 0
    Instance.new("UICorner", glassFrame).CornerRadius = UDim.new(0, 12)

    -- Title bar
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    titleBar.BorderSizePixel = 0
    
    local titleCorner = Instance.new("UICorner", titleBar)
    titleCorner.CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.Text = "🎮 RSQ GAMES LIBRARY - " .. (CurrentGameData.name or "Current Game")
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(79, 124, 255)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close button
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BackgroundTransparency = 0.8
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)

    -- Content area
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Size = UDim2.new(1, -20, 1, -70)
    contentFrame.Position = UDim2.new(0, 10, 0, 60)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ClipsDescendants = true

    -- Scrolling frame for scripts (only show current game's scripts)
    local scrollFrame = Instance.new("ScrollingFrame", contentFrame)
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    -- Scripts list container
    local scriptsListLayout = Instance.new("UIListLayout", scrollFrame)
    scriptsListLayout.Padding = UDim.new(0, 10)
    scriptsListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Function to load and display scripts for current game
    local function loadScripts()
        -- Clear existing scripts
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        -- Check if scripts exist for current game
        if not CurrentGameData.scripts or #CurrentGameData.scripts == 0 then
            local emptyLabel = Instance.new("TextLabel", scrollFrame)
            emptyLabel.Size = UDim2.new(1, 0, 0, 100)
            emptyLabel.Text = "📭 No scripts available for this game"
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.TextSize = 14
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.TextWrapped = true
            emptyLabel.LayoutOrder = 1
            return
        end
        
        -- Add scripts
        for _, scriptData in ipairs(CurrentGameData.scripts) do
            if scriptData and scriptData.name and scriptData.url then
                local scriptItem = Instance.new("Frame", scrollFrame)
                scriptItem.Size = UDim2.new(1, 0, 0, 80)
                scriptItem.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
                scriptItem.BackgroundTransparency = 0.2
                Instance.new("UICorner", scriptItem).CornerRadius = UDim.new(0, 8)
                
                local scriptName = Instance.new("TextLabel", scriptItem)
                scriptName.Size = UDim2.new(0.7, -10, 0, 30)
                scriptName.Position = UDim2.new(0, 10, 0, 10)
                scriptName.Text = scriptData.name
                scriptName.Font = Enum.Font.GothamBold
                scriptName.TextSize = 14
                scriptName.TextColor3 = Color3.new(1, 1, 1)
                scriptName.TextXAlignment = Enum.TextXAlignment.Left
                scriptName.BackgroundTransparency = 1
                
                local urlPreview = Instance.new("TextLabel", scriptItem)
                urlPreview.Size = UDim2.new(0.7, -10, 0, 20)
                urlPreview.Position = UDim2.new(0, 10, 0, 40)
                urlPreview.Text = string.sub(scriptData.url, 1, 40) .. "..."
                urlPreview.Font = Enum.Font.Gotham
                urlPreview.TextSize = 11
                urlPreview.TextColor3 = Color3.fromRGB(150, 150, 150)
                urlPreview.TextXAlignment = Enum.TextXAlignment.Left
                urlPreview.BackgroundTransparency = 1
                
                local executeBtn = Instance.new("TextButton", scriptItem)
                executeBtn.Size = UDim2.new(0, 100, 0, 30)
                executeBtn.Position = UDim2.new(1, -110, 0.5, -15)
                executeBtn.Text = "⚡ Execute"
                executeBtn.Font = Enum.Font.GothamBold
                executeBtn.TextSize = 12
                executeBtn.TextColor3 = Color3.new(1, 1, 1)
                executeBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
                Instance.new("UICorner", executeBtn).CornerRadius = UDim.new(0, 6)
                
                executeBtn.MouseButton1Click:Connect(function()
                    createNotify("Executing script: " .. scriptData.name, Color3.fromRGB(40, 200, 80))
                    
                    -- Execute the script
                    task.spawn(function()
                        local success, errorMsg = pcall(function()
                            local scriptContent = game:HttpGet(scriptData.url)
                            loadstring(scriptContent)()
                        end)
                        
                        if not success then
                            createNotify("❌ Script failed: " .. errorMsg, Color3.fromRGB(255, 50, 50))
                        end
                    end)
                end)
                
                scriptItem.LayoutOrder = _
            end
        end
        
        -- Update canvas size
        task.wait(0.1)
        local totalHeight = 0
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + scriptsListLayout.Padding.Offset
            end
        end
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
    end
    
    -- View other games button
    local otherGamesBtn = Instance.new("TextButton", mainFrame)
    otherGamesBtn.Size = UDim2.new(0, 140, 0, 30)
    otherGamesBtn.Position = UDim2.new(0.5, -70, 1, -40)
    otherGamesBtn.Text = "🎮 View Other Games"
    otherGamesBtn.Font = Enum.Font.GothamBold
    otherGamesBtn.TextSize = 12
    otherGamesBtn.TextColor3 = Color3.new(1, 1, 1)
    otherGamesBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    otherGamesBtn.BackgroundTransparency = 0.2
    Instance.new("UICorner", otherGamesBtn).CornerRadius = UDim.new(0, 6)
    
    otherGamesBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        showAllGamesGUI()
    end)
    
    -- Load scripts initially
    loadScripts()
    
    -- Animation
    mainFrame.BackgroundTransparency = 1
    TweenService:Create(mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
end

--==================================================--
-- ALL GAMES GUI (FOR VIEWING OTHER GAMES)
--==================================================--
local function showAllGamesGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_AllGamesGUI"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame", gui)
    mainFrame.Size = UDim2.new(0, 600, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 12)
    
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    titleBar.BorderSizePixel = 0
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.Text = "🌐 All Available Games"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(79, 124, 255)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        showAdvancedGamesGUI()
    end)

    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Size = UDim2.new(1, -20, 1, -70)
    contentFrame.Position = UDim2.new(0, 10, 0, 60)
    contentFrame.BackgroundTransparency = 1

    local scrollFrame = Instance.new("ScrollingFrame", contentFrame)
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    local gamesListLayout = Instance.new("UIListLayout", scrollFrame)
    gamesListLayout.Padding = UDim.new(0, 10)
    gamesListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Load all games
    for _, gameData in ipairs(GamesList) do
        if gameData and gameData.id and gameData.name then
            local gameCard = Instance.new("Frame", scrollFrame)
            gameCard.Size = UDim2.new(1, 0, 0, 100)
            gameCard.BackgroundColor3 = gameData.id == PLACE_ID and Color3.fromRGB(40, 45, 60) or Color3.fromRGB(30, 35, 50)
            gameCard.BackgroundTransparency = 0.3
            Instance.new("UICorner", gameCard).CornerRadius = UDim.new(0, 8)
            
            local gameName = Instance.new("TextLabel", gameCard)
            gameName.Size = UDim2.new(0.6, -10, 0, 30)
            gameName.Position = UDim2.new(0, 10, 0, 10)
            gameName.Text = gameData.name .. (gameData.id == PLACE_ID and " (Current)" or "")
            gameName.Font = Enum.Font.GothamBold
            gameName.TextSize = 14
            gameName.TextColor3 = gameData.id == PLACE_ID and Color3.fromRGB(79, 124, 255) or Color3.new(1, 1, 1)
            gameName.TextXAlignment = Enum.TextXAlignment.Left
            gameName.BackgroundTransparency = 1
            
            local gameId = Instance.new("TextLabel", gameCard)
            gameId.Size = UDim2.new(0.6, -10, 0, 20)
            gameId.Position = UDim2.new(0, 10, 0, 40)
            gameId.Text = "ID: " .. gameData.id
            gameId.Font = Enum.Font.Gotham
            gameId.TextSize = 12
            gameId.TextColor3 = Color3.fromRGB(150, 150, 150)
            gameId.TextXAlignment = Enum.TextXAlignment.Left
            gameId.BackgroundTransparency = 1
            
            local scriptCount = Instance.new("TextLabel", gameCard)
            scriptCount.Size = UDim2.new(0.6, -10, 0, 20)
            scriptCount.Position = UDim2.new(0, 10, 0, 60)
            scriptCount.Text = "Scripts: " .. (#(gameData.scripts or {}))
            scriptCount.Font = Enum.Font.Gotham
            scriptCount.TextSize = 12
            scriptCount.TextColor3 = Color3.fromRGB(0, 200, 255)
            scriptCount.TextXAlignment = Enum.TextXAlignment.Left
            scriptCount.BackgroundTransparency = 1
            
            if gameData.id ~= PLACE_ID then
                local teleportBtn = Instance.new("TextButton", gameCard)
                teleportBtn.Size = UDim2.new(0, 120, 0, 30)
                teleportBtn.Position = UDim2.new(1, -130, 0.5, -15)
                teleportBtn.Text = "🚀 Teleport"
                teleportBtn.Font = Enum.Font.GothamBold
                teleportBtn.TextSize = 12
                teleportBtn.TextColor3 = Color3.new(1, 1, 1)
                teleportBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
                Instance.new("UICorner", teleportBtn).CornerRadius = UDim.new(0, 6)
                
                teleportBtn.MouseButton1Click:Connect(function()
                    showTeleportConfirmation(gameData.id)
                end)
            end
            
            gameCard.LayoutOrder = _
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
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
    
    mainFrame.BackgroundTransparency = 1
    TweenService:Create(mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
end

--==================================================--
-- INITIAL KEY GUI
--==================================================--
local function showKeyGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_KeySystem"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local card = Instance.new("Frame", gui)
    card.Size = UDim2.new(0, 430, 0, 350) -- Increased height for new button
    card.Position = UDim2.new(0.5, -215, 0.5, -175)
    card.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    card.BackgroundTransparency = 1
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -40, 0, 36)
    title.Position = UDim2.new(0, 20, 0, 14)
    title.Text = "🔐 RSQ Key System"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1

    local input = Instance.new("TextBox", card)
    input.PlaceholderText = "Paste your key here"
    input.Size = UDim2.new(1, -40, 0, 40)
    input.Position = UDim2.new(0, 20, 0, 60)
    input.Font = Enum.Font.Gotham
    input.TextSize = 14
    input.TextColor3 = Color3.new(1,1,1)
    input.BackgroundColor3 = Color3.fromRGB(14,18,30)
    Instance.new("UICorner", input).CornerRadius = UDim.new(0,10)

    local unlock = Instance.new("TextButton", card)
    unlock.Text = "Unlock / Check Key"
    unlock.Size = UDim2.new(1, -40, 0, 40)
    unlock.Position = UDim2.new(0, 20, 0, 110)
    unlock.Font = Enum.Font.GothamBold
    unlock.TextSize = 15
    unlock.TextColor3 = Color3.new(1,1,1)
    unlock.BackgroundColor3 = Color3.fromRGB(0,140,255)
    Instance.new("UICorner", unlock).CornerRadius = UDim.new(0,10)

    local getKey = Instance.new("TextButton", card)
    getKey.Text = "🌐 Get Key"
    getKey.Size = UDim2.new(1, -40, 0, 36)
    getKey.Position = UDim2.new(0, 20, 0, 158)
    getKey.Font = Enum.Font.GothamBold
    getKey.TextSize = 14
    getKey.TextColor3 = Color3.new(1,1,1)
    getKey.BackgroundColor3 = Color3.fromRGB(255,140,0)
    Instance.new("UICorner", getKey).CornerRadius = UDim.new(0,10)

    local viewGames = Instance.new("TextButton", card)
    viewGames.Text = "🎮 View Games Library"
    viewGames.Size = UDim2.new(1, -40, 0, 36)
    viewGames.Position = UDim2.new(0, 20, 0, 202)
    viewGames.Font = Enum.Font.GothamBold
    viewGames.TextSize = 14
    viewGames.TextColor3 = Color3.new(1,1,1)
    viewGames.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    Instance.new("UICorner", viewGames).CornerRadius = UDim.new(0,10)

    local status = Instance.new("TextLabel", card)
    status.Position = UDim2.new(0, 20, 0, 250)
    status.Size = UDim2.new(1, -40, 0, 70)
    status.TextWrapped = true
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    status.TextColor3 = Color3.fromRGB(210,210,210)
    status.BackgroundTransparency = 1
    status.Text = "Enter your key to continue"

    TweenService:Create(card, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play()

    -- Button events
    unlock.MouseButton1Click:Connect(function()
        local inputKey = string_trim(input.Text)
        if inputKey == "" then return end

        status.Text = "⚡ Instant Check..."
        
        -- Try local validation first for instant response
        local ok, res = validate(inputKey, true) 
        
        -- If cache was empty or invalid, try one more time with a fresh fetch
        if not ok then
            ok, res = validate(inputKey, false)
        end

        if ok then
            CurrentKey = inputKey
            KeyActive = true
            status.Text = "✅ Success! Removing key..."
            
            sendWebhook("REDEEM", inputKey, res.exp)
            
            TweenService:Create(card, TweenInfo.new(0.3), {BackgroundTransparency = 1, Size = UDim2.new(0,0,0,0)}):Play()
            task.delay(0.3, function() 
                gui:Destroy() 
                showAdvancedGamesGUI()
            end)
        else
            status.Text = res
        end
    end)

    getKey.MouseButton1Click:Connect(function()
        setclipboard(GET_KEY_URL)
        status.Text = "📋 Link Copied!"
    end)

    viewGames.MouseButton1Click:Connect(function()
        gui:Destroy()
        showAdvancedGamesGUI()
    end)
end

--==================================================--
-- INITIALIZE
--==================================================--
showKeyGUI()

--==================================================--
-- SECURITY LOOPS (HIGH FREQUENCY)
--==================================================--
task.spawn(function()
    while true do
        task.wait(CHECK_INTERVAL)
        if KeyActive and CurrentKey then
            local ok, _ = validate(CurrentKey, false)
            if not ok then
                TeleportService:Teleport(PLACE_ID, player)
                break
            end
        end
    end
end)
