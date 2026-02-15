-- GameManager.lua
-- Manages game sessions, sequence generation, and win/loss logic

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))

-- Remote Events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local sequenceShowEvent = remoteEvents:WaitForChild("SequenceShow")
local playerInputEvent = remoteEvents:WaitForChild("PlayerInput")
local gameResultEvent = remoteEvents:WaitForChild("GameResult")
local updateLivesEvent = remoteEvents:WaitForChild("UpdateLives")
local countdownEvent = remoteEvents:WaitForChild("Countdown")
local turnNotificationEvent = remoteEvents:WaitForChild("TurnNotification")

local GameManager = {}
GameManager.ActiveGames = {}

-- Game Session Class
local GameSession = {}
GameSession.__index = GameSession

function GameSession.new(player1, player2, platform)
	local self = setmetatable({}, GameSession)
	self.Players = {player1, player2}
	self.Platform = platform
	self.Lives = {
		[player1.UserId] = GameConfig.STARTING_LIVES,
		[player2.UserId] = GameConfig.STARTING_LIVES
	}
	self.Sequence = {}
	self.SequenceLength = 1
	self.CurrentPlayerTurn = 1 -- Index in Players array (1 or 2)
	self.CurrentInputIndex = 1
	self.Active = true

	return self
end

function GameSession:Start()
	print("Game session starting...")

	-- Teleport players to game arena
	local arena = game.Workspace:WaitForChild("GameArena")
	local spawn = arena:FindFirstChild("SpawnLocation")

	if spawn then
		for i, player in ipairs(self.Players) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local offset = Vector3.new((i - 1.5) * 10, 0, 0) -- Space players apart
				player.Character.HumanoidRootPart.CFrame = spawn.CFrame + offset
			end
		end
	end

	-- Lock both players in position
	for _, player in ipairs(self.Players) do
		if player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 0
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0
			end

			-- Anchor the HumanoidRootPart
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = true
			end
		end
	end

	-- Show UI to BOTH players (they'll see it the whole game)
	for _, player in ipairs(self.Players) do
		updateLivesEvent:FireClient(player, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
	end

	-- Show countdown to both players
	task.wait(1)
	local countdownSteps = {"Ready...", "3", "2", "1", "GO!"}
	for _, step in ipairs(countdownSteps) do
		for _, player in ipairs(self.Players) do
			countdownEvent:FireClient(player, step)
		end
		task.wait(1)
	end

	-- Start first round
	task.wait(0.5)
	self:StartRound()
end

function GameSession:GenerateSequence()
	-- Add one more square to the sequence
	local gridSize = GameConfig.GRID_SIZE
	local newPosition = math.random(1, gridSize * gridSize)
	table.insert(self.Sequence, newPosition)
	self.SequenceLength = #self.Sequence

	print("Generated sequence of length " .. self.SequenceLength .. ": " .. table.concat(self.Sequence, ", "))
end

function GameSession:StartRound()
	if not self.Active then return end

	-- Generate sequence if this is the first round
	if #self.Sequence == 0 then
		self:GenerateSequence()
	end

	-- Get current player
	local currentPlayer = self.Players[self.CurrentPlayerTurn]
	local otherPlayer = self.Players[self.CurrentPlayerTurn == 1 and 2 or 1]

	print("Starting " .. currentPlayer.Name .. "'s turn (sequence length: " .. self.SequenceLength .. ")")

	-- Notify both players whose turn it is
	turnNotificationEvent:FireClient(currentPlayer, true, currentPlayer.Name) -- It's your turn
	turnNotificationEvent:FireClient(otherPlayer, false, currentPlayer.Name) -- It's opponent's turn

	-- Show sequence to BOTH players (both can see it, but only current player can click)
	for _, player in ipairs(self.Players) do
		sequenceShowEvent:FireClient(player, self.Sequence)
	end

	-- Wait for sequence to finish displaying
	local displayTime = #self.Sequence * (GameConfig.SEQUENCE_DISPLAY_TIME + GameConfig.SEQUENCE_GAP_TIME) + 1
	task.wait(displayTime)

	-- Start player input phase (only current player can click)
	print("Waiting for " .. currentPlayer.Name .. "'s input...")
	self.CurrentInputIndex = 1

	-- Inputs are handled via remote event
end

function GameSession:HandleInput(player, position)
	if not self.Active then return end
	if not table.find(self.Players, player) then return end

	-- Check if it's this player's turn
	local currentPlayer = self.Players[self.CurrentPlayerTurn]
	if player ~= currentPlayer then
		print(player.Name .. " tried to input but it's not their turn!")
		return
	end

	local expectedPosition = self.Sequence[self.CurrentInputIndex]

	if position == expectedPosition then
		-- Correct input
		print(player.Name .. " clicked correct position " .. position .. " (" .. self.CurrentInputIndex .. "/" .. #self.Sequence .. ")")

		-- Check if sequence is complete
		if self.CurrentInputIndex >= #self.Sequence then
			print(player.Name .. " completed the sequence!")
			self.CurrentInputIndex = 1

			-- Switch turns to other player
			self.CurrentPlayerTurn = (self.CurrentPlayerTurn == 1) and 2 or 1

			-- Check if we need to increment sequence (both players completed current length)
			if self.CurrentPlayerTurn == 1 then
				-- Just switched back to player 1, meaning player 2 just finished
				-- Increment sequence for next round
				self:GenerateSequence()
			end

			-- Small delay before next turn
			task.wait(1)
			self:StartRound()
		else
			self.CurrentInputIndex = self.CurrentInputIndex + 1
		end
	else
		-- Wrong input
		print(player.Name .. " clicked wrong position " .. position .. " (expected " .. expectedPosition .. ")")
		self:HandleWrongInput(player)
	end
end

function GameSession:HandleWrongInput(player)
	-- Deduct a life
	self.Lives[player.UserId] = self.Lives[player.UserId] - 1

	print(player.Name .. " lost a life! Lives remaining: " .. self.Lives[player.UserId])

	-- Update lives for both players
	for _, p in ipairs(self.Players) do
		updateLivesEvent:FireClient(p, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
	end

	-- Check if player is out of lives
	if self.Lives[player.UserId] <= 0 then
		self:EndGame(player)
	else
		-- Switch turns to other player (they get a chance with the same sequence)
		self.CurrentPlayerTurn = (self.CurrentPlayerTurn == 1) and 2 or 1

		-- Reset for next turn (same sequence length)
		self.CurrentInputIndex = 1
		task.wait(2)
		self:StartRound()
	end
end

function GameSession:EndGame(loser)
	if not self.Active then return end
	self.Active = false

	-- Determine winner
	local winner = nil
	for _, player in ipairs(self.Players) do
		if player ~= loser then
			winner = player
			break
		end
	end

	print("Game Over! Winner: " .. (winner and winner.Name or "None") .. ", Loser: " .. loser.Name)

	-- Award coins and update stats
	if winner then
		PlayerDataManager:AddWin(winner, GameConfig.WIN_COINS)
		PlayerDataManager:UpdateHighestSequence(winner, self.SequenceLength)
	end

	PlayerDataManager:AddLoss(loser, GameConfig.PARTICIPATION_COINS)
	PlayerDataManager:UpdateHighestSequence(loser, self.SequenceLength)

	-- Notify players
	for _, player in ipairs(self.Players) do
		local won = (player == winner)
		gameResultEvent:FireClient(player, won, self.SequenceLength)
	end

	-- Cleanup
	task.wait(5)
	self:Cleanup()
end

function GameSession:Cleanup()
	-- Unlock players
	for _, player in ipairs(self.Players) do
		if player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2
			end

			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = false
			end
		end
	end

	-- Teleport players back to lobby
	local lobby = game.Workspace:WaitForChild("Lobby")
	local spawnLocation = lobby:FindFirstChildOfClass("SpawnLocation") or workspace:FindFirstChildOfClass("SpawnLocation")

	for _, player in ipairs(self.Players) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			if spawnLocation then
				player.Character.HumanoidRootPart.CFrame = spawnLocation.CFrame + Vector3.new(0, 5, 0)
			end
		end
	end

	-- Reset platform
	if self.Platform then
		self.Platform:Reset()
	end

	-- Remove from active games
	GameManager.ActiveGames[self] = nil
end

-- Public API
function GameManager:StartGame(player1, player2, platform)
	local session = GameSession.new(player1, player2, platform)
	self.ActiveGames[session] = true
	session:Start()
end

-- Handle player input from client
playerInputEvent.OnServerEvent:Connect(function(player, position)
	-- Find the game session this player is in
	for session in pairs(GameManager.ActiveGames) do
		if table.find(session.Players, player) then
			session:HandleInput(player, position)
			break
		end
	end
end)

return GameManager
