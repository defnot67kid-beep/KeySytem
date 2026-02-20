-- Original script from LuaObfuscator.com
-- Deobfuscated and modified to use Firebase instead of JSONBin

local gameService = game:GetService("Players")
local httpService = game:GetService("HttpService")
local userInputService = game:GetService("UserInputService")
local teleportService = game:GetService("TeleportService")
local groupService = game:GetService("GroupService")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local coreGui = game:GetService("CoreGui")
local player = gameService.LocalPlayer
local userId = tostring(player.UserId)
local username = player.Name
local placeId = game.PlaceId

-- Firebase configuration
local firebaseConfig = {
  apiKey = "AIzaSyAupBkllyicDPD9O6CmX4mS4sF5z96mqxc",
  authDomain = "vertexpaste.firebaseapp.com",
  projectId = "vertexpaste",
  storageBucket = "vertexpaste.firebasestorage.app",
  messagingSenderId = "255275350380",
  appId = "1:255275350380:web:7be4e8add2cb5b04045b49"
}

-- Firebase URL (using Realtime Database REST API)
local firebaseURL = "https://vertexpaste-default-rtdb.firebaseio.com/"

-- Constants
local groupLink = "https://www.roblox.com/groups/687789545/CASHGRAB-EXPERIENCE#!/about"
local merchLink = "https://www.roblox.com/catalog/14602589212/Random"
local groupId = 687789545
local notificationTime = 0
local savedKey = nil
local keyActive = false
local currentGameData = nil
local guiOpen = false
local mainGui = nil
local loadedScripts = {}
local databaseError = false
local miniGui = nil
local inGroup = false
local fetchingData = true

-- Utility functions
local function getStoragePath()
    if (writefile and isfolder) then
        if not isfolder("RSQ_Storage") then
            makefolder("RSQ_Storage")
        end
        return "RSQ_Storage"
    end
    return nil
end

local function saveKeyLocally()
    local storagePath = getStoragePath()
    if not storagePath then return end
    
    local filePath = storagePath .. "/key_data.json"
    local keyData = {
        key = savedKey,
        active = keyActive,
        userId = userId,
        timestamp = os.time()
    }
    
    local success, err = pcall(function()
        writefile(filePath, httpService:JSONEncode(keyData))
    end)
    
    if not success then
        warn("Failed to save key locally:", err)
    end
end

local function loadLocalKey()
    local storagePath = getStoragePath()
    if not storagePath then return false end
    
    local filePath = storagePath .. "/key_data.json"
    if not isfile(filePath) then return false end
    
    local success, data = pcall(function()
        local content = readfile(filePath)
        return httpService:JSONDecode(content)
    end)
    
    if (success and data and data.userId == userId) then
        if (data.active and data.key) then
            savedKey = data.key
            keyActive = true
            return true
        end
    end
    return false
end

local function deleteLocalKey()
    local storagePath = getStoragePath()
    if not storagePath then return end
    
    local filePath = storagePath .. "/key_data.json"
    if isfile(filePath) then
        delfile(filePath)
    end
end

-- Check group membership
local function checkGroupMembership()
    local success, result = pcall(function()
        local inGroup = false
        local success, groups = pcall(function()
            return groupService:GetGroupsAsync(userId)
        end)
        
        if (success and groups) then
            for _, group in ipairs(groups) do
                if (group.Id == groupId) then
                    inGroup = true
                    break
                end
            end
        end
        
        if not inGroup then
            local success2, isMember = pcall(function()
                return groupService:UserInGroup(userId, groupId)
            end)
            if success2 then
                inGroup = isMember
            end
        end
        
        return inGroup
    end)
    
    if success then
        inGroup = result
        return result
    end
    return false
end

-- Check for existing GUI
local function isGUIAlreadyOpen()
    for _, child in pairs(coreGui:GetChildren()) do
        if ((child.Name == "RSQ_GUI") or (child.Name == "RSQ_KeyGUI") or (child.Name == "RSQ_Notification")) then
            return true
        end
    end
    
    if player.PlayerGui then
        for _, child in pairs(player.PlayerGui:GetChildren()) do
            if ((child.Name == "RSQ_GUI") or (child.Name == "RSQ_KeyGUI") or (child.Name == "RSQ_Notification")) then
                return true
            end
        end
    end
    return false
end

-- Draggable UI function
local function makeDraggable(frame, dragArea)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
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
    
    dragArea.InputBegan:Connect(function(input)
        if ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch)) then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if (input.UserInputState == Enum.UserInputState.End) then
                    dragging = false
                end
            end)
        end
    end)
    
    dragArea.InputChanged:Connect(function(input)
        if ((input.UserInputType == Enum.UserInputType.MouseMovement) or (input.UserInputType == Enum.UserInputType.Touch)) then
            dragStart = input.Position
        end
    end)
    
    userInputService.InputChanged:Connect(function(input)
        if (dragging and ((input == dragStart) or (input.UserInputType == Enum.UserInputType.Touch))) then
            update(input)
        end
    end)
    
    if userInputService.TouchEnabled then
        runService.Heartbeat:Connect(function()
            if (dragging and userInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)) then
                local touchPos = userInputService:GetMouseLocation()
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

-- Format scripts from game data
local function formatScripts(gameData)
    if (not gameData or not gameData.keys or (type(gameData.keys) ~= "table")) then
        return {}
    end
    
    local scripts = {}
    for _, scriptData in ipairs(gameData.keys) do
        if (scriptData and (type(scriptData) == "table") and scriptData.name and scriptData.value) then
            table.insert(scripts, {
                name = scriptData.name,
                value = scriptData.value,
                url = scriptData.url or nil
            })
        end
    end
    return scripts
end

-- Fetch data from Firebase
local function fetchFirebaseData()
    local retryCount = 0
    while retryCount < 3 do
        local success, response = pcall(function()
            local url = firebaseURL .. ".json?auth=" .. firebaseConfig.apiKey
            local data = game:HttpGet(url, true, {
                ["Content-Type"] = "application/json"
            })
            return httpService:JSONDecode(data)
        end)
        
        if (success and response and response.record) then
            currentGameData = response.record
            print("✅ Firebase data loaded successfully")
            
            -- Debug: print keys info
            if response.record.keys then
                print("📊 Keys found:", type(response.record.keys))
                local keyCount = 0
                for keyName, keyData in pairs(response.record.keys) do
                    keyCount = keyCount + 1
                    if (keyCount <= 5) then
                        print(string.format("  Key %d: %s -> User: %s, Generated by: %s", 
                            keyCount, keyName, tostring(keyData.rbx), tostring(keyData.generatedBy)))
                    end
                end
                print("📊 Total keys:", keyCount)
            else
                print("⚠️ No keys found in database")
            end
            
            -- Load games list
            if response.record.games then
                print("🎮 Games found:", type(response.record.games))
                if (type(response.record.games) == "table") then
                    local isArray = false
                    for k, v in pairs(response.record.games) do
                        if (type(k) == "number") then
                            isArray = true
                            break
                        end
                    end
                    
                    if isArray then
                        loadedScripts = response.record.games
                        print("📚 Games loaded (array):", #loadedScripts)
                    else
                        loadedScripts = {}
                        for gameId, gameData in pairs(response.record.games) do
                            if ((type(gameData) == "table") and gameData.id and gameData.name) then
                                table.insert(loadedScripts, gameData)
                            end
                        end
                        print("📚 Games loaded (object):", #loadedScripts)
                    end
                    
                    print("📋 Game list:")
                    for idx, game in ipairs(loadedScripts) do
                        if (game and game.id and game.name) then
                            local scriptCount = #(game.scripts or {})
                            print(string.format("  %d. %s (ID: %s) - %d scripts", idx, game.name, game.id, scriptCount))
                            
                            for sIdx, script in ipairs(game.scripts or {}) do
                                if (script and script.keys) then
                                    print(string.format("    Script %d: %s - %d keys", sIdx, script.name or "Unnamed", #script.keys))
                                end
                            end
                        end
                    end
                end
            else
                print("⚠️ No games found in database")
            end
            
            return response.record
        else
            local errorMsg = tostring(response)
            warn("Failed to fetch from Firebase (attempt " .. (retryCount + 1) .. "):", errorMsg)
            task.wait(1)
            retryCount = retryCount + 1
        end
    end
    
    return nil
end

-- Initialize data
task.spawn(function()
    local waitCount = 0
    while true do
        if waitCount == 0 then
            print("🚀 Fetching data from Firebase...")
            fetchFirebaseData()
            waitCount = 1
        end
        if waitCount == 1 then
            print("📚 Loaded", #loadedScripts, "games")
            break
        end
    end
end)

-- Send Discord webhook (keeping original functionality)
local function sendWebhook(type, key, expiry)
    local embedColor = 28167409
    local embedDesc = ""
    local embedTitle = ""
    
    local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local webhookData = {
        embeds = {{
            timestamp = timestamp,
            fields = {{
                name = "User",
                value = username .. " (" .. userId .. ")",
                inline = true
            }}
        }}
    }
    
    if (not webhookURL or (webhookURL == "")) then
        return
    end
    
    local userString = username .. " (" .. userId .. ")"
    
    if (type == "join") then
        webhookData.embeds[1].title = "📥 Player Joined System"
        webhookData.embeds[1].color = 28167409
        webhookData.embeds[1].description = string.format("**User:** %s\n**ID:** %s\n**Game ID:** %s", username, userId, tostring(placeId))
    
    elseif (type == "auth") then
        local expiryText = ((expiry == "permanent") and "♾️ Permanent") or os.date("%Y-%m-%d %H:%M:%S", expiry)
        webhookData.embeds[1].title = "🔑 Key Authenticated"
        webhookData.embeds[1].color = 11986473
        webhookData.embeds[1].fields = {
            {
                name = "User",
                value = username .. " (" .. userId .. ")",
                inline = true
            },
            {
                name = "Key",
                value = "`" .. key .. "`",
                inline = false
            },
            {
                name = "Expiry",
                value = expiryText,
                inline = true
            }
        }
    end
    
    pcall(function()
        httpService:PostAsync(webhookURL, httpService:JSONEncode(webhookData))
    end)
end

sendWebhook("join")

-- Extract key from input
local function extractKey(input)
    return input:match("^%s*(.-)%s*$")
end

-- Refresh data
local function refreshData()
    return fetchFirebaseData()
end

-- Kick player with reason
local function kickPlayer(reason)
    pcall(function()
        setclipboard(groupLink)
    end)
    local kickMsg = "🛑 [RSQ RESTRICTION]\n\nReason: " .. (reason or "No reason provided")
    
    while true do
        player:Kick(kickMsg)
        task.wait(0.5)
    end
end

-- Show notification
local function showNotification(message, color)
    local notificationGui = Instance.new("ScreenGui", coreGui)
    notificationGui.Name = "RSQ_Notification_" .. tostring(math.random(1, 1000))
    notificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local frame = Instance.new("Frame", notificationGui)
    frame.Size = UDim2.new(0, 300, 0, 60)
    frame.Position = UDim2.new(0, 10, 0.8, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)
    
    local progress = Instance.new("Frame", frame)
    progress.Size = UDim2.new(0, 0, 1, 0)
    progress.BackgroundColor3 = color
    progress.BorderSizePixel = 0
    
    local progressCorner = Instance.new("UICorner", progress)
    progressCorner.CornerRadius = UDim.new(0, 2)
    
    local text = Instance.new("TextLabel", frame)
    text.Size = UDim2.new(1, -20, 1, 0)
    text.Position = UDim2.new(0, 10, 0, 0)
    text.Text = message
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.BackgroundTransparency = 1
    text.TextXAlignment = Enum.TextXAlignment.Left
    
    frame:TweenPosition(UDim2.new(0, 10, 0.8, 0), "Out", "Quad", 0.5)
    
    tweenService:Create(progress, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)}):Play()
    
    task.delay(5, function()
        pcall(function()
            frame:TweenPosition(UDim2.new(1, 10, 0.8, 0), "Out", "Quad", 0.5)
            task.wait(0.5)
            notificationGui:Destroy()
        end)
    end)
end

-- Game ID mismatch popup
local function showGameMismatchPopup(scriptInfo, gameInfo)
    local currentPlaceId = tostring(game.PlaceId)
    local requiredPlaceId = tostring(gameInfo.id)
    
    if (currentPlaceId == requiredPlaceId) then
        return true
    end
    
    local popupGui = Instance.new("ScreenGui", coreGui)
    popupGui.Name = "RSQ_MismatchPopup"
    popupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local mainFrame = Instance.new("Frame", popupGui)
    mainFrame.Size = UDim2.new(0, 400, 0, 250)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
    mainFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    mainFrame.BackgroundTransparency = 0.7
    mainFrame.BorderSizePixel = 0
    
    local innerFrame = Instance.new("Frame", popupGui)
    innerFrame.Size = UDim2.new(0, 350, 0, 220)
    innerFrame.Position = UDim2.new(0.5, -175, 0.5, -110)
    innerFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    innerFrame.BorderSizePixel = 0
    makeDraggable(innerFrame, innerFrame)
    
    local innerCorner = Instance.new("UICorner", innerFrame)
    innerCorner.CornerRadius = UDim.new(0, 12)
    
    local titleBar = Instance.new("Frame", innerFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 40, 50)
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    
    local titleCorner = Instance.new("UICorner", titleBar)
    titleCorner.CornerRadius = UDim.new(0, 12, 0, 0)
    
    local titleText = Instance.new("TextLabel", titleBar)
    titleText.Size = UDim2.new(1, -40, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.Text = "⚠️ Wrong Game ID Detected"
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 16
    titleText.TextColor3 = Color3.fromRGB(255, 100, 0)
    titleText.BackgroundTransparency = 1
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -12.5)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.BorderSizePixel = 0
    
    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        popupGui:Destroy()
    end)
    
    local content = Instance.new("TextLabel", innerFrame)
    content.Size = UDim2.new(1, -20, 0, 80)
    content.Position = UDim2.new(0, 10, 0, 40)
    content.Text = "Script '" .. scriptInfo.name .. "' requires Game ID: " .. requiredPlaceId .. "\n\nCurrent Game ID: " .. currentPlaceId .. "\n\nDo you want to teleport to the correct game or use it in current game?"
    content.Font = Enum.Font.Gotham
    content.TextSize = 13
    content.TextColor3 = Color3.new(1, 1, 1)
    content.BackgroundTransparency = 1
    content.TextWrapped = true
    content.TextXAlignment = Enum.TextXAlignment.Left
    
    local teleportBtn = Instance.new("TextButton", innerFrame)
    teleportBtn.Size = UDim2.new(0, 140, 0, 40)
    teleportBtn.Position = UDim2.new(0.5, -150, 1, -70)
    teleportBtn.Text = "🚀 Teleport"
    teleportBtn.Font = Enum.Font.GothamBold
    teleportBtn.TextSize = 14
    teleportBtn.TextColor3 = Color3.new(1, 1, 1)
    teleportBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    teleportBtn.BorderSizePixel = 0
    
    local teleportCorner = Instance.new("UICorner", teleportBtn)
    teleportCorner.CornerRadius = UDim.new(0, 8)
    
    local hereBtn = Instance.new("TextButton", innerFrame)
    hereBtn.Size = UDim2.new(0, 140, 0, 40)
    hereBtn.Position = UDim2.new(0.5, 10, 1, -70)
    hereBtn.Text = "🎮 Use Here"
    hereBtn.Font = Enum.Font.GothamBold
    hereBtn.TextSize = 14
    hereBtn.TextColor3 = Color3.new(1, 1, 1)
    hereBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    hereBtn.BorderSizePixel = 0
    
    local hereCorner = Instance.new("UICorner", hereBtn)
    hereCorner.CornerRadius = UDim.new(0, 8)
    
    local cancelBtn = Instance.new("TextButton", innerFrame)
    cancelBtn.Size = UDim2.new(0, 100, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, -50, 1, -30)
    cancelBtn.Text = "❌ Cancel"
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 12
    cancelBtn.TextColor3 = Color3.new(1, 1, 1)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    cancelBtn.BorderSizePixel = 0
    
    local cancelCorner = Instance.new("UICorner", cancelBtn)
    cancelCorner.CornerRadius = UDim.new(0, 6)
    
    local result = nil
    
    teleportBtn.MouseButton1Click:Connect(function()
        result = "teleport"
        showNotification("🚀 Teleporting to game ID: " .. requiredPlaceId, Color3.fromRGB(79, 124, 255))
        popupGui:Destroy()
        
        local success, errorMsg = pcall(function()
            teleportService:Teleport(tonumber(requiredPlaceId), player)
        end)
        
        if not success then
            showNotification("❌ Teleport failed: " .. tostring(errorMsg), Color3.fromRGB(255, 50, 50))
        end
    end)
    
    hereBtn.MouseButton1Click:Connect(function()
        result = "here"
        showNotification("🎮 Using script in current game (ID: " .. currentPlaceId .. ")", Color3.fromRGB(40, 200, 80))
        popupGui:Destroy()
        return true
    end)
    
    cancelBtn.MouseButton1Click:Connect(function()
        result = "cancel"
        showNotification("❌ Script execution cancelled", Color3.fromRGB(255, 100, 100))
        popupGui:Destroy()
    end)
    
    innerFrame.BackgroundTransparency = 0
    tweenService:Create(innerFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    
    while popupGui.Parent do
        task.wait()
    end
    
    return result == "here"
end

-- Validate key
local function validateKey(inputKey, useCache)
    local gameData = (useCache and currentGameData) or refreshData()
    
    if not gameData then
        print("❌ No game data available")
        return false, "❌ No data available"
    end
    
    -- Check bans
    if gameData.bans then
        if gameData.bans[username] then
            kickPlayer(gameData.bans[username].reason)
            return false, "❌ Banned"
        elseif gameData.bans[userId] then
            kickPlayer(gameData.bans[userId].reason)
            return false, "❌ Banned"
        end
    end
    
    -- Check notifications
    if (gameData.notifications and gameData.notifications[username]) then
        local notif = gameData.notifications[username]
        if (notif.time > notificationTime) then
            notificationTime = notif.time
            if (notif.type == "revoke") then
                showNotification("⚠️ Admin has revoked your key!", Color3.fromRGB(255, 50, 50))
            elseif (notif.type == "renew") then
                showNotification("✅ Key renewed by Admin!", Color3.fromRGB(50, 255, 50))
            elseif (notif.type == "permanent") then
                showNotification("💎 Key is now PERMANENT!", Color3.fromRGB(0, 200, 255))
            end
        end
    end
    
    if (not inputKey or (inputKey == "")) then
        return false, "❌ No key provided"
    end
    
    if not gameData.keys then
        print("❌ No keys found in database")
        return false, "❌ No keys found in database"
    end
    
    print("🔑 Validating key:", inputKey)
    print("📊 Keys in database:", tostring(gameData.keys))
    
    local keyData = nil
    local keyName = nil
    
    for k, v in pairs(gameData.keys) do
        if (k == inputKey) then
            keyData = v
            keyName = k
            print("✅ Key found in database!")
            break
        end
    end
    
    if not keyData then
        print("❌ Key not found in database")
        local availableKeys = {}
        for k, v in pairs(gameData.keys) do
            table.insert(availableKeys, k)
        end
        print("🔑 Available keys:", table.concat(availableKeys, ", "))
        return false, "❌ Invalid Key"
    end
    
    local keyUserId = tostring(keyData.rbx)
    print("[RSQ] Key's user ID:", keyUserId, "vs", userId)
    
    if (keyUserId ~= userId) then
        return false, "❌ ID Mismatch. This key belongs to user ID: " .. keyUserId
    end
    
    if (keyData.exp ~= "permanent") then
        local expiryTime = tonumber(keyData.exp)
        if expiryTime then
            local currentTime = os.time()
            print("⏰ Key expiry:", expiryTime, "Current time:", currentTime)
            if (currentTime > expiryTime) then
                return false, "❌ Expired"
            end
        end
    end
    
    print("✅ Key is valid!")
    return true, keyData
end

-- Check game ID match
local function checkGameID(scriptInfo, gameInfo)
    local currentId = tostring(game.PlaceId)
    local requiredId = tostring(gameInfo.id)
    
    if (currentId == requiredId) then
        return true
    else
        local result = showGameMismatchPopup(scriptInfo, gameInfo)
        return result
    end
end

-- Show group join required GUI
local function showGroupRequiredGUI()
    local groupGui = Instance.new("ScreenGui", coreGui)
    groupGui.Name = "RSQ_GroupRequired"
    groupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local mainFrame = Instance.new("Frame", groupGui)
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 250)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    makeDraggable(mainFrame, mainFrame)
    
    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 12)
    
    local topBar = Instance.new("Frame", mainFrame)
    topBar.Size = UDim2.new(1, 0, 0, 35)
    topBar.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    topBar.BackgroundTransparency = 0.95
    topBar.BorderSizePixel = 0
    
    local topCorner = Instance.new("UICorner", topBar)
    topCorner.CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", topBar)
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "🚫 ACCESS DENIED"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeBtn = Instance.new("TextButton", topBar)
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -12.5)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.BorderSizePixel = 0
    
    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        groupGui:Destroy()
    end)
    
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Size = UDim2.new(1, -20, 1, -80)
    contentFrame.Position = UDim2.new(0, 10, 0, 40)
    contentFrame.BackgroundTransparency = 1
    
    local warningIcon = Instance.new("TextLabel", contentFrame)
    warningIcon.Size = UDim2.new(0, 40, 0, 40)
    warningIcon.Position = UDim2.new(0, 10, 0, 10)
    warningIcon.Text = "⚠️"
    warningIcon.Font = Enum.Font.GothamBold
    warningIcon.TextSize = 24
    warningIcon.TextColor3 = Color3.fromRGB(255, 200, 0)
    warningIcon.BackgroundTransparency = 1
    
    local warningText = Instance.new("TextLabel", contentFrame)
    warningText.Size = UDim2.new(1, -60, 0, 80)
    warningText.Position = UDim2.new(0, 60, 0, 10)
    warningText.Text = "𝙔𝙊𝙐 𝙈𝙐𝙎𝙏 𝙅𝙊𝙄𝙉 𝙏𝙃𝙀 𝙂𝙍𝙊𝙐𝙋 𝘽𝙀𝙁𝙊𝙍𝙀 𝘼𝘾𝘾𝙀𝙎𝙎𝙄𝙉𝙂 𝙏𝙃𝙀 𝙐𝙄!\n\n𝙉𝙤 𝙛𝙧𝙖𝙢𝙚𝙨 𝙬𝙞𝙡𝙡 𝙨𝙝𝙤𝙬 𝙪𝙣𝙩𝙞𝙇 𝙮𝙤𝙪 𝙟𝙤𝙞𝙣 𝙩𝙝𝙚 𝙜𝙧𝙤𝙪𝙥."
    warningText.Font = Enum.Font.GothamBold
    warningText.TextSize = 14
    warningText.TextColor3 = Color3.new(1, 1, 1)
    warningText.BackgroundTransparency = 1
    warningText.TextWrapped = true
    warningText.TextXAlignment = Enum.TextXAlignment.Left
    
    local groupInfo = Instance.new("TextLabel", contentFrame)
    groupInfo.Size = UDim2.new(1, -20, 0, 40)
    groupInfo.Position = UDim2.new(0, 10, 0, 100)
    groupInfo.Text = "📋 Group ID: 687789545\n🏷️ Group Name: CASHGRAB-EXPERIENCE"
    groupInfo.Font = Enum.Font.Gotham
    groupInfo.TextSize = 12
    groupInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    groupInfo.BackgroundTransparency = 1
    groupInfo.TextWrapped = true
    groupInfo.TextXAlignment = Enum.TextXAlignment.Left
    
    local copyBtn = Instance.new("TextButton", mainFrame)
    copyBtn.Size = UDim2.new(0, 180, 0, 40)
    copyBtn.Position = UDim2.new(0.5, -90, 1, -65)
    copyBtn.Text = "📋 Copy Group Link"
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 13
    copyBtn.TextColor3 = Color3.new(1, 1, 1)
    copyBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    copyBtn.BorderSizePixel = 0
    
    local copyCorner = Instance.new("UICorner", copyBtn)
    copyCorner.CornerRadius = UDim.new(0, 8)
    
    copyBtn.MouseButton1Click:Connect(function()
        setclipboard(groupLink)
        showNotification("✅ Group link copied to clipboard!", Color3.fromRGB(40, 200, 80))
    end)
    
    local merchBtn = Instance.new("TextButton", mainFrame)
    merchBtn.Size = UDim2.new(0, 150, 0, 40)
    merchBtn.Position = UDim2.new(0.5, -75, 1, -115)
    merchBtn.Text = "🛒 Buy My Merch"
    merchBtn.Font = Enum.Font.GothamBold
    merchBtn.TextSize = 13
    merchBtn.TextColor3 = Color3.new(1, 1, 1)
    merchBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    merchBtn.BorderSizePixel = 0
    
    local merchCorner = Instance.new("UICorner", merchBtn)
    merchCorner.CornerRadius = UDim.new(0, 8)
    
    merchBtn.MouseButton1Click:Connect(function()
        setclipboard(merchLink)
        showNotification("✅ Merch link copied to clipboard!", Color3.fromRGB(255, 140, 0))
    end)
    
    local checkBtn = Instance.new("TextButton", mainFrame)
    checkBtn.Size = UDim2.new(0, 160, 0, 30)
    checkBtn.Position = UDim2.new(0.5, -80, 1, -25)
    checkBtn.Text = "🔄 Check Membership"
    checkBtn.Font = Enum.Font.GothamBold
    checkBtn.TextSize = 12
    checkBtn.TextColor3 = Color3.new(1, 1, 1)
    checkBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    checkBtn.BorderSizePixel = 0
    
    local checkCorner = Instance.new("UICorner", checkBtn)
    checkCorner.CornerRadius = UDim.new(0, 6)
    
    checkBtn.MouseButton1Click:Connect(function()
        showNotification("⏳ Checking group membership...", Color3.fromRGB(79, 124, 255))
        local isMember = checkGroupMembership()
        
        if isMember then
            showNotification("✅ You're in the group! GUI will now show.", Color3.fromRGB(40, 200, 80))
            groupGui:Destroy()
            
            local hasKey = loadLocalKey()
            if hasKey then
                print("🔑 Loaded saved key:", savedKey)
                local valid, keyInfo = validateKey(savedKey, false)
                if valid then
                    showAdvancedGamesGUI()
                else
                    showKeyGUI()
                end
            else
                showKeyGUI()
            end
        else
            showNotification("❌ Still not in the group. Please join first!", Color3.fromRGB(255, 50, 50))
        end
    end)
    
    mainFrame.BackgroundTransparency = 1
    tweenService:Create(mainFrame, TweenInfo.new(0.5), {BackgroundTransparency = 0.1}):Play()
    
    return groupGui
end

-- Show temporary notification (fly-in)
local function showTempNotification()
    local notifGui = Instance.new("ScreenGui", coreGui)
    notifGui.Name = "RSQ_TempNotif"
    notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local frame = Instance.new("Frame", notifGui)
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(1, 10, 0.8, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)
    
    local leftBar = Instance.new("Frame", frame)
    leftBar.Size = UDim2.new(0, 5, 1, 0)
    leftBar.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    leftBar.BorderSizePixel = 0
    
    local leftCorner = Instance.new("UICorner", leftBar)
    leftCorner.CornerRadius = UDim.new(0, 2)
    
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 15, 0, 10)
    title.Text = "📢 REMINDER"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255, 200, 0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local message = Instance.new("TextLabel", frame)
    message.Size = UDim2.new(1, -20, 0, 40)
    message.Position = UDim2.new(0, 15, 0, 40)
    message.Text = "Join the group to access the UI!"
    message.Font = Enum.Font.Gotham
    message.TextSize = 14
    message.TextColor3 = Color3.fromRGB(200, 200, 200)
    message.BackgroundTransparency = 1
    message.TextXAlignment = Enum.TextXAlignment.Left
    
    frame:TweenPosition(UDim2.new(1, -310, 0.8, 0), "Out", "Quad", 0.5)
    
    task.delay(8, function()
        pcall(function()
            frame:TweenPosition(UDim2.new(1, 10, 0.8, 0), "Out", "Quad", 0.5)
            task.wait(0.5)
            notifGui:Destroy()
        end)
    end)
    
    return notifGui
end

-- Show key input GUI
local function showKeyGUI()
    if not inGroup then
        showNotification("❌ You must join the group first!", Color3.fromRGB(255, 50, 50))
        showGroupRequiredGUI()
        return
    end
    
    if isGUIAlreadyOpen() then
        showNotification("⚠️ GUI is already open!", Color3.fromRGB(255, 140, 0))
        return
    end
    
    if (mainGui and mainGui.Parent) then
        mainGui:Destroy()
        mainGui = nil
    end
    
    guiOpen = true
    databaseError = true
    
    print("🔐 Creating key GUI...")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RSQ_KeyGUI"
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = coreGui
    mainGui = screenGui
    
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, 350, 0, 250)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -125)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    makeDraggable(mainFrame, mainFrame)
    
    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 12)
    
    local topBar = Instance.new("Frame", mainFrame)
    topBar.Size = UDim2.new(1, 0, 0, 35)
    topBar.BackgroundColor3 = Color3.fromRGB(30, 40, 50)
    topBar.BackgroundTransparency = 0.95
    topBar.BorderSizePixel = 0
    
    local topCorner = Instance.new("UICorner", topBar)
    topCorner.CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", topBar)
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Text = "🔐 RSQ Key System"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    
    local closeBtn = Instance.new("TextButton", topBar)
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -30, 0.5, -12.5)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.BorderSizePixel = 0
    
    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 6)
    
    closeBtn.MouseButton1Click:Connect(function()
        guiOpen = false
        screenGui:Destroy()
        mainGui = nil
    end)
    
    local keyBox = Instance.new("TextBox", mainFrame)
    keyBox.PlaceholderText = "Enter your key here..."
    keyBox.Size = UDim2.new(1, -30, 0, 35)
    keyBox.Position = UDim2.new(0, 15, 0, 45)
    keyBox.Font = Enum.Font.Gotham
    keyBox.TextSize = 13
    keyBox.TextColor3 = Color3.new(1, 1, 1)
    keyBox.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    keyBox.BorderSizePixel = 0
    
    local keyCorner = Instance.new("UICorner", keyBox)
    keyCorner.CornerRadius = UDim.new(0, 8)
    
    local authBtn = Instance.new("TextButton", mainFrame)
    authBtn.Text = "🔑 Authenticate"
    authBtn.Size = UDim2.new(1, -30, 0, 35)
    authBtn.Position = UDim2.new(0, 15, 0, 90)
    authBtn.Font = Enum.Font.GothamBold
    authBtn.TextSize = 13
    authBtn.TextColor3 = Color3.new(1, 1, 1)
    authBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
    authBtn.BorderSizePixel = 0
    
    local authCorner = Instance.new("UICorner", authBtn)
    authCorner.CornerRadius = UDim.new(0, 8)
    
    local getKeyBtn = Instance.new("TextButton", mainFrame)
    getKeyBtn.Text = "🌐 Get Key"
    getKeyBtn.Size = UDim2.new(1, -30, 0, 30)
    getKeyBtn.Position = UDim2.new(0, 15, 0, 135)
    getKeyBtn.Font = Enum.Font.GothamBold
    getKeyBtn.TextSize = 12
    getKeyBtn.TextColor3 = Color3.new(1, 1, 1)
    getKeyBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    getKeyBtn.BorderSizePixel = 0
    
    local getKeyCorner = Instance.new("UICorner", getKeyBtn)
    getKeyCorner.CornerRadius = UDim.new(0, 8)
    
    local statusLabel = Instance.new("TextLabel", mainFrame)
    statusLabel.Position = UDim2.new(0, 15, 0, 175)
    statusLabel.Size = UDim2.new(1, -30, 0, 50)
    statusLabel.TextWrapped = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Enter your key to access the RSQ Game Library"
    
    tweenService:Create(mainFrame, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
    
    authBtn.MouseButton1Click:Connect(function()
        local enteredKey = extractKey(keyBox.Text)
        if (enteredKey == "") then
            return
        end
        
        statusLabel.Text = "⚡ Checking..."
        print("🔑 Validating key:", enteredKey)
        print("👤 User ID:", userId)
        print("👤 Username:", username)
        
        local success, keyInfo = validateKey(enteredKey, true)
        
        if not success then
            print("❌ Validation failed:", keyInfo)
            success, keyInfo = validateKey(enteredKey, false)
        end
        
        if success then
            local validCount = 0
            savedKey = enteredKey
            keyActive = true
            statusLabel.Text = "✅ Success! Loading..."
            sendWebhook("auth", enteredKey, keyInfo.exp)
            saveKeyLocally()
            
            tweenService:Create(mainFrame, TweenInfo.new(0.3), {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 1, 0)
            }):Play()
            
            task.delay(0.3, function()
                screenGui:Destroy()
                mainGui = nil
                guiOpen = false
                showAdvancedGamesGUI()
            end)
        else
            statusLabel.Text = keyInfo
            print("❌ Validation failed:", keyInfo)
            
            if ((keyInfo == "❌ Expired") or (keyInfo == "❌ Invalid Key")) then
                deleteLocalKey()
                savedKey = nil
                keyActive = false
            end
        end
    end)
    
    getKeyBtn.MouseButton1Click:Connect(function()
        setclipboard(groupLink)
        statusLabel.Text = "📋 Link Copied!"
    end)
end

-- Show advanced games GUI
local function showAdvancedGamesGUI()
    if not inGroup then
        showNotification("❌ You must join the group first!", Color3.fromRGB(255, 50, 50))
        showGroupRequiredGUI()
        return
    end
    
    if isGUIAlreadyOpen() then
        showNotification("⚠️ GUI is already open!", Color3.fromRGB(255, 140, 0))
        return
    end
    
    if (mainGui and mainGui.Parent) then
        mainGui:Destroy()
        mainGui = nil
    end
    
    guiOpen = true
    databaseError = true
    
    print("🎮 Creating advanced games GUI...")
    print("📚 Games loaded:", #loadedScripts)
    
    refreshData()
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RSQ_GUI"
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = coreGui
    mainGui = screenGui
    
    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Size = UDim2.new(0, 450, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -225, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    makeDraggable(mainFrame, mainFrame)
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 12)
    
    local topBar = Instance.new("Frame", mainFrame)
    topBar.Size = UDim2.new(1, 0, 0, 40)
    topBar.BackgroundColor3 = Color3.fromRGB(30, 40, 55)
    topBar.BackgroundTransparency = 0.95
    topBar.BorderSizePixel = 0
    
    local topCorner = Instance.new("UICorner", topBar)
    topCorner.CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", topBar)
    title.Size = UDim2.new(1, -45, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.Text = "🎮 RSQ GAMES LIBRARY"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeBtn = Instance.new("TextButton", topBar)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0.5, -15)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.BorderSizePixel = 0
    
    local closeCorner = Instance.new("UICorner", closeBtn)
    closeCorner.CornerRadius = UDim.new(0, 8)
    
    closeBtn.MouseButton1Click:Connect(function()
        guiOpen = false
        screenGui:Destroy()
        mainGui = nil
    end)
    
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Size = UDim2.new(1, -20, 1, -60)
    contentFrame.Position = UDim2.new(0, 10, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ClipsDescendants = true
    
    local gamesList = Instance.new("ScrollingFrame", contentFrame)
    gamesList.Size = UDim2.new(1, 0, 1, 0)
    gamesList.BackgroundTransparency = 1
    gamesList.ScrollBarThickness = 4
    gamesList.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    gamesList.CanvasSize = UDim2.new(0, 0, 0, 0)
    gamesList.Visible = true
    
    local listLayout = Instance.new("UIListLayout", gamesList)
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local currentGameInfo = nil
    local scriptsFrame = nil
    
    -- Function to show scripts for a game
    local function showScriptsForGame(gameInfo)
        local isValid = checkGameID(gameInfo, gameInfo)
        
        if isValid then
            showNotification("⚡ Loading script: " .. gameInfo.name, Color3.fromRGB(79, 124, 255))
            local success, errorMsg = pcall(function()
                local scriptUrl = game:HttpGet(gameInfo.url)
                loadstring(scriptUrl)()
            end)
            
            if success then
                showNotification("✅ Script loaded successfully!", Color3.fromRGB(40, 200, 80))
            else
                showNotification("❌ Failed to load script: " .. tostring(errorMsg), Color3.fromRGB(255, 50, 50))
            end
        else
            showNotification("❌ Game ID mismatch. Cannot load script.", Color3.fromRGB(255, 100, 0))
        end
    end
    
    -- Function to handle game selection
    local function onGameSelected(selectedGame)
        print("🎮 Selected game:", selectedGame.name)
        print("📜 Scripts count:", #(selectedGame.scripts or {}))
        
        currentGameInfo = selectedGame
        gamesList.Visible = false
        
        if scriptsFrame then
            scriptsFrame:Destroy()
            scriptsFrame = nil
        end
        
        scriptsFrame = Instance.new("ScrollingFrame", contentFrame)
        scriptsFrame.Name = "ScriptsFrame"
        scriptsFrame.Size = UDim2.new(1, 0, 1, 0)
        scriptsFrame.Position = UDim2.new(0, 0, 0, 0)
        scriptsFrame.BackgroundTransparency = 1
        scriptsFrame.ScrollBarThickness = 4
        scriptsFrame.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
        scriptsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scriptsFrame.Visible = true
        
        local scriptsLayout = Instance.new("UIListLayout", scriptsFrame)
        scriptsLayout.Padding = UDim.new(0, 8)
        scriptsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        
        title.Text = "📜 Scripts - " .. selectedGame.name
        
        local scripts = selectedGame.scripts or {}
        
        if (#scripts == 0) then
            local noScripts = Instance.new("TextLabel", scriptsFrame)
            noScripts.Size = UDim2.new(1, 0, 0, 50)
            noScripts.Text = "📭 No scripts available for this game."
            noScripts.Font = Enum.Font.Gotham
            noScripts.TextSize = 13
            noScripts.TextColor3 = Color3.fromRGB(150, 150, 150)
            noScripts.BackgroundTransparency = 1
            noScripts.TextWrapped = true
            noScripts.LayoutOrder = 1
        else
            for idx, scriptData in ipairs(scripts) do
                if (scriptData and scriptData.name and scriptData.url) then
                    print("📜 Loading script:", scriptData.name)
                    
                    local scriptItem = Instance.new("Frame", scriptsFrame)
                    scriptItem.Size = UDim2.new(1, 0, 0, 70)
                    scriptItem.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
                    scriptItem.BackgroundTransparency = 0.3
                    scriptItem.BorderSizePixel = 0
                    
                    local itemCorner = Instance.new("UICorner", scriptItem)
                    itemCorner.CornerRadius = UDim.new(0, 8)
                    
                    scriptItem.LayoutOrder = idx
                    
                    local textFrame = Instance.new("Frame", scriptItem)
                    textFrame.Size = UDim2.new(0.7, -10, 1, 0)
                    textFrame.Position = UDim2.new(0, 5, 0, 0)
                    textFrame.BackgroundTransparency = 1
                    
                    local scriptName = Instance.new("TextLabel", textFrame)
                    scriptName.Size = UDim2.new(1, -10, 0, 25)
                    scriptName.Position = UDim2.new(0, 5, 0, 5)
                    scriptName.Text = scriptData.name
                    scriptName.Font = Enum.Font.GothamBold
                    scriptName.TextSize = 13
                    scriptName.TextColor3 = Color3.new(1, 1, 1)
                    scriptName.TextXAlignment = Enum.TextXAlignment.Left
                    scriptName.BackgroundTransparency = 1
                    
                    local scriptUrl = Instance.new("TextLabel", textFrame)
                    scriptUrl.Size = UDim2.new(1, -10, 0, 20)
                    scriptUrl.Position = UDim2.new(0, 5, 0, 30)
                    scriptUrl.Text = "📎 " .. string.sub(scriptData.url, 1, 25) .. "..."
                    scriptUrl.Font = Enum.Font.Gotham
                    scriptUrl.TextSize = 11
                    scriptUrl.TextColor3 = Color3.fromRGB(200, 200, 150)
                    scriptUrl.TextXAlignment = Enum.TextXAlignment.Left
                    scriptUrl.BackgroundTransparency = 1
                    
                    local gameIdLabel = Instance.new("TextLabel", textFrame)
                    gameIdLabel.Size = UDim2.new(1, -10, 0, 20)
                    gameIdLabel.Position = UDim2.new(0, 5, 0, 50)
                    gameIdLabel.Text = "🎮 Game ID: " .. selectedGame.id
                    gameIdLabel.Font = Enum.Font.Gotham
                    gameIdLabel.TextSize = 10
                    gameIdLabel.TextColor3 = Color3.fromRGB(79, 124, 255)
                    gameIdLabel.TextXAlignment = Enum.TextXAlignment.Left
                    gameIdLabel.BackgroundTransparency = 1
                    
                    local execBtn = Instance.new("TextButton", scriptItem)
                    execBtn.Size = UDim2.new(0, 80, 0, 30)
                    execBtn.Position = UDim2.new(1, -90, 0.5, -15)
                    execBtn.Text = "⚡ Execute"
                    execBtn.Font = Enum.Font.GothamBold
                    execBtn.TextSize = 11
                    execBtn.TextColor3 = Color3.new(1, 1, 1)
                    execBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
                    execBtn.BackgroundTransparency = 0.2
                    execBtn.BorderSizePixel = 0
                    
                    local execCorner = Instance.new("UICorner", execBtn)
                    execCorner.CornerRadius = UDim.new(0, 6)
                    
                    local currentScript = scriptData
                    local currentGame = selectedGame
                    
                    execBtn.MouseButton1Click:Connect(function()
                        showScriptsForGame(currentScript, currentGame)
                    end)
                end
            end
        end
        
        task.wait(0.1)
        local totalHeight = 0
        for _, child in ipairs(scriptsFrame:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + scriptsLayout.Padding.Offset
            end
        end
        scriptsFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
    end
    
    -- Function to go back to games list
    local function backToGamesList()
        if scriptsFrame then
            scriptsFrame.Visible = false
        end
        gamesList.Visible = true
        title.Text = "🎮 RSQ GAMES LIBRARY"
    end
    
    -- Populate games list
    local function populateGamesList()
        for _, child in ipairs(gamesList:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        print("🎮 Populating games list, count:", #loadedScripts)
        
        if (not loadedScripts or (#loadedScripts == 0)) then
            local emptyLabel = Instance.new("TextLabel", gamesList)
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
        
        print("📋 Creating game buttons...")
        
        for idx, game in ipairs(loadedScripts) do
            if (game and game.id and game.name) then
                print("➕ Adding game:", game.name, "ID:", game.id)
                
                local gameItem = Instance.new("Frame", gamesList)
                gameItem.Size = UDim2.new(1, 0, 0, 70)
                gameItem.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
                gameItem.BackgroundTransparency = 0.3
                gameItem.BorderSizePixel = 0
                
                local itemCorner = Instance.new("UICorner", gameItem)
                itemCorner.CornerRadius = UDim.new(0, 8)
                
                local textFrame = Instance.new("Frame", gameItem)
                textFrame.Size = UDim2.new(0.7, -10, 1, 0)
                textFrame.Position = UDim2.new(0, 5, 0, 0)
                textFrame.BackgroundTransparency = 1
                
                local gameName = Instance.new("TextLabel", textFrame)
                gameName.Size = UDim2.new(1, -10, 0, 25)
                gameName.Position = UDim2.new(0, 5, 0, 5)
                gameName.Text = game.name
                gameName.Font = Enum.Font.GothamBold
                gameName.TextSize = 14
                gameName.TextColor3 = Color3.new(1, 1, 1)
                gameName.TextXAlignment = Enum.TextXAlignment.Left
                gameName.BackgroundTransparency = 1
                
                local gameId = Instance.new("TextLabel", textFrame)
                gameId.Size = UDim2.new(1, -10, 0, 20)
                gameId.Position = UDim2.new(0, 5, 0, 30)
                gameId.Text = "🆔 ID: " .. game.id
                gameId.Font = Enum.Font.Gotham
                gameId.TextSize = 12
                gameId.TextColor3 = Color3.fromRGB(150, 150, 150)
                gameId.TextXAlignment = Enum.TextXAlignment.Left
                gameId.BackgroundTransparency = 1
                
                local scriptCount = game.scripts or {}
                local countLabel = Instance.new("TextLabel", textFrame)
                countLabel.Size = UDim2.new(1, -10, 0, 15)
                countLabel.Position = UDim2.new(0, 5, 0, 50)
                countLabel.Text = "📜 " .. #scriptCount .. " script" .. (((#scriptCount == 1) and "") or "s")
                countLabel.Font = Enum.Font.Gotham
                countLabel.TextSize = 10
                countLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
                countLabel.TextXAlignment = Enum.TextXAlignment.Left
                countLabel.BackgroundTransparency = 1
                
                local viewBtn = Instance.new("TextButton", gameItem)
                viewBtn.Size = UDim2.new(0, 70, 0, 35)
                viewBtn.Position = UDim2.new(1, -80, 0.5, -17.5)
                viewBtn.Text = "📜 View"
                viewBtn.Font = Enum.Font.GothamBold
                viewBtn.TextSize = 11
                viewBtn.TextColor3 = Color3.new(1, 1, 1)
                viewBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
                viewBtn.BackgroundTransparency = 0.2
                viewBtn.BorderSizePixel = 0
                
                local viewCorner = Instance.new("UICorner", viewBtn)
                viewCorner.CornerRadius = UDim.new(0, 6)
                
                local selectedGame = game
                
                viewBtn.MouseButton1Click:Connect(function()
                    print("🎮 View button clicked for:", selectedGame.name)
                    print("📜 Scripts available:", #(selectedGame.scripts or {}))
                    onGameSelected(selectedGame)
                end)
            else
                print("⚠️ Invalid game data:", game)
            end
        end
        
        task.wait(0.1)
        local totalHeight = 0
        for _, child in ipairs(gamesList:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + listLayout.Padding.Offset
            end
        end
        gamesList.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    -- Back button
    local backBtn = Instance.new("TextButton", topBar)
    backBtn.Name = "BackButton"
    backBtn.Size = UDim2.new(0, 80, 0, 25)
    backBtn.Position = UDim2.new(0, 10, 0.5, -12.5)
    backBtn.Text = "← Back"
    backBtn.Font = Enum.Font.GothamBold
    backBtn.TextSize = 11
    backBtn.TextColor3 = Color3.new(1, 1, 1)
    backBtn.BackgroundColor3 = Color3.fromRGB(60, 70, 85)
    backBtn.Visible = false
    backBtn.BorderSizePixel = 0
    
    local backCorner = Instance.new("UICorner", backBtn)
    backCorner.CornerRadius = UDim.new(0, 6)
    
    backBtn.MouseButton1Click:Connect(function()
        backToGamesList()
        backBtn.Visible = false
    end)
    
    -- Override onGameSelected to show back button
    local originalOnGameSelected = onGameSelected
    function onGameSelected(gameInfo)
        originalOnGameSelected(gameInfo)
        backBtn.Visible = true
    end
    
    -- Refresh button
    local refreshBtn = Instance.new("TextButton", mainFrame)
    refreshBtn.Size = UDim2.new(0, 100, 0, 25)
    refreshBtn.Position = UDim2.new(0.5, -50, 1, -30)
    refreshBtn.Text = "🔄 Refresh"
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 11
    refreshBtn.TextColor3 = Color3.new(1, 1, 1)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    refreshBtn.BackgroundTransparency = 0.2
    refreshBtn.BorderSizePixel = 0
    
    local refreshCorner = Instance.new("UICorner", refreshBtn)
    refreshCorner.CornerRadius = UDim.new(0, 6)
    
    refreshBtn.MouseButton1Click:Connect(function()
        showNotification("🔄 Refreshing data...", Color3.fromRGB(79, 124, 255))
        refreshData()
        print("📚 Games after refresh:", #loadedScripts)
        populateGamesList()
        backToGamesList()
        backBtn.Visible = false
    end)
    
    populateGamesList()
    
    mainFrame.BackgroundTransparency = 1
    tweenService:Create(mainFrame, TweenInfo.new(0.5), {BackgroundTransparency = 0.1}):Play()
end

-- Main initialization
local function initialize()
    fetchingData = true
    task.wait(1)
    
    local groupStatus = checkGroupMembership()
    
    if not groupStatus then
        showGroupRequiredGUI()
        local reminderTime = 30
        
        task.spawn(function()
            while not inGroup do
                task.wait(reminderTime)
                showNotification("📢 REMINDER: Join the group to access the UI!", Color3.fromRGB(255, 140, 0))
                showTempNotification()
                checkGroupMembership()
            end
        end)
        
        repeat
            task.wait(5)
            checkGroupMembership()
        until inGroup
        
        showNotification("✅ You're now in the group! Loading UI...", Color3.fromRGB(40, 200, 80))
    end
    
    local hasLocalKey = loadLocalKey()
    
    if hasLocalKey then
        showNotification("🔑 Found saved key! Validating...", Color3.fromRGB(79, 124, 255))
        print("🔑 Loaded saved key:", savedKey)
        
        local valid, keyInfo = validateKey(savedKey, false)
        
        if valid then
            showNotification("✅ Key validated successfully!", Color3.fromRGB(40, 200, 80))
            task.wait(1)
            showAdvancedGamesGUI()
            
            for _, scriptUrl in ipairs(gamesList) do
                task.spawn(function()
                    pcall(function()
                        local content = game:HttpGet(scriptUrl)
                        loadstring(content)()
                    end)
                end)
            end
        else
            showNotification("❌ Saved key is invalid: " .. keyInfo, Color3.fromRGB(255, 50, 50))
            deleteLocalKey()
            savedKey = nil
            keyActive = false
            showKeyGUI()
        end
    else
        showKeyGUI()
    end
    
    fetchingData = false
end

task.spawn(function()
    initialize()
end)

-- Periodic validation check
task.spawn(function()
    while true do
        local checkInterval = 1
        if checkInterval == 0 then
            checkInterval = 0
            while true do
                if checkInterval == 0 then
                    task.wait(10)
                    if inGroup then
                        checkGroupMembership()
                    end
                    checkInterval = 1
                end
                if checkInterval == 1 then
                    if (keyActive and savedKey) then
                        local valid, result = validateKey(savedKey, false)
                        if not valid then
                            if inGroup then
                                showAdvancedGamesGUI()
                            else
                                showGroupRequiredGUI()
                            end
                            
                            savedKey = nil
                            deleteLocalKey()
                            
                            if inGroup then
                                showKeyGUI()
                            else
                                showGroupRequiredGUI()
                            end
                            
                            if (mainGui and mainGui.Parent) then
                                mainGui:Destroy()
                                mainGui = nil
                            end
                            guiOpen = false
                        end
                    end
                    break
                end
            end
        end
    end
end)

-- Mini GUI toggle
local function createMiniGUI()
    if not inGroup then
        return
    end
    
    if (miniGui and miniGui.Parent) then
        miniGui:Destroy()
        miniGui = nil
    end
    
    miniGui = Instance.new("ScreenGui")
    miniGui.Name = "RSQ_MiniGUI"
    miniGui.IgnoreGuiInset = true
    miniGui.ResetOnSpawn = false
    miniGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    miniGui.Parent = coreGui
    
    local toggleBtn = Instance.new("TextButton", miniGui)
    toggleBtn.Name = "ToggleButton"
    toggleBtn.Size = UDim2.new(0, 60, 0, 60)
    toggleBtn.Position = UDim2.new(1, -70, 0, 20)
    toggleBtn.Text = (guiOpen and "🔒") or "🔓"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 24
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.BackgroundColor3 = (guiOpen and Color3.fromRGB(255, 140, 0)) or Color3.fromRGB(79, 124, 255)
    toggleBtn.BackgroundTransparency = 0.2
    toggleBtn.BorderSizePixel = 0
    
    local btnCorner = Instance.new("UICorner", toggleBtn)
    btnCorner.CornerRadius = UDim.new(1, 0)
    
    local btnStroke = Instance.new("UIStroke", toggleBtn)
    btnStroke.Color = Color3.new(0, 0, 0)
    btnStroke.Transparency = 0.5
    btnStroke.Thickness = 2
    
    local function toggleGUI()
        if guiOpen then
            local openGuis = {}
            for _, child in pairs(coreGui:GetChildren()) do
                if ((child.Name == "RSQ_GUI") or (child.Name == "RSQ_KeyGUI") or (child.Name == "RSQ_GroupRequired")) then
                    table.insert(openGuis, child)
                end
            end
            
            if player.PlayerGui then
                for _, child in pairs(player.PlayerGui:GetChildren()) do
                    if ((child.Name == "RSQ_GUI") or (child.Name == "RSQ_KeyGUI") or (child.Name == "RSQ_GroupRequired")) then
                        table.insert(openGuis, child)
                    end
                end
            end
            
            for _, gui in ipairs(openGuis) do
                gui:Destroy()
            end
            guiOpen = false
            mainGui = nil
            toggleBtn.Text = "🔓"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        else
            if isGUIAlreadyOpen() then
                showNotification("⚠️ GUI is already open!", Color3.fromRGB(255, 140, 0))
                return
            end
            
            if (keyActive and savedKey) then
                showAdvancedGamesGUI()
            else
                showKeyGUI()
            end
            
            guiOpen = true
            toggleBtn.Text = "🔒"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
        end
    end
    
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    local function updateDrag(input)
        if dragging then
            local delta = input.Position - dragStart
            toggleBtn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end
    
    toggleBtn.InputBegan:Connect(function(input)
        if ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch)) then
            dragging = true
            dragStart = input.Position
            startPos = toggleBtn.Position
            
            input.Changed:Connect(function()
                if (input.UserInputState == Enum.UserInputState.End) then
                    dragging = false
                end
            end)
        end
    end)
    
    toggleBtn.InputChanged:Connect(function(input)
        if ((input.UserInputType == Enum.UserInputType.MouseMovement) or (input.UserInputType == Enum.UserInputType.Touch)) then
            dragStart = input.Position
        end
    end)
    
    userInputService.InputChanged:Connect(function(input)
        if (dragging and ((input == dragStart) or (input.UserInputType == Enum.UserInputType.Touch))) then
            updateDrag(input)
        end
    end)
    
    toggleBtn.MouseButton1Click:Connect(function()
        if not dragging then
            toggleGUI()
        end
    end)
    
    toggleBtn.MouseEnter:Connect(function()
        if not dragging then
            tweenService:Create(toggleBtn, TweenInfo.new(0.2), {Size = UDim2.new(0, 65, 0, 65)}):Play()
        end
    end)
    
    toggleBtn.MouseLeave:Connect(function()
        if not dragging then
            tweenService:Create(toggleBtn, TweenInfo.new(0.2), {Size = UDim2.new(0, 60, 0, 60)}):Play()
        end
    end)
    
    toggleBtn.Position = UDim2.new(1, -70, 0, 20)
    tweenService:Create(toggleBtn, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(1, -70, 0, 20)}):Play()
    
    return miniGui
end

-- Override functions for periodic checks
task.spawn(function()
    local waitTime = 0
    local tempFunc = nil
    local originalFunc = nil
    
    while true do
        if waitTime == 0 then
            repeat
                task.wait(5)
                checkGroupMembership()
            until inGroup
            
            createMiniGUI()
            waitTime = 1
        end
        
        if waitTime == 2 then
            tempFunc = showAdvancedGamesGUI
            
            function showAdvancedGamesGUI(...)
                local result = tempFunc(...)
                task.spawn(tempFunc)
                return result
            end
            break
        end
        
        if waitTime == 1 then
            tempFunc = nil
            
            function tempFunc()
                if guiOpen then
                    while guiOpen do
                        task.wait(300)
                        if guiOpen then
                            showTempNotification()
                        end
                    end
                end
            end
            waitTime = 2
        end
    end
end)
