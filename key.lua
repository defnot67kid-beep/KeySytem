--[[
    RSQ Elite - Firebase Integration
    Works with HTML Admin Panel
]]

-- Firebase Configuration (matches your HTML)
local FIREBASE_CONFIG = {
    apiKey = "AIzaSyAupBkllyicDPD9O6CmX4mS4sF5z96mqxc",
    projectId = "vertexpaste",
    databaseURL = "https://firestore.googleapis.com/v1/projects/vertexpaste/databases/(default)/documents"
}

-- Improved Firebase Service
local FirebaseService = {}
FirebaseService.__index = FirebaseService

function FirebaseService.new(apiKey, projectId)
    local self = setmetatable({}, FirebaseService)
    self.apiKey = apiKey
    self.projectId = projectId
    self.baseUrl = string.format("https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents", projectId)
    self.cache = {}
    self.cacheTime = {}
    return self
end

function FirebaseService:getDocument(path)
    -- Check cache first (1 second cache for faster updates)
    if self.cache[path] and self.cacheTime[path] and (os.time() - self.cacheTime[path]) < 1 then
        return self.cache[path]
    end
    
    local url = string.format("%s/%s?key=%s", self.baseUrl, path, self.apiKey)
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success and response then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(response)
        end)
        if success and data then
            -- Convert Firestore format to Lua table
            local converted = self:_fromFirestore(data)
            self.cache[path] = converted
            self.cacheTime[path] = os.time()
            return converted
        end
    end
    return nil
end

function FirebaseService:queryCollection(collection)
    local url = string.format("%s/%s?key=%s", self.baseUrl, collection, self.apiKey)
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    
    if success and response then
        local success, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(response)
        end)
        if success and data and data.documents then
            local results = {}
            for _, doc in ipairs(data.documents) do
                table.insert(results, self:_fromFirestore(doc))
            end
            return results
        end
    end
    return {}
end

function FirebaseService:updateDocument(path, data)
    local url = string.format("%s/%s?key=%s", self.baseUrl, path, self.apiKey)
    
    -- Convert to Firestore format
    local firestoreData = self:_toFirestore(data)
    local jsonData = game:GetService("HttpService"):JSONEncode(firestoreData)
    
    local success, response = pcall(function()
        return game:HttpPost(url, jsonData, Enum.HttpContentType.ApplicationJson, false)
    end)
    
    -- Clear cache for this path
    self.cache[path] = nil
    self.cacheTime[path] = nil
    
    return success
end

function FirebaseService:_fromFirestore(doc)
    if not doc or not doc.fields then return doc end
    
    local result = {}
    for key, value in pairs(doc.fields) do
        if value.stringValue then
            result[key] = value.stringValue
        elseif value.integerValue then
            result[key] = tonumber(value.integerValue)
        elseif value.booleanValue then
            result[key] = value.booleanValue
        elseif value.arrayValue then
            result[key] = self:_fromFirestoreArray(value.arrayValue.values)
        elseif value.mapValue then
            result[key] = self:_fromFirestore({fields = value.mapValue.fields})
        end
    end
    return result
end

function FirebaseService:_fromFirestoreArray(values)
    local result = {}
    if not values then return result end
    
    for _, value in ipairs(values) do
        if value.stringValue then
            table.insert(result, value.stringValue)
        elseif value.integerValue then
            table.insert(result, tonumber(value.integerValue))
        elseif value.booleanValue then
            table.insert(result, value.booleanValue)
        elseif value.mapValue then
            table.insert(result, self:_fromFirestore({fields = value.mapValue.fields}))
        end
    end
    return result
end

function FirebaseService:_toFirestore(data)
    local fields = {}
    for key, value in pairs(data) do
        fields[key] = self:_toFirestoreValue(value)
    end
    return {fields = fields}
end

function FirebaseService:_toFirestoreValue(value)
    if type(value) == "string" then
        return {stringValue = value}
    elseif type(value) == "number" then
        if value % 1 == 0 then
            return {integerValue = tostring(value)}
        else
            return {doubleValue = value}
        end
    elseif type(value) == "boolean" then
        return {booleanValue = value}
    elseif type(value) == "table" then
        -- Check if array
        local isArray = true
        for i, _ in ipairs(value) do
            if type(i) ~= "number" then
                isArray = false
                break
            end
        end
        
        if isArray then
            local values = {}
            for _, item in ipairs(value) do
                table.insert(values, self:_toFirestoreValue(item))
            end
            return {arrayValue = {values = values}}
        else
            return {mapValue = self:_toFirestore(value)}
        end
    end
    return {nullValue = "NULL_VALUE"}
end

-- Initialize Firebase
local firebase = FirebaseService.new(FIREBASE_CONFIG.apiKey, FIREBASE_CONFIG.projectId)

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

-- Constants
local GROUP_ID = 687789545  -- CASHGRAB-EXPERIENCE
local MERCH_URL = "https://www.roblox.com/catalog/7942034851/RSQ-Elite-Merch"
local GROUP_URL = "https://www.roblox.com/groups/687789545/CASHGRAB-EXPERIENCE"
local REQUIRED_SCRIPTS = {
    "https://raw.githubusercontent.com/yourusername/yourrepo/main/script1.lua",
    "https://raw.githubusercontent.com/yourusername/yourrepo/main/script2.lua"
}

-- Variables
local player = Players.LocalPlayer
local userId = tostring(player.UserId)
local username = player.Name
local placeId = tostring(game.PlaceId)

local systemData = nil
local userKey = nil
local keyValid = false
local isAdmin = false
local isInGroup = false
local guiOpen = false
local mainGui = nil
local toggleButton = nil
local currentGameData = nil
local activeGui = nil
local lastRefreshTime = 0
local isBanned = false
local banReason = ""

-- Notification system
local function showNotification(message, color, duration)
    duration = duration or 3
    color = color or Color3.fromRGB(79, 124, 255)
    
    local notification = Instance.new("ScreenGui")
    notification.Name = "RSQ_Notification"
    notification.IgnoreGuiInset = true
    notification.ResetOnSpawn = false
    notification.Parent = player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 45)
    frame.Position = UDim2.new(1, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = notification
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local leftBar = Instance.new("Frame")
    leftBar.Size = UDim2.new(0, 4, 1, 0)
    leftBar.BackgroundColor3 = color
    leftBar.BorderSizePixel = 0
    leftBar.Parent = frame
    
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 4)
    leftCorner.Parent = leftBar
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, 0)
    textLabel.Position = UDim2.new(0, 15, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = message
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 13
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = frame
    
    -- Slide in animation
    frame.Position = UDim2.new(1, 20, 0, 20)
    TweenService:Create(frame, TweenInfo.new(0.3), {Position = UDim2.new(1, -290, 0, 20)}):Play()
    
    -- Auto remove
    task.delay(duration, function()
        if frame and frame.Parent then
            TweenService:Create(frame, TweenInfo.new(0.3), {Position = UDim2.new(1, 20, 0, 20)}):Play()
            task.delay(0.3, function()
                if notification then notification:Destroy() end
            end)
        end
    end)
end

-- Close all open GUIs function
local function closeAllGuis()
    if activeGui and activeGui.Parent then
        activeGui:Destroy()
        activeGui = nil
    end
    if mainGui and mainGui.Parent then
        mainGui:Destroy()
        mainGui = nil
        guiOpen = false
    end
end

-- Group check function
local function checkGroup()
    local success, result = pcall(function()
        return player:IsInGroup(GROUP_ID)
    end)
    
    if success then
        local oldStatus = isInGroup
        isInGroup = result
        
        -- If group status changed
        if oldStatus ~= isInGroup then
            if isInGroup then
                showNotification("✅ You joined the group!", Color3.fromRGB(40, 200, 80))
                -- Close group GUI if open
                if activeGui and activeGui.Name == "RSQ_GroupRequired" then
                    activeGui:Destroy()
                    activeGui = nil
                end
            else
                showNotification("❌ You left the group!", Color3.fromRGB(255, 60, 60))
                -- Force close everything and show group GUI
                closeAllGuis()
                keyValid = false
                userKey = nil
                deleteSavedKey()
            end
            
            -- Update toggle button
            if toggleButton and toggleButton.Parent then
                toggleButton:Destroy()
                createToggleButton()
            end
        end
        
        return result
    end
    return false
end

-- Load system data from Firebase
local function loadSystemData()
    local success, data = pcall(function()
        return firebase:getDocument("system/config")
    end)
    
    if success and data then
        systemData = data
        return true
    end
    return false
end

-- Check if user is banned
local function checkBan()
    if not systemData or not systemData.bans then 
        isBanned = false
        return false 
    end
    
    -- Check by username
    if systemData.bans[username] then
        isBanned = true
        banReason = systemData.bans[username].reason or "Banned"
        return true, banReason
    end
    
    -- Check by userId
    if systemData.bans[userId] then
        isBanned = true
        banReason = systemData.bans[userId].reason or "Banned"
        return true, banReason
    end
    
    isBanned = false
    return false
end

-- Validate key against Firebase
local function validateKey(key)
    if not systemData or not systemData.keys then
        return false, "System error"
    end
    
    -- Find key in database
    local keyData = systemData.keys[key]
    if not keyData then
        return false, "Invalid key"
    end
    
    -- Check if key belongs to this user
    if tostring(keyData.rbx) ~= userId then
        return false, "Key belongs to another user"
    end
    
    -- Check expiration
    if keyData.exp ~= "INF" then
        local expTime = tonumber(keyData.exp)
        if expTime and os.time() > expTime then
            return false, "Key expired"
        end
    end
    
    return true, keyData
end

-- Save key locally
local function saveKey(key)
    if not isfile then return end
    
    local folder = "RSQ_Elite"
    if not isfolder(folder) then
        makefolder(folder)
    end
    
    local file = folder .. "/key_" .. userId .. ".txt"
    writefile(file, key)
end

-- Load saved key
local function loadSavedKey()
    if not isfile then return nil end
    
    local folder = "RSQ_Elite"
    local file = folder .. "/key_" .. userId .. ".txt"
    
    if isfile(file) then
        return readfile(file)
    end
    return nil
end

-- Delete saved key
local function deleteSavedKey()
    if not isfile then return end
    
    local folder = "RSQ_Elite"
    local file = folder .. "/key_" .. userId .. ".txt"
    
    if isfile(file) then
        delfile(file)
    end
end

-- Check if script URL is valid
local function isScriptValid(url)
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    return success and response and #response > 0
end

-- Execute script from URL
local function executeScriptFromUrl(url, scriptName)
    showNotification("⚡ Loading " .. scriptName, Color3.fromRGB(79, 124, 255))
    
    local success, result = pcall(function()
        local scriptContent = game:HttpGet(url)
        if scriptContent and #scriptContent > 0 then
            local func = loadstring(scriptContent)
            if func then
                func()
                return true
            end
        end
        return false
    end)
    
    if success then
        showNotification("✅ Script loaded: " .. scriptName, Color3.fromRGB(40, 200, 80))
    else
        showNotification("❌ Failed to load script", Color3.fromRGB(255, 60, 60))
    end
end

-- Execute script with game ID check
local function executeScript(scriptData, gameData)
    -- Check if script URL is still valid
    if not isScriptValid(scriptData.url) then
        showNotification("❌ Script no longer exists", Color3.fromRGB(255, 60, 60))
        return
    end
    
    -- Check if game ID matches
    if gameData and gameData.id and tostring(gameData.id) ~= placeId then
        -- Show game ID mismatch UI
        local gui = Instance.new("ScreenGui")
        gui.Name = "RSQ_GameMismatch"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.Parent = player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
        activeGui = gui
        
        local main = Instance.new("Frame")
        main.Size = UDim2.new(0, 350, 0, 220)
        main.Position = UDim2.new(0.5, -175, 0.5, -110)
        main.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
        main.BackgroundTransparency = 0.1
        main.BorderSizePixel = 0
        main.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = main
        
        -- Title bar with X button
        local titleBar = Instance.new("Frame")
        titleBar.Size = UDim2.new(1, 0, 0, 35)
        titleBar.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
        titleBar.BackgroundTransparency = 0.2
        titleBar.BorderSizePixel = 0
        titleBar.Parent = main
        
        local titleCorner = Instance.new("UICorner")
        titleCorner.CornerRadius = UDim.new(0, 12)
        titleCorner.Parent = titleBar
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -40, 1, 0)
        title.Position = UDim2.new(0, 10, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "⚠️ Wrong Game"
        title.TextColor3 = Color3.fromRGB(255, 140, 0)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = titleBar
        
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 22, 0, 22)
        closeBtn.Position = UDim2.new(1, -27, 0.5, -11)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.new(1, 1, 1)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 14
        closeBtn.BorderSizePixel = 0
        closeBtn.Parent = titleBar
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 6)
        closeCorner.Parent = closeBtn
        
        closeBtn.MouseButton1Click:Connect(function()
            gui:Destroy()
            activeGui = nil
        end)
        
        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -20, 0, 70)
        desc.Position = UDim2.new(0, 10, 0, 45)
        desc.BackgroundTransparency = 1
        desc.Text = string.format(
            "This script is for:\n%s (ID: %s)\n\nCurrent game: %s",
            gameData.name or "Unknown",
            tostring(gameData.id),
            placeId
        )
        desc.TextColor3 = Color3.fromRGB(200, 200, 200)
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 12
        desc.TextWrapped = true
        desc.Parent = main
        
        local teleportBtn = Instance.new("TextButton")
        teleportBtn.Size = UDim2.new(0, 140, 0, 35)
        teleportBtn.Position = UDim2.new(0.5, -150, 1, -50)
        teleportBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        teleportBtn.Text = "🚀 Teleport"
        teleportBtn.TextColor3 = Color3.new(1, 1, 1)
        teleportBtn.Font = Enum.Font.GothamBold
        teleportBtn.TextSize = 13
        teleportBtn.BorderSizePixel = 0
        teleportBtn.Parent = main
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = teleportBtn
        
        local hereBtn = Instance.new("TextButton")
        hereBtn.Size = UDim2.new(0, 140, 0, 35)
        hereBtn.Position = UDim2.new(0.5, 10, 1, -50)
        hereBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
        hereBtn.Text = "🎮 Use Here"
        hereBtn.TextColor3 = Color3.new(1, 1, 1)
        hereBtn.Font = Enum.Font.GothamBold
        hereBtn.TextSize = 13
        hereBtn.BorderSizePixel = 0
        hereBtn.Parent = main
        
        local hereCorner = Instance.new("UICorner")
        hereCorner.CornerRadius = UDim.new(0, 8)
        hereCorner.Parent = hereBtn
        
        teleportBtn.MouseButton1Click:Connect(function()
            gui:Destroy()
            activeGui = nil
            local gameId = tonumber(gameData.id)
            if gameId then
                showNotification("🚀 Teleporting...", Color3.fromRGB(79, 124, 255))
                TeleportService:Teleport(gameId, player)
            end
        end)
        
        hereBtn.MouseButton1Click:Connect(function()
            gui:Destroy()
            activeGui = nil
            executeScriptFromUrl(scriptData.url, scriptData.name)
        end)
        
        return
    end
    
    executeScriptFromUrl(scriptData.url, scriptData.name)
end

-- Create main GUI
local function createMainGUI()
    if mainGui and mainGui.Parent then
        mainGui:Destroy()
    end
    
    mainGui = Instance.new("ScreenGui")
    mainGui.Name = "RSQ_MainGUI"
    mainGui.IgnoreGuiInset = true
    mainGui.ResetOnSpawn = false
    mainGui.Parent = player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    activeGui = mainGui
    
    -- Main frame
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 400, 0, 350)
    main.Position = UDim2.new(0.5, -200, 0.5, -175)
    main.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
    main.BackgroundTransparency = 0.1
    main.BorderSizePixel = 0
    main.Parent = mainGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = main
    
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🎮 RSQ GAMES LIBRARY"
    title.TextColor3 = Color3.fromRGB(79, 124, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -27, 0.5, -11)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        guiOpen = false
        mainGui:Destroy()
        mainGui = nil
        activeGui = nil
    end)
    
    -- Back button
    local backBtn = Instance.new("TextButton")
    backBtn.Size = UDim2.new(0, 55, 0, 22)
    backBtn.Position = UDim2.new(0, 10, 1, -32)
    backBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
    backBtn.Text = "← Back"
    backBtn.TextColor3 = Color3.new(1, 1, 1)
    backBtn.Font = Enum.Font.GothamBold
    backBtn.TextSize = 11
    backBtn.BorderSizePixel = 0
    backBtn.Visible = false
    backBtn.Parent = main
    
    local backCorner = Instance.new("UICorner")
    backCorner.CornerRadius = UDim.new(0, 6)
    backCorner.Parent = backBtn
    
    -- Games container
    local gamesContainer = Instance.new("ScrollingFrame")
    gamesContainer.Size = UDim2.new(1, -20, 1, -70)
    gamesContainer.Position = UDim2.new(0, 10, 0, 45)
    gamesContainer.BackgroundTransparency = 1
    gamesContainer.ScrollBarThickness = 4
    gamesContainer.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    gamesContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    gamesContainer.Visible = true
    gamesContainer.Parent = main
    
    local gamesLayout = Instance.new("UIListLayout")
    gamesLayout.Padding = UDim.new(0, 6)
    gamesLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gamesLayout.Parent = gamesContainer
    
    -- Scripts container
    local scriptsContainer = Instance.new("ScrollingFrame")
    scriptsContainer.Size = UDim2.new(1, -20, 1, -70)
    scriptsContainer.Position = UDim2.new(0, 10, 0, 45)
    scriptsContainer.BackgroundTransparency = 1
    scriptsContainer.ScrollBarThickness = 4
    scriptsContainer.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    scriptsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    scriptsContainer.Visible = false
    scriptsContainer.Parent = main
    
    local scriptsLayout = Instance.new("UIListLayout")
    scriptsLayout.Padding = UDim.new(0, 6)
    scriptsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    scriptsLayout.Parent = scriptsContainer
    
    -- Refresh button
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0, 70, 0, 22)
    refreshBtn.Position = UDim2.new(1, -80, 1, -32)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    refreshBtn.Text = "🔄 Refresh"
    refreshBtn.TextColor3 = Color3.new(1, 1, 1)
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 10
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Parent = main
    
    local refreshCorner = Instance.new("UICorner")
    refreshCorner.CornerRadius = UDim.new(0, 6)
    refreshCorner.Parent = refreshBtn
    
    -- Functions to switch views
    local function showGames()
        gamesContainer.Visible = true
        scriptsContainer.Visible = false
        backBtn.Visible = false
        title.Text = "🎮 RSQ GAMES LIBRARY"
        currentGameData = nil
        loadGames()
    end
    
    local function showScripts(gameData)
        gamesContainer.Visible = false
        scriptsContainer.Visible = true
        backBtn.Visible = true
        title.Text = "📜 " .. gameData.name
        currentGameData = gameData
        loadScripts(gameData)
    end
    
    -- Load scripts function
    local function loadScripts(gameData)
        -- Clear scripts container
        for _, child in ipairs(scriptsContainer:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        -- Load scripts
        local scripts = gameData.scripts or {}
        if #scripts == 0 then
            local emptyFrame = Instance.new("Frame")
            emptyFrame.Size = UDim2.new(1, 0, 0, 60)
            emptyFrame.BackgroundTransparency = 1
            emptyFrame.Parent = scriptsContainer
            
            local emptyText = Instance.new("TextLabel")
            emptyText.Size = UDim2.new(1, 0, 1, 0)
            emptyText.BackgroundTransparency = 1
            emptyText.Text = "📭 No scripts available"
            emptyText.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyText.Font = Enum.Font.Gotham
            emptyText.TextSize = 13
            emptyText.Parent = emptyFrame
        else
            for i, scriptData in ipairs(scripts) do
                -- Check if script URL is valid
                local isValid = isScriptValid(scriptData.url)
                
                local scriptFrame = Instance.new("Frame")
                scriptFrame.Size = UDim2.new(1, 0, 0, 70)
                scriptFrame.BackgroundColor3 = isValid and Color3.fromRGB(30, 35, 50) or Color3.fromRGB(50, 35, 35)
                scriptFrame.BackgroundTransparency = 0.3
                scriptFrame.BorderSizePixel = 0
                scriptFrame.LayoutOrder = i
                scriptFrame.Parent = scriptsContainer
                
                local scriptCorner = Instance.new("UICorner")
                scriptCorner.CornerRadius = UDim.new(0, 8)
                scriptCorner.Parent = scriptFrame
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -90, 0, 22)
                nameLabel.Position = UDim2.new(0, 8, 0, 5)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = scriptData.name .. (isValid and "" or " (DELETED)")
                nameLabel.TextColor3 = isValid and Color3.new(1, 1, 1) or Color3.fromRGB(255, 100, 100)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 13
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Parent = scriptFrame
                
                local gameIdLabel = Instance.new("TextLabel")
                gameIdLabel.Size = UDim2.new(1, -90, 0, 18)
                gameIdLabel.Position = UDim2.new(0, 8, 0, 30)
                gameIdLabel.BackgroundTransparency = 1
                gameIdLabel.Text = "🎮 Game: " .. gameData.name
                gameIdLabel.TextColor3 = isValid and Color3.fromRGB(79, 124, 255) or Color3.fromRGB(150, 150, 150)
                gameIdLabel.Font = Enum.Font.Gotham
                gameIdLabel.TextSize = 10
                gameIdLabel.TextXAlignment = Enum.TextXAlignment.Left
                gameIdLabel.Parent = scriptFrame
                
                local typeLabel = Instance.new("TextLabel")
                typeLabel.Size = UDim2.new(1, -90, 0, 18)
                typeLabel.Position = UDim2.new(0, 8, 0, 48)
                typeLabel.BackgroundTransparency = 1
                typeLabel.Text = isValid and (scriptData.type or "Script") or "❌ Deleted"
                typeLabel.TextColor3 = isValid and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(255, 60, 60)
                typeLabel.Font = Enum.Font.Gotham
                typeLabel.TextSize = 9
                typeLabel.TextXAlignment = Enum.TextXAlignment.Left
                typeLabel.Parent = scriptFrame
                
                local execBtn = Instance.new("TextButton")
                execBtn.Size = UDim2.new(0, 70, 0, 28)
                execBtn.Position = UDim2.new(1, -80, 0.5, -14)
                execBtn.BackgroundColor3 = isValid and Color3.fromRGB(40, 200, 80) or Color3.fromRGB(100, 100, 100)
                execBtn.Text = isValid and "⚡ Run" or "❌"
                execBtn.TextColor3 = Color3.new(1, 1, 1)
                execBtn.Font = Enum.Font.GothamBold
                execBtn.TextSize = 11
                execBtn.BorderSizePixel = 0
                execBtn.Parent = scriptFrame
                execBtn.Active = isValid
                execBtn.AutoButtonColor = isValid
                
                local execCorner = Instance.new("UICorner")
                execCorner.CornerRadius = UDim.new(0, 6)
                execCorner.Parent = execBtn
                
                -- Only allow execution if script is valid
                if isValid then
                    local thisScript = scriptData
                    local thisGame = gameData
                    
                    execBtn.MouseButton1Click:Connect(function()
                        executeScript(thisScript, thisGame)
                    end)
                end
            end
        end
        
        -- Update canvas size
        task.wait()
        local totalHeight = 0
        for _, child in ipairs(scriptsContainer:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + scriptsLayout.Padding.Offset
            end
        end
        scriptsContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    backBtn.MouseButton1Click:Connect(showGames)
    
    refreshBtn.MouseButton1Click:Connect(function()
        showNotification("🔄 Refreshing data...", Color3.fromRGB(79, 124, 255))
        loadSystemData()
        showGames()
        if currentGameData then
            -- Find updated game data
            if systemData and systemData.games then
                for _, gameData in ipairs(systemData.games) do
                    if gameData.id == currentGameData.id then
                        showScripts(gameData)
                        break
                    end
                end
            end
        end
    end)
    
    -- Load games function
    local function loadGames()
        -- Clear games container
        for _, child in ipairs(gamesContainer:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        if not systemData or not systemData.games or #systemData.games == 0 then
            local emptyFrame = Instance.new("Frame")
            emptyFrame.Size = UDim2.new(1, 0, 0, 60)
            emptyFrame.BackgroundTransparency = 1
            emptyFrame.Parent = gamesContainer
            
            local emptyText = Instance.new("TextLabel")
            emptyText.Size = UDim2.new(1, 0, 1, 0)
            emptyText.BackgroundTransparency = 1
            emptyText.Text = "📭 No games available"
            emptyText.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyText.Font = Enum.Font.Gotham
            emptyText.TextSize = 13
            emptyText.Parent = emptyFrame
            return
        end
        
        for i, gameData in ipairs(systemData.games) do
            local gameFrame = Instance.new("Frame")
            gameFrame.Size = UDim2.new(1, 0, 0, 70)
            gameFrame.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
            gameFrame.BackgroundTransparency = 0.3
            gameFrame.BorderSizePixel = 0
            gameFrame.LayoutOrder = i
            gameFrame.Parent = gamesContainer
            
            local gameCorner = Instance.new("UICorner")
            gameCorner.CornerRadius = UDim.new(0, 8)
            gameCorner.Parent = gameFrame
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -90, 0, 22)
            nameLabel.Position = UDim2.new(0, 8, 0, 5)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = gameData.name
            nameLabel.TextColor3 = Color3.new(1, 1, 1)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextSize = 14
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = gameFrame
            
            local idLabel = Instance.new("TextLabel")
            idLabel.Size = UDim2.new(1, -90, 0, 18)
            idLabel.Position = UDim2.new(0, 8, 0, 27)
            idLabel.BackgroundTransparency = 1
            idLabel.Text = "🆔 ID: " .. gameData.id
            idLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            idLabel.Font = Enum.Font.Gotham
            idLabel.TextSize = 10
            idLabel.TextXAlignment = Enum.TextXAlignment.Left
            idLabel.Parent = gameFrame
            
            -- Count valid scripts
            local validScripts = 0
            local totalScripts = #(gameData.scripts or {})
            if gameData.scripts then
                for _, script in ipairs(gameData.scripts) do
                    if isScriptValid(script.url) then
                        validScripts = validScripts + 1
                    end
                end
            end
            
            local scriptLabel = Instance.new("TextLabel")
            scriptLabel.Size = UDim2.new(1, -90, 0, 18)
            scriptLabel.Position = UDim2.new(0, 8, 0, 45)
            scriptLabel.BackgroundTransparency = 1
            scriptLabel.Text = string.format("📜 %d/%d scripts valid", validScripts, totalScripts)
            scriptLabel.TextColor3 = validScripts > 0 and Color3.fromRGB(79, 124, 255) or Color3.fromRGB(255, 60, 60)
            scriptLabel.Font = Enum.Font.Gotham
            scriptLabel.TextSize = 10
            scriptLabel.TextXAlignment = Enum.TextXAlignment.Left
            scriptLabel.Parent = gameFrame
            
            local viewBtn = Instance.new("TextButton")
            viewBtn.Size = UDim2.new(0, 70, 0, 28)
            viewBtn.Position = UDim2.new(1, -80, 0.5, -14)
            viewBtn.BackgroundColor3 = validScripts > 0 and Color3.fromRGB(79, 124, 255) or Color3.fromRGB(100, 100, 100)
            viewBtn.Text = validScripts > 0 and "📜 View" or "🚫"
            viewBtn.TextColor3 = Color3.new(1, 1, 1)
            viewBtn.Font = Enum.Font.GothamBold
            viewBtn.TextSize = 11
            viewBtn.BorderSizePixel = 0
            viewBtn.Parent = gameFrame
            viewBtn.Active = validScripts > 0
            viewBtn.AutoButtonColor = validScripts > 0
            
            local viewCorner = Instance.new("UICorner")
            viewCorner.CornerRadius = UDim.new(0, 6)
            viewCorner.Parent = viewBtn
            
            -- Only allow viewing if there are valid scripts
            if validScripts > 0 then
                local thisGame = gameData
                viewBtn.MouseButton1Click:Connect(function()
                    showScripts(thisGame)
                end)
            end
        end
        
        -- Update canvas size
        task.wait()
        local totalHeight = 0
        for _, child in ipairs(gamesContainer:GetChildren()) do
            if child:IsA("Frame") then
                totalHeight = totalHeight + child.Size.Y.Offset + gamesLayout.Padding.Offset
            end
        end
        gamesContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    loadGames()
    
    -- Make draggable
    local dragging = false
    local dragStart
    local startPos
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Create group requirement GUI
local function createGroupGUI()
    closeAllGuis()
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_GroupRequired"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    activeGui = gui
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 320, 0, 250)
    main.Position = UDim2.new(0.5, -160, 0.5, -125)
    main.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
    main.BackgroundTransparency = 0.1
    main.BorderSizePixel = 0
    main.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = main
    
    -- Title bar with X button
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚠️ GROUP REQUIRED"
    title.TextColor3 = Color3.fromRGB(255, 140, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -27, 0.5, -11)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        activeGui = nil
    end)
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 0, 40)
    icon.Position = UDim2.new(0, 0, 0, 40)
    icon.BackgroundTransparency = 1
    icon.Text = "⚠️"
    icon.TextColor3 = Color3.fromRGB(255, 140, 0)
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 30
    icon.Parent = main
    
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -40, 0, 50)
    desc.Position = UDim2.new(0, 20, 0, 85)
    desc.BackgroundTransparency = 1
    desc.Text = "You must join the group before accessing RSQ Elite"
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 12
    desc.TextWrapped = true
    desc.Parent = main
    
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 130, 0, 35)
    copyBtn.Position = UDim2.new(0.5, -140, 1, -55)
    copyBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    copyBtn.Text = "📋 Copy Link"
    copyBtn.TextColor3 = Color3.new(1, 1, 1)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 12
    copyBtn.BorderSizePixel = 0
    copyBtn.Parent = main
    
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 8)
    copyCorner.Parent = copyBtn
    
    local checkBtn = Instance.new("TextButton")
    checkBtn.Size = UDim2.new(0, 130, 0, 35)
    checkBtn.Position = UDim2.new(0.5, 10, 1, -55)
    checkBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    checkBtn.Text = "🔄 Check"
    checkBtn.TextColor3 = Color3.new(1, 1, 1)
    checkBtn.Font = Enum.Font.GothamBold
    checkBtn.TextSize = 12
    checkBtn.BorderSizePixel = 0
    checkBtn.Parent = main
    
    local checkCorner = Instance.new("UICorner")
    checkCorner.CornerRadius = UDim.new(0, 8)
    checkCorner.Parent = checkBtn
    
    copyBtn.MouseButton1Click:Connect(function()
        setclipboard(GROUP_URL)
        showNotification("✅ Group link copied!", Color3.fromRGB(79, 124, 255))
    end)
    
    checkBtn.MouseButton1Click:Connect(function()
        if checkGroup() then
            gui:Destroy()
            activeGui = nil
            showNotification("✅ You're in the group!", Color3.fromRGB(40, 200, 80))
            if not keyValid then
                createKeyGUI()
            else
                createMainGUI()
                guiOpen = true
            end
        else
            showNotification("❌ Still not in group", Color3.fromRGB(255, 60, 60))
        end
    end)
    
    -- Make draggable
    local dragging = false
    local dragStart
    local startPos
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    return gui
end

-- Create key input GUI
local function createKeyGUI()
    closeAllGuis()
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_KeyInput"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    activeGui = gui
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 300, 0, 220)
    main.Position = UDim2.new(0.5, -150, 0.5, -110)
    main.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    main.BackgroundTransparency = 0.1
    main.BorderSizePixel = 0
    main.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = main
    
    -- Title bar with X button
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🔐 KEY SYSTEM"
    title.TextColor3 = Color3.fromRGB(79, 124, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -27, 0.5, -11)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        activeGui = nil
    end)
    
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -40, 0, 25)
    desc.Position = UDim2.new(0, 20, 0, 40)
    desc.BackgroundTransparency = 1
    desc.Text = "Enter your access key:"
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 12
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = main
    
    local keyBox = Instance.new("TextBox")
    keyBox.Size = UDim2.new(1, -40, 0, 30)
    keyBox.Position = UDim2.new(0, 20, 0, 70)
    keyBox.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    keyBox.PlaceholderText = "Enter key..."
    keyBox.Text = ""
    keyBox.TextColor3 = Color3.new(1, 1, 1)
    keyBox.Font = Enum.Font.Gotham
    keyBox.TextSize = 12
    keyBox.BorderSizePixel = 0
    keyBox.Parent = main
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 8)
    boxCorner.Parent = keyBox
    
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(1, -40, 0, 35)
    submitBtn.Position = UDim2.new(0, 20, 0, 110)
    submitBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    submitBtn.Text = "🔓 Validate Key"
    submitBtn.TextColor3 = Color3.new(1, 1, 1)
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 13
    submitBtn.BorderSizePixel = 0
    submitBtn.Parent = main
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = submitBtn
    
    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Size = UDim2.new(1, -40, 0, 25)
    getKeyBtn.Position = UDim2.new(0, 20, 0, 155)
    getKeyBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    getKeyBtn.Text = "🌐 Get Key"
    getKeyBtn.TextColor3 = Color3.new(1, 1, 1)
    getKeyBtn.Font = Enum.Font.GothamBold
    getKeyBtn.TextSize = 11
    getKeyBtn.BorderSizePixel = 0
    getKeyBtn.Parent = main
    
    local getCorner = Instance.new("UICorner")
    getCorner.CornerRadius = UDim.new(0, 6)
    getCorner.Parent = getKeyBtn
    
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -40, 0, 20)
    status.Position = UDim2.new(0, 20, 0, 185)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(150, 150, 150)
    status.Font = Enum.Font.Gotham
    status.TextSize = 10
    status.Parent = main
    
    submitBtn.MouseButton1Click:Connect(function()
        local key = keyBox.Text:gsub("%s+", "")
        if key == "" then
            status.Text = "❌ Please enter a key"
            status.TextColor3 = Color3.fromRGB(255, 60, 60)
            return
        end
        
        status.Text = "⚡ Validating..."
        status.TextColor3 = Color3.fromRGB(79, 124, 255)
        
        task.spawn(function()
            local valid, keyData = validateKey(key)
            
            if valid then
                userKey = key
                keyValid = true
                saveKey(key)
                gui:Destroy()
                activeGui = nil
                showNotification("✅ Key validated successfully!", Color3.fromRGB(40, 200, 80))
                
                -- Load required scripts
                for _, url in ipairs(REQUIRED_SCRIPTS) do
                    task.spawn(function()
                        pcall(function()
                            local script = game:HttpGet(url)
                            loadstring(script)()
                        end)
                    end)
                end
                
                -- Create main GUI
                createMainGUI()
                guiOpen = true
            else
                status.Text = "❌ " .. tostring(keyData)
                status.TextColor3 = Color3.fromRGB(255, 60, 60)
            end
        end)
    end)
    
    getKeyBtn.MouseButton1Click:Connect(function()
        setclipboard("https://your-key-shop.com")
        status.Text = "📋 Link copied!"
        status.TextColor3 = Color3.fromRGB(79, 124, 255)
    end)
    
    -- Make draggable
    local dragging = false
    local dragStart
    local startPos
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    return gui
end

-- Create floating toggle button
local function createToggleButton()
    if toggleButton and toggleButton.Parent then
        toggleButton:Destroy()
    end
    
    toggleButton = Instance.new("ScreenGui")
    toggleButton.Name = "RSQ_Toggle"
    toggleButton.IgnoreGuiInset = true
    toggleButton.ResetOnSpawn = false
    toggleButton.Parent = player:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 50, 0, 50)
    button.Position = UDim2.new(1, -60, 0, 20)
    
    -- Set color and text based on state
    if isBanned then
        button.BackgroundColor3 = Color3.fromRGB(100, 0, 0) -- Dark red when banned
        button.Text = "⛔"
        button.Active = false
        button.AutoButtonColor = false
    elseif not isInGroup then
        button.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Gray when disabled
        button.Text = "🔒"
        button.Active = false
        button.AutoButtonColor = false
    elseif keyValid then
        button.BackgroundColor3 = Color3.fromRGB(79, 124, 255) -- Blue when unlocked
        button.Text = "🔓"
        button.Active = true
    else
        button.BackgroundColor3 = Color3.fromRGB(255, 140, 0) -- Orange when locked
        button.Text = "🔒"
        button.Active = true
    end
    
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 20
    button.BorderSizePixel = 0
    button.Parent = toggleButton
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = button
    
    -- Make draggable
    local dragging = false
    local dragStart
    local startPos
    
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
        end
    end)
    
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
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
    
    button.MouseButton1Click:Connect(function()
        if isBanned then
            showNotification("⛔ You are banned: " .. banReason, Color3.fromRGB(255, 60, 60))
            return
        end
        
        if not isInGroup then
            showNotification("❌ You must join the group first", Color3.fromRGB(255, 60, 60))
            if not activeGui then
                createGroupGUI()
            end
            return
        end
        
        if not dragging then
            if activeGui and activeGui.Parent then
                activeGui:Destroy()
                activeGui = nil
                if mainGui then
                    mainGui = nil
                    guiOpen = false
                end
            elseif keyValid then
                createMainGUI()
                guiOpen = true
            else
                createKeyGUI()
            end
        end
    end)
    
    return toggleButton
end

-- Main initialization
local function initialize()
    showNotification("🚀 RSQ Elite Loading...", Color3.fromRGB(79, 124, 255))
    
    -- Load system data
    if not loadSystemData() then
        showNotification("❌ Failed to connect to server", Color3.fromRGB(255, 60, 60))
        return
    end
    
    -- Check if banned
    checkBan()
    if isBanned then
        showNotification("⛔ You are banned: " .. banReason, Color3.fromRGB(255, 60, 60))
        createToggleButton()
        return
    end
    
    -- Check group
    checkGroup()
    
    -- Check for saved key (only if in group)
    if isInGroup then
        local savedKey = loadSavedKey()
        if savedKey then
            local valid, keyData = validateKey(savedKey)
            if valid then
                userKey = savedKey
                keyValid = true
                showNotification("✅ Saved key validated!", Color3.fromRGB(40, 200, 80))
                
                -- Load required scripts
                for _, url in ipairs(REQUIRED_SCRIPTS) do
                    task.spawn(function()
                        pcall(function()
                            local script = game:HttpGet(url)
                            loadstring(script)()
                        end)
                    end)
                end
            else
                deleteSavedKey()
            end
        end
    end
    
    -- Create toggle button
    createToggleButton()
    
    -- Show appropriate GUI
    if isBanned then
        -- Don't show any GUI, just banned notification
    elseif not isInGroup then
        createGroupGUI()
    elseif not keyValid then
        createKeyGUI()
    end
end

-- Auto-refresh every 1 second - checks everything
task.spawn(function()
    while true do
        task.wait(1) -- Exactly 1 second
        
        -- Load fresh system data
        local oldSystemData = systemData
        loadSystemData()
        
        -- Check if data changed
        local dataChanged = (oldSystemData ~= systemData)
        
        -- Check ban status
        local wasBanned = isBanned
        checkBan()
        if wasBanned ~= isBanned then
            if isBanned then
                showNotification("⛔ You have been banned: " .. banReason, Color3.fromRGB(255, 60, 60))
                closeAllGuis()
                keyValid = false
                userKey = nil
            end
            -- Update toggle button
            if toggleButton and toggleButton.Parent then
                toggleButton:Destroy()
                createToggleButton()
            end
        end
        
        -- Skip other checks if banned
        if isBanned then
            -- Keep showing banned state
            if activeGui and activeGui.Name ~= "RSQ_Banned" then
                closeAllGuis()
            end
            goto continue
        end
        
        -- Check group status
        local oldGroupStatus = isInGroup
        checkGroup()
        
        -- Check key validity
        if userKey and keyValid then
            local valid, _ = validateKey(userKey)
            if not valid then
                keyValid = false
                userKey = nil
                deleteSavedKey()
                showNotification("❌ Key no longer valid", Color3.fromRGB(255, 60, 60))
                closeAllGuis()
            end
        end
        
        -- Update toggle button if any state changed
        if oldGroupStatus ~= isInGroup or dataChanged or (userKey and not keyValid) then
            if toggleButton and toggleButton.Parent then
                toggleButton:Destroy()
                createToggleButton()
            end
        end
        
        -- Handle state transitions
        if not isInGroup and not (activeGui and activeGui.Name == "RSQ_GroupRequired") then
            closeAllGuis()
            createGroupGUI()
        elseif isInGroup and not keyValid and not (activeGui and activeGui.Name == "RSQ_KeyInput") then
            closeAllGuis()
            createKeyGUI()
        elseif isInGroup and keyValid and guiOpen and mainGui and mainGui.Parent then
            -- Refresh main GUI if data changed and it's open
            if dataChanged then
                local wasInScripts = currentGameData ~= nil
                local oldGameData = currentGameData
                createMainGUI()
                if wasInScripts and oldGameData then
                    -- Try to find updated game data
                    if systemData and systemData.games then
                        for _, gameData in ipairs(systemData.games) do
                            if gameData.id == oldGameData.id then
                                -- Need to wait for GUI to be created
                                task.wait(0.1)
                                if mainGui and mainGui.Parent then
                                    -- Find scripts container and show scripts
                                    for _, child in ipairs(mainGui:GetDescendants()) do
                                        if child.Name == "scriptsContainer" and child:IsA("ScrollingFrame") then
                                            child.Visible = true
                                            -- Find back button
                                            for _, btn in ipairs(mainGui:GetDescendants()) do
                                                if btn.Name == "backBtn" and btn:IsA("TextButton") then
                                                    btn.Visible = true
                                                    break
                                                end
                                            end
                                            -- Load scripts
                                            task.spawn(function()
                                                loadScripts(gameData)
                                            end)
                                            break
                                        end
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
        
        ::continue::
    end
end)

-- Start
initialize()
