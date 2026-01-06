--==================================================--
-- RSQ KEY SYSTEM — FULL LOCAL SCRIPT (FIXED FOR HTML SYSTEM)
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
local MERCH_URL = "https://www.roblox.com/catalog/136243714765116/Sythics-Merch"

-- File saving paths
local LOCAL_FOLDER = "RSQ_KeySystem"
local KEY_STATUS_FILE = "key_status.json"

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
        return result
    end
    
    return false
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
            
            warn("[RSQ] Fetch attempt " .. attempt .. " failed")
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

--==================================================--
-- FIXED VALIDATION LOGIC FOR HTML SYSTEM
--==================================================--
local function validate(keyToVerify, skipFetch)
    local data = skipFetch and CachedData or fetchData()
    if not data then 
        print("[VALIDATE] Failed to fetch data")
        return false, "Connection Error" 
    end

    -- Ban Logic
    if data.bans and (data.bans[USER_NAME] or data.bans[USER_ID]) then
        kickBanned((data.bans[USER_NAME] or data.bans[USER_ID]).reason)
        return false, "Banned"
    end

    if not keyToVerify then return false, "" end

    local entry = data.keys and data.keys[keyToVerify]
    if not entry then 
        print("[VALIDATE] Key not found in database")
        return false, "❌ Invalid Key" 
    end
    
    -- FIXED FOR HTML SYSTEM: Proper UserID comparison with multiple format checks
    local storedUserIdRaw = tostring(entry.rbx)
    local currentUserIdRaw = tostring(USER_ID)
    
    -- Clean both IDs (remove whitespace, quotes, etc.)
    local storedUserId = storedUserIdRaw:gsub("%s+", ""):gsub('"', ""):gsub("'", "")
    local currentUserId = currentUserIdRaw:gsub("%s+", ""):gsub('"', ""):gsub("'", "")
    
    -- Try multiple comparison methods
    local match = false
    
    -- Method 1: Direct string comparison
    if storedUserId == currentUserId then
        match = true
    -- Method 2: Compare as numbers (in case one is stored as number, other as string)
    elseif tonumber(storedUserId) and tonumber(currentUserId) then
        match = tonumber(storedUserId) == tonumber(currentUserId)
    -- Method 3: Check if they're the same after converting to numbers and back
    elseif tostring(tonumber(storedUserId) or storedUserId) == tostring(tonumber(currentUserId) or currentUserId) then
        match = true
    end
    
    if not match then 
        print("[VALIDATE] ID MISMATCH!")
        print("[VALIDATE] Stored UserID (raw):", storedUserIdRaw, "Type:", type(entry.rbx))
        print("[VALIDATE] Stored UserID (clean):", storedUserId)
        print("[VALIDATE] Current UserID (raw):", currentUserIdRaw)
        print("[VALIDATE] Current UserID (clean):", currentUserId)
        return false, "❌ ID Mismatch" 
    end
    
    if entry.exp ~= "INF" and os.time() > tonumber(entry.exp) then 
        return false, "❌ Expired" 
    end

    print("[VALIDATE] ✅ Key validation SUCCESS!")
    return true, entry
end

-- Debug function to check all keys
local function debugCheckAllKeys()
    local data = fetchData()
    if not data or not data.keys then
        print("[DEBUG] No data or keys found")
        return
    end
    
    print("[DEBUG] ===== KEY DATABASE DUMP =====")
    print("[DEBUG] Current UserID:", USER_ID)
    local keyCount = 0
    for _ in pairs(data.keys) do keyCount = keyCount + 1 end
    print("[DEBUG] Total keys in database:", keyCount)
    
    for key, entry in pairs(data.keys) do
        print("[DEBUG] Key:", key:sub(1, 8).."...")
        print("[DEBUG]   UserID stored:", entry.rbx, "Type:", type(entry.rbx))
        print("[DEBUG]   Generated by:", entry.generatedBy or "unknown")
        print("[DEBUG]   Expires:", entry.exp)
        
        -- Check if this key matches current user
        local storedUserId = tostring(entry.rbx):gsub("%s+", ""):gsub('"', ""):gsub("'", "")
        local currentUserId = tostring(USER_ID):gsub("%s+", ""):gsub('"', ""):gsub("'", "")
        local matches = storedUserId == currentUserId
        
        if matches then
            print("[DEBUG]   ✅ THIS KEY MATCHES YOUR USERID!")
        else
            print("[DEBUG]   ❌ Does NOT match your user")
        end
        print("[DEBUG] ---")
    end
    print("[DEBUG] =============================")
end

--==================================================--
-- GROUP REQUIREMENT NOTIFICATION SYSTEM
--==================================================--
local function createGroupRequirementNotification()
    local groupNotification = Instance.new("ScreenGui", CoreGui)
    groupNotification.Name = "RSQ_GroupRequirement"
    groupNotification.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local notificationFrame = Instance.new("Frame", groupNotification)
    notificationFrame.Size = UDim2.new(0, 400, 0, 250)
    notificationFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
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
    title.Text = "🚫 ACCESS DENIED"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Main message
    local messageFrame = Instance.new("Frame", notificationFrame)
    messageFrame.Size = UDim2.new(1, -20, 1, -120)
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
    messageText.Size = UDim2.new(1, -60, 0, 80)
    messageText.Position = UDim2.new(0, 60, 0, 10)
    messageText.Text = "𝙔𝙊𝙐 𝙈𝙐𝙎𝙏 𝙅𝙊𝙄𝙉 𝙏𝙃𝙀 𝙂𝙍𝙊𝙐𝙋 𝘽𝙀𝙁𝙊𝙍𝙀 𝘼𝘾𝘾𝙀𝙎𝙎𝙄𝙉𝙂 𝙏𝙃𝙀 𝙐𝙄!\n\n𝙉𝙤 𝙛𝙧𝙖𝙢𝙚𝙨 𝙬𝙞𝙡𝙡 𝙨𝙝𝙤𝙬 𝙪𝙣𝙩𝙞𝙇 𝙮𝙤𝙪 𝙟𝙤𝙞𝙣 𝙩𝙝𝙚 𝙜𝙧𝙤𝙪𝙥."
    messageText.Font = Enum.Font.GothamBold
    messageText.TextSize = 14
    messageText.TextColor3 = Color3.new(1, 1, 1)
    messageText.BackgroundTransparency = 1
    messageText.TextWrapped = true
    messageText.TextXAlignment = Enum.TextXAlignment.Left
    
    local groupInfo = Instance.new("TextLabel", messageFrame)
    groupInfo.Size = UDim2.new(1, -20, 0, 40)
    groupInfo.Position = UDim2.new(0, 10, 0, 100)
    groupInfo.Text = "📋 Group ID: 687789545\n🏷️ Group Name: CASHGRAB-EXPERIENCE"
    groupInfo.Font = Enum.Font.Gotham
    groupInfo.TextSize = 12
    groupInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    groupInfo.BackgroundTransparency = 1
    groupInfo.TextWrapped = true
    groupInfo.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Group Join Button
    local groupBtn = Instance.new("TextButton", notificationFrame)
    groupBtn.Size = UDim2.new(0, 180, 0, 40)
    groupBtn.Position = UDim2.new(0.5, -190, 1, -65)
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
    
    -- Refresh Button (to check if they joined)
    local refreshBtn = Instance.new("TextButton", notificationFrame)
    refreshBtn.Size = UDim2.new(0, 120, 0, 30)
    refreshBtn.Position = UDim2.new(0.5, -60, 1, -115)
    refreshBtn.Text = "🔄 Check Membership"
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.TextColor3 = Color3.new(1, 1, 1)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    refreshBtn.BorderSizePixel = 0
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)
    
    refreshBtn.MouseButton1Click:Connect(function()
        createNotify("Checking group membership...", Color3.fromRGB(79, 124, 255))
        local isInGroup = checkGroupMembership()
        if isInGroup then
            createNotify("✅ You're in the group! GUI will now show.", Color3.fromRGB(40, 200, 80))
            groupNotification:Destroy()
            
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
            createNotify("❌ Still not in the group. Please join first!", Color3.fromRGB(255, 59, 48))
        end
    end)
    
    -- Animation
    notificationFrame.BackgroundTransparency = 1
    TweenService:Create(notificationFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
    
    return groupNotification
end

--==================================================--
-- INITIAL KEY GUI (WITH GROUP CHECK) - FIXED
--==================================================--
local function showKeyGUI()
    -- First check group membership
    if not IsInRequiredGroup then
        createNotify("❌ You must join the group first!", Color3.fromRGB(255, 59, 48))
        createGroupRequirementNotification()
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
    card.Size = UDim2.new(0, 350, 0, 250)
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

    -- FIXED BUTTON EVENTS
    unlock.MouseButton1Click:Connect(function()
        local inputKey = string_trim(input.Text)
        if inputKey == "" then return end

        status.Text = "⚡ Checking..."
        
        -- Debug info
        print("[KEY CHECK] Testing key:", inputKey)
        
        -- Try local validation first for instant response
        local ok, res = validate(inputKey, true) 
        
        -- If cache was empty or invalid, try one more time with a fresh fetch
        if not ok then
            print("[KEY CHECK] Local validation failed, trying fresh fetch...")
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
            print("[KEY CHECK] Validation failed:", res)
            
            -- Show debug info on failure
            debugCheckAllKeys()
            
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
    
    -- Add debug button
    local debugBtn = Instance.new("TextButton", card)
    debugBtn.Text = "🐛 Debug"
    debugBtn.Size = UDim2.new(0, 60, 0, 20)
    debugBtn.Position = UDim2.new(1, -70, 1, -25)
    debugBtn.Font = Enum.Font.GothamBold
    debugBtn.TextSize = 10
    debugBtn.TextColor3 = Color3.new(1,1,1)
    debugBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    debugBtn.BorderSizePixel = 0
    Instance.new("UICorner", debugBtn).CornerRadius = UDim.new(0,4)
    
    debugBtn.MouseButton1Click:Connect(function()
        debugCheckAllKeys()
        createNotify("Debug info printed to console!", Color3.fromRGB(255, 140, 0))
    end)
end

--==================================================--
-- INITIALIZE WITH GROUP CHECK
--==================================================--
local function initializeWithGroupCheck()
    IsInitializing = true
    
    -- First, show the group requirement notification
    task.wait(1)
    
    -- Check group membership
    local isInGroup = checkGroupMembership()
    
    if not isInGroup then
        -- Show group requirement notification
        createGroupRequirementNotification()
        
        -- Don't proceed further until user is in group
        repeat
            task.wait(5)
            checkGroupMembership()
        until IsInRequiredGroup
        
        -- Show success message when they join
        createNotify("✅ You're now in the group! Loading UI...", Color3.fromRGB(40, 200, 80))
    end
    
    -- User is in group, proceed with initialization
    local hasSavedKey = loadKeyStatus()
    if hasSavedKey then
        -- Auto-open advanced GUI if key is saved and valid
        createNotify("Loading saved key...", Color3.fromRGB(79, 124, 255))
        
        -- Validate the saved key with debug
        print("[INIT] Validating saved key:", CurrentKey)
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
    initializeWithGroupCheck()
end)

--==================================================--
-- SECURITY LOOPS
--==================================================--
task.spawn(function()
    while true do
        task.wait(CHECK_INTERVAL)
        
        -- Periodically check group membership
        if IsInRequiredGroup then
            checkGroupMembership()
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
                
                -- Show key GUI again (if in group)
                if IsInRequiredGroup then
                    showKeyGUI()
                else
                    createGroupRequirementNotification()
                end
            end
        end
    end
end)

-- Function to create open button (only created when in group)
local function createOpenButton()
    -- Only create if in group
    if not IsInRequiredGroup then
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
    
    -- Function to toggle GUI
    local function toggleGUI()
        if IsGuiOpen then
            -- Close all RSQ GUIs
            local existingGuis = {}
            
            for _, gui in pairs(CoreGui:GetChildren()) do
                if (gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI") then
                    table.insert(existingGuis, gui)
                end
            end
            
            if player.PlayerGui then
                for _, gui in pairs(player.PlayerGui:GetChildren()) do
                    if (gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI") then
                        table.insert(existingGuis, gui)
                    end
                end
            end
            
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
    
    -- Animation on creation
    button.Position = UDim2.new(1, 100, 0, 20)
    TweenService:Create(button, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -70, 0, 20)
    }):Play()
    
    return OpenButton
end

-- Create open button when user joins group
task.spawn(function()
    repeat
        task.wait(5)
        checkGroupMembership()
    until IsInRequiredGroup
    
    createOpenButton()
end)

print("[RSQ] RSQ Key System Initialized with HTML System Compatibility")
print("[RSQ] Your UserID:", USER_ID)
print("[RSQ] Press the 🐛 Debug button in key GUI to see database contents")
