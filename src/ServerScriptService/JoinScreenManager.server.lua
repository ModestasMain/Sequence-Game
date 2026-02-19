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
	local lockedPlayers = {} -- [player] = {connection, origWalkSpeed}

	-- === FLOATING BILLBOARD (above platform) ===
	local joinScreenPart = joinScreen -- the Part itself
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlatformBillboard"
	billboard.Size = UDim2.new(4, 0, 1.5, 0)   -- studs, not pixels — scales with world
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300
	billboard.Adornee = joinScreenPart
	billboard.Parent = joinScreenPart

	local billboardModeLabel = Instance.new("TextLabel")
	billboardModeLabel.Size = UDim2.new(1, 0, 0.42, 0)
	billboardModeLabel.Position = UDim2.new(0, 0, 0, 0)
	billboardModeLabel.BackgroundTransparency = 1
	billboardModeLabel.Text = "1v1"
	billboardModeLabel.TextColor3 = Color3.fromRGB(100, 210, 255)
	billboardModeLabel.TextScaled = true
	billboardModeLabel.Font = Enum.Font.GothamBold
	billboardModeLabel.TextStrokeTransparency = 0
	billboardModeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	billboardModeLabel.Parent = billboard

	local billboardCountLabel = Instance.new("TextLabel")
	billboardCountLabel.Size = UDim2.new(1, 0, 0.58, 0)
	billboardCountLabel.Position = UDim2.new(0, 0, 0.42, 0)
	billboardCountLabel.BackgroundTransparency = 1
	billboardCountLabel.Text = "0/2 Players"
	billboardCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	billboardCountLabel.TextScaled = true
	billboardCountLabel.Font = Enum.Font.GothamBold
	billboardCountLabel.TextStrokeTransparency = 0
	billboardCountLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	billboardCountLabel.Parent = billboard

	local function updateBillboard()
		local count = #waitingPlayers
		if gameInProgress then
			billboardCountLabel.Text = "In Progress"
			billboardCountLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif count == 0 then
			billboardCountLabel.Text = "0/2 Players"
			billboardCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		elseif count == 1 then
			billboardCountLabel.Text = "1/2 Players"
			billboardCountLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		else
			billboardCountLabel.Text = "Starting..."
			billboardCountLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
	end

	-- === LOBBY FRAME ===
	local lobbyFrame = Instance.new("Frame")
	lobbyFrame.Name = "LobbyFrame"
	lobbyFrame.Size = UDim2.new(1, 0, 1, 0)
	lobbyFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	lobbyFrame.BorderSizePixel = 0
	lobbyFrame.Visible = false
	lobbyFrame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = lobbyFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 80)
	titleLabel.Position = UDim2.new(0, 0, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "MEMORY SEQUENCE"
	titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	titleLabel.TextSize = 36
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextStrokeTransparency = 0
	titleLabel.Parent = lobbyFrame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0, 40)
	subtitleLabel.Position = UDim2.new(0, 0, 0, 100)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = ""
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	subtitleLabel.TextSize = 24
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Parent = lobbyFrame

	local playerCountLabel = Instance.new("TextLabel")
	playerCountLabel.Size = UDim2.new(1, 0, 0, 60)
	playerCountLabel.Position = UDim2.new(0, 0, 0, 160)
	playerCountLabel.BackgroundTransparency = 1
	playerCountLabel.Text = "0/2 Players"
	playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	playerCountLabel.TextSize = 42
	playerCountLabel.Font = Enum.Font.GothamBold
	playerCountLabel.Parent = lobbyFrame

	local playersListLabel = Instance.new("TextLabel")
	playersListLabel.Size = UDim2.new(1, -40, 0, 100)
	playersListLabel.Position = UDim2.new(0, 20, 0, 240)
	playersListLabel.BackgroundTransparency = 1
	playersListLabel.Text = ""
	playersListLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
	playersListLabel.TextSize = 28
	playersListLabel.Font = Enum.Font.Gotham
	playersListLabel.TextYAlignment = Enum.TextYAlignment.Top
	playersListLabel.Parent = lobbyFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 40)
	statusLabel.Position = UDim2.new(0, 0, 1, -60)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Press E to Join"
	statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	statusLabel.TextSize = 28
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextStrokeTransparency = 0.5
	statusLabel.Parent = lobbyFrame

	-- === LIVE PREVIEW FRAME ===
	local previewFrame = Instance.new("Frame")
	previewFrame.Name = "PreviewFrame"
	previewFrame.Size = UDim2.new(1, 0, 1, 0)
	previewFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
	previewFrame.BorderSizePixel = 0
	previewFrame.Visible = true
	previewFrame.Parent = gui

	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = UDim.new(0, 12)
	previewCorner.Parent = previewFrame

	-- LIVE badge
	local liveBadge = Instance.new("Frame")
	liveBadge.Size = UDim2.new(0, 90, 0, 30)
	liveBadge.Position = UDim2.new(0, 10, 0, 10)
	liveBadge.BackgroundColor3 = Color3.fromRGB(210, 40, 40)
	liveBadge.BorderSizePixel = 0
	liveBadge.Visible = false
	liveBadge.Parent = previewFrame
	local liveBadgeCorner = Instance.new("UICorner")
	liveBadgeCorner.CornerRadius = UDim.new(0, 6)
	liveBadgeCorner.Parent = liveBadge
	local liveBadgeLabel = Instance.new("TextLabel")
	liveBadgeLabel.Size = UDim2.new(1, 0, 1, 0)
	liveBadgeLabel.BackgroundTransparency = 1
	liveBadgeLabel.Text = "● LIVE"
	liveBadgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	liveBadgeLabel.TextSize = 16
	liveBadgeLabel.Font = Enum.Font.GothamBold
	liveBadgeLabel.Parent = liveBadge

	-- Player names / turn indicator
	local previewInfoLabel = Instance.new("TextLabel")
	previewInfoLabel.Name = "InfoLabel"
	previewInfoLabel.Size = UDim2.new(1, -10, 0, 36)
	previewInfoLabel.Position = UDim2.new(0, 5, 0, 46)
	previewInfoLabel.BackgroundTransparency = 1
	previewInfoLabel.Text = "Waiting for players"
	previewInfoLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	previewInfoLabel.TextSize = 20
	previewInfoLabel.Font = Enum.Font.GothamBold
	previewInfoLabel.Parent = previewFrame

	-- Lives display
	local previewLivesLabel = Instance.new("TextLabel")
	previewLivesLabel.Name = "LivesLabel"
	previewLivesLabel.Size = UDim2.new(1, -10, 0, 26)
	previewLivesLabel.Position = UDim2.new(0, 5, 0, 84)
	previewLivesLabel.BackgroundTransparency = 1
	previewLivesLabel.Text = "0/2 Players"
	previewLivesLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	previewLivesLabel.TextSize = 18
	previewLivesLabel.Font = Enum.Font.Gotham
	previewLivesLabel.Parent = previewFrame

	-- Sequence length display
	local previewSeqLabel = Instance.new("TextLabel")
	previewSeqLabel.Name = "SeqLabel"
	previewSeqLabel.Size = UDim2.new(1, -10, 0, 24)
	previewSeqLabel.Position = UDim2.new(0, 5, 0, 112)
	previewSeqLabel.BackgroundTransparency = 1
	previewSeqLabel.Text = ""
	previewSeqLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
	previewSeqLabel.TextSize = 16
	previewSeqLabel.Font = Enum.Font.Gotham
	previewSeqLabel.Parent = previewFrame

	-- 3x3 grid
	local squareSize = 110
	local squareGap = 8
	local gridTotal = GameConfig.GRID_SIZE * squareSize + (GameConfig.GRID_SIZE - 1) * squareGap

	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "GridFrame"
	gridFrame.Size = UDim2.new(0, gridTotal, 0, gridTotal)
	gridFrame.Position = UDim2.new(0.5, -gridTotal / 2, 0, 142)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = previewFrame

	local previewSquares = {}
	for row = 1, GameConfig.GRID_SIZE do
		for col = 1, GameConfig.GRID_SIZE do
			local pos = (row - 1) * GameConfig.GRID_SIZE + col
			local sq = Instance.new("Frame")
			sq.Name = "Square" .. pos
			sq.Size = UDim2.new(0, squareSize, 0, squareSize)
			sq.Position = UDim2.new(0, (col - 1) * (squareSize + squareGap), 0, (row - 1) * (squareSize + squareGap))
			sq.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
			sq.BorderSizePixel = 0
			sq.Parent = gridFrame
			local sqCorner = Instance.new("UICorner")
			sqCorner.CornerRadius = UDim.new(0, 8)
			sqCorner.Parent = sq
			previewSquares[pos] = sq
		end
	end

	-- Bottom status
	local previewStatusLabel = Instance.new("TextLabel")
	previewStatusLabel.Name = "StatusLabel"
	previewStatusLabel.Size = UDim2.new(1, 0, 0, 36)
	previewStatusLabel.Position = UDim2.new(0, 0, 1, -48)
	previewStatusLabel.BackgroundTransparency = 1
	previewStatusLabel.Text = "Press E to Join!"
	previewStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	previewStatusLabel.TextSize = 18
	previewStatusLabel.Font = Enum.Font.Gotham
	previewStatusLabel.Parent = previewFrame

	-- === LivePreview API (called by GameManager) ===
	local LivePreview = {}

	function LivePreview:Show(player1Name, player2Name)
		liveBadge.Visible = true
		previewInfoLabel.Text = player1Name .. "  vs  " .. player2Name
		previewLivesLabel.Text = "♥♥♥  vs  ♥♥♥"
		previewSeqLabel.Text = "Sequence: 1"
		previewStatusLabel.Text = "Match starting..."
		previewStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
		self:ResetAllSquares()
	end

	function LivePreview:Hide()
		liveBadge.Visible = false
		previewInfoLabel.Text = "Waiting for players"
		previewLivesLabel.Text = "0/2 Players"
		previewSeqLabel.Text = ""
		previewStatusLabel.Text = "Press E to Join!"
		previewStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		self:ResetAllSquares()
	end

	function LivePreview:HighlightSquare(position, color)
		if previewSquares[position] then
			previewSquares[position].BackgroundColor3 = color
		end
	end

	function LivePreview:ResetSquare(position)
		if previewSquares[position] then
			previewSquares[position].BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
		end
	end

	function LivePreview:ResetAllSquares()
		for _, sq in pairs(previewSquares) do
			sq.BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
		end
	end

	-- Flash a square briefly to show a player click
	function LivePreview:ShowClickFlash(position)
		if previewSquares[position] then
			previewSquares[position].BackgroundColor3 = GameConfig.SQUARE_ACTIVE_COLOR
			task.delay(0.12, function()
				if previewSquares[position] then
					previewSquares[position].BackgroundColor3 = GameConfig.SQUARE_DEFAULT_COLOR
				end
			end)
		end
	end

	-- Flash all squares green (correct) or red (wrong)
	function LivePreview:ShowFeedback(isCorrect)
		local color = isCorrect and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
		for _, sq in pairs(previewSquares) do
			sq.BackgroundColor3 = color
		end
		task.delay(1, function()
			self:ResetAllSquares()
		end)
	end

	function LivePreview:UpdateLives(lives1, lives2)
		local function hearts(n, max)
			return string.rep("♥", math.max(0, n)) .. string.rep("♡", math.max(0, max - n))
		end
		previewLivesLabel.Text = hearts(lives1, GameConfig.STARTING_LIVES) .. "  vs  " .. hearts(lives2, GameConfig.STARTING_LIVES)
	end

	function LivePreview:UpdateSequenceLength(len)
		previewSeqLabel.Text = "Sequence: " .. len
	end

	-- Show whose turn it is with an arrow indicator
	function LivePreview:UpdateTurnInfo(player1Name, player2Name, currentTurnName)
		if currentTurnName == player1Name then
			previewInfoLabel.Text = "▶ " .. player1Name .. "   |   " .. player2Name
		else
			previewInfoLabel.Text = player1Name .. "   |   " .. player2Name .. " ◀"
		end
	end

	function LivePreview:UpdateStatus(text, color)
		previewStatusLabel.Text = text
		previewStatusLabel.TextColor3 = color or Color3.fromRGB(160, 160, 160)
	end

	-- ===========================
	-- Lobby logic
	-- ===========================
	local function updateDisplay()
		updateBillboard()
		local count = #waitingPlayers
		if gameInProgress then
			return
		elseif count == 0 then
			previewInfoLabel.Text = "Waiting for players"
			previewLivesLabel.Text = "0/2 Players"
			previewStatusLabel.Text = "Press E to Join!"
			previewStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		elseif count == 1 then
			previewInfoLabel.Text = waitingPlayers[1].Name .. " is waiting..."
			previewLivesLabel.Text = "1/2 Players"
			previewStatusLabel.Text = "Need 1 more player!"
			previewStatusLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
		else
			previewInfoLabel.Text = waitingPlayers[1].Name .. "  vs  " .. waitingPlayers[2].Name
			previewLivesLabel.Text = "2/2 Players"
			previewStatusLabel.Text = "Starting Match..."
			previewStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
	end

	local function isPlayerWaiting(player)
		for _, p in ipairs(waitingPlayers) do
			if p == player then return true end
		end
		return false
	end

	local function unlockPlayer(player)
		local data = lockedPlayers[player]
		if not data then return end
		data.connection:Disconnect()
		lockedPlayers[player] = nil
		if player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = data.origWalkSpeed
			end
		end
	end

	local function removePlayer(player)
		for i, p in ipairs(waitingPlayers) do
			if p == player then
				table.remove(waitingPlayers, i)
				unlockPlayer(player)
				print("[JoinScreen] " .. player.Name .. " left the queue on " .. platformModel.Name)
				updateDisplay()
				return true
			end
		end
		return false
	end

	local function lockPlayerToSpot(player, part)
		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")
		if not hrp or not humanoid then return end

		local origWalkSpeed = humanoid.WalkSpeed

		-- Teleport above the part, facing the table center
		local standPos = part.Position + Vector3.new(0, part.Size.Y / 2 + 2.5, 0)
		local centerPos = Vector3.new(joinScreenPart.Position.X, standPos.Y, joinScreenPart.Position.Z)
		hrp.CFrame = CFrame.lookAt(standPos, centerPos)

		-- Prevent walking but keep jump ability so player can jump to exit
		humanoid.WalkSpeed = 0

		-- Detect jump → exit queue (only if game hasn't started yet)
		local connection
		connection = humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Jumping then
				connection:Disconnect()
				lockedPlayers[player] = nil
				humanoid.WalkSpeed = origWalkSpeed
				-- Don't remove if countdown/game already in progress — GameSession takes over
				if not gameInProgress and not countdownActive then
					removePlayer(player)
				end
			end
		end)

		lockedPlayers[player] = { connection = connection, origWalkSpeed = origWalkSpeed }
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

		previewStatusLabel.Text = "Starting in 3..."
		task.wait(1)
		previewStatusLabel.Text = "Starting in 2..."
		task.wait(1)
		previewStatusLabel.Text = "Starting in 1..."
		task.wait(1)

		-- Switch to live preview immediately
		LivePreview:Show(player1.Name, player2.Name)

		-- Unlock queue position locks — GameSession:Start() will re-position and re-lock
		unlockPlayer(player1)
		unlockPlayer(player2)

		local GameManager = require(game.ServerScriptService:WaitForChild("GameManager"))

		local platformObj = {
			Model = platformModel,
			LeftPart = platformModel:FindFirstChild("Left"),
			RightPart = platformModel:FindFirstChild("Right"),
			LivePreview = LivePreview,
		}

		function platformObj:Reset()
			waitingPlayers = {}
			gameInProgress = false
			countdownActive = false
			joinPrompt.Enabled = true
			LivePreview:Hide()
			updateBillboard()
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

		-- Lock player to their seat (slot 1 = Left, slot 2 = Right)
		local slot = #waitingPlayers
		local seatPart = slot == 1 and platformModel:FindFirstChild("Left") or platformModel:FindFirstChild("Right")
		if seatPart then
			lockPlayerToSpot(player, seatPart)
		end

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
