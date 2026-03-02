-- SoloJoinScreenManager.server.lua
-- Handles Press E to Join for solo platforms

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local ThemeConfig = require(ReplicatedStorage:WaitForChild("ThemeConfig"))
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local cameraFocusEvent = remoteEvents:WaitForChild("CameraFocus")

-- Ensure QuitSoloGame exists at server startup so clients can WaitForChild it immediately
if not remoteEvents:FindFirstChild("QuitSoloGame") then
	local e = Instance.new("RemoteEvent")
	e.Name   = "QuitSoloGame"
	e.Parent = remoteEvents
end

local SoloJoinScreenManager = {}

function SoloJoinScreenManager:SetupPlatform(platformModel)
	local joinScreen = platformModel:FindFirstChild("JoinScreen")
	if not joinScreen then return end

	local gui = joinScreen:FindFirstChild("JoinGui")
	local joinPrompt = joinScreen:FindFirstChild("JoinPrompt")
	if not gui or not joinPrompt then return end

	-- Hide the SurfaceGui panel — 3D tiles now handle the game display
	gui.Enabled = false

	-- Update prompt text for solo
	joinPrompt.ActionText = "Play Solo"
	joinPrompt.ObjectText = "Solo Memory Sequence"

	local gameInProgress = false
	local debounce = {}

	-- Read grid size from platform attribute (default 3x3)
	local gridSize = platformModel:GetAttribute("GridSize") or GameConfig.GRID_SIZE

	-- === FLOATING BILLBOARD (above platform) ===
	local joinScreenPart = joinScreen
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlatformBillboard"
	billboard.Size = UDim2.new(4, 0, 1.2, 0)   -- studs, not pixels — scales with world
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300
	billboard.Adornee = joinScreenPart
	billboard.Parent = joinScreenPart

	local billboardModeLabel = Instance.new("TextLabel")
	billboardModeLabel.Size = UDim2.new(1, 0, 0.42, 0)
	billboardModeLabel.Position = UDim2.new(0, 0, 0, 0)
	billboardModeLabel.BackgroundTransparency = 1
	billboardModeLabel.Text = gridSize == 5 and "Solo (5x5)" or "Solo Mode"
	billboardModeLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
	billboardModeLabel.TextScaled = true
	billboardModeLabel.Font = Enum.Font.GothamBold
	billboardModeLabel.TextStrokeTransparency = 0
	billboardModeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	billboardModeLabel.Parent = billboard

	local billboardCountLabel = Instance.new("TextLabel")
	billboardCountLabel.Size = UDim2.new(1, 0, 0.58, 0)
	billboardCountLabel.Position = UDim2.new(0, 0, 0.42, 0)
	billboardCountLabel.BackgroundTransparency = 1
	billboardCountLabel.Text = "Available"
	billboardCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	billboardCountLabel.TextScaled = true
	billboardCountLabel.Font = Enum.Font.GothamBold
	billboardCountLabel.TextStrokeTransparency = 0
	billboardCountLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	billboardCountLabel.Parent = billboard

	local function updateBillboard()
		if gameInProgress then
			billboardCountLabel.Text = "In Progress"
			billboardCountLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		else
			billboardCountLabel.Text = "Available"
			billboardCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	-- === LOBBY FRAME ===
	local lobbyFrame = Instance.new("Frame")
	lobbyFrame.Name = "LobbyFrame"
	lobbyFrame.Size = UDim2.new(1, 0, 1, 0)
	lobbyFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
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
	titleLabel.Text = "SOLO MODE"
	titleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	titleLabel.TextSize = 40
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextStrokeTransparency = 0
	titleLabel.Parent = lobbyFrame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0, 40)
	subtitleLabel.Position = UDim2.new(0, 0, 0, 100)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "How far can you go?"
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	subtitleLabel.TextSize = 24
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Parent = lobbyFrame

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -40, 0, 80)
	infoLabel.Position = UDim2.new(0, 20, 0, 160)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "3 Lives\nSequence grows each round\nSee how far you can get!"
	infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	infoLabel.TextSize = 22
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.Parent = lobbyFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 40)
	statusLabel.Position = UDim2.new(0, 0, 1, -60)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Press E to Play"
	statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	statusLabel.TextSize = 28
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextStrokeTransparency = 0.5
	statusLabel.Parent = lobbyFrame

	-- === LIVE PREVIEW FRAME ===
	local previewFrame = Instance.new("Frame")
	previewFrame.Name = "PreviewFrame"
	previewFrame.Size = UDim2.new(1, 0, 1, 0)
	previewFrame.BackgroundColor3 = Color3.fromRGB(20, 18, 10)
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

	-- Player name
	local previewInfoLabel = Instance.new("TextLabel")
	previewInfoLabel.Name = "InfoLabel"
	previewInfoLabel.Size = UDim2.new(1, -10, 0, 36)
	previewInfoLabel.Position = UDim2.new(0, 5, 0, 46)
	previewInfoLabel.BackgroundTransparency = 1
	previewInfoLabel.Text = "Solo Mode"
	previewInfoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	previewInfoLabel.TextSize = 20
	previewInfoLabel.Font = Enum.Font.GothamBold
	previewInfoLabel.Parent = previewFrame

	-- Lives display
	local previewLivesLabel = Instance.new("TextLabel")
	previewLivesLabel.Name = "LivesLabel"
	previewLivesLabel.Size = UDim2.new(1, -10, 0, 26)
	previewLivesLabel.Position = UDim2.new(0, 5, 0, 84)
	previewLivesLabel.BackgroundTransparency = 1
	previewLivesLabel.Text = "How far can you go?"
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
	previewSeqLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	previewSeqLabel.TextSize = 16
	previewSeqLabel.Font = Enum.Font.Gotham
	previewSeqLabel.Parent = previewFrame

	-- Grid preview: scale square size so total fits the same display area
	local squareSize = gridSize == 5 and 62 or 110
	local squareGap = 8
	local gridTotal = gridSize * squareSize + (gridSize - 1) * squareGap

	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "GridFrame"
	gridFrame.Size = UDim2.new(0, gridTotal, 0, gridTotal)
	gridFrame.Position = UDim2.new(0.5, -gridTotal / 2, 0, 142)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = previewFrame

	local previewSquares = {}
	for row = 1, gridSize do
		for col = 1, gridSize do
			local pos = (row - 1) * gridSize + col
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
	previewStatusLabel.Text = "Press E to Play!"
	previewStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	previewStatusLabel.TextSize = 18
	previewStatusLabel.Font = Enum.Font.Gotham
	previewStatusLabel.Parent = previewFrame

	-- === LivePreview API (called by SoloGameManager) ===
	local LivePreview = {}

	-- Tracks the active theme colors; reset to defaults when no game is running
	local lpColors = {
		Square    = GameConfig.SQUARE_DEFAULT_COLOR,
		Highlight = GameConfig.SQUARE_HIGHLIGHT_COLOR,
		Active    = GameConfig.SQUARE_ACTIVE_COLOR,
	}

	function LivePreview:Show(playerName, themeColors)
		if themeColors then
			lpColors.Square    = themeColors.Square
			lpColors.Highlight = themeColors.Highlight
			lpColors.Active    = themeColors.Active
		end
		liveBadge.Visible = true
		previewInfoLabel.Text = playerName .. " — Solo Run"
		previewLivesLabel.Text = "Lives: " .. string.rep("♥", GameConfig.STARTING_LIVES)
		previewSeqLabel.Text = "Sequence: 1"
		previewStatusLabel.Text = "Solo run starting..."
		previewStatusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
		self:ResetAllSquares()
	end

	function LivePreview:Hide()
		lpColors.Square    = GameConfig.SQUARE_DEFAULT_COLOR
		lpColors.Highlight = GameConfig.SQUARE_HIGHLIGHT_COLOR
		lpColors.Active    = GameConfig.SQUARE_ACTIVE_COLOR
		liveBadge.Visible = false
		previewInfoLabel.Text = "Solo Mode"
		previewLivesLabel.Text = "How far can you go?"
		previewSeqLabel.Text = ""
		previewStatusLabel.Text = "Press E to Play!"
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
			previewSquares[position].BackgroundColor3 = lpColors.Square
		end
	end

	function LivePreview:ResetAllSquares()
		for _, sq in pairs(previewSquares) do
			sq.BackgroundColor3 = lpColors.Square
		end
	end

	function LivePreview:ShowClickFlash(position)
		if previewSquares[position] then
			previewSquares[position].BackgroundColor3 = lpColors.Active
			local squareColor = lpColors.Square
			task.delay(0.12, function()
				if previewSquares[position] then
					previewSquares[position].BackgroundColor3 = squareColor
				end
			end)
		end
	end

	function LivePreview:ShowFeedback(isCorrect)
		local color = isCorrect and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
		for _, sq in pairs(previewSquares) do
			sq.BackgroundColor3 = color
		end
		task.delay(1, function()
			self:ResetAllSquares()
		end)
	end

	function LivePreview:UpdateLives(lives)
		local function hearts(n, max)
			return string.rep("♥", math.max(0, n)) .. string.rep("♡", math.max(0, max - n))
		end
		previewLivesLabel.Text = "Lives: " .. hearts(lives, GameConfig.STARTING_LIVES)
	end

	function LivePreview:UpdateSequenceLength(len)
		previewSeqLabel.Text = "Sequence: " .. len
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
		if gameInProgress then
			return
		else
			previewStatusLabel.Text = "Press E to Play!"
			previewStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
	end

	joinPrompt.Triggered:Connect(function(player)
		print("[SoloJoin] E pressed by " .. player.Name .. " on " .. platformModel.Name)

		if debounce[player.UserId] then return end
		debounce[player.UserId] = true
		task.delay(2, function()
			debounce[player.UserId] = nil
		end)

		if gameInProgress then return end

		gameInProgress = true
		joinPrompt.Enabled = false
		updateDisplay()

		print("[SoloJoin] Starting solo game for " .. player.Name)

		-- Teleport player onto the Left part, facing the JoinScreen
		local leftPart = platformModel:FindFirstChild("Left")
		if player.Character and leftPart then
			local hrp = player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local standPos = leftPart.Position + Vector3.new(0, leftPart.Size.Y / 2 + 2.5, 0)
				local centerPos = Vector3.new(joinScreen.Position.X, standPos.Y, joinScreen.Position.Z)
					hrp.CFrame = CFrame.lookAt(standPos, centerPos) * CFrame.Angles(0, math.pi/2, 0)
			end
		end
		-- Look up player's equipped theme
		local playerData = PlayerDataManager.PlayerData[player.UserId]
		local equippedKey = (playerData and playerData.EquippedTheme) or "Default"
		local themeEntry = ThemeConfig.Themes[equippedKey] or ThemeConfig.Themes.Default
		-- Merge Colors + Icon into one table so SoloSession has everything it needs
		local src = themeEntry.Colors
		local themeColors = {
			Square    = src.Square,
			Highlight = src.Highlight,
			Active    = src.Active,
			Wrong     = src.Wrong,
			HeartAlive = src.HeartAlive,
			HeartDead  = src.HeartDead,
			Icon      = themeEntry.SquareIcon or "",
		}

		-- Switch to live preview immediately with theme colors
		LivePreview:Show(player.Name, themeColors)

		-- Compute and send camera positions (pure top-down, no horizontal offset = no tilt)
		do
			local gridCenter = Vector3.new(joinScreen.Position.X, joinScreen.Position.Y + 1.2, joinScreen.Position.Z)
			local upHint = Vector3.new(-1, 0, 0) -- rotated 90° so table appears correctly centred
			local farCF   = CFrame.lookAt(gridCenter + Vector3.new(0, 18, 0), gridCenter, upHint)
			local closeCF = CFrame.lookAt(gridCenter + Vector3.new(0,  8, 0), gridCenter, upHint)
			cameraFocusEvent:FireClient(player, farCF, closeCF)
		end

		local SoloGameManager = require(game.ServerScriptService:WaitForChild("SoloGameManager"))

		local platformObj = {
			Model = platformModel,
			LeftPart = platformModel:FindFirstChild("Left"),
			RightPart = platformModel:FindFirstChild("Right"),
			LivePreview = LivePreview,
		}

		function platformObj:Reset()
			gameInProgress = false
			joinPrompt.Enabled = true
			LivePreview:Hide()
			updateBillboard()
			updateDisplay()
			print("[SoloJoin] " .. platformModel.Name .. " reset")
		end

		SoloGameManager:StartGame(player, platformObj, gridSize, themeColors)
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		debounce[player.UserId] = nil
	end)

	updateDisplay()
	print("[SoloJoin] Setup complete for " .. platformModel.Name)
end

function SoloJoinScreenManager:Initialize()
	-- Scan workspace root and the Lobby folder for solo platforms
	local function scan(parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:IsA("Model") and child.Name:match("^SoloPlatform") and child:FindFirstChild("JoinScreen") then
				self:SetupPlatform(child)
			end
		end
	end

	scan(game.Workspace)
	local lobby = game.Workspace:FindFirstChild("Lobby")
	if lobby then scan(lobby) end

	print("[SoloJoin] All solo platforms initialized")
end

task.wait(2)
SoloJoinScreenManager:Initialize()

return SoloJoinScreenManager
