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

-- UI Elements
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SequenceUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

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
livesLabel.Size = UDim2.new(1, 0, 0, 40)
livesLabel.Position = UDim2.new(0, 0, 0, 10)
livesLabel.BackgroundTransparency = 1
livesLabel.Text = "Lives: 3 vs 3"
livesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
livesLabel.TextSize = 20
livesLabel.Font = Enum.Font.GothamBold
livesLabel.Parent = mainFrame

-- Turn Indicator
local turnLabel = Instance.new("TextLabel")
turnLabel.Name = "TurnLabel"
turnLabel.Size = UDim2.new(1, 0, 0, 50)
turnLabel.Position = UDim2.new(0, 0, 0, 50)
turnLabel.BackgroundTransparency = 1
turnLabel.Text = ""
turnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
turnLabel.TextSize = 28
turnLabel.Font = Enum.Font.GothamBold
turnLabel.Visible = false
turnLabel.Parent = mainFrame

-- Countdown Display
local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "CountdownLabel"
countdownLabel.Size = UDim2.new(1, 0, 0, 100)
countdownLabel.Position = UDim2.new(0, 0, 0.5, -50)
countdownLabel.BackgroundTransparency = 1
countdownLabel.Text = ""
countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
countdownLabel.TextSize = 60
countdownLabel.Font = Enum.Font.GothamBold
countdownLabel.Visible = false
countdownLabel.Parent = mainFrame

-- Grid Container
local gridFrame = Instance.new("Frame")
gridFrame.Name = "GridFrame"
gridFrame.Size = UDim2.new(0, 360, 0, 360)
gridFrame.Position = UDim2.new(0.5, -180, 0, 110)
gridFrame.BackgroundTransparency = 1
gridFrame.Visible = true
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

-- Variables
local currentSequence = {}
local canInput = false
local isShowingSequence = false
local isMyTurn = false
local clickDebounce = false

-- Functions
function ShowSequence(sequence)
	isShowingSequence = true
	canInput = false
	statusLabel.Text = "Watch the sequence..."

	-- Reset all squares
	for _, button in pairs(gridButtons) do
		button.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
	end

	-- Show sequence
	for i, position in ipairs(sequence) do
		task.wait(GameConfig.SEQUENCE_GAP_TIME)

		-- Highlight square
		if gridButtons[position] then
			gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_HIGHLIGHT_COLOR
		end

		task.wait(GameConfig.SEQUENCE_DISPLAY_TIME)

		-- Reset square
		if gridButtons[position] then
			gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
		end
	end

	-- Enable input only if it's the player's turn
	task.wait(0.5)
	isShowingSequence = false

	if isMyTurn then
		canInput = true
		statusLabel.Text = "Click the sequence!"
	else
		canInput = false
		statusLabel.Text = "Wait for your turn..."
	end
end

function OnSquareClick(position)
	if not canInput or isShowingSequence then return end
	if clickDebounce then return end -- Prevent rapid double-clicks

	-- Set debounce
	clickDebounce = true

	-- Visual feedback
	if gridButtons[position] then
		gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_ACTIVE_COLOR

		task.delay(0.15, function()
			if gridButtons[position] then
				gridButtons[position].BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
			end
		end)
	end

	-- Send to server
	playerInputEvent:FireServer(position)

	-- Clear debounce after short delay
	task.wait(0.1)
	clickDebounce = false
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

	-- Hide UI after delay
	task.wait(4)
	mainFrame.Visible = false
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
end

function UpdateLives(lives1, lives2)
	livesLabel.Text = string.format("Lives: %d vs %d", lives1, lives2)
end

function ShowCountdown(text)
	-- Hide grid and show countdown
	gridFrame.Visible = false
	countdownLabel.Visible = true
	countdownLabel.Text = text
	statusLabel.Visible = false
	turnLabel.Visible = false

	-- Special color for "GO!"
	if text == "GO!" then
		countdownLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	end
end

function ShowTurnNotification(myTurn, playerName)
	isMyTurn = myTurn

	-- Hide countdown and show grid
	countdownLabel.Visible = false
	gridFrame.Visible = true
	turnLabel.Visible = true
	statusLabel.Visible = true

	if myTurn then
		turnLabel.Text = "YOUR TURN!"
		turnLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		statusLabel.Text = "Watch the sequence..."
	else
		turnLabel.Text = playerName .. "'s Turn"
		turnLabel.TextColor3 = Color3.fromRGB(255, 150, 100)
		statusLabel.Text = "Wait for your turn..."
		canInput = false
	end
end

-- Event Handlers
sequenceShowEvent.OnClientEvent:Connect(function(sequence)
	currentSequence = sequence
	mainFrame.Visible = true
	ShowSequence(sequence)
end)

gameResultEvent.OnClientEvent:Connect(function(won, sequenceLength)
	ShowResult(won, sequenceLength)
end)

updateLivesEvent.OnClientEvent:Connect(function(lives1, lives2)
	UpdateLives(lives1, lives2)
end)

countdownEvent.OnClientEvent:Connect(function(text)
	mainFrame.Visible = true
	ShowCountdown(text)
end)

turnNotificationEvent.OnClientEvent:Connect(function(myTurn, playerName)
	ShowTurnNotification(myTurn, playerName)
end)

print("SequenceClient loaded for " .. player.Name)
