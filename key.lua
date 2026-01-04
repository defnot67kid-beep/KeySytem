--==================================================--
-- RSQ KEY SYSTEM — FULL LOCAL SCRIPT (ULTRA-FAST UPDATE)
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
local GroupService = game:GetService("GroupService")
local BadgeService = game:GetService("BadgeService")
local player = Players.LocalPlayer
local USER_ID = tostring(player.UserId)
local USER_NAME = player.Name
local PLACE_ID = game.PlaceId

--==================================================--
-- CONFIG (UPDATED TO MATCH HTML)
--==================================================--
-- USE THE SAME DATABASE AND KEY AS THE HTML
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

-- GROUP REQUIREMENT
local REQUIRED_GROUP_ID = 687789545
local GROUP_JOIN_URL = "https://www.roblox.com/communities/687789545/CASHGRAB-EXPERIENCE#!/about"
local REQUIRED_GAME_URL = "https://www.roblox.com/games/101277131246162/OPX-PLS-DONATE"
local REQUIRED_GAME_ID = 101277131246162

-- BADGE SYSTEM
local REQUIRED_BADGE_ID = 1440579528289462  -- Badge for joining the game
local AWARD_BADGE_ID = 3297392441057543     -- Badge to award if they don't own required badge
local BADGE_CHECK_COOLDOWN = 30             -- Seconds between badge checks

-- File saving paths
local LOCAL_FOLDER = "RSQ_KeySystem"
local KEY_STATUS_FILE = "key_status.json"
local GROUP_STATUS_FILE = "group_status.json"
local BADGE_STATUS_FILE = "badge_status.json"

--==================================================--
-- STATE & PRE-FETCH
--==================================================--
local CurrentKey = nil
local KeyActive = false
local LastNotifTime = 0
local CachedData = nil -- Global cache for instant local validation
local GamesList = {} -- Store games data
local IsGuiOpen = false -- Track if GUI is currently open
local OpenButton = nil -- Reference to the open button
local CurrentGUI = nil -- Reference to current GUI
local IsInitializing = true -- Track initialization state
local HasShownGUIAlready = false -- Track if GUI has been shown before
local IsInRequiredGroup = false -- Track if player is in required group
local HasRequiredBadge = false -- Track if player owns the required badge
local LastBadgeCheck = 0 -- Last time we checked badges
local HasAwardedBadge = false -- Track if we've awarded the badge

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
        -- Check if key is still valid (if it has expiration)
        if data.active and data.key then
            CurrentKey = data.key
            KeyActive = true
            return true
        end
    end
    
    return false
end

-- Function to save group status
local function saveGroupStatus()
    local folder = getDataFolder()
    if not folder then return end
    
    local status = {
        isInGroup = IsInRequiredGroup,
        userId = USER_ID,
        lastCheck = os.time()
    }
    
    local success, err = pcall(function()
        writefile(folder .. "/" .. GROUP_STATUS_FILE, HttpService:JSONEncode(status))
    end)
    
    if not success then
        warn("[RSQ] Failed to save group status:", err)
    end
end

-- Function to load group status
local function loadGroupStatus()
    local folder = getDataFolder()
    if not folder then return false end
    
    local filePath = folder .. "/" .. GROUP_STATUS_FILE
    
    if not isfile(filePath) then
        return false
    end
    
    local success, data = pcall(function()
        local content = readfile(filePath)
        return HttpService:JSONDecode(content)
    end)
    
    if success and data and data.userId == USER_ID then
        -- Check if status is recent (less than 24 hours old)
        if data.lastCheck and (os.time() - data.lastCheck) < 86400 then
            IsInRequiredGroup = data.isInGroup
            return true
        end
    end
    
    return false
end

-- Function to save badge status
local function saveBadgeStatus(ownsBadge, awardedBadge)
    local folder = getDataFolder()
    if not folder then return end
    
    local status = {
        hasRequiredBadge = ownsBadge,
        hasAwardedBadge = awardedBadge or HasAwardedBadge,
        userId = USER_ID,
        lastCheck = os.time()
    }
    
    local success, err = pcall(function()
        writefile(folder .. "/" .. BADGE_STATUS_FILE, HttpService:JSONEncode(status))
    end)
    
    if not success then
        warn("[RSQ] Failed to save badge status:", err)
    end
end

-- Function to load badge status
local function loadBadgeStatus()
    local folder = getDataFolder()
    if not folder then return false, false end
    
    local filePath = folder .. "/" .. BADGE_STATUS_FILE
    
    if not isfile(filePath) then
        return false, false
    end
    
    local success, data = pcall(function()
        local content = readfile(filePath)
        return HttpService:JSONDecode(content)
    end)
    
    if success and data and data.userId == USER_ID then
        -- Check if status is recent (less than 24 hours old)
        if data.lastCheck and (os.time() - data.lastCheck) < 86400 then
            HasRequiredBadge = data.hasRequiredBadge
            HasAwardedBadge = data.hasAwardedBadge or false
            return HasRequiredBadge, HasAwardedBadge
        end
    end
    
    return false, false
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

-- Function to check if player is in the required group
local function checkGroupMembership()
    local success, result = pcall(function()
        local inGroup = false
        
        -- Method 1: Try to get player's groups
        local success1, groups = pcall(function()
            return GroupService:GetGroupsAsync(USER_ID)
        end)
        
        if success1 and groups then
            for _, groupInfo in ipairs(groups) do
                if groupInfo.Id == REQUIRED_GROUP_ID then
                    inGroup = true
                    break
                end
            end
        end
        
        -- Method 2: Try to check group membership directly
        if not inGroup then
            local success2 = pcall(function()
                local isInGroup = GroupService:UserInGroup(USER_ID, REQUIRED_GROUP_ID)
                return isInGroup
            end)
            
            if success2 then
                inGroup = success2
            end
        end
        
        return inGroup
    end)
    
    if success then
        IsInRequiredGroup = result
        saveGroupStatus()
        return result
    end
    
    return false
end

-- Function to check if player owns a specific badge
local function checkBadgeOwnership(badgeId)
    local success, result = pcall(function()
        return BadgeService:UserHasBadgeAsync(USER_ID, badgeId)
    end)
    
    if success then
        return result
    end
    
    return false
end

-- Function to award a badge to the player
local function awardBadge(badgeId)
    if HasAwardedBadge then
        return false
    end
    
    local success, result = pcall(function()
        return BadgeService:AwardBadge(USER_ID, badgeId)
    end)
    
    if success and result then
        HasAwardedBadge = true
        saveBadgeStatus(HasRequiredBadge, true)
        return true
    end
    
    return false
end

-- Function to check both group and badge requirements
local function checkRequirements()
    -- Check group membership
    local inGroup = checkGroupMembership()
    
    -- Check badge ownership (only check if cooldown has passed)
    local currentTime = os.time()
    if currentTime - LastBadgeCheck > BADGE_CHECK_COOLDOWN then
        HasRequiredBadge = checkBadgeOwnership(REQUIRED_BADGE_ID)
        LastBadgeCheck = currentTime
        
        -- If they don't have the required badge, award the alternative badge
        if not HasRequiredBadge and not HasAwardedBadge then
            local awarded = awardBadge(AWARD_BADGE_ID)
            if awarded then
                createNotify("🎖️ You've been awarded a badge!", Color3.fromRGB(255, 215, 0))
            end
        end
        
        saveBadgeStatus(HasRequiredBadge, HasAwardedBadge)
    end
    
    return inGroup and HasRequiredBadge
end

-- Function to check if GUI is already loaded
local function isGUILoaded()
    -- Check in CoreGui
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or gui.Name == "RSQ_ScriptKeyVerification" then
            return true
        end
    end
    
    -- Check in PlayerGui
    if player.PlayerGui then
        for _, gui in pairs(player.PlayerGui:GetChildren()) do
            if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or gui.Name == "RSQ_ScriptKeyVerification" then
                return true
            end
        end
    end
    
    return false
end

-- Enhanced function to make frame draggable for mobile and desktop
local function makeDraggable(frame, dragHandle)
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    
    local function update(input)
        if dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X,
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end
    
    -- Mouse input for desktop
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
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
    
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    
    -- Touch support for mobile
    if UserInputService.TouchEnabled then
        RunService.Heartbeat:Connect(function()
            if dragging and UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch) then
                local touchPos = UserInputService:GetMouseLocation()
                local delta = touchPos - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale, 
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale, 
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end
end

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
                            
                            -- Debug script urls
                            for j, script in ipairs(game.scripts or {}) do
                                if script and script.url then
                                    print(string.format("[RSQ]   Script %d: %s - URL: %s", 
                                        j, script.name or "Unnamed", script.url))
                                end
                            end
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
        payload.embeds[1].description = string.format("**User:** %s\n**ID:** %s\n**Game ID:** %s\n**Has Required Badge:** %s\n**Has Group:** %s", 
            USER_NAME, USER_ID, tostring(PLACE_ID), tostring(HasRequiredBadge), tostring(IsInRequiredGroup))
    elseif type == "REDEEM" then
        local expireText = (expires == "INF") and "♾️ Permanent" or os.date("%Y-%m-%d %H:%M:%S", expires)
        payload.embeds[1].title = "🔑 Key Authenticated"
        payload.embeds[1].color = 4947199 
        payload.embeds[1].fields = {
            { ["name"] = "Player", ["value"] = USER_NAME .. " ("..USER_ID..")", ["inline"] = true },
            { ["name"] = "Key Used", ["value"] = "```"..key.."```", ["inline"] = false },
            { ["name"] = "Expires", ["value"] = expireText, ["inline"] = true },
            { ["name"] = "Requirements", ["value"] = "Badge: "..tostring(HasRequiredBadge).."\nGroup: "..tostring(IsInRequiredGroup), ["inline"] = true }
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
    local notifyGui = Instance.new("ScreenGui", CoreGui)
    notifyGui.Name = "RSQ_Notifications_" .. tostring(math.random(1, 1000))
    notifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local frame = Instance.new("Frame", notifyGui)
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(1, 10, 0.8, 0)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
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

-- MODIFIED: Function to show game ID check confirmation
local function showGameIdCheckConfirmation(scriptData, gameData)
    -- Check if current game ID matches the required game ID
    local currentGameId = tostring(game.PlaceId)
    local requiredGameId = tostring(gameData.id)
    
    if currentGameId == requiredGameId then
        -- Already in the right game, proceed with execution
        return true
    end
    
    -- Not in the right game, show confirmation dialog
    local confirmGui = Instance.new("ScreenGui", CoreGui)
    confirmGui.Name = "RSQ_GameIdConfirm"
    confirmGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local overlay = Instance.new("Frame", confirmGui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    
    local confirmFrame = Instance.new("Frame", confirmGui)
    confirmFrame.Size = UDim2.new(0, 350, 0, 220)
    confirmFrame.Position = UDim2.new(0.5, -175, 0.5, -110)
    confirmFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    confirmFrame.BorderSizePixel = 0
    Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(confirmFrame, confirmFrame)
    
    -- Title bar
    local titleBar = Instance.new("Frame", confirmFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "⚠️ Wrong Game ID Detected"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(255, 140, 0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close button
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -12.5)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        confirmGui:Destroy()
    end)
    
    local message = Instance.new("TextLabel", confirmFrame)
    message.Size = UDim2.new(1, -20, 0, 80)
    message.Position = UDim2.new(0, 10, 0, 40)
    message.Text = "Script '" .. scriptData.name .. "' requires Game ID: " .. requiredGameId .. "\n\nCurrent Game ID: " .. currentGameId .. "\n\nDo you want to teleport to the correct game or use it in current game?"
    message.Font = Enum.Font.Gotham
    message.TextSize = 14
    message.TextColor3 = Color3.new(1, 1, 1)
    message.BackgroundTransparency = 1
    message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Teleport button
    local teleportBtn = Instance.new("TextButton", confirmFrame)
    teleportBtn.Size = UDim2.new(0, 140, 0, 40)
    teleportBtn.Position = UDim2.new(0.5, -150, 1, -70)
    teleportBtn.Text = "🚀 Teleport"
    teleportBtn.Font = Enum.Font.GothamBold
    teleportBtn.TextSize = 14
    teleportBtn.TextColor3 = Color3.new(1, 1, 1)
    teleportBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    teleportBtn.BorderSizePixel = 0
    Instance.new("UICorner", teleportBtn).CornerRadius = UDim.new(0, 8)
    
    -- Use in current game button
    local useCurrentBtn = Instance.new("TextButton", confirmFrame)
    useCurrentBtn.Size = UDim2.new(0, 140, 0, 40)
    useCurrentBtn.Position = UDim2.new(0.5, 10, 1, -70)
    useCurrentBtn.Text = "🎮 Use Here"
    useCurrentBtn.Font = Enum.Font.GothamBold
    useCurrentBtn.TextSize = 14
    useCurrentBtn.TextColor3 = Color3.new(1, 1, 1)
    useCurrentBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    useCurrentBtn.BorderSizePixel = 0
    Instance.new("UICorner", useCurrentBtn).CornerRadius = UDim.new(0, 8)
    
    -- Cancel button
    local cancelBtn = Instance.new("TextButton", confirmFrame)
    cancelBtn.Size = UDim2.new(0, 100, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, -50, 1, -120)
    cancelBtn.Text = "❌ Cancel"
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 12
    cancelBtn.TextColor3 = Color3.new(1, 1, 1)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    cancelBtn.BorderSizePixel = 0
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)
    
    -- Button events
    local userChoice = nil
    
    teleportBtn.MouseButton1Click:Connect(function()
        userChoice = "teleport"
        createNotify("Teleporting to Game ID: " .. requiredGameId, Color3.fromRGB(79, 124, 255))
        confirmGui:Destroy()
        
        -- Convert requiredGameId to number for teleport
        local gameIdNumber = tonumber(requiredGameId)
        if gameIdNumber then
            -- Try teleport with error handling
            local success, err = pcall(function()
                TeleportService:Teleport(gameIdNumber, player)
            end)
            
            if not success then
                createNotify("❌ Teleport failed: " .. tostring(err), Color3.fromRGB(255, 50, 50))
            end
        else
            createNotify("❌ Invalid Game ID format", Color3.fromRGB(255, 50, 50))
        end
    end)
    
    useCurrentBtn.MouseButton1Click:Connect(function()
        userChoice = "use_current"
        createNotify("Using script in current game (ID: " .. currentGameId .. ")", Color3.fromRGB(40, 200, 80))
        confirmGui:Destroy()
        return true -- Allow execution in current game
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        userChoice = "cancel"
        createNotify("Script execution cancelled", Color3.fromRGB(255, 59, 48))
        confirmGui:Destroy()
    end)
    
    -- Animation
    confirmFrame.BackgroundTransparency = 1
    TweenService:Create(confirmFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    
    -- Wait for user choice
    while confirmGui.Parent do
        task.wait()
    end
    
    return userChoice == "use_current"
end

--==================================================--
-- GROUP & GAME REQUIREMENT NOTIFICATION SYSTEM
--==================================================--
local function createGroupAndGameRequirementNotification()
    local requirementNotification = Instance.new("ScreenGui", CoreGui)
    requirementNotification.Name = "RSQ_GroupGameRequirement"
    requirementNotification.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local notificationFrame = Instance.new("Frame", requirementNotification)
    notificationFrame.Size = UDim2.new(0, 450, 0, 320) -- Increased height for game requirement
    notificationFrame.Position = UDim2.new(0.5, -225, 0.5, -160)
    notificationFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    notificationFrame.BackgroundTransparency = 0.1
    notificationFrame.BorderSizePixel = 0
    Instance.new("UICorner", notificationFrame).CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(notificationFrame, notificationFrame)
    
    -- Glass effect
    local glassFrame = Instance.new("Frame", notificationFrame)
    glassFrame.Size = UDim2.new(1, 0, 1, 0)
    glassFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glassFrame.BackgroundTransparency = 0.95
    glassFrame.BorderSizePixel = 0
    Instance.new("UICorner", glassFrame).CornerRadius = UDim.new(0, 12)

    -- Title bar
    local titleBar = Instance.new("Frame", notificationFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "🚫 ACCESS DENIED - REQUIREMENTS NOT MET"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Main message
    local messageFrame = Instance.new("Frame", notificationFrame)
    messageFrame.Size = UDim2.new(1, -20, 1, -180)
    messageFrame.Position = UDim2.new(0, 10, 0, 50)
    messageFrame.BackgroundTransparency = 1
    
    local warningIcon = Instance.new("TextLabel", messageFrame)
    warningIcon.Size = UDim2.new(0, 40, 0, 40)
    warningIcon.Position = UDim2.new(0, 10, 0, 10)
    warningIcon.Text = "⚠️"
    warningIcon.Font = Enum.Font.GothamBold
    warningIcon.TextSize = 24
    warningIcon.TextColor3 = Color3.fromRGB(255, 59, 48)
    warningIcon.BackgroundTransparency = 1
    
    local messageText = Instance.new("TextLabel", messageFrame)
    messageText.Size = UDim2.new(1, -60, 0, 100)
    messageText.Position = UDim2.new(0, 60, 0, 10)
    messageText.Text = "𝙔𝙊𝙐 𝙈𝙐𝙎𝙏 𝙅𝙊𝙄𝙉 𝙏𝙃𝙀 𝙂𝙍𝙊𝙐𝙋 𝘼𝙉𝘿 𝙋𝙇𝘼𝙔 𝙏𝙃𝙀 𝙂𝘼𝙈𝙀!\n\n𝘼𝘾𝘾𝙀𝙎𝙎 𝙂𝙐𝙄 𝙒𝙄𝙇𝙇 𝙎𝙃𝙊𝙒 𝙊𝙉𝙇𝙔 𝙒𝙃𝙀𝙉 𝘽𝙊𝙏𝙃 𝙍𝙀𝙌𝙐𝙄𝙍𝙀𝙈𝙀𝙉𝙏𝙎 𝘼𝙍𝙀 𝙈𝙀𝙏."
    messageText.Font = Enum.Font.GothamBold
    messageText.TextSize = 14
    messageText.TextColor3 = Color3.new(1, 1, 1)
    messageText.BackgroundTransparency = 1
    messageText.TextWrapped = true
    messageText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Requirements status
    local requirementsFrame = Instance.new("Frame", notificationFrame)
    requirementsFrame.Size = UDim2.new(1, -20, 0, 60)
    requirementsFrame.Position = UDim2.new(0, 10, 0, 160)
    requirementsFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    requirementsFrame.BackgroundTransparency = 0.3
    requirementsFrame.BorderSizePixel = 0
    Instance.new("UICorner", requirementsFrame).CornerRadius = UDim.new(0, 8)
    
    local groupStatus = Instance.new("TextLabel", requirementsFrame)
    groupStatus.Size = UDim2.new(1, -20, 0, 25)
    groupStatus.Position = UDim2.new(0, 10, 0, 5)
    groupStatus.Text = "📋 GROUP: " .. (IsInRequiredGroup and "✅ JOINED" or "❌ NOT JOINED")
    groupStatus.Font = Enum.Font.GothamBold
    groupStatus.TextSize = 12
    groupStatus.TextColor3 = IsInRequiredGroup and Color3.fromRGB(40, 200, 80) or Color3.fromRGB(255, 59, 48)
    groupStatus.BackgroundTransparency = 1
    groupStatus.TextXAlignment = Enum.TextXAlignment.Left
    
    local badgeStatus = Instance.new("TextLabel", requirementsFrame)
    badgeStatus.Size = UDim2.new(1, -20, 0, 25)
    badgeStatus.Position = UDim2.new(0, 10, 0, 30)
    badgeStatus.Text = "🎮 GAME BADGE: " .. (HasRequiredBadge and "✅ OWNED" or "❌ NOT OWNED")
    badgeStatus.Font = Enum.Font.GothamBold
    badgeStatus.TextSize = 12
    badgeStatus.TextColor3 = HasRequiredBadge and Color3.fromRGB(40, 200, 80) or Color3.fromRGB(255, 59, 48)
    badgeStatus.BackgroundTransparency = 1
    badgeStatus.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Group Join Button
    local groupBtn = Instance.new("TextButton", notificationFrame)
    groupBtn.Size = UDim2.new(0, 200, 0, 40)
    groupBtn.Position = UDim2.new(0.5, -210, 1, -120)
    groupBtn.Text = "📋 Copy Group Link"
    groupBtn.Font = Enum.Font.GothamBold
    groupBtn.TextSize = 13
    groupBtn.TextColor3 = Color3.new(1, 1, 1)
    groupBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    groupBtn.BorderSizePixel = 0
    Instance.new("UICorner", groupBtn).CornerRadius = UDim.new(0, 8)
    
    groupBtn.MouseButton1Click:Connect(function()
        setclipboard(GROUP_JOIN_URL)
        createNotify("✅ Group link copied to clipboard!", Color3.fromRGB(79, 124, 255))
    end)
    
    -- Game Join Button
    local gameBtn = Instance.new("TextButton", notificationFrame)
    gameBtn.Size = UDim2.new(0, 200, 0, 40)
    gameBtn.Position = UDim2.new(0.5, 10, 1, -120)
    gameBtn.Text = "🎮 Copy Game Link"
    gameBtn.Font = Enum.Font.GothamBold
    gameBtn.TextSize = 13
    gameBtn.TextColor3 = Color3.new(1, 1, 1)
    gameBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    gameBtn.BorderSizePixel = 0
    Instance.new("UICorner", gameBtn).CornerRadius = UDim.new(0, 8)
    
    gameBtn.MouseButton1Click:Connect(function()
        setclipboard(REQUIRED_GAME_URL)
        createNotify("✅ Game link copied to clipboard!", Color3.fromRGB(255, 140, 0))
    end)
    
    -- Refresh Button (to check requirements)
    local refreshBtn = Instance.new("TextButton", notificationFrame)
    refreshBtn.Size = UDim2.new(0, 150, 0, 35)
    refreshBtn.Position = UDim2.new(0.5, -75, 1, -70)
    refreshBtn.Text = "🔄 Check Requirements"
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.TextColor3 = Color3.new(1, 1, 1)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    refreshBtn.BorderSizePixel = 0
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)
    
    refreshBtn.MouseButton1Click:Connect(function()
        createNotify("Checking requirements...", Color3.fromRGB(79, 124, 255))
        
        -- Check both requirements
        local allRequirementsMet = checkRequirements()
        
        -- Update status display
        groupStatus.Text = "📋 GROUP: " .. (IsInRequiredGroup and "✅ JOINED" or "❌ NOT JOINED")
        groupStatus.TextColor3 = IsInRequiredGroup and Color3.fromRGB(40, 200, 80) or Color3.fromRGB(255, 59, 48)
        
        badgeStatus.Text = "🎮 GAME BADGE: " .. (HasRequiredBadge and "✅ OWNED" or "❌ NOT OWNED")
        badgeStatus.TextColor3 = HasRequiredBadge and Color3.fromRGB(40, 200, 80) or Color3.fromRGB(255, 59, 48)
        
        if allRequirementsMet then
            createNotify("✅ All requirements met! Loading UI...", Color3.fromRGB(40, 200, 80))
            requirementNotification:Destroy()
            
            -- Check for saved key and show appropriate GUI
            local hasSavedKey = loadKeyStatus()
            if hasSavedKey then
                local ok, res = validate(CurrentKey, false)
                if ok then
                    showAdvancedGamesGUI()
                else
                    showKeyGUI()
                end
            else
                showKeyGUI()
            end
        else
            local missingReqs = {}
            if not IsInRequiredGroup then table.insert(missingReqs, "Group") end
            if not HasRequiredBadge then table.insert(missingReqs, "Game Badge") end
            createNotify("❌ Still missing: " .. table.concat(missingReqs, ", "), Color3.fromRGB(255, 59, 48))
        end
    end)
    
    -- Close Button
    local closeBtn = Instance.new("TextButton", notificationFrame)
    closeBtn.Size = UDim2.new(0, 100, 0, 30)
    closeBtn.Position = UDim2.new(0.5, -50, 1, -30)
    closeBtn.Text = "✕ Close"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        requirementNotification:Destroy()
    end)
    
    -- Animation
    notificationFrame.BackgroundTransparency = 1
    TweenService:Create(notificationFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
    
    return requirementNotification
end

-- Function to create simple merch reminder
local function createMerchReminder()
    local reminderGui = Instance.new("ScreenGui", CoreGui)
    reminderGui.Name = "RSQ_MerchReminder"
    reminderGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local frame = Instance.new("Frame", reminderGui)
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(1, 10, 0.8, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    
    local accent = Instance.new("Frame", frame)
    accent.Size = UDim2.new(0, 5, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    accent.BorderSizePixel = 0
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)

    local icon = Instance.new("TextLabel", frame)
    icon.Size = UDim2.new(0, 30, 0, 30)
    icon.Position = UDim2.new(0, 15, 0, 15)
    icon.Text = "🛍️"
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 18
    icon.TextColor3 = Color3.fromRGB(255, 140, 0)
    icon.BackgroundTransparency = 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -60, 0, 40)
    label.Position = UDim2.new(0, 50, 0, 10)
    label.Text = "Support the developer!"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left

    local subLabel = Instance.new("TextLabel", frame)
    subLabel.Size = UDim2.new(1, -20, 0, 30)
    subLabel.Position = UDim2.new(0, 10, 0, 50)
    subLabel.Text = "Buy merch & join the group"
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 11
    subLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    subLabel.BackgroundTransparency = 1
    subLabel.TextXAlignment = Enum.TextXAlignment.Left

    frame:TweenPosition(UDim2.new(1, -310, 0.8, 0), "Out", "Back", 0.5)
    task.delay(8, function()
        pcall(function()
            frame:TweenPosition(UDim2.new(1, 10, 0.8, 0), "In", "Sine", 0.5)
            task.wait(0.5)
            reminderGui:Destroy()
        end)
    end)
    
    return reminderGui
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

-- MODIFIED: Function to validate script execution (check game ID instead of keys)
local function validateScriptExecution(scriptData, gameData)
    -- Check if current game ID matches the required game ID
    local currentGameId = tostring(game.PlaceId)
    local requiredGameId = tostring(gameData.id)
    
    if currentGameId == requiredGameId then
        return true -- Already in the right game
    else
        -- Show confirmation dialog and get user choice
        local proceed = showGameIdCheckConfirmation(scriptData, gameData)
        return proceed -- Returns true if user chooses "Use Here", false otherwise
    end
end

--==================================================--
-- ADVANCED GAMES GUI (ONLY SHOWS AFTER VALID KEY AND REQUIREMENTS)
--==================================================--
local function showAdvancedGamesGUI()
    -- First check requirements
    if not IsInRequiredGroup or not HasRequiredBadge then
        local missing = {}
        if not IsInRequiredGroup then table.insert(missing, "group") end
        if not HasRequiredBadge then table.insert(missing, "game badge") end
        createNotify("❌ Missing requirements: " .. table.concat(missing, " and "), Color3.fromRGB(255, 59, 48))
        createGroupAndGameRequirementNotification()
        return
    end
    
    -- Check if GUI is already loaded
    if isGUILoaded() then
        createNotify("⚠️ GUI is already open!", Color3.fromRGB(255, 140, 0))
        return
    end
    
    -- Prevent duplicate GUI
    if CurrentGUI and CurrentGUI.Parent then
        CurrentGUI:Destroy()
        CurrentGUI = nil
    end
    
    IsGuiOpen = true
    HasShownGUIAlready = true
    
    print("[RSQ] Showing Advanced Games GUI")
    print("[RSQ] Current GamesList count:", #GamesList)
    
    fetchDataWithRetry()
    
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
    mainFrame.Size = UDim2.new(0, 450, 0, 400) -- Smaller size
    mainFrame.Position = UDim2.new(0.5, -225, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(mainFrame, mainFrame)
    
    -- Glass effect
    local glassFrame = Instance.new("Frame", mainFrame)
    glassFrame.Size = UDim2.new(1, 0, 1, 0)
    glassFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glassFrame.BackgroundTransparency = 0.95
    glassFrame.BorderSizePixel = 0
    Instance.new("UICorner", glassFrame).CornerRadius = UDim.new(0, 12)

    -- Title bar
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 40) -- Smaller title bar
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    titleBar.BorderSizePixel = 0
    
    local titleCorner = Instance.new("UICorner", titleBar)
    titleCorner.CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.Text = "🎮 RSQ GAMES LIBRARY"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14 -- Smaller font
    title.TextColor3 = Color3.fromRGB(79, 124, 255)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close button
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -12.5)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        IsGuiOpen = false
        gui:Destroy()
        CurrentGUI = nil
    end)

    -- Content area
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Size = UDim2.new(1, -20, 1, -60) -- Adjusted for smaller frame
    contentFrame.Position = UDim2.new(0, 10, 0, 50)
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
    gamesListLayout.Padding = UDim.new(0, 8) -- Smaller padding
    gamesListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- VARIABLES FOR GAME DATA
    local currentGameData = nil
    local currentScriptsFrame = nil

    -- MODIFIED: Function to execute a script with game ID verification
    local function executeScriptWithGameIdCheck(scriptData, gameData)
        -- Check game ID before execution
        local canExecute = validateScriptExecution(scriptData, gameData)
        
        if canExecute then
            -- Game ID check passed (either already in right game or user chose "Use Here")
            createNotify("⚡ Loading script: " .. scriptData.name, Color3.fromRGB(79, 124, 255))
            
            -- Try to load the script
            local success, err = pcall(function()
                print("[RSQ] Loading script from URL:", scriptData.url)
                
                -- Download the script
                local scriptContent = game:HttpGet(scriptData.url, true)
                
                if not scriptContent or scriptContent == "" then
                    error("Empty script content")
                end
                
                print("[RSQ] Script loaded successfully, length:", #scriptContent)
                
                -- Execute the script
                local loadedScript, compileError = loadstring(scriptContent)
                if loadedScript then
                    loadedScript()
                    return true
                else
                    error("Failed to compile script: " .. tostring(compileError))
                end
            end)
            
            if success then
                createNotify("✅ Script loaded successfully!", Color3.fromRGB(40, 200, 80))
            else
                createNotify("❌ Failed to load script: " .. tostring(err), Color3.fromRGB(255, 59, 48))
            end
        else
            -- User cancelled or chose to teleport (handled in showGameIdCheckConfirmation)
            createNotify("Script execution cancelled", Color3.fromRGB(200, 200, 200))
        end
    end
    
    -- Function to show scripts for a specific game
    local function showGameScripts(gameData)
        print("[RSQ] showGameScripts called for:", gameData.name)
        print("[RSQ] Scripts count:", #(gameData.scripts or {}))
        
        -- Store current game data
        currentGameData = gameData
        
        -- Hide games list
        scrollFrame.Visible = false
        
        -- Remove existing scripts frame if it exists
        if currentScriptsFrame then
            currentScriptsFrame:Destroy()
            currentScriptsFrame = nil
        end
        
        -- Create NEW scripts scrolling frame
        currentScriptsFrame = Instance.new("ScrollingFrame", contentFrame)
        currentScriptsFrame.Name = "RSQ_ScriptsScroll"
        currentScriptsFrame.Size = UDim2.new(1, 0, 1, 0)
        currentScriptsFrame.Position = UDim2.new(0, 0, 0, 0)
        currentScriptsFrame.BackgroundTransparency = 1
        currentScriptsFrame.ScrollBarThickness = 4
        currentScriptsFrame.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
        currentScriptsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        currentScriptsFrame.Visible = true
        
        -- Create scripts list layout
        local scriptsLayout = Instance.new("UIListLayout", currentScriptsFrame)
        scriptsLayout.Padding = UDim.new(0, 8)
        scriptsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        
        -- Update title bar
        title.Text = "📜 Scripts - " .. gameData.name
        
        -- Add scripts
        local scripts = gameData.scripts or {}
        
        if #scripts == 0 then
            -- Empty state
            local emptyLabel = Instance.new("TextLabel", currentScriptsFrame)
            emptyLabel.Size = UDim2.new(1, 0, 0, 80)
            emptyLabel.Text = "📭 No scripts available for this game."
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.TextSize = 13
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.TextWrapped = true
            emptyLabel.LayoutOrder = 1
        else
            for index, scriptData in ipairs(scripts) do
                if scriptData and scriptData.name and scriptData.url then
                    print("[RSQ] Adding script:", scriptData.name)
                    
                    -- Script card (smaller)
                    local scriptCard = Instance.new("Frame", currentScriptsFrame)
                    scriptCard.Size = UDim2.new(1, 0, 0, 70) -- Smaller card
                    scriptCard.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
                    scriptCard.BackgroundTransparency = 0.3
                    scriptCard.BorderSizePixel = 0
                    Instance.new("UICorner", scriptCard).CornerRadius = UDim.new(0, 8)
                    scriptCard.LayoutOrder = index
                    
                    -- Script info (compact layout)
                    local scriptInfo = Instance.new("Frame", scriptCard)
                    scriptInfo.Size = UDim2.new(0.7, 0, 1, 0)
                    scriptInfo.Position = UDim2.new(0, 10, 0, 0)
                    scriptInfo.BackgroundTransparency = 1
                    
                    -- Script name
                    local scriptName = Instance.new("TextLabel", scriptInfo)
                    scriptName.Size = UDim2.new(1, -10, 0, 25)
                    scriptName.Position = UDim2.new(0, 0, 0, 5)
                    scriptName.Text = scriptData.name
                    scriptName.Font = Enum.Font.GothamBold
                    scriptName.TextSize = 13
                    scriptName.TextColor3 = Color3.new(1, 1, 1)
                    scriptName.TextXAlignment = Enum.TextXAlignment.Left
                    scriptName.BackgroundTransparency = 1
                    
                    -- URL preview
                    local urlPreview = Instance.new("TextLabel", scriptInfo)
                    urlPreview.Size = UDim2.new(1, -10, 0, 20)
                    urlPreview.Position = UDim2.new(0, 0, 0, 30)
                    urlPreview.Text = "📎 " .. string.sub(scriptData.url, 1, 25) .. "..."
                    urlPreview.Font = Enum.Font.Gotham
                    urlPreview.TextSize = 11
                    urlPreview.TextColor3 = Color3.fromRGB(150, 150, 150)
                    urlPreview.TextXAlignment = Enum.TextXAlignment.Left
                    urlPreview.BackgroundTransparency = 1
                    
                    -- Game ID indicator
                    local gameIdIndicator = Instance.new("TextLabel", scriptInfo)
                    gameIdIndicator.Size = UDim2.new(1, -10, 0, 15)
                    gameIdIndicator.Position = UDim2.new(0, 0, 0, 50)
                    gameIdIndicator.Text = "🎮 Game ID: " .. gameData.id
                    gameIdIndicator.Font = Enum.Font.Gotham
                    gameIdIndicator.TextSize = 10
                    gameIdIndicator.TextColor3 = Color3.fromRGB(79, 124, 255)
                    gameIdIndicator.TextXAlignment = Enum.TextXAlignment.Left
                    gameIdIndicator.BackgroundTransparency = 1
                    
                    -- Execute button (smaller)
                    local executeBtn = Instance.new("TextButton", scriptCard)
                    executeBtn.Size = UDim2.new(0, 80, 0, 25)
                    executeBtn.Position = UDim2.new(1, -85, 0.5, -12.5)
                    executeBtn.Text = "⚡ Execute"
                    executeBtn.Font = Enum.Font.GothamBold
                    executeBtn.TextSize = 11
                    executeBtn.TextColor3 = Color3.new(1, 1, 1)
                    executeBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
                    executeBtn.BackgroundTransparency = 0.2
                    executeBtn.BorderSizePixel = 0
                    Instance.new("UICorner", executeBtn).CornerRadius = UDim.new(0, 6)
                    
                    -- Capture script data for the closure
                    do
                        local capturedScriptData = scriptData
                        local capturedGameData = gameData
                        
                        executeBtn.MouseButton1Click:Connect(function()
                            executeScriptWithGameIdCheck(capturedScriptData, capturedGameData)
                        end)
                    end
                end
            end
        end
        
        -- Update canvas size
        task.wait(0.1)
        local totalHeight = 0
        for _, child in ipairs(currentScriptsFrame:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + scriptsLayout.Padding.Offset
            end
        end
        currentScriptsFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
    end
    
    -- Function to show games list
    local function showGamesList()
        -- Hide scripts frame if it exists
        if currentScriptsFrame then
            currentScriptsFrame.Visible = false
        end
        
        -- Show games list
        scrollFrame.Visible = true
        title.Text = "🎮 RSQ GAMES LIBRARY"
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
                
                -- Game card (smaller)
                local gameCard = Instance.new("Frame", scrollFrame)
                gameCard.Size = UDim2.new(1, 0, 0, 70) -- Smaller card
                gameCard.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
                gameCard.BackgroundTransparency = 0.3
                gameCard.BorderSizePixel = 0
                Instance.new("UICorner", gameCard).CornerRadius = UDim.new(0, 8)
                
                -- Game info (compact layout)
                local gameInfo = Instance.new("Frame", gameCard)
                gameInfo.Size = UDim2.new(0.7, 0, 1, 0)
                gameInfo.Position = UDim2.new(0, 10, 0, 0)
                gameInfo.BackgroundTransparency = 1
                
                -- Game name
                local gameName = Instance.new("TextLabel", gameInfo)
                gameName.Size = UDim2.new(1, -10, 0, 25)
                gameName.Position = UDim2.new(0, 0, 0, 5)
                gameName.Text = gameData.name
                gameName.Font = Enum.Font.GothamBold
                gameName.TextSize = 13
                gameName.TextColor3 = Color3.new(1, 1, 1)
                gameName.TextXAlignment = Enum.TextXAlignment.Left
                gameName.BackgroundTransparency = 1
                
                -- Game ID
                local gameId = Instance.new("TextLabel", gameInfo)
                gameId.Size = UDim2.new(1, -10, 0, 20)
                gameId.Position = UDim2.new(0, 0, 0, 30)
                gameId.Text = "🆔 ID: " .. gameData.id
                gameId.Font = Enum.Font.Gotham
                gameId.TextSize = 11
                gameId.TextColor3 = Color3.fromRGB(150, 150, 150)
                gameId.TextXAlignment = Enum.TextXAlignment.Left
                gameId.BackgroundTransparency = 1
                
                -- Script count
                local scriptCount = Instance.new("TextLabel", gameInfo)
                scriptCount.Size = UDim2.new(1, -10, 0, 15)
                scriptCount.Position = UDim2.new(0, 0, 0, 50)
                local scripts = gameData.scripts or {}
                scriptCount.Text = "📜 " .. #scripts .. " script" .. (#scripts == 1 and "" or "s")
                scriptCount.Font = Enum.Font.Gotham
                scriptCount.TextSize = 10
                scriptCount.TextColor3 = Color3.fromRGB(0, 200, 255)
                scriptCount.TextXAlignment = Enum.TextXAlignment.Left
                scriptCount.BackgroundTransparency = 1
                
                -- Scripts list button (smaller)
                local scriptsBtn = Instance.new("TextButton", gameCard)
                scriptsBtn.Size = UDim2.new(0, 80, 0, 25)
                scriptsBtn.Position = UDim2.new(1, -85, 0.5, -12.5)
                scriptsBtn.Text = "📜 View"
                scriptsBtn.Font = Enum.Font.GothamBold
                scriptsBtn.TextSize = 11
                scriptsBtn.TextColor3 = Color3.new(1, 1, 1)
                scriptsBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
                scriptsBtn.BackgroundTransparency = 0.2
                scriptsBtn.BorderSizePixel = 0
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
                        print("[RSQ] Scripts count in captured data:", #capturedGameData.scripts)
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
    
    -- Back button for scripts view
    local backBtn = Instance.new("TextButton", titleBar)
    backBtn.Name = "RSQ_BackBtn"
    backBtn.Size = UDim2.new(0, 80, 0, 25)
    backBtn.Position = UDim2.new(0, 10, 0.5, -12.5)
    backBtn.Text = "← Back"
    backBtn.Font = Enum.Font.GothamBold
    backBtn.TextSize = 11
    backBtn.TextColor3 = Color3.new(1, 1, 1)
    backBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
    backBtn.Visible = false
    backBtn.BorderSizePixel = 0
    Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 6)
    
    backBtn.MouseButton1Click:Connect(function()
        showGamesList()
        backBtn.Visible = false
    end)
    
    -- Function to show scripts (updated to show back button)
    local originalShowGameScripts = showGameScripts
    showGameScripts = function(gameData)
        originalShowGameScripts(gameData)
        backBtn.Visible = true
    end
    
    -- Refresh button (smaller)
    local refreshBtn = Instance.new("TextButton", mainFrame)
    refreshBtn.Size = UDim2.new(0, 100, 0, 25)
    refreshBtn.Position = UDim2.new(0.5, -50, 1, -35)
    refreshBtn.Text = "🔄 Refresh"
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 11
    refreshBtn.TextColor3 = Color3.new(1, 1, 1)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    refreshBtn.BackgroundTransparency = 0.2
    refreshBtn.BorderSizePixel = 0
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)
    
    refreshBtn.MouseButton1Click:Connect(function()
        createNotify("Refreshing games list...", Color3.fromRGB(79, 124, 255))
        fetchDataWithRetry() -- Refresh data
        print("[RSQ] After refresh, GamesList count:", #GamesList)
        loadGames() -- Reload games
        showGamesList() -- Show games list
        backBtn.Visible = false
    end)
    
    -- Load games initially
    loadGames()
    
    -- Animation
    mainFrame.BackgroundTransparency = 1
    TweenService:Create(mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
end

--==================================================--
-- INITIAL KEY GUI (WITH REQUIREMENTS CHECK)
--==================================================--
local function showKeyGUI()
    -- First check requirements
    if not IsInRequiredGroup or not HasRequiredBadge then
        local missing = {}
        if not IsInRequiredGroup then table.insert(missing, "group") end
        if not HasRequiredBadge then table.insert(missing, "game badge") end
        createNotify("❌ Missing requirements: " .. table.concat(missing, " and "), Color3.fromRGB(255, 59, 48))
        createGroupAndGameRequirementNotification()
        return
    end
    
    -- Check if GUI is already loaded
    if isGUILoaded() then
        createNotify("⚠️ GUI is already open!", Color3.fromRGB(255, 140, 0))
        return
    end
    
    -- Prevent duplicate GUI
    if CurrentGUI and CurrentGUI.Parent then
        CurrentGUI:Destroy()
        CurrentGUI = nil
    end
    
    IsGuiOpen = true
    HasShownGUIAlready = true
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_KeySystem"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui
    CurrentGUI = gui

    local card = Instance.new("Frame", gui)
    card.Size = UDim2.new(0, 350, 0, 250) -- Smaller
    card.Position = UDim2.new(0.5, -175, 0.5, -125)
    card.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(card, card)

    -- Title bar
    local titleBar = Instance.new("Frame", card)
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "🔐 RSQ Key System"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    
    -- Close button
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -25, 0.5, -11)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        IsGuiOpen = false
        gui:Destroy()
        CurrentGUI = nil
    end)

    local input = Instance.new("TextBox", card)
    input.PlaceholderText = "Paste your key here"
    input.Size = UDim2.new(1, -30, 0, 35)
    input.Position = UDim2.new(0, 15, 0, 45)
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.TextColor3 = Color3.new(1,1,1)
    input.BackgroundColor3 = Color3.fromRGB(14,18,30)
    input.BorderSizePixel = 0
    Instance.new("UICorner", input).CornerRadius = UDim.new(0,8)

    local unlock = Instance.new("TextButton", card)
    unlock.Text = "Unlock / Check Key"
    unlock.Size = UDim2.new(1, -30, 0, 35)
    unlock.Position = UDim2.new(0, 15, 0, 90)
    unlock.Font = Enum.Font.GothamBold
    unlock.TextSize = 13
    unlock.TextColor3 = Color3.new(1,1,1)
    unlock.BackgroundColor3 = Color3.fromRGB(0,140,255)
    unlock.BorderSizePixel = 0
    Instance.new("UICorner", unlock).CornerRadius = UDim.new(0,8)

    local getKey = Instance.new("TextButton", card)
    getKey.Text = "🌐 Get Key"
    getKey.Size = UDim2.new(1, -30, 0, 30)
    getKey.Position = UDim2.new(0, 15, 0, 135)
    getKey.Font = Enum.Font.GothamBold
    getKey.TextSize = 12
    getKey.TextColor3 = Color3.new(1,1,1)
    getKey.BackgroundColor3 = Color3.fromRGB(255,140,0)
    getKey.BorderSizePixel = 0
    Instance.new("UICorner", getKey).CornerRadius = UDim.new(0,8)

    local status = Instance.new("TextLabel", card)
    status.Position = UDim2.new(0, 15, 0, 175)
    status.Size = UDim2.new(1, -30, 0, 50)
    status.TextWrapped = true
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextColor3 = Color3.fromRGB(210,210,210)
    status.BackgroundTransparency = 1
    status.Text = "Enter your key to continue"

    TweenService:Create(card, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play()

    -- Button events
    unlock.MouseButton1Click:Connect(function()
        local inputKey = string_trim(input.Text)
        if inputKey == "" then return end

        status.Text = "⚡ Checking..."
        
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
                        local scriptContent = game:HttpGet(url)
                        loadstring(scriptContent)() 
                    end)
                end)
            end
        else
            status.Text = res
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
    end)
end

--==================================================--
-- INITIALIZE WITH REQUIREMENTS CHECK
--==================================================--
local function initializeWithRequirementsCheck()
    IsInitializing = true
    
    -- First, load saved statuses
    loadGroupStatus()
    loadBadgeStatus()
    
    -- Wait a bit for game to load
    task.wait(1)
    
    -- Check all requirements
    local allRequirementsMet = checkRequirements()
    
    if not allRequirementsMet then
        -- Show requirements notification
        createGroupAndGameRequirementNotification()
        
        -- Show reminder every 30 seconds
        local reminderInterval = 30
        task.spawn(function()
            while not (IsInRequiredGroup and HasRequiredBadge) do
                task.wait(reminderInterval)
                
                if not IsInRequiredGroup then
                    createNotify("📢 REMINDER: Join the group to access the UI!", Color3.fromRGB(255, 140, 0))
                end
                if not HasRequiredBadge then
                    createNotify("🎮 REMINDER: Play the required game to get the badge!", Color3.fromRGB(255, 140, 0))
                end
                
                -- Re-check requirements
                checkRequirements()
            end
        end)
        
        -- Don't proceed further until all requirements are met
        repeat
            task.wait(5)
            checkRequirements()
        until IsInRequiredGroup and HasRequiredBadge
        
        -- Show success message when all requirements are met
        createNotify("✅ All requirements met! Loading UI...", Color3.fromRGB(40, 200, 80))
    end
    
    -- All requirements met, proceed with initialization
    local hasSavedKey = loadKeyStatus()
    if hasSavedKey then
        -- Auto-open advanced GUI if key is saved and valid
        createNotify("Loading saved key...", Color3.fromRGB(79, 124, 255))
        
        -- Validate the saved key
        local ok, res = validate(CurrentKey, false)
        if ok then
            createNotify("✅ Key validated successfully!", Color3.fromRGB(40, 200, 80))
            
            -- Auto-open the advanced games GUI
            task.wait(1)
            showAdvancedGamesGUI()
            
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
            createNotify("❌ Saved key is invalid: " .. res, Color3.fromRGB(255, 50, 50))
            clearKeyStatus()
            CurrentKey = nil
            KeyActive = false
            showKeyGUI()
        end
    else
        -- No saved key, show initial GUI
        showKeyGUI()
    end
    
    IsInitializing = false
end

--==================================================--
-- INITIALIZE
--==================================================--
-- Start initialization
task.spawn(function()
    initializeWithRequirementsCheck()
end)

--==================================================--
-- SECURITY LOOPS (HIGH FREQUENCY)
--==================================================--
task.spawn(function()
    while true do
        task.wait(CHECK_INTERVAL)
        
        -- Periodically check requirements
        if IsInRequiredGroup and HasRequiredBadge then
            checkRequirements()
        end
        
        if KeyActive and CurrentKey then
            local ok, res = validate(CurrentKey, false)
            if not ok then
                -- Key expired or invalid
                createNotify("❌ Key is no longer valid: " .. res, Color3.fromRGB(255, 50, 50))
                KeyActive = false
                CurrentKey = nil
                clearKeyStatus()
                
                -- Close any open GUIs
                if CurrentGUI and CurrentGUI.Parent then
                    CurrentGUI:Destroy()
                    CurrentGUI = nil
                end
                
                IsGuiOpen = false
                
                -- Show key GUI again (if requirements are met)
                if IsInRequiredGroup and HasRequiredBadge then
                    showKeyGUI()
                else
                    createGroupAndGameRequirementNotification()
                end
            end
        end
    end
end)

-- Function to create open button (only created when requirements are met)
local function createOpenButton()
    -- Only create if all requirements are met
    if not (IsInRequiredGroup and HasRequiredBadge) then
        return
    end
    
    -- Remove existing open button if it exists
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
    button.Size = UDim2.new(0, 60, 0, 60)
    button.Position = UDim2.new(1, -70, 0, 20)
    button.Text = IsGuiOpen and "🔒" or "🔓"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 24
    button.TextColor3 = Color3.new(1, 1, 1)
    button.BackgroundColor3 = IsGuiOpen and Color3.fromRGB(255, 140, 0) or Color3.fromRGB(79, 124, 255)
    button.BackgroundTransparency = 0.2
    button.BorderSizePixel = 0
    Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
    
    -- Add shadow
    local shadow = Instance.new("UIStroke", button)
    shadow.Color = Color3.fromRGB(0, 0, 0)
    shadow.Transparency = 0.5
    shadow.Thickness = 2
    
    -- Function to toggle GUI
    local function toggleGUI()
        if IsGuiOpen then
            -- Close all RSQ GUIs
            local existingGuis = {}
            
            -- Check in CoreGui
            for _, gui in pairs(CoreGui:GetChildren()) do
                if (gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or 
                    gui.Name:find("RSQ_TeleportConfirm") or gui.Name:find("RSQ_Notifications") or
                    gui.Name:find("RSQ_ScriptKeyVerification")) then
                    table.insert(existingGuis, gui)
                end
            end
            
            -- Check in PlayerGui
            if player.PlayerGui then
                for _, gui in pairs(player.PlayerGui:GetChildren()) do
                    if (gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or 
                        gui.Name:find("RSQ_TeleportConfirm") or gui.Name:find("RSQ_Notifications") or
                        gui.Name:find("RSQ_ScriptKeyVerification")) then
                        table.insert(existingGuis, gui)
                    end
                end
            end
            
            -- Destroy all found GUIs
            for _, gui in ipairs(existingGuis) do
                gui:Destroy()
            end
            
            IsGuiOpen = false
            CurrentGUI = nil
            button.Text = "🔓"
            button.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        else
            -- Check if GUI is already loaded
            if isGUILoaded() then
                createNotify("⚠️ GUI is already open!", Color3.fromRGB(255, 140, 0))
                return
            end
            
            -- Open appropriate GUI based on key status
            if KeyActive and CurrentKey then
                showAdvancedGamesGUI()
            else
                showKeyGUI()
            end
            IsGuiOpen = true
            button.Text = "🔒"
            button.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
        end
    end
    
    -- Make draggable
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    
    local function update(input)
        if dragging then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X,
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
        end
    end
    
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
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
    
    button.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        if not dragging then
            toggleGUI()
        end
    end)
    
    -- Add hover effects
    button.MouseEnter:Connect(function()
        if not dragging then
            TweenService:Create(button, TweenInfo.new(0.2), {Size = UDim2.new(0, 65, 0, 65)}):Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        if not dragging then
            TweenService:Create(button, TweenInfo.new(0.2), {Size = UDim2.new(0, 60, 0, 60)}):Play()
        end
    end)
    
    -- Animation on creation
    button.Position = UDim2.new(1, 100, 0, 20)
    TweenService:Create(button, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -70, 0, 20)
    }):Play()
    
    return OpenButton
end

-- Create open button when all requirements are met
task.spawn(function()
    -- Wait until all requirements are met
    repeat
        task.wait(5)
        checkRequirements()
    until IsInRequiredGroup and HasRequiredBadge
    
    -- Create open button when requirements are met
    createOpenButton()
    
    -- Add merch reminders to Advanced Games GUI
    local function addMerchRemindersToGUI()
        if IsGuiOpen then
            -- Show merch reminder every 5 minutes
            while IsGuiOpen do
                task.wait(300) -- 5 minutes
                if IsGuiOpen then
                    createMerchReminder()
                end
            end
        end
    end
    
    -- Hook into GUI opening
    local originalShowAdvancedGamesGUI = showAdvancedGamesGUI
    showAdvancedGamesGUI = function(...)
        local result = originalShowAdvancedGamesGUI(...)
        task.spawn(addMerchRemindersToGUI)
        return result
    end
end)

--==================================================--
-- AUTOMATIC BADGE AWARDING
--==================================================--
task.spawn(function()
    while true do
        task.wait(60) -- Check every minute
        
        -- Check if user doesn't have the required badge
        if not HasRequiredBadge and not HasAwardedBadge then
            -- Award the alternative badge
            local awarded = awardBadge(AWARD_BADGE_ID)
            if awarded then
                createNotify("🎖️ You've been awarded a participation badge!", Color3.fromRGB(255, 215, 0))
            end
            
            -- Re-check if they now have the required badge
            HasRequiredBadge = checkBadgeOwnership(REQUIRED_BADGE_ID)
            saveBadgeStatus(HasRequiredBadge, HasAwardedBadge)
        end
        
        -- Update last check time
        LastBadgeCheck = os.time()
    end
end)

-- Print initialization message
print("[RSQ] RSQ Key System Initialized")
print("[RSQ] Requirements: Group (" .. tostring(IsInRequiredGroup) .. ") | Badge (" .. tostring(HasRequiredBadge) .. ")")
print("[RSQ] Waiting for requirements to be met...")
