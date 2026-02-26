-- CaseUI.client.lua
-- CS:GO-style case spinner UI for Win Effects Case.
-- Opens when the local player activates the Case chest ProximityPrompt.
-- All sizing is SCALE-based; tile pixel sizes are computed at runtime from AbsoluteSize.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

local WinEffectConfig = require(ReplicatedStorage:WaitForChild("WinEffectConfig"))
local RobuxConfig     = require(ReplicatedStorage:WaitForChild("RobuxConfig"))

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local openCaseEvent   = remoteEvents:WaitForChild("OpenCase")
local caseResultEvent = remoteEvents:WaitForChild("CaseResult")

local bindableEvents    = ReplicatedStorage:WaitForChild("BindableEvents")
local openCaseUIEvent   = bindableEvents:WaitForChild("OpenCaseUI")

-- Effect display order for case (all spinnable)
local SPIN_ORDER = { "Fireworks", "MoneyRain", "Galaxy", "Lightning" }

-- Rarity colour borders per rarity (loosely — use effect color)
local RARITY_COLORS = {
	Fireworks = Color3.fromRGB(255, 100, 50),
	MoneyRain = Color3.fromRGB(255, 215, 50),
	Galaxy    = Color3.fromRGB(120, 80, 255),
	Lightning = Color3.fromRGB(200, 150, 255),
}

-- ── Build the screen GUI ─────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "CaseUI"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = playerGui

-- Dim background overlay
local dimBg = Instance.new("Frame")
dimBg.Size                  = UDim2.new(1, 0, 1, 0)
dimBg.BackgroundColor3      = Color3.fromRGB(0, 0, 0)
dimBg.BackgroundTransparency = 0.45
dimBg.BorderSizePixel       = 0
dimBg.ZIndex                = 50
dimBg.Visible               = false
dimBg.Parent                = screenGui

-- Main panel
local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0.62, 0, 0.72, 0)
panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(18, 12, 28)
panel.BorderSizePixel  = 0
panel.ZIndex           = 51
panel.Visible          = false
panel.Parent           = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0.025, 0)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = Color3.fromRGB(255, 190, 0)
panelStroke.Thickness = 2

-- Aspect ratio lock so layout is consistent across screen sizes
local arc = Instance.new("UIAspectRatioConstraint", panel)
arc.AspectRatio = 1.45

-- Close button (top-right)
local closeBtn = Instance.new("TextButton")
closeBtn.Size                  = UDim2.new(0.08, 0, 0.06, 0)
closeBtn.Position              = UDim2.new(0.92, 0, 0.01, 0)
closeBtn.AnchorPoint           = Vector2.new(0, 0)
closeBtn.BackgroundColor3      = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel       = 0
closeBtn.Text                  = "X"
closeBtn.TextColor3            = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled            = true
closeBtn.Font                  = Enum.Font.GothamBold
closeBtn.ZIndex                = 52
closeBtn.Parent                = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.3, 0)

-- Title label
local titleLabel = Instance.new("TextLabel")
titleLabel.Size               = UDim2.new(0.85, 0, 0.1, 0)
titleLabel.Position           = UDim2.new(0.075, 0, 0.01, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text               = "WIN EFFECTS CASE"
titleLabel.TextColor3         = Color3.fromRGB(255, 190, 0)
titleLabel.TextScaled         = true
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.ZIndex             = 52
titleLabel.Parent             = panel

-- Rarity preview row (4 small tiles showing possible prizes)
local rarityRow = Instance.new("Frame")
rarityRow.Size             = UDim2.new(0.9, 0, 0.13, 0)
rarityRow.Position         = UDim2.new(0.05, 0, 0.12, 0)
rarityRow.BackgroundTransparency = 1
rarityRow.ZIndex           = 52
rarityRow.Parent           = panel

local rarityLayout = Instance.new("UIListLayout")
rarityLayout.FillDirection       = Enum.FillDirection.Horizontal
rarityLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rarityLayout.Padding             = UDim.new(0.015, 0)
rarityLayout.Parent              = rarityRow

for _, key in ipairs(SPIN_ORDER) do
	local eff = WinEffectConfig.Effects[key]
	local tile = Instance.new("Frame")
	tile.Size             = UDim2.new(0.22, 0, 1, 0)
	tile.BackgroundColor3 = Color3.fromRGB(30, 20, 45)
	tile.BorderSizePixel  = 0
	tile.ZIndex           = 52
	tile.Parent           = rarityRow
	Instance.new("UICorner", tile).CornerRadius = UDim.new(0.08, 0)
	local tStroke = Instance.new("UIStroke", tile)
	tStroke.Color     = RARITY_COLORS[key]
	tStroke.Thickness = 2

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(1, 0, 0.55, 0)
	iconLbl.Position = UDim2.new(0, 0, 0, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = eff.Icon
	iconLbl.TextScaled = true
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.ZIndex = 53
	iconLbl.Parent = tile

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0.4, 0)
	nameLbl.Position = UDim2.new(0, 0, 0.58, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = eff.Name
	nameLbl.TextColor3 = RARITY_COLORS[key]
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.Gotham
	nameLbl.ZIndex = 53
	nameLbl.Parent = tile
end

-- Strip container (clips the scrolling content)
local stripContainer = Instance.new("Frame")
stripContainer.Name               = "StripContainer"
stripContainer.Size               = UDim2.new(0.95, 0, 0.26, 0)
stripContainer.Position           = UDim2.new(0.025, 0, 0.27, 0)
stripContainer.BackgroundColor3   = Color3.fromRGB(10, 6, 18)
stripContainer.BorderSizePixel    = 0
stripContainer.ClipsDescendants   = true
stripContainer.ZIndex             = 52
stripContainer.Parent             = panel
Instance.new("UICorner", stripContainer).CornerRadius = UDim.new(0.04, 0)
local stripStroke = Instance.new("UIStroke", stripContainer)
stripStroke.Color     = Color3.fromRGB(80, 60, 100)
stripStroke.Thickness = 1

-- Scrolling content frame (width set at runtime)
local contentFrame = Instance.new("Frame")
contentFrame.Name               = "Content"
contentFrame.Size               = UDim2.new(0, 0, 1, 0)   -- width set at runtime
contentFrame.Position           = UDim2.new(0, 0, 0, 0)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex             = 53
contentFrame.Parent             = stripContainer

local tileListLayout = Instance.new("UIListLayout")
tileListLayout.FillDirection = Enum.FillDirection.Horizontal
tileListLayout.SortOrder     = Enum.SortOrder.LayoutOrder
tileListLayout.Padding       = UDim.new(0, 4)
tileListLayout.Parent        = contentFrame

-- Center indicator line / arrow (golden vertical line)
local indicator = Instance.new("Frame")
indicator.Name               = "Indicator"
indicator.Size               = UDim2.new(0, 3, 1, 0)
indicator.Position           = UDim2.new(0.5, -1, 0, 0)
indicator.AnchorPoint        = Vector2.new(0.5, 0)
indicator.BackgroundColor3   = Color3.fromRGB(255, 200, 0)
indicator.BorderSizePixel    = 0
indicator.ZIndex             = 56
indicator.Parent             = stripContainer

-- Top & bottom indicator triangles (decorative arrows)
local topArrow = Instance.new("Frame")
topArrow.Size             = UDim2.new(0, 12, 0, 12)
topArrow.Position         = UDim2.new(0.5, -6, 0, -6)
topArrow.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
topArrow.BorderSizePixel  = 0
topArrow.ZIndex           = 57
topArrow.Rotation         = 45
topArrow.Parent           = stripContainer

-- Description / hint text
local hintLabel = Instance.new("TextLabel")
hintLabel.Size               = UDim2.new(0.9, 0, 0.08, 0)
hintLabel.Position           = UDim2.new(0.05, 0, 0.54, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Text               = "Duplicate item → +10 IQ & +50 Coins"
hintLabel.TextColor3         = Color3.fromRGB(160, 140, 190)
hintLabel.TextScaled         = true
hintLabel.Font               = Enum.Font.Gotham
hintLabel.ZIndex             = 52
hintLabel.Parent             = panel

-- Coins open button
local coinsBtn = Instance.new("TextButton")
coinsBtn.Size             = UDim2.new(0.42, 0, 0.13, 0)
coinsBtn.Position         = UDim2.new(0.04, 0, 0.64, 0)
coinsBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
coinsBtn.BorderSizePixel  = 0
coinsBtn.Text             = "Open  ♦ 300 Coins"
coinsBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
coinsBtn.TextScaled       = true
coinsBtn.Font             = Enum.Font.GothamBold
coinsBtn.ZIndex           = 52
coinsBtn.Parent           = panel
Instance.new("UICorner", coinsBtn).CornerRadius = UDim.new(0.2, 0)

-- Robux open button
local robuxBtn = Instance.new("TextButton")
robuxBtn.Size             = UDim2.new(0.42, 0, 0.13, 0)
robuxBtn.Position         = UDim2.new(0.54, 0, 0.64, 0)
robuxBtn.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
robuxBtn.BorderSizePixel  = 0
robuxBtn.Text             = "Open  R$ 25"
robuxBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
robuxBtn.TextScaled       = true
robuxBtn.Font             = Enum.Font.GothamBold
robuxBtn.ZIndex           = 52
robuxBtn.Parent           = panel
Instance.new("UICorner", robuxBtn).CornerRadius = UDim.new(0.2, 0)

-- Result panel (shown over the strip after spin)
local resultPanel = Instance.new("Frame")
resultPanel.Size             = UDim2.new(0.88, 0, 0.42, 0)
resultPanel.Position         = UDim2.new(0.06, 0, 0.27, 0)
resultPanel.BackgroundColor3 = Color3.fromRGB(18, 12, 28)
resultPanel.BackgroundTransparency = 0.05
resultPanel.BorderSizePixel  = 0
resultPanel.ZIndex           = 58
resultPanel.Visible          = false
resultPanel.Parent           = panel
Instance.new("UICorner", resultPanel).CornerRadius = UDim.new(0.04, 0)
local resultStroke = Instance.new("UIStroke", resultPanel)
resultStroke.Color     = Color3.fromRGB(255, 190, 0)
resultStroke.Thickness = 2

local resultIconLbl = Instance.new("TextLabel")
resultIconLbl.Size = UDim2.new(1, 0, 0.45, 0)
resultIconLbl.Position = UDim2.new(0, 0, 0, 0)
resultIconLbl.BackgroundTransparency = 1
resultIconLbl.TextScaled = true
resultIconLbl.Font = Enum.Font.GothamBold
resultIconLbl.ZIndex = 59
resultIconLbl.Parent = resultPanel

local resultNameLbl = Instance.new("TextLabel")
resultNameLbl.Size = UDim2.new(1, 0, 0.2, 0)
resultNameLbl.Position = UDim2.new(0, 0, 0.44, 0)
resultNameLbl.BackgroundTransparency = 1
resultNameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
resultNameLbl.TextScaled = true
resultNameLbl.Font = Enum.Font.GothamBold
resultNameLbl.ZIndex = 59
resultNameLbl.Parent = resultPanel

local resultDupLbl = Instance.new("TextLabel")
resultDupLbl.Size = UDim2.new(1, 0, 0.18, 0)
resultDupLbl.Position = UDim2.new(0, 0, 0.64, 0)
resultDupLbl.BackgroundTransparency = 1
resultDupLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
resultDupLbl.TextScaled = true
resultDupLbl.Font = Enum.Font.Gotham
resultDupLbl.ZIndex = 59
resultDupLbl.Parent = resultPanel

local okBtn = Instance.new("TextButton")
okBtn.Size             = UDim2.new(0.5, 0, 0.2, 0)
okBtn.Position         = UDim2.new(0.25, 0, 0.78, 0)
okBtn.BackgroundColor3 = Color3.fromRGB(255, 190, 0)
okBtn.BorderSizePixel  = 0
okBtn.Text             = "Awesome!"
okBtn.TextColor3       = Color3.fromRGB(18, 12, 28)
okBtn.TextScaled       = true
okBtn.Font             = Enum.Font.GothamBold
okBtn.ZIndex           = 59
okBtn.Parent           = resultPanel
Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0.3, 0)

-- ── State ────────────────────────────────────────────────────────────────────

local isSpinning = false
local tiles      = {}   -- the 40 tile frames, rebuilt each open

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function setButtonsEnabled(enabled)
	coinsBtn.AutoButtonColor = enabled
	robuxBtn.AutoButtonColor  = enabled
	coinsBtn.BackgroundTransparency = enabled and 0 or 0.5
	robuxBtn.BackgroundTransparency  = enabled and 0 or 0.5
end

local function makeTile(key)
	local eff = WinEffectConfig.Effects[key]
	local tileFrame = Instance.new("Frame")
	tileFrame.BackgroundColor3 = Color3.fromRGB(28, 18, 40)
	tileFrame.BorderSizePixel  = 0
	tileFrame.ZIndex           = 54

	local ts = Instance.new("UIStroke", tileFrame)
	ts.Color     = RARITY_COLORS[key] or Color3.fromRGB(100, 100, 100)
	ts.Thickness = 2

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0.6, 0)
	icon.BackgroundTransparency = 1
	icon.Text = eff.Icon
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.ZIndex = 55
	icon.Parent = tileFrame

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.38, 0)
	name.Position = UDim2.new(0, 0, 0.62, 0)
	name.BackgroundTransparency = 1
	name.Text = eff.Name
	name.TextColor3 = RARITY_COLORS[key] or Color3.fromRGB(200, 200, 200)
	name.TextScaled = true
	name.Font = Enum.Font.Gotham
	name.ZIndex = 55
	name.Parent = tileFrame

	Instance.new("UICorner", tileFrame).CornerRadius = UDim.new(0.06, 0)
	return tileFrame
end

local function buildStrip(spinSequence)
	-- Remove old tiles
	for _, t in ipairs(tiles) do t:Destroy() end
	tiles = {}

	for i, key in ipairs(spinSequence) do
		local tile = makeTile(key)
		tile.LayoutOrder = i
		tile.Parent      = contentFrame
		tiles[i]         = tile
	end
end

local function sizeStrip()
	-- tileWidth = strip height (square tiles)
	task.wait()   -- let layout settle
	local tileW = stripContainer.AbsoluteSize.Y
	contentFrame.Size = UDim2.new(0, tileW * #tiles + 4 * (#tiles - 1), 1, 0)
	contentFrame.Position = UDim2.new(0, 0, 0, 0)
	for _, tile in ipairs(tiles) do
		tile.Size = UDim2.new(0, tileW, 1, 0)
	end
	return tileW
end

-- ── Open / close ─────────────────────────────────────────────────────────────

local function openPanel()
	dimBg.Visible   = true
	panel.Visible   = true
	panel.Size      = UDim2.new(0.62, 0, 0.72, 0)
	resultPanel.Visible = false
	setButtonsEnabled(true)
end

local function closePanel()
	dimBg.Visible  = false
	panel.Visible  = false
	isSpinning     = false
end

-- ── Spin animation ───────────────────────────────────────────────────────────

local SPIN_DURATION   = 5.5
local WIN_SLOT        = 33
local BOUNCE_BACK_PX  = 18   -- pixels of bounce-back after landing

local function playSpin(spinSequence, onDone)
	buildStrip(spinSequence)
	local tileW = sizeStrip()
	if tileW <= 0 then onDone(); return end

	-- Target: center tile WIN_SLOT in the visible strip
	-- contentX = (3 - WIN_SLOT) * tileW  (see math in comments at top)
	local targetX = (3 - WIN_SLOT) * tileW

	-- Main tween
	local mainTween = TweenService:Create(
		contentFrame,
		TweenInfo.new(SPIN_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, targetX, 0, 0) }
	)
	mainTween:Play()
	mainTween.Completed:Wait()

	-- Small bounce back
	local bounceTween = TweenService:Create(
		contentFrame,
		TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, targetX + BOUNCE_BACK_PX, 0, 0) }
	)
	bounceTween:Play()
	bounceTween.Completed:Wait()

	-- Settle
	local settleTween = TweenService:Create(
		contentFrame,
		TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{ Position = UDim2.new(0, targetX, 0, 0) }
	)
	settleTween:Play()
	settleTween.Completed:Wait()

	onDone()
end

-- ── CaseResult handler ───────────────────────────────────────────────────────

caseResultEvent.OnClientEvent:Connect(function(spinSequence, winEffect, isDuplicate, dupIQ, dupCoins, errCode)
	if errCode == "NotEnoughCoins" then
		-- Show brief flash on coins button
		isSpinning = false
		setButtonsEnabled(true)
		local orig = coinsBtn.BackgroundColor3
		coinsBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		coinsBtn.Text = "Not enough coins!"
		task.delay(1.5, function()
			coinsBtn.BackgroundColor3 = orig
			coinsBtn.Text = "Open  ♦ 300 Coins"
		end)
		return
	end

	-- Start animation
	task.spawn(function()
		playSpin(spinSequence, function()
			-- Show result panel
			local eff = WinEffectConfig.Effects[winEffect]
			resultIconLbl.Text = eff.Icon
			resultNameLbl.Text = eff.Name
			resultNameLbl.TextColor3 = RARITY_COLORS[winEffect] or Color3.fromRGB(255, 255, 255)

			if isDuplicate then
				resultDupLbl.Text = "Already owned! +" .. dupIQ .. " IQ  +" .. dupCoins .. " Coins"
			else
				resultDupLbl.Text = "New effect unlocked!"
				resultDupLbl.TextColor3 = Color3.fromRGB(80, 255, 120)
			end

			resultPanel.Visible = true

			-- Bounce in the result panel
			resultPanel.Size = UDim2.new(0.3, 0, 0.2, 0)
			TweenService:Create(
				resultPanel,
				TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.88, 0, 0.42, 0) }
			):Play()
		end)
	end)
end)

-- ── Button logic ─────────────────────────────────────────────────────────────

coinsBtn.Activated:Connect(function()
	if isSpinning then return end
	isSpinning = true
	setButtonsEnabled(false)
	openCaseEvent:FireServer()
end)

robuxBtn.Activated:Connect(function()
	if isSpinning then return end
	local productId = RobuxConfig.CaseProduct and RobuxConfig.CaseProduct.ProductId or 0
	if productId == 0 then
		-- Not yet set up — show hint
		robuxBtn.Text = "Coming soon!"
		task.delay(2, function() robuxBtn.Text = "Open  R$ 25" end)
		return
	end
	-- Prompt purchase; ProcessReceipt → CaseGranted → CaseManager will fire CaseResult
	isSpinning = true
	setButtonsEnabled(false)
	MarketplaceService:PromptProductPurchase(player, productId)
end)

-- If the Robux purchase prompt is dismissed without buying, unlock the UI
MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, productId, wasPurchased)
	if wasPurchased then return end
	local caseProductId = RobuxConfig.CaseProduct and RobuxConfig.CaseProduct.ProductId or 0
	if productId == caseProductId and isSpinning then
		isSpinning = false
		setButtonsEnabled(true)
	end
end)

closeBtn.Activated:Connect(function()
	if isSpinning then return end
	closePanel()
end)

okBtn.Activated:Connect(function()
	closePanel()
end)

-- ── Find the case chest ProximityPrompt ──────────────────────────────────────

task.spawn(function()
	local chestsModel = workspace:WaitForChild("Chests", 30)
	if not chestsModel then return end

	local caseChest = chestsModel:WaitForChild("Case_ShopDisplay", 30)
	if not caseChest then return end

	local prompt = caseChest:WaitForChild("ProximityPrompt", 10)
	if not prompt then return end

	prompt.Triggered:Connect(function()
		if not panel.Visible then
			openPanel()
		end
	end)
end)

-- ── Shop "OPEN" button trigger ────────────────────────────────────────────────

openCaseUIEvent.Event:Connect(function()
	if not panel.Visible then
		openPanel()
	end
end)

print("[CaseUI] loaded")
