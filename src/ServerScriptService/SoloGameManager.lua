-- SoloGameManager.server.lua
-- Handles solo mode - see how far you can get

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local ThemeConfig = require(ReplicatedStorage:WaitForChild("ThemeConfig"))
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))
local BattlePassManager = require(game.ServerScriptService:WaitForChild("BattlePassManager"))

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

-- Created here so it exists before any client connects
local quitSoloGameEvent = remoteEvents:FindFirstChild("QuitSoloGame") or (function()
	local e = Instance.new("RemoteEvent")
	e.Name   = "QuitSoloGame"
	e.Parent = remoteEvents
	return e
end)()

local SoloGameManager = {}
SoloGameManager.ActiveGames = {}

-- Solo Session class
local SoloSession = {}
SoloSession.__index = SoloSession

function SoloSession.new(player, platform, gridSize, themeColors)
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
	self.Tiles = {}
	self.TileConnections = {}
	self.AcceptingInput = false  -- only true during player's input phase
	self.HeartParts = {}
	self.CountdownAnchor = nil
	self.ThemeColors = themeColors or ThemeConfig.Themes.Default.Colors
	self.FlashTokens = {}  -- per-tile token to cancel stale delayed restores
	self.Barriers = {}
	return self
end

-- Helper to safely access LivePreview
function SoloSession:LP()
	return self.Platform and self.Platform.LivePreview
end

-- ── 3D Tile helpers ──────────────────────────────────────────────────────────

function SoloSession:CollectTiles()
	self.Tiles = {}
	local model = self.Platform and self.Platform.Model
	if not model then return end
	for _, part in ipairs(model:GetChildren()) do
		if part.Name:match("^Tile_%d+$") then
			local idx = tonumber(part.Name:match("%d+"))
			if idx then self.Tiles[idx] = part end
		end
	end
	local count = 0
	for _ in pairs(self.Tiles) do count = count + 1 end
	print("[Solo] Found " .. count .. " tiles on " .. model.Name)
end

function SoloSession:FlashTile(idx, color, duration)
	local tile = self.Tiles[idx]
	if not tile then return end
	tile.Color    = color
	tile.Material = Enum.Material.Neon
	local pl = tile:FindFirstChildOfClass("PointLight") or Instance.new("PointLight", tile)
	pl.Color = color; pl.Brightness = 1.5; pl.Range = 5
	local token = (self.FlashTokens[idx] or 0) + 1
	self.FlashTokens[idx] = token
	local squareColor = self.ThemeColors.Square
	task.delay(duration, function()
		if tile.Parent and self.FlashTokens[idx] == token then
			tile.Color    = squareColor
			tile.Material = Enum.Material.SmoothPlastic
			local existPl = tile:FindFirstChildOfClass("PointLight")
			if existPl then existPl:Destroy() end
		end
	end)
end

function SoloSession:FlashAllTiles(color, duration)
	for idx in pairs(self.Tiles) do
		self:FlashTile(idx, color, duration)
	end
end

function SoloSession:ResetTiles()
	for _, tile in pairs(self.Tiles) do
		tile.Color    = self.ThemeColors.Square
		tile.Material = Enum.Material.SmoothPlastic
		local pl = tile:FindFirstChildOfClass("PointLight")
		if pl then pl:Destroy() end
	end
end

function SoloSession:ShowTileSequence()
	task.spawn(function()
		for _, position in ipairs(self.Sequence) do
			if not self.Active then break end
			task.wait(GameConfig.SEQUENCE_GAP_TIME)
			self:FlashTile(position, self.ThemeColors.Highlight, GameConfig.SEQUENCE_DISPLAY_TIME)
			task.wait(GameConfig.SEQUENCE_DISPLAY_TIME)
		end
	end)
end

function SoloSession:ConnectTileInputs()
	self.TileConnections = {}
	for idx, tile in pairs(self.Tiles) do
		local cd = tile:FindFirstChildOfClass("ClickDetector")
		if cd then
			local conn = cd.MouseClick:Connect(function(clickingPlayer)
				if clickingPlayer == self.Player and self.Active and self.AcceptingInput then
					self:FlashTile(idx, self.ThemeColors.Active, 0.08)
					playerInputEvent:FireClient(self.Player, idx)
					self:HandleInput(idx)
				end
			end)
			table.insert(self.TileConnections, conn)
		end
	end
end

function SoloSession:DisconnectTileInputs()
	for _, conn in ipairs(self.TileConnections) do
		conn:Disconnect()
	end
	self.TileConnections = {}
end

-- ── Tile theme icons ─────────────────────────────────────────────────────────

function SoloSession:ApplyTileTheme()
	local icon = self.ThemeColors.Icon
	for _, tile in pairs(self.Tiles) do
		local existing = tile:FindFirstChild("TileIconGui")
		if existing then existing:Destroy() end

		if icon and icon ~= "" then
			local sg = Instance.new("SurfaceGui")
			sg.Name           = "TileIconGui"
			sg.Face           = Enum.NormalId.Top
			sg.SizingMode     = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud  = 80
			sg.AlwaysOnTop    = false
			sg.LightInfluence = 0
			sg.Parent         = tile

			local lbl = Instance.new("TextLabel", sg)
			lbl.Size                   = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text                   = icon
			lbl.TextScaled             = true
			lbl.Font                   = Enum.Font.GothamBold
			lbl.TextColor3             = self.ThemeColors.Highlight
			lbl.TextTransparency       = 0.4
			lbl.TextStrokeTransparency = 1
		end
	end
end

function SoloSession:RemoveTileIcons()
	for _, tile in pairs(self.Tiles) do
		local gui = tile:FindFirstChild("TileIconGui")
		if gui then gui:Destroy() end
	end
end

-- ── 3D Hearts ────────────────────────────────────────────────────────────────

function SoloSession:CreateHearts()
	self.HeartParts = {}
	local model = self.Platform and self.Platform.Model
	if not model then return end
	local js = model:FindFirstChild("JoinScreen")
	if not js then return end

	local cx = js.Position.X
	local cy = js.Position.Y + 0.55
	local cz = js.Position.Z
	local heartAlive = self.ThemeColors.HeartAlive
	local heartDead  = self.ThemeColors.HeartDead

	for i = 1, 3 do
		-- Flat slab facing upward — visible from top-down camera
		local heart = Instance.new("Part")
		heart.Name        = "Heart_" .. i
		heart.Size         = Vector3.new(1.4, 0.08, 1.4)
		heart.Transparency = 1
		heart.CanCollide   = false
		heart.CanQuery    = false
		heart.Anchored    = true
		heart.Position    = Vector3.new(cx + 3.1, cy, cz + (i - 2) * 1.8)
		heart.Parent      = model

		-- ♥ symbol on the top face, visible from directly above
		local sg = Instance.new("SurfaceGui", heart)
		sg.Face           = Enum.NormalId.Top
		sg.SizingMode     = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud  = 100
		sg.AlwaysOnTop    = false
		sg.LightInfluence = 0

		local lbl = Instance.new("TextLabel", sg)
		lbl.Size                   = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                   = "♥"
		lbl.TextScaled             = true
		lbl.Font                   = Enum.Font.GothamBold
		lbl.TextColor3             = heartAlive
		lbl.TextStrokeTransparency = 0.3
		lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)

		local pl = Instance.new("PointLight", heart)
		pl.Color = heartAlive; pl.Brightness = 2; pl.Range = 4

		self.HeartParts[i] = heart
	end
end

function SoloSession:UpdateHearts(lives)
	local heartAlive = self.ThemeColors.HeartAlive
	local heartDead  = self.ThemeColors.HeartDead
	for i, heart in pairs(self.HeartParts) do
		local active = i <= lives
		local sg  = heart:FindFirstChildOfClass("SurfaceGui")
		local lbl = sg and sg:FindFirstChildOfClass("TextLabel")
		if lbl then
			lbl.TextColor3 = active and heartAlive or heartDead
			lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		end
		local pl = heart:FindFirstChildOfClass("PointLight")
		if pl then pl.Enabled = active end
	end
end

function SoloSession:DestroyHearts()
	for _, heart in pairs(self.HeartParts) do
		if heart and heart.Parent then heart:Destroy() end
	end
	self.HeartParts = {}
end

-- ── 3D Countdown ─────────────────────────────────────────────────────────────

function SoloSession:ShowCountdown()
	local model = self.Platform and self.Platform.Model
	if not model then return end
	local js = model:FindFirstChild("JoinScreen")
	if not js then return end

	local anchor = Instance.new("Part")
	anchor.Name        = "CountdownAnchor"
	anchor.Size        = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.CanCollide  = false
	anchor.CanQuery    = false
	anchor.Anchored    = true
	anchor.Position    = Vector3.new(js.Position.X, js.Position.Y + 3, js.Position.Z)
	anchor.Parent      = model
	self.CountdownAnchor = anchor  -- store so EndGame can destroy it immediately

	local bb = Instance.new("BillboardGui", anchor)
	bb.Size        = UDim2.new(9, 0, 9, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0

	local lbl = Instance.new("TextLabel", bb)
	lbl.Size                  = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextScaled            = true
	lbl.Font                  = Enum.Font.GothamBold
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)

	local COLORS = {
		[3] = Color3.fromRGB(255, 80,  80),
		[2] = Color3.fromRGB(255, 200, 50),
		[1] = Color3.fromRGB(80,  255, 120),
	}

	for i = 3, 1, -1 do
		if not self.Active then break end
		lbl.Text       = tostring(i)
		lbl.TextColor3 = COLORS[i]
		countdownEvent:FireClient(self.Player, tostring(i))
		task.wait(1)
	end

	if self.Active then
		lbl.Text       = "GO!"
		lbl.TextColor3 = Color3.fromRGB(80, 255, 120)
		countdownEvent:FireClient(self.Player, "GO!")
		task.wait(0.6)
	end

	if anchor and anchor.Parent then anchor:Destroy() end
	self.CountdownAnchor = nil
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
	self.AcceptingInput = true  -- player's input phase begins
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
	self.AcceptingInput = false  -- input phase ends when timer stops
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

-- ── Platform barriers ────────────────────────────────────────────────────────

function SoloSession:CreateBarriers()
	local model = self.Platform and self.Platform.Model
	if not model then return end

	local cf, size = model:GetBoundingBox()
	local center   = cf.Position
	local halfX    = size.X / 2
	local halfZ    = size.Z / 2
	local pad      = 2       -- studs outside each edge
	local height   = 16      -- tall enough that players can't jump over
	local thick    = 0.5
	local groundY  = center.Y - size.Y / 2
	local wallY    = groundY + height / 2

	local function makeWall(x, z, sx, sz)
		local part = Instance.new("Part")
		part.Size        = Vector3.new(sx, height, sz)
		part.CFrame      = CFrame.new(x, wallY, z)
		part.Anchored    = true
		part.CanCollide  = true
		part.Transparency = 1
		part.Name        = "SoloBarrier"
		part.Parent      = workspace
		table.insert(self.Barriers, part)
	end

	local spanZ = size.Z + (pad + thick) * 2
	local spanX = size.X + (pad + thick) * 2
	makeWall(center.X + halfX + pad + thick / 2, center.Z, thick, spanZ)  -- right
	makeWall(center.X - halfX - pad - thick / 2, center.Z, thick, spanZ)  -- left
	makeWall(center.X, center.Z + halfZ + pad + thick / 2, spanX, thick)  -- front
	makeWall(center.X, center.Z - halfZ - pad - thick / 2, spanX, thick)  -- back
end

function SoloSession:RemoveBarriers()
	for _, barrier in ipairs(self.Barriers) do
		if barrier.Parent then barrier:Destroy() end
	end
	self.Barriers = {}
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
			hrp.CFrame = CFrame.new(lp.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.pi/2, 0)
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

	-- Barrier walls so other players can't walk onto the table
	self:CreateBarriers()

	-- Show UI (pass gridSize so client builds the right grid)
	showGameUIEvent:FireClient(self.Player, true, self.GridSize)
	updateLivesEvent:FireClient(self.Player, self.Lives, 0)

	-- Wire up 3D tile grid, apply theme, and create hearts
	self:CollectTiles()
	self:ResetTiles()       -- apply theme color to tiles immediately
	self:ApplyTileTheme()   -- add theme icon overlays
	self:ConnectTileInputs()
	self:CreateHearts()
	self:UpdateHearts(self.Lives)

	-- Update preview lives on start
	local lp = self:LP()
	if lp then
		lp:UpdateLives(self.Lives)
	end

	-- 3D countdown (also fires countdownEvent to client)
	self:ShowCountdown()

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

	-- Reset tiles for new round
	self:ResetTiles()

	-- Send sequence (client plays sounds; 3D tiles show the display)
	turnNotificationEvent:FireClient(self.Player, true, self.Player.Name)
	sequenceShowEvent:FireClient(self.Player, self.Sequence)
	self:ShowTileSequence()

	-- Mirror sequence on live preview
	if lp then
		task.spawn(function()
			for _, position in ipairs(self.Sequence) do
				if not self.Active then break end
				task.wait(GameConfig.SEQUENCE_GAP_TIME)
				lp:HighlightSquare(position, self.ThemeColors.Highlight)
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
			self:FlashAllTiles(Color3.fromRGB(0, 255, 0), 0.6)

			-- Track peak for quest progress
			if self.SequenceLength > self.PeakSequence then
				self.PeakSequence = self.SequenceLength
			end

			if lp then
				lp:ShowFeedback(true)
			end
			task.wait(0.6)
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
	self:FlashAllTiles(Color3.fromRGB(255, 50, 50), 0.8)
	updateLivesEvent:FireClient(self.Player, self.Lives, 0)
	self:UpdateHearts(self.Lives)

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

		-- Replay sequence on 3D tiles
		self:ResetTiles()
		turnNotificationEvent:FireClient(self.Player, true, self.Player.Name)
		sequenceShowEvent:FireClient(self.Player, self.Sequence)
		self:ShowTileSequence()

		-- Mirror retry sequence on live preview
		if lp then
			task.spawn(function()
				for _, position in ipairs(self.Sequence) do
					if not self.Active then break end
					task.wait(GameConfig.SEQUENCE_GAP_TIME)
					lp:HighlightSquare(position, self.ThemeColors.Highlight)
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
	self:DisconnectTileInputs()
	self:RemoveTileIcons()
	self:DestroyHearts()
	self:ResetTiles()
	self:StopTimer()
	self:HideTimer()

	-- Destroy countdown billboard immediately if still showing
	if self.CountdownAnchor and self.CountdownAnchor.Parent then
		self.CountdownAnchor:Destroy()
	end
	self.CountdownAnchor = nil

	-- Reset platform and remove barriers
	self:RemoveBarriers()
	if self.Platform then
		self.Platform:Reset()
		self.Platform = nil
	end

	-- Player reset/left — restore camera & focus, no result screen
	if forced then
		if self.Player.Character then
			local humanoid = self.Player.Character:FindFirstChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed  = 16
				humanoid.JumpPower  = 50
				humanoid.JumpHeight = 7.2
			end
			local hrp = self.Player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Anchored = false end
		end
		showGameUIEvent:FireClient(self.Player, false)
		SoloGameManager.ActiveGames[self] = nil
		return
	end

	print("[Solo] Game over for " .. self.Player.Name .. " - Reached sequence: " .. self.SequenceLength)

	-- Check for new personal best BEFORE updating
	local playerData = PlayerDataManager.PlayerData[self.Player.UserId]
	local prevBest = playerData and (playerData.HighestSequence or 0) or 0
	local isNewRecord = self.SequenceLength > prevBest

	PlayerDataManager:UpdateHighestSequence(self.Player, self.SequenceLength)

	-- Battle Pass XP + solo quest: only if they genuinely played (completed at least 5 tiles)
	if self.PeakSequence >= 5 then
		BattlePassManager.AddXP(self.Player, "SOLO_PLAYED")
		PlayerDataManager:UpdateQuestProgress(self.Player, "play_solo", 1)
	end

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
function SoloGameManager:StartGame(player, platform, gridSize, themeColors)
	-- Check if player already in a game
	for session in pairs(self.ActiveGames) do
		if session.Player == player then
			print("[Solo] Player " .. player.Name .. " already in a game")
			return
		end
	end

	local session = SoloSession.new(player, platform, gridSize, themeColors)
	self.ActiveGames[session] = true

	local inputConnection
	local disconnectConnection
	local characterAddedConnection
	local characterRemovingConnection
	local quitConnection

	local function cleanup()
		if inputConnection then inputConnection:Disconnect() end
		if disconnectConnection then disconnectConnection:Disconnect() end
		if characterAddedConnection then characterAddedConnection:Disconnect() end
		if characterRemovingConnection then characterRemovingConnection:Disconnect() end
		if quitConnection then quitConnection:Disconnect() end
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

	-- Player leaves server
	disconnectConnection = game.Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player then
			forceEnd()
		end
	end)

	-- CharacterRemoving fires the moment reset/death begins — fastest possible detection
	characterRemovingConnection = player.CharacterRemoving:Connect(function()
		forceEnd()
	end)

	-- CharacterAdded as a backup (catches cases CharacterRemoving may have missed)
	characterAddedConnection = player.CharacterAdded:Connect(function()
		forceEnd()
	end)

	-- Client quit button
	quitConnection = quitSoloGameEvent.OnServerEvent:Connect(function(quittingPlayer)
		if quittingPlayer == player then
			forceEnd()
		end
	end)

	-- Clean up connections after game ends naturally
	task.spawn(function()
		session:Start()
		while session.Active do
			task.wait(1)
		end
		cleanup()
	end)
end

print("[Solo] SoloGameManager loaded")

return SoloGameManager
