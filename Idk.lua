--==================================================
-- FULL ENHANCED STOCK SCRIPT - COMPLETE EDITION
-- Auto-syncs Sell TextBox with Statement.Shares
-- Value label shows FAKE SHARES × Price
-- Net Worth = Value × 5
-- Changes Rank #1 names to "NayScripts"
-- No clicking or typing required!
-- FOR ROBLOX STUDIO TESTING ONLY
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

--==================================================
-- FLAGS
--==================================================
local isProcessing = false
local isSelling = false
local processing2 = false  -- For sell processing state
local success2 = false     -- For sell success state
local pendingSharesToAdd = 0
local pendingSharesToRemove = 0
local originalSharesValue = 0
local forcedSharesValue = nil
local actualPointsValue = nil
local loopActive = true

-- Flags to distinguish between game updates and UI updates
local isGameUpdating = false      -- When the game/server is updating points
local isUIUpdating = false        -- When our UI updater is changing points
local pendingGameUpdate = false   -- When a game update is pending

-- Make points value accessible globally for other scripts
_G.actualPointsValue = nil

-- Variables to store sell transaction data
local pendingSellShares = 0
local pendingSellPrice = 0

-- Track purchase price for price change calculation
local lastBuyPrice = nil

--==================================================
-- SAFE WAIT
--==================================================

local function safeWait(parent, childName, timeout)
	local obj = parent:WaitForChild(childName, timeout or 15)
	if obj then
		print("✅ Found:", obj:GetFullName())
	else
		warn("❌ Missing:", childName, "inside", parent.Name)
	end
	return obj
end

--==================================================
-- REMOTE BLOCKER
--==================================================

local rf = ReplicatedStorage:FindFirstChild("Packages")
if rf then
	rf = rf:FindFirstChild("_Index")
	if rf then
		rf = rf:FindFirstChild("sleitnick_knit@1.7.0")
		if rf then
			rf = rf:FindFirstChild("knit")
			if rf then
				rf = rf:FindFirstChild("Services")
				if rf then
					rf = rf:FindFirstChild("Stocks")
					if rf then
						rf = rf:FindFirstChild("RF")
						if rf then
							rf = rf:FindFirstChild("MarketBuyPoints")
						end
					end
				end
			end
		end
	end
end

if rf then
	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local args = {...}
		local method = getnamecallmethod()
		if self == rf and method == "InvokeServer" then
			print("🚫 Blocked MarketBuyPoints:", unpack(args))
			return nil
		end
		return oldNamecall(self, ...)
	end)
	print("✅ Remote blocker enabled")
end

--==================================================
-- GET UI
--==================================================

local playerGui = safeWait(player, "PlayerGui")
if not playerGui then return end

local main = safeWait(playerGui, "Main")
if not main then return end

local invest = safeWait(main, "Invest")
if not invest then return end

local stock = safeWait(invest, "Stock")
if not stock then return end

local trading = safeWait(stock, "Trading")
if not trading then return end

local interface = safeWait(trading, "Interface")
if not interface then return end

--==================================================
-- GET STATEMENT AND SHARES LABEL & VALUE LABEL
--==================================================

local statement = safeWait(interface, "Statement")
if not statement then return end

local sharesLabel = safeWait(statement, "Shares")
if not sharesLabel then
	warn("⚠️ Statement.Shares not found")
end

print("✅ Shares Label found:", sharesLabel and sharesLabel.Text or "N/A")

-- Find the Value label in Statement
local valueLabel = nil
for _, v in ipairs(statement:GetDescendants()) do
	if v:IsA("TextLabel") and (v.Name == "Value" or string.find(v.Name:lower(), "value")) then
		valueLabel = v
		print("✅ Value Label found:", v:GetFullName())
		break
	end
end

if not valueLabel then
	warn("⚠️ Statement.Value not found")
end

--==================================================
-- GET POINTS LABEL
--==================================================

local pointsFrame = safeWait(stock, "Points")
if not pointsFrame then return end

local pointsLabel = nil
for _, v in ipairs(pointsFrame:GetDescendants()) do
	if v:IsA("TextLabel") then
		pointsLabel = v
		break
	end
end

if not pointsLabel then
	warn("❌ Points label not found")
end

print("✅ Points Label found:", pointsLabel and pointsLabel.Text or "N/A")

--==================================================
-- GET MARKET AND UI ELEMENTS
--==================================================

local market = safeWait(interface, "Market")
if not market then return end

local playerFrame = safeWait(market, "Player")
if not playerFrame then return end

--==================================================
-- GET BUY TEXTBOX (Path: Player.Buy.3.TextBox)
--==================================================

local buy = safeWait(playerFrame, "Buy")
if not buy then return end

local buyFolder3 = safeWait(buy, "3")
if not buyFolder3 then return end

local buyTextbox = safeWait(buyFolder3, "TextBox")
if not buyTextbox then return end

print("✅ Buy TextBox found")

--==================================================
-- GET BUY TOTAL BUTTON (Buy.3.Total.TextButton)
--==================================================

local buyTotalButton = nil
if buyFolder3 then
	for _, v in ipairs(buyFolder3:GetDescendants()) do
		if v:IsA("TextButton") and v.Name == "Total" then
			buyTotalButton = v
			break
		end
	end
end

if buyTotalButton then
	print("✅ Buy Total Button found")
end

--==================================================
-- GET SELL TEXTBOX (Path: Player.Sell.3.TextBox)
--==================================================

local sell = safeWait(playerFrame, "Sell")
if not sell then
	warn("❌ Sell folder not found")
end

local sellTextbox = nil
local sellFolder3 = nil
if sell then
	sellFolder3 = safeWait(sell, "3")
	if sellFolder3 then
		sellTextbox = safeWait(sellFolder3, "TextBox")
		if sellTextbox then
			print("✅ Sell TextBox found")
		end
	end
end

--==================================================
-- GET SELL TOTAL BUTTON (Sell.3.Total.TextButton)
-- LOOKS FOR TEXTBUTTON INSIDE TOTAL FOLDER
--==================================================

local sellTotalButton = nil
if sellFolder3 then
	-- First look for a folder named "Total"
	local totalFolder = sellFolder3:FindFirstChild("Total")
	if totalFolder then
		-- Look for TextButton INSIDE the Total folder
		for _, child in ipairs(totalFolder:GetChildren()) do
			if child:IsA("TextButton") then
				sellTotalButton = child
				break
			end
		end
	end
	
	-- If no button found in Total folder, look for TextButton named Total directly
	if not sellTotalButton then
		for _, v in ipairs(sellFolder3:GetDescendants()) do
			if v:IsA("TextButton") and v.Name == "Total" then
				sellTotalButton = v
				break
			end
		end
	end
end

if sellTotalButton then
	print("✅ Sell Total Button found - will show total Ᵽ value of shares")
	print("   Path: " .. sellTotalButton:GetFullName())
else
	warn("⚠️ Sell Total Button not found!")
end

--==================================================
-- GET PRICE LABEL
--==================================================

local details = safeWait(interface, "Details")
if not details then return end

local priceFrame = safeWait(details, "Price")
if not priceFrame then return end

local priceLabel = safeWait(priceFrame, "TextLabel")
if not priceLabel then return end

print("✅ Price Label:", priceLabel.Text)

--==================================================
-- GET MAX BUTTONS
--==================================================

local buyMaxButton = market:FindFirstChild("MAX")
if buyMaxButton then
	print("✅ Buy MAX button found")
end

local sellMaxButton = nil
if sell then
	sellMaxButton = sell:FindFirstChild("MAX")
	if sellMaxButton then
		print("✅ Sell MAX button found")
	end
end

--==================================================
-- GET RESPONSE AND PROCESSING LABELS (USE GAME'S EXISTING LABELS)
--==================================================

local prompts = safeWait(market, "Prompts")
if not prompts then return end

local confirmations = safeWait(prompts, "Confirmations")
if not confirmations then return end

local responseFrame = safeWait(confirmations, "Response")
if not responseFrame then return end

-- Get the existing Response label (for "Success !")
local responseLabel = safeWait(responseFrame, "Response")
if not responseLabel then return end

-- Get the existing Processing label (game's built-in "Processing..." label)
local processingLabel = responseFrame:FindFirstChild("Processing")
if not processingLabel then
	warn("⚠️ Response.Processing not found, creating fallback")
	processingLabel = Instance.new("TextLabel")
	processingLabel.Name = "Processing"
	processingLabel.Text = "Processing..."
	processingLabel.TextSize = 14
	processingLabel.TextColor3 = Color3.fromRGB(54, 54, 54)
	processingLabel.BackgroundTransparency = 1
	processingLabel.Size = UDim2.new(0.918880403, 0, 0.268368006, 0)
	processingLabel.Position = UDim2.new(0.508249342, 0, 0.445323527, 0)
	processingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	processingLabel.Visible = false
	processingLabel.Parent = responseFrame
else
	print("✅ Found existing Response.Processing label!")
end

local responseOK = safeWait(responseFrame, "OK")

-- Set the Response label color to grey (matching game)
if responseLabel then
	responseLabel.TextColor3 = Color3.fromRGB(54, 54, 54)
end

--==================================================
-- HELPER FUNCTIONS
--==================================================

local function cleanNumber(str)
	if not str then return nil end
	str = tostring(str)
	-- Remove all commas and spaces first
	str = str:gsub(",", "")
	str = str:gsub("%s+", "")
	-- Remove currency symbols and labels
	str = str:gsub("%$", "")
	str = str:gsub("Ᵽ:", "")
	str = str:gsub("Ᵽ", "")
	str = str:gsub("Shares:", "")
	str = str:gsub("Value:", "")
	return tonumber(str)
end

local function formatNumber(num)
	if not num then return "0" end
	local formatted = string.format("%.0f", num)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

local function formatSharesLabel(num)
	return "Shares: " .. formatNumber(math.floor(num))
end

local function formatPointsLabel(points)
	local rounded = math.floor(points + 0.5)
	return "Ᵽ: " .. formatNumber(rounded)
end

local function formatTotalButton(points)
	local rounded = math.floor(points + 0.5)
	return "Ᵽ " .. formatNumber(rounded)
end

--==================================================
-- GET CURRENT VALUES (FIXED NUMBER PARSING)
--==================================================

local function getFakeShares()
	if not sharesLabel then return 0 end
	local text = sharesLabel.Text
	
	-- Remove "Shares:" prefix
	local numberPart = text:gsub("Shares:", ""):gsub("%s+", "")
	-- Remove commas
	numberPart = numberPart:gsub(",", "")
	
	local number = tonumber(numberPart) or 0
	return number
end

local function getCurrentPoints()
	if buyTotalButton then
		local points = cleanNumber(buyTotalButton.Text)
		if points then return points end
	end
	if pointsLabel then
		return cleanNumber(pointsLabel.Text)
	end
	return nil
end

-- FIXED: Properly handles "Ᵽ 100" format with space
local function getCurrentPrice()
	if not priceLabel then return nil end
	local text = priceLabel.Text
	
	-- Remove "Ᵽ" symbol and ALL spaces (including the one after Ᵽ)
	local numberPart = text:gsub("Ᵽ", "")
	numberPart = numberPart:gsub("%s+", "")  -- This removes the space!
	numberPart = numberPart:gsub(":", "")
	numberPart = numberPart:gsub(",", "")
	
	local number = tonumber(numberPart)
	
	-- Debug print occasionally to verify parsing
	if math.random(1, 30) == 1 then
		print("📊 Price parsing - Raw: '" .. text .. "' → Cleaned: '" .. numberPart .. "' → Number: " .. tostring(number))
	end
	
	return number
end

--==================================================
-- UPDATE VALUE LABEL USING FAKE SHARES (FIXED)
--==================================================

local function updateValueLabelWithFakeShares()
	if not valueLabel then 
		-- Try to find it again if missing
		if statement then
			valueLabel = statement:FindFirstChild("Value")
		end
		if not valueLabel then return end
	end
	
	local currentShares = getFakeShares()
	local currentPrice = getCurrentPrice()
	
	if currentShares and currentPrice and currentPrice > 0 then
		local totalValue = currentShares * currentPrice
		local formattedValue = "Value: Ᵽ " .. formatNumber(math.floor(totalValue))
		valueLabel.Text = formattedValue
		if math.random(1, 50) == 1 then
			print("💰 Value Label updated to:", formattedValue, "(", currentShares, "shares ×", currentPrice, "price =", totalValue, ")")
		end
	else
		valueLabel.Text = "Value: Ᵽ 0"
	end
end

--==================================================
-- NET WORTH UPDATER (Value × 5)
--==================================================

local function updateNetWorth()
    -- Wait for leaderstats to exist
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        return
    end
    
    local netWorthStat = leaderstats:FindFirstChild("Net Worth")
    if not netWorthStat then
        return
    end
    
    local currentShares = getFakeShares()
    local currentPrice = getCurrentPrice()
    
    if currentShares and currentPrice and currentPrice > 0 then
        local value = currentShares * currentPrice
        local netWorth = value * 5
        netWorthStat.Value = math.floor(netWorth)
        
        if math.random(1, 50) == 1 then
            print("💰 Net Worth updated: " .. formatNumber(value) .. " × 5 = " .. formatNumber(netWorth))
        end
    else
        netWorthStat.Value = 0
    end
end

-- Start Net Worth updater loop
local function startNetWorthUpdater()
    task.spawn(function()
        print("💰 Starting Net Worth updater (Value × 5)")
        
        -- Wait for leaderstats to be available
        local leaderstats = player:WaitForChild("leaderstats", 10)
        if not leaderstats then
            print("❌ Could not find leaderstats")
            return
        end
        
        local netWorthStat = leaderstats:WaitForChild("Net Worth", 10)
        if not netWorthStat then
            print("❌ Could not find Net Worth stat")
            return
        end
        
        print("✅ Net Worth stat found! Will update with Value × 5")
        
        while loopActive do
            updateNetWorth()
            task.wait(0.5) -- Update twice per second
        end
    end)
end

--==================================================
-- CHANGE ONLY RANK #1 ON ALL LEADERBOARDS
--==================================================

local function changeAllRank1Names()
    local changedCount = 0
    
    local function searchRecursive(instance, depth)
        if depth > 25 then return end
        
        -- Check if this instance has a "Rank" child
        local rankLabel = instance:FindFirstChild("Rank")
        
        if rankLabel and rankLabel:IsA("TextLabel") then
            local rankText = rankLabel.Text
            
            -- ONLY if this is Rank #1
            if rankText == "1" then
                local namLabel = instance:FindFirstChild("Nam")
                
                if namLabel and namLabel:IsA("TextLabel") then
                    local oldText = namLabel.Text
                    
                    -- Change ONLY Rank #1's .Nam Text
                    if oldText ~= "NayScripts" then
                        namLabel.Text = "NayScripts"
                        changedCount = changedCount + 1
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        print("✅ RANK #1 FOUND AND CHANGED!")
                        print("   Path: " .. instance:GetFullName())
                        print("   Old Name: " .. oldText)
                        print("   New Name: " .. namLabel.Text)
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    end
                end
            end
        end
        
        -- Search all children recursively
        for _, child in ipairs(instance:GetChildren()) do
            searchRecursive(child, depth + 1)
        end
    end
    
    -- Start searching from workspace
    searchRecursive(workspace, 0)
    
    if changedCount > 0 then
        print("📊 Total Rank #1 entries changed: " .. changedCount)
    else
        print("❌ No Rank #1 entries found")
    end
    
    return changedCount
end

-- Start Rank #1 changer loop (runs every 5 seconds to catch new leaderboards)
local function startRank1ChangerLoop()
    task.spawn(function()
        print("👑 Starting Rank #1 changer loop (checks every 5 seconds)")
        
        -- Run once immediately after a short delay
        task.wait(3)
        changeAllRank1Names()
        
        -- Then loop to catch any new leaderboards that appear
        while loopActive do
            task.wait(5)
            changeAllRank1Names()
        end
    end)
end

--==================================================
-- FORCE SELL TEXTBOX VALUE (NO CLICKING NEEDED)
--==================================================

local function forceSellTextBoxValue(value)
	if not sellTextbox then
		return false
	end
	
	sellTextbox.Text = tostring(value)
	sellTextbox:CaptureFocus()
	task.wait(0.02)
	sellTextbox:ReleaseFocus()
	
	for i = 1, 3 do
		sellTextbox.Text = tostring(value)
		task.wait(0.01)
	end
	
	return sellTextbox.Text == tostring(value)
end

--==================================================
-- UPDATE BUY TOTAL BUTTON WITH AFFORDABLE COST
--==================================================

local function updateBuyTotalButton()
	if not buyTotalButton then return end
	
	local totalPoints = getCurrentPoints()
	local pricePerShare = getCurrentPrice()
	
	if not totalPoints or not pricePerShare or pricePerShare <= 0 then
		return
	end
	
	local maxSharesRaw = totalPoints / pricePerShare
	local maxShares = math.floor(maxSharesRaw)
	local actualCost = maxShares * pricePerShare
	
	buyTotalButton.Text = formatTotalButton(actualCost)
	
	if math.random(1, 50) == 1 then
		print("💰 Buy Total Button:", actualCost, "points (", maxShares, "shares @", pricePerShare, "each)")
	end
end

--==================================================
-- UPDATE SELL TOTAL BUTTON (Shows total Ᵽ value of shares)
--==================================================

local function updateSellTotalButton()
	if not sellTotalButton then return end
	
	local currentShares = getFakeShares()
	local pricePerShare = getCurrentPrice()
	
	if not currentShares or not pricePerShare or pricePerShare <= 0 or currentShares <= 0 then
		if sellTotalButton then
			sellTotalButton.Text = formatTotalButton(0)
		end
		return
	end
	
	local totalValue = currentShares * pricePerShare
	local formattedValue = formatTotalButton(totalValue)
	
	sellTotalButton.Text = formattedValue
	
	pcall(function()
		sellTotalButton:CaptureFocus()
		task.wait(0.01)
		sellTotalButton:ReleaseFocus()
		sellTotalButton.Text = formattedValue
	end)
	
	if math.random(1, 30) == 1 then
		print("💰 Sell Total Button forced to:", formattedValue, "(", currentShares, "shares @", pricePerShare, "each)")
	end
end

--==================================================
-- UPDATE BUY TEXTBOX WITH MAX AFFORDABLE SHARES
--==================================================

local function updateBuyTextBoxWithMaxAffordable()
	local totalPoints = getCurrentPoints()
	local pricePerShare = getCurrentPrice()
	
	if not totalPoints or not pricePerShare or pricePerShare <= 0 then
		buyTextbox.Text = "0"
		return
	end
	
	local maxShares = math.floor(totalPoints / pricePerShare)
	
	if maxShares <= 0 then
		buyTextbox.Text = "0"
	else
		buyTextbox.Text = tostring(maxShares)
	end
	
	buyTextbox.CursorPosition = #buyTextbox.Text + 1
	
	updateBuyTotalButton()
	
	print("✅ Buy TextBox set to MAX affordable:", maxShares, "shares")
end

--==================================================
-- ENHANCED SELL TEXTBOX LOOP
--==================================================

local function startEnhancedSellTextBoxLoop()
	task.spawn(function()
		print("🔄 Starting ENHANCED Sell TextBox force loop (updates 20x per second!)")
		
		while loopActive do
			if not isProcessing and not processing2 and sellTextbox then
				local fakeShares = getFakeShares()
				local currentSellValue = cleanNumber(sellTextbox.Text) or 0
				
				if currentSellValue ~= fakeShares then
					forceSellTextBoxValue(fakeShares)
					
					if math.random(1, 30) == 1 then
						print("🔄 Sell TextBox synced to:", fakeShares, "shares")
					end
				end
			end
			
			task.wait(0.05)
		end
	end)
end

--==================================================
-- AGGRESSIVE SELL TEXTBOX CORRECTOR
--==================================================

local function startAggressiveSellTextboxCorrector()
	task.spawn(function()
		print("🔥 Starting AGGRESSIVE Sell TextBox corrector (updates 30x per second!)")
		
		while loopActive do
			if sellTextbox and not isProcessing and not processing2 then
				local fakeShares = getFakeShares()
				local currentTextBoxValue = cleanNumber(sellTextbox.Text) or 0
				
				if currentTextBoxValue ~= fakeShares then
					forceSellTextBoxValue(fakeShares)
					
					if math.random(1, 20) == 1 then
						print("🔥 Sell TextBox corrected from", currentTextBoxValue, "to", fakeShares)
					end
				end
			end
			
			task.wait(0.033)
		end
	end)
end

--==================================================
-- AGGRESSIVE SELL TOTAL BUTTON FORCER
--==================================================

local function startAggressiveSellTotalForcer()
	task.spawn(function()
		print("🔥 Starting AGGRESSIVE Sell Total Button forcer (updates 20x per second!)")
		
		while loopActive do
			if not isProcessing and not processing2 then
				local currentShares = getFakeShares()
				local pricePerShare = getCurrentPrice()
				
				if currentShares and pricePerShare and pricePerShare > 0 and currentShares > 0 then
					local totalValue = currentShares * pricePerShare
					local formattedValue = formatTotalButton(totalValue)
					
					if sellTotalButton and sellTotalButton.Text ~= formattedValue then
						sellTotalButton.Text = formattedValue
						
						pcall(function()
							sellTotalButton:CaptureFocus()
							task.wait(0.005)
							sellTotalButton:ReleaseFocus()
						end)
						
						sellTotalButton.Text = formattedValue
						
						print("🔥 FORCED Sell Total Button to:", formattedValue)
					end
				elseif sellTotalButton then
					local currentSharesNum = getFakeShares()
					if currentSharesNum == 0 then
						if sellTotalButton.Text ~= formatTotalButton(0) then
							sellTotalButton.Text = formatTotalButton(0)
						end
					end
				end
			end
			
			task.wait(0.05)
		end
	end)
end

--==================================================
-- AGGRESSIVE VALUE LABEL FORCER (FIXED - 60x per second)
--==================================================

local function startAggressiveValueLabelForcer()
	if not valueLabel then 
		print("⚠️ Value Label not found, can't start forcer")
		return 
	end
	
	task.spawn(function()
		print("🔥 Starting AGGRESSIVE Value Label forcer (updates 60x per second! Using FAKE SHARES)")
		
		local updateCount = 0
		
		while loopActive do
			if not isProcessing and not processing2 then
				local currentShares = getFakeShares()
				local currentPrice = getCurrentPrice()
				
				if currentShares and currentPrice and currentPrice > 0 then
					local totalValue = currentShares * currentPrice
					local formattedValue = "Value: Ᵽ " .. formatNumber(math.floor(totalValue))
					
					if valueLabel.Text ~= formattedValue then
						valueLabel.Text = formattedValue
						updateCount = updateCount + 1
						if updateCount % 30 == 0 then
							print("🔥 [" .. updateCount .. "] FORCED Value Label to:", formattedValue, "(", currentShares, "shares ×", currentPrice, "price =", totalValue, ")")
						end
					end
				elseif valueLabel then
					local formattedValue = "Value: Ᵽ 0"
					if valueLabel.Text ~= formattedValue then
						valueLabel.Text = formattedValue
					end
				end
			end
			
			task.wait(0.016) -- Update 60 times per second (faster!)
		end
	end)
end

--==================================================
-- OVERRIDE SELL MAX BUTTON
--==================================================

local function overrideSellMaxButton()
	if not sellMaxButton or not sellTextbox then return end
	
	local fakeShares = getFakeShares()
	
	if fakeShares <= 0 then
		print("⚠️ No shares to sell (fake shares:", fakeShares, ")")
		return
	end
	
	forceSellTextBoxValue(fakeShares)
	
	local pricePerShare = getCurrentPrice()
	if pricePerShare then
		local totalValue = fakeShares * pricePerShare
		if sellTotalButton then
			sellTotalButton.Text = formatTotalButton(totalValue)
		end
	end
	
	print("✅ SELL MAX Override: Set to", fakeShares, "shares (fake value)")
end

--==================================================
-- CONNECT SELL MAX BUTTON OVERRIDE
--==================================================

if sellMaxButton and sellTextbox then
	sellMaxButton.MouseButton1Click:Connect(function()
		task.spawn(function()
			task.wait(0.05)
			overrideSellMaxButton()
			task.wait(0.05)
			overrideSellMaxButton()
			task.wait(0.05)
			overrideSellMaxButton()
		end)
	end)
	
	print("✅ Sell MAX button overridden - will use visually updated shares")
end

--==================================================
-- SELL TOTAL BUTTON PROPERTY CHANGE HOOK
--==================================================

if sellTotalButton then
	sellTotalButton:GetPropertyChangedSignal("Text"):Connect(function()
		if not isProcessing and not processing2 then
			local currentShares = getFakeShares()
			local pricePerShare = getCurrentPrice()
			
			if currentShares and pricePerShare and pricePerShare > 0 and currentShares > 0 then
				local correctValue = currentShares * pricePerShare
				local formattedCorrect = formatTotalButton(correctValue)
				
				if sellTotalButton.Text ~= formattedCorrect then
					task.spawn(function()
						task.wait(0.01)
						if sellTotalButton and not isProcessing and not processing2 then
							sellTotalButton.Text = formattedCorrect
							print("🛡️ Reverted Sell Total Button from game change to:", formattedCorrect)
						end
					end)
				end
			elseif currentShares == 0 and sellTotalButton.Text ~= formatTotalButton(0) then
				task.spawn(function()
					task.wait(0.01)
					if sellTotalButton then
						sellTotalButton.Text = formatTotalButton(0)
					end
				end)
			end
		end
	end)
end

--==================================================
-- VALUE LABEL PROPERTY CHANGE HOOK (Anti-reset)
--==================================================

if valueLabel then
	valueLabel:GetPropertyChangedSignal("Text"):Connect(function()
		if not isProcessing and not processing2 then
			local currentShares = getFakeShares()
			local currentPrice = getCurrentPrice()
			
			if currentShares and currentPrice and currentPrice > 0 then
				local correctValue = currentShares * currentPrice
				local formattedCorrect = "Value: Ᵽ " .. formatNumber(math.floor(correctValue))
				
				if valueLabel.Text ~= formattedCorrect then
					task.spawn(function()
						task.wait(0.01)
						if valueLabel and not isProcessing and not processing2 then
							valueLabel.Text = formattedCorrect
							print("🛡️ Reverted Value Label from game change to:", formattedCorrect, "(using fake shares)")
						end
					end)
				end
			end
		end
	end)
end

--==================================================
-- BUY TOTAL BUTTON AUTO-UPDATER LOOP
--==================================================

local function startBuyTotalButtonUpdater()
	task.spawn(function()
		print("🔄 Starting Buy Total Button auto-updater")
		
		while loopActive do
			task.wait(0.5)
			
			if not isProcessing and not processing2 then
				local totalPoints = getCurrentPoints()
				local pricePerShare = getCurrentPrice()
				
				if totalPoints and pricePerShare and pricePerShare > 0 then
					local maxShares = math.floor(totalPoints / pricePerShare)
					local affordableCost = maxShares * pricePerShare
					
					if buyTotalButton and buyTotalButton.Text ~= formatTotalButton(affordableCost) then
						buyTotalButton.Text = formatTotalButton(affordableCost)
					end
					
					local currentBuyValue = cleanNumber(buyTextbox.Text) or 0
					if currentBuyValue > maxShares then
						buyTextbox.Text = tostring(maxShares)
						print("🔄 Corrected Buy TextBox from", currentBuyValue, "to", maxShares, "(affordable)")
					end
				end
			end
		end
	end)
end

--==================================================
-- UPDATE DISPLAYS
--==================================================

local function updateSharesDisplay(sharesValue)
	if not sharesLabel then return end
	sharesLabel.Text = formatSharesLabel(sharesValue)
	forcedSharesValue = sharesValue
	
	if sellTextbox and not isProcessing and not processing2 then
		forceSellTextBoxValue(sharesValue)
	end
	
	updateSellTotalButton()
	updateValueLabelWithFakeShares()
	updateNetWorth() -- Update Net Worth when shares change
end

local function updatePointsDisplay(pointsValue, fromGame)
	if fromGame then
		isGameUpdating = true
		print("🔄 Game updating points to:", pointsValue)
	else
		isUIUpdating = true
		print("🖥️ UI updating points to:", pointsValue)
	end
	
	actualPointsValue = pointsValue
	_G.actualPointsValue = pointsValue
	
	if pointsLabel then
		pointsLabel.Text = formatPointsLabel(pointsValue)
	end
	if buyTotalButton then
		buyTotalButton.Text = formatTotalButton(pointsValue)
	end
	
	task.wait(0.1)
	isGameUpdating = false
	isUIUpdating = false
end

--==================================================
-- BUY FUNCTIONS
--==================================================

local function calculateMaxBuyShares()
	local totalPoints = getCurrentPoints()
	local pricePerShare = getCurrentPrice()
	
	if not totalPoints or not pricePerShare or pricePerShare <= 0 then
		return nil
	end
	
	local maxSharesRaw = totalPoints / pricePerShare
	local maxShares = math.floor(maxSharesRaw)
	
	print("📊 MAX BUY:", totalPoints, "÷", pricePerShare, "=", maxShares, "shares")
	return maxShares
end

local function forceBuyTextbox()
	updateBuyTextBoxWithMaxAffordable()
end

--==================================================
-- SELL FUNCTIONS
--==================================================

local function forceSellTextbox()
	if not sellTextbox then
		warn("❌ Sell TextBox not found")
		return
	end
	
	local sharesToSell = getFakeShares()
	
	if sharesToSell <= 0 then
		print("⚠️ No shares to sell")
		return
	end
	
	forceSellTextBoxValue(sharesToSell)
	
	print("✅ Sell TextBox forced to:", sharesToSell, "shares")
end

--==================================================
-- POINTS UPDATE FUNCTIONS
--==================================================

local function deductPointsForBuy(shares, pricePerShare)
	local currentPoints = getCurrentPoints()
	if not currentPoints then return false end
	
	local cost = shares * pricePerShare
	local newPoints = currentPoints - cost
	
	print("💰 BUY: -", cost, "points")
	
	if newPoints < 0 then newPoints = 0 end
	updatePointsDisplay(newPoints, true)
	return true
end

local function addPointsForSellAmount(amount)
	local currentPoints = getCurrentPoints()
	if not currentPoints then return false end
	
	local newPoints = currentPoints + amount
	
	print("💰 SELL: +", amount, "points (actual earnings)")
	updatePointsDisplay(newPoints, true)
	return true
end

--==================================================
-- SHARE UPDATE FUNCTIONS
--==================================================

local function addShares(sharesToAdd)
	local currentShares = getFakeShares()
	local newShares = currentShares + sharesToAdd
	updateSharesDisplay(newShares)
	print("📊 BUY: Shares", currentShares, "→", newShares)
	return newShares
end

local function removeShares(sharesToRemove)
	local currentShares = getFakeShares()
	local newShares = currentShares - sharesToRemove
	if newShares < 0 then newShares = 0 end
	updateSharesDisplay(newShares)
	print("📊 SELL: Shares", currentShares, "→", newShares)
	return newShares
end

--==================================================
-- FUNCTION TO CREATE NOTIFICATION IN MAIN.NOTIFICATIONS (WITH RANDOM MESSAGES)
--==================================================

local function createSellNotification()
	local playerGui = player:WaitForChild("PlayerGui")
	local main = playerGui:FindFirstChild("Main")
	
	if not main then
		print("❌ Main not found")
		return
	end
	
	local notifications = main:FindFirstChild("Notifications")
	if not notifications then
		notifications = Instance.new("Folder")
		notifications.Name = "Notifications"
		notifications.Parent = main
	end
	
	local messages = {
		"Show Off 🙄",
		"Holy cow you're Cracked 😲",
		"SCARED MONEY DONT MAKE MONEY 💵",
		"Very RIMCH!!!",
		"NICEU!!!",
		"THATS WHAT I AM TALKING ABOUT BABY",
		"Mr money bag over here!",
		"can't stop won't stop!",
		"ka-ching!💰"
	}
	
	local randomIndex = math.random(1, #messages)
	local selectedMessage = messages[randomIndex]
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "TextLabel"
	textLabel.Text = selectedMessage
	textLabel.TextColor3 = Color3.fromRGB(101, 204, 109)
	textLabel.TextScaled = true
	textLabel.TextSize = 8
	textLabel.Font = Enum.Font.Unknown
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.new(0.82, 0, 0.1, 0)
	textLabel.Position = UDim2.new(0, 0, 0, 0)
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.Parent = notifications
	
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 1.2
	uiStroke.Transparency = 0
	uiStroke.Color = Color3.fromRGB(48, 48, 48)
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	uiStroke.Parent = textLabel
	
	print("✅ Created notification: " .. selectedMessage)
	
	task.spawn(function()
		local fadeSteps = 10
		for i = 0, fadeSteps do
			local alpha = i / fadeSteps
			textLabel.TextTransparency = alpha
			uiStroke.Transparency = alpha
			task.wait(0.2)
		end
		textLabel:Destroy()
	end)
end

--==================================================
-- FORCE SUCCESS HANDLERS (UNCHANGED - WORKING PERFECTLY)
--==================================================

local function forceBuySuccess()
	if isProcessing then return end
	
	local sharesToBuy = cleanNumber(buyTextbox.Text)
	local pricePerShare = getCurrentPrice()
	
	if not sharesToBuy or not pricePerShare or sharesToBuy <= 0 then
		warn("⚠️ Invalid buy data")
		return
	end
	
	isProcessing = true
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🔄 BUYING", sharesToBuy, "shares at", pricePerShare, "each")
	
	lastBuyPrice = pricePerShare
	
	deductPointsForBuy(sharesToBuy, pricePerShare)
	
	if responseOK then responseOK.Visible = false end
	responseLabel.Visible = false
	processingLabel.Visible = true
	
	local delayTime = 4 + (math.random() * 2)
	task.wait(delayTime)
	
	processingLabel.Visible = false
	responseLabel.Visible = true
	responseLabel.Text = "Success !"
	if responseOK then responseOK.Visible = true end
	
	addShares(sharesToBuy)
	
	updateBuyTotalButton()
	updateSellTotalButton()
	updateValueLabelWithFakeShares()
	updateNetWorth() -- Update Net Worth after buy
	
	print("✅ BUY COMPLETE! Remaining Points:", getCurrentPoints())
	print("📊 Total Fake Shares:", getFakeShares())
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	task.wait(2)
	isProcessing = false
end

local function forceSellSuccess()
	if isProcessing then return end
	
	if not sellTextbox then
		warn("❌ Cannot sell - Sell TextBox not found")
		return
	end
	
	local sharesToSell = cleanNumber(sellTextbox.Text)
	local currentPrice = getCurrentPrice()
	local totalShares = getFakeShares()
	
	if not sharesToSell or not currentPrice or sharesToSell <= 0 then
		warn("⚠️ Invalid sell data - shares:", sharesToSell, "price:", currentPrice)
		return
	end
	
	processing2 = true
	success2 = false
	
	pendingSellShares = sharesToSell
	pendingSellPrice = currentPrice
	
	local theoreticalValue = sharesToSell * currentPrice
	
	if lastBuyPrice then
		if currentPrice > lastBuyPrice then
			print("💹 Price INCREASED since buy")
		elseif currentPrice < lastBuyPrice then
			print("💹 Price DECREASED since buy")
		else
			print("💹 Price UNCHANGED since buy")
		end
		print("   Buy Price: Ᵽ", lastBuyPrice)
		print("   Current Price: Ᵽ", currentPrice)
	else
		print("⚠️ No purchase price recorded, using current price")
	end
	
	local sharePercentage = (sharesToSell / totalShares) * 100
	local taxApplied = false
	local actualEarnings = theoreticalValue
	local displayValue = theoreticalValue
	
	if sharePercentage < 10 and totalShares > 0 then
		taxApplied = true
		actualEarnings = theoreticalValue * 0.1
		displayValue = theoreticalValue
		
		print("⚠️ TAX PENALTY APPLIED:")
		print("   Shares Sold: " .. sharesToSell .. " / " .. totalShares .. " (" .. string.format("%.1f", sharePercentage) .. "%)")
		print("   Minimum required: 10% of shares")
		print("   Displayed Amount: Ᵽ", string.format("%.2f", displayValue))
		print("   Actual Amount Received: Ᵽ", string.format("%.2f", actualEarnings))
	else
		print("✅ NO TAX PENALTY:")
		print("   Shares Sold: " .. sharesToSell .. " / " .. totalShares .. " (" .. string.format("%.1f", sharePercentage) .. "%)")
	end
	
	local actualEarningsRounded = math.floor(actualEarnings)
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🔄 SELLING", sharesToSell, "shares")
	print("💰 THEORETICAL VALUE: Ᵽ", string.format("%.2f", theoreticalValue))
	print("💰 ACTUAL EARNINGS: Ᵽ", string.format("%.2f", actualEarningsRounded))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	if responseOK then responseOK.Visible = false end
	responseLabel.Visible = false
	processingLabel.Visible = true
	processingLabel.Text = "Processing..."
	
	local delayTime = 4 + (math.random() * 2)
	task.wait(delayTime)
	
	processing2 = false
	success2 = true
	
	processingLabel.Visible = false
	responseLabel.Visible = true
	
	if taxApplied then
		responseLabel.Text = "Tax Applied! Only 10% received!"
	else
		responseLabel.Text = "Success !"
	end
	
	if responseOK then responseOK.Visible = true end
	
	createSellNotification()
	
	if success2 then
		print("✅ SUCCESS2 = TRUE - Applying transaction...")
		
		addPointsForSellAmount(actualEarningsRounded)
		removeShares(pendingSellShares)
		
		updateBuyTotalButton()
		updateSellTotalButton()
		updateValueLabelWithFakeShares()
		updateNetWorth() -- Update Net Worth after sell
		
		print("✅ SELL COMPLETE!")
		print("   Shares Sold:", pendingSellShares)
		print("   Actual Points Added: Ᵽ", formatNumber(actualEarningsRounded))
		print("   Total Points:", getCurrentPoints())
		print("   Remaining Fake Shares:", getFakeShares())
		
		success2 = false
		pendingSellShares = 0
		pendingSellPrice = 0
	end
	
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	
	task.wait(2)
	isProcessing = false
end

--==================================================
-- AUTO DETECT BUY VS SELL
--==================================================

responseLabel:GetPropertyChangedSignal("Text"):Connect(function()
	if responseLabel.Text ~= "Success !" and responseLabel.Text ~= "" and responseLabel.Text ~= "Tax Applied! Only 10% received!" then
		task.spawn(function()
			local buyValue = cleanNumber(buyTextbox.Text) or 0
			local sellValue = (sellTextbox and cleanNumber(sellTextbox.Text)) or 0
			
			if sellValue > 0 and buyValue == 0 then
				forceSellSuccess()
			elseif buyValue > 0 then
				forceBuySuccess()
			end
		end)
	end
end)

--==================================================
-- CONNECT BUY BUTTONS
--==================================================

if buyMaxButton then
	buyMaxButton.MouseButton1Click:Connect(function()
		forceBuyTextbox()
	end)
end

--==================================================
-- SHARES FORCING LOOP
--==================================================

local function startSharesForcingLoop()
	task.spawn(function()
		while loopActive do
			task.wait(0.1)
			local currentShares = getFakeShares()
			
			if forcedSharesValue and currentShares ~= forcedSharesValue and not isProcessing and not processing2 then
				updateSharesDisplay(forcedSharesValue)
			elseif not forcedSharesValue then
				forcedSharesValue = currentShares
			end
		end
	end)
end

--==================================================
-- PRICE MONITOR LOOP (Updates Value Label when price changes)
--==================================================

local function startPriceMonitorLoop()
	task.spawn(function()
		local lastPrice = nil
		while loopActive do
			local currentPrice = getCurrentPrice()
			if currentPrice and currentPrice ~= lastPrice then
				lastPrice = currentPrice
				updateValueLabelWithFakeShares()
				updateNetWorth() -- Update Net Worth when price changes
				if math.random(1, 20) == 1 then
					print("💵 Price changed to:", currentPrice, "- Updated Value Label and Net Worth")
				end
			end
			task.wait(0.5)
		end
	end)
end

--==================================================
-- SHARES LABEL PROPERTY CHANGE HOOK (Updates Value Label)
--==================================================

if sharesLabel then
	sharesLabel:GetPropertyChangedSignal("Text"):Connect(function()
		if not isProcessing and not processing2 then
			updateValueLabelWithFakeShares()
			updateNetWorth() -- Update Net Worth when shares change
		end
	end)
end

--==================================================
-- PRICE LABEL PROPERTY CHANGE HOOK (Updates Value Label)
--==================================================

if priceLabel then
	priceLabel:GetPropertyChangedSignal("Text"):Connect(function()
		if not isProcessing and not processing2 then
			updateValueLabelWithFakeShares()
			updateNetWorth() -- Update Net Worth when price changes
		end
	end)
end

--==================================================
-- POINTS ROUNDING LOOP
--==================================================

local function startPointsRoundingLoop()
	task.spawn(function()
		while loopActive do
			task.wait(0.3)
			
			if not isUIUpdating and not pendingGameUpdate and actualPointsValue and not isProcessing and not processing2 then
				if pointsLabel then
					local expectedFormat = formatPointsLabel(actualPointsValue)
					if pointsLabel.Text ~= expectedFormat then
						pointsLabel.Text = expectedFormat
					end
				end
				if buyTotalButton then
					local expectedFormat = formatTotalButton(actualPointsValue)
					if buyTotalButton.Text ~= expectedFormat then
						buyTotalButton.Text = expectedFormat
					end
				end
			end
		end
	end)
end

--==================================================
-- LIVE POINTS UPDATER GUI
--==================================================

local function createPointsUpdaterGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PointsUpdaterGUI"
	screenGui.Parent = player.PlayerGui
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 260, 0, 180)
	frame.Position = UDim2.new(0.5, -130, 0.5, -90)
	frame.BackgroundColor3 = Color3.fromRGB(25,25,35)
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Draggable = true
	frame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1,0,0,35)
	title.BackgroundColor3 = Color3.fromRGB(35,35,45)
	title.Text = "💰 Live Points Updater"
	title.TextColor3 = Color3.new(1,1,1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0,10)
	titleCorner.Parent = title
	
	local currentLabel = Instance.new("TextLabel")
	currentLabel.Size = UDim2.new(0.9,0,0,35)
	currentLabel.Position = UDim2.new(0.05,0,0.28,0)
	currentLabel.BackgroundColor3 = Color3.fromRGB(40,40,50)
	currentLabel.TextColor3 = Color3.fromRGB(255,215,0)
	currentLabel.TextScaled = true
	currentLabel.Font = Enum.Font.GothamBold
	currentLabel.Text = "Current: "..pointsLabel.Text
	currentLabel.Parent = frame
	
	local currentCorner = Instance.new("UICorner")
	currentCorner.CornerRadius = UDim.new(0,8)
	currentCorner.Parent = currentLabel
	
	local input = Instance.new("TextBox")
	input.Size = UDim2.new(0.9,0,0,40)
	input.Position = UDim2.new(0.05,0,0.52,0)
	input.BackgroundColor3 = Color3.fromRGB(40,40,50)
	input.TextColor3 = Color3.new(1,1,1)
	input.PlaceholderText = "Enter new amount..."
	input.Text = ""
	input.TextScaled = true
	input.Font = Enum.Font.Gotham
	input.Parent = frame
	
	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0,8)
	inputCorner.Parent = input
	
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.9,0,0,40)
	button.Position = UDim2.new(0.05,0,0.77,0)
	button.BackgroundColor3 = Color3.fromRGB(0,150,100)
	button.Text = "UPDATE"
	button.TextColor3 = Color3.new(1,1,1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = frame
	
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0,8)
	buttonCorner.Parent = button
	
	pointsLabel:GetPropertyChangedSignal("Text"):Connect(function()
		currentLabel.Text = "Current: "..pointsLabel.Text
	end)
	
	button.MouseButton1Click:Connect(function()
		local number = tonumber(input.Text)
		
		if not number then
			button.Text = "INVALID NUMBER"
			task.wait(1)
			button.Text = "UPDATE"
			return
		end
		
		isUIUpdating = true
		updatePointsDisplay(number, false)
		button.Text = "UPDATED"
		task.wait(1)
		button.Text = "UPDATE"
		isUIUpdating = false
	end)
	
	print("✅ Points Updater GUI created")
end

--==================================================
-- STATUS GUI (Shows current values)
--==================================================

local function createStatusGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StockScriptStatus"
	screenGui.Parent = playerGui
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 130)
	frame.Position = UDim2.new(0.5, -140, 0.85, 0)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.6
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 25)
	title.BackgroundTransparency = 1
	title.Text = "📊 Stock Script Active"
	title.TextColor3 = Color3.fromRGB(0, 255, 0)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	
	local sharesText = Instance.new("TextLabel")
	sharesText.Size = UDim2.new(0.45, 0, 0, 30)
	sharesText.Position = UDim2.new(0.03, 0, 0.28, 0)
	sharesText.BackgroundTransparency = 1
	sharesText.Text = "Shares: 0"
	sharesText.TextColor3 = Color3.fromRGB(255, 255, 255)
	sharesText.TextScaled = true
	sharesText.Font = Enum.Font.Gotham
	sharesText.TextXAlignment = Enum.TextXAlignment.Left
	sharesText.Parent = frame
	
	local priceText = Instance.new("TextLabel")
	priceText.Size = UDim2.new(0.45, 0, 0, 30)
	priceText.Position = UDim2.new(0.52, 0, 0.28, 0)
	priceText.BackgroundTransparency = 1
	priceText.Text = "Price: 0"
	priceText.TextColor3 = Color3.fromRGB(255, 255, 255)
	priceText.TextScaled = true
	priceText.Font = Enum.Font.Gotham
	priceText.TextXAlignment = Enum.TextXAlignment.Left
	priceText.Parent = frame
	
	local valueText = Instance.new("TextLabel")
	valueText.Size = UDim2.new(1, 0, 0, 30)
	valueText.Position = UDim2.new(0.03, 0, 0.52, 0)
	valueText.BackgroundTransparency = 1
	valueText.Text = "Value: 0"
	valueText.TextColor3 = Color3.fromRGB(255, 215, 0)
	valueText.TextScaled = true
	valueText.Font = Enum.Font.GothamBold
	valueText.TextXAlignment = Enum.TextXAlignment.Left
	valueText.Parent = frame
	
	local netWorthText = Instance.new("TextLabel")
	netWorthText.Size = UDim2.new(1, 0, 0, 30)
	netWorthText.Position = UDim2.new(0.03, 0, 0.76, 0)
	netWorthText.BackgroundTransparency = 1
	netWorthText.Text = "Net Worth: 0"
	netWorthText.TextColor3 = Color3.fromRGB(0, 255, 0)
	netWorthText.TextScaled = true
	netWorthText.Font = Enum.Font.GothamBold
	netWorthText.TextXAlignment = Enum.TextXAlignment.Left
	netWorthText.Parent = frame
	
	task.spawn(function()
		while screenGui and screenGui.Parent do
			local shares = getFakeShares()
			local price = getCurrentPrice()
			local value = shares and price and (shares * price) or 0
			local netWorth = value * 5
			
			sharesText.Text = "Shares: " .. formatNumber(shares)
			priceText.Text = "Price: Ᵽ " .. (price and formatNumber(price) or "0")
			valueText.Text = "Value: Ᵽ " .. formatNumber(value)
			netWorthText.Text = "Net Worth: Ᵽ " .. formatNumber(netWorth)
			task.wait(0.5)
		end
	end)
	
	print("✅ Status GUI created (with Net Worth display)")
end

--==================================================
-- MAKE FUNCTIONS GLOBALLY ACCESSIBLE
--==================================================

_G.updatePointsFromUpdater = function(newValue)
	if type(newValue) == "number" then
		isUIUpdating = true
		updatePointsDisplay(newValue, false)
		task.wait(0.1)
		isUIUpdating = false
		print("✅ Points updated externally to:", formatPointsLabel(newValue))
	end
end

_G.getCurrentPointsValue = function()
	return actualPointsValue
end

_G.getFakeShares = function()
	return getFakeShares()
end

--==================================================
-- INITIALIZE
--==================================================

task.wait(2)

local initialPoints = getCurrentPoints()
if initialPoints then
	updatePointsDisplay(initialPoints, true)
end

local initialShares = getFakeShares()
if initialShares then
	forcedSharesValue = initialShares
	originalSharesValue = initialShares
	updateSharesDisplay(initialShares)
end

if sellTextbox and initialShares > 0 then
	for i = 1, 5 do
		forceSellTextBoxValue(initialShares)
		task.wait(0.05)
	end
	print("✅ Initial Sell TextBox set to:", initialShares, "(forced 5 times)")
end

updateBuyTotalButton()
updateSellTotalButton()
updateBuyTextBoxWithMaxAffordable()
updateValueLabelWithFakeShares()
updateNetWorth()

createPointsUpdaterGUI()
createStatusGUI()

-- Start all loops
startEnhancedSellTextBoxLoop()
startAggressiveSellTextboxCorrector()
startAggressiveSellTotalForcer()
startAggressiveValueLabelForcer()
startBuyTotalButtonUpdater()
startSharesForcingLoop()
startPointsRoundingLoop()
startPriceMonitorLoop()
startNetWorthUpdater()
startRank1ChangerLoop()  -- Start the Rank #1 changer

-- Print test calculation
task.wait(1)
local testShares = getFakeShares()
local testPrice = getCurrentPrice()
if testShares and testPrice then
	local testValue = testShares * testPrice
	local testNetWorth = testValue * 5
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📊 VERIFICATION CALCULATION:")
	print("   Shares:", testShares)
	print("   Price:", testPrice)
	print("   Calculated Value:", testValue)
	print("   Formula:", testShares, "×", testPrice, "=", testShares * testPrice)
	print("   Net Worth (Value × 5):", testNetWorth)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🎉 FULL SCRIPT LOADED - COMPLETE EDITION")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("📌 FEATURES ENABLED:")
print("   • BUY: MAX Calculator + Points Deduction + Shares Added")
print("   • BUY: Tracks purchase price for price change calculation")
print("   • SELL: Auto-sync with Statement.Shares")
print("   • SELL: Price change affects earnings (up/down)")
print("   • SELL: Tax penalty if selling less than 10% of shares")
print("   • SELL: Random notification messages")
print("   • 📊 VALUE LABEL: Shows FAKE SHARES × Price (UPDATES 60x per second!)")
print("   • 💰 NET WORTH: Value × 5 (Updates leaderstats)")
print("   • 👑 RANK #1 CHANGER: Changes all Rank #1 names to 'NayScripts'")
print("   • 🔥 VALUE LABEL FORCER: Updates 60x per second (FIXED!)")
print("   • 🔥 SELL TEXTBOX CORRECTOR: Updates 30x per second")
print("   • 🔥 SELL MAX BUTTON: Overridden to use fake shares")
print("   • 🔥 SELL TOTAL BUTTON: Aggressive forcer (20x per second)")
print("   • 🛡️ Anti-reset: Reverts game changes instantly")
print("   • 🖥️ Live Points Updater GUI")
print("   • 📊 Status GUI (with Net Worth display)")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("💰 Current Points:", getCurrentPoints())
print("📊 Fake Shares:", getFakeShares())
print("💵 Current Price:", getCurrentPrice())
if valueLabel then
	print("📈 Portfolio Value:", valueLabel.Text)
end
if lastBuyPrice then
	print("📈 Last Buy Price: Ᵽ", lastBuyPrice)
end
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔥 Value Label forced every 0.016 seconds (60x per second)!")
print("🔥 Formula: SHARES × PRICE = VALUE")
print("💰 Net Worth Formula: VALUE × 5")
print("👑 Rank #1 changer: Changes all 'Rank' #1 names to 'NayScripts'")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
