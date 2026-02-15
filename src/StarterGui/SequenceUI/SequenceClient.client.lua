-- SequenceClient.lua (LocalScript in StarterGui)
-- Handles client-side UI for the 3x3 sequence grid

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Remote Events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local sequenceShowEvent = remoteEvents:WaitForChild("SequenceShow")
local playerInputEvent = remoteEvents:WaitForChild("PlayerInput")
local gameResultEvent = remoteEvents:WaitForChild("GameResult")
local updateLivesEvent = remoteEvents:WaitForChild("UpdateLives")
local countdownEvent = remoteEvents:WaitForChild("Countdown")
local turnNotificationEvent = remoteEvents:WaitForChild("TurnNotification")
local showGameUIEvent = remoteEvents:WaitForChild("ShowGameUI")
local sequenceFeedbackEvent = remoteEvents:WaitForChild("SequenceFeedback")
local updateTimerEvent = remoteEvents:WaitForChild("UpdateTimer")

-- Sequence Sounds
local sequenceSounds = ReplicatedStorage:WaitForChild("SequenceSounds")
local soundInstances = {}
print("=== LOADING SEQUENCE SOUNDS ===")

-- Parent sounds to Camera for 2D audio (non-positional)
local camera = workspace.CurrentCamera

for i = 1, 9 do
	local sound = sequenceSounds:FindFirstChild("Sequence" .. i)
	if sound then
		-- Clone sound to camera for 2D playback
		local soundClone = sound:Clone()
		soundClone.Parent = camera
		soundInstances[i] = soundClone
		print("✓ Loaded sound for position", i, "- Volume:", soundClone.Volume, "PlaybackSpeed:", soundClone.PlaybackSpeed)
	else
		print("✗ Failed to find sound: Sequence" .. i)
	end
end
print("=== TOTAL SOUNDS LOADED:", #soundInstances, "===")

-- UI Elements
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = playerGui:WaitForChild("SequenceUI")  -- Use the existing ScreenGui from StarterGui
screenGui.ResetOnSpawn = false

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 500)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- Round corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- Lives Display
local livesLabel = Instance.new("TextLabel")
livesLabel.Name = "LivesLabel"
livesLabel.Size = UDim2.new(1, 0, 0, 50)
livesLabel.Position = UDim2.new(0, 0, 0, 10)
livesLabel.BackgroundTransparency = 1
livesLabel.Text = "Lives: 3 vs 3"
livesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
livesLabel.TextSize = 24
livesLabel.Font = Enum.Font.GothamBold
livesLabel.Parent = mainFrame

-- Timer Display (top right, next to lives)
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0, 80, 0, 50)
timerLabel.Position = UDim2.new(1, -90, 0, 10)  -- Top right, aligned with lives
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "10"
timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerLabel.TextSize = 32
timerLabel.Font = Enum.Font.GothamBold
timerLabel.TextStrokeTransparency = 0.5
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.Visible = false
timerLabel.Parent = mainFrame

-- Timer icon/label
local timerIcon = Instance.new("TextLabel")
timerIcon.Name = "TimerIcon"
timerIcon.Size = UDim2.new(0, 60, 0, 50)
timerIcon.Position = UDim2.new(1, -155, 0, 10)  -- Left of timer number
timerIcon.BackgroundTransparency = 1
timerIcon.Text = "⏱"
timerIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
timerIcon.TextSize = 28
timerIcon.Font = Enum.Font.GothamBold
timerIcon.TextXAlignment = Enum.TextXAlignment.Right
timerIcon.Visible = false
timerIcon.Parent = mainFrame

-- Grid Container
local gridFrame = Instance.new("Frame")
gridFrame.Name = "GridFrame"
gridFrame.Size = UDim2.new(0, 360, 0, 360)
gridFrame.Position = UDim2.new(0.5, -180, 0, 80)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = mainFrame

-- Create 3x3 grid of buttons
local gridButtons = {}
local buttonSize = 110
local buttonGap = 10

for row = 1, GameConfig.GRID_SIZE do
	for col = 1, GameConfig.GRID_SIZE do
		local position = (row - 1) * GameConfig.GRID_SIZE + col

		local button = Instance.new("TextButton")
		button.Name = "Square" .. position
		button.Size = UDim2.new(0, buttonSize, 0, buttonSize)
		button.Position = UDim2.new(0, (col - 1) * (buttonSize + buttonGap), 0, (row - 1) * (buttonSize + buttonGap))
		button.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = gridFrame

		-- Round corners
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = button

		-- Click handler
		button.MouseButton1Click:Connect(function()
			OnSquareClick(position)
		end)

		gridButtons[position] = button
	end
end

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 0, 40)
statusLabel.Position = UDim2.new(0, 0, 1, -50)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Watch the sequence..."
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextSize = 18
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- Countdown Label (large, centered)
local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "CountdownLabel"
countdownLabel.Size = UDim2.new(1, 0, 0, 100)
countdownLabel.Position = UDim2.new(0, 0, 0.5, -50)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Text = ""
countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countdownLabel.TextSize = 48
countdownLabel.Font = Enum.Font.GothamBold
countdownLabel.Visible = false
countdownLabel.ZIndex = 10
countdownLabel.Parent = mainFrame

-- Variables
local currentSequence = {}
local canInput = false
local isShowingSequence = false
local isMyTurn = false
local lastClickTime = {}  -- Track last click time per button (for debug only)
local playerInputs = {}  -- Track player's inputs for feedback

-- Functions
function ShowSequence(sequence, shouldShowAnimation)
	print("=== CLIENT: ShowSequence called ===")
	print("Sequence length:", #sequence)
	print("Sequence:", table.concat(sequence, ", "))
	print("Should show animation:", shouldShowAnimation)

	isShowingSequence = true
	canInput = false
	playerInputs = {}  -- Clear previous inputs
	lastClickTime = {}  -- Clear click times

	-- Reset all squares
	for _, button in pairs(gridButtons) do
		button.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
	end

	if shouldShowAnimation then
		-- This player sees the sequence animation
		statusLabel.Text = "Watch the sequence..."

		-- Show sequence
		for i, position in ipairs(sequence) do
			print("Showing square", i, "at position", position)
			task.wait(GameConfig.SEQUENCE_GAP_TIME)

			-- Highlight square
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_HIGHLIGHT_COLOR

				-- Play corresponding sound for this position
				if soundInstances[position] then
					print("🔊 Playing sound for position", position)
					soundInstances[position]:Play()
				else
					print("⚠️ No sound found for position", position)
				end
			end

			task.wait(GameConfig.SEQUENCE_DISPLAY_TIME)

			-- Reset square
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
			end
		end

		-- Enable input IMMEDIATELY after sequence (no delay)
		isShowingSequence = false
		canInput = true
		statusLabel.Text = "Your turn! Click the sequence..."
		print("Input enabled!")
	else
		-- Other player just sees waiting message
		statusLabel.Text = "Waiting for opponent..."
		isShowingSequence = false
		canInput = false
	end
end

function ShowFeedback(isCorrect)
	canInput = false

	if isCorrect then
		-- Light up ALL squares GREEN to celebrate success!
		for _, button in pairs(gridButtons) do
			button.BackgroundColor3 = Color3.fromRGB(100, 255, 100)  -- Green
		end
		statusLabel.Text = "Correct! ✓"
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		-- Light up ALL squares RED to show failure
		for _, button in pairs(gridButtons) do
			button.BackgroundColor3 = Color3.fromRGB(255, 100, 100)  -- Red
		end
		statusLabel.Text = "Wrong! Try Again! ✗"
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	end

	-- Reset after delay
	task.wait(1)
	for _, button in pairs(gridButtons) do
		button.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
	end
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	playerInputs = {}  -- Clear tracked inputs
end

function OnSquareClick(position)
	if not canInput or isShowingSequence then
		print("Click blocked - canInput:", canInput, "isShowingSequence:", isShowingSequence)
		return
	end

	-- NO DEBOUNCE - allow ultra-fast clicking
	local currentTime = tick()
	local timeSinceLastClick = lastClickTime[position] and (currentTime - lastClickTime[position]) or 999
	lastClickTime[position] = currentTime

	print("=== CLICK:", position, "Time since last click on this button:", math.floor(timeSinceLastClick * 1000) .. "ms")

	-- Visual feedback - brief flash
	if gridButtons[position] then
		gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_ACTIVE_COLOR
		task.delay(0.06, function()
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
			end
		end)
	end

	-- Play sound for this position
	if soundInstances[position] then
		soundInstances[position]:Play()
	end

	-- Track this input
	table.insert(playerInputs, position)
	print("Sending to server - Input #" .. #playerInputs .. ": position " .. position)

	-- Send to server immediately
	playerInputEvent:FireServer(position)
end

function ShowResult(won, sequenceLength)
	canInput = false

	if won then
		statusLabel.Text = "YOU WIN! 🎉 Sequence: " .. sequenceLength
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		statusLabel.Text = "YOU LOSE! Sequence: " .. sequenceLength
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	end

	-- UI will be hidden by server after delay
end

function UpdateLives(lives1, lives2)
	livesLabel.Text = string.format("Lives: %d vs %d", lives1, lives2)
end

-- Event Handlers
-- Show/hide game UI
showGameUIEvent.OnClientEvent:Connect(function(show)
	print("=== CLIENT: Show UI Event ===")
	print("Player:", player.Name)
	print("Show:", show)

	mainFrame.Visible = show
	if not show then
		-- Reset state when hiding
		canInput = false
		isShowingSequence = false
		isMyTurn = false
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end)

sequenceShowEvent.OnClientEvent:Connect(function(sequence)
	print("=== CLIENT: Received sequenceShowEvent ===")
	print("Received sequence length:", #sequence)
	print("Received sequence:", table.concat(sequence, ", "))

	currentSequence = sequence
	-- Only show animation if it's my turn
	ShowSequence(sequence, isMyTurn)
end)

gameResultEvent.OnClientEvent:Connect(function(won, sequenceLength)
	ShowResult(won, sequenceLength)
end)

updateLivesEvent.OnClientEvent:Connect(function(lives1, lives2)
	UpdateLives(lives1, lives2)
end)

-- Countdown event (for initial game countdown)
countdownEvent.OnClientEvent:Connect(function(message)
	countdownLabel.Text = message
	countdownLabel.Visible = true

	-- Hide after a moment
	task.delay(0.9, function()
		countdownLabel.Visible = false
	end)
end)

-- Turn notification event
turnNotificationEvent.OnClientEvent:Connect(function(isYourTurn, playerName)
	print("=== CLIENT: Turn Notification ===")
	print("Player:", player.Name)
	print("Is your turn:", isYourTurn)
	print("Current player name:", playerName)

	isMyTurn = isYourTurn

	if isYourTurn then
		statusLabel.Text = "YOUR TURN!"
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		statusLabel.Text = playerName .. "'s turn - waiting..."
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	end

	-- Reset color after the turn notification is done
	task.delay(2, function()
		if not isMyTurn then
			-- Keep waiting message visible for opponent
			statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end)
end)

-- Sequence feedback event (correct/wrong)
sequenceFeedbackEvent.OnClientEvent:Connect(function(isCorrect)
	ShowFeedback(isCorrect)
end)

-- Timer update event
updateTimerEvent.OnClientEvent:Connect(function(timeRemaining, isActive)
	if isActive and isMyTurn then
		timerLabel.Visible = true
		timerIcon.Visible = true
		timerLabel.Text = tostring(math.ceil(timeRemaining))

		-- Change color based on time remaining
		local color
		if timeRemaining <= 3 then
			color = Color3.fromRGB(255, 100, 100) -- Red
		elseif timeRemaining <= 5 then
			color = Color3.fromRGB(255, 200, 100) -- Orange
		else
			color = Color3.fromRGB(255, 255, 255) -- White
		end

		timerLabel.TextColor3 = color
		timerIcon.TextColor3 = color
	else
		timerLabel.Visible = false
		timerIcon.Visible = false
	end
end)

print("SequenceClient loaded for " .. player.Name)
