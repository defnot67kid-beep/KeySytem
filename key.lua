--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to RSQ Elite System - Firebase Integrated Version
]]--

-- Firebase Configuration
local FIREBASE_CONFIG = {
    apiKey = "AIzaSyAupBkllyicDPD9O6CmX4mS4sF5z96mqxc",
    authDomain = "vertexpaste.firebaseapp.com",
    projectId = "vertexpaste",
    storageBucket = "vertexpaste.firebasestorage.app",
    messagingSenderId = "255275350380",
    appId = "1:255275350380:web:7be4e8add2cb5b04045b49"
}

local ADMIN_USERNAME = "plstealme2"
local ADMIN_PASSWORD = "Livetopimo"

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local GroupService = game:GetService("GroupService")

-- Player info
local player = Players.LocalPlayer
local userId = tostring(player.UserId)
local username = player.Name
local displayName = player.DisplayName

-- Constants
local GROUP_ID = 687789545
local CACHE_TTL = 30
local NOTIFICATION_DURATION = 5
local CHAT_MAX_MESSAGES = 100
local KEY_COOLDOWN_HOURS = 24

-- Firebase endpoints
local FIRESTORE_URL = string.format("https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/system/config", FIREBASE_CONFIG.projectId)

-- State variables
local dataCache = nil
local lastFetchTime = 0
local isAdminAuthenticated = false
local currentUser = nil
local currentGameIndex = -1
local unreadCount = 0
local chatUnreadCount = 0
local notifications = {}
local pinnedMessage = nil
local isChatOpen = false
local isDragging = false
local dragOffset = nil
local originalPosition = nil
local keyCooldowns = {}
local bannedUsers = {}
local messageHistory = {}
local typingUsers = {}
local replyTarget = nil
local reactionPopups = {}

-- GUI References
local gui = Instance.new("ScreenGui")
local mainPanel = nil
local chatWindow = nil
local notificationCenter = nil
local adminPanel = nil
local loadingOverlay = nil

-- Utility Functions
local function encodeJSON(data)
    return HttpService:JSONEncode(data)
end

local function decodeJSON(data)
    return HttpService:JSONDecode(data)
end

local function generateRandomKey(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    local key = ""
    for i = 1, length do
        local rand = math.random(1, #chars)
        key = key .. string.sub(chars, rand, rand)
    end
    return key
end

local function moderateText(text)
    if not text then return false end
    local blockedWords = {"badword1", "badword2"} -- Add your blocked words here
    local lowerText = text:lower()
    for _, word in ipairs(blockedWords) do
        if lowerText:find(word) then
            return true
        end
    end
    return false
end

local function formatTime(timestamp)
    if not timestamp then return "Unknown" end
    local date = os.date("*t", timestamp / 1000)
    return string.format("%02d:%02d", date.hour, date.min)
end

local function formatDate(timestamp)
    if not timestamp then return "Unknown" end
    return os.date("%Y-%m-%d %H:%M:%S", timestamp / 1000)
end

local function showLoading(text)
    if loadingOverlay and loadingOverlay.Parent then
        local textLabel = loadingOverlay:FindFirstChild("TextLabel", true)
        if textLabel then
            textLabel.Text = text or "Loading..."
        end
        loadingOverlay.Visible = true
    end
end

local function hideLoading()
    if loadingOverlay then
        loadingOverlay.Visible = false
    end
end

-- Firebase API Functions
local function getFirebaseHeaders()
    return {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json"
    }
end

local function fetchFromFirestore()
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = FIRESTORE_URL,
            Method = "GET",
            Headers = getFirebaseHeaders()
        })
    end)
    
    if success and response.Success and response.StatusCode == 200 then
        local data = decodeJSON(response.Body)
        if data.fields then
            local result = {}
            for key, value in pairs(data.fields) do
                if value.stringValue then
                    result[key] = value.stringValue
                elseif value.integerValue then
                    result[key] = tonumber(value.integerValue)
                elseif value.booleanValue then
                    result[key] = value.booleanValue
                elseif value.arrayValue then
                    result[key] = {}
                    for _, item in ipairs(value.arrayValue.values or {}) do
                        if item.stringValue then
                            table.insert(result[key], item.stringValue)
                        elseif item.mapValue then
                            local obj = {}
                            for k, v in pairs(item.mapValue.fields or {}) do
                                if v.stringValue then
                                    obj[k] = v.stringValue
                                elseif v.integerValue then
                                    obj[k] = tonumber(v.integerValue)
                                end
                            end
                            table.insert(result[key], obj)
                        end
                    end
                elseif value.mapValue then
                    result[key] = {}
                    for k, v in pairs(value.mapValue.fields or {}) do
                        if v.stringValue then
                            result[key][k] = v.stringValue
                        elseif v.integerValue then
                            result[key][k] = tonumber(v.integerValue)
                        elseif v.booleanValue then
                            result[key][k] = v.booleanValue
                        end
                    end
                end
            end
            return result
        end
    end
    return nil
end

local function updateFirestore(data)
    local firestoreData = {
        fields = {}
    }
    
    for key, value in pairs(data) do
        if type(value) == "string" then
            firestoreData.fields[key] = { stringValue = value }
        elseif type(value) == "number" then
            firestoreData.fields[key] = { integerValue = tostring(value) }
        elseif type(value) == "boolean" then
            firestoreData.fields[key] = { booleanValue = value }
        elseif type(value) == "table" then
            if value[1] then -- Array
                firestoreData.fields[key] = { arrayValue = { values = {} } }
                for _, item in ipairs(value) do
                    if type(item) == "string" then
                        table.insert(firestoreData.fields[key].arrayValue.values, { stringValue = item })
                    elseif type(item) == "table" then
                        local mapValue = { mapValue = { fields = {} } }
                        for k, v in pairs(item) do
                            if type(v) == "string" then
                                mapValue.mapValue.fields[k] = { stringValue = v }
                            elseif type(v) == "number" then
                                mapValue.mapValue.fields[k] = { integerValue = tostring(v) }
                            end
                        end
                        table.insert(firestoreData.fields[key].arrayValue.values, mapValue)
                    end
                end
            else -- Object
                firestoreData.fields[key] = { mapValue = { fields = {} } }
                for k, v in pairs(value) do
                    if type(v) == "string" then
                        firestoreData.fields[key].mapValue.fields[k] = { stringValue = v }
                    elseif type(v) == "number" then
                        firestoreData.fields[key].mapValue.fields[k] = { integerValue = tostring(v) }
                    elseif type(v) == "boolean" then
                        firestoreData.fields[key].mapValue.fields[k] = { booleanValue = v }
                    end
                end
            end
        end
    end
    
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = FIRESTORE_URL .. "?updateMask.fieldPaths=users&updateMask.fieldPaths=keys&updateMask.fieldPaths=games&updateMask.fieldPaths=bans&updateMask.fieldPaths=feedbacks&updateMask.fieldPaths=chats&updateMask.fieldPaths=pinned&updateMask.fieldPaths=settings",
            Method = "PATCH",
            Headers = getFirebaseHeaders(),
            Body = encodeJSON(firestoreData)
        })
    end)
    
    return success and response and response.Success
end

local function refreshData()
    local currentTime = os.time()
    if not dataCache or (currentTime - lastFetchTime) > CACHE_TTL then
        local newData = fetchFromFirestore()
        if newData then
            dataCache = newData
            lastFetchTime = currentTime
            
            -- Update banned users
            if dataCache.bans then
                bannedUsers = {}
                for k, v in pairs(dataCache.bans) do
                    if type(k) == "string" then
                        bannedUsers[k] = v
                    end
                end
            end
            
            -- Update pinned message
            pinnedMessage = dataCache.pinned
            
            return true
        end
    end
    return false
end

-- Notification System
local function addNotification(title, message, type, data)
    local notification = {
        id = tick() * 1000 + math.random(1, 1000),
        title = tostring(title),
        message = tostring(message),
        type = type or "info",
        timestamp = os.time() * 1000,
        read = false,
        data = data
    }
    
    table.insert(notifications, 1, notification)
    
    -- Keep only last 50 notifications
    while #notifications > 50 do
        table.remove(notifications)
    end
    
    -- Show floating notification
    local function showFloatingNotif()
        local notif = Instance.new("Frame")
        notif.Name = "FloatingNotification"
        notif.Size = UDim2.new(0, 300, 0, 80)
        notif.Position = UDim2.new(1, -320, 0, 50)
        notif.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
        notif.BackgroundTransparency = 0.1
        notif.BorderSizePixel = 0
        notif.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notif
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 20)
        title.Position = UDim2.new(0, 10, 0, 10)
        title.BackgroundTransparency = 1
        title.Text = title
        title.TextColor3 = Color3.fromRGB(79, 124, 255)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = notif
        
        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, -20, 0, 40)
        msg.Position = UDim2.new(0, 10, 0, 30)
        msg.BackgroundTransparency = 1
        msg.Text = message
        msg.TextColor3 = Color3.new(1, 1, 1)
        msg.Font = Enum.Font.Gotham
        msg.TextSize = 12
        msg.TextWrapped = true
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.Parent = notif
        
        notif:TweenPosition(UDim2.new(1, -310, 0, 50), "Out", "Quad", 0.3, true)
        
        task.delay(NOTIFICATION_DURATION, function()
            if notif and notif.Parent then
                notif:TweenPosition(UDim2.new(1, 10, 0, 50), "Out", "Quad", 0.3, true)
                task.delay(0.3, function()
                    if notif then notif:Destroy() end
                end)
            end
        end)
    end
    
    coroutine.wrap(showFloatingNotif)()
    
    return notification
end

-- Group Check Functions
local function isInGroup()
    local success, result = pcall(function()
        return player:IsInGroup(GROUP_ID)
    end)
    return success and result
end

local function getGroupRank()
    local success, result = pcall(function()
        return player:GetRankInGroup(GROUP_ID)
    end)
    return success and result or 0
end

-- User Authentication
local function authenticateUser(username, password)
    refreshData()
    if not dataCache or not dataCache.users then
        return false, "Database unavailable"
    end
    
    local user = dataCache.users[tostring(username)]
    if not user then
        return false, "User not found"
    end
    
    if user.password ~= tostring(password) then
        return false, "Invalid password"
    end
    
    currentUser = {
        username = tostring(username),
        role = user.role or "user",
        created = user.created
    }
    
    return true, currentUser
end

local function createUser(username, password)
    if string.len(username) < 3 then
        return false, "Username must be at least 3 characters"
    end
    
    if string.len(password) < 4 then
        return false, "Password must be at least 4 characters"
    end
    
    refreshData()
    if not dataCache then
        dataCache = {
            users = {},
            keys = {},
            games = {},
            bans = {},
            feedbacks = {},
            chats = {},
            settings = {
                version = "2.0",
                created = os.time() * 1000
            }
        }
    end
    
    if dataCache.users[tostring(username)] then
        return false, "Username already exists"
    end
    
    dataCache.users[tostring(username)] = {
        password = tostring(password),
        created = os.time() * 1000,
        role = username == ADMIN_USERNAME and "SUPER_ADMIN" or "user"
    }
    
    local success = updateFirestore(dataCache)
    if success then
        refreshData()
        return true, "Account created"
    else
        return false, "Failed to save user"
    end
end

-- Key Management
local function generateKeyForUser(targetUserId, generatedBy)
    if not targetUserId or not generatedBy then
        return nil, "Invalid parameters"
    end
    
    refreshData()
    if not dataCache then
        return nil, "Database unavailable"
    end
    
    if not dataCache.keys then
        dataCache.keys = {}
    end
    
    -- Check cooldown for this user
    if keyCooldowns[targetUserId] then
        local timeSince = os.time() - keyCooldowns[targetUserId]
        if timeSince < (KEY_COOLDOWN_HOURS * 3600) then
            local hoursLeft = math.ceil((KEY_COOLDOWN_HOURS * 3600 - timeSince) / 3600)
            local minutesLeft = math.ceil(((KEY_COOLDOWN_HOURS * 3600 - timeSince) % 3600) / 60)
            return nil, string.format("Cooldown: %d hours %d minutes", hoursLeft, minutesLeft)
        end
    end
    
    -- Check if key already exists
    for key, keyData in pairs(dataCache.keys) do
        if tonumber(keyData.rbx) == tonumber(targetUserId) then
            return key, "Key already exists"
        end
    end
    
    local newKey = generateRandomKey(16)
    
    dataCache.keys[newKey] = {
        rbx = tonumber(targetUserId),
        exp = "INF",
        created = os.time() * 1000,
        generatedBy = tostring(generatedBy),
        userRole = currentUser and currentUser.role or "user",
        originalUserId = tostring(targetUserId)
    }
    
    local success = updateFirestore(dataCache)
    if success then
        refreshData()
        keyCooldowns[targetUserId] = os.time()
        return newKey, "Key generated"
    else
        return nil, "Failed to save key"
    end
end

local function validateKey(key)
    refreshData()
    if not dataCache or not dataCache.keys then
        return false, "Database unavailable"
    end
    
    local keyData = dataCache.keys[tostring(key)]
    if not keyData then
        return false, "Invalid key"
    end
    
    if tonumber(keyData.rbx) ~= tonumber(userId) then
        return false, string.format("Key belongs to user %d", keyData.rbx)
    end
    
    return true, keyData
end

-- Chat Functions
local function sendChatMessage(message)
    if not message or message == "" then return false end
    
    if moderateText(message) then
        addNotification("⚠️ Message Blocked", "Message contains blocked content", "warning")
        return false
    end
    
    if bannedUsers[username] or bannedUsers[userId] then
        addNotification("❌ Chat Banned", "You are banned from chat", "error")
        return false
    end
    
    refreshData()
    if not dataCache then return false end
    
    if not dataCache.chats then
        dataCache.chats = {}
    end
    
    local newMsg = {
        user = username,
        userId = userId,
        txt = tostring(message),
        timestamp = os.time() * 1000,
        replyTo = replyTarget
    }
    
    table.insert(dataCache.chats, newMsg)
    
    -- Keep only last 100 messages
    while #dataCache.chats > CHAT_MAX_MESSAGES do
        table.remove(dataCache.chats, 1)
    end
    
    local success = updateFirestore(dataCache)
    if success then
        refreshData()
        replyTarget = nil
        return true
    end
    return false
end

local function sendSystemMessage(message)
    refreshData()
    if not dataCache then return false end
    
    if not dataCache.chats then
        dataCache.chats = {}
    end
    
    local newMsg = {
        user = "SYSTEM",
        txt = tostring(message),
        timestamp = os.time() * 1000,
        system = true
    }
    
    table.insert(dataCache.chats, newMsg)
    
    while #dataCache.chats > CHAT_MAX_MESSAGES do
        table.remove(dataCache.chats, 1)
    end
    
    return updateFirestore(dataCache)
end

local function setPinnedMessage(message)
    refreshData()
    if not dataCache then return false end
    
    dataCache.pinned = {
        text = tostring(message),
        pinnedBy = username,
        pinnedAt = os.time() * 1000
    }
    
    return updateFirestore(dataCache)
end

-- Feedback Functions
local function submitFeedback(feedbackUser, feedbackUserId, message)
    if not feedbackUser or not feedbackUserId or not message then
        return false, "All fields required"
    end
    
    refreshData()
    if not dataCache then return false, "Database unavailable" end
    
    if not dataCache.feedbacks then
        dataCache.feedbacks = {}
    end
    
    local newFeedback = {
        user = tostring(feedbackUser),
        userId = tostring(feedbackUserId),
        message = tostring(message),
        timestamp = os.time() * 1000,
        status = "pending"
    }
    
    table.insert(dataCache.feedbacks, newFeedback)
    
    local success = updateFirestore(dataCache)
    if success then
        refreshData()
        return true, "Feedback submitted"
    else
        return false, "Failed to submit feedback"
    end
end

-- Ban Functions
local function banUser(targetUserId, reason, bannedBy)
    refreshData()
    if not dataCache then return false end
    
    if not dataCache.bans then
        dataCache.bans = {}
    end
    
    dataCache.bans[tostring(targetUserId)] = {
        reason = tostring(reason or "No reason provided"),
        banned_by = tostring(bannedBy or username),
        time = os.time() * 1000,
        username = "Unknown"
    }
    
    bannedUsers[tostring(targetUserId)] = true
    
    return updateFirestore(dataCache)
end

local function unbanUser(targetUserId)
    refreshData()
    if not dataCache or not dataCache.bans then return false end
    
    dataCache.bans[tostring(targetUserId)] = nil
    bannedUsers[tostring(targetUserId)] = nil
    
    return updateFirestore(dataCache)
end

-- Game Management Functions
local function createGame(gameName, gameId, imageData)
    if not gameName or not gameId then
        return false, "Name and ID required"
    end
    
    refreshData()
    if not dataCache then return false, "Database unavailable" end
    
    if not dataCache.games then
        dataCache.games = {}
    end
    
    -- Check for duplicate ID
    for _, game in ipairs(dataCache.games) do
        if game.id == tostring(gameId) then
            return false, "Game ID already exists"
        end
    end
    
    local newGame = {
        id = tostring(gameId),
        name = tostring(gameName),
        image = tostring(imageData or ""),
        scripts = {},
        created = os.time() * 1000,
        createdBy = username
    }
    
    table.insert(dataCache.games, newGame)
    
    local success = updateFirestore(dataCache)
    if success then
        refreshData()
        return true, "Game created"
    else
        return false, "Failed to save game"
    end
end

local function deleteGame(index)
    refreshData()
    if not dataCache or not dataCache.games or not dataCache.games[index] then
        return false
    end
    
    table.remove(dataCache.games, index)
    return updateFirestore(dataCache)
end

local function addScriptToGame(gameIndex, scriptName, scriptUrl)
    if not scriptName or not scriptUrl then
        return false, "Name and URL required"
    end
    
    refreshData()
    if not dataCache or not dataCache.games or not dataCache.games[gameIndex] then
        return false, "Game not found"
    end
    
    if not scriptUrl:match("^https?://") then
        return false, "Invalid URL"
    end
    
    local game = dataCache.games[gameIndex]
    if not game.scripts then
        game.scripts = {}
    end
    
    -- Check for duplicate URL
    for _, script in ipairs(game.scripts) do
        if script.url == scriptUrl then
            return false, "Script URL already exists"
        end
    end
    
    local newScript = {
        name = tostring(scriptName),
        url = tostring(scriptUrl),
        added = os.time() * 1000,
        addedBy = username
    }
    
    table.insert(game.scripts, newScript)
    
    local success = updateFirestore(dataCache)
    if success then
        refreshData()
        return true, "Script added"
    else
        return false, "Failed to save script"
    end
end

local function deleteScriptFromGame(gameIndex, scriptIndex)
    refreshData()
    if not dataCache or not dataCache.games or not dataCache.games[gameIndex] then
        return false
    end
    
    local game = dataCache.games[gameIndex]
    if not game.scripts or not game.scripts[scriptIndex] then
        return false
    end
    
    table.remove(game.scripts, scriptIndex)
    return updateFirestore(dataCache)
end

-- GUI Creation Functions
local function createDraggable(frame)
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
    
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
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

local function createLoadingOverlay()
    local overlay = Instance.new("Frame")
    overlay.Name = "LoadingOverlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(5, 7, 10)
    overlay.BackgroundTransparency = 0.3
    overlay.Visible = false
    overlay.Parent = gui
    
    local blur = Instance.new("Frame")
    blur.Size = UDim2.new(1, 0, 1, 0)
    blur.BackgroundColor3 = Color3.new(0, 0, 0)
    blur.BackgroundTransparency = 0.5
    blur.BorderSizePixel = 0
    blur.Parent = overlay
    
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0, 120, 0, 120)
    holder.Position = UDim2.new(0.5, -60, 0.5, -60)
    holder.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    holder.BackgroundTransparency = 0.1
    holder.BorderSizePixel = 0
    holder.Parent = overlay
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = holder
    
    local spinner = Instance.new("Frame")
    spinner.Size = UDim2.new(0, 40, 0, 40)
    spinner.Position = UDim2.new(0.5, -20, 0.3, 0)
    spinner.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    spinner.BackgroundTransparency = 0.7
    spinner.BorderSizePixel = 0
    spinner.Parent = holder
    
    local spinCorner = Instance.new("UICorner")
    spinCorner.CornerRadius = UDim.new(1, 0)
    spinCorner.Parent = spinner
    
    local spinInner = Instance.new("Frame")
    spinInner.Size = UDim2.new(0.7, 0, 0.7, 0)
    spinInner.Position = UDim2.new(0.15, 0, 0.15, 0)
    spinInner.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    spinInner.BorderSizePixel = 0
    spinInner.Parent = spinner
    
    local spinInnerCorner = Instance.new("UICorner")
    spinInnerCorner.CornerRadius = UDim.new(1, 0)
    spinInnerCorner.Parent = spinInner
    
    local text = Instance.new("TextLabel")
    text.Name = "TextLabel"
    text.Size = UDim2.new(1, -20, 0, 30)
    text.Position = UDim2.new(0, 10, 0, 70)
    text.BackgroundTransparency = 1
    text.Text = "Loading..."
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Font = Enum.Font.Gotham
    text.TextSize = 14
    text.Parent = holder
    
    -- Spinner animation
    coroutine.wrap(function()
        while overlay.Parent do
            spinner.Rotation = spinner.Rotation + 5
            task.wait(0.02)
        end
    end)()
    
    return overlay
end

local function createAuthPanel()
    local panel = Instance.new("Frame")
    panel.Name = "AuthPanel"
    panel.Size = UDim2.new(0, 420, 0, 500)
    panel.Position = UDim2.new(0.5, -210, 0.5, -250)
    panel.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0
    panel.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = panel
    
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 45
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(79, 124, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 210, 255))
    })
    gradient.Parent = Instance.new("Frame")
    gradient.Parent.Size = UDim2.new(1, 0, 2, 0)
    gradient.Parent.Position = UDim2.new(0, 0, 1, -2)
    gradient.Parent.BackgroundTransparency = 1
    gradient.Parent.Parent = panel
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 80)
    title.Position = UDim2.new(0, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "RSQ GATE"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 32
    title.Parent = panel
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, 0, 0, 20)
    subtitle.Position = UDim2.new(0, 0, 0, 70)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Secure Access System"
    subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.Parent = panel
    
    -- Login View
    local loginView = Instance.new("Frame")
    loginView.Name = "LoginView"
    loginView.Size = UDim2.new(1, -40, 1, -120)
    loginView.Position = UDim2.new(0, 20, 0, 100)
    loginView.BackgroundTransparency = 1
    loginView.Parent = panel
    
    local userInput = Instance.new("TextBox")
    userInput.Name = "UsernameInput"
    userInput.Size = UDim2.new(1, 0, 0, 45)
    userInput.Position = UDim2.new(0, 0, 0, 0)
    userInput.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    userInput.BackgroundTransparency = 0.7
    userInput.BorderSizePixel = 0
    userInput.PlaceholderText = "Username"
    userInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    userInput.Text = ""
    userInput.TextColor3 = Color3.new(1, 1, 1)
    userInput.Font = Enum.Font.Gotham
    userInput.TextSize = 14
    userInput.ClearTextOnFocus = false
    userInput.Parent = loginView
    
    local userCorner = Instance.new("UICorner")
    userCorner.CornerRadius = UDim.new(0, 10)
    userCorner.Parent = userInput
    
    local passInput = Instance.new("TextBox")
    passInput.Name = "PasswordInput"
    passInput.Size = UDim2.new(1, 0, 0, 45)
    passInput.Position = UDim2.new(0, 0, 0, 55)
    passInput.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    passInput.BackgroundTransparency = 0.7
    passInput.BorderSizePixel = 0
    passInput.PlaceholderText = "Password"
    passInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    passInput.Text = ""
    passInput.TextColor3 = Color3.new(1, 1, 1)
    passInput.Font = Enum.Font.Gotham
    passInput.TextSize = 14
    passInput.ClearTextOnFocus = false
    passInput.Parent = loginView
    
    local passCorner = Instance.new("UICorner")
    passCorner.CornerRadius = UDim.new(0, 10)
    passCorner.Parent = passInput
    
    local loginBtn = Instance.new("TextButton")
    loginBtn.Name = "LoginButton"
    loginBtn.Size = UDim2.new(1, 0, 0, 45)
    loginBtn.Position = UDim2.new(0, 0, 0, 115)
    loginBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    loginBtn.BorderSizePixel = 0
    loginBtn.Text = "Sign In"
    loginBtn.TextColor3 = Color3.new(1, 1, 1)
    loginBtn.Font = Enum.Font.GothamBold
    loginBtn.TextSize = 14
    loginBtn.Parent = loginView
    
    local loginBtnCorner = Instance.new("UICorner")
    loginBtnCorner.CornerRadius = UDim.new(0, 10)
    loginBtnCorner.Parent = loginBtn
    
    local loginSpinner = Instance.new("Frame")
    loginSpinner.Name = "Spinner"
    loginSpinner.Size = UDim2.new(0, 20, 0, 20)
    loginSpinner.Position = UDim2.new(1, -30, 0.5, -10)
    loginSpinner.BackgroundColor3 = Color3.new(1, 1, 1)
    loginSpinner.BackgroundTransparency = 0.5
    loginSpinner.BorderSizePixel = 0
    loginSpinner.Visible = false
    loginSpinner.Parent = loginBtn
    
    local spinCorner = Instance.new("UICorner")
    spinCorner.CornerRadius = UDim.new(1, 0)
    spinCorner.Parent = loginSpinner
    
    local signupLink = Instance.new("TextLabel")
    signupLink.Size = UDim2.new(1, 0, 0, 20)
    signupLink.Position = UDim2.new(0, 0, 1, -30)
    signupLink.BackgroundTransparency = 1
    signupLink.Text = "New here? Create Account"
    signupLink.TextColor3 = Color3.fromRGB(150, 150, 150)
    signupLink.Font = Enum.Font.Gotham
    signupLink.TextSize = 12
    signupLink.Parent = loginView
    
    -- Signup View
    local signupView = Instance.new("Frame")
    signupView.Name = "SignupView"
    signupView.Size = UDim2.new(1, -40, 1, -120)
    signupView.Position = UDim2.new(0, 20, 0, 100)
    signupView.BackgroundTransparency = 1
    signupView.Visible = false
    signupView.Parent = panel
    
    local sUserInput = Instance.new("TextBox")
    sUserInput.Name = "SignupUsernameInput"
    sUserInput.Size = UDim2.new(1, 0, 0, 45)
    sUserInput.Position = UDim2.new(0, 0, 0, 0)
    sUserInput.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    sUserInput.BackgroundTransparency = 0.7
    sUserInput.BorderSizePixel = 0
    sUserInput.PlaceholderText = "Choose Username"
    sUserInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    sUserInput.Text = ""
    sUserInput.TextColor3 = Color3.new(1, 1, 1)
    sUserInput.Font = Enum.Font.Gotham
    sUserInput.TextSize = 14
    sUserInput.ClearTextOnFocus = false
    sUserInput.Parent = signupView
    
    local sUserCorner = Instance.new("UICorner")
    sUserCorner.CornerRadius = UDim.new(0, 10)
    sUserCorner.Parent = sUserInput
    
    local sPassInput = Instance.new("TextBox")
    sPassInput.Name = "SignupPasswordInput"
    sPassInput.Size = UDim2.new(1, 0, 0, 45)
    sPassInput.Position = UDim2.new(0, 0, 0, 55)
    sPassInput.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    sPassInput.BackgroundTransparency = 0.7
    sPassInput.BorderSizePixel = 0
    sPassInput.PlaceholderText = "Choose Password"
    sPassInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    sPassInput.Text = ""
    sPassInput.TextColor3 = Color3.new(1, 1, 1)
    sPassInput.Font = Enum.Font.Gotham
    sPassInput.TextSize = 14
    sPassInput.ClearTextOnFocus = false
    sPassInput.Parent = signupView
    
    local sPassCorner = Instance.new("UICorner")
    sPassCorner.CornerRadius = UDim.new(0, 10)
    sPassCorner.Parent = sPassInput
    
    local signupBtn = Instance.new("TextButton")
    signupBtn.Name = "SignupButton"
    signupBtn.Size = UDim2.new(1, 0, 0, 45)
    signupBtn.Position = UDim2.new(0, 0, 0, 115)
    signupBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    signupBtn.BorderSizePixel = 0
    signupBtn.Text = "Sign Up"
    signupBtn.TextColor3 = Color3.new(1, 1, 1)
    signupBtn.Font = Enum.Font.GothamBold
    signupBtn.TextSize = 14
    signupBtn.Parent = signupView
    
    local signupBtnCorner = Instance.new("UICorner")
    signupBtnCorner.CornerRadius = UDim.new(0, 10)
    signupBtnCorner.Parent = signupBtn
    
    local signupSpinner = Instance.new("Frame")
    signupSpinner.Name = "Spinner"
    signupSpinner.Size = UDim2.new(0, 20, 0, 20)
    signupSpinner.Position = UDim2.new(1, -30, 0.5, -10)
    signupSpinner.BackgroundColor3 = Color3.new(1, 1, 1)
    signupSpinner.BackgroundTransparency = 0.5
    signupSpinner.BorderSizePixel = 0
    signupSpinner.Visible = false
    signupSpinner.Parent = signupBtn
    
    local sSpinCorner = Instance.new("UICorner")
    sSpinCorner.CornerRadius = UDim.new(1, 0)
    sSpinCorner.Parent = signupSpinner
    
    local loginLink = Instance.new("TextLabel")
    loginLink.Size = UDim2.new(1, 0, 0, 20)
    loginLink.Position = UDim2.new(0, 0, 1, -30)
    loginLink.BackgroundTransparency = 1
    loginLink.Text = "Have account? Sign In"
    loginLink.TextColor3 = Color3.fromRGB(150, 150, 150)
    loginLink.Font = Enum.Font.Gotham
    loginLink.TextSize = 12
    loginLink.Parent = signupView
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -40, 0, 20)
    statusLabel.Position = UDim2.new(0, 20, 1, -40)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(255, 59, 48)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.Parent = panel
    
    createDraggable(panel)
    
    return panel, loginView, signupView, userInput, passInput, sUserInput, sPassInput, loginBtn, signupBtn, loginSpinner, signupSpinner, statusLabel, loginLink, signupLink
end

local function createMainPanel()
    local panel = Instance.new("Frame")
    panel.Name = "MainPanel"
    panel.Size = UDim2.new(0, 420, 0, 500)
    panel.Position = UDim2.new(0.5, -210, 0.5, -250)
    panel.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = panel
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 60)
    title.Position = UDim2.new(0, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = "RSQ ELITE"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 28
    title.Parent = panel
    
    local welcomeLabel = Instance.new("TextLabel")
    welcomeLabel.Name = "WelcomeLabel"
    welcomeLabel.Size = UDim2.new(1, 0, 0, 20)
    welcomeLabel.Position = UDim2.new(0, 0, 0, 55)
    welcomeLabel.BackgroundTransparency = 1
    welcomeLabel.Text = ""
    welcomeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    welcomeLabel.Font = Enum.Font.Gotham
    welcomeLabel.TextSize = 11
    welcomeLabel.Parent = panel
    
    local userIdInput = Instance.new("TextBox")
    userIdInput.Name = "UserIdInput"
    userIdInput.Size = UDim2.new(1, -40, 0, 45)
    userIdInput.Position = UDim2.new(0, 20, 0, 100)
    userIdInput.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    userIdInput.BackgroundTransparency = 0.7
    userIdInput.BorderSizePixel = 0
    userIdInput.PlaceholderText = "Roblox UserID"
    userIdInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    userIdInput.Text = ""
    userIdInput.TextColor3 = Color3.new(1, 1, 1)
    userIdInput.Font = Enum.Font.Gotham
    userIdInput.TextSize = 14
    userIdInput.ClearTextOnFocus = false
    userIdInput.Parent = panel
    
    local userCorner = Instance.new("UICorner")
    userCorner.CornerRadius = UDim.new(0, 10)
    userCorner.Parent = userIdInput
    
    local generateBtn = Instance.new("TextButton")
    generateBtn.Name = "GenerateButton"
    generateBtn.Size = UDim2.new(1, -40, 0, 45)
    generateBtn.Position = UDim2.new(0, 20, 0, 160)
    generateBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    generateBtn.BorderSizePixel = 0
    generateBtn.Text = "Generate Access Key"
    generateBtn.TextColor3 = Color3.new(1, 1, 1)
    generateBtn.Font = Enum.Font.GothamBold
    generateBtn.TextSize = 14
    generateBtn.Parent = panel
    
    local genCorner = Instance.new("UICorner")
    genCorner.CornerRadius = UDim.new(0, 10)
    genCorner.Parent = generateBtn
    
    local genSpinner = Instance.new("Frame")
    genSpinner.Name = "Spinner"
    genSpinner.Size = UDim2.new(0, 20, 0, 20)
    genSpinner.Position = UDim2.new(1, -30, 0.5, -10)
    genSpinner.BackgroundColor3 = Color3.new(1, 1, 1)
    genSpinner.BackgroundTransparency = 0.5
    genSpinner.BorderSizePixel = 0
    genSpinner.Visible = false
    genSpinner.Parent = generateBtn
    
    local spinCorner = Instance.new("UICorner")
    spinCorner.CornerRadius = UDim.new(1, 0)
    spinCorner.Parent = genSpinner
    
    local statusMsg = Instance.new("TextLabel")
    statusMsg.Name = "StatusMessage"
    statusMsg.Size = UDim2.new(1, -40, 0, 20)
    statusMsg.Position = UDim2.new(0, 20, 0, 215)
    statusMsg.BackgroundTransparency = 1
    statusMsg.Text = ""
    statusMsg.TextColor3 = Color3.fromRGB(255, 59, 48)
    statusMsg.Font = Enum.Font.Gotham
    statusMsg.TextSize = 12
    statusMsg.Parent = panel
    
    local keyOut = Instance.new("TextLabel")
    keyOut.Name = "KeyOutput"
    keyOut.Size = UDim2.new(1, -40, 0, 50)
    keyOut.Position = UDim2.new(0, 20, 0, 240)
    keyOut.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    keyOut.BackgroundTransparency = 0.7
    keyOut.BorderSizePixel = 0
    keyOut.Text = ""
    keyOut.TextColor3 = Color3.fromRGB(79, 124, 255)
    keyOut.Font = Enum.Font.Code
    keyOut.TextSize = 16
    keyOut.TextWrapped = true
    keyOut.Parent = panel
    
    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 10)
    keyCorner.Parent = keyOut
    
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, -40, 0, 45)
    buttonFrame.Position = UDim2.new(0, 20, 1, -65)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = panel
    
    local feedbackBtn = Instance.new("TextButton")
    feedbackBtn.Name = "FeedbackButton"
    feedbackBtn.Size = UDim2.new(0.48, 0, 1, 0)
    feedbackBtn.Position = UDim2.new(0, 0, 0, 0)
    feedbackBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    feedbackBtn.BorderSizePixel = 0
    feedbackBtn.Text = "💬 Feedback"
    feedbackBtn.TextColor3 = Color3.new(1, 1, 1)
    feedbackBtn.Font = Enum.Font.GothamBold
    feedbackBtn.TextSize = 14
    feedbackBtn.Parent = buttonFrame
    
    local fbCorner = Instance.new("UICorner")
    fbCorner.CornerRadius = UDim.new(0, 10)
    fbCorner.Parent = feedbackBtn
    
    local logoutBtn = Instance.new("TextButton")
    logoutBtn.Name = "LogoutButton"
    logoutBtn.Size = UDim2.new(0.48, 0, 1, 0)
    logoutBtn.Position = UDim2.new(0.52, 0, 0, 0)
    logoutBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    logoutBtn.BackgroundTransparency = 0.95
    logoutBtn.BorderSizePixel = 0
    logoutBtn.Text = "🚪 Logout"
    logoutBtn.TextColor3 = Color3.new(1, 1, 1)
    logoutBtn.Font = Enum.Font.GothamBold
    logoutBtn.TextSize = 14
    logoutBtn.Parent = buttonFrame
    
    local logoutCorner = Instance.new("UICorner")
    logoutCorner.CornerRadius = UDim.new(0, 10)
    logoutCorner.Parent = logoutBtn
    
    local adminBtn = Instance.new("TextButton")
    adminBtn.Name = "AdminButton"
    adminBtn.Size = UDim2.new(0.48, 0, 1, 0)
    adminBtn.Position = UDim2.new(0, 0, 0, 0)
    adminBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    adminBtn.BorderSizePixel = 0
    adminBtn.Text = "👑 Admin"
    adminBtn.TextColor3 = Color3.new(1, 1, 1)
    adminBtn.Font = Enum.Font.GothamBold
    adminBtn.TextSize = 14
    adminBtn.Visible = false
    adminBtn.Parent = buttonFrame
    
    local adminCorner = Instance.new("UICorner")
    adminCorner.CornerRadius = UDim.new(0, 10)
    adminCorner.Parent = adminBtn
    
    local adminInput = Instance.new("TextBox")
    adminInput.Name = "AdminPasswordInput"
    adminInput.Size = UDim2.new(1, -40, 0, 45)
    adminInput.Position = UDim2.new(0, 20, 1, -120)
    adminInput.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    adminInput.BackgroundTransparency = 0.7
    adminInput.BorderSizePixel = 0
    adminInput.PlaceholderText = "Enter Admin Password"
    adminInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    adminInput.Text = ""
    adminInput.TextColor3 = Color3.new(1, 1, 1)
    adminInput.Font = Enum.Font.Gotham
    adminInput.TextSize = 14
    adminInput.ClearTextOnFocus = false
    adminInput.Parent = panel
    
    local adminCorner2 = Instance.new("UICorner")
    adminCorner2.CornerRadius = UDim.new(0, 10)
    adminCorner2.Parent = adminInput
    
    createDraggable(panel)
    
    return panel, welcomeLabel, userIdInput, generateBtn, genSpinner, statusMsg, keyOut, feedbackBtn, logoutBtn, adminBtn, adminInput
end

local function createFeedbackPanel()
    local panel = Instance.new("Frame")
    panel.Name = "FeedbackPanel"
    panel.Size = UDim2.new(0, 420, 0, 500)
    panel.Position = UDim2.new(0.5, -210, 0.5, -250)
    panel.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    panel.BackgroundTransparency = 0.05
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 20)
    corner.Parent = panel
    
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, -40, 0, 50)
    header.Position = UDim2.new(0, 20, 0, 20)
    header.BackgroundTransparency = 1
    header.Parent = panel
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "📝 FEEDBACK"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 24
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -40, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 10)
    closeCorner.Parent = closeBtn
    
    local fbUser = Instance.new("TextBox")
    fbUser.Name = "FeedbackUser"
    fbUser.Size = UDim2.new(1, -40, 0, 45)
    fbUser.Position = UDim2.new(0, 20, 0, 90)
    fbUser.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fbUser.BackgroundTransparency = 0.7
    fbUser.BorderSizePixel = 0
    fbUser.PlaceholderText = "Roblox Username"
    fbUser.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    fbUser.Text = ""
    fbUser.TextColor3 = Color3.new(1, 1, 1)
    fbUser.Font = Enum.Font.Gotham
    fbUser.TextSize = 14
    fbUser.ClearTextOnFocus = false
    fbUser.Parent = panel
    
    local fbUserCorner = Instance.new("UICorner")
    fbUserCorner.CornerRadius = UDim.new(0, 10)
    fbUserCorner.Parent = fbUser
    
    local fbId = Instance.new("TextBox")
    fbId.Name = "FeedbackUserId"
    fbId.Size = UDim2.new(1, -40, 0, 45)
    fbId.Position = UDim2.new(0, 20, 0, 145)
    fbId.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fbId.BackgroundTransparency = 0.7
    fbId.BorderSizePixel = 0
    fbId.PlaceholderText = "Roblox UserID"
    fbId.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    fbId.Text = ""
    fbId.TextColor3 = Color3.new(1, 1, 1)
    fbId.Font = Enum.Font.Gotham
    fbId.TextSize = 14
    fbId.ClearTextOnFocus = false
    fbId.Parent = panel
    
    local fbIdCorner = Instance.new("UICorner")
    fbIdCorner.CornerRadius = UDim.new(0, 10)
    fbIdCorner.Parent = fbId
    
    local fbMsg = Instance.new("TextBox")
    fbMsg.Name = "FeedbackMessage"
    fbMsg.Size = UDim2.new(1, -40, 0, 120)
    fbMsg.Position = UDim2.new(0, 20, 0, 200)
    fbMsg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fbMsg.BackgroundTransparency = 0.7
    fbMsg.BorderSizePixel = 0
    fbMsg.PlaceholderText = "Write your feedback here..."
    fbMsg.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    fbMsg.Text = ""
    fbMsg.TextColor3 = Color3.new(1, 1, 1)
    fbMsg.Font = Enum.Font.Gotham
    fbMsg.TextSize = 14
    fbMsg.TextWrapped = true
    fbMsg.MultiLine = true
    fbMsg.ClearTextOnFocus = false
    fbMsg.Parent = panel
    
    local fbMsgCorner = Instance.new("UICorner")
    fbMsgCorner.CornerRadius = UDim.new(0, 10)
    fbMsgCorner.Parent = fbMsg
    
    local charCount = Instance.new("TextLabel")
    charCount.Name = "CharCount"
    charCount.Size = UDim2.new(0, 50, 0, 20)
    charCount.Position = UDim2.new(1, -60, 0, 310)
    charCount.BackgroundTransparency = 1
    charCount.Text = "0/500"
    charCount.TextColor3 = Color3.fromRGB(150, 150, 150)
    charCount.Font = Enum.Font.Gotham
    charCount.TextSize = 10
    charCount.Parent = panel
    
    local submitBtn = Instance.new("TextButton")
    submitBtn.Name = "SubmitFeedback"
    submitBtn.Size = UDim2.new(1, -40, 0, 45)
    submitBtn.Position = UDim2.new(0, 20, 1, -65)
    submitBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    submitBtn.BorderSizePixel = 0
    submitBtn.Text = "Submit Feedback"
    submitBtn.TextColor3 = Color3.new(1, 1, 1)
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 14
    submitBtn.Parent = panel
    
    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 10)
    submitCorner.Parent = submitBtn
    
    local fbSpinner = Instance.new("Frame")
    fbSpinner.Name = "Spinner"
    fbSpinner.Size = UDim2.new(0, 20, 0, 20)
    fbSpinner.Position = UDim2.new(1, -30, 0.5, -10)
    fbSpinner.BackgroundColor3 = Color3.new(1, 1, 1)
    fbSpinner.BackgroundTransparency = 0.5
    fbSpinner.BorderSizePixel = 0
    fbSpinner.Visible = false
    fbSpinner.Parent = submitBtn
    
    local fbSpinCorner = Instance.new("UICorner")
    fbSpinCorner.CornerRadius = UDim.new(1, 0)
    fbSpinCorner.Parent = fbSpinner
    
    createDraggable(panel)
    
    return panel, closeBtn, fbUser, fbId, fbMsg, charCount, submitBtn, fbSpinner
end

local function createChatWindow()
    local window = Instance.new("Frame")
    window.Name = "ChatWindow"
    window.Size = UDim2.new(0, 380, 0, 520)
    window.Position = UDim2.new(1, -400, 1, -540)
    window.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    window.BackgroundTransparency = 0.05
    window.BorderSizePixel = 0
    window.Visible = false
    window.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = window
    
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    header.BackgroundTransparency = 0.97
    header.BorderSizePixel = 0
    header.Parent = window
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 16)
    headerCorner.Parent = header
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "NETWORK CHAT"
    title.TextColor3 = Color3.fromRGB(79, 124, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    local stats = Instance.new("Frame")
    stats.Size = UDim2.new(0.4, -15, 1, 0)
    stats.Position = UDim2.new(0.6, 0, 0, 0)
    stats.BackgroundTransparency = 1
    stats.Parent = header
    
    local onlineCount = Instance.new("TextLabel")
    onlineCount.Name = "OnlineCount"
    onlineCount.Size = UDim2.new(0.5, 0, 1, 0)
    onlineCount.BackgroundTransparency = 1
    onlineCount.Text = "👤 0"
    onlineCount.TextColor3 = Color3.fromRGB(200, 200, 200)
    onlineCount.Font = Enum.Font.Gotham
    onlineCount.TextSize = 11
    onlineCount.Parent = stats
    
    local msgCount = Instance.new("TextLabel")
    msgCount.Name = "MessageCount"
    msgCount.Size = UDim2.new(0.5, 0, 1, 0)
    msgCount.Position = UDim2.new(0.5, 0, 0, 0)
    msgCount.BackgroundTransparency = 1
    msgCount.Text = "💬 0"
    msgCount.TextColor3 = Color3.fromRGB(200, 200, 200)
    msgCount.Font = Enum.Font.Gotham
    msgCount.TextSize = 11
    msgCount.Parent = stats
    
    local pinnedArea = Instance.new("Frame")
    pinnedArea.Name = "PinnedArea"
    pinnedArea.Size = UDim2.new(1, 0, 0, 40)
    pinnedArea.Position = UDim2.new(0, 0, 0, 50)
    pinnedArea.BackgroundColor3 = Color3.fromRGB(255, 204, 0)
    pinnedArea.BackgroundTransparency = 0.9
    pinnedArea.BorderSizePixel = 0
    pinnedArea.Visible = false
    pinnedArea.Parent = window
    
    local pinIcon = Instance.new("TextLabel")
    pinIcon.Size = UDim2.new(0, 30, 1, 0)
    pinIcon.BackgroundTransparency = 1
    pinIcon.Text = "📌"
    pinIcon.TextColor3 = Color3.fromRGB(255, 204, 0)
    pinIcon.Font = Enum.Font.Gotham
    pinIcon.TextSize = 14
    pinIcon.Parent = pinnedArea
    
    local pinText = Instance.new("TextLabel")
    pinText.Name = "PinnedText"
    pinText.Size = UDim2.new(1, -40, 1, 0)
    pinText.Position = UDim2.new(0, 30, 0, 0)
    pinText.BackgroundTransparency = 1
    pinText.Text = ""
    pinText.TextColor3 = Color3.new(1, 1, 1)
    pinText.Font = Enum.Font.Gotham
    pinText.TextSize = 12
    pinText.TextXAlignment = Enum.TextXAlignment.Left
    pinText.Parent = pinnedArea
    
    local messages = Instance.new("ScrollingFrame")
    messages.Name = "Messages"
    messages.Size = UDim2.new(1, 0, 1, -140)
    messages.Position = UDim2.new(0, 0, 0, 90)
    messages.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    messages.BackgroundTransparency = 0.9
    messages.BorderSizePixel = 0
    messages.CanvasSize = UDim2.new(0, 0, 0, 0)
    messages.ScrollBarThickness = 4
    messages.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    messages.Parent = window
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = messages
    
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.Parent = messages
    
    local typingIndicator = Instance.new("Frame")
    typingIndicator.Name = "TypingIndicator"
    typingIndicator.Size = UDim2.new(1, -20, 0, 20)
    typingIndicator.Position = UDim2.new(0, 10, 1, -70)
    typingIndicator.BackgroundTransparency = 1
    typingIndicator.Visible = false
    typingIndicator.Parent = window
    
    local typingText = Instance.new("TextLabel")
    typingText.Name = "TypingText"
    typingText.Size = UDim2.new(1, 0, 1, 0)
    typingText.BackgroundTransparency = 1
    typingText.Text = ""
    typingText.TextColor3 = Color3.fromRGB(79, 124, 255)
    typingText.Font = Enum.Font.Gotham
    typingText.TextSize = 11
    typingText.TextXAlignment = Enum.TextXAlignment.Left
    typingText.Parent = typingIndicator
    
    local inputArea = Instance.new("Frame")
    inputArea.Size = UDim2.new(1, 0, 0, 70)
    inputArea.Position = UDim2.new(0, 0, 1, -70)
    inputArea.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    inputArea.BackgroundTransparency = 0.98
    inputArea.BorderSizePixel = 0
    inputArea.Parent = window
    
    local inputAreaCorner = Instance.new("UICorner")
    inputAreaCorner.CornerRadius = UDim.new(0, 16)
    inputAreaCorner.Parent = inputArea
    
    local replyPreview = Instance.new("Frame")
    replyPreview.Name = "ReplyPreview"
    replyPreview.Size = UDim2.new(1, -20, 0, 30)
    replyPreview.Position = UDim2.new(0, 10, 0, -35)
    replyPreview.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    replyPreview.BackgroundTransparency = 0.9
    replyPreview.BorderSizePixel = 0
    replyPreview.Visible = false
    replyPreview.Parent = inputArea
    
    local replyPreviewCorner = Instance.new("UICorner")
    replyPreviewCorner.CornerRadius = UDim.new(0, 8)
    replyPreviewCorner.Parent = replyPreview
    
    local replyPreviewText = Instance.new("TextLabel")
    replyPreviewText.Name = "ReplyPreviewText"
    replyPreviewText.Size = UDim2.new(1, -40, 1, 0)
    replyPreviewText.Position = UDim2.new(0, 10, 0, 0)
    replyPreviewText.BackgroundTransparency = 1
    replyPreviewText.Text = ""
    replyPreviewText.TextColor3 = Color3.new(1, 1, 1)
    replyPreviewText.Font = Enum.Font.Gotham
    replyPreviewText.TextSize = 11
    replyPreviewText.TextXAlignment = Enum.TextXAlignment.Left
    replyPreviewText.Parent = replyPreview
    
    local cancelReply = Instance.new("TextButton")
    cancelReply.Size = UDim2.new(0, 20, 0, 20)
    cancelReply.Position = UDim2.new(1, -25, 0.5, -10)
    cancelReply.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    cancelReply.BackgroundTransparency = 0.5
    cancelReply.BorderSizePixel = 0
    cancelReply.Text = "✕"
    cancelReply.TextColor3 = Color3.new(1, 1, 1)
    cancelReply.Font = Enum.Font.GothamBold
    cancelReply.TextSize = 12
    cancelReply.Parent = replyPreview
    
    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 4)
    cancelCorner.Parent = cancelReply
    
    local inputBox = Instance.new("TextBox")
    inputBox.Name = "ChatInput"
    inputBox.Size = UDim2.new(0.75, -10, 0, 40)
    inputBox.Position = UDim2.new(0, 10, 0, 15)
    inputBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    inputBox.BackgroundTransparency = 0.7
    inputBox.BorderSizePixel = 0
    inputBox.PlaceholderText = "Type a message..."
    inputBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    inputBox.Text = ""
    inputBox.TextColor3 = Color3.new(1, 1, 1)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 13
    inputBox.ClearTextOnFocus = false
    inputBox.Parent = inputArea
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 10)
    inputCorner.Parent = inputBox
    
    local sendBtn = Instance.new("TextButton")
    sendBtn.Name = "SendButton"
    sendBtn.Size = UDim2.new(0.25, -15, 0, 40)
    sendBtn.Position = UDim2.new(0.75, 5, 0, 15)
    sendBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    sendBtn.BorderSizePixel = 0
    sendBtn.Text = "SEND"
    sendBtn.TextColor3 = Color3.new(1, 1, 1)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 12
    sendBtn.Parent = inputArea
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 10)
    sendCorner.Parent = sendBtn
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ChatToggle"
    toggleBtn.Size = UDim2.new(0, 56, 0, 56)
    toggleBtn.Position = UDim2.new(1, -75, 1, -95)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = ""
    toggleBtn.Parent = gui
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn
    
    local toggleIcon = Instance.new("ImageLabel")
    toggleIcon.Size = UDim2.new(0, 28, 0, 28)
    toggleIcon.Position = UDim2.new(0.5, -14, 0.5, -14)
    toggleIcon.BackgroundTransparency = 1
    toggleIcon.Image = "rbxassetid://6023426915"
    toggleIcon.ImageColor3 = Color3.new(1, 1, 1)
    toggleIcon.Parent = toggleBtn
    
    local unreadBadge = Instance.new("Frame")
    unreadBadge.Name = "UnreadBadge"
    unreadBadge.Size = UDim2.new(0, 20, 0, 20)
    unreadBadge.Position = UDim2.new(1, -10, 0, -5)
    unreadBadge.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    unreadBadge.BorderSizePixel = 0
    unreadBadge.Visible = false
    unreadBadge.Parent = toggleBtn
    
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(1, 0)
    badgeCorner.Parent = unreadBadge
    
    local badgeText = Instance.new("TextLabel")
    badgeText.Name = "BadgeText"
    badgeText.Size = UDim2.new(1, 0, 1, 0)
    badgeText.BackgroundTransparency = 1
    badgeText.Text = "0"
    badgeText.TextColor3 = Color3.new(1, 1, 1)
    badgeText.Font = Enum.Font.GothamBold
    badgeText.TextSize = 11
    badgeText.Parent = unreadBadge
    
    return window, messages, inputBox, sendBtn, toggleBtn, unreadBadge, badgeText, pinText, pinnedArea, typingText, replyPreview, replyPreviewText, cancelReply, onlineCount, msgCount
end

-- Initialize GUI
local function initializeGUI()
    gui.Name = "RSQ_Elite"
    gui.Parent = CoreGui
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    loadingOverlay = createLoadingOverlay()
    
    -- Create all panels
    local authPanel, loginView, signupView, loginUser, loginPass, signupUser, signupPass, loginBtn, signupBtn, loginSpinner, signupSpinner, authStatus, loginLink, signupLink = createAuthPanel()
    local mainPanel, welcomeLabel, userIdInput, generateBtn, genSpinner, statusMsg, keyOut, feedbackBtn, logoutBtn, adminBtn, adminInput = createMainPanel()
    local feedbackPanel, fbCloseBtn, fbUser, fbId, fbMsg, fbCharCount, fbSubmitBtn, fbSpinner = createFeedbackPanel()
    local chatWindow, chatMessages, chatInput, chatSendBtn, chatToggle, unreadBadge, badgeText, pinText, pinnedArea, typingText, replyPreview, replyPreviewText, cancelReply, onlineCount, msgCount = createChatWindow()
    
    -- Notification Center
    local notifCenter = Instance.new("Frame")
    notifCenter.Name = "NotificationCenter"
    notifCenter.Size = UDim2.new(0, 350, 0, 400)
    notifCenter.Position = UDim2.new(1, -370, 0, 60)
    notifCenter.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    notifCenter.BackgroundTransparency = 0.05
    notifCenter.BorderSizePixel = 0
    notifCenter.Visible = false
    notifCenter.Parent = gui
    
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 16)
    notifCorner.Parent = notifCenter
    
    local notifHeader = Instance.new("Frame")
    notifHeader.Size = UDim2.new(1, 0, 0, 50)
    notifHeader.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    notifHeader.BackgroundTransparency = 0.97
    notifHeader.BorderSizePixel = 0
    notifHeader.Parent = notifCenter
    
    local notifHeaderCorner = Instance.new("UICorner")
    notifHeaderCorner.CornerRadius = UDim.new(0, 16)
    notifHeaderCorner.Parent = notifHeader
    
    local notifTitle = Instance.new("TextLabel")
    notifTitle.Size = UDim2.new(0.6, 0, 1, 0)
    notifTitle.Position = UDim2.new(0, 15, 0, 0)
    notifTitle.BackgroundTransparency = 1
    notifTitle.Text = "🔔 Notifications"
    notifTitle.TextColor3 = Color3.fromRGB(79, 124, 255)
    notifTitle.Font = Enum.Font.GothamBold
    notifTitle.TextSize = 14
    notifTitle.TextXAlignment = Enum.TextXAlignment.Left
    notifTitle.Parent = notifHeader
    
    local notifActions = Instance.new("Frame")
    notifActions.Size = UDim2.new(0.4, -15, 1, 0)
    notifActions.Position = UDim2.new(0.6, 0, 0, 0)
    notifActions.BackgroundTransparency = 1
    notifActions.Parent = notifHeader
    
    local markReadBtn = Instance.new("TextButton")
    markReadBtn.Size = UDim2.new(0.7, -5, 0, 25)
    markReadBtn.Position = UDim2.new(0, 0, 0.5, -12.5)
    markReadBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    markReadBtn.BorderSizePixel = 0
    markReadBtn.Text = "✓ Mark all read"
    markReadBtn.TextColor3 = Color3.new(1, 1, 1)
    markReadBtn.Font = Enum.Font.GothamBold
    markReadBtn.TextSize = 10
    markReadBtn.Parent = notifActions
    
    local markCorner = Instance.new("UICorner")
    markCorner.CornerRadius = UDim.new(0, 6)
    markCorner.Parent = markReadBtn
    
    local closeNotifBtn = Instance.new("TextButton")
    closeNotifBtn.Size = UDim2.new(0.3, -5, 0, 25)
    closeNotifBtn.Position = UDim2.new(0.7, 5, 0.5, -12.5)
    closeNotifBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    closeNotifBtn.BorderSizePixel = 0
    closeNotifBtn.Text = "✕"
    closeNotifBtn.TextColor3 = Color3.new(1, 1, 1)
    closeNotifBtn.Font = Enum.Font.GothamBold
    closeNotifBtn.TextSize = 12
    closeNotifBtn.Parent = notifActions
    
    local closeNotifCorner = Instance.new("UICorner")
    closeNotifCorner.CornerRadius = UDim.new(0, 6)
    closeNotifCorner.Parent = closeNotifBtn
    
    local notifList = Instance.new("ScrollingFrame")
    notifList.Name = "NotificationList"
    notifList.Size = UDim2.new(1, 0, 1, -60)
    notifList.Position = UDim2.new(0, 0, 0, 60)
    notifList.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    notifList.BackgroundTransparency = 0.9
    notifList.BorderSizePixel = 0
    notifList.CanvasSize = UDim2.new(0, 0, 0, 0)
    notifList.ScrollBarThickness = 4
    notifList.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    notifList.Parent = notifCenter
    
    local notifLayout = Instance.new("UIListLayout")
    notifLayout.Padding = UDim.new(0, 8)
    notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifLayout.Parent = notifList
    
    local notifPadding = Instance.new("UIPadding")
    notifPadding.PaddingTop = UDim.new(0, 10)
    notifPadding.PaddingBottom = UDim.new(0, 10)
    notifPadding.PaddingLeft = UDim.new(0, 10)
    notifPadding.PaddingRight = UDim.new(0, 10)
    notifPadding.Parent = notifList
    
    local notifToggle = Instance.new("TextButton")
    notifToggle.Name = "NotificationToggle"
    notifToggle.Size = UDim2.new(0, 36, 0, 36)
    notifToggle.Position = UDim2.new(1, -50, 0, 10)
    notifToggle.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    notifToggle.BackgroundTransparency = 0.1
    notifToggle.BorderSizePixel = 0
    notifToggle.Text = ""
    notifToggle.Parent = gui
    
    local notifToggleCorner = Instance.new("UICorner")
    notifToggleCorner.CornerRadius = UDim.new(1, 0)
    notifToggleCorner.Parent = notifToggle
    
    local notifIcon = Instance.new("ImageLabel")
    notifIcon.Size = UDim2.new(0, 18, 0, 18)
    notifIcon.Position = UDim2.new(0.5, -9, 0.5, -9)
    notifIcon.BackgroundTransparency = 1
    notifIcon.Image = "rbxassetid://6023426915" -- Replace with bell icon
    notifIcon.ImageColor3 = Color3.new(1, 1, 1)
    notifIcon.Parent = notifToggle
    
    local notifBadge = Instance.new("Frame")
    notifBadge.Name = "NotificationBadge"
    notifBadge.Size = UDim2.new(0, 18, 0, 18)
    notifBadge.Position = UDim2.new(1, -5, 0, -5)
    notifBadge.BackgroundColor3 = Color3.fromRGB(255, 77, 109)
    notifBadge.BorderSizePixel = 0
    notifBadge.Visible = false
    notifBadge.Parent = notifToggle
    
    local notifBadgeCorner = Instance.new("UICorner")
    notifBadgeCorner.CornerRadius = UDim.new(1, 0)
    notifBadgeCorner.Parent = notifBadge
    
    local notifBadgeText = Instance.new("TextLabel")
    notifBadgeText.Name = "BadgeText"
    notifBadgeText.Size = UDim2.new(1, 0, 1, 0)
    notifBadgeText.BackgroundTransparency = 1
    notifBadgeText.Text = "0"
    notifBadgeText.TextColor3 = Color3.new(1, 1, 1)
    notifBadgeText.Font = Enum.Font.GothamBold
    notifBadgeText.TextSize = 10
    notifBadgeText.Parent = notifBadge
    
    -- Connection Status
    local connStatus = Instance.new("Frame")
    connStatus.Name = "ConnectionStatus"
    connStatus.Size = UDim2.new(0, 120, 0, 24)
    connStatus.Position = UDim2.new(0, 10, 0, 10)
    connStatus.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    connStatus.BackgroundTransparency = 0.5
    connStatus.BorderSizePixel = 0
    connStatus.Parent = gui
    
    local connCorner = Instance.new("UICorner")
    connCorner.CornerRadius = UDim.new(0, 12)
    connCorner.Parent = connStatus
    
    local statusDot = Instance.new("Frame")
    statusDot.Name = "StatusDot"
    statusDot.Size = UDim2.new(0, 8, 0, 8)
    statusDot.Position = UDim2.new(0, 8, 0.5, -4)
    statusDot.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = connStatus
    
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = statusDot
    
    local connText = Instance.new("TextLabel")
    connText.Size = UDim2.new(1, -20, 1, 0)
    connText.Position = UDim2.new(0, 20, 0, 0)
    connText.BackgroundTransparency = 1
    connText.Text = "Connected"
    connText.TextColor3 = Color3.new(1, 1, 1)
    connText.Font = Enum.Font.Gotham
    connText.TextSize = 11
    connText.TextXAlignment = Enum.TextXAlignment.Left
    connText.Parent = connStatus
    
    -- Stats Bar
    local statsBar = Instance.new("Frame")
    statsBar.Name = "StatsBar"
    statsBar.Size = UDim2.new(1, 0, 0, 36)
    statsBar.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
    statsBar.BackgroundTransparency = 0.1
    statsBar.BorderSizePixel = 0
    statsBar.Parent = gui
    
    local statsLayout = Instance.new("UIListLayout")
    statsLayout.FillDirection = Enum.FillDirection.Horizontal
    statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    statsLayout.Padding = UDim.new(0, 20)
    statsLayout.Parent = statsBar
    
    local viewStat = Instance.new("TextLabel")
    viewStat.Name = "ViewStat"
    viewStat.BackgroundTransparency = 1
    viewStat.Text = "👁️ Views: 0"
    viewStat.TextColor3 = Color3.fromRGB(200, 200, 200)
    viewStat.Font = Enum.Font.Gotham
    viewStat.TextSize = 12
    viewStat.Parent = statsBar
    
    local activeStat = Instance.new("TextLabel")
    activeStat.Name = "ActiveStat"
    activeStat.BackgroundTransparency = 1
    activeStat.Text = "⚡ Live Active: 0"
    activeStat.TextColor3 = Color3.fromRGB(200, 200, 200)
    activeStat.Font = Enum.Font.Gotham
    activeStat.TextSize = 12
    activeStat.Parent = statsBar
    
    local timeStat = Instance.new("TextLabel")
    timeStat.Name = "TimeStat"
    timeStat.BackgroundTransparency = 1
    timeStat.Text = "🕒 " .. os.date("%H:%M")
    timeStat.TextColor3 = Color3.fromRGB(200, 200, 200)
    timeStat.Font = Enum.Font.Gotham
    timeStat.TextSize = 12
    timeStat.Parent = statsBar
    
    -- Return all created elements
    return {
        gui = gui,
        loadingOverlay = loadingOverlay,
        auth = {
            panel = authPanel,
            loginView = loginView,
            signupView = signupView,
            loginUser = loginUser,
            loginPass = loginPass,
            signupUser = signupUser,
            signupPass = signupPass,
            loginBtn = loginBtn,
            signupBtn = signupBtn,
            loginSpinner = loginSpinner,
            signupSpinner = signupSpinner,
            status = authStatus,
            loginLink = loginLink,
            signupLink = signupLink
        },
        main = {
            panel = mainPanel,
            welcome = welcomeLabel,
            userIdInput = userIdInput,
            generateBtn = generateBtn,
            genSpinner = genSpinner,
            statusMsg = statusMsg,
            keyOut = keyOut,
            feedbackBtn = feedbackBtn,
            logoutBtn = logoutBtn,
            adminBtn = adminBtn,
            adminInput = adminInput
        },
        feedback = {
            panel = feedbackPanel,
            closeBtn = fbCloseBtn,
            user = fbUser,
            userId = fbId,
            message = fbMsg,
            charCount = fbCharCount,
            submitBtn = fbSubmitBtn,
            spinner = fbSpinner
        },
        chat = {
            window = chatWindow,
            messages = chatMessages,
            input = chatInput,
            sendBtn = chatSendBtn,
            toggle = chatToggle,
            unreadBadge = unreadBadge,
            badgeText = badgeText,
            pinText = pinText,
            pinnedArea = pinnedArea,
            typingText = typingText,
            replyPreview = replyPreview,
            replyPreviewText = replyPreviewText,
            cancelReply = cancelReply,
            onlineCount = onlineCount,
            msgCount = msgCount
        },
        notifications = {
            center = notifCenter,
            list = notifList,
            layout = notifLayout,
            toggle = notifToggle,
            badge = notifBadge,
            badgeText = notifBadgeText,
            markReadBtn = markReadBtn,
            closeBtn = closeNotifBtn
        },
        stats = {
            bar = statsBar,
            view = viewStat,
            active = activeStat,
            time = timeStat
        },
        connection = {
            status = connStatus,
            dot = statusDot,
            text = connText
        }
    }
end

-- Event Handlers
local function setupEventHandlers(ui)
    -- Auth panel events
    ui.auth.loginBtn.MouseButton1Click:Connect(function()
        local username = ui.auth.loginUser.Text
        local password = ui.auth.loginPass.Text
        
        ui.auth.loginSpinner.Visible = true
        ui.auth.status.Text = ""
        
        local success, result = authenticateUser(username, password)
        
        ui.auth.loginSpinner.Visible = false
        
        if success then
            ui.auth.panel.Visible = false
            ui.main.panel.Visible = true
            ui.main.welcome.Text = "Logged in as: " .. username
            
            if username == ADMIN_USERNAME then
                ui.main.adminBtn.Visible = true
                ui.main.adminInput.Text = ADMIN_PASSWORD
            end
            
            addNotification("Welcome!", "Logged in as " .. username, "success")
        else
            ui.auth.status.Text = result
            ui.auth.status.TextColor3 = Color3.fromRGB(255, 59, 48)
        end
    end)
    
    ui.auth.signupBtn.MouseButton1Click:Connect(function()
        local username = ui.auth.signupUser.Text
        local password = ui.auth.signupPass.Text
        
        ui.auth.signupSpinner.Visible = true
        ui.auth.status.Text = ""
        
        local success, result = createUser(username, password)
        
        ui.auth.signupSpinner.Visible = false
        
        if success then
            ui.auth.status.Text = "Account created! Please login."
            ui.auth.status.TextColor3 = Color3.fromRGB(40, 200, 80)
            ui.auth.loginView.Visible = true
            ui.auth.signupView.Visible = false
            ui.auth.loginUser.Text = username
        else
            ui.auth.status.Text = result
            ui.auth.status.TextColor3 = Color3.fromRGB(255, 59, 48)
        end
    end)
    
    ui.auth.loginLink.MouseButton1Click:Connect(function()
        ui.auth.loginView.Visible = true
        ui.auth.signupView.Visible = false
        ui.auth.status.Text = ""
    end)
    
    ui.auth.signupLink.MouseButton1Click:Connect(function()
        ui.auth.signupView.Visible = true
        ui.auth.loginView.Visible = false
        ui.auth.status.Text = ""
    end)
    
    -- Main panel events
    ui.main.generateBtn.MouseButton1Click:Connect(function()
        local targetId = ui.main.userIdInput.Text:match("%d+")
        
        if not targetId then
            ui.main.statusMsg.Text = "Please enter a valid UserID"
            ui.main.statusMsg.TextColor3 = Color3.fromRGB(255, 59, 48)
            return
        end
        
        ui.main.genSpinner.Visible = true
        ui.main.statusMsg.Text = "Generating key..."
        ui.main.statusMsg.TextColor3 = Color3.fromRGB(200, 200, 200)
        
        local key, message = generateKeyForUser(targetId, currentUser.username)
        
        ui.main.genSpinner.Visible = false
        
        if key then
            ui.main.keyOut.Text = key
            ui.main.statusMsg.Text = "✅ Key generated successfully!"
            ui.main.statusMsg.TextColor3 = Color3.fromRGB(40, 200, 80)
            ui.main.userIdInput.Text = ""
            addNotification("🔑 Key Generated", "New key for UserID " .. targetId, "success")
        else
            ui.main.statusMsg.Text = "❌ " .. message
            ui.main.statusMsg.TextColor3 = Color3.fromRGB(255, 59, 48)
        end
    end)
    
    ui.main.feedbackBtn.MouseButton1Click:Connect(function()
        ui.main.panel.Visible = false
        ui.feedback.panel.Visible = true
    end)
    
    ui.main.logoutBtn.MouseButton1Click:Connect(function()
        currentUser = nil
        ui.main.panel.Visible = false
        ui.auth.panel.Visible = true
        ui.auth.loginView.Visible = true
        ui.auth.signupView.Visible = false
        ui.auth.loginUser.Text = ""
        ui.auth.loginPass.Text = ""
        ui.auth.signupUser.Text = ""
        ui.auth.signupPass.Text = ""
        ui.main.adminBtn.Visible = false
        ui.main.adminInput.Text = ""
        ui.main.keyOut.Text = ""
        ui.main.statusMsg.Text = ""
        addNotification("👋 Goodbye!", "Logged out successfully", "info")
    end)
    
    ui.main.adminBtn.MouseButton1Click:Connect(function()
        if ui.main.adminInput.Text == ADMIN_PASSWORD then
            ui.main.panel.Visible = false
            -- Show admin panel (to be implemented)
            addNotification("👑 Admin Access", "Admin panel unlocked", "success")
        else
            ui.main.statusMsg.Text = "❌ Invalid admin password"
            ui.main.statusMsg.TextColor3 = Color3.fromRGB(255, 59, 48)
        end
    end)
    
    -- Feedback panel events
    ui.feedback.closeBtn.MouseButton1Click:Connect(function()
        ui.feedback.panel.Visible = false
        ui.main.panel.Visible = true
        ui.feedback.user.Text = ""
        ui.feedback.userId.Text = ""
        ui.feedback.message.Text = ""
    end)
    
    ui.feedback.message:GetPropertyChangedSignal("Text"):Connect(function()
        local text = ui.feedback.message.Text
        local count = #text
        ui.feedback.charCount.Text = count .. "/500"
        if count > 500 then
            ui.feedback.message.Text = text:sub(1, 500)
            ui.feedback.charCount.Text = "500/500"
        end
    end)
    
    ui.feedback.submitBtn.MouseButton1Click:Connect(function()
        local user = ui.feedback.user.Text
        local userId = ui.feedback.userId.Text
        local message = ui.feedback.message.Text
        
        if user == "" or userId == "" or message == "" then
            addNotification("❌ Error", "Please fill in all fields", "error")
            return
        end
        
        ui.feedback.spinner.Visible = true
        
        local success, result = submitFeedback(user, userId, message)
        
        ui.feedback.spinner.Visible = false
        
        if success then
            addNotification("✅ Feedback Submitted", "Thank you for your feedback!", "success")
            ui.feedback.panel.Visible = false
            ui.main.panel.Visible = true
            ui.feedback.user.Text = ""
            ui.feedback.userId.Text = ""
            ui.feedback.message.Text = ""
        else
            addNotification("❌ Error", result or "Failed to submit feedback", "error")
        end
    end)
    
    -- Chat events
    ui.chat.toggle.MouseButton1Click:Connect(function()
        ui.chat.window.Visible = not ui.chat.window.Visible
        if ui.chat.window.Visible then
            chatUnreadCount = 0
            ui.chat.unreadBadge.Visible = false
        end
    end)
    
    ui.chat.sendBtn.MouseButton1Click:Connect(function()
        local message = ui.chat.input.Text
        if message ~= "" then
            local success = sendChatMessage(message)
            if success then
                ui.chat.input.Text = ""
                ui.chat.replyPreview.Visible = false
                replyTarget = nil
            end
        end
    end)
    
    ui.chat.input:GetPropertyChangedSignal("Text"):Connect(function()
        -- Typing indicator would go here
    end)
    
    ui.chat.cancelReply.MouseButton1Click:Connect(function()
        ui.chat.replyPreview.Visible = false
        replyTarget = nil
    end)
    
    -- Notification events
    ui.notifications.toggle.MouseButton1Click:Connect(function()
        ui.notifications.center.Visible = not ui.notifications.center.Visible
        if ui.notifications.center.Visible then
            renderNotifications(ui)
        end
    end)
    
    ui.notifications.closeBtn.MouseButton1Click:Connect(function()
        ui.notifications.center.Visible = false
    end)
    
    ui.notifications.markReadBtn.MouseButton1Click:Connect(function()
        for _, notif in ipairs(notifications) do
            notif.read = true
        end
        updateNotificationBadge(ui)
        renderNotifications(ui)
    end)
    
    -- Connection status updates
    task.spawn(function()
        while true do
            task.wait(5)
            local success = refreshData()
            if success then
                ui.connection.dot.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
                ui.connection.text.Text = "Connected"
            else
                ui.connection.dot.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
                ui.connection.text.Text = "Disconnected"
            end
        end
    end)
    
    -- Stats updates
    task.spawn(function()
        while true do
            task.wait(30)
            ui.stats.time.Text = "🕒 " .. os.date("%H:%M")
            ui.stats.view.Text = "👁️ Views: " .. math.random(100, 500)
            ui.stats.active.Text = "⚡ Live Active: " .. math.random(10, 50)
        end
    end)
    
    -- Chat message polling
    task.spawn(function()
        while true do
            task.wait(3)
            if ui.chat.window.Visible then
                renderChatMessages(ui)
            else
                -- Check for new messages for badge
                if dataCache and dataCache.chats then
                    local lastMsg = dataCache.chats[#dataCache.chats]
                    if lastMsg and lastMsg.timestamp > (lastSeenMessageTime or 0) then
                        if lastMsg.user ~= username then
                            chatUnreadCount = chatUnreadCount + 1
                            updateChatBadge(ui)
                        end
                    end
                end
            end
        end
    end)
end

-- Render functions
local function renderNotifications(ui)
    local list = ui.notifications.list
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    if #notifications == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 100)
        empty.BackgroundTransparency = 1
        empty.Text = "🔔\nNo notifications"
        empty.TextColor3 = Color3.fromRGB(150, 150, 150)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 13
        empty.Parent = list
        return
    end
    
    for i, notif in ipairs(notifications) do
        local item = Instance.new("Frame")
        item.Name = "Notification" .. i
        item.Size = UDim2.new(1, 0, 0, 80)
        item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        item.BackgroundTransparency = notif.read and 0.97 or 0.95
        item.BorderSizePixel = 0
        item.Parent = list
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = item
        
        if not notif.read then
            local border = Instance.new("Frame")
            border.Size = UDim2.new(0, 3, 1, -10)
            border.Position = UDim2.new(0, 0, 0, 5)
            border.BackgroundColor3 = Color3.fromRGB(255, 77, 109)
            border.BorderSizePixel = 0
            border.Parent = item
            
            local borderCorner = Instance.new("UICorner")
            borderCorner.CornerRadius = UDim.new(0, 2)
            borderCorner.Parent = border
        end
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 20)
        title.Position = UDim2.new(0, 10, 0, 10)
        title.BackgroundTransparency = 1
        title.Text = notif.title
        title.TextColor3 = Color3.fromRGB(79, 124, 255)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = item
        
        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, -20, 0, 30)
        msg.Position = UDim2.new(0, 10, 0, 30)
        msg.BackgroundTransparency = 1
        msg.Text = notif.message
        msg.TextColor3 = Color3.new(1, 1, 1)
        msg.Font = Enum.Font.Gotham
        msg.TextSize = 11
        msg.TextWrapped = true
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.Parent = item
        
        local time = Instance.new("TextLabel")
        time.Size = UDim2.new(1, -20, 0, 15)
        time.Position = UDim2.new(0, 10, 1, -20)
        time.BackgroundTransparency = 1
        time.Text = formatTime(notif.timestamp)
        time.TextColor3 = Color3.fromRGB(150, 150, 150)
        time.Font = Enum.Font.Gotham
        time.TextSize = 9
        time.TextXAlignment = Enum.TextXAlignment.Left
        time.Parent = item
        
        item.MouseButton1Click:Connect(function()
            notif.read = true
            updateNotificationBadge(ui)
            renderNotifications(ui)
        end)
    end
    
    -- Update canvas size
    local contentHeight = #notifications * 88
    list.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
end

local function renderChatMessages(ui)
    if not dataCache or not dataCache.chats then return end
    
    local messages = ui.chat.messages
    local container = messages
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            child:Destroy()
        end
    end
    
    local chats = dataCache.chats
    if #chats == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 100)
        empty.BackgroundTransparency = 1
        empty.Text = "💬\nNo messages yet"
        empty.TextColor3 = Color3.fromRGB(150, 150, 150)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 13
        empty.Parent = container
        return
    end
    
    ui.chat.msgCount.Text = "💬 " .. #chats
    
    for i, msg in ipairs(chats) do
        local isOwner = msg.user == "plstealme2"
        local isSystem = msg.user == "SYSTEM"
        
        local item = Instance.new("Frame")
        item.Name = "Message" .. i
        item.Size = UDim2.new(1, 0, 0, 0)
        item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        item.BackgroundTransparency = isSystem and 0.92 or 0.97
        item.BorderSizePixel = 0
        item.Parent = container
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = item
        
        if isOwner then
            local border = Instance.new("Frame")
            border.Size = UDim2.new(0, 3, 1, -10)
            border.Position = UDim2.new(0, 0, 0, 5)
            border.BackgroundColor3 = Color3.fromRGB(255, 204, 0)
            border.BorderSizePixel = 0
            border.Parent = item
            
            local borderCorner = Instance.new("UICorner")
            borderCorner.CornerRadius = UDim.new(0, 2)
            borderCorner.Parent = border
        elseif isSystem then
            local border = Instance.new("Frame")
            border.Size = UDim2.new(0, 3, 1, -10)
            border.Position = UDim2.new(0, 0, 0, 5)
            border.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
            border.BorderSizePixel = 0
            border.Parent = item
            
            local borderCorner = Instance.new("UICorner")
            borderCorner.CornerRadius = UDim.new(0, 2)
            borderCorner.Parent = border
        end
        
        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, -20, 0, 20)
        header.Position = UDim2.new(0, 10, 0, 10)
        header.BackgroundTransparency = 1
        header.Parent = item
        
        local userLabel = Instance.new("TextLabel")
        userLabel.Size = UDim2.new(0.7, 0, 1, 0)
        userLabel.BackgroundTransparency = 1
        userLabel.Text = msg.user
        userLabel.TextColor3 = isSystem and Color3.fromRGB(79, 124, 255) or (isOwner and Color3.fromRGB(255, 204, 0) or Color3.fromRGB(200, 200, 200))
        userLabel.Font = isOwner and Enum.Font.GothamBold or Enum.Font.Gotham
        userLabel.TextSize = 12
        userLabel.TextXAlignment = Enum.TextXAlignment.Left
        userLabel.Parent = header
        
        if isOwner then
            local crown = Instance.new("TextLabel")
            crown.Size = UDim2.new(0, 20, 1, 0)
            crown.Position = UDim2.new(0.7, 5, 0, 0)
            crown.BackgroundTransparency = 1
            crown.Text = "👑"
            crown.TextColor3 = Color3.fromRGB(255, 204, 0)
            crown.Font = Enum.Font.Gotham
            crown.TextSize = 12
            crown.Parent = header
        end
        
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(0.3, -10, 1, 0)
        timeLabel.Position = UDim2.new(0.7, isOwner and 25 or 0, 0, 0)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = formatTime(msg.timestamp)
        timeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        timeLabel.Font = Enum.Font.Gotham
        timeLabel.TextSize = 10
        timeLabel.TextXAlignment = Enum.TextXAlignment.Right
        timeLabel.Parent = header
        
        local content = Instance.new("TextLabel")
        content.Size = UDim2.new(1, -20, 0, 0)
        content.Position = UDim2.new(0, 10, 0, 35)
        content.BackgroundTransparency = 1
        content.Text = msg.txt
        content.TextColor3 = Color3.new(1, 1, 1)
        content.Font = Enum.Font.Gotham
        content.TextSize = 13
        content.TextWrapped = true
        content.RichText = true
        content.Parent = item
        
        -- Calculate height
        local textBounds = content.TextBounds
        content.Size = UDim2.new(1, -20, 0, textBounds.Y)
        item.Size = UDim2.new(1, 0, 0, textBounds.Y + 50)
        
        -- Reply button
        local replyBtn = Instance.new("TextButton")
        replyBtn.Size = UDim2.new(0, 20, 0, 20)
        replyBtn.Position = UDim2.new(1, -25, 0, 10)
        replyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        replyBtn.BackgroundTransparency = 0.5
        replyBtn.BorderSizePixel = 0
        replyBtn.Text = "↩️"
        replyBtn.TextColor3 = Color3.new(1, 1, 1)
        replyBtn.Font = Enum.Font.Gotham
        replyBtn.TextSize = 12
        replyBtn.Visible = false
        replyBtn.Parent = item
        
        local replyCorner = Instance.new("UICorner")
        replyCorner.CornerRadius = UDim.new(0, 4)
        replyCorner.Parent = replyBtn
        
        replyBtn.MouseButton1Click:Connect(function()
            replyTarget = msg
            ui.chat.replyPreview.Visible = true
            ui.chat.replyPreviewText.Text = "Replying to " .. msg.user .. ": " .. msg.txt:sub(1, 30) .. (msg.txt:len() > 30 and "..." or "")
        end)
        
        item.MouseEnter:Connect(function()
            replyBtn.Visible = true
        end)
        
        item.MouseLeave:Connect(function()
            replyBtn.Visible = false
        end)
    end
    
    -- Scroll to bottom
    task.wait()
    container.CanvasSize = UDim2.new(0, 0, 0, container.UIListLayout.AbsoluteContentSize.Y)
    container.CanvasPosition = Vector2.new(0, container.CanvasSize.Y.Offset)
end

local function updateNotificationBadge(ui)
    local unreadCount = 0
    for _, notif in ipairs(notifications) do
        if not notif.read then
            unreadCount = unreadCount + 1
        end
    end
    
    if unreadCount > 0 then
        ui.notifications.badge.Visible = true
        ui.notifications.badgeText.Text = tostring(unreadCount)
    else
        ui.notifications.badge.Visible = false
    end
end

local function updateChatBadge(ui)
    if chatUnreadCount > 0 then
        ui.chat.unreadBadge.Visible = true
        ui.chat.badgeText.Text = tostring(chatUnreadCount)
    else
        ui.chat.unreadBadge.Visible = false
    end
end

-- Initialize everything
local ui = initializeGUI()
setupEventHandlers(ui)

-- Initial data fetch
refreshData()

-- Check for saved session
local success, result = pcall(function()
    -- Check local storage for session (would need a DataStore in real implementation)
end)

-- Show auth panel by default
ui.auth.panel.Visible = true
ui.main.panel.Visible = false
ui.feedback.panel.Visible = false

addNotification("🚀 System Ready", "RSQ Elite System initialized", "success")

-- Anti-cheat / Security
local function checkForExploits()
    -- Basic anti-exploit measures
    if not isInGroup() then
        -- Show group join UI
        local groupUI = Instance.new("Frame")
        groupUI.Size = UDim2.new(0, 400, 0, 300)
        groupUI.Position = UDim2.new(0.5, -200, 0.5, -150)
        groupUI.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
        groupUI.BackgroundTransparency = 0.1
        groupUI.BorderSizePixel = 0
        groupUI.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 20)
        corner.Parent = groupUI
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 60)
        title.Position = UDim2.new(0, 0, 0, 20)
        title.BackgroundTransparency = 1
        title.Text = "⚠️ ACCESS DENIED"
        title.TextColor3 = Color3.fromRGB(255, 59, 48)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 24
        title.Parent = groupUI
        
        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, -40, 0, 80)
        msg.Position = UDim2.new(0, 20, 0, 100)
        msg.BackgroundTransparency = 1
        msg.Text = "You must join the group before accessing the system!\n\nGroup ID: " .. GROUP_ID
        msg.TextColor3 = Color3.new(1, 1, 1)
        msg.Font = Enum.Font.Gotham
        msg.TextSize = 14
        msg.TextWrapped = true
        msg.Parent = groupUI
        
        local joinBtn = Instance.new("TextButton")
        joinBtn.Size = UDim2.new(0.8, 0, 0, 45)
        joinBtn.Position = UDim2.new(0.1, 0, 1, -70)
        joinBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        joinBtn.BorderSizePixel = 0
        joinBtn.Text = "📋 Copy Group Link"
        joinBtn.TextColor3 = Color3.new(1, 1, 1)
        joinBtn.Font = Enum.Font.GothamBold
        joinBtn.TextSize = 14
        joinBtn.Parent = groupUI
        
        local joinCorner = Instance.new("UICorner")
        joinCorner.CornerRadius = UDim.new(0, 10)
        joinCorner.Parent = joinBtn
        
        joinBtn.MouseButton1Click:Connect(function()
            setclipboard("https://www.roblox.com/groups/" .. GROUP_ID)
            addNotification("✅ Copied!", "Group link copied to clipboard", "success")
        end)
        
        -- Keep checking until user joins
        task.spawn(function()
            while not isInGroup() do
                task.wait(5)
            end
            groupUI:Destroy()
            addNotification("✅ Group Joined!", "Access granted. Welcome!", "success")
        end)
    end
end

-- Run security check
task.spawn(checkForExploits)

print("RSQ Elite System loaded successfully!")
