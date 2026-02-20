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

function GameSession.new(player1, player2, platform, gridSize)
	local self = setmetatable({}, GameSession)
	self.Players = {player1, player2}
	self.Platform = platform
	self.GridSize = gridSize or GameConfig.GRID_SIZE
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

-- Helper to safely call LivePreview methods (no-op if not available)
function GameSession:LP()
	return self.Platform and self.Platform.LivePreview
end

function GameSession:Start()
	if self.Started then
		print("WARNING: Start() called twice on same session. Ignoring.")
		return
	end
	self.Started = true

	print("Game session starting...")

	-- Keep players on their platform pads and make them face each other
	if self.Platform and self.Platform.LeftPart and self.Platform.RightPart then
		local leftPos = self.Platform.LeftPart.Position
		local rightPos = self.Platform.RightPart.Position

		-- Position players on their pads facing each other
		for i, player in ipairs(self.Players) do
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = player.Character.HumanoidRootPart

				if i == 1 then
					-- Player 1 on left pad, facing right
					hrp.CFrame = CFrame.new(leftPos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(-90), 0)
				else
					-- Player 2 on right pad, facing left
					hrp.CFrame = CFrame.new(rightPos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(90), 0)
				end
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

	-- Show UI to BOTH players immediately (pass gridSize so client builds the right grid)
	for _, player in ipairs(self.Players) do
		showGameUIEvent:FireClient(player, true, self.GridSize)
		updateLivesEvent:FireClient(player, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
	end

	-- Setup player disconnect/death detection
	local Players = game:GetService("Players")
	for _, player in ipairs(self.Players) do
		-- Detect player leaving
		Players.PlayerRemoving:Connect(function(leavingPlayer)
			if leavingPlayer == player and self.Active then
				print(player.Name .. " left the game!")
				self:EndGame(player, true)
			end
		end)

		-- Detect player death
		if player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					if self.Active then
						print(player.Name .. " died!")
						self:EndGame(player, true)
					end
				end)
			end
		end

		-- Detect character reset/respawn
		player.CharacterAdded:Connect(function()
			if self.Active then
				print(player.Name .. " reset/respawned!")
				self:EndGame(player, true)
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
	local newPosition = math.random(1, self.GridSize * self.GridSize)
	table.insert(self.Sequence, newPosition)
	self.SequenceLength = #self.Sequence

	print("=== GenerateSequence called ===")
	print("New sequence length: " .. self.SequenceLength)
	print("Full sequence: " .. table.concat(self.Sequence, ", "))
	print("Added position: " .. newPosition)

	-- Update live preview sequence length
	local lp = self:LP()
	if lp then
		lp:UpdateSequenceLength(self.SequenceLength)
	end
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
end

function GameSession:HideTimer()
	for _, player in ipairs(self.Players) do
		updateTimerEvent:FireClient(player, 0, "hidden")
	end
end

function GameSession:StartTimer()
	-- Stop any existing timer
	self:StopTimer()

	local perStep = self.GridSize == 5 and GameConfig.TIMER_PER_STEP_SECONDS_5X5 or GameConfig.TIMER_PER_STEP_SECONDS
	local timerDuration = GameConfig.TIMER_BASE_SECONDS + (self.SequenceLength - 1) * perStep
	local currentPlayer = self.Players[self.CurrentPlayerTurn]

	print("Starting timer: " .. timerDuration .. " seconds for " .. currentPlayer.Name)

	self.TimerActive = true
	self.TimerThread = task.spawn(function()
		local timeRemaining = timerDuration

		-- Fire immediately so timer snaps to active the moment input phase begins
		while self.TimerActive and self.Active do
			updateTimerEvent:FireClient(currentPlayer, timeRemaining, "active")
			if timeRemaining <= 0 then break end
			task.wait(0.1)
			timeRemaining = timeRemaining - 0.1
		end

		-- Timer ran out (timeRemaining hit 0 without being manually stopped)
		if self.TimerActive and self.Active and timeRemaining <= 0 then
			print("⏱ " .. currentPlayer.Name .. " RAN OUT OF TIME!")
			self.TimerActive = false
			self:HideTimer()
			self:HandleWrongInput(currentPlayer)
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

	-- Update live preview: who's turn it is
	local lp = self:LP()
	if lp then
		lp:UpdateTurnInfo(self.Players[1].Name, self.Players[2].Name, currentPlayer.Name)
		lp:UpdateStatus(currentPlayer.Name .. " is watching the sequence...", Color3.fromRGB(160, 160, 160))
		lp:ResetAllSquares()
	end

	-- Show UI to both players
	for _, player in ipairs(self.Players) do
		updateLivesEvent:FireClient(player, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
	end

	-- Wait a moment to ensure turn notification is processed before showing sequence
	task.wait(0.2)

	-- Show timer in paused (gray) state immediately so it's visible during the sequence preview
	local perStep = self.GridSize == 5 and GameConfig.TIMER_PER_STEP_SECONDS_5X5 or GameConfig.TIMER_PER_STEP_SECONDS
	local timerDuration = GameConfig.TIMER_BASE_SECONDS + (self.SequenceLength - 1) * perStep
	updateTimerEvent:FireClient(currentPlayer, timerDuration, "paused")

	-- Reset input index BEFORE showing sequence (prevents race condition with fast clickers!)
	self.CurrentInputIndex = 1
	print("Waiting for " .. currentPlayer.Name .. "'s input...")

	-- Show sequence to both players (but only current player sees animation)
	for _, player in ipairs(self.Players) do
		sequenceShowEvent:FireClient(player, self.Sequence)
	end

	-- Mirror sequence animation on live preview (runs concurrently)
	if lp then
		task.spawn(function()
			for _, position in ipairs(self.Sequence) do
				if not self.Active then break end
				task.wait(GameConfig.SEQUENCE_GAP_TIME)
				lp:HighlightSquare(position, GameConfig.SQUARE_HIGHLIGHT_COLOR)
				task.wait(GameConfig.SEQUENCE_DISPLAY_TIME)
				lp:ResetSquare(position)
			end
			if self.Active then
				lp:UpdateStatus(currentPlayer.Name .. " is entering sequence...", Color3.fromRGB(255, 220, 80))
			end
		end)
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

	-- Mirror every click on the live preview
	local lp = self:LP()
	if lp then
		lp:ShowClickFlash(position)
	end

	if position == expectedPosition then
		-- Correct input
		print("✓ CORRECT!")
		print(player.Name .. " clicked correct position " .. position .. " (" .. self.CurrentInputIndex .. "/" .. #self.Sequence .. ")")

		-- Check if sequence is complete
		if self.CurrentInputIndex >= #self.Sequence then
			print(player.Name .. " completed the sequence!")

			-- Stop the timer
			self:StopTimer()

			-- Show green feedback to player and on live preview
			sequenceFeedbackEvent:FireClient(player, true)
			if lp then
				lp:ShowFeedback(true)
			end

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

	-- Show red feedback to player and on live preview
	sequenceFeedbackEvent:FireClient(player, false)
	local lp = self:LP()
	if lp then
		lp:ShowFeedback(false)
	end

	-- Deduct a life
	self.Lives[player.UserId] = self.Lives[player.UserId] - 1

	print(player.Name .. " lost a life! Lives remaining: " .. self.Lives[player.UserId])

	-- Update lives for both players and on live preview
	for _, p in ipairs(self.Players) do
		updateLivesEvent:FireClient(p, self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
	end
	if lp then
		lp:UpdateLives(self.Lives[self.Players[1].UserId], self.Lives[self.Players[2].UserId])
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

function GameSession:EndGame(loser, forced)
	if not self.Active then return end
	self.Active = false

	-- Stop any active timer and hide it for both players
	self:StopTimer()
	self:HideTimer()

	-- Reset platform immediately so the table stops showing gameplay
	if self.Platform then
		self.Platform:Reset()
		self.Platform = nil
	end

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

	if forced then
		-- Player left/reset mid-game: notify winner instantly, short wait
		if winner then
			gameResultEvent:FireClient(winner, true, self.SequenceLength)
		end
		task.wait(2)
	else
		-- Natural game end: notify both players
		for _, player in ipairs(self.Players) do
			local won = (player == winner)
			gameResultEvent:FireClient(player, won, self.SequenceLength)
		end
		task.wait(5)
	end

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

	-- Remove from active games
	GameManager.ActiveGames[self] = nil
end

-- Public API
function GameManager:StartGame(player1, player2, platform, gridSize)
	-- Check if either player is already in an active game
	for session in pairs(self.ActiveGames) do
		if table.find(session.Players, player1) or table.find(session.Players, player2) then
			print("WARNING: Player already in game. Ignoring duplicate StartGame call.")
			print("Player1: " .. player1.Name .. ", Player2: " .. player2.Name)
			return
		end
	end

	local session = GameSession.new(player1, player2, platform, gridSize)
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
