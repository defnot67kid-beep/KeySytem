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
local player = Players.LocalPlayer
local USER_ID = tostring(player.UserId)
local USER_NAME = player.Name
local PLACE_ID = game.PlaceId

--==================================================--
-- CONFIG
--==================================================--
local REQUIRED_GROUP_ID = 687789545  -- Group ID that user must be in
local REQUIRED_FOLLOW_USER_ID = 10164999531  -- User ID to follow

local JSONBIN_URL = "https://api.jsonbin.io/v3/b/695418f4ae596e708fbaa2c0/latest"
local JSON_KEY = "$2a$10$lJsjtUi1Uhv4Rf/UaeMP7.GU5IwIEkAfdNZGpxyIesXLCj7hasRRG"
local GET_KEY_URL = "https://realscripts-q.github.io/KEY-JSONHandler/"
local DISCORD_WEBHOOK = "https://webhook.lewisakura.moe/api/webhooks/1453515343833338017/7VwwcpKDpSvIYr0PA3Ceh8YgMwIEba47CoyISHCZkvdaF2hUsvyUYw3zNV_TbYyDFTMy"

local SCRIPT_URLS = {
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/D.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/I.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/N.lua",
}
local CHECK_INTERVAL = 1 -- Reduced to 1 second for faster background checks

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
local IsCheckingRequirements = false -- Track if we're checking requirements
local HasMetRequirements = false -- Track if user has met group/follow requirements

-- Function to check if user is in required group
local function checkGroupMembership()
    local success, result = pcall(function()
        local groups = player:GetGroups()
        for _, group in ipairs(groups) do
            if group.Id == REQUIRED_GROUP_ID then
                return true
            end
        end
        return false
    end)
    
    if success then
        return result
    else
        warn("[RSQ] Error checking group membership:", result)
        return false
    end
end

-- Function to prompt user to join group
local function promptJoinGroup()
    local success, result = pcall(function()
        return GroupService:PromptJoinAsync(REQUIRED_GROUP_ID)
    end)
    
    if success then
        return result
    else
        warn("[RSQ] Error prompting group join:", result)
        return nil
    end
end

-- Function to check follow status (simplified - Roblox API limitation)
local function checkFollowStatus()
    -- Note: Roblox doesn't provide a direct API to check follow status
    -- We'll show a notification instead
    return true  -- Assume they need to follow
end

-- Function to create requirement check GUI
local function showRequirementsGUI()
    -- Check if GUI is already loaded
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name == "RSQ_RequirementsCheck" then
            gui:Destroy()
        end
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_RequirementsCheck"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui
    
    local overlay = Instance.new("Frame", gui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    
    local mainFrame = Instance.new("Frame", gui)
    mainFrame.Size = UDim2.new(0, 400, 0, 350)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(mainFrame, mainFrame)
    
    -- Title bar
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.Text = "⚠️ Requirements Needed"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 140, 0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Size = UDim2.new(1, -40, 1, -100)
    contentFrame.Position = UDim2.new(0, 20, 0, 60)
    contentFrame.BackgroundTransparency = 1
    
    -- Requirements text
    local requirementsText = Instance.new("TextLabel", contentFrame)
    requirementsText.Size = UDim2.new(1, 0, 0, 150)
    requirementsText.Position = UDim2.new(0, 0, 0, 0)
    requirementsText.Text = [[To use RSQ Elite, you must:

1. 🏢 JOIN OUR GROUP
   • Group ID: ]] .. REQUIRED_GROUP_ID .. [[
   • Click the "Join Group" button below

2. 👤 FOLLOW THE OWNER
   • User ID: ]] .. REQUIRED_FOLLOW_USER_ID .. [[
   • Search for the user and click "Follow"

3. ✅ GET YOUR KEY
   • Visit our website: ]] .. GET_KEY_URL .. [[
   • Generate a key with your Roblox ID

Once you've completed these steps,
click "Verify Requirements" to continue.]]
    requirementsText.Font = Enum.Font.Gotham
    requirementsText.TextSize = 13
    requirementsText.TextColor3 = Color3.new(1, 1, 1)
    requirementsText.BackgroundTransparency = 1
    requirementsText.TextWrapped = true
    requirementsText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Join Group button
    local joinGroupBtn = Instance.new("TextButton", mainFrame)
    joinGroupBtn.Size = UDim2.new(0, 160, 0, 35)
    joinGroupBtn.Position = UDim2.new(0.5, -170, 1, -50)
    joinGroupBtn.Text = "🏢 Join Group"
    joinGroupBtn.Font = Enum.Font.GothamBold
    joinGroupBtn.TextSize = 13
    joinGroupBtn.TextColor3 = Color3.new(1, 1, 1)
    joinGroupBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    joinGroupBtn.BorderSizePixel = 0
    Instance.new("UICorner", joinGroupBtn).CornerRadius = UDim.new(0, 8)
    
    -- Verify button
    local verifyBtn = Instance.new("TextButton", mainFrame)
    verifyBtn.Size = UDim2.new(0, 160, 0, 35)
    verifyBtn.Position = UDim2.new(0.5, 10, 1, -50)
    verifyBtn.Text = "✅ Verify Requirements"
    verifyBtn.Font = Enum.Font.GothamBold
    verifyBtn.TextSize = 13
    verifyBtn.TextColor3 = Color3.new(1, 1, 1)
    verifyBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    verifyBtn.BorderSizePixel = 0
    Instance.new("UICorner", verifyBtn).CornerRadius = UDim.new(0, 8)
    
    -- Button functions
    joinGroupBtn.MouseButton1Click:Connect(function()
        createNotify("Opening group join prompt...", Color3.fromRGB(79, 124, 255))
        local status = promptJoinGroup()
        
        if status then
            createNotify("Group join initiated. Please accept the prompt.", Color3.fromRGB(40, 200, 80))
        else
            createNotify("Could not open group prompt. Please join group manually.", Color3.fromRGB(255, 140, 0))
        end
    end)
    
    verifyBtn.MouseButton1Click:Connect(function()
        createNotify("Checking requirements...", Color3.fromRGB(79, 124, 255))
        
        -- Check group membership
        local isInGroup = checkGroupMembership()
        
        if isInGroup then
            createNotify("✅ You're in the group!", Color3.fromRGB(40, 200, 80))
            HasMetRequirements = true
            gui:Destroy()
            
            -- Show key GUI
            task.wait(1)
            createNotify("Requirements met! Opening key system...", Color3.fromRGB(40, 200, 80))
            showKeyGUI()
        else
            createNotify("❌ You must join the group first!", Color3.fromRGB(255, 50, 50))
        end
    end)
    
    -- Animation
    mainFrame.BackgroundTransparency = 1
    TweenService:Create(mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
end

-- Function to check all requirements
local function checkRequirements()
    IsCheckingRequirements = true
    
    -- First, check group membership
    local isInGroup = checkGroupMembership()
    
    if not isInGroup then
        createNotify("❌ You must join group " .. REQUIRED_GROUP_ID .. " to use RSQ Elite!", Color3.fromRGB(255, 50, 50))
        showRequirementsGUI()
        IsCheckingRequirements = false
        return false
    end
    
    -- Group requirement met
    createNotify("✅ Group requirement met!", Color3.fromRGB(40, 200, 80))
    
    -- Remind about follow requirement (we can't actually check this)
    createNotify("⚠️ Remember to follow User ID: " .. REQUIRED_FOLLOW_USER_ID, Color3.fromRGB(255, 140, 0))
    
    HasMetRequirements = true
    IsCheckingRequirements = false
    return true
end

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

-- Function to check if GUI is already loaded
local function isGUILoaded()
    -- Check in CoreGui
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or gui.Name == "RSQ_RequirementsCheck" then
            return true
        end
    end
    
    -- Check in PlayerGui
    if player.PlayerGui then
        for _, gui in pairs(player.PlayerGui:GetChildren()) do
            if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or gui.Name == "RSQ_RequirementsCheck" then
                return true
            end
        end
    end
    
    return false
end

-- Function to create open button (only if requirements met)
local function createOpenButton()
    -- Don't create button if requirements not met
    if not HasMetRequirements then
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
                    gui.Name:find("RSQ_TeleportConfirm") or gui.Name:find("RSQ_Notifications")) then
                    table.insert(existingGuis, gui)
                end
            end
            
            -- Check in PlayerGui
            if player.PlayerGui then
                for _, gui in pairs(player.PlayerGui:GetChildren()) do
                    if (gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or 
                        gui.Name:find("RSQ_TeleportConfirm") or gui.Name:find("RSQ_Notifications")) then
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
            
            -- Check requirements again
            if not checkRequirements() then
                createNotify("❌ Requirements not met!", Color3.fromRGB(255, 50, 50))
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

-- Function to create notification
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
    title.Text = "⚠️ Teleport Required"
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
        teleportGui:Destroy()
    end)
    
    local message = Instance.new("TextLabel", confirmFrame)
    message.Size = UDim2.new(1, -20, 0, 80)
    message.Position = UDim2.new(0, 10, 0, 40)
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
    yesBtn.BorderSizePixel = 0
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
    noBtn.BorderSizePixel = 0
    Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 8)
    
    -- Button events
    yesBtn.MouseButton1Click:Connect(function()
        createNotify("Teleporting to Game ID: " .. gameId, Color3.fromRGB(40, 200, 80))
        teleportGui:Destroy()
        
        -- Convert gameId to number for teleport
        local gameIdNumber = tonumber(gameId)
        if gameIdNumber then
            -- Try teleport with error handling
            local success, err = pcall(function()
                TeleportService:Teleport(gameIdNumber, player)
            end)
            
            if not success then
                createNotify("❌ Teleport failed: " .. tostring(err), Color3.fromRGB(255, 50, 50))
                
                -- Try alternative teleport method
                task.wait(1)
                createNotify("Trying alternative teleport method...", Color3.fromRGB(255, 140, 0))
                
                -- Use MarketplaceService to launch game
                pcall(function()
                    MarketplaceService:PromptGamePassPurchase(player, gameIdNumber)
                end)
            end
        else
            createNotify("❌ Invalid Game ID format", Color3.fromRGB(255, 50, 50))
        end
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
    -- First check requirements
    if not checkRequirements() then
        createNotify("❌ Requirements not met!", Color3.fromRGB(255, 50, 50))
        showRequirementsGUI()
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
    
    if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
        OpenButton.ToggleButton.Text = "🔒"
        OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    end
    
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
        if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
            OpenButton.ToggleButton.Text = "🔓"
            OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        end
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
                    
                    -- Added by info
                    local addedByInfo = Instance.new("TextLabel", scriptInfo)
                    addedByInfo.Size = UDim2.new(1, -10, 0, 15)
                    addedByInfo.Position = UDim2.new(0, 0, 0, 50)
                    addedByInfo.Text = "👤 " .. (scriptData.addedBy or "Unknown")
                    addedByInfo.Font = Enum.Font.Gotham
                    addedByInfo.TextSize = 10
                    addedByInfo.TextColor3 = Color3.fromRGB(0, 200, 255)
                    addedByInfo.TextXAlignment = Enum.TextXAlignment.Left
                    addedByInfo.BackgroundTransparency = 1
                    
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
                        local capturedScriptData = {
                            name = scriptData.name,
                            url = scriptData.url
                        }
                        local capturedGameId = gameData.id
                        
                        executeBtn.MouseButton1Click:Connect(function()
                            -- Check if player is in the right game
                            if tostring(capturedGameId) == tostring(PLACE_ID) then
                                createNotify("Executing script: " .. capturedScriptData.name, Color3.fromRGB(40, 200, 80))
                                
                                -- Execute the script
                                task.spawn(function()
                                    local success, errorMsg = pcall(function()
                                        local scriptContent = game:HttpGet(capturedScriptData.url)
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
-- INITIAL KEY GUI
--==================================================--
local function showKeyGUI()
    -- First check requirements
    if not checkRequirements() then
        createNotify("❌ Requirements not met!", Color3.fromRGB(255, 50, 50))
        showRequirementsGUI()
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
    
    if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
        OpenButton.ToggleButton.Text = "🔒"
        OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_KeySystem"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui
    CurrentGUI = gui

    local card = Instance.new("Frame", gui)
    card.Size = UDim2.new(0, 350, 0, 280) -- Taller to show requirements
    card.Position = UDim2.new(0.5, -175, 0.5, -140)
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
        if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
            OpenButton.ToggleButton.Text = "🔓"
            OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        end
        gui:Destroy()
        CurrentGUI = nil
    end)

    -- Requirements info
    local reqInfo = Instance.new("TextLabel", card)
    reqInfo.Size = UDim2.new(1, -30, 0, 50)
    reqInfo.Position = UDim2.new(0, 15, 0, 45)
    reqInfo.Text = "✅ Requirements Met:\n• Group: " .. REQUIRED_GROUP_ID .. "\n• Follow: " .. REQUIRED_FOLLOW_USER_ID
    reqInfo.Font = Enum.Font.Gotham
    reqInfo.TextSize = 11
    reqInfo.TextColor3 = Color3.fromRGB(40, 200, 80)
    reqInfo.BackgroundTransparency = 1
    reqInfo.TextWrapped = true
    reqInfo.TextXAlignment = Enum.TextXAlignment.Left

    local input = Instance.new("TextBox", card)
    input.PlaceholderText = "Paste your key here"
    input.Size = UDim2.new(1, -30, 0, 35)
    input.Position = UDim2.new(0, 15, 0, 105)
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.TextColor3 = Color3.new(1,1,1)
    input.BackgroundColor3 = Color3.fromRGB(14,18,30)
    input.BorderSizePixel = 0
    Instance.new("UICorner", input).CornerRadius = UDim.new(0,8)

    local unlock = Instance.new("TextButton", card)
    unlock.Text = "Unlock / Check Key"
    unlock.Size = UDim2.new(1, -30, 0, 35)
    unlock.Position = UDim2.new(0, 15, 0, 150)
    unlock.Font = Enum.Font.GothamBold
    unlock.TextSize = 13
    unlock.TextColor3 = Color3.new(1,1,1)
    unlock.BackgroundColor3 = Color3.fromRGB(0,140,255)
    unlock.BorderSizePixel = 0
    Instance.new("UICorner", unlock).CornerRadius = UDim.new(0,8)

    local getKey = Instance.new("TextButton", card)
    getKey.Text = "🌐 Get Key"
    getKey.Size = UDim2.new(1, -30, 0, 30)
    getKey.Position = UDim2.new(0, 15, 0, 195)
    getKey.Font = Enum.Font.GothamBold
    getKey.TextSize = 12
    getKey.TextColor3 = Color3.new(1,1,1)
    getKey.BackgroundColor3 = Color3.fromRGB(255,140,0)
    getKey.BorderSizePixel = 0
    Instance.new("UICorner", getKey).CornerRadius = UDim.new(0,8)

    local status = Instance.new("TextLabel", card)
    status.Position = UDim2.new(0, 15, 0, 235)
    status.Size = UDim2.new(1, -30, 0, 35)
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
-- INITIALIZE
--==================================================--
-- Check for saved key first
task.spawn(function()
    IsInitializing = true
    
    -- Show welcome notification
    createNotify("⚠️ RSQ Elite requires you to:\n1. Join Group " .. REQUIRED_GROUP_ID .. "\n2. Follow User " .. REQUIRED_FOLLOW_USER_ID, Color3.fromRGB(255, 140, 0))
    
    -- Check requirements first
    local requirementsMet = checkRequirements()
    
    if requirementsMet then
        local hasSavedKey = loadKeyStatus()
        if hasSavedKey then
            -- Auto-open advanced GUI if key is saved and valid
            createNotify("Loading saved key...", Color3.fromRGB(79, 124, 255))
            
            -- Validate the saved key
            local ok, res = validate(CurrentKey, false)
            if ok then
                createNotify("✅ Key validated successfully!", Color3.fromRGB(40, 200, 80))
                createOpenButton()
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
                createOpenButton()
                task.wait(1)
                showKeyGUI()
            end
        else
            -- No saved key, show key GUI
            createOpenButton()
            task.wait(1)
            showKeyGUI()
        end
    else
        -- Requirements not met, show requirements GUI
        task.wait(2)
        showRequirementsGUI()
    end
    
    IsInitializing = false
end)

--==================================================--
-- SECURITY LOOPS (HIGH FREQUENCY)
--==================================================--
task.spawn(function()
    while true do
        task.wait(CHECK_INTERVAL)
        if KeyActive and CurrentKey then
            local ok, res = validate(CurrentKey, false)
            if not ok then
                -- Key expired or invalid
                createNotify("❌ Key is no longer valid: " .. res, Color3.fromRGB(255, 50, 50))--==================================================--
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
local player = Players.LocalPlayer
local USER_ID = tostring(player.UserId)
local USER_NAME = player.Name
local PLACE_ID = game.PlaceId

--==================================================--
-- CONFIG
--==================================================--
local REQUIRED_GROUP_ID = 10164999531  -- Group ID that user must be in
local REQUIRED_FOLLOW_USER_ID = 10164999531  -- User ID to follow

local JSONBIN_URL = "https://api.jsonbin.io/v3/b/695418f4ae596e708fbaa2c0/latest"
local JSON_KEY = "$2a$10$lJsjtUi1Uhv4Rf/UaeMP7.GU5IwIEkAfdNZGpxyIesXLCj7hasRRG"
local GET_KEY_URL = "https://realscripts-q.github.io/KEY-JSONHandler/"
local DISCORD_WEBHOOK = "https://webhook.lewisakura.moe/api/webhooks/1453515343833338017/7VwwcpKDpSvIYr0PA3Ceh8YgMwIEba47CoyISHCZkvdaF2hUsvyUYw3zNV_TbYyDFTMy"

local SCRIPT_URLS = {
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/D.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/I.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/N.lua",
}
local CHECK_INTERVAL = 1 -- Reduced to 1 second for faster background checks

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
local IsCheckingRequirements = false -- Track if we're checking requirements
local HasMetRequirements = false -- Track if user has met group/follow requirements

-- Function to check if user is in required group
local function checkGroupMembership()
    local success, result = pcall(function()
        local groups = player:GetGroups()
        for _, group in ipairs(groups) do
            if group.Id == REQUIRED_GROUP_ID then
                return true
            end
        end
        return false
    end)
    
    if success then
        return result
    else
        warn("[RSQ] Error checking group membership:", result)
        return false
    end
end

-- Function to prompt user to join group
local function promptJoinGroup()
    local success, result = pcall(function()
        return GroupService:PromptJoinAsync(REQUIRED_GROUP_ID)
    end)
    
    if success then
        return result
    else
        warn("[RSQ] Error prompting group join:", result)
        return nil
    end
end

-- Function to check follow status (simplified - Roblox API limitation)
local function checkFollowStatus()
    -- Note: Roblox doesn't provide a direct API to check follow status
    -- We'll show a notification instead
    return true  -- Assume they need to follow
end

-- Function to create requirement check GUI
local function showRequirementsGUI()
    -- Check if GUI is already loaded
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name == "RSQ_RequirementsCheck" then
            gui:Destroy()
        end
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_RequirementsCheck"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui
    
    local overlay = Instance.new("Frame", gui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    
    local mainFrame = Instance.new("Frame", gui)
    mainFrame.Size = UDim2.new(0, 400, 0, 350)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
    
    -- Make draggable
    makeDraggable(mainFrame, mainFrame)
    
    -- Title bar
    local titleBar = Instance.new("Frame", mainFrame)
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.Text = "⚠️ Requirements Needed"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 140, 0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Size = UDim2.new(1, -40, 1, -100)
    contentFrame.Position = UDim2.new(0, 20, 0, 60)
    contentFrame.BackgroundTransparency = 1
    
    -- Requirements text
    local requirementsText = Instance.new("TextLabel", contentFrame)
    requirementsText.Size = UDim2.new(1, 0, 0, 150)
    requirementsText.Position = UDim2.new(0, 0, 0, 0)
    requirementsText.Text = [[To use RSQ Elite, you must:

1. 🏢 JOIN OUR GROUP
   • Group ID: ]] .. REQUIRED_GROUP_ID .. [[
   • Click the "Join Group" button below

2. 👤 FOLLOW THE OWNER
   • User ID: ]] .. REQUIRED_FOLLOW_USER_ID .. [[
   • Search for the user and click "Follow"

3. ✅ GET YOUR KEY
   • Visit our website: ]] .. GET_KEY_URL .. [[
   • Generate a key with your Roblox ID

Once you've completed these steps,
click "Verify Requirements" to continue.]]
    requirementsText.Font = Enum.Font.Gotham
    requirementsText.TextSize = 13
    requirementsText.TextColor3 = Color3.new(1, 1, 1)
    requirementsText.BackgroundTransparency = 1
    requirementsText.TextWrapped = true
    requirementsText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Join Group button
    local joinGroupBtn = Instance.new("TextButton", mainFrame)
    joinGroupBtn.Size = UDim2.new(0, 160, 0, 35)
    joinGroupBtn.Position = UDim2.new(0.5, -170, 1, -50)
    joinGroupBtn.Text = "🏢 Join Group"
    joinGroupBtn.Font = Enum.Font.GothamBold
    joinGroupBtn.TextSize = 13
    joinGroupBtn.TextColor3 = Color3.new(1, 1, 1)
    joinGroupBtn.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
    joinGroupBtn.BorderSizePixel = 0
    Instance.new("UICorner", joinGroupBtn).CornerRadius = UDim.new(0, 8)
    
    -- Verify button
    local verifyBtn = Instance.new("TextButton", mainFrame)
    verifyBtn.Size = UDim2.new(0, 160, 0, 35)
    verifyBtn.Position = UDim2.new(0.5, 10, 1, -50)
    verifyBtn.Text = "✅ Verify Requirements"
    verifyBtn.Font = Enum.Font.GothamBold
    verifyBtn.TextSize = 13
    verifyBtn.TextColor3 = Color3.new(1, 1, 1)
    verifyBtn.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    verifyBtn.BorderSizePixel = 0
    Instance.new("UICorner", verifyBtn).CornerRadius = UDim.new(0, 8)
    
    -- Button functions
    joinGroupBtn.MouseButton1Click:Connect(function()
        createNotify("Opening group join prompt...", Color3.fromRGB(79, 124, 255))
        local status = promptJoinGroup()
        
        if status then
            createNotify("Group join initiated. Please accept the prompt.", Color3.fromRGB(40, 200, 80))
        else
            createNotify("Could not open group prompt. Please join group manually.", Color3.fromRGB(255, 140, 0))
        end
    end)
    
    verifyBtn.MouseButton1Click:Connect(function()
        createNotify("Checking requirements...", Color3.fromRGB(79, 124, 255))
        
        -- Check group membership
        local isInGroup = checkGroupMembership()
        
        if isInGroup then
            createNotify("✅ You're in the group!", Color3.fromRGB(40, 200, 80))
            HasMetRequirements = true
            gui:Destroy()
            
            -- Show key GUI
            task.wait(1)
            createNotify("Requirements met! Opening key system...", Color3.fromRGB(40, 200, 80))
            showKeyGUI()
        else
            createNotify("❌ You must join the group first!", Color3.fromRGB(255, 50, 50))
        end
    end)
    
    -- Animation
    mainFrame.BackgroundTransparency = 1
    TweenService:Create(mainFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
end

-- Function to check all requirements
local function checkRequirements()
    IsCheckingRequirements = true
    
    -- First, check group membership
    local isInGroup = checkGroupMembership()
    
    if not isInGroup then
        createNotify("❌ You must join group " .. REQUIRED_GROUP_ID .. " to use RSQ Elite!", Color3.fromRGB(255, 50, 50))
        showRequirementsGUI()
        IsCheckingRequirements = false
        return false
    end
    
    -- Group requirement met
    createNotify("✅ Group requirement met!", Color3.fromRGB(40, 200, 80))
    
    -- Remind about follow requirement (we can't actually check this)
    createNotify("⚠️ Remember to follow User ID: " .. REQUIRED_FOLLOW_USER_ID, Color3.fromRGB(255, 140, 0))
    
    HasMetRequirements = true
    IsCheckingRequirements = false
    return true
end

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

-- Function to check if GUI is already loaded
local function isGUILoaded()
    -- Check in CoreGui
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or gui.Name == "RSQ_RequirementsCheck" then
            return true
        end
    end
    
    -- Check in PlayerGui
    if player.PlayerGui then
        for _, gui in pairs(player.PlayerGui:GetChildren()) do
            if gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or gui.Name == "RSQ_RequirementsCheck" then
                return true
            end
        end
    end
    
    return false
end

-- Function to create open button (only if requirements met)
local function createOpenButton()
    -- Don't create button if requirements not met
    if not HasMetRequirements then
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
                    gui.Name:find("RSQ_TeleportConfirm") or gui.Name:find("RSQ_Notifications")) then
                    table.insert(existingGuis, gui)
                end
            end
            
            -- Check in PlayerGui
            if player.PlayerGui then
                for _, gui in pairs(player.PlayerGui:GetChildren()) do
                    if (gui.Name == "RSQ_KeySystem" or gui.Name == "RSQ_AdvancedGamesGUI" or 
                        gui.Name:find("RSQ_TeleportConfirm") or gui.Name:find("RSQ_Notifications")) then
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
            
            -- Check requirements again
            if not checkRequirements() then
                createNotify("❌ Requirements not met!", Color3.fromRGB(255, 50, 50))
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

-- Function to create notification
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
    title.Text = "⚠️ Teleport Required"
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
        teleportGui:Destroy()
    end)
    
    local message = Instance.new("TextLabel", confirmFrame)
    message.Size = UDim2.new(1, -20, 0, 80)
    message.Position = UDim2.new(0, 10, 0, 40)
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
    yesBtn.BorderSizePixel = 0
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
    noBtn.BorderSizePixel = 0
    Instance.new("UICorner", noBtn).CornerRadius = UDim.new(0, 8)
    
    -- Button events
    yesBtn.MouseButton1Click:Connect(function()
        createNotify("Teleporting to Game ID: " .. gameId, Color3.fromRGB(40, 200, 80))
        teleportGui:Destroy()
        
        -- Convert gameId to number for teleport
        local gameIdNumber = tonumber(gameId)
        if gameIdNumber then
            -- Try teleport with error handling
            local success, err = pcall(function()
                TeleportService:Teleport(gameIdNumber, player)
            end)
            
            if not success then
                createNotify("❌ Teleport failed: " .. tostring(err), Color3.fromRGB(255, 50, 50))
                
                -- Try alternative teleport method
                task.wait(1)
                createNotify("Trying alternative teleport method...", Color3.fromRGB(255, 140, 0))
                
                -- Use MarketplaceService to launch game
                pcall(function()
                    MarketplaceService:PromptGamePassPurchase(player, gameIdNumber)
                end)
            end
        else
            createNotify("❌ Invalid Game ID format", Color3.fromRGB(255, 50, 50))
        end
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
    -- First check requirements
    if not checkRequirements() then
        createNotify("❌ Requirements not met!", Color3.fromRGB(255, 50, 50))
        showRequirementsGUI()
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
    
    if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
        OpenButton.ToggleButton.Text = "🔒"
        OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    end
    
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
        if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
            OpenButton.ToggleButton.Text = "🔓"
            OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        end
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
                    
                    -- Added by info
                    local addedByInfo = Instance.new("TextLabel", scriptInfo)
                    addedByInfo.Size = UDim2.new(1, -10, 0, 15)
                    addedByInfo.Position = UDim2.new(0, 0, 0, 50)
                    addedByInfo.Text = "👤 " .. (scriptData.addedBy or "Unknown")
                    addedByInfo.Font = Enum.Font.Gotham
                    addedByInfo.TextSize = 10
                    addedByInfo.TextColor3 = Color3.fromRGB(0, 200, 255)
                    addedByInfo.TextXAlignment = Enum.TextXAlignment.Left
                    addedByInfo.BackgroundTransparency = 1
                    
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
                        local capturedScriptData = {
                            name = scriptData.name,
                            url = scriptData.url
                        }
                        local capturedGameId = gameData.id
                        
                        executeBtn.MouseButton1Click:Connect(function()
                            -- Check if player is in the right game
                            if tostring(capturedGameId) == tostring(PLACE_ID) then
                                createNotify("Executing script: " .. capturedScriptData.name, Color3.fromRGB(40, 200, 80))
                                
                                -- Execute the script
                                task.spawn(function()
                                    local success, errorMsg = pcall(function()
                                        local scriptContent = game:HttpGet(capturedScriptData.url)
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
-- INITIAL KEY GUI
--==================================================--
local function showKeyGUI()
    -- First check requirements
    if not checkRequirements() then
        createNotify("❌ Requirements not met!", Color3.fromRGB(255, 50, 50))
        showRequirementsGUI()
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
    
    if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
        OpenButton.ToggleButton.Text = "🔒"
        OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "RSQ_KeySystem"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui
    CurrentGUI = gui

    local card = Instance.new("Frame", gui)
    card.Size = UDim2.new(0, 350, 0, 280) -- Taller to show requirements
    card.Position = UDim2.new(0.5, -175, 0.5, -140)
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
        if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
            OpenButton.ToggleButton.Text = "🔓"
            OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
        end
        gui:Destroy()
        CurrentGUI = nil
    end)

    -- Requirements info
    local reqInfo = Instance.new("TextLabel", card)
    reqInfo.Size = UDim2.new(1, -30, 0, 50)
    reqInfo.Position = UDim2.new(0, 15, 0, 45)
    reqInfo.Text = "✅ Requirements Met:\n• Group: " .. REQUIRED_GROUP_ID .. "\n• Follow: " .. REQUIRED_FOLLOW_USER_ID
    reqInfo.Font = Enum.Font.Gotham
    reqInfo.TextSize = 11
    reqInfo.TextColor3 = Color3.fromRGB(40, 200, 80)
    reqInfo.BackgroundTransparency = 1
    reqInfo.TextWrapped = true
    reqInfo.TextXAlignment = Enum.TextXAlignment.Left

    local input = Instance.new("TextBox", card)
    input.PlaceholderText = "Paste your key here"
    input.Size = UDim2.new(1, -30, 0, 35)
    input.Position = UDim2.new(0, 15, 0, 105)
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.TextColor3 = Color3.new(1,1,1)
    input.BackgroundColor3 = Color3.fromRGB(14,18,30)
    input.BorderSizePixel = 0
    Instance.new("UICorner", input).CornerRadius = UDim.new(0,8)

    local unlock = Instance.new("TextButton", card)
    unlock.Text = "Unlock / Check Key"
    unlock.Size = UDim2.new(1, -30, 0, 35)
    unlock.Position = UDim2.new(0, 15, 0, 150)
    unlock.Font = Enum.Font.GothamBold
    unlock.TextSize = 13
    unlock.TextColor3 = Color3.new(1,1,1)
    unlock.BackgroundColor3 = Color3.fromRGB(0,140,255)
    unlock.BorderSizePixel = 0
    Instance.new("UICorner", unlock).CornerRadius = UDim.new(0,8)

    local getKey = Instance.new("TextButton", card)
    getKey.Text = "🌐 Get Key"
    getKey.Size = UDim2.new(1, -30, 0, 30)
    getKey.Position = UDim2.new(0, 15, 0, 195)
    getKey.Font = Enum.Font.GothamBold
    getKey.TextSize = 12
    getKey.TextColor3 = Color3.new(1,1,1)
    getKey.BackgroundColor3 = Color3.fromRGB(255,140,0)
    getKey.BorderSizePixel = 0
    Instance.new("UICorner", getKey).CornerRadius = UDim.new(0,8)

    local status = Instance.new("TextLabel", card)
    status.Position = UDim2.new(0, 15, 0, 235)
    status.Size = UDim2.new(1, -30, 0, 35)
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
-- INITIALIZE
--==================================================--
-- Check for saved key first
task.spawn(function()
    IsInitializing = true
    
    -- Show welcome notification
    createNotify("⚠️ RSQ Elite requires you to:\n1. Join Group " .. REQUIRED_GROUP_ID .. "\n2. Follow User " .. REQUIRED_FOLLOW_USER_ID, Color3.fromRGB(255, 140, 0))
    
    -- Check requirements first
    local requirementsMet = checkRequirements()
    
    if requirementsMet then
        local hasSavedKey = loadKeyStatus()
        if hasSavedKey then
            -- Auto-open advanced GUI if key is saved and valid
            createNotify("Loading saved key...", Color3.fromRGB(79, 124, 255))
            
            -- Validate the saved key
            local ok, res = validate(CurrentKey, false)
            if ok then
                createNotify("✅ Key validated successfully!", Color3.fromRGB(40, 200, 80))
                createOpenButton()
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
                createOpenButton()
                task.wait(1)
                showKeyGUI()
            end
        else
            -- No saved key, show key GUI
            createOpenButton()
            task.wait(1)
            showKeyGUI()
        end
    else
        -- Requirements not met, show requirements GUI
        task.wait(2)
        showRequirementsGUI()
    end
    
    IsInitializing = false
end)

--==================================================--
-- SECURITY LOOPS (HIGH FREQUENCY)
--==================================================--
task.spawn(function()
    while true do
        task.wait(CHECK_INTERVAL)
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
                if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
                    OpenButton.ToggleButton.Text = "🔓"
                    OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
                end
                
                -- Show key GUI again
                showKeyGUI()
            end
        end
    end
end)
                KeyActive = false
                CurrentKey = nil
                clearKeyStatus()
                
                -- Close any open GUIs
                if CurrentGUI and CurrentGUI.Parent then
                    CurrentGUI:Destroy()
                    CurrentGUI = nil
                end
                
                IsGuiOpen = false
                if OpenButton and OpenButton:FindFirstChild("ToggleButton") then
                    OpenButton.ToggleButton.Text = "🔓"
                    OpenButton.ToggleButton.BackgroundColor3 = Color3.fromRGB(79, 124, 255)
                end
                
                -- Show key GUI again
                showKeyGUI()
            end
        end
    end
end)
