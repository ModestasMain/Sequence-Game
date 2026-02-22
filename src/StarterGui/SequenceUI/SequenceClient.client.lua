-- SequenceClient.lua (LocalScript in StarterGui)
-- All sizing is SCALE-based so it looks correct on every screen size and platform.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local player            = Players.LocalPlayer

local GameConfig  = require(ReplicatedStorage:WaitForChild("GameConfig"))
local ThemeConfig = require(ReplicatedStorage:WaitForChild("ThemeConfig"))
local SoundConfig = require(ReplicatedStorage:WaitForChild("SoundConfig"))

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
local themeDataEvent        = remoteEvents:WaitForChild("ThemeData")
local soundDataEvent        = remoteEvents:WaitForChild("SoundData")
local playWinSoundEvent     = remoteEvents:WaitForChild("PlayWinSound")

-- Theme state
local currentTheme = ThemeConfig.Themes["Default"]

-- Sound pack state (independent of theme)
local equippedSoundPack = SoundConfig.Packs["Default"]

-- ── Sounds ──────────────────────────────────────────────────────────────────
local sequenceSounds = ReplicatedStorage:WaitForChild("SequenceSounds")
local soundInstances = {}
local camera         = workspace.CurrentCamera

-- Original per-position sounds (used by Default theme)
for i = 1, 9 do
	local sound = sequenceSounds:FindFirstChild("Sequence" .. i)
	if sound then
		local clone = sound:Clone()
		clone.Parent = camera
		soundInstances[i] = clone
	end
end

-- Theme soundpack: one click sound pitched per grid position, plus correct/wrong stings
-- Pitch multipliers for positions 1-9 — roughly a major scale
local PITCH_MAP = {0.70, 0.79, 0.89, 1.00, 1.12, 1.26, 1.41, 1.59, 1.78}

local clickSound   = Instance.new("Sound"); clickSound.Parent   = camera
local correctSound = Instance.new("Sound"); correctSound.Parent = camera
local wrongSound   = Instance.new("Sound"); wrongSound.Parent   = camera

local function applyThemeSounds(theme)
	-- Only apply theme sounds if no custom sound pack is equipped
	if equippedSoundPack and equippedSoundPack.Click ~= nil then return end
	local s = theme and theme.Sounds
	clickSound.SoundId   = (s and s.Click   or "")
	correctSound.SoundId = (s and s.Correct or "")
	wrongSound.SoundId   = (s and s.Wrong   or "")
end

local function applySoundPack(pack)
	equippedSoundPack = pack
	if pack and pack.Click ~= nil then
		-- Sound pack overrides theme sounds
		clickSound.SoundId   = pack.Click   or ""
		correctSound.SoundId = pack.Correct or ""
		wrongSound.SoundId   = pack.Wrong   or ""
	else
		-- Default pack: fall back to current theme sounds
		applyThemeSounds(currentTheme)
	end
end

local function playClickSound(position)
	if clickSound.SoundId ~= "" then
		-- Modulo so positions 10-25 (5x5 mode) still get a valid pitch
		clickSound.PlaybackSpeed = PITCH_MAP[((position - 1) % #PITCH_MAP) + 1]
		clickSound:Play()
	else
		-- Default per-position sounds only cover 1-9; cycle for higher positions
		local fallbackIdx = ((position - 1) % 9) + 1
		local si = soundInstances[position] or soundInstances[fallbackIdx]
		if si then si:Play() end
	end
end

-- ── ScreenGui ───────────────────────────────────────────────────────────────
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("SequenceUI")
screenGui.ResetOnSpawn = false

-- ══════════════════════════════════════════════════════════════════════════════
--  MAIN PANEL
-- ══════════════════════════════════════════════════════════════════════════════
local mainFrame = Instance.new("Frame")
mainFrame.Name                = "MainFrame"
mainFrame.AnchorPoint         = Vector2.new(0.5, 0.5)
mainFrame.Position            = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.Size                = UDim2.new(0, 0, 0.78, 0)
mainFrame.BackgroundColor3    = currentTheme.Colors.Panel
mainFrame.BorderSizePixel     = 0
mainFrame.Visible             = false
mainFrame.Parent              = screenGui

local frameAspect = Instance.new("UIAspectRatioConstraint")
frameAspect.AspectRatio  = 0.78
frameAspect.AspectType   = Enum.AspectType.ScaleWithParentSize
frameAspect.DominantAxis = Enum.DominantAxis.Height
frameAspect.Parent = mainFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.025, 0)
corner.Parent = mainFrame

-- ── Top row: Lives + Timer ────────────────────────────────────────────────

local function makeHeart(posX)
	local h = Instance.new("TextLabel")
	h.Size                  = UDim2.new(0.065, 0, 0.09, 0)
	h.Position              = UDim2.new(posX, 0, 0.02, 0)
	h.BackgroundTransparency = 1
	h.Text                  = "♥"
	h.TextColor3            = currentTheme.Colors.HeartAlive
	h.TextScaled            = true
	h.Font                  = Enum.Font.GothamBold
	h.TextXAlignment        = Enum.TextXAlignment.Center
	h.Parent                = mainFrame
	return h
end

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

local gridFrame = Instance.new("Frame")
gridFrame.Name                 = "GridFrame"
gridFrame.AnchorPoint          = Vector2.new(0.5, 0)
gridFrame.Position             = UDim2.new(0.5, 0, 0.12, 0)
gridFrame.Size                 = UDim2.new(0.90, 0, 0, 0)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent               = mainFrame

local gridAspect = Instance.new("UIAspectRatioConstraint")
gridAspect.AspectRatio  = 1
gridAspect.AspectType   = Enum.AspectType.ScaleWithParentSize
gridAspect.DominantAxis = Enum.DominantAxis.Width
gridAspect.Parent = gridFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize            = UDim2.new(0.314, 0, 0.314, 0)
gridLayout.CellPadding         = UDim2.new(0.029, 0, 0.029, 0)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
gridLayout.SortOrder           = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local gridButtons = {}

for row = 1, GameConfig.GRID_SIZE do
	for col = 1, GameConfig.GRID_SIZE do
		local pos = (row - 1) * GameConfig.GRID_SIZE + col

		local btn = Instance.new("TextButton")
		btn.Name             = "Square" .. pos
		btn.BackgroundColor3 = currentTheme.Colors.Square
		btn.BorderSizePixel  = 0
		btn.AutoButtonColor  = false
		btn.LayoutOrder      = pos
		btn.Text             = currentTheme.SquareIcon or ""
		btn.TextColor3       = currentTheme.Colors.Highlight
		btn.TextTransparency = (currentTheme.SquareIcon and currentTheme.SquareIcon ~= "") and 0.3 or 1
		btn.TextScaled       = true
		btn.Font             = Enum.Font.GothamBold
		btn.Parent           = gridFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0.08, 0)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			OnSquareClick(pos)
		end)

		gridButtons[pos] = btn
	end
end

-- Rebuilds the button grid for the given grid size (3 or 5).
-- Called each time ShowGameUI fires with show=true so 3x3 and 5x5 share the same UI.
local function rebuildGrid(newGridSize)
	-- Destroy existing buttons
	for _, btn in pairs(gridButtons) do
		btn:Destroy()
	end
	gridButtons = {}

	-- Adjust UIGridLayout cell sizes to fill the square frame
	if newGridSize == 5 then
		gridLayout.CellSize    = UDim2.new(0.186, 0, 0.186, 0)
		gridLayout.CellPadding = UDim2.new(0.017, 0, 0.017, 0)
	else
		gridLayout.CellSize    = UDim2.new(0.314, 0, 0.314, 0)
		gridLayout.CellPadding = UDim2.new(0.029, 0, 0.029, 0)
	end

	local hasIcon = currentTheme.SquareIcon and currentTheme.SquareIcon ~= ""
	for row = 1, newGridSize do
		for col = 1, newGridSize do
			local pos = (row - 1) * newGridSize + col

			local btn = Instance.new("TextButton")
			btn.Name             = "Square" .. pos
			btn.BackgroundColor3 = currentTheme.Colors.Square
			btn.BorderSizePixel  = 0
			btn.AutoButtonColor  = false
			btn.LayoutOrder      = pos
			btn.Text             = currentTheme.SquareIcon or ""
			btn.TextColor3       = currentTheme.Colors.Highlight
			btn.TextTransparency = hasIcon and 0.3 or 1
			btn.TextScaled       = true
			btn.Font             = Enum.Font.GothamBold
			btn.Parent           = gridFrame

			local btnCorner = Instance.new("UICorner")
			btnCorner.CornerRadius = UDim.new(0.08, 0)
			btnCorner.Parent = btn

			btn.MouseButton1Click:Connect(function()
				OnSquareClick(pos)
			end)

			gridButtons[pos] = btn
		end
	end
end

-- ── Status label ──────────────────────────────────────────────────────────
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

-- ── Countdown overlay ────────────────────────────────────────────────────
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
--  THEME SYSTEM
-- ══════════════════════════════════════════════════════════════════════════════

-- Track current lives for heart recoloring on theme change
local currentLives1 = 3
local currentLives2 = 0

local function ApplyTheme(themeKey)
	local theme = ThemeConfig.Themes[themeKey]
	if not theme then return end
	currentTheme = theme

	-- Panel + square colors
	mainFrame.BackgroundColor3 = theme.Colors.Panel
	for _, btn in pairs(gridButtons) do
		btn.BackgroundColor3 = theme.Colors.Square
	end

	-- Square icon
	local hasIcon = theme.SquareIcon and theme.SquareIcon ~= ""
	for _, btn in pairs(gridButtons) do
		btn.Text             = theme.SquareIcon or ""
		btn.TextColor3       = theme.Colors.Highlight
		btn.TextTransparency = hasIcon and 0.3 or 1
	end

	-- Soundpack
	applyThemeSounds(theme)

	-- Recolor hearts based on current lives
	for i, h in ipairs(p1HeartLabels) do
		h.TextColor3 = (i <= currentLives1) and theme.Colors.HeartAlive or theme.Colors.HeartDead
	end
	for i, h in ipairs(p2HeartLabels) do
		h.TextColor3 = (i <= currentLives2) and theme.Colors.HeartAlive or theme.Colors.HeartDead
	end
end

-- Listen for theme changes fired by the shop client
local bindableEvents = ReplicatedStorage:WaitForChild("BindableEvents")
local themeChangedEvent = bindableEvents:WaitForChild("ThemeChanged")
themeChangedEvent.Event:Connect(ApplyTheme)

-- Apply equipped theme when server sends data on join
themeDataEvent.OnClientEvent:Connect(function(ownedThemes, equippedTheme)
	ApplyTheme(equippedTheme)
end)

-- Apply equipped sound pack when server sends data on join / after purchase
soundDataEvent.OnClientEvent:Connect(function(ownedSounds, equippedSound)
	local pack = SoundConfig.Packs[equippedSound] or SoundConfig.Packs["Default"]
	applySoundPack(pack)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  WIN BURST OVERLAY
-- ══════════════════════════════════════════════════════════════════════════════

local winOverlay = Instance.new("Frame")
winOverlay.Name                   = "WinOverlay"
winOverlay.Size                   = UDim2.new(1, 0, 1, 0)
winOverlay.Position               = UDim2.new(0, 0, 0, 0)
winOverlay.BackgroundTransparency = 1
winOverlay.ZIndex                 = 50
winOverlay.Visible                = false
winOverlay.Parent                 = screenGui

local flashFrame = Instance.new("Frame")
flashFrame.Size                   = UDim2.new(1, 0, 1, 0)
flashFrame.Position               = UDim2.new(0, 0, 0, 0)
flashFrame.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel        = 0
flashFrame.ZIndex                 = 51
flashFrame.Parent                 = winOverlay

local winCard = Instance.new("Frame")
winCard.Name                      = "WinCard"
winCard.AnchorPoint               = Vector2.new(0.5, 0.5)
winCard.Position                  = UDim2.new(0.5, 0, 0.44, 0)
winCard.Size                      = UDim2.new(0.01, 0, 0.01, 0)
winCard.BackgroundColor3          = Color3.fromRGB(18, 18, 32)
winCard.BorderSizePixel           = 0
winCard.ZIndex                    = 52
winCard.Parent                    = winOverlay

local winCardCorner = Instance.new("UICorner")
winCardCorner.CornerRadius        = UDim.new(0.055, 0)
winCardCorner.Parent              = winCard

local winCardStroke = Instance.new("UIStroke")
winCardStroke.Color               = Color3.fromRGB(255, 200, 50)
winCardStroke.Thickness           = 3
winCardStroke.Parent              = winCard

local winTrophyLabel = Instance.new("TextLabel")
winTrophyLabel.Size               = UDim2.new(0.9, 0, 0.30, 0)
winTrophyLabel.Position           = UDim2.new(0.05, 0, 0.04, 0)
winTrophyLabel.BackgroundTransparency = 1
winTrophyLabel.Text               = "🏆 YOU WIN! 🏆"
winTrophyLabel.TextColor3         = Color3.fromRGB(255, 210, 50)
winTrophyLabel.TextScaled         = true
winTrophyLabel.Font               = Enum.Font.GothamBold
winTrophyLabel.ZIndex             = 53
winTrophyLabel.Parent             = winCard

local winCoinsLabel = Instance.new("TextLabel")
winCoinsLabel.Name                = "WinCoinsLabel"
winCoinsLabel.Size                = UDim2.new(0.9, 0, 0.25, 0)
winCoinsLabel.Position            = UDim2.new(0.05, 0, 0.36, 0)
winCoinsLabel.BackgroundTransparency = 1
winCoinsLabel.Text                = "+50 coins"
winCoinsLabel.TextColor3          = Color3.fromRGB(255, 255, 255)
winCoinsLabel.TextScaled          = true
winCoinsLabel.Font                = Enum.Font.Gotham
winCoinsLabel.ZIndex              = 53
winCoinsLabel.Parent              = winCard

local winStreakLabel = Instance.new("TextLabel")
winStreakLabel.Name               = "WinStreakLabel"
winStreakLabel.Size               = UDim2.new(0.9, 0, 0.22, 0)
winStreakLabel.Position           = UDim2.new(0.05, 0, 0.68, 0)
winStreakLabel.BackgroundTransparency = 1
winStreakLabel.Text               = ""
winStreakLabel.TextColor3         = Color3.fromRGB(255, 150, 50)
winStreakLabel.TextScaled         = true
winStreakLabel.Font               = Enum.Font.GothamBold
winStreakLabel.ZIndex             = 53
winStreakLabel.Parent             = winCard

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 215, 50),
	Color3.fromRGB(100, 200, 255),
	Color3.fromRGB(150, 255, 120),
	Color3.fromRGB(255, 100, 200),
	Color3.fromRGB(200, 130, 255),
	Color3.fromRGB(255, 160, 50),
}

local function PlayWinBurst(totalCoins, bonusCoins, streakCount)
	mainFrame.Visible  = false
	winOverlay.Visible = true
	winCard.Size       = UDim2.new(0.01, 0, 0.01, 0)

	local bonusText = bonusCoins > 0 and (" (+" .. bonusCoins .. " bonus)") or ""
	winCoinsLabel.Text = "+" .. totalCoins .. " coins" .. bonusText
	winStreakLabel.Text = streakCount >= 3 and ("🔥 " .. streakCount .. " win streak!") or ""

	-- White flash
	flashFrame.BackgroundTransparency = 0.25
	TweenService:Create(flashFrame, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()

	-- Card bounce in
	task.delay(0.06, function()
		TweenService:Create(winCard, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0.68, 0, 0.38, 0),
		}):Play()
	end)

	-- Confetti burst
	for i = 1, 30 do
		task.spawn(function()
			task.wait(math.random() * 1.3)
			local piece = Instance.new("Frame")
			piece.Size             = UDim2.new(0.018, 0, 0.028, 0)
			piece.Position         = UDim2.new(math.random() * 0.88 + 0.05, 0, -0.06, 0)
			piece.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
			piece.BorderSizePixel  = 0
			piece.ZIndex           = 55
			piece.Parent           = winOverlay
			Instance.new("UICorner", piece).CornerRadius = UDim.new(0.2, 0)
			local fallTime = 1.6 + math.random() * 1.2
			TweenService:Create(piece, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(piece.Position.X.Scale, 0, 1.15, 0),
			}):Play()
			task.wait(fallTime + 0.1)
			piece:Destroy()
		end)
	end

	-- Shrink card out after 3.2s then hide
	task.delay(3.2, function()
		TweenService:Create(winCard, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0.01, 0, 0.01, 0),
		}):Play()
		task.delay(0.4, function()
			winOverlay.Visible = false
		end)
	end)
end

-- ══════════════════════════════════════════════════════════════════════════════
--  GAME LOGIC
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
		button.BackgroundColor3 = currentTheme.Colors.Square
	end

	if shouldShowAnimation then
		statusLabel.Text = "Watch the sequence..."

		for i, position in ipairs(sequence) do
			task.wait(GameConfig.SEQUENCE_GAP_TIME)
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = currentTheme.Colors.Highlight
				playClickSound(position)
			end
			task.wait(GameConfig.SEQUENCE_DISPLAY_TIME)
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = currentTheme.Colors.Square
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
	local color = isCorrect and currentTheme.Colors.Active or currentTheme.Colors.Wrong
	for _, button in pairs(gridButtons) do
		button.BackgroundColor3 = color
	end
	statusLabel.Text       = isCorrect and "Correct! ✓" or "Wrong! Try Again! ✗"
	statusLabel.TextColor3 = color

	-- Play theme correct/wrong sound
	if isCorrect then
		if correctSound.SoundId ~= "" then correctSound:Play() end
	else
		if wrongSound.SoundId ~= "" then wrongSound:Play() end
	end

	task.wait(isCorrect and 0.2 or 0.8)
	for _, button in pairs(gridButtons) do
		button.BackgroundColor3 = currentTheme.Colors.Square
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
		gridButtons[position].BackgroundColor3 = currentTheme.Colors.Active
		task.delay(0.06, function()
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = currentTheme.Colors.Square
			end
		end)
	end

	playClickSound(position)

	table.insert(playerInputs, position)
	playerInputEvent:FireServer(position)
end

function ShowResult(won, sequenceLength, bonusCoins, streakCount, isNewRecord)
	canInput = false
	bonusCoins  = bonusCoins  or 0
	streakCount = streakCount or 0
	isNewRecord = isNewRecord or false

	if won then
		local baseCoins   = 50
		local totalCoins  = baseCoins + bonusCoins
		local streakText  = streakCount >= 3 and ("  🔥 " .. streakCount .. " streak!") or ""
		local bonusText   = bonusCoins > 0 and (" (+" .. bonusCoins .. " bonus)") or ""
		statusLabel.Text       = "YOU WIN! +$" .. totalCoins .. " coins" .. bonusText .. streakText
		statusLabel.TextColor3 = currentTheme.Colors.Active
		PlayWinBurst(totalCoins, bonusCoins, streakCount)
	else
		-- Solo game
		local recordText = isNewRecord and "  ⭐ NEW RECORD!" or ""
		statusLabel.Text       = "Game Over! Sequence: " .. sequenceLength .. recordText
		statusLabel.TextColor3 = isNewRecord and Color3.fromRGB(255, 215, 0) or currentTheme.Colors.Wrong
	end
end

function UpdateLives(lives1, lives2)
	currentLives1 = lives1
	currentLives2 = lives2
	if lives2 > 0 then isMultiplayer = true end
	for i, h in ipairs(p1HeartLabels) do
		h.TextColor3 = (i <= lives1) and currentTheme.Colors.HeartAlive or currentTheme.Colors.HeartDead
	end
	if isMultiplayer then
		vsLabel.Visible = true
		for i, h in ipairs(p2HeartLabels) do
			h.Visible    = true
			h.TextColor3 = (i <= lives2) and currentTheme.Colors.HeartAlive or currentTheme.Colors.HeartDead
		end
	end
end

-- ── Event handlers ───────────────────────────────────────────────────────────

showGameUIEvent.OnClientEvent:Connect(function(show, gridSize)
	if show then
		rebuildGrid(gridSize or GameConfig.GRID_SIZE)
	end
	mainFrame.Visible  = show
	winOverlay.Visible = false
	if not show then
		canInput          = false
		isShowingSequence = false
		isMyTurn          = false
		isMultiplayer     = false
		currentLives1     = 3
		currentLives2     = 0
		vsLabel.Visible   = false
		for _, h in ipairs(p1HeartLabels) do h.TextColor3 = currentTheme.Colors.HeartAlive end
		for _, h in ipairs(p2HeartLabels) do h.Visible = false; h.TextColor3 = currentTheme.Colors.HeartAlive end
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end)

sequenceShowEvent.OnClientEvent:Connect(function(sequence)
	currentSequence = sequence
	ShowSequence(sequence, isMyTurn)
end)

gameResultEvent.OnClientEvent:Connect(function(won, sequenceLength, bonusCoins, streakCount, isNewRecord)
	ShowResult(won, sequenceLength, bonusCoins, streakCount, isNewRecord)
end)

playWinSoundEvent.OnClientEvent:Connect(function(winnerName)
	local winSound = workspace:FindFirstChild("roblox-old-winning-sound-effect")
	local popSound = workspace:FindFirstChild("confetti-pop-sound")
	if winSound then winSound:Play() end
	if popSound then popSound:Play() end
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
		statusLabel.TextColor3 = currentTheme.Colors.Active
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

updateTimerEvent.OnClientEvent:Connect(function(timeRemaining, state)
	if state == "hidden" then
		timerDisplay.Visible = false
	elseif state == "paused" then
		timerDisplay.Visible = true
		timerDisplay.Text    = "⏱: " .. tostring(math.ceil(timeRemaining))
		timerDisplay.TextColor3 = Color3.fromRGB(140, 140, 140)
	else -- "active"
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
	end
end)

print("SequenceClient loaded for " .. player.Name)
