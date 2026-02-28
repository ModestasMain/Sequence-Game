-- BattlePassUI.client.lua
-- Battle Pass panel: XP progress, 30 tier cards, free/premium claiming.
--!strict

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local bpDataEvent     = remoteEvents:WaitForChild("BattlePassData")
local claimTierEvent  = remoteEvents:WaitForChild("ClaimBattlePassTier")
local buyPremiumEvent = remoteEvents:WaitForChild("BuyBattlePassPremium")

-- ── Colours ────────────────────────────────────────────────────────────────

local COL_BG        = Color3.fromRGB(12,  12,  18)
local COL_PANEL     = Color3.fromRGB(18,  18,  28)
local COL_CARD      = Color3.fromRGB(24,  24,  36)
local COL_GOLD      = Color3.fromRGB(255, 210,  50)
local COL_PREM      = Color3.fromRGB(255, 180,  30)
local COL_GREEN     = Color3.fromRGB(80,  210, 120)
local COL_GREY      = Color3.fromRGB(80,   80,  90)
local COL_LOCKED    = Color3.fromRGB(40,  40,  52)
local COL_WHITE     = Color3.fromRGB(230, 230, 240)
local COL_SUBTEXT   = Color3.fromRGB(130, 130, 150)

-- ── State ──────────────────────────────────────────────────────────────────

local bpState: {}? = nil
local isOpen       = false
local tierCards: {{}} = {}  -- array of {frame, freeBtn, premBtn}

-- ── Root GUI ───────────────────────────────────────────────────────────────

local screenGui = script.Parent
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 50

-- ── Toggle event (fired by the button in ButtonsUI) ────────────────────────

local toggleEvent = script.Parent:WaitForChild("ToggleEvent")

-- ── Main panel ─────────────────────────────────────────────────────────────

local panel = Instance.new("Frame", screenGui)
panel.Size             = UDim2.new(0.82, 0, 0.72, 0)
panel.Position         = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = COL_PANEL
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.ZIndex           = 10
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = Color3.fromRGB(50, 50, 70)
panelStroke.Thickness = 1.5

-- Dim backdrop
local backdrop = Instance.new("TextButton", screenGui)
backdrop.Text                   = ""
backdrop.AutoButtonColor        = false
backdrop.Size                   = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel        = 0
backdrop.Visible                = false
backdrop.ZIndex                 = 9

-- ── Header row ─────────────────────────────────────────────────────────────

local header = Instance.new("Frame", panel)
header.Size             = UDim2.new(1, 0, 0.11, 0)
header.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
header.BorderSizePixel  = 0
header.ZIndex           = 11
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)

local titleLabel = Instance.new("TextLabel", header)
titleLabel.Size                   = UDim2.new(0.6, 0, 0.58, 0)
titleLabel.Position               = UDim2.fromScale(0.04, 0.02)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "🎖  BATTLE PASS"
titleLabel.TextColor3             = COL_GOLD
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextScaled             = true
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.ZIndex                 = 12

local seasonLabel = Instance.new("TextLabel", header)
seasonLabel.Size                   = UDim2.new(0.25, 0, 0.32, 0)
seasonLabel.Position               = UDim2.fromScale(0.06, 0.64)
seasonLabel.BackgroundTransparency = 1
seasonLabel.Text                   = "Season 1"
seasonLabel.TextColor3             = COL_SUBTEXT
seasonLabel.Font                   = Enum.Font.Gotham
seasonLabel.TextScaled             = true
seasonLabel.TextXAlignment         = Enum.TextXAlignment.Left
seasonLabel.ZIndex                 = 12

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size             = UDim2.new(0.06, 0, 0.7, 0)
closeBtn.Position         = UDim2.new(0.93, 0, 0.15, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
closeBtn.Text             = "X"
closeBtn.TextColor3       = Color3.fromRGB(220, 100, 100)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextScaled       = true
closeBtn.BorderSizePixel  = 0
closeBtn.AutoButtonColor  = false
closeBtn.ZIndex           = 12
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- ── XP bar row ─────────────────────────────────────────────────────────────

local xpRow = Instance.new("Frame", panel)
xpRow.Size             = UDim2.new(1, 0, 0.13, 0)
xpRow.Position         = UDim2.fromScale(0, 0.11)
xpRow.BackgroundTransparency = 1
xpRow.BorderSizePixel  = 0
xpRow.ZIndex           = 11

local xpLabel = Instance.new("TextLabel", xpRow)
xpLabel.Size                   = UDim2.new(0.4, 0, 0.55, 0)
xpLabel.Position               = UDim2.fromScale(0.04, 0.05)
xpLabel.BackgroundTransparency = 1
xpLabel.Text                   = "XP: 0 / 500"
xpLabel.TextColor3             = COL_WHITE
xpLabel.Font                   = Enum.Font.GothamBold
xpLabel.TextScaled             = true
xpLabel.TextXAlignment         = Enum.TextXAlignment.Left
xpLabel.ZIndex                 = 12

local tierLabel = Instance.new("TextLabel", xpRow)
tierLabel.Size                   = UDim2.new(0.3, 0, 0.55, 0)
tierLabel.Position               = UDim2.fromScale(0.44, 0.05)
tierLabel.BackgroundTransparency = 1
tierLabel.Text                   = "Tier 0 / 30"
tierLabel.TextColor3             = COL_SUBTEXT
tierLabel.Font                   = Enum.Font.Gotham
tierLabel.TextScaled             = true
tierLabel.TextXAlignment         = Enum.TextXAlignment.Center
tierLabel.ZIndex                 = 12

-- Premium button (right side of XP row)
local premBtn = Instance.new("TextButton", xpRow)
premBtn.Size             = UDim2.new(0.22, 0, 0.72, 0)
premBtn.Position         = UDim2.new(0.77, 0, 0.14, 0)
premBtn.BackgroundColor3 = COL_PREM
premBtn.Text             = "GET PREMIUM\n399 R$"
premBtn.TextColor3       = Color3.fromRGB(20, 20, 20)
premBtn.Font             = Enum.Font.GothamBold
premBtn.TextScaled       = true
premBtn.BorderSizePixel  = 0
premBtn.AutoButtonColor  = false
premBtn.ZIndex           = 12
Instance.new("UICorner", premBtn).CornerRadius = UDim.new(0, 8)

-- XP bar track
local xpTrack = Instance.new("Frame", xpRow)
xpTrack.Size             = UDim2.new(0.7, 0, 0.22, 0)
xpTrack.Position         = UDim2.fromScale(0.04, 0.72)
xpTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
xpTrack.BorderSizePixel  = 0
xpTrack.ZIndex           = 12
Instance.new("UICorner", xpTrack).CornerRadius = UDim.new(1, 0)

local xpFill = Instance.new("Frame", xpTrack)
xpFill.Size             = UDim2.fromScale(0, 1)
xpFill.BackgroundColor3 = COL_GOLD
xpFill.BorderSizePixel  = 0
xpFill.ZIndex           = 13
Instance.new("UICorner", xpFill).CornerRadius = UDim.new(1, 0)

-- ── Tier scroll ────────────────────────────────────────────────────────────

local scrollFrame = Instance.new("ScrollingFrame", panel)
scrollFrame.Size                  = UDim2.new(1, -16, 0.72, 0)
scrollFrame.Position              = UDim2.fromScale(0, 0.26)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel       = 0
scrollFrame.ScrollBarThickness    = 4
scrollFrame.ScrollBarImageColor3  = COL_GREY
scrollFrame.CanvasSize            = UDim2.fromOffset(0, 0)  -- set dynamically
scrollFrame.ZIndex                = 11

local listLayout = Instance.new("UIListLayout", scrollFrame)
listLayout.FillDirection  = Enum.FillDirection.Horizontal
listLayout.SortOrder      = Enum.SortOrder.LayoutOrder
listLayout.Padding        = UDim.new(0, 6)

local scrollPad = Instance.new("UIPadding", scrollFrame)
scrollPad.PaddingLeft   = UDim.new(0, 8)
scrollPad.PaddingRight  = UDim.new(0, 8)
scrollPad.PaddingTop    = UDim.new(0, 6)
scrollPad.PaddingBottom = UDim.new(0, 6)

-- ── Build tier cards (once, static layout) ─────────────────────────────────

local CARD_W = 90
local CARD_H_SCALE = 0.90  -- relative to scrollFrame height

for i = 1, 30 do
	local card = Instance.new("Frame", scrollFrame)
	card.Size             = UDim2.new(0, CARD_W, CARD_H_SCALE, 0)
	card.BackgroundColor3 = COL_CARD
	card.BorderSizePixel  = 0
	card.LayoutOrder      = i
	card.ZIndex           = 12
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	-- Tier number header
	local numBg = Instance.new("Frame", card)
	numBg.Size             = UDim2.new(1, 0, 0.18, 0)
	numBg.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
	numBg.BorderSizePixel  = 0
	numBg.ZIndex           = 13
	Instance.new("UICorner", numBg).CornerRadius = UDim.new(0, 10)

	local numLabel = Instance.new("TextLabel", numBg)
	numLabel.Size                   = UDim2.fromScale(1, 1)
	numLabel.BackgroundTransparency = 1
	numLabel.Text                   = tostring(i)
	numLabel.TextColor3             = COL_SUBTEXT
	numLabel.Font                   = Enum.Font.GothamBold
	numLabel.TextScaled             = true
	numLabel.ZIndex                 = 14

	-- FREE section label
	local freeTag = Instance.new("TextLabel", card)
	freeTag.Size                   = UDim2.new(1, 0, 0.1, 0)
	freeTag.Position               = UDim2.fromScale(0, 0.19)
	freeTag.BackgroundTransparency = 1
	freeTag.Text                   = "FREE"
	freeTag.TextColor3             = COL_GREEN
	freeTag.Font                   = Enum.Font.GothamBold
	freeTag.TextScaled             = true
	freeTag.ZIndex                 = 13

	-- FREE reward display
	local freeReward = Instance.new("TextLabel", card)
	freeReward.Size                   = UDim2.new(1, -4, 0.18, 0)
	freeReward.Position               = UDim2.fromScale(0, 0.30)
	freeReward.BackgroundTransparency = 1
	freeReward.Text                   = "..."
	freeReward.TextColor3             = COL_WHITE
	freeReward.Font                   = Enum.Font.Gotham
	freeReward.TextScaled             = true
	freeReward.ZIndex                 = 13

	-- FREE claim button
	local freeClaimBtn = Instance.new("TextButton", card)
	freeClaimBtn.Size             = UDim2.new(0.88, 0, 0.13, 0)
	freeClaimBtn.Position         = UDim2.fromScale(0.06, 0.49)
	freeClaimBtn.BackgroundColor3 = COL_GREEN
	freeClaimBtn.Text             = "CLAIM"
	freeClaimBtn.TextColor3       = Color3.fromRGB(10, 10, 18)
	freeClaimBtn.Font             = Enum.Font.GothamBold
	freeClaimBtn.TextScaled       = true
	freeClaimBtn.BorderSizePixel  = 0
	freeClaimBtn.AutoButtonColor  = false
	freeClaimBtn.ZIndex           = 14
	Instance.new("UICorner", freeClaimBtn).CornerRadius = UDim.new(0, 6)

	-- Divider
	local divider = Instance.new("Frame", card)
	divider.Size             = UDim2.new(0.85, 0, 0, 1)
	divider.Position         = UDim2.fromScale(0.075, 0.64)
	divider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	divider.BorderSizePixel  = 0
	divider.ZIndex           = 13

	-- PREMIUM section label
	local premTag = Instance.new("TextLabel", card)
	premTag.Size                   = UDim2.new(1, 0, 0.1, 0)
	premTag.Position               = UDim2.fromScale(0, 0.65)
	premTag.BackgroundTransparency = 1
	premTag.Text                   = "PREMIUM"
	premTag.TextColor3             = COL_PREM
	premTag.Font                   = Enum.Font.GothamBold
	premTag.TextScaled             = true
	premTag.ZIndex                 = 13

	-- PREMIUM reward display
	local premReward = Instance.new("TextLabel", card)
	premReward.Size                   = UDim2.new(1, -4, 0.14, 0)
	premReward.Position               = UDim2.fromScale(0, 0.75)
	premReward.BackgroundTransparency = 1
	premReward.Text                   = "..."
	premReward.TextColor3             = COL_WHITE
	premReward.Font                   = Enum.Font.Gotham
	premReward.TextScaled             = true
	premReward.ZIndex                 = 13

	-- PREMIUM claim button
	local premClaimBtn = Instance.new("TextButton", card)
	premClaimBtn.Size             = UDim2.new(0.88, 0, 0.1, 0)
	premClaimBtn.Position         = UDim2.fromScale(0.06, 0.89)
	premClaimBtn.BackgroundColor3 = COL_PREM
	premClaimBtn.Text             = "CLAIM"
	premClaimBtn.TextColor3       = Color3.fromRGB(10, 10, 18)
	premClaimBtn.Font             = Enum.Font.GothamBold
	premClaimBtn.TextScaled       = true
	premClaimBtn.BorderSizePixel  = 0
	premClaimBtn.AutoButtonColor  = false
	premClaimBtn.ZIndex           = 14
	Instance.new("UICorner", premClaimBtn).CornerRadius = UDim.new(0, 6)

	local tierIndex = i
	freeClaimBtn.MouseButton1Click:Connect(function()
		claimTierEvent:FireServer(tierIndex, "free")
	end)
	premClaimBtn.MouseButton1Click:Connect(function()
		claimTierEvent:FireServer(tierIndex, "premium")
	end)

	tierCards[i] = {
		card        = card,
		numLabel    = numLabel,
		freeReward  = freeReward,
		freeBtn     = freeClaimBtn,
		premReward  = premReward,
		premBtn     = premClaimBtn,
		premTag     = premTag,
	}
end

-- Update canvas size after cards are laid out
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.fromOffset(listLayout.AbsoluteContentSize.X + 16, 0)
end)

-- ── Render state ───────────────────────────────────────────────────────────

local function rewardText(reward: {}): string
	if reward.title then
		return "★ " .. reward.title:gsub("(%u)", " %1"):gsub("^ ", "")
	end
	return "+" .. tostring(reward.coins) .. " Coins"
end

local function refreshUI(state: {})
	local tier    = state.tier
	local xp      = state.xp
	local xpPT    = state.xpPerTier
	local premium = state.premium

	-- XP bar
	local progress = (xp % xpPT) / xpPT
	if tier >= state.maxTiers then progress = 1 end
	TweenService:Create(xpFill, TweenInfo.new(0.4), {Size = UDim2.fromScale(progress, 1)}):Play()
	xpLabel.Text  = string.format("XP: %d / %d", xp % xpPT, xpPT)
	tierLabel.Text = string.format("Tier %d / %d", tier, state.maxTiers)
	seasonLabel.Text = "Season " .. tostring(state.season)

	-- Premium button
	if premium then
		premBtn.Text             = "⭐ PREMIUM ACTIVE"
		premBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
		premBtn.TextColor3       = COL_PREM
		premBtn.Active           = false
	else
		premBtn.Text             = "GET PREMIUM\n" .. tostring(state.robux) .. " R$"
		premBtn.BackgroundColor3 = COL_PREM
		premBtn.TextColor3       = Color3.fromRGB(20, 20, 20)
		premBtn.Active           = true
	end

	-- Tier cards
	for i, cardData in ipairs(tierCards) do
		local tConfig    = state.tiers[i]
		local reached    = (tier >= i)
		local freeClaimed  = state.freeClaimed[i] == true
		local premClaimed  = state.premiumClaimed[i] == true

		-- Card background
		if freeClaimed and (premClaimed or not premium) then
			cardData.card.BackgroundColor3 = Color3.fromRGB(20, 36, 20)  -- completed
			cardData.numLabel.TextColor3   = COL_GOLD
		elseif reached then
			cardData.card.BackgroundColor3 = COL_CARD
			cardData.numLabel.TextColor3   = COL_WHITE
		else
			cardData.card.BackgroundColor3 = COL_LOCKED
			cardData.numLabel.TextColor3   = COL_GREY
		end

		-- Free reward text & button
		if tConfig and tConfig.free then
			cardData.freeReward.Text = rewardText(tConfig.free)
		end
		if freeClaimed then
			cardData.freeBtn.Text             = "✓"
			cardData.freeBtn.BackgroundColor3 = Color3.fromRGB(40, 70, 40)
			cardData.freeBtn.TextColor3       = COL_GREEN
			cardData.freeBtn.Active           = false
		elseif reached then
			cardData.freeBtn.Text             = "CLAIM"
			cardData.freeBtn.BackgroundColor3 = COL_GREEN
			cardData.freeBtn.TextColor3       = Color3.fromRGB(10, 10, 18)
			cardData.freeBtn.Active           = true
		else
			-- Tier not yet reached — greyed out CLAIM, no lock
			cardData.freeBtn.Text             = "CLAIM"
			cardData.freeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			cardData.freeBtn.TextColor3       = COL_GREY
			cardData.freeBtn.Active           = false
		end

		-- Premium reward text & button
		if tConfig and tConfig.premium then
			cardData.premReward.Text = rewardText(tConfig.premium)
		end
		local premTagColor = premium and COL_PREM or COL_GREY
		cardData.premTag.TextColor3 = premTagColor

		if premClaimed then
			cardData.premBtn.Text             = "✓"
			cardData.premBtn.BackgroundColor3 = Color3.fromRGB(60, 45, 10)
			cardData.premBtn.TextColor3       = COL_PREM
			cardData.premBtn.Active           = false
		elseif not premium then
			-- No premium pass — locked behind purchase
			cardData.premBtn.Text             = "🔒"
			cardData.premBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			cardData.premBtn.TextColor3       = COL_GREY
			cardData.premBtn.Active           = false
		elseif reached then
			-- Has premium, tier reached — claimable
			cardData.premBtn.Text             = "CLAIM"
			cardData.premBtn.BackgroundColor3 = COL_PREM
			cardData.premBtn.TextColor3       = Color3.fromRGB(10, 10, 18)
			cardData.premBtn.Active           = true
		else
			-- Has premium, tier not yet reached — greyed out CLAIM
			cardData.premBtn.Text             = "CLAIM"
			cardData.premBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			cardData.premBtn.TextColor3       = COL_GREY
			cardData.premBtn.Active           = false
		end
	end
end

-- ── Open / close ───────────────────────────────────────────────────────────

local function open()
	isOpen = true
	backdrop.Visible = true
	panel.Visible    = true
	panel.Size       = UDim2.new(0.82, 0, 0.01, 0)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.82, 0, 0.72, 0),
	}):Play()
	if bpState then refreshUI(bpState) end
end

local function close()
	isOpen = false
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0.82, 0, 0.01, 0),
	}):Play()
	task.delay(0.2, function()
		panel.Visible    = false
		backdrop.Visible = false
	end)
end

toggleEvent.Event:Connect(function()
	if isOpen then close() else open() end
end)
closeBtn.MouseButton1Click:Connect(close)
backdrop.MouseButton1Click:Connect(close)

premBtn.MouseButton1Click:Connect(function()
	if bpState and not bpState.premium then
		buyPremiumEvent:FireServer()
	end
end)

-- ── Receive data from server ───────────────────────────────────────────────

bpDataEvent.OnClientEvent:Connect(function(state: {})
	bpState = state
	if isOpen then refreshUI(state) end
end)
