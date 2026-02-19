-- NameTagManager.server.lua
-- Displays a custom nametag above every player's head showing
-- streak (🔥), wins (🏆), IQ (🧠), player name, and rank.

local Players = game:GetService("Players")

-- BillboardGui pixel dimensions
local GUI_W = 200
local GUI_H = 175

-- Text colours
local COL_STREAK = Color3.fromRGB(255, 160, 30)   -- orange
local COL_WINS   = Color3.fromRGB(255, 210, 0)    -- gold
local COL_IQ     = Color3.fromRGB(80, 200, 255)   -- cyan
local COL_NAME   = Color3.fromRGB(255, 255, 255)  -- white
local COL_RANK   = Color3.fromRGB(170, 170, 170)  -- grey

-- ── Helper: plain TextLabel ───────────────────────────────────────────────────
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled             = true
	l.Font                   = props.font or Enum.Font.GothamBold
	l.TextColor3             = props.color or COL_NAME
	l.Text                   = props.text or ""
	l.Size                   = props.size
	l.Position               = props.pos
	l.TextXAlignment         = props.xalign or Enum.TextXAlignment.Center
	if props.stroke ~= nil then
		l.TextStrokeTransparency = props.stroke
		l.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	end
	l.Parent = parent
	return l
end

-- ── Build nametag for one character ──────────────────────────────────────────
local function createTag(player, character)
	local head     = character:WaitForChild("Head",     10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not head or not humanoid then return end

	-- Hide the default Roblox overhead name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then return end

	local winsVal   = leaderstats:WaitForChild("Wins",   10)
	local iqVal     = leaderstats:WaitForChild("IQ",     10)
	local streakVal = leaderstats:WaitForChild("Streak", 10)

	-- Remove any leftover tag from a previous spawn
	local old = head:FindFirstChild("NameTag")
	if old then old:Destroy() end

	-- ── BillboardGui ─────────────────────────────────────────────────────────
	local gui           = Instance.new("BillboardGui")
	gui.Name            = "NameTag"
	gui.Adornee         = head
	gui.StudsOffset     = Vector3.new(0, 2.4, 0)
	gui.Size            = UDim2.new(0, GUI_W, 0, GUI_H)
	gui.AlwaysOnTop     = true
	gui.MaxDistance     = 80
	gui.ResetOnSpawn    = false
	gui.Parent          = head

	local root          = Instance.new("Frame")
	root.Size           = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.Parent         = gui

	-- ── Row 1 · Streak ───────────────────────────────────────────────────────
	--  Flame emoji (46×46) + streak number to its right, pair centred in 200px.
	--  Combined group width ≈ 46 + 6 + 36 = 88px  →  start at x = (200-88)/2 = 56

	label(root, {
		text   = "🔥",
		size   = UDim2.new(0, 46, 0, 46),
		pos    = UDim2.new(0, 56, 0, 2),
	})

	local streakNum = label(root, {
		text   = tostring(streakVal and streakVal.Value or 0),
		size   = UDim2.new(0, 36, 0, 30),
		pos    = UDim2.new(0, 108, 0, 10),
		color  = COL_STREAK,
		stroke = 0.4,
	})

	-- ── Row 2 · Wins + IQ ────────────────────────────────────────────────────
	--  Layout: 🏆(26) + wins(32) + gap(14) + 🧠(26) + IQ(36)  = 134px
	--  Centred: x-start = (200-134)/2 = 33

	label(root, {
		text   = "🏆",
		size   = UDim2.new(0, 26, 0, 26),
		pos    = UDim2.new(0, 33, 0, 58),
	})

	local winsNum = label(root, {
		text   = tostring(winsVal and winsVal.Value or 0),
		size   = UDim2.new(0, 32, 0, 22),
		pos    = UDim2.new(0, 61, 0, 62),
		color  = COL_WINS,
		stroke = 0.4,
	})

	label(root, {
		text   = "🧠",
		size   = UDim2.new(0, 26, 0, 26),
		pos    = UDim2.new(0, 107, 0, 58),
	})

	local iqNum = label(root, {
		text   = tostring(iqVal and iqVal.Value or 100),
		size   = UDim2.new(0, 36, 0, 22),
		pos    = UDim2.new(0, 135, 0, 62),
		color  = COL_IQ,
		stroke = 0.4,
	})

	-- ── Row 3 · Player name ───────────────────────────────────────────────────
	label(root, {
		text   = player.Name,
		size   = UDim2.new(1, -8, 0, 44),
		pos    = UDim2.new(0, 4, 0, 92),
		color  = COL_NAME,
		stroke = 0,
	})

	-- ── Row 4 · Rank label ────────────────────────────────────────────────────
	label(root, {
		text   = "Player",
		size   = UDim2.new(1, -8, 0, 26),
		pos    = UDim2.new(0, 4, 0, 140),
		color  = COL_RANK,
		font   = Enum.Font.Gotham,
	})

	-- ── Live updates ──────────────────────────────────────────────────────────
	if winsVal   then winsVal.Changed:Connect(  function(v) winsNum.Text   = tostring(v) end) end
	if iqVal     then iqVal.Changed:Connect(    function(v) iqNum.Text     = tostring(v) end) end
	if streakVal then streakVal.Changed:Connect(function(v) streakNum.Text = tostring(v) end) end
end

-- ── Wire up all players ───────────────────────────────────────────────────────
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)   -- brief wait for leaderstats to replicate
		createTag(player, character)
	end)
	if player.Character then
		createTag(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end
