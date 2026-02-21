-- SoloGameManager.server.lua
-- Handles solo mode - see how far you can get

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

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

local SoloGameManager = {}
SoloGameManager.ActiveGames = {}

-- Solo Session class
local SoloSession = {}
SoloSession.__index = SoloSession

function SoloSession.new(player, platform, gridSize)
	local self = setmetatable({}, SoloSession)
	self.Player = player
	self.Platform = platform
	self.GridSize = gridSize or GameConfig.GRID_SIZE
	self.Active = true
	self.Sequence = {}
	self.SequenceLength = 0
	self.CurrentInputIndex = 1
	self.Lives = 3
	self.Started = false
	self.TimerThread = nil
	self.TimerActive = false
	self.PeakSequence = 0  -- Highest sequence completed this session (for solo_seq quest)
	return self
end

-- Helper to safely access LivePreview
function SoloSession:LP()
	return self.Platform and self.Platform.LivePreview
end

function SoloSession:GenerateSequence()
	local newPosition = math.random(1, self.GridSize * self.GridSize)
	table.insert(self.Sequence, newPosition)
	self.SequenceLength = #self.Sequence
	print("[Solo] Sequence length: " .. self.SequenceLength .. " for " .. self.Player.Name)

	local lp = self:LP()
	if lp then
		lp:UpdateSequenceLength(self.SequenceLength)
	end
end

function SoloSession:StartTimer()
	self:StopTimer()
	local perStep = self.GridSize == 5 and GameConfig.TIMER_PER_STEP_SECONDS_5X5 or GameConfig.TIMER_PER_STEP_SECONDS
	local totalTime = GameConfig.TIMER_BASE_SECONDS + (self.SequenceLength - 1) * perStep
	self.TimerActive = true

	self.TimerThread = task.spawn(function()
		local timeRemaining = totalTime

		while self.TimerActive and self.Active do
			updateTimerEvent:FireClient(self.Player, timeRemaining, "active")
			if timeRemaining <= 0 then break end
			task.wait(0.1)
			timeRemaining = timeRemaining - 0.1
		end

		if self.TimerActive and self.Active and timeRemaining <= 0 then
			print("[Solo] Timer expired for " .. self.Player.Name)
			self.TimerActive = false
			self:HideTimer()
			self:HandleWrongInput()
		end
	end)
end

function SoloSession:StopTimer()
	self.TimerActive = false
	if self.TimerThread and coroutine.running() ~= self.TimerThread then
		pcall(function()
			task.cancel(self.TimerThread)
		end)
		self.TimerThread = nil
	end
end

function SoloSession:HideTimer()
	updateTimerEvent:FireClient(self.Player, 0, "hidden")
end

function SoloSession:Start()
	if self.Started then return end
	self.Started = true

	print("[Solo] Game starting for " .. self.Player.Name)

	-- Position player on the left pad then freeze them
	if self.Player.Character then
		local hrp = self.Player.Character:FindFirstChild("HumanoidRootPart")

		if hrp and self.Platform and self.Platform.LeftPart then
			local lp = self.Platform.LeftPart
			hrp.CFrame = CFrame.new(lp.Position + Vector3.new(0, 3, 0))
		end

		local humanoid = self.Player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end
		if hrp then
			hrp.Anchored = true
		end
	end

	-- Show UI (pass gridSize so client builds the right grid)
	showGameUIEvent:FireClient(self.Player, true, self.GridSize)
	updateLivesEvent:FireClient(self.Player, self.Lives, 0)

	-- Update preview lives on start
	local lp = self:LP()
	if lp then
		lp:UpdateLives(self.Lives)
	end

	-- Countdown
	for i = 3, 1, -1 do
		countdownEvent:FireClient(self.Player, tostring(i))
		task.wait(1)
	end
	countdownEvent:FireClient(self.Player, "GO!")
	task.wait(0.5)

	-- Notify it's their turn
	turnNotificationEvent:FireClient(self.Player, true, self.Player.Name)

	-- Start first round
	self:NextRound()
end

function SoloSession:NextRound()
	if not self.Active then return end

	self:GenerateSequence()
	self.CurrentInputIndex = 1

	-- Update lives display
	updateLivesEvent:FireClient(self.Player, self.Lives, 0)

	local lp = self:LP()
	if lp then
		lp:UpdateLives(self.Lives)
		lp:ResetAllSquares()
		lp:UpdateStatus(self.Player.Name .. " is watching the sequence...", Color3.fromRGB(160, 160, 160))
	end

	-- Show timer paused so it's visible while sequence plays
	local perStep = self.GridSize == 5 and GameConfig.TIMER_PER_STEP_SECONDS_5X5 or GameConfig.TIMER_PER_STEP_SECONDS
	local timerDuration = GameConfig.TIMER_BASE_SECONDS + (self.SequenceLength - 1) * perStep
	updateTimerEvent:FireClient(self.Player, timerDuration, "paused")

	-- Send sequence
	turnNotificationEvent:FireClient(self.Player, true, self.Player.Name)
	sequenceShowEvent:FireClient(self.Player, self.Sequence)

	-- Mirror sequence on live preview
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
				lp:UpdateStatus(self.Player.Name .. " is entering sequence...", Color3.fromRGB(255, 220, 80))
			end
		end)
	end

	-- Start timer after sequence display time
	local displayTime = #self.Sequence * (GameConfig.SEQUENCE_DISPLAY_TIME + GameConfig.SEQUENCE_GAP_TIME) + 1
	task.delay(displayTime, function()
		if self.Active then
			self:StartTimer()
		end
	end)
end

function SoloSession:HandleInput(position)
	if not self.Active then return end

	local expectedPosition = self.Sequence[self.CurrentInputIndex]

	-- Mirror click on live preview regardless of correctness
	local lp = self:LP()
	if lp then
		lp:ShowClickFlash(position)
	end

	if position == expectedPosition then
		self.CurrentInputIndex = self.CurrentInputIndex + 1

		-- Check if full sequence completed
		if self.CurrentInputIndex > #self.Sequence then
			self:StopTimer()
			print("[Solo] Correct sequence! Length: " .. self.SequenceLength .. " by " .. self.Player.Name)
			PlayerDataManager:AddCoins(self.Player, GameConfig.SOLO_CORRECT_COINS)
			sequenceFeedbackEvent:FireClient(self.Player, true)

			-- Track peak for quest progress
			if self.SequenceLength > self.PeakSequence then
				self.PeakSequence = self.SequenceLength
			end

			if lp then
				lp:ShowFeedback(true)
			end
			task.wait(0.3)
			self:NextRound()
		end
	else
		self:HandleWrongInput()
	end
end

function SoloSession:HandleWrongInput()
	self:StopTimer()
	self.Lives = self.Lives - 1
	print("[Solo] Wrong! Lives: " .. self.Lives .. " for " .. self.Player.Name)

	sequenceFeedbackEvent:FireClient(self.Player, false)
	updateLivesEvent:FireClient(self.Player, self.Lives, 0)

	local lp = self:LP()
	if lp then
		lp:ShowFeedback(false)
		lp:UpdateLives(self.Lives)
	end

	if self.Lives <= 0 then
		-- Game over
		task.wait(1.5)
		self:EndGame()
	else
		-- Retry same sequence
		task.wait(1.5)
		self.CurrentInputIndex = 1

		if lp then
			lp:ResetAllSquares()
			lp:UpdateStatus(self.Player.Name .. " retrying sequence...", Color3.fromRGB(255, 160, 80))
		end

		-- Show timer paused for retry
		local perStep = self.GridSize == 5 and GameConfig.TIMER_PER_STEP_SECONDS_5X5 or GameConfig.TIMER_PER_STEP_SECONDS
		local timerDuration = GameConfig.TIMER_BASE_SECONDS + (self.SequenceLength - 1) * perStep
		updateTimerEvent:FireClient(self.Player, timerDuration, "paused")

		turnNotificationEvent:FireClient(self.Player, true, self.Player.Name)
		sequenceShowEvent:FireClient(self.Player, self.Sequence)

		-- Mirror retry sequence on live preview
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
					lp:UpdateStatus(self.Player.Name .. " is entering sequence...", Color3.fromRGB(255, 220, 80))
				end
			end)
		end

		local displayTime = #self.Sequence * (GameConfig.SEQUENCE_DISPLAY_TIME + GameConfig.SEQUENCE_GAP_TIME) + 1
		task.delay(displayTime, function()
			if self.Active then
				self:StartTimer()
			end
		end)
	end
end

function SoloSession:EndGame(forced)
	if not self.Active then return end
	self.Active = false
	self:StopTimer()
	self:HideTimer()

	-- Reset platform immediately so the table stops showing gameplay
	if self.Platform then
		self.Platform:Reset()
		self.Platform = nil
	end

	-- Player reset/left — no result screen needed, they already respawned
	if forced then
		SoloGameManager.ActiveGames[self] = nil
		return
	end

	print("[Solo] Game over for " .. self.Player.Name .. " - Reached sequence: " .. self.SequenceLength)

	-- Check for new personal best BEFORE updating
	local playerData = PlayerDataManager.PlayerData[self.Player.UserId]
	local prevBest = playerData and (playerData.HighestSequence or 0) or 0
	local isNewRecord = self.SequenceLength > prevBest

	PlayerDataManager:UpdateHighestSequence(self.Player, self.SequenceLength)

	-- Quest: play 1 solo game
	PlayerDataManager:UpdateQuestProgress(self.Player, "play_solo", 1)

	-- Quest: reach sequence milestones (uses PeakSequence = highest completed this session)
	PlayerDataManager:UpdateQuestProgress(self.Player, "solo_seq_8",  self.PeakSequence)
	PlayerDataManager:UpdateQuestProgress(self.Player, "solo_seq_12", self.PeakSequence)

	-- Show result (won=false for solo, bonusCoins=0, streak=0, isNewRecord)
	gameResultEvent:FireClient(self.Player, false, self.SequenceLength, 0, 0, isNewRecord)

	task.wait(3)

	-- Hide UI
	showGameUIEvent:FireClient(self.Player, false)

	-- Unlock player
	if self.Player.Character then
		local humanoid = self.Player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
			humanoid.JumpHeight = 7.2
		end
		local hrp = self.Player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
		end
	end

	-- Remove from active games
	SoloGameManager.ActiveGames[self] = nil
end

-- Public API
function SoloGameManager:StartGame(player, platform, gridSize)
	-- Check if player already in a game
	for session in pairs(self.ActiveGames) do
		if session.Player == player then
			print("[Solo] Player " .. player.Name .. " already in a game")
			return
		end
	end

	local session = SoloSession.new(player, platform, gridSize)
	self.ActiveGames[session] = true

	local inputConnection
	local disconnectConnection
	local resetConnection

	local function cleanup()
		if inputConnection then inputConnection:Disconnect() end
		if disconnectConnection then disconnectConnection:Disconnect() end
		if resetConnection then resetConnection:Disconnect() end
		self.ActiveGames[session] = nil
	end

	local function forceEnd()
		if not session.Active then return end
		print("[Solo] " .. player.Name .. " left or reset — ending game")
		session:EndGame(true)
		cleanup()
	end

	-- Listen for input
	inputConnection = playerInputEvent.OnServerEvent:Connect(function(inputPlayer, position)
		if inputPlayer == player and session.Active then
			session:HandleInput(position)
		end
	end)

	-- Player leaves
	disconnectConnection = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player then
			forceEnd()
		end
	end)

	-- Player resets character
	resetConnection = player.CharacterAdded:Connect(function()
		forceEnd()
	end)

	-- Clean up connections after game ends naturally
	task.spawn(function()
		session:Start()
		-- Wait until the session has actually ended before disconnecting
		while session.Active do
			task.wait(1)
		end
		cleanup()
	end)
end

print("[Solo] SoloGameManager loaded")

return SoloGameManager
