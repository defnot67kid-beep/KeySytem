--==================================================--
-- RSQ KEY SYSTEM — WITH SYTHICSMERCH & GROUP REQUIREMENT
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
-- CONFIG - UPDATED WITH YOUR BIN
--==================================================--
local JSONBIN_URL = "6952cbcdd0ea881f4047f5ff"
local JSON_KEY = "$2a$10$f6r4B1gP.MfB1k49kq2m7eEzyesjD9KWP5zCa6QtJKW5ZBhL1M0/O"
local GET_KEY_URL = "https://defnot67kid-beep.github.io/KeySytem/"
local REQUIRED_GROUP_ID = 687789545  -- Required group for GUI access
local SYTHICSMERCH_GAMEPASS_ID = 136243714765116  -- SythicsMerch GamePass ID
local DISCORD_WEBHOOK = ""

local SCRIPT_URLS = {
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/D.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/I.lua",
    "https://raw.githubusercontent.com/RealScripts-q/KEY-JSONHandler/main/N.lua",
}
local CHECK_INTERVAL = 1

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
local IsInRequiredGroup = false
local HasCheckedGroup = false

-- Function to check if player is in required group
local function checkGroupMembership()
    if HasCheckedGroup then return IsInRequiredGroup end
    
    local success, result = pcall(function()
        -- Try to get player groups
        local groups = player:GetGroups()
        for _, group in ipairs(groups) do
            if group.Id == REQUIRED_GROUP_ID then
                IsInRequiredGroup = true
                return true
            end
        end
        return false
    end)
    
    if not success then
        -- Alternative method for executors that might block GetGroups
        IsInRequiredGroup = true  -- Allow access for executors
        print("[RSQ] Group check failed, allowing access for executor")
    end
    
    HasCheckedGroup = true
    return IsInRequiredGroup
end

-- Function to fetch data from JSONBin
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
                print("[RSQ] Loaded " .. #GamesList .. " games from JSONBin")
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

-- Function to show SythicsMerch purchase prompt before execution
local function showSythicsMerchPrompt(callback)
    -- Create a blocking prompt that requires response
    local promptGui = Instance.new("ScreenGui", CoreGui)
    promptGui.Name = "RSQ_SythicsMerch_Prompt_Blocking"
    promptGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    promptGui.ResetOnSpawn = false
    
    -- Overlay that blocks all other interactions
    local overlay = Instance.new("Frame", promptGui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    
    -- Main container
    local mainContainer = Instance.new("Frame", promptGui)
    mainContainer.Size = UDim2.new(0, 450, 0, 450)
    mainContainer.Position = UDim2.new(0.5, -225, 0.5, -225)
    mainContainer.BackgroundColor3 = COLOR_PALETTE.dark.bg2
    mainContainer.BackgroundTransparency = 0.1
    mainContainer.BorderSizePixel = 0
    local mainCorner = Instance.new("UICorner", mainContainer)
    mainCorner.CornerRadius = UDim.new(0, 20)
    
    -- Glow effect
    local glow = Instance.new("Frame", mainContainer)
    glow.Size = UDim2.new(1, 20, 1, 20)
    glow.Position = UDim2.new(0, -10, 0, -10)
    glow.BackgroundColor3 = COLOR_PALETTE.secondary
    glow.BackgroundTransparency = 0.9
    glow.BorderSizePixel = 0
    glow.ZIndex = -1
    Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 20)
    
    -- Border with pulsing animation
    local border = Instance.new("UIStroke", mainContainer)
    border.Color = COLOR_PALETTE.secondary
    border.Thickness = 3
    border.Transparency = 0
    
    -- Pulse animation
    task.spawn(function()
        while mainContainer.Parent do
            TweenService:Create(border, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0.5
            }):Play()
            task.wait(1)
            TweenService:Create(border, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = 0
            }):Play()
            task.wait(1)
        end
    end)
    
    -- Title bar
    local titleBar = Instance.new("Frame", mainContainer)
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = COLOR_PALETTE.dark.bg4
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 20, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.Text = "✨ SUPPORT THE DEVELOPER ✨"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = COLOR_PALETTE.secondary
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Content area
    local contentFrame = Instance.new("Frame", mainContainer)
    contentFrame.Size = UDim2.new(1, -30, 1, -130)
    contentFrame.Position = UDim2.new(0, 15, 0, 60)
    contentFrame.BackgroundTransparency = 1
    
    -- Premium icon
    local icon = Instance.new("TextLabel", contentFrame)
    icon.Size = UDim2.new(1, 0, 0, 100)
    icon.Text = "👕"
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 80
    icon.TextColor3 = COLOR_PALETTE.secondary
    icon.BackgroundTransparency = 1
    
    -- Product name
    local productName = Instance.new("TextLabel", contentFrame)
    productName.Size = UDim2.new(1, 0, 0, 50)
    productName.Position = UDim2.new(0, 0, 0, 100)
    productName.Text = "SYTHICSMERCH"
    productName.Font = Enum.Font.GothamBold
    productName.TextSize = 32
    productName.TextColor3 = COLOR_PALETTE.light.text
    productName.BackgroundTransparency = 1
    
    -- Price tag
    local priceTag = Instance.new("Frame", contentFrame)
    priceTag.Size = UDim2.new(0, 150, 0, 50)
    priceTag.Position = UDim2.new(0.5, -75, 0, 150)
    priceTag.BackgroundColor3 = COLOR_PALETTE.secondary
    priceTag.BackgroundTransparency = 0.2
    priceTag.BorderSizePixel = 0
    Instance.new("UICorner", priceTag).CornerRadius = UDim.new(0, 12)
    
    local priceText = Instance.new("TextLabel", priceTag)
    priceText.Size = UDim2.new(1, 0, 1, 0)
    priceText.Text = "🪙 5 ROBUX"
    priceText.Font = Enum.Font.GothamBold
    priceText.TextSize = 20
    priceText.TextColor3 = COLOR_PALETTE.light.text
    priceText.BackgroundTransparency = 1
    
    -- Description
    local description = Instance.new("TextLabel", contentFrame)
    description.Size = UDim2.new(1, 0, 0, 120)
    description.Position = UDim2.new(0, 0, 0, 210)
    description.Text = "🔥 Get SythicsMerch for just 5 Robux!\n\n✅ Premium Support\n✅ Exclusive Features\n✅ Early Access to Scripts\n✅ Developer Badge\n✅ Custom Requests"
    description.Font = Enum.Font.Gotham
    description.TextSize = 14
    description.TextColor3 = COLOR_PALETTE.light.subtext
    description.BackgroundTransparency = 1
    description.TextWrapped = true
    
    -- Buttons container
    local buttonContainer = Instance.new("Frame", mainContainer)
    buttonContainer.Size = UDim2.new(1, -20, 0, 60)
    buttonContainer.Position = UDim2.new(0, 10, 1, -70)
    buttonContainer.BackgroundTransparency = 1
    
    -- Buy button
    local buyBtn = Instance.new("TextButton", buttonContainer)
    buyBtn.Size = UDim2.new(0.48, -5, 1, 0)
    buyBtn.Position = UDim2.new(0, 0, 0, 0)
    buyBtn.Text = "🛒 BUY NOW"
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.TextSize = 16
    buyBtn.TextColor3 = COLOR_PALETTE.light.text
    buyBtn.BackgroundColor3 = COLOR_PALETTE.success
    buyBtn.BackgroundTransparency = 0.2
    buyBtn.BorderSizePixel = 0
    Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 10)
    
    -- Continue without buying button
    local continueBtn = Instance.new("TextButton", buttonContainer)
    continueBtn.Size = UDim2.new(0.48, -5, 1, 0)
    continueBtn.Position = UDim2.new(0.52, 5, 0, 0)
    continueBtn.Text = "▶️ CONTINUE"
    continueBtn.Font = Enum.Font.GothamBold
    continueBtn.TextSize = 16
    continueBtn.TextColor3 = COLOR_PALETTE.light.text
    continueBtn.BackgroundColor3 = COLOR_PALETTE.warning
    continueBtn.BackgroundTransparency = 0.2
    continueBtn.BorderSizePixel = 0
    Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0, 10)
    
    -- Button hover effects
    buyBtn.MouseEnter:Connect(function()
        TweenService:Create(buyBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0,
            Size = UDim2.new(0.48, -1, 1.1, 0)
        }):Play()
    end)
    
    buyBtn.MouseLeave:Connect(function()
        TweenService:Create(buyBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.2,
            Size = UDim2.new(0.48, -5, 1, 0)
        }):Play()
    end)
    
    continueBtn.MouseEnter:Connect(function()
        TweenService:Create(continueBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0,
            Size = UDim2.new(0.48, -1, 1.1, 0)
        }):Play()
    end)
    
    continueBtn.MouseLeave:Connect(function()
        TweenService:Create(continueBtn, TweenInfo.new(0.2), {
            BackgroundTransparency = 0.2,
            Size = UDim2.new(0.48, -5, 1, 0)
        }):Play()
    end)
    
    -- Button events
    local choiceMade = false
    
    buyBtn.MouseButton1Click:Connect(function()
        if choiceMade then return end
        choiceMade = true
        
        TweenService:Create(mainContainer, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -225, 1.5, 0),
            BackgroundTransparency = 1
        }):Play()
        
        task.delay(0.3, function()
            promptGui:Destroy()
            createNotify("Opening SythicsMerch purchase...", COLOR_PALETTE.success)
            
            -- Open marketplace for purchase
            pcall(function()
                MarketplaceService:PromptGamePassPurchase(player, SYTHICSMERCH_GAMEPASS_ID)
            end)
            
            -- Execute callback
            if callback then
                callback()
            end
        end)
    end)
    
    continueBtn.MouseButton1Click:Connect(function()
        if choiceMade then return end
        choiceMade = true
        
        TweenService:Create(mainContainer, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -225, -0.5, 0),
            BackgroundTransparency = 1
        }):Play()
        
        task.delay(0.3, function()
            promptGui:Destroy()
            createNotify("Continuing without purchase", COLOR_PALETTE.warning)
            
            -- Execute callback
            if callback then
                callback()
            end
        end)
    end)
    
    -- Entry animation
    mainContainer.Position = UDim2.new(0.5, -225, -0.5, 0)
    TweenService:Create(mainContainer, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -225, 0.5, -225),
        BackgroundTransparency = 0.1
    }):Play()
    
    -- This prompt blocks until a choice is made
    return promptGui
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
        -- Check group requirement first
        if not checkGroupMembership() then
            createNotify("❌ Join group " .. REQUIRED_GROUP_ID .. " to access!", COLOR_PALETTE.danger)
            return
        end
        
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
        TweenService:Create(button, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 55, 0, 55),
            BackgroundTransparency = 0
        }):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 50, 0, 50),
            BackgroundTransparency = 0.2
        }):Play()
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

-- Function to show keybox for scripts
local function showKeyboxForScript(scriptIndex, gameId)
    -- Fetch fresh data from JSONBin
    local data = fetchDataWithRetry()
    if not data or not data.games then
        createNotify("❌ Failed to fetch game data", COLOR_PALETTE.danger)
        return
    end
    
    -- Find the game
    local game = nil
    for _, g in ipairs(data.games) do
        if tostring(g.id) == tostring(gameId) then
            game = g
            break
        end
    end
    
    if not game or not game.scripts or not game.scripts[scriptIndex + 1] then
        createNotify("❌ Script not found", COLOR_PALETTE.danger)
        return
    end
    
    local scriptData = game.scripts[scriptIndex + 1]
    
    -- Check if script has keys
    if not scriptData.keys or #scriptData.keys == 0 then
        createNotify("❌ No keys available for this script", COLOR_PALETTE.warning)
        return
    end
    
    -- Create keybox GUI
    local keyboxGui = Instance.new("ScreenGui", CoreGui)
    keyboxGui.Name = "RSQ_Keybox_" .. tostring(math.random(1, 1000))
    keyboxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Overlay
    local overlay = Instance.new("Frame", keyboxGui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    
    -- Main container
    local mainContainer = Instance.new("Frame", keyboxGui)
    mainContainer.Size = UDim2.new(0, 450, 0, 350)
    mainContainer.Position = UDim2.new(0.5, -225, 0.5, -175)
    mainContainer.BackgroundColor3 = COLOR_PALETTE.dark.bg2
    mainContainer.BackgroundTransparency = 0.1
    mainContainer.BorderSizePixel = 0
    local mainCorner = Instance.new("UICorner", mainContainer)
    mainCorner.CornerRadius = UDim.new(0, 20)
    
    -- Title bar
    local titleBar = Instance.new("Frame", mainContainer)
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = COLOR_PALETTE.dark.bg4
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 20, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.Text = "🔑 Keys - " .. scriptData.name
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = COLOR_PALETTE.warning
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close button
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = COLOR_PALETTE.light.text
    closeBtn.BackgroundColor3 = COLOR_PALETTE.danger
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    
    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(mainContainer, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -225, -0.5, 0),
            BackgroundTransparency = 1
        }):Play()
        task.delay(0.3, function()
            keyboxGui:Destroy()
        end)
    end)
    
    -- Content area
    local contentFrame = Instance.new("ScrollingFrame", mainContainer)
    contentFrame.Size = UDim2.new(1, -20, 1, -60)
    contentFrame.Position = UDim2.new(0, 10, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ScrollBarThickness = 4
    contentFrame.ScrollBarImageColor3 = COLOR_PALETTE.primary
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    -- Layout for keys
    local keysLayout = Instance.new("UIListLayout", contentFrame)
    keysLayout.Padding = UDim.new(0, 10)
    keysLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    -- Add each key
    local totalHeight = 0
    for keyIndex, keyData in ipairs(scriptData.keys) do
        if keyData and keyData.name and keyData.value then
            -- Key item container
            local keyItem = Instance.new("Frame", contentFrame)
            keyItem.Size = UDim2.new(1, 0, 0, 80)
            keyItem.BackgroundColor3 = COLOR_PALETTE.dark.bg4
            keyItem.BackgroundTransparency = 0.2
            keyItem.BorderSizePixel = 0
            keyItem.LayoutOrder = keyIndex
            Instance.new("UICorner", keyItem).CornerRadius = UDim.new(0, 10)
            
            -- Key name
            local keyName = Instance.new("TextLabel", keyItem)
            keyName.Size = UDim2.new(1, -20, 0, 25)
            keyName.Position = UDim2.new(0, 10, 0, 5)
            keyName.Text = keyData.name
            keyName.Font = Enum.Font.GothamBold
            keyName.TextSize = 13
            keyName.TextColor3 = COLOR_PALETTE.warning
            keyName.BackgroundTransparency = 1
            keyName.TextXAlignment = Enum.TextXAlignment.Left
            
            -- Key value (hidden by default)
            local keyValue = Instance.new("TextBox", keyItem)
            keyValue.Size = UDim2.new(0.7, -40, 0, 30)
            keyValue.Position = UDim2.new(0, 10, 0, 35)
            keyValue.Text = "••••••••••••••••"
            keyValue.Font = Enum.Font.Gotham
            keyValue.TextSize = 12
            keyValue.TextColor3 = COLOR_PALETTE.light.subtext
            keyValue.BackgroundColor3 = COLOR_PALETTE.dark.bg3
            keyValue.BackgroundTransparency = 0.1
            keyValue.BorderSizePixel = 0
            keyValue.ClearTextOnFocus = false
            Instance.new("UICorner", keyValue).CornerRadius = UDim.new(0, 6)
            
            -- Show/Hide toggle button
            local toggleBtn = Instance.new("TextButton", keyItem)
            toggleBtn.Size = UDim2.new(0, 60, 0, 30)
            toggleBtn.Position = UDim2.new(0.7, -20, 0, 35)
            toggleBtn.Text = "👁️ Show"
            toggleBtn.Font = Enum.Font.GothamBold
            toggleBtn.TextSize = 11
            toggleBtn.TextColor3 = COLOR_PALETTE.light.text
            toggleBtn.BackgroundColor3 = COLOR_PALETTE.primary
            toggleBtn.BackgroundTransparency = 0.2
            toggleBtn.BorderSizePixel = 0
            Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)
            
            local isHidden = true
            toggleBtn.MouseButton1Click:Connect(function()
                if isHidden then
                    keyValue.Text = keyData.value
                    toggleBtn.Text = "🔒 Hide"
                    toggleBtn.BackgroundColor3 = COLOR_PALETTE.success
                else
                    keyValue.Text = "••••••••••••••••"
                    toggleBtn.Text = "👁️ Show"
                    toggleBtn.BackgroundColor3 = COLOR_PALETTE.primary
                end
                isHidden = not isHidden
            end)
            
            -- Copy button
            local copyBtn = Instance.new("TextButton", keyItem)
            copyBtn.Size = UDim2.new(0, 70, 0, 30)
            copyBtn.Position = UDim2.new(1, -80, 0, 35)
            copyBtn.Text = "📋 Copy"
            copyBtn.Font = Enum.Font.GothamBold
            copyBtn.TextSize = 11
            copyBtn.TextColor3 = COLOR_PALETTE.light.text
            copyBtn.BackgroundColor3 = COLOR_PALETTE.success
            copyBtn.BackgroundTransparency = 0.2
            copyBtn.BorderSizePixel = 0
            Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)
            
            copyBtn.MouseButton1Click:Connect(function()
                setclipboard(keyData.value)
                createNotify("✅ Key copied to clipboard", COLOR_PALETTE.success)
            end)
            
            totalHeight = totalHeight + 90
        end
    end
    
    -- Set canvas size
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
    
    -- Entry animation
    mainContainer.Position = UDim2.new(0.5, -225, -0.5, 0)
    TweenService:Create(mainContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -225, 0.5, -175),
        BackgroundTransparency = 0.1
    }):Play()
end

-- Function to show scripts for a specific game (FIXED VERSION)
local function showGameScripts(gameData)
    if not gameData or not gameData.id then
        createNotify("❌ Invalid game data", COLOR_PALETTE.danger)
        return
    end
    
    -- Fetch fresh data from JSONBin
    local data = fetchDataWithRetry()
    if not data or not data.games then
        createNotify("❌ Failed to fetch game data", COLOR_PALETTE.danger)
        return
    end
    
    -- Find the game in fresh data
    local foundGame = nil
    for _, g in ipairs(data.games) do
        if tostring(g.id) == tostring(gameData.id) then
            foundGame = g
            break
        end
    end
    
    if not foundGame then
        createNotify("❌ Game not found in database", COLOR_PALETTE.danger)
        return
    end
    
    local scripts = foundGame.scripts or {}
    print("[RSQ] Found " .. #scripts .. " scripts for game: " .. foundGame.name)
    
    -- Create scripts GUI
    if CurrentGUI and CurrentGUI:FindFirstChild("RSQ_ScriptsGUI") then
        CurrentGUI.RSQ_ScriptsGUI:Destroy()
    end
    
    local scriptsGui = Instance.new("ScreenGui", CoreGui)
    scriptsGui.Name = "RSQ_ScriptsGUI"
    scriptsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Overlay
    local overlay = Instance.new("Frame", scriptsGui)
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.7
    overlay.BorderSizePixel = 0
    
    -- Main container
    local mainContainer = Instance.new("Frame", scriptsGui)
    mainContainer.Size = UDim2.new(0, 500, 0, 500)
    mainContainer.Position = UDim2.new(0.5, -250, 0.5, -250)
    mainContainer.BackgroundColor3 = COLOR_PALETTE.dark.bg2
    mainContainer.BackgroundTransparency = 0.1
    mainContainer.BorderSizePixel = 0
    local mainCorner = Instance.new("UICorner", mainContainer)
    mainCorner.CornerRadius = UDim.new(0, 20)
    
    -- Make draggable
    makeDraggable(mainContainer, mainContainer)
    
    -- Title bar
    local titleBar = Instance.new("Frame", mainContainer)
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = COLOR_PALETTE.dark.bg4
    titleBar.BackgroundTransparency = 0.3
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 20, 0, 0)
    
    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.Text = "📜 Scripts - " .. foundGame.name
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = COLOR_PALETTE.primary
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close button
    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0.5, -15)
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = COLOR_PALETTE.light.text
    closeBtn.BackgroundColor3 = COLOR_PALETTE.danger
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel = 0
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    
    closeBtn.MouseButton1Click:Connect(function()
        TweenService:Create(mainContainer, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -250, 1.5, 0),
            BackgroundTransparency = 1
        }):Play()
        task.delay(0.3, function()
            scriptsGui:Destroy()
        end)
    end)
    
    -- Back button
    local backBtn = Instance.new("TextButton", titleBar)
    backBtn.Size = UDim2.new(0, 80, 0, 30)
    backBtn.Position = UDim2.new(1, -120, 0.5, -15)
    backBtn.Text = "← Back"
    backBtn.Font = Enum.Font.GothamBold
    backBtn.TextSize = 12
    backBtn.TextColor3 = COLOR_PALETTE.light.text
    backBtn.BackgroundColor3 = COLOR_PALETTE.secondary
    backBtn.BackgroundTransparency = 0.2
    backBtn.BorderSizePixel = 0
    Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 8)
    
    backBtn.MouseButton1Click:Connect(function()
        TweenService:Create(mainContainer, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, -250, 1.5, 0),
            BackgroundTransparency = 1
        }):Play()
        task.delay(0.3, function()
            scriptsGui:Destroy()
            showAdvancedGamesGUI()  -- Return to games list
        end)
    end)
    
    -- Content area
    local contentFrame = Instance.new("ScrollingFrame", mainContainer)
    contentFrame.Size = UDim2.new(1, -20, 1, -60)
    contentFrame.Position = UDim2.new(0, 10, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ScrollBarThickness = 6
    contentFrame.ScrollBarImageColor3 = COLOR_PALETTE.primary
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    -- Layout for scripts
    local scriptsLayout = Instance.new("UIListLayout", contentFrame)
    scriptsLayout.Padding = UDim.new(0, 12)
    scriptsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    -- Add each script
    local totalHeight = 0
    
    if #scripts == 0 then
        -- No scripts message
        local emptyLabel = Instance.new("TextLabel", contentFrame)
        emptyLabel.Size = UDim2.new(1, 0, 0, 100)
        emptyLabel.Text = "📭 No scripts available for this game.\n\nAdd scripts through the admin panel."
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextSize = 14
        emptyLabel.TextColor3 = COLOR_PALETTE.light.subtext
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.TextWrapped = true
        emptyLabel.TextYAlignment = Enum.TextYAlignment.Center
        emptyLabel.LayoutOrder = 1
        totalHeight = 120
    else
        for scriptIndex, scriptData in ipairs(scripts) do
            if scriptData and scriptData.name and scriptData.url then
                -- Script card
                local scriptCard = Instance.new("Frame", contentFrame)
                scriptCard.Size = UDim2.new(1, 0, 0, 100)
                scriptCard.BackgroundColor3 = COLOR_PALETTE.dark.bg4
                scriptCard.BackgroundTransparency = 0.2
                scriptCard.BorderSizePixel = 0
                scriptCard.LayoutOrder = scriptIndex
                Instance.new("UICorner", scriptCard).CornerRadius = UDim.new(0, 10)
                
                -- Border
                local cardBorder = Instance.new("UIStroke", scriptCard)
                cardBorder.Color = COLOR_PALETTE.light.border
                cardBorder.Thickness = 1
                cardBorder.Transparency = 0.3
                
                -- Script name
                local scriptName = Instance.new("TextLabel", scriptCard)
                scriptName.Size = UDim2.new(1, -20, 0, 30)
                scriptName.Position = UDim2.new(0, 10, 0, 5)
                scriptName.Text = scriptData.name
                scriptName.Font = Enum.Font.GothamBold
                scriptName.TextSize = 15
                scriptName.TextColor3 = COLOR_PALETTE.primary
                scriptName.BackgroundTransparency = 1
                scriptName.TextXAlignment = Enum.TextXAlignment.Left
                
                -- Script URL (full display)
                local urlText = Instance.new("TextLabel", scriptCard)
                urlText.Size = UDim2.new(1, -20, 0, 40)
                urlText.Position = UDim2.new(0, 10, 0, 35)
                urlText.Text = "🔗 " .. scriptData.url
                urlText.Font = Enum.Font.Gotham
                urlText.TextSize = 12
                urlText.TextColor3 = COLOR_PALETTE.light.subtext
                urlText.BackgroundTransparency = 1
                urlText.TextXAlignment = Enum.TextXAlignment.Left
                urlText.TextWrapped = true
                urlText.TextYAlignment = Enum.TextYAlignment.Top
                
                -- Copy button
                local copyBtn = Instance.new("TextButton", scriptCard)
                copyBtn.Size = UDim2.new(0, 80, 0, 30)
                copyBtn.Position = UDim2.new(1, -90, 1, -40)
                copyBtn.Text = "📋 Copy URL"
                copyBtn.Font = Enum.Font.GothamBold
                copyBtn.TextSize = 12
                copyBtn.TextColor3 = COLOR_PALETTE.light.text
                copyBtn.BackgroundColor3 = COLOR_PALETTE.success
                copyBtn.BackgroundTransparency = 0.2
                copyBtn.BorderSizePixel = 0
                Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)
                
                copyBtn.MouseButton1Click:Connect(function()
                    setclipboard(scriptData.url)
                    createNotify("✅ Script URL copied to clipboard!", COLOR_PALETTE.success)
                end)
                
                -- Execute button with SythicsMerch prompt
                local executeBtn = Instance.new("TextButton", scriptCard)
                executeBtn.Size = UDim2.new(0, 80, 0, 30)
                executeBtn.Position = UDim2.new(1, -180, 1, -40)
                executeBtn.Text = "⚡ Execute"
                executeBtn.Font = Enum.Font.GothamBold
                executeBtn.TextSize = 12
                executeBtn.TextColor3 = COLOR_PALETTE.light.text
                executeBtn.BackgroundColor3 = COLOR_PALETTE.warning
                executeBtn.BackgroundTransparency = 0.2
                executeBtn.BorderSizePixel = 0
                Instance.new("UICorner", executeBtn).CornerRadius = UDim.new(0, 6)
                
                executeBtn.MouseButton1Click:Connect(function()
                    -- Check if we're in the right game
                    if tostring(foundGame.id) == tostring(PLACE_ID) then
                        -- Show SythicsMerch purchase prompt before execution
                        showSythicsMerchPrompt(function()
                            -- This callback runs after user makes a choice
                            createNotify("Executing script: " .. scriptData.name, COLOR_PALETTE.success)
                            
                            -- Execute the script
                            task.spawn(function()
                                local success, errorMsg = pcall(function()
                                    local scriptContent = game:HttpGet(scriptData.url)
                                    loadstring(scriptContent)()
                                end)
                                
                                if not success then
                                    createNotify("❌ Script failed: " .. tostring(errorMsg), COLOR_PALETTE.danger)
                                end
                            end)
                        end)
                    else
                        createNotify("❌ Wrong game! Teleport required", COLOR_PALETTE.warning)
                    end
                end)
                
                -- Show keys button if script has keys
                if scriptData.keys and #scriptData.keys > 0 then
                    local keysBtn = Instance.new("TextButton", scriptCard)
                    keysBtn.Size = UDim2.new(0, 80, 0, 30)
                    keysBtn.Position = UDim2.new(1, -270, 1, -40)
                    keysBtn.Text = "🔑 " .. #scriptData.keys .. " Keys"
                    keysBtn.Font = Enum.Font.GothamBold
                    keysBtn.TextSize = 12
                    keysBtn.TextColor3 = COLOR_PALETTE.light.text
                    keysBtn.BackgroundColor3 = COLOR_PALETTE.accent
                    keysBtn.BackgroundTransparency = 0.2
                    keysBtn.BorderSizePixel = 0
                    Instance.new("UICorner", keysBtn).CornerRadius = UDim.new(0, 6)
                    
                    keysBtn.MouseButton1Click:Connect(function()
                        showKeyboxForScript(scriptIndex - 1, foundGame.id)
                    end)
                end
                
                totalHeight = totalHeight + 112
            end
        end
    end
    
    -- Set canvas size
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
    
    -- Entry animation
    mainContainer.Position = UDim2.new(0.5, -250, -0.5, 0)
    TweenService:Create(mainContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -250, 0.5, -250),
        BackgroundTransparency = 0.1
    }):Play()
end

--==================================================--
-- ADVANCED GAMES GUI (REWRITTEN)
--==================================================--
local function showAdvancedGamesGUI()
    -- Check group requirement first
    if not checkGroupMembership() then
        createNotify("❌ Join group " .. REQUIRED_GROUP_ID .. " to access!", COLOR_PALETTE.danger)
        return
    end
    
    if CurrentGUI and CurrentGUI.Parent then
        CurrentGUI:Destroy()
        CurrentGUI = nil
    end
    
    IsGuiOpen = true
    
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

    -- Main container
    local mainFrame = Instance.new("Frame", gui)
    mainFrame.Size = UDim2.new(0, 400, 0, 450)
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

    -- Games container
    local gamesContainer = Instance.new("Frame", contentFrame)
    gamesContainer.Size = UDim2.new(1, 0, 1, 0)
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
    
    -- Function to create game card
    local function createGameCard(gameData, parent)
        local card = Instance.new("Frame", parent)
        card.Size = UDim2.new(1, 0, 0, 70)
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
        
        -- Button events (FIXED - properly passes game data)
        scriptsBtn.MouseButton1Click:Connect(function()
            print("[RSQ] View Scripts clicked for:", gameData.name)
            -- Store current GUI reference before destroying
            local currentGuiRef = CurrentGUI
            
            -- Close current games GUI
            if currentGuiRef then
                currentGuiRef:Destroy()
                CurrentGUI = nil
            end
            
            -- Show scripts GUI
            showGameScripts(gameData)
        end)
        
        -- Hover effects
        card.MouseEnter:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundTransparency = 0.1
            }):Play()
            TweenService:Create(border, TweenInfo.new(0.2), {
                Transparency = 0
            }):Play()
        end)
        
        card.MouseLeave:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundTransparency = 0.2
            }):Play()
            TweenService:Create(border, TweenInfo.new(0.2), {
                Transparency = 0.5
            }):Play()
        end)
        
        return card
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
    refreshBtn.Position = UDim2.new(1, -110, 1, -40)
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
        fetchDataWithRetry()
        task.wait(0.5)
        loadGames()
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
    -- Check group requirement first
    if not checkGroupMembership() then
        createNotify("❌ Join group " .. REQUIRED_GROUP_ID .. " to access!", COLOR_PALETTE.danger)
        return
    end
    
    if CurrentGUI and CurrentGUI.Parent then
        CurrentGUI:Destroy()
        CurrentGUI = nil
    end
    
    IsGuiOpen = true
    
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
        local inputKey = string.trim(input.Text)
        if inputKey == "" then return end

        status.Text = "⚡ Checking..."
        status.TextColor3 = COLOR_PALETTE.primary
        
        -- Simple validation for now
        if inputKey:match("^RSQ%-[A-Z0-9]+$") then
            CurrentKey = inputKey
            KeyActive = true
            status.Text = "✅ Success! Loading..."
            status.TextColor3 = COLOR_PALETTE.success
            
            TweenService:Create(card, TweenInfo.new(0.3), {BackgroundTransparency = 1, Size = UDim2.new(0,0,0,0)}):Play()
            task.delay(0.3, function() 
                gui:Destroy() 
                CurrentGUI = nil
                IsGuiOpen = false
                showAdvancedGamesGUI()
            end)
        else
            status.Text = "❌ Invalid key format"
            status.TextColor3 = COLOR_PALETTE.danger
        end
    end)

    getKey.MouseButton1Click:Connect(function()
        setclipboard(GET_KEY_URL)
        status.Text = "📋 Link Copied!"
        status.TextColor3 = COLOR_PALETTE.accent
    end)
end

--==================================================--
-- INITIALIZE WITH GROUP CHECK
--==================================================--
task.spawn(function()
    -- Check group membership first
    if checkGroupMembership() then
        createOpenButton()
        createNotify("✅ Welcome to RSQ Elite!", COLOR_PALETTE.success)
        showKeyGUI()
    else
        -- Show notification about group requirement
        local notification = Instance.new("ScreenGui", CoreGui)
        notification.Name = "RSQ_GroupRequirement"
        notification.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        
        local frame = Instance.new("Frame", notification)
        frame.Size = UDim2.new(0, 400, 0, 150)
        frame.Position = UDim2.new(0.5, -200, 0.5, -75)
        frame.BackgroundColor3 = COLOR_PALETTE.dark.bg2
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
        
        local title = Instance.new("TextLabel", frame)
        title.Size = UDim2.new(1, -20, 0, 40)
        title.Position = UDim2.new(0, 10, 0, 10)
        title.Text = "⚠️ GROUP REQUIRED ⚠️"
        title.Font = Enum.Font.GothamBold
        title.TextSize = 18
        title.TextColor3 = COLOR_PALETTE.warning
        title.BackgroundTransparency = 1
        
        local message = Instance.new("TextLabel", frame)
        message.Size = UDim2.new(1, -20, 0, 60)
        message.Position = UDim2.new(0, 10, 0, 50)
        message.Text = "Join group " .. REQUIRED_GROUP_ID .. " to access RSQ Elite!\n\nRe-execute the script after joining."
        message.Font = Enum.Font.Gotham
        message.TextSize = 14
        message.TextColor3 = COLOR_PALETTE.light.text
        message.BackgroundTransparency = 1
        message.TextWrapped = true
        
        local copyBtn = Instance.new("TextButton", frame)
        copyBtn.Size = UDim2.new(0, 150, 0, 35)
        copyBtn.Position = UDim2.new(0.5, -75, 1, -45)
        copyBtn.Text = "📋 Copy Group Link"
        copyBtn.Font = Enum.Font.GothamBold
        copyBtn.TextSize = 13
        copyBtn.TextColor3 = COLOR_PALETTE.light.text
        copyBtn.BackgroundColor3 = COLOR_PALETTE.primary
        copyBtn.BackgroundTransparency = 0.2
        copyBtn.BorderSizePixel = 0
        Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 8)
        
        copyBtn.MouseButton1Click:Connect(function()
            setclipboard("https://www.roblox.com/groups/" .. REQUIRED_GROUP_ID)
            copyBtn.Text = "✅ Copied!"
            task.wait(1)
            copyBtn.Text = "📋 Copy Group Link"
        end)
        
        -- Animation
        frame.BackgroundTransparency = 1
        TweenService:Create(frame, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
    end
end)
