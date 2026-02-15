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
local showGameUIEvent = remoteEvents:WaitForChild("ShowGameUI")
local sequenceFeedbackEvent = remoteEvents:WaitForChild("SequenceFeedback")
local updateTimerEvent = remoteEvents:WaitForChild("UpdateTimer")

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
	self.Started = false  -- Prevent Start() from being called twice
	self.RoundInProgress = false  -- Prevent StartRound from being called twice
	self.TimerThread = nil  -- Active timer coroutine
	self.TimerActive = false  -- Whether timer is currently running

	return self
end

function GameSession:Start()
	if self.Started then
		print("WARNING: Start() called twice on same session. Ignoring.")
		return
	end
	self.Started = true

	print("Game session starting...")

	-- Teleport players to game arena
	local arena = game.Workspace:WaitForChild("GameArena")
	local spawn = arena:FindFirstChild("SpawnLocation")

	if spawn then
		-- Calculate unique arena position for this game based on platform
		-- Extract platform number from name (Platform1 -> 1, Platform2 -> 2, etc.)
		local platformNumber = 1
		if self.Platform and self.Platform.Model then
			local platformName = self.Platform.Model.Name
			platformNumber = tonumber(string.match(platformName, "%d+")) or 1
		end

		-- Space out games: each game gets its own area 50 studs apart
		local gameAreaOffset = Vector3.new(0, 0, (platformNumber - 1) * 50)

		for i, player in ipairs(self.Players) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				-- Space players apart within their game area (10 studs between them)
				local playerOffset = Vector3.new((i - 1.5) * 10, 0, 0)
				player.Character.HumanoidRootPart.CFrame = spawn.CFrame + gameAreaOffset + playerOffset
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

	-- Show UI to BOTH players immediately
	for _, player in ipairs(self.Players) do
		showGameUIEvent:FireClient(player, true)
		updateLivesEvent:FireClient(player, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
	end

	-- Setup player disconnect/death detection
	local Players = game:GetService("Players")
	for _, player in ipairs(self.Players) do
		-- Detect player leaving
		Players.PlayerRemoving:Connect(function(leavingPlayer)
			if leavingPlayer == player and self.Active then
				print(player.Name .. " left the game!")
				self:EndGame(player)
			end
		end)

		-- Detect player death
		if player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					if self.Active then
						print(player.Name .. " died!")
						self:EndGame(player)
					end
				end)
			end
		end

		-- Detect character reset/respawn
		player.CharacterAdded:Connect(function()
			if self.Active then
				print(player.Name .. " reset/respawned!")
				self:EndGame(player)
			end
		end)
	end

	-- Show countdown to both players (only once at start)
	task.wait(1)
	local countdownSteps = {"Ready...", "3", "2", "1", "GO!"}
	for _, step in ipairs(countdownSteps) do
		for _, player in ipairs(self.Players) do
			countdownEvent:FireClient(player, step)
		end
		task.wait(1)
	end

	-- Generate the very first sequence before starting
	self:GenerateSequence()
	print("Initial sequence generated: " .. table.concat(self.Sequence, ", "))

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

	print("=== GenerateSequence called ===")
	print("New sequence length: " .. self.SequenceLength)
	print("Full sequence: " .. table.concat(self.Sequence, ", "))
	print("Added position: " .. newPosition)
end

function GameSession:StopTimer()
	self.TimerActive = false

	-- Only cancel thread if we're not currently inside it
	if self.TimerThread and coroutine.running() ~= self.TimerThread then
		pcall(function()
			task.cancel(self.TimerThread)
		end)
		self.TimerThread = nil
	end

	-- Hide timer for both players
	for _, player in ipairs(self.Players) do
		updateTimerEvent:FireClient(player, 0, false)
	end
end

function GameSession:StartTimer()
	-- Stop any existing timer
	self:StopTimer()

	-- Calculate timer duration: 10 base seconds + 1.5 seconds per sequence length
	local timerDuration = 10 + (self.SequenceLength - 1) * 1.5
	local currentPlayer = self.Players[self.CurrentPlayerTurn]

	print("Starting timer: " .. timerDuration .. " seconds for " .. currentPlayer.Name)

	self.TimerActive = true
	self.TimerThread = task.spawn(function()
		local timeRemaining = timerDuration

		while timeRemaining > 0 and self.TimerActive and self.Active do
			-- Send timer update to current player only
			updateTimerEvent:FireClient(currentPlayer, timeRemaining, true)

			task.wait(0.1)
			timeRemaining = timeRemaining - 0.1
		end

		-- Debug logging
		print("=== TIMER LOOP EXITED ===")
		print("Time remaining:", timeRemaining)
		print("TimerActive:", self.TimerActive)
		print("Game Active:", self.Active)

		-- Timer ran out! (time reached 0, but timer wasn't manually stopped)
		if self.TimerActive and self.Active and timeRemaining <= 0 then
			print("⏱ " .. currentPlayer.Name .. " RAN OUT OF TIME!")
			self.TimerActive = false
			updateTimerEvent:FireClient(currentPlayer, 0, false)

			-- Treat as wrong input (lose a life)
			self:HandleWrongInput(currentPlayer)
		else
			print("Timer stopped normally (not timeout)")
		end
	end)
end

function GameSession:StartRound()
	if not self.Active then return end

	-- Prevent duplicate calls
	if self.RoundInProgress then
		print("WARNING: StartRound called while already in progress. Ignoring.")
		return
	end

	self.RoundInProgress = true

	-- Get current player
	local currentPlayer = self.Players[self.CurrentPlayerTurn]
	local otherPlayer = self.Players[self.CurrentPlayerTurn == 1 and 2 or 1]

	print("Starting " .. currentPlayer.Name .. "'s turn (sequence length: " .. self.SequenceLength .. ")")

	-- Notify both players whose turn it is
	turnNotificationEvent:FireClient(currentPlayer, true, currentPlayer.Name) -- It's your turn
	turnNotificationEvent:FireClient(otherPlayer, false, currentPlayer.Name) -- It's opponent's turn

	-- Show UI to both players
	for _, player in ipairs(self.Players) do
		updateLivesEvent:FireClient(player, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
	end

	-- Wait a moment to ensure turn notification is processed before showing sequence
	task.wait(0.2)

	-- Reset input index BEFORE showing sequence (prevents race condition with fast clickers!)
	self.CurrentInputIndex = 1
	print("Waiting for " .. currentPlayer.Name .. "'s input...")

	-- Show sequence to both players (but only current player sees animation)
	for _, player in ipairs(self.Players) do
		sequenceShowEvent:FireClient(player, self.Sequence)
	end

	-- Wait for sequence to finish displaying (only for current player)
	local displayTime = #self.Sequence * (GameConfig.SEQUENCE_DISPLAY_TIME + GameConfig.SEQUENCE_GAP_TIME) + 1
	task.wait(displayTime)

	-- Start the timer for this round
	self:StartTimer()

	-- Round setup complete, allow next round to start
	self.RoundInProgress = false

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

	print("=== SERVER INPUT RECEIVED ===")
	print("Player: " .. player.Name)
	print("Clicked position: " .. position)
	print("Expected position: " .. expectedPosition)
	print("Current index: " .. self.CurrentInputIndex .. " / " .. #self.Sequence)
	print("Full sequence: " .. table.concat(self.Sequence, ", "))

	if position == expectedPosition then
		-- Correct input
		print("✓ CORRECT!")
		print(player.Name .. " clicked correct position " .. position .. " (" .. self.CurrentInputIndex .. "/" .. #self.Sequence .. ")")

		-- Check if sequence is complete
		if self.CurrentInputIndex >= #self.Sequence then
			print(player.Name .. " completed the sequence!")

			-- Stop the timer
			self:StopTimer()

			-- Show green feedback to player
			sequenceFeedbackEvent:FireClient(player, true)

			self.CurrentInputIndex = 1

			-- Check if we need to increment sequence (both players completed current length)
			if self.CurrentPlayerTurn == 2 then
				-- Player 2 just finished, increment sequence for next round
				self:GenerateSequence()
			end

			-- Switch turns to other player
			self.CurrentPlayerTurn = (self.CurrentPlayerTurn == 1) and 2 or 1

			-- Wait for feedback animation to finish before next turn
			task.wait(1.5)
			self:StartRound()
		else
			self.CurrentInputIndex = self.CurrentInputIndex + 1
		end
	else
		-- Wrong input
		print("✗ WRONG!")
		print(player.Name .. " clicked wrong position " .. position .. " (expected " .. expectedPosition .. ")")
		print("Sequence was: " .. table.concat(self.Sequence, ", "))
		self:HandleWrongInput(player)
	end
end

function GameSession:HandleWrongInput(player)
	-- Stop the timer
	self:StopTimer()

	-- Show red feedback to player
	sequenceFeedbackEvent:FireClient(player, false)

	-- Deduct a life
	self.Lives[player.UserId] = self.Lives[player.UserId] - 1

	print(player.Name .. " lost a life! Lives remaining: " .. self.Lives[player.UserId])

	-- Update lives for both players
	for _, p in ipairs(self.Players) do
		updateLivesEvent:FireClient(p, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
	end

	-- Check if player is out of lives
	if self.Lives[player.UserId] <= 0 then
		task.wait(1.5) -- Wait for feedback animation
		self:EndGame(player)
	else
		-- SAME player tries again (no turn switch - they get to redeem themselves!)
		print(player.Name .. " gets another chance with the same sequence!")

		-- Reset for retry (same sequence, same player)
		self.CurrentInputIndex = 1
		task.wait(1.5) -- Wait for feedback animation
		self:StartRound()
	end
end

function GameSession:EndGame(loser)
	if not self.Active then return end
	self.Active = false

	-- Stop any active timer
	self:StopTimer()

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

	-- Update IQ ratings (ELO-style)
	if winner then
		PlayerDataManager:UpdateIQ(winner, loser)
	end

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
	-- Hide UI for both players
	for _, player in ipairs(self.Players) do
		showGameUIEvent:FireClient(player, false)
	end

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
	-- Check if either player is already in an active game
	for session in pairs(self.ActiveGames) do
		if table.find(session.Players, player1) or table.find(session.Players, player2) then
			print("WARNING: Player already in game. Ignoring duplicate StartGame call.")
			print("Player1: " .. player1.Name .. ", Player2: " .. player2.Name)
			return
		end
	end

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
