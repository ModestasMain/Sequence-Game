-- SequenceClient.lua (LocalScript in StarterGui)
-- All sizing is SCALE-based so it looks correct on every screen size and platform.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local player            = Players.LocalPlayer

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Remote Events
local remoteEvents          = ReplicatedStorage:WaitForChild("RemoteEvents")
local sequenceShowEvent     = remoteEvents:WaitForChild("SequenceShow")
local playerInputEvent      = remoteEvents:WaitForChild("PlayerInput")
local gameResultEvent       = remoteEvents:WaitForChild("GameResult")
local updateLivesEvent      = remoteEvents:WaitForChild("UpdateLives")
local countdownEvent        = remoteEvents:WaitForChild("Countdown")
local turnNotificationEvent = remoteEvents:WaitForChild("TurnNotification")
local showGameUIEvent       = remoteEvents:WaitForChild("ShowGameUI")
local sequenceFeedbackEvent = remoteEvents:WaitForChild("SequenceFeedback")
local updateTimerEvent      = remoteEvents:WaitForChild("UpdateTimer")

-- ── Sounds ──────────────────────────────────────────────────────────────────
local sequenceSounds = ReplicatedStorage:WaitForChild("SequenceSounds")
local soundInstances = {}
local camera         = workspace.CurrentCamera

for i = 1, 9 do
	local sound = sequenceSounds:FindFirstChild("Sequence" .. i)
	if sound then
		local clone = sound:Clone()
		clone.Parent = camera
		soundInstances[i] = clone
	end
end

-- ── ScreenGui ───────────────────────────────────────────────────────────────
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("SequenceUI")
screenGui.ResetOnSpawn = false

-- ══════════════════════════════════════════════════════════════════════════════
--  MAIN PANEL
--  • Height-driven: always 78 % of the viewport height
--  • UIAspectRatioConstraint keeps width = 0.78 × height on every screen
--    → portrait panel that fits mobile landscape AND desktop perfectly
-- ══════════════════════════════════════════════════════════════════════════════
local mainFrame = Instance.new("Frame")
mainFrame.Name                = "MainFrame"
mainFrame.AnchorPoint         = Vector2.new(0.5, 0.5)
mainFrame.Position            = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size                = UDim2.new(0, 0, 0.78, 0)   -- width filled by constraint
mainFrame.BackgroundColor3    = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel     = 0
mainFrame.Visible             = false
mainFrame.Parent              = screenGui

local frameAspect = Instance.new("UIAspectRatioConstraint")
frameAspect.AspectRatio  = 0.78          -- width = 0.78 × height
frameAspect.AspectType   = Enum.AspectType.ScaleWithParentSize
frameAspect.DominantAxis = Enum.DominantAxis.Height
frameAspect.Parent = mainFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.025, 0)  -- scale-based rounding
corner.Parent = mainFrame

-- ── Top row: Lives (left) + Timer (right) ─────────────────────────────────
--   All positions / sizes are Scale-based relative to mainFrame.

local HEART_ALIVE = Color3.fromRGB(255, 68, 102)
local HEART_DEAD  = Color3.fromRGB(80, 80, 80)

local function makeHeart(posX)
	local h = Instance.new("TextLabel")
	h.Size                  = UDim2.new(0.065, 0, 0.09, 0)
	h.Position              = UDim2.new(posX, 0, 0.02, 0)
	h.BackgroundTransparency = 1
	h.Text                  = "♥"
	h.TextColor3            = HEART_ALIVE
	h.TextScaled            = true
	h.Font                  = Enum.Font.GothamBold
	h.TextXAlignment        = Enum.TextXAlignment.Center
	h.Parent                = mainFrame
	return h
end

-- p1 hearts: X = 0.04, 0.115, 0.19
local p1HeartLabels = {
	makeHeart(0.04),
	makeHeart(0.115),
	makeHeart(0.19),
}

local vsLabel = Instance.new("TextLabel")
vsLabel.Name                   = "VsLabel"
vsLabel.Size                   = UDim2.new(0.05, 0, 0.09, 0)
vsLabel.Position               = UDim2.new(0.27, 0, 0.02, 0)
vsLabel.BackgroundTransparency = 1
vsLabel.Text                   = "vs"
vsLabel.TextColor3             = Color3.fromRGB(140, 140, 140)
vsLabel.TextScaled             = true
vsLabel.Font                   = Enum.Font.Gotham
vsLabel.TextXAlignment         = Enum.TextXAlignment.Center
vsLabel.Visible                = false
vsLabel.Parent                 = mainFrame

-- p2 hearts: X = 0.33, 0.405, 0.48  (multiplayer only, hidden until needed)
local p2HeartLabels = {
	makeHeart(0.33),
	makeHeart(0.405),
	makeHeart(0.48),
}
for _, h in ipairs(p2HeartLabels) do h.Visible = false end

local timerDisplay = Instance.new("TextLabel")
timerDisplay.Name                 = "TimerDisplay"
timerDisplay.Size                 = UDim2.new(0.37, 0, 0.09, 0)
timerDisplay.Position             = UDim2.new(0.61, 0, 0.02, 0)
timerDisplay.BackgroundTransparency = 1
timerDisplay.Text                 = "⏱: 10"
timerDisplay.TextColor3           = Color3.fromRGB(255, 255, 255)
timerDisplay.TextScaled           = true
timerDisplay.Font                 = Enum.Font.GothamBold
timerDisplay.TextStrokeTransparency = 0.5
timerDisplay.TextXAlignment       = Enum.TextXAlignment.Right
timerDisplay.Visible              = false
timerDisplay.Parent               = mainFrame

-- ── 3×3 Grid ────────────────────────────────────────────────────────────────
--   GridFrame is width-driven (90 % of panel width) and kept SQUARE by
--   UIAspectRatioConstraint.  UIGridLayout fills it with 9 equal buttons.

local gridFrame = Instance.new("Frame")
gridFrame.Name                 = "GridFrame"
gridFrame.AnchorPoint          = Vector2.new(0.5, 0)
gridFrame.Position             = UDim2.new(0.5, 0, 0.12, 0)
gridFrame.Size                 = UDim2.new(0.90, 0, 0, 0)   -- height = width via constraint
gridFrame.BackgroundTransparency = 1
gridFrame.Parent               = mainFrame

local gridAspect = Instance.new("UIAspectRatioConstraint")
gridAspect.AspectRatio  = 1                          -- always square
gridAspect.AspectType   = Enum.AspectType.ScaleWithParentSize
gridAspect.DominantAxis = Enum.DominantAxis.Width
gridAspect.Parent = gridFrame

--   3 cells × 31.4 % + 2 gaps × 2.9 % = 100 % — perfect fit, no overflow.
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize            = UDim2.new(0.314, 0, 0.314, 0)
gridLayout.CellPadding         = UDim2.new(0.029, 0, 0.029, 0)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
gridLayout.SortOrder           = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

-- Buttons — UIGridLayout controls their size; we only set color / rounding.
local gridButtons = {}

for row = 1, GameConfig.GRID_SIZE do
	for col = 1, GameConfig.GRID_SIZE do
		local pos = (row - 1) * GameConfig.GRID_SIZE + col

		local btn = Instance.new("TextButton")
		btn.Name             = "Square" .. pos
		btn.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
		btn.BorderSizePixel  = 0
		btn.Text             = ""
		btn.AutoButtonColor  = false
		btn.LayoutOrder      = pos
		btn.Parent           = gridFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0.08, 0)   -- scale-based, stays round on any size
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			OnSquareClick(pos)
		end)

		gridButtons[pos] = btn
	end
end

-- ── Status label (bottom of panel) ──────────────────────────────────────────
local statusLabel = Instance.new("TextLabel")
statusLabel.Name               = "StatusLabel"
statusLabel.AnchorPoint        = Vector2.new(0.5, 1)
statusLabel.Size               = UDim2.new(0.90, 0, 0.08, 0)
statusLabel.Position           = UDim2.new(0.5, 0, 0.98, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text               = "Watch the sequence..."
statusLabel.TextColor3         = Color3.fromRGB(200, 200, 200)
statusLabel.TextScaled         = true
statusLabel.Font               = Enum.Font.Gotham
statusLabel.Parent             = mainFrame

-- ── Countdown overlay (large centered, ZIndex on top) ───────────────────────
local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name            = "CountdownLabel"
countdownLabel.AnchorPoint     = Vector2.new(0.5, 0.5)
countdownLabel.Size            = UDim2.new(0.80, 0, 0.22, 0)
countdownLabel.Position        = UDim2.new(0.5, 0, 0.5, 0)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Text            = ""
countdownLabel.TextColor3      = Color3.fromRGB(255, 255, 255)
countdownLabel.TextScaled      = true
countdownLabel.Font            = Enum.Font.GothamBold
countdownLabel.Visible         = false
countdownLabel.ZIndex          = 10
countdownLabel.Parent          = mainFrame

-- ══════════════════════════════════════════════════════════════════════════════
--  GAME LOGIC  (unchanged from original)
-- ══════════════════════════════════════════════════════════════════════════════

local currentSequence  = {}
local canInput         = false
local isShowingSequence = false
local isMyTurn         = false
local isMultiplayer    = false
local lastClickTime    = {}
local playerInputs     = {}

function ShowSequence(sequence, shouldShowAnimation)
	isShowingSequence = true
	canInput          = false
	playerInputs      = {}
	lastClickTime     = {}

	for _, button in pairs(gridButtons) do
		button.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
	end

	if shouldShowAnimation then
		statusLabel.Text = "Watch the sequence..."

		for i, position in ipairs(sequence) do
			task.wait(GameConfig.SEQUENCE_GAP_TIME)
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_HIGHLIGHT_COLOR
				if soundInstances[position] then soundInstances[position]:Play() end
			end
			task.wait(GameConfig.SEQUENCE_DISPLAY_TIME)
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
			end
		end

		isShowingSequence = false
		canInput          = true
		statusLabel.Text  = "Your turn! Click the sequence..."
	else
		statusLabel.Text  = "Waiting for opponent..."
		isShowingSequence = false
		canInput          = false
	end
end

function ShowFeedback(isCorrect)
	canInput = false
	local color = isCorrect and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
	for _, button in pairs(gridButtons) do
		button.BackgroundColor3 = color
	end
	statusLabel.Text      = isCorrect and "Correct! ✓" or "Wrong! Try Again! ✗"
	statusLabel.TextColor3 = color

	task.wait(1)
	for _, button in pairs(gridButtons) do
		button.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
	end
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	playerInputs = {}
end

function OnSquareClick(position)
	if not canInput or isShowingSequence then return end

	local currentTime        = tick()
	local timeSinceLastClick = lastClickTime[position] and (currentTime - lastClickTime[position]) or 999
	lastClickTime[position]  = currentTime

	print("CLICK:", position, "| gap:", math.floor(timeSinceLastClick * 1000) .. "ms")

	if gridButtons[position] then
		gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_ACTIVE_COLOR
		task.delay(0.06, function()
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
			end
		end)
	end

	if soundInstances[position] then soundInstances[position]:Play() end

	table.insert(playerInputs, position)
	playerInputEvent:FireServer(position)
end

function ShowResult(won, sequenceLength)
	canInput = false
	if won then
		statusLabel.Text       = "YOU WIN! 🎉 Sequence: " .. sequenceLength
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		statusLabel.Text       = "YOU LOSE! Sequence: " .. sequenceLength
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	end
end

function UpdateLives(lives1, lives2)
	if lives2 > 0 then isMultiplayer = true end
	for i, h in ipairs(p1HeartLabels) do
		h.TextColor3 = (i <= lives1) and HEART_ALIVE or HEART_DEAD
	end
	if isMultiplayer then
		vsLabel.Visible = true
		for i, h in ipairs(p2HeartLabels) do
			h.Visible    = true
			h.TextColor3 = (i <= lives2) and HEART_ALIVE or HEART_DEAD
		end
	end
end

-- ── Event handlers ───────────────────────────────────────────────────────────

showGameUIEvent.OnClientEvent:Connect(function(show)
	mainFrame.Visible = show
	if not show then
		canInput          = false
		isShowingSequence = false
		isMyTurn          = false
		isMultiplayer     = false
		vsLabel.Visible   = false
		for _, h in ipairs(p1HeartLabels) do h.TextColor3 = HEART_ALIVE end
		for _, h in ipairs(p2HeartLabels) do h.Visible = false; h.TextColor3 = HEART_ALIVE end
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end)

sequenceShowEvent.OnClientEvent:Connect(function(sequence)
	currentSequence = sequence
	ShowSequence(sequence, isMyTurn)
end)

gameResultEvent.OnClientEvent:Connect(function(won, sequenceLength)
	ShowResult(won, sequenceLength)
end)

updateLivesEvent.OnClientEvent:Connect(function(lives1, lives2)
	UpdateLives(lives1, lives2)
end)

countdownEvent.OnClientEvent:Connect(function(message)
	countdownLabel.Text    = message
	countdownLabel.Visible = true
	task.delay(0.9, function()
		countdownLabel.Visible = false
	end)
end)

turnNotificationEvent.OnClientEvent:Connect(function(isYourTurn, playerName)
	isMyTurn = isYourTurn
	if isYourTurn then
		statusLabel.Text       = "YOUR TURN!"
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		statusLabel.Text       = playerName .. "'s turn - waiting..."
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	end
	task.delay(2, function()
		if not isMyTurn then
			statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end)
end)

sequenceFeedbackEvent.OnClientEvent:Connect(function(isCorrect)
	ShowFeedback(isCorrect)
end)

updateTimerEvent.OnClientEvent:Connect(function(timeRemaining, isActive)
	if isActive then
		timerDisplay.Visible = true
		timerDisplay.Text    = "⏱: " .. tostring(math.ceil(timeRemaining))

		local color
		if timeRemaining <= 3 then
			color = Color3.fromRGB(255, 100, 100)
		elseif timeRemaining <= 5 then
			color = Color3.fromRGB(255, 200, 100)
		else
			color = Color3.fromRGB(255, 255, 255)
		end
		timerDisplay.TextColor3 = color
	else
		timerDisplay.Visible = false
	end
end)

print("SequenceClient loaded for " .. player.Name)
