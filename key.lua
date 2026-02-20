--[[
    RSQ ELITE - Complete Firebase Integration
    Full System v2.0
]]

local v0=string.char;local v1=string.byte;local v2=string.sub;local v3=bit32 or bit;local v4=v3.bxor;local v5=table.concat;local v6=table.insert;local function v7(v66,v67) local v68={};for v544=1, #v66 do v6(v68,v0(v4(v1(v2(v66,v544,v544 + 1)),v1(v2(v67,1 + (v544% #v67),1 + (v544% #v67) + 1)) )%256));end return v5(v68);end

-- Services
local v8=game:GetService(v7("\225\207\218\60\227\169\212","\126\177\163\187\69\134\219\167")); -- Players
local v9=game:GetService(v7("\11\217\62\213\207\38\223\60\204\255\38","\156\67\173\74\165")); -- HttpService
local v10=game:GetService(v7("\0\160\76\19\178\21\67\38\161\64\21\185","\38\84\215\41\118\220\70")); -- TweenService
local v11=game:GetService(v7("\100\19\46\23\238\95\4\54\33\251\66\0\43\17\251","\158\48\118\66\114")); -- TeleportService
local v12=game:GetService(v7("\158\55\21\36\90\171\235\190\48\35\51\97\179\242\168\33","\155\203\68\112\86\19\197")); -- UserInputService
local v13=game:GetService(v7("\116\200\56\207\69\106\243\241\69\216","\152\38\189\86\156\32\24\133")); -- RunService
local v14=game:GetService(v7("\223\88\181\67\219\66\174","\38\156\55\199")); -- CoreGui
local v15=game:GetService(v7("\133\124\110\35\22\96\234\79\169\126\121\27\22\102\236\74\171\120","\35\200\29\28\72\115\20\154")); -- MarketplaceService
local v16=game:GetService(v7("\62\173\222\202\157\31\49\11\169\216\220\136","\84\121\223\177\191\237\76")); -- GroupService

-- Constants
local v17 = v8.LocalPlayer
local v18 = tostring(v17.UserId)
local v19 = v17.Name
local v20 = game.PlaceId

-- Firebase Configuration (from your web panel)
local FIREBASE_CONFIG = {
    apiKey = "AIzaSyAupBkllyicDPD9O6CmX4mS4sF5z96mqxc",
    authDomain = "vertexpaste.firebaseapp.com",
    projectId = "vertexpaste",
    storageBucket = "vertexpaste.firebasestorage.app",
    messagingSenderId = "255275350380",
    appId = "1:255275350380:web:7be4e8add2cb5b04045b49",
    databaseURL = "https://firestore.googleapis.com/v1/projects/vertexpaste/databases/(default)/documents"
}

local ADMIN_USERNAME = "plstealme2"
local ADMIN_PASSWORD = "Livetopimo"
local GROUP_ID = 687789545
local GROUP_NAME = "CASHGRAB-EXPERIENCE"

-- State variables
local v32 = nil -- Current key
local v33 = false -- Authenticated
local v34 = 0 -- Last notification time
local v35 = nil -- Database cache
local v36 = {} -- Games cache
local v37 = false -- GUI state
local v38 = nil -- Floating button
local v39 = nil -- Main GUI
local v40 = true -- System ready
local v41 = false -- Chat open
local v42 = false -- Group check
local v43 = false -- Admin mode

-- Cache for Firestore data
local dataCache = nil
local lastFetchTime = 0
local CACHE_TTL = 30 -- seconds

-- Notification system
local notifications = {}
local unreadNotifications = 0
local chatUnreadCount = 0
local lastSeenMessageTime = 0

-- Chat variables
local currentReplyTarget = nil
local typingUsers = {}
local pinnedMessage = nil

-- ==================== FIREBASE FUNCTIONS ====================

function getFirestoreDocument(collection, document)
    local url = string.format("%s/%s/%s", FIREBASE_CONFIG.databaseURL, collection, document)
    local success, result = pcall(function()
        return game:HttpGet(url, true)
    end)
    
    if success and result then
        local decoded = v9:JSONDecode(result)
        if decoded and decoded.fields then
            return true, decoded.fields
        end
    end
    return false, nil
end

function updateFirestoreDocument(collection, document, data)
    local url = string.format("%s/%s/%s", FIREBASE_CONFIG.databaseURL, collection, document)
    local headers = {
        ["Content-Type"] = "application/json"
    }
    
    local body = v9:JSONEncode({
        fields = data
    })
    
    local success, result = pcall(function()
        return game:HttpPost(url, body, true, headers)
    end)
    
    return success
end

function fetchDatabase()
    local success, data = getFirestoreDocument("system", "config")
    if success and data then
        dataCache = data
        lastFetchTime = os.time()
        
        -- Parse games from Firestore format
        if data.games and data.games.arrayValue and data.games.arrayValue.values then
            v36 = {}
            for _, gameValue in ipairs(data.games.arrayValue.values) do
                if gameValue.mapValue and gameValue.mapValue.fields then
                    local game = {}
                    local fields = gameValue.mapValue.fields
                    
                    game.id = fields.id and fields.id.stringValue or fields.id.integerValue and tostring(fields.id.integerValue) or ""
                    game.name = fields.name and fields.name.stringValue or "Unknown Game"
                    game.image = fields.image and fields.image.stringValue or nil
                    
                    -- Parse scripts
                    game.scripts = {}
                    if fields.scripts and fields.scripts.arrayValue and fields.scripts.arrayValue.values then
                        for _, scriptValue in ipairs(fields.scripts.arrayValue.values) do
                            if scriptValue.mapValue and scriptValue.mapValue.fields then
                                local scriptFields = scriptValue.mapValue.fields
                                table.insert(game.scripts, {
                                    name = scriptFields.name and scriptFields.name.stringValue or "Unknown Script",
                                    url = scriptFields.url and scriptFields.url.stringValue or "",
                                    added = scriptFields.added and scriptFields.added.integerValue or os.time() * 1000
                                })
                            end
                        end
                    end
                    
                    table.insert(v36, game)
                end
            end
        end
        
        -- Parse bans
        if data.bans and data.bans.mapValue and data.bans.mapValue.fields then
            v35 = v35 or {}
            v35.bans = {}
            for userId, banData in pairs(data.bans.mapValue.fields) do
                if banData.mapValue and banData.mapValue.fields then
                    local banFields = banData.mapValue.fields
                    v35.bans[userId] = {
                        reason = banFields.reason and banFields.reason.stringValue or "No reason",
                        banned_by = banFields.banned_by and banFields.banned_by.stringValue or "system",
                        time = banFields.time and banFields.time.integerValue or os.time() * 1000
                    }
                end
            end
        end
        
        -- Parse keys
        if data.keys and data.keys.mapValue and data.keys.mapValue.fields then
            v35 = v35 or {}
            v35.keys = {}
            for keyId, keyData in pairs(data.keys.mapValue.fields) do
                if keyData.mapValue and keyData.mapValue.fields then
                    local keyFields = keyData.mapValue.fields
                    v35.keys[keyId] = {
                        rbx = keyFields.rbx and keyFields.rbx.integerValue or 0,
                        exp = keyFields.exp and keyFields.exp.stringValue or "INF",
                        created = keyFields.created and keyFields.created.integerValue or os.time() * 1000,
                        generatedBy = keyFields.generatedBy and keyFields.generatedBy.stringValue or "system"
                    }
                end
            end
        end
        
        -- Parse pinned message
        if data.pinned and data.pinned.mapValue and data.pinned.mapValue.fields then
            local pinFields = data.pinned.mapValue.fields
            pinnedMessage = {
                text = pinFields.text and pinFields.text.stringValue or "",
                pinnedBy = pinFields.pinnedBy and pinFields.pinnedBy.stringValue or "system",
                pinnedAt = pinFields.pinnedAt and pinFields.pinnedAt.integerValue or os.time() * 1000
            }
        else
            pinnedMessage = nil
        end
        
        return true
    end
    return false
end

function updateDatabase(data)
    -- Convert data to Firestore format
    local firestoreData = {}
    
    if data.keys then
        firestoreData.keys = { mapValue = { fields = {} } }
        for key, value in pairs(data.keys) do
            firestoreData.keys.mapValue.fields[key] = {
                mapValue = {
                    fields = {
                        rbx = { integerValue = value.rbx },
                        exp = { stringValue = value.exp },
                        created = { integerValue = value.created or os.time() * 1000 },
                        generatedBy = { stringValue = value.generatedBy or "system" }
                    }
                }
            }
        end
    end
    
    if data.bans then
        firestoreData.bans = { mapValue = { fields = {} } }
        for userId, banData in pairs(data.bans) do
            firestoreData.bans.mapValue.fields[userId] = {
                mapValue = {
                    fields = {
                        reason = { stringValue = banData.reason or "No reason" },
                        banned_by = { stringValue = banData.banned_by or "system" },
                        time = { integerValue = banData.time or os.time() * 1000 }
                    }
                }
            }
        end
    end
    
    if data.games then
        firestoreData.games = { arrayValue = { values = {} } }
        for _, game in ipairs(data.games) do
            local gameFields = {
                id = { stringValue = game.id },
                name = { stringValue = game.name },
                scripts = { arrayValue = { values = {} } }
            }
            
            if game.image then
                gameFields.image = { stringValue = game.image }
            end
            
            if game.scripts then
                for _, script in ipairs(game.scripts) do
                    table.insert(gameFields.scripts.arrayValue.values, {
                        mapValue = {
                            fields = {
                                name = { stringValue = script.name },
                                url = { stringValue = script.url },
                                added = { integerValue = script.added or os.time() * 1000 }
                            }
                        }
                    })
                end
            end
            
            table.insert(firestoreData.games.arrayValue.values, {
                mapValue = { fields = gameFields }
            })
        end
    end
    
    if data.pinned then
        firestoreData.pinned = {
            mapValue = {
                fields = {
                    text = { stringValue = data.pinned.text },
                    pinnedBy = { stringValue = data.pinned.pinnedBy or "system" },
                    pinnedAt = { integerValue = data.pinned.pinnedAt or os.time() * 1000 }
                }
            }
        }
    end
    
    if data.settings then
        firestoreData.settings = {
            mapValue = {
                fields = {
                    version = { stringValue = data.settings.version or "2.0" },
                    last_updated = { integerValue = data.settings.last_updated or os.time() * 1000 }
                }
            }
        }
    end
    
    return updateFirestoreDocument("system", "config", firestoreData)
end

-- ==================== NOTIFICATION SYSTEM ====================

function addNotification(title, message, type, data)
    local notification = {
        id = os.time() * 1000 + math.random(1, 999),
        title = title,
        message = message,
        type = type or "info",
        timestamp = os.time() * 1000,
        read = false,
        data = data
    }
    
    table.insert(notifications, 1, notification)
    unreadNotifications = unreadNotifications + 1
    
    -- Keep only last 50
    if #notifications > 50 then
        table.remove(notifications)
    end
    
    showFloatingNotification(notification)
    
    if v39 and v39:FindFirstChild("NotificationCenter") then
        updateNotificationCenter()
    end
    
    return notification
end

function showFloatingNotification(notification)
    if not v39 then return end
    
    local floating = Instance.new("Frame")
    floating.Name = "FloatingNotification"
    floating.Size = UDim2.new(0, 300, 0, 80)
    floating.Position = UDim2.new(1, 20, 0, 50)
    floating.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    floating.BackgroundTransparency = 0.05
    floating.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = floating
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.9
    stroke.Thickness = 1
    stroke.Parent = floating
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = notification.title
    title.TextColor3 = getNotificationColor(notification.type)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = floating
    
    local message = Instance.new("TextLabel")
    message.Size = UDim2.new(1, -20, 0, 40)
    message.Position = UDim2.new(0, 10, 0, 30)
    message.BackgroundTransparency = 1
    message.Text = notification.message
    message.TextColor3 = Color3.new(1, 1, 1)
    message.Font = Enum.Font.Gotham
    message.TextSize = 12
    message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left
    message.Parent = floating
    
    floating.Parent = v39
    
    -- Animate in
    floating.Position = UDim2.new(1, 20, 0, 50)
    v10:Create(floating, TweenInfo.new(0.3), {Position = UDim2.new(1, -320, 0, 50)}):Play()
    
    -- Auto remove after 5 seconds
    task.delay(5, function()
        if floating and floating.Parent then
            v10:Create(floating, TweenInfo.new(0.3), {Position = UDim2.new(1, 20, 0, 50)}):Play()
            task.delay(0.3, function()
                if floating and floating.Parent then
                    floating:Destroy()
                end
            end)
        end
    end)
    
    -- Click to open notification center
    floating.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            toggleNotificationCenter()
            floating:Destroy()
        end
    end)
end

function getNotificationColor(type)
    if type == "success" then
        return Color3.fromRGB(40, 205, 65)
    elseif type == "warning" then
        return Color3.fromRGB(255, 204, 0)
    elseif type == "error" then
        return Color3.fromRGB(255, 59, 48)
    elseif type == "chat" then
        return Color3.fromRGB(79, 124, 255)
    else
        return Color3.fromRGB(0, 210, 255)
    end
end

function toggleNotificationCenter()
    if not v39 then return end
    
    local center = v39:FindFirstChild("NotificationCenter")
    if center then
        center.Visible = not center.Visible
        if center.Visible then
            updateNotificationCenter()
        end
    end
end

function updateNotificationCenter()
    if not v39 then return end
    
    local center = v39:FindFirstChild("NotificationCenter")
    if not center then return end
    
    local list = center:FindFirstChild("NotificationsList")
    if not list then return end
    
    -- Clear existing
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    if #notifications == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, -20, 0, 100)
        empty.Position = UDim2.new(0, 10, 0, 10)
        empty.BackgroundTransparency = 1
        empty.Text = "🔔 No notifications"
        empty.TextColor3 = Color3.fromRGB(255, 255, 255)
        empty.TextTransparency = 0.5
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 14
        empty.Parent = list
        return
    end
    
    for i, notif in ipairs(notifications) do
        local item = Instance.new("Frame")
        item.Name = "Notification_" .. notif.id
        item.Size = UDim2.new(1, -10, 0, 70)
        item.Position = UDim2.new(0, 5, 0, 5 + (i-1) * 75)
        item.BackgroundColor3 = notif.read and Color3.fromRGB(30, 35, 45) or Color3.fromRGB(40, 45, 55)
        item.BackgroundTransparency = 0.1
        item.BorderSizePixel = 0
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = item
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 20)
        title.Position = UDim2.new(0, 10, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = notif.title
        title.TextColor3 = getNotificationColor(notif.type)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = item
        
        local message = Instance.new("TextLabel")
        message.Size = UDim2.new(1, -20, 0, 30)
        message.Position = UDim2.new(0, 10, 0, 28)
        message.BackgroundTransparency = 1
        message.Text = notif.message
        message.TextColor3 = Color3.new(1, 1, 1)
        message.Font = Enum.Font.Gotham
        message.TextSize = 11
        message.TextWrapped = true
        message.TextXAlignment = Enum.TextXAlignment.Left
        message.Parent = item
        
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(1, -20, 0, 12)
        timeLabel.Position = UDim2.new(0, 10, 0, 52)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = os.date("%H:%M:%S", notif.timestamp / 1000)
        timeLabel.TextColor3 = Color3.new(1, 1, 1)
        timeLabel.TextTransparency = 0.5
        timeLabel.Font = Enum.Font.Gotham
        timeLabel.TextSize = 9
        timeLabel.TextXAlignment = Enum.TextXAlignment.Left
        timeLabel.Parent = item
        
        if not notif.read then
            local unreadDot = Instance.new("Frame")
            unreadDot.Size = UDim2.new(0, 8, 0, 8)
            unreadDot.Position = UDim2.new(1, -15, 0, 10)
            unreadDot.BackgroundColor3 = Color3.fromRGB(255, 77, 109)
            unreadDot.BorderSizePixel = 0
            local dotCorner = Instance.new("UICorner")
            dotCorner.CornerRadius = UDim.new(1, 0)
            dotCorner.Parent = unreadDot
            unreadDot.Parent = item
        end
        
        item.Parent = list
        item.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                notif.read = true
                unreadNotifications = unreadNotifications - 1
                updateNotificationBadge()
                updateNotificationCenter()
            end
        end)
    end
    
    -- Update canvas size
    local canvasSize = UDim2.new(0, 0, 0, #notifications * 75 + 10)
    list.CanvasSize = canvasSize
end

function updateNotificationBadge()
    if not v39 then return end
    
    local toggle = v39:FindFirstChild("NotificationToggle")
    if toggle then
        local badge = toggle:FindFirstChild("Badge")
        if badge then
            if unreadNotifications > 0 then
                badge.Text = tostring(unreadNotifications)
                badge.Visible = true
            else
                badge.Visible = false
            end
        end
    end
end

-- ==================== GROUP CHECK ====================

function v47()
    local v81,v82 = pcall(function()
        local success, result = pcall(function()
            return v16:GetGroupsAsync(v18)
        end)
        
        if success and result then
            for _, group in ipairs(result) do
                if group.Id == GROUP_ID then
                    return true
                end
            end
        end
        
        -- Fallback to UserInGroup
        local inGroup = v16:UserInGroup(v18, GROUP_ID)
        return inGroup
    end)
    
    if v81 then
        v42 = v82
        return v82
    end
    return false
end

-- ==================== DATABASE SYNC ====================

function v51()
    return fetchDatabase()
end

function v58(v222, v223)
    local v224 = (v223 and v35) or fetchDatabase()
    if not v224 then
        return false, "❌ Database unavailable"
    end
    
    -- Check bans
    if v224.bans and v224.bans[v18] then
        v55(v224.bans[v18].reason)
        return false, "❌ Banned"
    elseif v224.bans and v224.bans[v19] then
        v55(v224.bans[v19].reason)
        return false, "❌ Banned"
    end
    
    -- Check notifications
    -- (Would need to implement notification system in Firestore)
    
    if not v222 or v222 == "" then
        return false, "❌ No key provided"
    end
    
    if not v224.keys then
        return false, "❌ No keys found"
    end
    
    local v225 = v224.keys[v222]
    
    if not v225 then
        return false, "❌ Invalid Key"
    end
    
    local v227 = tostring(v225.rbx)
    if v227 ~= v18 then
        return false, "❌ ID Mismatch. This key belongs to user ID: " .. v227
    end
    
    if v225.exp ~= "INF" then
        local v618 = tonumber(v225.exp)
        if v618 and os.time() * 1000 > v618 then
            return false, "❌ Expired"
        end
    end
    
    return true, v225
end

-- ==================== KEY STORAGE ====================

function v43()
    if writefile and isfolder then
        if not isfolder("RSQ") then
            makefolder("RSQ")
        end
        return "RSQ"
    end
    return nil
end

function v44()
    local v70 = v43()
    if not v70 then return end
    
    local v71 = {
        userId = v18,
        active = v33,
        key = v32,
        time = os.time()
    }
    
    local v73 = v70 .. "/" .. v19 .. ".json"
    writefile(v73, v9:JSONEncode(v71))
end

function v45()
    local v74 = v43()
    if not v74 then return false end
    
    local v75 = v74 .. "/" .. v19 .. ".json"
    if not isfile(v75) then return false end
    
    local success, v77 = pcall(function()
        return v9:JSONDecode(readfile(v75))
    end)
    
    if success and v77 and v77.userId == v18 then
        if v77.active and v77.key then
            v32 = v77.key
            v33 = true
            return true
        end
    end
    return false
end

function v46()
    local v79 = v43()
    if not v79 then return end
    
    local v80 = v79 .. "/" .. v19 .. ".json"
    if isfile(v80) then
        delfile(v80)
    end
end

-- ==================== UI NOTIFICATION ====================

function v56(message, color)
    local notification = addNotification("System", message, "info")
    
    -- Also show GUI notification if available
    if v39 and v39.Parent then
        local notif = Instance.new("Frame")
        notif.Size = UDim2.new(0, 300, 0, 50)
        notif.Position = UDim2.new(0.5, -150, 0, -50)
        notif.BackgroundColor3 = color or Color3.fromRGB(79, 124, 255)
        notif.BackgroundTransparency = 0.1
        notif.BorderSizePixel = 0
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = notif
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = message
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextWrapped = true
        label.Parent = notif
        
        notif.Parent = v39
        
        -- Animate in
        v10:Create(notif, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -150, 0, 20)}):Play()
        
        -- Fade out
        task.delay(3, function()
            if notif and notif.Parent then
                v10:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 1, Position = UDim2.new(0.5, -150, 0, -50)}):Play()
                v10:Create(label, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
                task.delay(0.3, function()
                    if notif and notif.Parent then
                        notif:Destroy()
                    end
                end)
            end
        end)
    end
end

function v55(reason)
    v56("🚫 ACCESS DENIED: " .. (reason or "No reason provided"), Color3.fromRGB(255, 59, 48))
    v17:Kick("RSQ: " .. (reason or "Access Denied"))
end

-- ==================== KEY GENERATION ====================

function generateKey()
    if not v42 then
        v56("❌ You must join the group first!", Color3.fromRGB(255, 59, 48))
        return
    end
    
    local userId = v18
    
    if not userId or userId == "" then
        v56("❌ Could not get UserID", Color3.fromRGB(255, 59, 48))
        return
    end
    
    -- Check if user already has a key
    local keys = dataCache and dataCache.keys or {}
    local existingKey = nil
    for keyId, keyData in pairs(keys) do
        if tostring(keyData.rbx) == userId then
            existingKey = {keyId, keyData}
            break
        end
    end
    
    if existingKey then
        local keyId, keyData = existingKey[1], existingKey[2]
        local timeSinceCreation = (os.time() * 1000) - keyData.created
        local hoursSinceCreation = timeSinceCreation / (1000 * 60 * 60)
        
        if keyData.generatedBy == v19 and hoursSinceCreation < 24 then
            local hoursLeft = math.ceil(24 - hoursSinceCreation)
            v56(string.format("⏳ You can generate a new key in %d hours", hoursLeft), Color3.fromRGB(255, 204, 0))
            return
        elseif keyData.generatedBy ~= v19 then
            v56("❌ This UserID already has a key (generated by " .. keyData.generatedBy .. ")", Color3.fromRGB(255, 59, 48))
            return
        end
    end
    
    v56("⚡ Generating key...", Color3.fromRGB(79, 124, 255))
    
    -- Generate random key
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*'
    local newKey = ''
    for i = 1, 16 do
        newKey = newKey .. chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    
    -- Save to database
    local success = pcall(function()
        if not dataCache then dataCache = {} end
        if not dataCache.keys then dataCache.keys = {} end
        
        dataCache.keys[newKey] = {
            rbx = tonumber(userId),
            exp = "INF",
            created = os.time() * 1000,
            generatedBy = v19
        }
        
        updateDatabase(dataCache)
    end)
    
    if success then
        v32 = newKey
        v33 = true
        v44()
        v56("✅ Key generated: " .. newKey, Color3.fromRGB(40, 205, 65))
        addNotification("🔑 Key Generated", "New access key created for UserID " .. userId, "success")
    else
        v56("❌ Failed to generate key", Color3.fromRGB(255, 59, 48))
    end
end

-- ==================== GAME/SCRIPT LOADING ====================

function loadGameScripts(gameId)
    if not v33 or not v32 then
        v56("❌ Not authenticated", Color3.fromRGB(255, 59, 48))
        return
    end
    
    if not v36 or #v36 == 0 then
        v56("❌ No games available", Color3.fromRGB(255, 59, 48))
        return
    end
    
    -- Find current game
    local currentGame = nil
    for _, game in ipairs(v36) do
        if tostring(game.id) == tostring(v20) then
            currentGame = game
            break
        end
    end
    
    if not currentGame then
        -- Show game selection UI
        showGameSelector()
        return
    end
    
    -- Load scripts for this game
    if currentGame.scripts and #currentGame.scripts > 0 then
        v56("📜 Loading " .. #currentGame.scripts .. " scripts for " .. currentGame.name, Color3.fromRGB(79, 124, 255))
        
        for _, script in ipairs(currentGame.scripts) do
            local success, err = pcall(function()
                local content = game:HttpGet(script.url)
                loadstring(content)()
            end)
            
            if success then
                addNotification("📜 Script Loaded", script.name .. " loaded successfully", "success")
            else
                addNotification("❌ Script Failed", script.name .. ": " .. tostring(err), "error")
            end
            
            task.wait(0.5)
        end
        
        v56("✅ All scripts loaded!", Color3.fromRGB(40, 205, 65))
    else
        v56("📭 No scripts for this game", Color3.fromRGB(255, 204, 0))
    end
end

function showGameSelector()
    if not v39 then return end
    
    local selector = Instance.new("Frame")
    selector.Name = "GameSelector"
    selector.Size = UDim2.new(0, 400, 0, 500)
    selector.Position = UDim2.new(0.5, -200, 0.5, -250)
    selector.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    selector.BackgroundTransparency = 0.05
    selector.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = selector
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "🎮 Select Game"
    title.TextColor3 = Color3.fromRGB(0, 210, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = selector
    
    local list = Instance.new("ScrollingFrame")
    list.Name = "GameList"
    list.Size = UDim2.new(1, -20, 1, -70)
    list.Position = UDim2.new(0, 10, 0, 60)
    list.BackgroundTransparency = 1
    list.ScrollBarThickness = 4
    list.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    list.CanvasSize = UDim2.new(0, 0, 0, #v36 * 70)
    list.Parent = selector
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = list
    
    for _, game in ipairs(v36) do
        local gameBtn = Instance.new("Frame")
        gameBtn.Size = UDim2.new(1, 0, 0, 60)
        gameBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
        gameBtn.BackgroundTransparency = 0.1
        gameBtn.BorderSizePixel = 0
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = gameBtn
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -20, 0, 25)
        nameLabel.Position = UDim2.new(0, 10, 0, 8)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = game.name
        nameLabel.TextColor3 = Color3.new(1, 1, 1)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 16
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = gameBtn
        
        local idLabel = Instance.new("TextLabel")
        idLabel.Size = UDim2.new(1, -20, 0, 20)
        idLabel.Position = UDim2.new(0, 10, 0, 33)
        idLabel.BackgroundTransparency = 1
        idLabel.Text = "ID: " .. game.id
        idLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        idLabel.Font = Enum.Font.Gotham
        idLabel.TextSize = 12
        idLabel.TextXAlignment = Enum.TextXAlignment.Left
        idLabel.Parent = gameBtn
        
        local scriptCount = Instance.new("TextLabel")
        scriptCount.Size = UDim2.new(0, 80, 0, 20)
        scriptCount.Position = UDim2.new(1, -90, 0, 20)
        scriptCount.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        scriptCount.BackgroundTransparency = 0.3
        scriptCount.Text = (game.scripts and #game.scripts or 0) .. " scripts"
        scriptCount.TextColor3 = Color3.new(1, 1, 1)
        scriptCount.Font = Enum.Font.GothamBold
        scriptCount.TextSize = 10
        scriptCount.TextWrapped = true
        
        local countCorner = Instance.new("UICorner")
        countCorner.CornerRadius = UDim.new(0, 4)
        countCorner.Parent = scriptCount
        scriptCount.Parent = gameBtn
        
        gameBtn.Parent = list
        gameBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if tostring(game.id) ~= tostring(v20) then
                    v56("🚀 Teleporting to game " .. game.id .. "...", Color3.fromRGB(79, 124, 255))
                    v11:Teleport(tonumber(game.id), v17)
                else
                    selector:Destroy()
                end
            end
        end)
    end
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(1, 0)
    closeCorner.Parent = closeBtn
    closeBtn.Parent = selector
    
    closeBtn.MouseButton1Click:Connect(function()
        selector:Destroy()
    end)
    
    selector.Parent = v39
end

-- ==================== CHAT SYSTEM ====================

function sendChat(message)
    if not v33 or not v42 then
        v56("❌ Not authenticated", Color3.fromRGB(255, 59, 48))
        return
    end
    
    if not message or message == "" then return end
    
    -- Check if banned
    if dataCache and dataCache.bans and dataCache.bans[v18] then
        v56("❌ You are banned from chat", Color3.fromRGB(255, 59, 48))
        return
    end
    
    -- Moderate message
    if moderateMessage(message) then
        v56("⚠️ Message contains blocked words", Color3.fromRGB(255, 204, 0))
        return
    end
    
    local newMsg = {
        user = v19,
        txt = message,
        timestamp = os.time() * 1000,
        userId = v18
    }
    
    -- Add to database
    local success = pcall(function()
        if not dataCache then dataCache = {} end
        if not dataCache.chats then dataCache.chats = {} end
        
        table.insert(dataCache.chats, newMsg)
        
        -- Keep last 100 messages
        if #dataCache.chats > 100 then
            local newChats = {}
            for i = #dataCache.chats - 99, #dataCache.chats do
                table.insert(newChats, dataCache.chats[i])
            end
            dataCache.chats = newChats
        end
        
        updateDatabase(dataCache)
    end)
    
    if success then
        updateChatDisplay()
    end
end

function moderateMessage(text)
    local blockedWords = {"badword1", "badword2"} -- Add your blocked words here
    text = text:lower()
    for _, word in ipairs(blockedWords) do
        if text:find(word) then
            return true
        end
    end
    return false
end

function updateChatDisplay()
    if not v39 then return end
    
    local chatWindow = v39:FindFirstChild("ChatWindow")
    if not chatWindow or not chatWindow.Visible then return end
    
    local msgsContainer = chatWindow:FindFirstChild("Messages")
    if not msgsContainer then return end
    
    -- Clear existing messages
    for _, child in ipairs(msgsContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    if not dataCache or not dataCache.chats or #dataCache.chats == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 100)
        empty.Position = UDim2.new(0, 0, 0, 0)
        empty.BackgroundTransparency = 1
        empty.Text = "💬 No messages yet"
        empty.TextColor3 = Color3.fromRGB(255, 255, 255)
        empty.TextTransparency = 0.5
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 14
        empty.Parent = msgsContainer
        return
    end
    
    local yPos = 0
    for i, msg in ipairs(dataCache.chats) do
        local msgFrame = Instance.new("Frame")
        msgFrame.Size = UDim2.new(1, -10, 0, 60)
        msgFrame.Position = UDim2.new(0, 5, 0, yPos)
        msgFrame.BackgroundColor3 = msg.user == "SYSTEM" and Color3.fromRGB(79, 124, 255) or 
                                   msg.user == ADMIN_USERNAME and Color3.fromRGB(255, 204, 0) or
                                   Color3.fromRGB(30, 35, 45)
        msgFrame.BackgroundTransparency = 0.1
        msgFrame.BorderSizePixel = 0
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = msgFrame
        
        local userLabel = Instance.new("TextLabel")
        userLabel.Size = UDim2.new(1, -20, 0, 18)
        userLabel.Position = UDim2.new(0, 10, 0, 5)
        userLabel.BackgroundTransparency = 1
        userLabel.Text = msg.user .. (msg.user == ADMIN_USERNAME and " 👑" or "")
        userLabel.TextColor3 = Color3.new(1, 1, 1)
        userLabel.Font = Enum.Font.GothamBold
        userLabel.TextSize = 12
        userLabel.TextXAlignment = Enum.TextXAlignment.Left
        userLabel.Parent = msgFrame
        
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(0, 80, 0, 18)
        timeLabel.Position = UDim2.new(1, -90, 0, 5)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = os.date("%H:%M", msg.timestamp / 1000)
        timeLabel.TextColor3 = Color3.new(1, 1, 1)
        timeLabel.TextTransparency = 0.5
        timeLabel.Font = Enum.Font.Gotham
        timeLabel.TextSize = 10
        timeLabel.TextXAlignment = Enum.TextXAlignment.Right
        timeLabel.Parent = msgFrame
        
        local messageLabel = Instance.new("TextLabel")
        messageLabel.Size = UDim2.new(1, -20, 0, 30)
        messageLabel.Position = UDim2.new(0, 10, 0, 25)
        messageLabel.BackgroundTransparency = 1
        messageLabel.Text = msg.txt
        messageLabel.TextColor3 = Color3.new(1, 1, 1)
        messageLabel.Font = Enum.Font.Gotham
        messageLabel.TextSize = 11
        messageLabel.TextWrapped = true
        messageLabel.TextXAlignment = Enum.TextXAlignment.Left
        messageLabel.TextYAlignment = Enum.TextYAlignment.Top
        messageLabel.Parent = msgFrame
        
        -- Calculate actual height based on text
        local textBounds = messageLabel.TextBounds
        local msgHeight = math.max(60, 35 + textBounds.Y)
        msgFrame.Size = UDim2.new(1, -10, 0, msgHeight)
        
        msgFrame.Parent = msgsContainer
        yPos = yPos + msgHeight + 5
    end
    
    -- Update canvas size
    msgsContainer.CanvasSize = UDim2.new(0, 0, 0, yPos)
    
    -- Scroll to bottom
    task.wait()
    msgsContainer.CanvasPosition = Vector2.new(0, yPos)
end

-- ==================== MAIN UI ====================

function createMainUI()
    if v39 and v39.Parent then
        v39:Destroy()
    end
    
    v39 = Instance.new("ScreenGui")
    v39.Name = "RSQ_Elite"
    v39.Parent = v14
    v39.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    v39.ResetOnSpawn = false
    
    -- Create floating button
    createFloatingButton()
    
    -- Create notification toggle
    createNotificationToggle()
    
    -- Create chat window
    createChatWindow()
    
    -- Load scripts for current game
    if v33 and v42 then
        loadGameScripts(v20)
    end
    
    addNotification("🚀 RSQ Elite", "System initialized successfully", "success")
end

function createFloatingButton()
    if v38 and v38.Parent then
        v38:Destroy()
    end
    
    v38 = Instance.new("TextButton")
    v38.Name = "FloatingButton"
    v38.Size = UDim2.new(0, 50, 0, 50)
    v38.Position = UDim2.new(1, -70, 1, -80)
    v38.BackgroundColor3 = v33 and v42 and Color3.fromRGB(40, 205, 65) or 
                           v42 and Color3.fromRGB(255, 204, 0) or 
                           Color3.fromRGB(255, 59, 48)
    v38.BackgroundTransparency = 0.2
    v38.Text = v33 and v42 and "🔓" or v42 and "🔑" or "🔒"
    v38.TextColor3 = Color3.new(1, 1, 1)
    v38.Font = Enum.Font.GothamBold
    v38.TextSize = 24
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = v38
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Transparency = 0.5
    stroke.Thickness = 1
    stroke.Parent = v38
    
    v38.Parent = v39
    
    -- Make draggable
    local dragging = false
    local dragInput
    local dragStart
    local startPos
    
    v38.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = v38.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    v38.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    v12.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            v38.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    
    -- Click functionality
    v38.MouseButton1Click:Connect(function()
        if v33 and v42 then
            -- Show main menu
            createMainMenu()
        elseif v42 then
            -- Show key input
            showKeyInput()
        else
            -- Show group join prompt
            showGroupPrompt()
        end
    end)
end

function createNotificationToggle()
    local toggle = Instance.new("Frame")
    toggle.Name = "NotificationToggle"
    toggle.Size = UDim2.new(0, 40, 0, 40)
    toggle.Position = UDim2.new(1, -120, 1, -80)
    toggle.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    toggle.BackgroundTransparency = 0.1
    toggle.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = toggle
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "🔔"
    icon.TextColor3 = Color3.new(1, 1, 1)
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 20
    icon.Parent = toggle
    
    local badge = Instance.new("TextLabel")
    badge.Name = "Badge"
    badge.Size = UDim2.new(0, 18, 0, 18)
    badge.Position = UDim2.new(1, -10, 0, -5)
    badge.BackgroundColor3 = Color3.fromRGB(255, 77, 109)
    badge.Text = "0"
    badge.TextColor3 = Color3.new(1, 1, 1)
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 10
    
    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(1, 0)
    badgeCorner.Parent = badge
    badge.Parent = toggle
    badge.Visible = false
    
    toggle.Parent = v39
    
    -- Create notification center (initially hidden)
    local center = Instance.new("Frame")
    center.Name = "NotificationCenter"
    center.Size = UDim2.new(0, 350, 0, 400)
    center.Position = UDim2.new(1, -360, 1, -500)
    center.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    center.BackgroundTransparency = 0.05
    center.BorderSizePixel = 0
    center.Visible = false
    
    local centerCorner = Instance.new("UICorner")
    centerCorner.CornerRadius = UDim.new(0, 15)
    centerCorner.Parent = center
    
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    header.BackgroundTransparency = 0.95
    header.BorderSizePixel = 0
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 15)
    headerCorner.Parent = header
    
    local headerTitle = Instance.new("TextLabel")
    headerTitle.Size = UDim2.new(0, 200, 0, 30)
    headerTitle.Position = UDim2.new(0, 15, 0, 10)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "🔔 Notifications"
    headerTitle.TextColor3 = Color3.fromRGB(0, 210, 255)
    headerTitle.Font = Enum.Font.GothamBold
    headerTitle.TextSize = 16
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    headerTitle.Parent = header
    
    local markAllBtn = Instance.new("TextButton")
    markAllBtn.Size = UDim2.new(0, 80, 0, 30)
    markAllBtn.Position = UDim2.new(1, -95, 0, 10)
    markAllBtn.BackgroundColor3 = Color3.fromRGB(40, 205, 65)
    markAllBtn.BackgroundTransparency = 0.2
    markAllBtn.Text = "✓ All"
    markAllBtn.TextColor3 = Color3.new(1, 1, 1)
    markAllBtn.Font = Enum.Font.GothamBold
    markAllBtn.TextSize = 11
    
    local markCorner = Instance.new("UICorner")
    markCorner.CornerRadius = UDim.new(0, 6)
    markCorner.Parent = markAllBtn
    markAllBtn.Parent = header
    header.Parent = center
    
    local list = Instance.new("ScrollingFrame")
    list.Name = "NotificationsList"
    list.Size = UDim2.new(1, -10, 1, -60)
    list.Position = UDim2.new(0, 5, 0, 55)
    list.BackgroundTransparency = 1
    list.ScrollBarThickness = 4
    list.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    list.Parent = center
    
    center.Parent = v39
    
    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            toggleNotificationCenter()
        end
    end)
    
    markAllBtn.MouseButton1Click:Connect(function()
        for _, notif in ipairs(notifications) do
            notif.read = true
        end
        unreadNotifications = 0
        updateNotificationBadge()
        updateNotificationCenter()
    end)
end

function createChatWindow()
    local chatWindow = Instance.new("Frame")
    chatWindow.Name = "ChatWindow"
    chatWindow.Size = UDim2.new(0, 350, 0, 450)
    chatWindow.Position = UDim2.new(1, -370, 1, -560)
    chatWindow.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    chatWindow.BackgroundTransparency = 0.05
    chatWindow.BorderSizePixel = 0
    chatWindow.Visible = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = chatWindow
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    header.BackgroundTransparency = 0.95
    header.BorderSizePixel = 0
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 15)
    headerCorner.Parent = header
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 200, 0, 30)
    title.Position = UDim2.new(0, 15, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "💬 Network Chat"
    title.TextColor3 = Color3.fromRGB(0, 210, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(1, 0)
    closeCorner.Parent = closeBtn
    closeBtn.Parent = header
    header.Parent = chatWindow
    
    -- Pinned message area
    local pinned = Instance.new("Frame")
    pinned.Name = "PinnedMessage"
    pinned.Size = UDim2.new(1, 0, 0, 30)
    pinned.Position = UDim2.new(0, 0, 0, 50)
    pinned.BackgroundColor3 = Color3.fromRGB(255, 204, 0)
    pinned.BackgroundTransparency = 0.9
    pinned.BorderSizePixel = 0
    pinned.Visible = pinnedMessage ~= nil
    
    local pinIcon = Instance.new("TextLabel")
    pinIcon.Size = UDim2.new(0, 20, 0, 20)
    pinIcon.Position = UDim2.new(0, 8, 0, 5)
    pinIcon.BackgroundTransparency = 1
    pinIcon.Text = "📌"
    pinIcon.TextColor3 = Color3.fromRGB(255, 204, 0)
    pinIcon.Font = Enum.Font.Gotham
    pinIcon.TextSize = 14
    pinIcon.Parent = pinned
    
    local pinText = Instance.new("TextLabel")
    pinText.Size = UDim2.new(1, -35, 0, 20)
    pinText.Position = UDim2.new(0, 30, 0, 5)
    pinText.BackgroundTransparency = 1
    pinText.Text = pinnedMessage and pinnedMessage.text or ""
    pinText.TextColor3 = Color3.new(1, 1, 1)
    pinText.Font = Enum.Font.GothamBold
    pinText.TextSize = 11
    pinText.TextXAlignment = Enum.TextXAlignment.Left
    pinText.TextTruncate = Enum.TextTruncate.AtEnd
    pinText.Parent = pinned
    pinned.Parent = chatWindow
    
    -- Messages container
    local msgs = Instance.new("ScrollingFrame")
    msgs.Name = "Messages"
    msgs.Size = UDim2.new(1, -10, 1, -150)
    msgs.Position = UDim2.new(0, 5, 0, 85)
    msgs.BackgroundTransparency = 1
    msgs.ScrollBarThickness = 4
    msgs.ScrollBarImageColor3 = Color3.fromRGB(79, 124, 255)
    msgs.CanvasSize = UDim2.new(0, 0, 0, 0)
    msgs.Parent = chatWindow
    
    -- Input area
    local inputArea = Instance.new("Frame")
    inputArea.Size = UDim2.new(1, -20, 0, 60)
    inputArea.Position = UDim2.new(0, 10, 1, -70)
    inputArea.BackgroundTransparency = 1
    inputArea.Parent = chatWindow
    
    local inputBox = Instance.new("TextBox")
    inputBox.Name = "ChatInput"
    inputBox.Size = UDim2.new(1, -90, 0, 40)
    inputBox.Position = UDim2.new(0, 0, 0, 10)
    inputBox.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    inputBox.BackgroundTransparency = 0.1
    inputBox.PlaceholderText = "Type a message..."
    inputBox.PlaceholderColor3 = Color3.fromRGB(200, 200, 200)
    inputBox.Text = ""
    inputBox.TextColor3 = Color3.new(1, 1, 1)
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 12
    inputBox.ClearTextOnFocus = false
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBox
    inputBox.Parent = inputArea
    
    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0, 80, 0, 40)
    sendBtn.Position = UDim2.new(1, -80, 0, 10)
    sendBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    sendBtn.Text = "SEND"
    sendBtn.TextColor3 = Color3.new(1, 1, 1)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 12
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 8)
    sendCorner.Parent = sendBtn
    sendBtn.Parent = inputArea
    
    chatWindow.Parent = v39
    
    -- Create chat toggle button
    local chatToggle = Instance.new("TextButton")
    chatToggle.Name = "ChatToggle"
    chatToggle.Size = UDim2.new(0, 50, 0, 50)
    chatToggle.Position = UDim2.new(1, -70, 1, -140)
    chatToggle.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    chatToggle.BackgroundTransparency = 0.2
    chatToggle.Text = "💬"
    chatToggle.TextColor3 = Color3.new(1, 1, 1)
    chatToggle.Font = Enum.Font.GothamBold
    chatToggle.TextSize = 24
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = chatToggle
    
    local unread = Instance.new("TextLabel")
    unread.Name = "UnreadBadge"
    unread.Size = UDim2.new(0, 18, 0, 18)
    unread.Position = UDim2.new(1, -10, 0, -5)
    unread.BackgroundColor3 = Color3.fromRGB(255, 77, 109)
    unread.Text = "0"
    unread.TextColor3 = Color3.new(1, 1, 1)
    unread.Font = Enum.Font.GothamBold
    unread.TextSize = 10
    
    local unreadCorner = Instance.new("UICorner")
    unreadCorner.CornerRadius = UDim.new(1, 0)
    unreadCorner.Parent = unread
    unread.Parent = chatToggle
    unread.Visible = false
    
    chatToggle.Parent = v39
    
    -- Chat toggle functionality
    chatToggle.MouseButton1Click:Connect(function()
        chatWindow.Visible = not chatWindow.Visible
        if chatWindow.Visible then
            chatUnreadCount = 0
            unread.Visible = false
            updateChatDisplay()
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        chatWindow.Visible = false
    end)
    
    -- Send message
    sendBtn.MouseButton1Click:Connect(function()
        sendChat(inputBox.Text)
        inputBox.Text = ""
    end)
    
    inputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            sendChat(inputBox.Text)
            inputBox.Text = ""
        end
    end)
end

function createMainMenu()
    if not v39 then return end
    
    local menu = Instance.new("Frame")
    menu.Name = "MainMenu"
    menu.Size = UDim2.new(0, 300, 0, 400)
    menu.Position = UDim2.new(0.5, -150, 0.5, -200)
    menu.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    menu.BackgroundTransparency = 0.05
    menu.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = menu
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    header.BackgroundTransparency = 0.1
    header.BorderSizePixel = 0
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 15)
    headerCorner.Parent = header
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "RSQ ELITE"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 24
    title.Parent = header
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, 0, 0, 15)
    subtitle.Position = UDim2.new(0, 0, 0, 45)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Welcome, " .. v19
    subtitle.TextColor3 = Color3.new(1, 1, 1)
    subtitle.TextTransparency = 0.3
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.Parent = header
    header.Parent = menu
    
    -- Content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -80)
    content.Position = UDim2.new(0, 10, 0, 70)
    content.BackgroundTransparency = 1
    content.Parent = menu
    
    -- Key display
    local keyFrame = Instance.new("Frame")
    keyFrame.Size = UDim2.new(1, 0, 0, 60)
    keyFrame.Position = UDim2.new(0, 0, 0, 0)
    keyFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    keyFrame.BackgroundTransparency = 0.1
    keyFrame.BorderSizePixel = 0
    
    local keyCorner = Instance.new("UICorner")
    keyCorner.CornerRadius = UDim.new(0, 8)
    keyCorner.Parent = keyFrame
    
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size = UDim2.new(1, -10, 0, 20)
    keyLabel.Position = UDim2.new(0, 5, 0, 5)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text = "🔑 Access Key"
    keyLabel.TextColor3 = Color3.fromRGB(79, 124, 255)
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.TextSize = 12
    keyLabel.TextXAlignment = Enum.TextXAlignment.Left
    keyLabel.Parent = keyFrame
    
    local keyValue = Instance.new("TextLabel")
    keyValue.Size = UDim2.new(1, -10, 0, 30)
    keyValue.Position = UDim2.new(0, 5, 0, 25)
    keyValue.BackgroundTransparency = 1
    keyValue.Text = v32 or "No key"
    keyValue.TextColor3 = Color3.new(1, 1, 1)
    keyValue.Font = Enum.Font.Gotham
    keyValue.TextSize = 14
    keyValue.TextXAlignment = Enum.TextXAlignment.Left
    keyValue.TextWrapped = true
    keyValue.Parent = keyFrame
    keyFrame.Parent = content
    
    -- Games button
    local gamesBtn = createMenuButton("🎮 Games Library", "Browse available games", 70, function()
        menu:Destroy()
        showGameSelector()
    end)
    gamesBtn.Parent = content
    
    -- Chat button
    local chatBtn = createMenuButton("💬 Open Chat", "Join the discussion", 140, function()
        menu:Destroy()
        local chatWindow = v39:FindFirstChild("ChatWindow")
        if chatWindow then
            chatWindow.Visible = true
        end
    end)
    chatBtn.Parent = content
    
    -- Generate key button (if no key)
    if not v32 then
        local genBtn = createMenuButton("🔑 Generate Key", "Create access key", 210, function()
            menu:Destroy()
            generateKey()
        end)
        genBtn.Parent = content
    end
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(1, -20, 0, 40)
    closeBtn.Position = UDim2.new(0, 10, 1, -50)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 59, 48)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.Text = "Close"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeBtn
    closeBtn.Parent = content
    
    closeBtn.MouseButton1Click:Connect(function()
        menu:Destroy()
    end)
    
    menu.Parent = v39
end

function createMenuButton(text, desc, yPos, callback)
    local btn = Instance.new("Frame")
    btn.Size = UDim2.new(1, 0, 0, 50)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 25)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = btn
    
    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -20, 0, 15)
    description.Position = UDim2.new(0, 10, 0, 30)
    description.BackgroundTransparency = 1
    description.Text = desc
    description.TextColor3 = Color3.fromRGB(200, 200, 200)
    description.Font = Enum.Font.Gotham
    description.TextSize = 11
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.Parent = btn
    
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            callback()
        end
    end)
    
    return btn
end

function showKeyInput()
    if not v39 then return end
    
    local inputFrame = Instance.new("Frame")
    inputFrame.Size = UDim2.new(0, 300, 0, 200)
    inputFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
    inputFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    inputFrame.BackgroundTransparency = 0.05
    inputFrame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = inputFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🔑 Enter Access Key"
    title.TextColor3 = Color3.fromRGB(0, 210, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = inputFrame
    
    local input = Instance.new("TextBox")
    input.Name = "KeyInput"
    input.Size = UDim2.new(1, -40, 0, 40)
    input.Position = UDim2.new(0, 20, 0, 60)
    input.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
    input.PlaceholderText = "Paste your key here"
    input.PlaceholderColor3 = Color3.fromRGB(200, 200, 200)
    input.Text = ""
    input.TextColor3 = Color3.new(1, 1, 1)
    input.Font = Enum.Font.Gotham
    input.TextSize = 14
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = input
    input.Parent = inputFrame
    
    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0, 120, 0, 35)
    submitBtn.Position = UDim2.new(0.5, -60, 0, 120)
    submitBtn.BackgroundColor3 = Color3.fromRGB(40, 205, 65)
    submitBtn.Text = "Submit"
    submitBtn.TextColor3 = Color3.new(1, 1, 1)
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 14
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = submitBtn
    submitBtn.Parent = inputFrame
    
    local status = Instance.new("TextLabel")
    status.Name = "KeyStatus"
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.new(0, 10, 0, 165)
    status.BackgroundTransparency = 1
    status.Text = ""
    status.TextColor3 = Color3.fromRGB(255, 59, 48)
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.Parent = inputFrame
    
    inputFrame.Parent = v39
    
    submitBtn.MouseButton1Click:Connect(function()
        local key = input.Text:gsub("%s+", "")
        if key == "" then
            status.Text = "❌ Please enter a key"
            return
        end
        
        status.Text = "⚡ Validating..."
        status.TextColor3 = Color3.fromRGB(255, 204, 0)
        
        task.spawn(function()
            local valid, result = v58(key, true)
            if valid then
                v32 = key
                v33 = true
                v44()
                status.Text = "✅ Key validated!"
                status.TextColor3 = Color3.fromRGB(40, 205, 65)
                task.wait(1)
                inputFrame:Destroy()
                createFloatingButton()
                loadGameScripts(v20)
                addNotification("✅ Key Validated", "Access granted successfully", "success")
            else
                status.Text = result or "❌ Invalid key"
                status.TextColor3 = Color3.fromRGB(255, 59, 48)
            end
        end)
    end)
    
    -- Also show generate option
    local generateBtn = Instance.new("TextButton")
    generateBtn.Size = UDim2.new(1, -40, 0, 30)
    generateBtn.Position = UDim2.new(0, 20, 0, 165)
    generateBtn.BackgroundTransparency = 1
    generateBtn.Text = "Don't have a key? Generate one"
    generateBtn.TextColor3 = Color3.fromRGB(79, 124, 255)
    generateBtn.Font = Enum.Font.Gotham
    generateBtn.TextSize = 11
    generateBtn.Parent = inputFrame
    
    generateBtn.MouseButton1Click:Connect(function()
        inputFrame:Destroy()
        generateKey()
    end)
end

function showGroupPrompt()
    if not v39 then return end
    
    local prompt = Instance.new("Frame")
    prompt.Size = UDim2.new(0, 350, 0, 250)
    prompt.Position = UDim2.new(0.5, -175, 0.5, -125)
    prompt.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    prompt.BackgroundTransparency = 0.05
    prompt.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = prompt
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "🚫 ACCESS DENIED"
    title.TextColor3 = Color3.fromRGB(255, 59, 48)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 20
    title.Parent = prompt
    
    local message = Instance.new("TextLabel")
    message.Size = UDim2.new(1, -40, 0, 60)
    message.Position = UDim2.new(0, 20, 0, 60)
    message.BackgroundTransparency = 1
    message.Text = "You must join the group before accessing this system.\n\nGroup ID: " .. GROUP_ID .. "\nGroup: " .. GROUP_NAME
    message.TextColor3 = Color3.new(1, 1, 1)
    message.Font = Enum.Font.Gotham
    message.TextSize = 13
    message.TextWrapped = true
    message.Parent = prompt
    
    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0, 150, 0, 35)
    copyBtn.Position = UDim2.new(0.5, -160, 0, 140)
    copyBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    copyBtn.Text = "📋 Copy Group Link"
    copyBtn.TextColor3 = Color3.new(1, 1, 1)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 12
    
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 8)
    copyCorner.Parent = copyBtn
    copyBtn.Parent = prompt
    
    local checkBtn = Instance.new("TextButton")
    checkBtn.Size = UDim2.new(0, 150, 0, 35)
    checkBtn.Position = UDim2.new(0.5, 10, 0, 140)
    checkBtn.BackgroundColor3 = Color3.fromRGB(40, 205, 65)
    checkBtn.Text = "🔄 Check Again"
    checkBtn.TextColor3 = Color3.new(1, 1, 1)
    checkBtn.Font = Enum.Font.GothamBold
    checkBtn.TextSize = 12
    
    local checkCorner = Instance.new("UICorner")
    checkCorner.CornerRadius = UDim.new(0, 8)
    checkCorner.Parent = checkBtn
    checkBtn.Parent = prompt
    
    prompt.Parent = v39
    
    copyBtn.MouseButton1Click:Connect(function()
        setclipboard("https://www.roblox.com/groups/" .. GROUP_ID)
        v56("✅ Group link copied!", Color3.fromRGB(40, 205, 65))
    end)
    
    checkBtn.MouseButton1Click:Connect(function()
        v56("🔄 Checking membership...", Color3.fromRGB(79, 124, 255))
        task.spawn(function()
            local inGroup = v47()
            if inGroup then
                v42 = true
                prompt:Destroy()
                createFloatingButton()
                showKeyInput()
                addNotification("✅ Group Joined", "You are now a member!", "success")
            else
                v56("❌ Still not in group", Color3.fromRGB(255, 59, 48))
            end
        end)
    end)
end

-- ==================== MAIN LOOP ====================

-- Initialize
task.spawn(function()
    -- Check group membership
    v42 = v47()
    
    -- Load database
    fetchDatabase()
    
    -- Check for saved key
    local saved = v45()
    if saved then
        local valid, result = v58(v32, false)
        if not valid then
            v32 = nil
            v33 = false
            v46()
            addNotification("❌ Key Invalid", result or "Saved key is no longer valid", "error")
        else
            v33 = true
            addNotification("✅ Key Restored", "Saved key validated successfully", "success")
        end
    end
    
    -- Create UI
    createMainUI()
    
    -- Start periodic sync
    task.spawn(function()
        while true do
            task.wait(30) -- Sync every 30 seconds
            fetchDatabase()
            
            -- Check if still authenticated
            if v33 and v32 then
                local valid = v58(v32, false)
                if not valid then
                    v33 = false
                    v32 = nil
                    v46()
                    createFloatingButton()
                    addNotification("⚠️ Session Expired", "Please re-authenticate", "warning")
                end
            end
            
            -- Update chat if open
            local chatWindow = v39 and v39:FindFirstChild("ChatWindow")
            if chatWindow and chatWindow.Visible then
                updateChatDisplay()
            end
            
            -- Check for new messages (for badge)
            if not chatWindow or not chatWindow.Visible then
                if dataCache and dataCache.chats then
                    local lastMsg = dataCache.chats[#dataCache.chats]
                    if lastMsg and lastMsg.timestamp > lastSeenMessageTime and lastMsg.user ~= v19 then
                        chatUnreadCount = chatUnreadCount + 1
                        local chatToggle = v39 and v39:FindFirstChild("ChatToggle")
                        if chatToggle then
                            local badge = chatToggle:FindFirstChild("UnreadBadge")
                            if badge then
                                badge.Text = tostring(chatUnreadCount)
                                badge.Visible = true
                            end
                        end
                    end
                end
            end
        end
    end)
end)

-- Admin commands (if username matches)
if v19 == ADMIN_USERNAME then
    -- Add admin commands here
    _G.RSQ_ADMIN = {
        banUser = function(userId, reason)
            if not dataCache then dataCache = {} end
            if not dataCache.bans then dataCache.bans = {} end
            dataCache.bans[tostring(userId)] = {
                reason = reason or "Banned by admin",
                banned_by = v19,
                time = os.time() * 1000
            }
            updateDatabase(dataCache)
            addNotification("⛔ User Banned", "User " .. userId .. " has been banned", "warning")
        end,
        
        unbanUser = function(userId)
            if dataCache and dataCache.bans then
                dataCache.bans[tostring(userId)] = nil
                updateDatabase(dataCache)
                addNotification("✅ User Unbanned", "User " .. userId .. " has been unbanned", "success")
            end
        end,
        
        broadcast = function(message)
            if not dataCache then dataCache = {} end
            if not dataCache.chats then dataCache.chats = {} end
            table.insert(dataCache.chats, {
                user = "SYSTEM",
                txt = message,
                timestamp = os.time() * 1000
            })
            updateDatabase(dataCache)
            addNotification("📢 Broadcast", message, "info")
        end,
        
        pinMessage = function(message)
            dataCache.pinned = {
                text = message,
                pinnedBy = v19,
                pinnedAt = os.time() * 1000
            }
            updateDatabase(dataCache)
            addNotification("📌 Message Pinned", message, "info")
        end
    }
end

print("✅ RSQ Elite system loaded")
addNotification("🚀 RSQ Elite", "System initialized", "success")
