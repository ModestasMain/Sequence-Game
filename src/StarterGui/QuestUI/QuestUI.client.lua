-- QuestUI.client.lua
-- Standalone daily quest panel. Opened via ToggleEvent from ButtonsUI.
--!strict

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local remoteEvents          = ReplicatedStorage:WaitForChild("RemoteEvents")
local questUpdateEvent      = remoteEvents:WaitForChild("QuestUpdate")
local claimQuestEvent       = remoteEvents:WaitForChild("ClaimQuest")
local requestQuestDataEvent = remoteEvents:WaitForChild("RequestQuestData")

local QuestConfig      = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local BattlePassConfig = require(ReplicatedStorage:WaitForChild("BattlePassConfig"))

local BP_XP       = BattlePassConfig.XP.QUEST_CLAIMED  -- 150
local toggleEvent = script.Parent:WaitForChild("ToggleEvent")

-- ── Colors ───────────────────────────────────────────────────────────────────

local C_PANEL   = Color3.fromRGB(18,  18,  28)
local C_HEADER  = Color3.fromRGB(22,  22,  34)
local C_CARD    = Color3.fromRGB(24,  24,  36)
local C_GOLD    = Color3.fromRGB(255, 210,  50)
local C_GREEN   = Color3.fromRGB(70,  200, 110)
local C_BLUE    = Color3.fromRGB(100, 160, 255)
local C_GREY    = Color3.fromRGB(80,   80,  90)
local C_WHITE   = Color3.fromRGB(230, 230, 240)
local C_SUBTEXT = Color3.fromRGB(130, 130, 150)

-- ── State ────────────────────────────────────────────────────────────────────

local isOpen     = false
local timeLeft: number? = nil
local dataLoaded = false
local questCards: { [number]: { [string]: any } } = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function formatTime(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", h, m, s)
end

-- ── Root GUI ─────────────────────────────────────────────────────────────────

local screenGui = script.Parent
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 50

local backdrop = Instance.new("TextButton", screenGui)
backdrop.Text                   = ""
backdrop.AutoButtonColor        = false
backdrop.Size                   = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel        = 0
backdrop.Visible                = false
backdrop.ZIndex                 = 9

local panel = Instance.new("Frame", screenGui)
panel.Size             = UDim2.new(0.70, 0, 0.82, 0)
panel.Position         = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = C_PANEL
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.ZIndex           = 10
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = Color3.fromRGB(50, 50, 70)
panelStroke.Thickness = 1.5

-- ── Header ───────────────────────────────────────────────────────────────────

local header = Instance.new("Frame", panel)
header.Size             = UDim2.new(1, 0, 0.11, 0)
header.BackgroundColor3 = C_HEADER
header.BorderSizePixel  = 0
header.ZIndex           = 11
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local titleLabel = Instance.new("TextLabel", header)
titleLabel.Size                   = UDim2.new(0.60, 0, 0.56, 0)
titleLabel.Position               = UDim2.fromScale(0.04, 0.04)
titleLabel.BackgroundTransparency = 1
titleLabel.Text                   = "🔥  DAILY QUESTS"
titleLabel.TextColor3             = C_GOLD
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextScaled             = true
titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
titleLabel.ZIndex                 = 12

local timerLabel = Instance.new("TextLabel", header)
timerLabel.Size                   = UDim2.new(0.50, 0, 0.34, 0)
timerLabel.Position               = UDim2.fromScale(0.06, 0.62)
timerLabel.BackgroundTransparency = 1
timerLabel.Text                   = "Resets in: --:--:--"
timerLabel.TextColor3             = C_SUBTEXT
timerLabel.Font                   = Enum.Font.Gotham
timerLabel.TextScaled             = true
timerLabel.TextXAlignment         = Enum.TextXAlignment.Left
timerLabel.ZIndex                 = 12

local closeBtn = Instance.new("TextButton", header)
closeBtn.Size             = UDim2.new(0.06, 0, 0.70, 0)
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

-- ── Quest icons ───────────────────────────────────────────────────────────────

local ICONS: { [string]: string } = {
	play_solo   = "▶",
	play_1v1    = "VS",
	win_1v1     = "🏆",
	solo_seq_8  = "🧠",
	solo_seq_12 = "🧠",
}

-- ── Scroll container ──────────────────────────────────────────────────────────

local CARD_H = 110  -- fixed pixel height per card

local scrollFrame = Instance.new("ScrollingFrame", panel)
scrollFrame.Size                   = UDim2.new(1, 0, 0.89, 0)
scrollFrame.Position               = UDim2.fromScale(0, 0.11)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel        = 0
scrollFrame.ScrollBarThickness     = 4
scrollFrame.ScrollBarImageColor3   = C_GREY
scrollFrame.ZIndex                 = 11

local listLayout = Instance.new("UIListLayout", scrollFrame)
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.SortOrder     = Enum.SortOrder.LayoutOrder
listLayout.Padding       = UDim.new(0, 8)

local listPad = Instance.new("UIPadding", scrollFrame)
listPad.PaddingLeft   = UDim.new(0, 12)
listPad.PaddingRight  = UDim.new(0, 12)
listPad.PaddingTop    = UDim.new(0, 10)
listPad.PaddingBottom = UDim.new(0, 10)

-- ── Build quest cards ─────────────────────────────────────────────────────────

for i, quest in ipairs(QuestConfig.QUESTS) do
	local card = Instance.new("Frame", scrollFrame)
	card.Size             = UDim2.new(1, 0, 0, CARD_H)
	card.BackgroundColor3 = C_CARD
	card.BorderSizePixel  = 0
	card.LayoutOrder      = i
	card.ZIndex           = 12
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local cardStroke = Instance.new("UIStroke", card)
	cardStroke.Color     = Color3.fromRGB(40, 40, 60)
	cardStroke.Thickness = 1

	-- Left accent bar
	local accent = Instance.new("Frame", card)
	accent.Size             = UDim2.new(0, 4, 0.60, 0)
	accent.Position         = UDim2.new(0, 0, 0.20, 0)
	accent.BackgroundColor3 = C_GREEN
	accent.BorderSizePixel  = 0
	accent.ZIndex           = 14
	Instance.new("UICorner", accent).CornerRadius = UDim.new(1, 0)

	-- Icon background
	local iconBg = Instance.new("Frame", card)
	iconBg.Size             = UDim2.new(0, 60, 0, 60)
	iconBg.Position         = UDim2.new(0, 14, 0.5, -30)
	iconBg.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
	iconBg.BorderSizePixel  = 0
	iconBg.ZIndex           = 13
	Instance.new("UICorner", iconBg).CornerRadius = UDim.new(0, 12)

	local iconLabel = Instance.new("TextLabel", iconBg)
	iconLabel.Size                   = UDim2.fromScale(1, 1)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text                   = ICONS[quest.type] or tostring(i)
	iconLabel.TextColor3             = C_GREEN
	iconLabel.Font                   = Enum.Font.GothamBold
	iconLabel.TextScaled             = true
	iconLabel.ZIndex                 = 14

	-- Quest name
	local nameLabel = Instance.new("TextLabel", card)
	nameLabel.Size                   = UDim2.new(0.48, 0, 0, 28)
	nameLabel.Position               = UDim2.new(0, 88, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                   = quest.name
	nameLabel.TextColor3             = C_WHITE
	nameLabel.Font                   = Enum.Font.GothamBold
	nameLabel.TextScaled             = true
	nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
	nameLabel.ZIndex                 = 13

	-- Description
	local descLabel = Instance.new("TextLabel", card)
	descLabel.Size                   = UDim2.new(0.52, 0, 0, 20)
	descLabel.Position               = UDim2.new(0, 88, 0, 40)
	descLabel.BackgroundTransparency = 1
	descLabel.Text                   = quest.desc
	descLabel.TextColor3             = C_SUBTEXT
	descLabel.Font                   = Enum.Font.Gotham
	descLabel.TextScaled             = true
	descLabel.TextXAlignment         = Enum.TextXAlignment.Left
	descLabel.ZIndex                 = 13

	-- Coin reward badge (fixed pixel width so gap stays consistent)
	local coinBadge = Instance.new("Frame", card)
	coinBadge.Size             = UDim2.new(0, 120, 0, 22)
	coinBadge.Position         = UDim2.new(0, 88, 0, 66)
	coinBadge.BackgroundColor3 = Color3.fromRGB(45, 35, 8)
	coinBadge.BorderSizePixel  = 0
	coinBadge.ZIndex           = 13
	Instance.new("UICorner", coinBadge).CornerRadius = UDim.new(0, 6)

	local coinLabel = Instance.new("TextLabel", coinBadge)
	coinLabel.Size                   = UDim2.fromScale(1, 1)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Text                   = "+" .. quest.reward .. " Coins"
	coinLabel.TextColor3             = C_GOLD
	coinLabel.Font                   = Enum.Font.GothamBold
	coinLabel.TextScaled             = true
	coinLabel.ZIndex                 = 14

	-- BP XP badge (starts 10px after coin badge)
	local xpBadge = Instance.new("Frame", card)
	xpBadge.Size             = UDim2.new(0, 90, 0, 22)
	xpBadge.Position         = UDim2.new(0, 218, 0, 66)   -- 88 + 120 + 10 gap
	xpBadge.BackgroundColor3 = Color3.fromRGB(15, 25, 55)
	xpBadge.BorderSizePixel  = 0
	xpBadge.ZIndex           = 13
	Instance.new("UICorner", xpBadge).CornerRadius = UDim.new(0, 6)

	local xpLabel = Instance.new("TextLabel", xpBadge)
	xpLabel.Size                   = UDim2.fromScale(1, 1)
	xpLabel.BackgroundTransparency = 1
	xpLabel.Text                   = "+" .. BP_XP .. " XP"
	xpLabel.TextColor3             = C_BLUE
	xpLabel.Font                   = Enum.Font.GothamBold
	xpLabel.TextScaled             = true
	xpLabel.ZIndex                 = 14

	-- Progress bar track (extends to near the claim button)
	local barTrack = Instance.new("Frame", card)
	barTrack.Size             = UDim2.new(0.60, 0, 0, 6)
	barTrack.Position         = UDim2.new(0, 88, 1, -16)
	barTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	barTrack.BorderSizePixel  = 0
	barTrack.ZIndex           = 13
	Instance.new("UICorner", barTrack).CornerRadius = UDim.new(1, 0)

	local barFill = Instance.new("Frame", barTrack)
	barFill.Size             = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = C_GREEN
	barFill.BorderSizePixel  = 0
	barFill.ZIndex           = 14
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

	-- Progress count (right-aligned just after bar end)
	local progLabel = Instance.new("TextLabel", card)
	progLabel.Size                   = UDim2.new(0.10, 0, 0, 22)
	progLabel.Position               = UDim2.new(0.62, 0, 1, -22)
	progLabel.BackgroundTransparency = 1
	progLabel.Text                   = "0/" .. quest.target
	progLabel.TextColor3             = C_SUBTEXT
	progLabel.Font                   = Enum.Font.Gotham
	progLabel.TextScaled             = true
	progLabel.ZIndex                 = 13

	-- Claim button
	local claimBtn = Instance.new("TextButton", card)
	claimBtn.Size             = UDim2.new(0.17, 0, 0, 64)
	claimBtn.Position         = UDim2.new(0.81, 0, 0.5, -32)
	claimBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	claimBtn.Text             = "CLAIM"
	claimBtn.TextColor3       = C_GREY
	claimBtn.Font             = Enum.Font.GothamBold
	claimBtn.TextScaled       = true
	claimBtn.BorderSizePixel  = 0
	claimBtn.AutoButtonColor  = false
	claimBtn.ZIndex           = 14
	Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 10)

	local idx = i
	claimBtn.MouseButton1Click:Connect(function()
		claimQuestEvent:FireServer(idx)
	end)

	questCards[i] = {
		card       = card,
		accent     = accent,
		iconBg     = iconBg,
		iconLabel  = iconLabel,
		barFill    = barFill,
		progLabel  = progLabel,
		claimBtn   = claimBtn,
		cardStroke = cardStroke,
	}
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 20)
end)

-- ── Refresh UI ───────────────────────────────────────────────────────────────

local function updateQuestUI(status: { [string]: any })
	if not status then return end

	dataLoaded = true
	timeLeft   = status.TimeLeft or 0
	timerLabel.Text = "Resets in: " .. formatTime(timeLeft :: number)

	for i, quest in ipairs(QuestConfig.QUESTS) do
		local c       = questCards[i]
		local prog    = status.Progress[i] or 0
		local claimed = status.Claimed[i]  or false
		local done    = prog >= quest.target
		local fill    = math.clamp(prog / quest.target, 0, 1)

		c.progLabel.Text = math.min(prog, quest.target) .. "/" .. quest.target
		TweenService:Create(c.barFill, TweenInfo.new(0.4), { Size = UDim2.fromScale(fill, 1) }):Play()

		if claimed then
			c.card.BackgroundColor3    = Color3.fromRGB(18, 28, 18)
			c.cardStroke.Color         = Color3.fromRGB(35, 65, 35)
			c.accent.BackgroundColor3  = Color3.fromRGB(40, 80, 40)
			c.iconBg.BackgroundColor3  = Color3.fromRGB(22, 42, 22)
			c.iconLabel.TextColor3     = Color3.fromRGB(55, 140, 55)
			c.barFill.BackgroundColor3 = Color3.fromRGB(45, 110, 45)
			c.claimBtn.Text             = "✓"
			c.claimBtn.BackgroundColor3 = Color3.fromRGB(28, 55, 28)
			c.claimBtn.TextColor3       = Color3.fromRGB(55, 150, 55)
			c.claimBtn.Active           = false
		elseif done then
			-- Ready to claim — gold highlight
			c.card.BackgroundColor3    = Color3.fromRGB(26, 24, 14)
			c.cardStroke.Color         = Color3.fromRGB(70, 58, 18)
			c.accent.BackgroundColor3  = C_GOLD
			c.iconBg.BackgroundColor3  = Color3.fromRGB(52, 42, 10)
			c.iconLabel.TextColor3     = C_GOLD
			c.barFill.BackgroundColor3 = C_GOLD
			c.claimBtn.Text             = "CLAIM"
			c.claimBtn.BackgroundColor3 = C_GOLD
			c.claimBtn.TextColor3       = Color3.fromRGB(15, 12, 4)
			c.claimBtn.Active           = true
		else
			-- In progress
			c.card.BackgroundColor3    = C_CARD
			c.cardStroke.Color         = Color3.fromRGB(40, 40, 60)
			c.accent.BackgroundColor3  = C_GREEN
			c.iconBg.BackgroundColor3  = Color3.fromRGB(30, 50, 30)
			c.iconLabel.TextColor3     = C_GREEN
			c.barFill.BackgroundColor3 = C_GREEN
			c.claimBtn.Text             = "CLAIM"
			c.claimBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			c.claimBtn.TextColor3       = C_GREY
			c.claimBtn.Active           = false
		end
	end
end

-- ── Open / close ─────────────────────────────────────────────────────────────

local function open()
	isOpen = true
	backdrop.Visible = true
	panel.Visible    = true
	panel.Size       = UDim2.new(0.70, 0, 0.01, 0)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.70, 0, 0.82, 0),
	}):Play()
end

local function close()
	isOpen = false
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0.70, 0, 0.01, 0),
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

-- ── Timer countdown ───────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(1)
		if dataLoaded and timeLeft then
			if timeLeft > 0 then timeLeft = (timeLeft :: number) - 1 end
			timerLabel.Text = "Resets in: " .. formatTime(timeLeft :: number)
		end
	end
end)

-- ── Server events ─────────────────────────────────────────────────────────────

questUpdateEvent.OnClientEvent:Connect(updateQuestUI)
requestQuestDataEvent:FireServer()
