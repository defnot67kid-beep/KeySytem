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
local JSONBIN_URL = "https://api.jsonbin.io/v3/b/6952cbcdd0ea881f4047f5ff/latest"
local JSON_KEY = "$2a$10$f6r4B1gP.MfB1k49kq2m7eEzyesjD9KWP5zCa6QtJKW5ZBhL1M0/O"
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

-- Function to fetch data with better error handling
local function fetchDataWithRetry()
    for attempt = 1, 3 do
        local ok, res = pcall(function()
            -- Try with headers first
            local response = game:HttpGet(JSONBIN_URL, true, {["X-Master-Key"] = JSON_KEY})
            return HttpService:JSONDecode(response)
        end)
        
        if ok and res and res.record then
            CachedData = res.record
            -- Debug logging
            print("[RSQ] Data fetched successfully")
            
            -- Convert games to proper table format
            GamesList = {}
            
            -- Handle games data - check if it exists and is a table
            if res.record.games then
                print("[RSQ] Games data type:", type(res.record.games))
                
                -- If games is already an array
                if type(res.record.games) == "table" then
                    local gameCount = 0
                    
                    -- Check if it's an array (numeric keys)
                    local isArray = false
                    for k, _ in pairs(res.record.games) do
                        if type(k) == "number" then
                            isArray = true
                            break
                        end
                    end
                    
                    if isArray then
                        -- It's already an array
                        GamesList = res.record.games
                        gameCount = #GamesList
                    else
                        -- It's an object, convert to array
                        for _, game in pairs(res.record.games) do
                            if type(game) == "table" and game.id and game.name then
                                table.insert(GamesList, game)
                                gameCount = gameCount + 1
                            end
                        end
                    end
                    
                    print("[RSQ] Loaded " .. gameCount .. " games")
                    
                    -- Print each game for debugging
                    for i, game in ipairs(GamesList) do
                        if game and game.id and game.name then
                            local scriptCount = #(game.scripts or {})
                            print(string.format("[RSQ] Game %d: %s (ID: %s) - %d scripts", 
                                i, game.name, game.id, scriptCount))
                        end
                    end
                else
                    print("[RSQ] Games is not a table, type:", type(res.record.games))
                end
            else
                print("[RSQ] No games field found in data")
            end
            return CachedData
        else
            -- Try without headers as fallback
            local ok2, res2 = pcall(function()
                local response = game:HttpGet(JSONBIN_URL)
                return HttpService:JSONDecode(response)
            end)
            
            if ok2 and res2 and res2.record then
                CachedData = res2.record
                print("[RSQ] Data fetched without headers")
                
                -- Same games processing logic as above
                GamesList = {}
                if res2.record.games and type(res2.record.games) == "table" then
                    local gameCount = 0
                    for _, game in pairs(res2.record.games) do
                        if type(game) == "table" and game.id and game.name then
                            table.insert(GamesList, game)
                            gameCount = gameCount + 1
                        end
                    end
                    print("[RSQ] Loaded " .. gameCount .. " games (no headers)")
                end
                return CachedData
            end
            
            warn("[RSQ] Fetch attempt " .. attempt .. " failed: " .. tostring(res))
            task.wait(1)
        end
    end
    return CachedData
end

-- Start downloading the database immediately on execution
task.spawn(function()
    print("[RSQ] Starting initial data fetch...")
    fetchDataWithRetry()
    print("[RSQ] Initial fetch complete. GamesList count:", #GamesList)
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

-- Function to show teleport confirmation
local function showTeleportConfirmation(gameId, gameName)
    local teleportGui = Instance.new("ScreenGui", player.PlayerGui)
    teleportGui.Name = "RSQ_TeleportConfirm"
    
    local overlay = Instance.new("Frame", teleportGui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    
    local confirmFrame = Instance.new("Frame", teleportGui)
    confirmFrame.Size = UDim2.new(0, 350, 0, 200)
    confirmFrame.Position = UDim2.new(0.5, -175, 0.5, -100)
    confirmFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 12)
    
    local title = Instance.new("TextLabel", confirmFrame)
    title.Size = UDim2.new(1, -20, 0, 40)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.Text = "⚠️ Teleport Required"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 140, 0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local message = Instance.new("TextLabel", confirmFrame)
    message.Size = UDim2.new(1, -20, 0, 80)
    message.Position = UDim2.new(0, 10, 0, 50)
    message.Text = "Script '" .. gameName .. "' requires Game ID: " .. gameId .. "\n\nDo you want to teleport to the correct game?"
    message.Font = Enum.Font.Gotham
    message.TextSize = 14
    message.TextColor3 = Color3.new(1, 1, 1)
    message.BackgroundTransparency = 1
    message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Yes button
    local yesBtn = Instance.new("TextButton", confirmFrame)
    yesBtn.Size = UDim2.new(0, 140, 0, 40)
    yesBtn.Position = UDim2.new(0.5, -150, 1, -60)
    yesBtn.Text = "✅ YES, Teleport"
    yesBtn.Font = Enum.Font.GothamBold
    yesBtn.TextSize = 14
    yesBtn.TextColor3 = Color3.new(1, 1, 1)
    yesBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    Instance.new("UICorner", yesBtn).CornerRadius = UDim.new(0, 8)
    
    -- No button
    local noBtn = Instance.new("TextButton", confirmFrame)
    noBtn.Size = UDim2.new(0, 140, 0, 40)
    noBtn.Position = UDim2.new(0.5, 10, 1, -60)
    noBtn.Text = "❌ NO, Cancel"
    noBtn.Font = Enum.Font.GothamBold
    noBtn.TextSize = 14
    noBtn.TextColor3 = Color3.new(1, 1, 1)
    noBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 8)
    
    -- Button events
    yesBtn.MouseButton1Click:Connect(function()
        createNotify("Teleporting to Game ID: " .. gameId, Color3.fromRGB(40, 200, 80))
        teleportGui:Destroy()
        task.wait(1)
        TeleportService:Teleport(tonumber(gameId), player)
    end)
    
    noBtn.MouseButton1Click:Connect(function()
        createNotify("Teleport cancelled", Color3.fromRGB(255, 59, 48))
        teleportGui:Destroy()
    end)
    
    -- Animation
    confirmFrame.BackgroundTransparency = 1
    TweenService:Create(confirmFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
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
-- ADVANCED GAMES GUI (ONLY SHOWS AFTER VALID KEY)
--==================================================--
local function showAdvancedGamesGUI()
    -- Refresh data before showing GUI
    print("[RSQ] Showing Advanced Games GUI")
    print("[RSQ] Current GamesList count:", #GamesList)
    
    fetchDataWithRetry()
    
    -- Create main GUI
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
    title.Text = "🎮 RSQ GAMES LIBRARY"
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

    -- Scrolling frame for games
    local scrollFrame = Instance.new("ScrollingFrame", contentFrame)
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Visible = true

    -- Games list container
    local gamesListLayout = Instance.new("UIListLayout", scrollFrame)
    gamesListLayout.Padding = UDim.new(0, 10)
    gamesListLayout.SortOrder = Enum.SortOrder.LayoutOrder

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
            emptyLabel.Size = UDim2.new(1, 0, 0, 100)
            emptyLabel.Text = "📭 No games available\nCheck back later!"
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.TextSize = 14
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.TextWrapped = true
            emptyLabel.LayoutOrder = 1
            return
        end
        
        print("[RSQ] Found " .. #GamesList .. " games to display")
        
        -- Add games
        for _, gameData in ipairs(GamesList) do
            if gameData and gameData.id and gameData.name then
                print("[RSQ] Adding game:", gameData.name, "ID:", gameData.id)
                
                -- Game card
                local gameCard = Instance.new("Frame", scrollFrame)
                gameCard.Size = UDim2.new(1, 0, 0, 100)
                gameCard.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
                gameCard.BackgroundTransparency = 0.3
                Instance.new("UICorner", gameCard).CornerRadius = UDim.new(0, 8)
                
                -- Game image/icon
                local gameIcon = Instance.new("Frame", gameCard)
                gameIcon.Size = UDim2.new(0, 80, 0, 80)
                gameIcon.Position = UDim2.new(0, 10, 0.5, -40)
                gameIcon.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
                Instance.new("UICorner", gameIcon).CornerRadius = UDim.new(0, 6)
                
                local iconLabel = Instance.new("TextLabel", gameIcon)
                iconLabel.Size = UDim2.new(1, 0, 1, 0)
                iconLabel.Text = "🎮"
                iconLabel.Font = Enum.Font.GothamBold
                iconLabel.TextSize = 24
                iconLabel.TextColor3 = Color3.new(1, 1, 1)
                iconLabel.BackgroundTransparency = 1
                
                -- Game info
                local gameInfo = Instance.new("Frame", gameCard)
                gameInfo.Size = UDim2.new(0.6, 0, 1, 0)
                gameInfo.Position = UDim2.new(0, 100, 0, 0)
                gameInfo.BackgroundTransparency = 1
                
                local gameName = Instance.new("TextLabel", gameInfo)
                gameName.Size = UDim2.new(1, -10, 0, 30)
                gameName.Position = UDim2.new(0, 10, 0, 10)
                gameName.Text = gameData.name
                gameName.Font = Enum.Font.GothamBold
                gameName.TextSize = 16
                gameName.TextColor3 = Color3.new(1, 1, 1)
                gameName.TextXAlignment = Enum.TextXAlignment.Left
                gameName.BackgroundTransparency = 1
                
                local gameId = Instance.new("TextLabel", gameInfo)
                gameId.Size = UDim2.new(1, -10, 0, 20)
                gameId.Position = UDim2.new(0, 10, 0, 40)
                gameId.Text = "ID: " .. gameData.id
                gameId.Font = Enum.Font.Gotham
                gameId.TextSize = 12
                gameId.TextColor3 = Color3.fromRGB(150, 150, 150)
                gameId.TextXAlignment = Enum.TextXAlignment.Left
                gameId.BackgroundTransparency = 1
                
                local scriptCount = Instance.new("TextLabel", gameInfo)
                scriptCount.Size = UDim2.new(1, -10, 0, 20)
                scriptCount.Position = UDim2.new(0, 10, 0, 60)
                local scripts = gameData.scripts or {}
                scriptCount.Text = "Scripts: " .. #scripts
                scriptCount.Font = Enum.Font.Gotham
                scriptCount.TextSize = 12
                scriptCount.TextColor3 = Color3.fromRGB(0, 200, 255)
                scriptCount.TextXAlignment = Enum.TextXAlignment.Left
                scriptCount.BackgroundTransparency = 1
                
                -- Scripts list button - FIXED WITH PROPER CLOSURE
                local scriptsBtn = Instance.new("TextButton", gameCard)
                scriptsBtn.Size = UDim2.new(0, 120, 0, 30)
                scriptsBtn.Position = UDim2.new(1, -140, 0.5, -15)
                scriptsBtn.Text = "📜 View Scripts"
                scriptsBtn.Font = Enum.Font.GothamBold
                scriptsBtn.TextSize = 12
                scriptsBtn.TextColor3 = Color3.new(1, 1, 1)
                scriptsBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
                scriptsBtn.BackgroundTransparency = 0.2
                Instance.new("UICorner", scriptsBtn).CornerRadius = UDim.new(0, 6)
                
                -- Capture game data in a local variable for the closure
                do
                    local capturedGameData = {
                        id = gameData.id,
                        name = gameData.name,
                        scripts = gameData.scripts or {}
                    }
                    
                    scriptsBtn.MouseButton1Click:Connect(function()
                        print("[RSQ] View Scripts clicked for:", capturedGameData.name)
                        showGameScripts(capturedGameData)
                    end)
                end
            else
                print("[RSQ] Invalid game data:", gameData)
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
    
    -- Function to show scripts for a specific game
    local function showGameScripts(gameData)
        print("[RSQ] showGameScripts called for:", gameData.name)
        
        -- Hide games list
        scrollFrame.Visible = false
        
        -- Remove existing scripts scroll if it exists
        local oldScripts = contentFrame:FindFirstChild("RSQ_ScriptsScroll")
        if oldScripts then
            oldScripts:Destroy()
        end
        
        -- Create NEW scripts scrolling frame
        local scriptsScroll = Instance.new("ScrollingFrame", contentFrame)
        scriptsScroll.Name = "RSQ_ScriptsScroll"
        scriptsScroll.Size = UDim2.new(1, 0, 1, 0)
        scriptsScroll.Position = UDim2.new(0, 0, 0, 0)
        scriptsScroll.BackgroundTransparency = 1
        scriptsScroll.ScrollBarThickness = 4
        scriptsScroll.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
        scriptsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scriptsScroll.Visible = true
        
        -- Create scripts list layout
        local scriptsLayout = Instance.new("UIListLayout", scriptsScroll)
        scriptsLayout.Padding = UDim.new(0, 10)
        scriptsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        
        -- Update title bar
        title.Text = "📜 Scripts - " .. gameData.name
        
        -- Add back button
        local backBtn = titleBar:FindFirstChild("RSQ_BackBtn")
        if backBtn then
            backBtn:Destroy()
        end
        
        backBtn = Instance.new("TextButton", titleBar)
        backBtn.Name = "RSQ_BackBtn"
        backBtn.Size = UDim2.new(0, 100, 0, 30)
        backBtn.Position = UDim2.new(0, 10, 0.5, -15)
        backBtn.Text = "← Back to Games"
        backBtn.Font = Enum.Font.GothamBold
        backBtn.TextSize = 12
        backBtn.TextColor3 = Color3.new(1, 1, 1)
        backBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
        Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 6)
        
        backBtn.MouseButton1Click:Connect(function()
            -- Return to games list
            scriptsScroll:Destroy()
            scrollFrame.Visible = true
            title.Text = "🎮 RSQ GAMES LIBRARY"
        end)
        
        -- Add scripts
        local scripts = gameData.scripts or {}
        print("[RSQ] Showing " .. #scripts .. " scripts")
        
        if #scripts == 0 then
            local emptyLabel = Instance.new("TextLabel", scriptsScroll)
            emptyLabel.Size = UDim2.new(1, 0, 0, 100)
            emptyLabel.Text = "No scripts available for this game."
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.TextSize = 14
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.TextWrapped = true
            emptyLabel.LayoutOrder = 1
        else
            for index, scriptData in ipairs(scripts) do
                if scriptData and scriptData.name and scriptData.url then
                    print("[RSQ] Adding script:", scriptData.name)
                    
                    -- Script card
                    local scriptCard = Instance.new("Frame", scriptsScroll)
                    scriptCard.Size = UDim2.new(1, 0, 0, 100)
                    scriptCard.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
                    scriptCard.BackgroundTransparency = 0.3
                    Instance.new("UICorner", scriptCard).CornerRadius = UDim.new(0, 8)
                    scriptCard.LayoutOrder = index
                    
                    -- Script icon
                    local scriptIcon = Instance.new("Frame", scriptCard)
                    scriptIcon.Size = UDim2.new(0, 80, 0, 80)
                    scriptIcon.Position = UDim2.new(0, 10, 0.5, -40)
                    scriptIcon.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
                    Instance.new("UICorner", scriptIcon).CornerRadius = UDim.new(0, 6)
                    
                    local iconLabel = Instance.new("TextLabel", scriptIcon)
                    iconLabel.Size = UDim2.new(1, 0, 1, 0)
                    iconLabel.Text = "📜"
                    iconLabel.Font = Enum.Font.GothamBold
                    iconLabel.TextSize = 24
                    iconLabel.TextColor3 = Color3.new(1, 1, 1)
                    iconLabel.BackgroundTransparency = 1
                    
                    -- Script info
                    local scriptInfo = Instance.new("Frame", scriptCard)
                    scriptInfo.Size = UDim2.new(0.6, 0, 1, 0)
                    scriptInfo.Position = UDim2.new(0, 100, 0, 0)
                    scriptInfo.BackgroundTransparency = 1
                    
                    local scriptName = Instance.new("TextLabel", scriptInfo)
                    scriptName.Size = UDim2.new(1, -10, 0, 30)
                    scriptName.Position = UDim2.new(0, 10, 0, 10)
                    scriptName.Text = scriptData.name
                    scriptName.Font = Enum.Font.GothamBold
                    scriptName.TextSize = 16
                    scriptName.TextColor3 = Color3.new(1, 1, 1)
                    scriptName.TextXAlignment = Enum.TextXAlignment.Left
                    scriptName.BackgroundTransparency = 1
                    
                    local urlPreview = Instance.new("TextLabel", scriptInfo)
                    urlPreview.Size = UDim2.new(1, -10, 0, 20)
                    urlPreview.Position = UDim2.new(0, 10, 0, 40)
                    urlPreview.Text = "URL: " .. string.sub(scriptData.url, 1, 30) .. "..."
                    urlPreview.Font = Enum.Font.Gotham
                    urlPreview.TextSize = 12
                    urlPreview.TextColor3 = Color3.fromRGB(150, 150, 150)
                    urlPreview.TextXAlignment = Enum.TextXAlignment.Left
                    urlPreview.BackgroundTransparency = 1
                    
                    local addedByInfo = Instance.new("TextLabel", scriptInfo)
                    addedByInfo.Size = UDim2.new(1, -10, 0, 20)
                    addedByInfo.Position = UDim2.new(0, 10, 0, 60)
                    addedByInfo.Text = "Added by: " .. (scriptData.addedBy or "Unknown")
                    addedByInfo.Font = Enum.Font.Gotham
                    addedByInfo.TextSize = 12
                    addedByInfo.TextColor3 = Color3.fromRGB(0, 200, 255)
                    addedByInfo.TextXAlignment = Enum.TextXAlignment.Left
                    addedByInfo.BackgroundTransparency = 1
                    
                    -- Execute button
                    local executeBtn = Instance.new("TextButton", scriptCard)
                    executeBtn.Size = UDim2.new(0, 120, 0, 30)
                    executeBtn.Position = UDim2.new(1, -140, 0.5, -15)
                    executeBtn.Text = "⚡ Execute"
                    executeBtn.Font = Enum.Font.GothamBold
                    executeBtn.TextSize = 12
                    executeBtn.TextColor3 = Color3.new(1, 1, 1)
                    executeBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
                    executeBtn.BackgroundTransparency = 0.2
                    Instance.new("UICorner", executeBtn).CornerRadius = UDim.new(0, 6)
                    
                    executeBtn.MouseButton1Click:Connect(function()
                        -- Check if player is in the right game
                        if tostring(gameData.id) == tostring(PLACE_ID) then
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
                        else
                            -- Not in the right game, show notification and teleport confirmation
                            createNotify("❌ Cannot run script - Wrong Game ID", Color3.fromRGB(255, 140, 0))
                            
                            -- Wait 1 second then show teleport confirmation
                            task.wait(1)
                            showTeleportConfirmation(gameData.id, scriptData.name)
                        end
                    end)
                else
                    print("[RSQ] Invalid script data:", scriptData)
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
    
    -- Refresh button
    local refreshBtn = Instance.new("TextButton", mainFrame)
    refreshBtn.Size = UDim2.new(0, 120, 0, 30)
    refreshBtn.Position = UDim2.new(0.5, -60, 1, -40)
    refreshBtn.Text = "🔄 Refresh Games"
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.TextColor3 = Color3.new(1, 1, 1)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    refreshBtn.BackgroundTransparency = 0.2
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)
    
    refreshBtn.MouseButton1Click:Connect(function()
        createNotify("Refreshing games list...", Color3.fromRGB(79, 124, 255))
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
-- INITIAL KEY GUI
--==================================================--
local function showKeyGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_KeySystem"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local card = Instance.new("Frame", gui)
    card.Size = UDim2.new(0, 430, 0, 300) -- Reduced height (removed View Games button)
    card.Position = UDim2.new(0.5, -215, 0.5, -150)
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

    local status = Instance.new("TextLabel", card)
    status.Position = UDim2.new(0, 20, 0, 205)
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
            status.Text = "✅ Success! Loading games..."
            
            sendWebhook("REDEEM", inputKey, res.exp)
            
            TweenService:Create(card, TweenInfo.new(0.3), {BackgroundTransparency = 1, Size = UDim2.new(0,0,0,0)}):Play()
            task.delay(0.3, function() 
                gui:Destroy() 
                showAdvancedGamesGUI()
            end)

            -- Execute main scripts
            for _, url in ipairs(SCRIPT_URLS) do
                task.spawn(function()
                    pcall(function() 
                        local scriptContent = game:HttpGet(url)
                        loadstring(scriptContent)() 
                    end)
                end)
            end
        else
            status.Text = res
        end
    end)

    getKey.MouseButton1Click:Connect(function()
        setclipboard(GET_KEY_URL)
        status.Text = "📋 Link Copied!"
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
