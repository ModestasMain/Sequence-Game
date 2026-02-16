-- JoinScreenManager.lua
-- Handles Press E to Join system for all platforms
-- Lives in ServerScriptService so it syncs via Rojo

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local JoinScreenManager = {}

function JoinScreenManager:SetupPlatform(platformModel)
	local joinScreen = platformModel:FindFirstChild("JoinScreen")
	if not joinScreen then
		print("[JoinScreen] No JoinScreen found in " .. platformModel.Name)
		return
	end

	local gui = joinScreen:FindFirstChild("JoinGui")
	local joinPrompt = joinScreen:FindFirstChild("JoinPrompt")

	if not gui or not joinPrompt then
		print("[JoinScreen] Missing JoinGui or JoinPrompt in " .. platformModel.Name)
		return
	end

	local waitingPlayers = {}
	local gameInProgress = false
	local countdownActive = false
	local debounce = {}

	-- UI Elements
	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bgFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 80)
	titleLabel.Position = UDim2.new(0, 0, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "MEMORY SEQUENCE"
	titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	titleLabel.TextSize = 36
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextStrokeTransparency = 0
	titleLabel.Parent = bgFrame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0, 40)
	subtitleLabel.Position = UDim2.new(0, 0, 0, 100)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "1v1 Competitive Match"
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	subtitleLabel.TextSize = 24
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Parent = bgFrame

	local playerCountLabel = Instance.new("TextLabel")
	playerCountLabel.Size = UDim2.new(1, 0, 0, 60)
	playerCountLabel.Position = UDim2.new(0, 0, 0, 160)
	playerCountLabel.BackgroundTransparency = 1
	playerCountLabel.Text = "0/2 Players"
	playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	playerCountLabel.TextSize = 42
	playerCountLabel.Font = Enum.Font.GothamBold
	playerCountLabel.Parent = bgFrame

	local playersListLabel = Instance.new("TextLabel")
	playersListLabel.Size = UDim2.new(1, -40, 0, 100)
	playersListLabel.Position = UDim2.new(0, 20, 0, 240)
	playersListLabel.BackgroundTransparency = 1
	playersListLabel.Text = ""
	playersListLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
	playersListLabel.TextSize = 28
	playersListLabel.Font = Enum.Font.Gotham
	playersListLabel.TextYAlignment = Enum.TextYAlignment.Top
	playersListLabel.Parent = bgFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 40)
	statusLabel.Position = UDim2.new(0, 0, 1, -60)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Press E to Join"
	statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	statusLabel.TextSize = 28
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextStrokeTransparency = 0.5
	statusLabel.Parent = bgFrame

	local function updateDisplay()
		local count = #waitingPlayers

		if gameInProgress then
			playerCountLabel.Text = "2/2 Players"
			playersListLabel.Text = waitingPlayers[1].Name .. " vs " .. waitingPlayers[2].Name
			statusLabel.Text = "Match In Progress!"
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			playerCountLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif count == 0 then
			playerCountLabel.Text = "0/2 Players"
			playersListLabel.Text = ""
			statusLabel.Text = "Press E to Join"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		elseif count == 1 then
			playerCountLabel.Text = "1/2 Players"
			playersListLabel.Text = waitingPlayers[1].Name .. " is waiting..."
			statusLabel.Text = "Waiting for opponent..."
			statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
			playerCountLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		else
			playerCountLabel.Text = "2/2 Players"
			playersListLabel.Text = waitingPlayers[1].Name .. "\n" .. waitingPlayers[2].Name
			statusLabel.Text = "Starting Match..."
			statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
			playerCountLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
	end

	local function isPlayerWaiting(player)
		for _, p in ipairs(waitingPlayers) do
			if p == player then return true end
		end
		return false
	end

	local function removePlayer(player)
		for i, p in ipairs(waitingPlayers) do
			if p == player then
				table.remove(waitingPlayers, i)
				print("[JoinScreen] " .. player.Name .. " left the queue on " .. platformModel.Name)
				updateDisplay()
				return true
			end
		end
		return false
	end

	local function startGame()
		if #waitingPlayers < 2 or gameInProgress or countdownActive then return end

		countdownActive = true
		gameInProgress = true
		joinPrompt.Enabled = false
		updateDisplay()

		local player1 = waitingPlayers[1]
		local player2 = waitingPlayers[2]

		print("[JoinScreen] Starting game: " .. player1.Name .. " vs " .. player2.Name .. " on " .. platformModel.Name)

		statusLabel.Text = "Starting in 3..."
		task.wait(1)
		statusLabel.Text = "Starting in 2..."
		task.wait(1)
		statusLabel.Text = "Starting in 1..."
		task.wait(1)

		local GameManager = require(game.ServerScriptService:WaitForChild("GameManager"))

		local platformObj = {
			Model = platformModel,
			LeftPart = platformModel:FindFirstChild("Left"),
			RightPart = platformModel:FindFirstChild("Right")
		}

		function platformObj:Reset()
			waitingPlayers = {}
			gameInProgress = false
			countdownActive = false
			joinPrompt.Enabled = true
			updateDisplay()
			print("[JoinScreen] " .. platformModel.Name .. " reset")
		end

		GameManager:StartGame(player1, player2, platformObj)
	end

	-- Handle Press E
	joinPrompt.Triggered:Connect(function(player)
		print("[JoinScreen] E pressed by " .. player.Name .. " on " .. platformModel.Name)

		if debounce[player.UserId] then return end
		debounce[player.UserId] = true
		task.delay(1, function()
			debounce[player.UserId] = nil
		end)

		if gameInProgress or countdownActive then return end

		if isPlayerWaiting(player) then
			removePlayer(player)
			return
		end

		if #waitingPlayers >= 2 then return end

		table.insert(waitingPlayers, player)
		print("[JoinScreen] " .. player.Name .. " joined! Queue: " .. #waitingPlayers .. "/2 on " .. platformModel.Name)
		updateDisplay()

		if #waitingPlayers == 2 then
			startGame()
		end
	end)

	-- Handle player leaving game
	game.Players.PlayerRemoving:Connect(function(player)
		removePlayer(player)
		debounce[player.UserId] = nil
	end)

	updateDisplay()
	print("[JoinScreen] Setup complete for " .. platformModel.Name)
end

-- Initialize all platforms
function JoinScreenManager:Initialize()
	local lobby = game.Workspace:WaitForChild("Lobby")

	for _, child in pairs(lobby:GetChildren()) do
		if child:IsA("Model") and child:FindFirstChild("JoinScreen") then
			self:SetupPlatform(child)
		end
	end

	print("[JoinScreen] All platforms initialized")
end

task.wait(2) -- Wait for workspace and Rojo to load
JoinScreenManager:Initialize()

return JoinScreenManager
