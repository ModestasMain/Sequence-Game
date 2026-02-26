-- ReactionTime.client.lua
-- Fully local reaction time minigame — all players play independently.
-- Click the PLAY board on the island → countdown → red circle → green circle → click it!

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remote events
local remoteEvents      = ReplicatedStorage:WaitForChild("RemoteEvents")
local scoreEvent        = remoteEvents:WaitForChild("ReactionScore")
local leaderboardEvent  = remoteEvents:WaitForChild("ReactionLeaderboard")

-- Island refs
local island       = workspace:WaitForChild("ReactionIsland")
local playBoard    = island:WaitForChild("PlayBoard")
local clickDet     = playBoard:WaitForChild("ClickDetector")
local leaderBoard  = island:WaitForChild("LeaderBoard")
local leaderGui    = leaderBoard:WaitForChild("LeaderGui")
local contentLabel = leaderGui:WaitForChild("ContentLabel")

local isPlaying = false

-- Confetti palette
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80,  80),
	Color3.fromRGB(80,  180, 255),
	Color3.fromRGB(255, 220, 0),
	Color3.fromRGB(100, 255, 120),
	Color3.fromRGB(200, 100, 255),
	Color3.fromRGB(255, 150, 50),
	Color3.fromRGB(255, 255, 255),
}

-- ─── Confetti ──────────────────────────────────────────────────────────────
local function spawnConfetti(parent: Instance)
	for _ = 1, 90 do
		task.spawn(function()
			local piece = Instance.new("Frame")
			piece.Size              = UDim2.new(0, math.random(8, 18), 0, math.random(8, 18))
			piece.Position          = UDim2.fromScale(math.random(), -0.06)
			piece.BackgroundColor3  = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
			piece.BorderSizePixel   = 0
			piece.Rotation          = math.random(0, 360)
			piece.ZIndex            = 5
			piece.Parent            = parent
			local corner = Instance.new("UICorner", piece)
			corner.CornerRadius = UDim.new(0.15, 0)

			local dur  = 1.8 + math.random() * 1.6
			local endX = piece.Position.X.Scale + (math.random() - 0.5) * 0.35
			task.wait(math.random() * 0.7)
			TweenService:Create(piece, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(endX, 1.15),
				Rotation = piece.Rotation + math.random(-300, 300),
			}):Play()
			task.wait(dur + 0.2)
			if piece.Parent then piece:Destroy() end
		end)
	end
end

-- ─── Rating ────────────────────────────────────────────────────────────────
local function getRating(ms: number): (string, Color3)
	if ms < 150 then return "LEGENDARY!",      Color3.fromRGB(255, 215,   0)  end
	if ms < 200 then return "ELITE!",          Color3.fromRGB(180, 100, 255)  end
	if ms < 250 then return "GREAT!",          Color3.fromRGB(0,   220, 120)  end
	if ms < 350 then return "GOOD",            Color3.fromRGB(80,  180, 255)  end
	if ms < 500 then return "AVERAGE",         Color3.fromRGB(200, 200, 200)  end
	return              "KEEP PRACTISING",     Color3.fromRGB(200, 120,  80)
end

-- ─── Result Screen ─────────────────────────────────────────────────────────
local function showResult(ms: number)
	local rating, ratingCol = getRating(ms)

	local gui = Instance.new("ScreenGui")
	gui.Name           = "ReactionResult"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn   = false
	gui.DisplayOrder   = 110
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent         = playerGui

	-- Dim backdrop
	local bg = Instance.new("Frame", gui)
	bg.Size                   = UDim2.fromScale(1, 1)
	bg.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 0.45
	bg.BorderSizePixel        = 0
	bg.ZIndex                 = 1

	-- Confetti flies on top
	spawnConfetti(gui)

	-- Celebration sound
	local sound = Instance.new("Sound", gui)
	sound.SoundId = "rbxassetid://9120038906"
	sound.Volume  = 0.85
	sound:Play()

	-- Result card
	local card = Instance.new("Frame", gui)
	card.Size             = UDim2.fromScale(0.38, 0.52)
	card.Position         = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint      = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	card.BorderSizePixel  = 0
	card.ZIndex           = 10
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color     = Color3.fromRGB(60, 60, 70)
	stroke.Thickness = 1.5

	-- "YOUR TIME" header
	local header = Instance.new("TextLabel", card)
	header.Size                   = UDim2.fromScale(1, 0.16)
	header.Position               = UDim2.fromScale(0, 0.06)
	header.BackgroundTransparency = 1
	header.Text                   = "YOUR TIME"
	header.TextColor3             = Color3.fromRGB(150, 150, 160)
	header.Font                   = Enum.Font.GothamBold
	header.TextScaled             = true
	header.ZIndex                 = 11

	-- Big time value
	local timeLabel = Instance.new("TextLabel", card)
	timeLabel.Size                   = UDim2.fromScale(1, 0.28)
	timeLabel.Position               = UDim2.fromScale(0, 0.22)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text                   = string.format("%d ms", math.round(ms))
	timeLabel.TextColor3             = Color3.fromRGB(0, 240, 120)
	timeLabel.Font                   = Enum.Font.GothamBold
	timeLabel.TextScaled             = true
	timeLabel.ZIndex                 = 11

	-- Rating
	local ratingLabel = Instance.new("TextLabel", card)
	ratingLabel.Size                   = UDim2.fromScale(1, 0.18)
	ratingLabel.Position               = UDim2.fromScale(0, 0.50)
	ratingLabel.BackgroundTransparency = 1
	ratingLabel.Text                   = rating
	ratingLabel.TextColor3             = ratingCol
	ratingLabel.Font                   = Enum.Font.GothamBold
	ratingLabel.TextScaled             = true
	ratingLabel.ZIndex                 = 11

	-- Play Again button
	local playAgain = Instance.new("TextButton", card)
	playAgain.Size             = UDim2.fromScale(0.58, 0.14)
	playAgain.Position         = UDim2.fromScale(0.5, 0.82)
	playAgain.AnchorPoint      = Vector2.new(0.5, 0.5)
	playAgain.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
	playAgain.Text             = "Play Again"
	playAgain.TextColor3       = Color3.fromRGB(20, 20, 26)
	playAgain.Font             = Enum.Font.GothamBold
	playAgain.TextScaled       = true
	playAgain.BorderSizePixel  = 0
	playAgain.ZIndex           = 11
	playAgain.AutoButtonColor  = false
	Instance.new("UICorner", playAgain).CornerRadius = UDim.new(0.3, 0)

	-- Hover effect
	playAgain.MouseEnter:Connect(function()
		TweenService:Create(playAgain, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(210, 210, 220)}):Play()
	end)
	playAgain.MouseLeave:Connect(function()
		TweenService:Create(playAgain, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(240, 240, 245)}):Play()
	end)

	local function close()
		gui:Destroy()
		isPlaying = false
	end

	playAgain.MouseButton1Click:Connect(close)

	-- Auto-dismiss after 7 seconds
	task.delay(7, function()
		if gui.Parent then close() end
	end)
end

-- ─── Main Game ─────────────────────────────────────────────────────────────
local function runGame()
	if isPlaying then return end
	isPlaying = true

	-- ── Countdown GUI (3 2 1) ──
	local countGui = Instance.new("ScreenGui")
	countGui.Name           = "ReactionCountdown"
	countGui.IgnoreGuiInset = true
	countGui.ResetOnSpawn   = false
	countGui.DisplayOrder   = 105
	countGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	countGui.Parent         = playerGui

	local countLabel = Instance.new("TextLabel", countGui)
	countLabel.Size                   = UDim2.fromScale(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font                   = Enum.Font.GothamBold
	countLabel.TextScaled             = true
	countLabel.TextTransparency       = 1
	countLabel.TextColor3             = Color3.fromRGB(255, 220, 80)

	for i = 3, 1, -1 do
		countLabel.Text = tostring(i)
		TweenService:Create(countLabel, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
		task.wait(0.65)
		TweenService:Create(countLabel, TweenInfo.new(0.18), {TextTransparency = 1}):Play()
		task.wait(0.35)
	end
	countGui:Destroy()

	-- ── Reaction GUI ──
	local gameGui = Instance.new("ScreenGui")
	gameGui.Name           = "ReactionGame"
	gameGui.IgnoreGuiInset = true
	gameGui.ResetOnSpawn   = false
	gameGui.DisplayOrder   = 106
	gameGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gameGui.Parent         = playerGui

	-- Dark overlay
	local overlay = Instance.new("Frame", gameGui)
	overlay.Size                   = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel        = 0

	-- Big reaction circle (starts RED)
	local circle = Instance.new("TextButton", gameGui)
	circle.Size             = UDim2.fromScale(0.22, 0.22)
	circle.Position         = UDim2.fromScale(0.5, 0.46)
	circle.AnchorPoint      = Vector2.new(0.5, 0.5)
	circle.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	circle.Text             = "WAIT..."
	circle.TextColor3       = Color3.fromRGB(255, 255, 255)
	circle.Font             = Enum.Font.GothamBold
	circle.TextScaled       = true
	circle.BorderSizePixel  = 0
	circle.AutoButtonColor  = false
	circle.ZIndex           = 2
	Instance.new("UICorner", circle).CornerRadius          = UDim.new(1, 0)
	Instance.new("UIAspectRatioConstraint", circle).AspectRatio = 1

	-- Hint text below
	local hint = Instance.new("TextLabel", gameGui)
	hint.Size                   = UDim2.fromScale(0.5, 0.06)
	hint.Position               = UDim2.fromScale(0.5, 0.72)
	hint.AnchorPoint            = Vector2.new(0.5, 0)
	hint.BackgroundTransparency = 1
	hint.Text                   = "Wait for green..."
	hint.TextColor3             = Color3.fromRGB(200, 200, 210)
	hint.Font                   = Enum.Font.Gotham
	hint.TextScaled             = true
	hint.ZIndex                 = 2

	-- ── Red phase: random 1.2–4.5 s delay ──
	local waitTime  = 1.2 + math.random() * 3.3
	local earlyClick = false

	local earlyConn = circle.MouseButton1Click:Connect(function()
		earlyClick = true
	end)

	task.wait(waitTime)
	earlyConn:Disconnect()

	if earlyClick then
		-- Too early — flash orange, brief penalty
		circle.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
		circle.Text             = "TOO EARLY!"
		hint.Text               = "Don't click on red!"
		task.wait(2)
		gameGui:Destroy()
		isPlaying = false
		return
	end

	-- ── Green phase — GO! ──
	TweenService:Create(circle, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(0, 215, 85)}):Play()
	circle.Text = "CLICK!"
	hint.Text   = "NOW!"

	local goTime  = tick()
	local clicked = false
	local resultMs = 0

	local clickConn = circle.MouseButton1Click:Connect(function()
		if not clicked then
			clicked   = true
			resultMs  = (tick() - goTime) * 1000
		end
	end)

	-- Wait up to 5 s for click
	local elapsed = 0
	while not clicked and elapsed < 5 do
		task.wait(0.016)
		elapsed += 0.016
	end
	clickConn:Disconnect()
	gameGui:Destroy()

	if not clicked then
		-- Timed out — just reset quietly
		isPlaying = false
		return
	end

	-- Submit score to server (server validates & saves personal best)
	scoreEvent:FireServer(resultMs)

	showResult(resultMs)
end

-- ─── Leaderboard display ────────────────────────────────────────────────────
local function updateLeaderboard(data: {})
	if #data == 0 then
		contentLabel.Text = "No scores yet!\nBe the first to play."
		return
	end

	local lines = {}
	for _, entry in ipairs(data) do
		-- Truncate to 9 chars max so lines stay short
		local name = entry.name
		if #name > 9 then name = name:sub(1, 8) .. "." end
		table.insert(lines, string.format("#%d %s - %dms", entry.rank, name, entry.ms))
	end

	contentLabel.Text = table.concat(lines, "\n")
end

leaderboardEvent.OnClientEvent:Connect(updateLeaderboard)

-- ── Entry point ─────────────────────────────────────────────────────────────
clickDet.MouseClick:Connect(function()
	task.spawn(runGame)
end)
