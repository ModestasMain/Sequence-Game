-- SoloGameManager.server.lua
-- Handles solo mode - see how far you can get

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

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

function SoloSession.new(player, platform)
	local self = setmetatable({}, SoloSession)
	self.Player = player
	self.Platform = platform
	self.Active = true
	self.Sequence = {}
	self.SequenceLength = 0
	self.CurrentInputIndex = 1
	self.Lives = 3
	self.Started = false
	self.TimerThread = nil
	self.TimerActive = false
	return self
end

function SoloSession:GenerateSequence()
	local newPosition = math.random(1, GameConfig.GRID_SIZE * GameConfig.GRID_SIZE)
	table.insert(self.Sequence, newPosition)
	self.SequenceLength = #self.Sequence
	print("[Solo] Sequence length: " .. self.SequenceLength .. " for " .. self.Player.Name)
end

function SoloSession:StartTimer()
	self:StopTimer()
	local baseTime = 10
	local extraTime = (self.SequenceLength - 1) * 1.5
	local totalTime = baseTime + extraTime
	self.TimerActive = true

	self.TimerThread = task.spawn(function()
		local timeRemaining = totalTime
		while timeRemaining > 0 and self.TimerActive and self.Active do
			updateTimerEvent:FireClient(self.Player, timeRemaining, true)
			task.wait(0.1)
			timeRemaining = timeRemaining - 0.1
		end

		if self.TimerActive and self.Active then
			print("[Solo] Timer expired for " .. self.Player.Name)
			self.TimerActive = false
			updateTimerEvent:FireClient(self.Player, 0, false)
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
	updateTimerEvent:FireClient(self.Player, 0, false)
end

function SoloSession:Start()
	if self.Started then return end
	self.Started = true

	print("[Solo] Game starting for " .. self.Player.Name)

	-- Freeze player in place
	if self.Player.Character then
		local humanoid = self.Player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end
		local hrp = self.Player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
		end
	end

	-- Show UI
	showGameUIEvent:FireClient(self.Player, true)
	updateLivesEvent:FireClient(self.Player, self.Lives, 0)

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

	-- Update lives display (lives vs 0 for solo)
	updateLivesEvent:FireClient(self.Player, self.Lives, 0)

	-- Send sequence
	turnNotificationEvent:FireClient(self.Player, true, self.Player.Name)
	sequenceShowEvent:FireClient(self.Player, self.Sequence)

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

	if position == expectedPosition then
		self.CurrentInputIndex = self.CurrentInputIndex + 1

		-- Check if full sequence completed
		if self.CurrentInputIndex > #self.Sequence then
			self:StopTimer()
			print("[Solo] Correct sequence! Length: " .. self.SequenceLength .. " by " .. self.Player.Name)
			sequenceFeedbackEvent:FireClient(self.Player, true)
			task.wait(1.5)
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

	if self.Lives <= 0 then
		-- Game over
		task.wait(1.5)
		self:EndGame()
	else
		-- Retry same sequence
		task.wait(1.5)
		self.CurrentInputIndex = 1
		turnNotificationEvent:FireClient(self.Player, true, self.Player.Name)
		sequenceShowEvent:FireClient(self.Player, self.Sequence)

		local displayTime = #self.Sequence * (GameConfig.SEQUENCE_DISPLAY_TIME + GameConfig.SEQUENCE_GAP_TIME) + 1
		task.delay(displayTime, function()
			if self.Active then
				self:StartTimer()
			end
		end)
	end
end

function SoloSession:EndGame()
	self.Active = false
	self:StopTimer()

	print("[Solo] Game over for " .. self.Player.Name .. " - Reached sequence: " .. self.SequenceLength)

	-- Show result
	gameResultEvent:FireClient(self.Player, false, self.SequenceLength)

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

	-- Reset platform
	if self.Platform then
		self.Platform:Reset()
	end

	-- Remove from active games
	SoloGameManager.ActiveGames[self] = nil
end

-- Public API
function SoloGameManager:StartGame(player, platform)
	-- Check if player already in a game
	for session in pairs(self.ActiveGames) do
		if session.Player == player then
			print("[Solo] Player " .. player.Name .. " already in a game")
			return
		end
	end

	local session = SoloSession.new(player, platform)
	self.ActiveGames[session] = true

	-- Listen for input
	local inputConnection
	inputConnection = playerInputEvent.OnServerEvent:Connect(function(inputPlayer, position)
		if inputPlayer == player and session.Active then
			session:HandleInput(position)
		end
	end)

	-- Listen for disconnect
	local disconnectConnection
	disconnectConnection = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player and session.Active then
			session.Active = false
			session:StopTimer()
			if platform then platform:Reset() end
			self.ActiveGames[session] = nil
			inputConnection:Disconnect()
			disconnectConnection:Disconnect()
		end
	end)

	-- Clean up when game ends
	task.spawn(function()
		session:Start()
		-- After game ends, clean up connections
		task.wait(5)
		if not session.Active then
			inputConnection:Disconnect()
			disconnectConnection:Disconnect()
		end
	end)
end

print("[Solo] SoloGameManager loaded")

return SoloGameManager
