-- NameTagManager.server.lua
-- Stud-based BillboardGui sizing (matches NameTagScript approach):
--   Size = UDim2.new(studsW, 0, studsH, 0)  →  scales naturally with the world.
-- All child labels use scale positions/sizes (0–1 relative to the gui).

local Players = game:GetService("Players")

-- BillboardGui size in world studs
local STUD_W = 5
local STUD_H = 3

-- Text colours
local COL_STREAK = Color3.fromRGB(255, 160, 30)   -- orange
local COL_WINS   = Color3.fromRGB(255, 210, 0)    -- gold
local COL_IQ     = Color3.fromRGB(80, 200, 255)   -- cyan
local COL_NAME   = Color3.fromRGB(255, 255, 255)  -- white
local COL_RANK   = Color3.fromRGB(170, 170, 170)  -- grey

-- ── Helper: TextLabel with scale-based size/position ──────────────────────────
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

	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local leaderstats = player:WaitForChild("leaderstats", 15)
	if not leaderstats then return end

	local winsVal   = leaderstats:WaitForChild("Wins",   10)
	local iqVal     = leaderstats:WaitForChild("IQ",     10)
	local streakVal = leaderstats:WaitForChild("Streak", 10)

	local old = head:FindFirstChild("NameTag")
	if old then old:Destroy() end

	-- ── BillboardGui — stud-based size ────────────────────────────────────────
	local gui        = Instance.new("BillboardGui")
	gui.Name         = "NameTag"
	gui.Adornee      = head
	gui.StudsOffset  = Vector3.new(0, 2.5, 0)
	gui.Size         = UDim2.new(STUD_W, 0, STUD_H, 0)   -- studs, not pixels
	gui.AlwaysOnTop  = true
	gui.ResetOnSpawn = false
	gui.Parent       = head

	local root = Instance.new("Frame")
	root.Size  = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.Parent = gui

	-- ── Row 1 · Stats: 🔥 streak  🏆 wins  🧠 IQ ─────────────────────────────
	--   Y spans 0.02 → 0.32  (30% of height)
	--   Six elements across full width using scale X positions.

	label(root, { text = "🔥",  size = UDim2.new(0.10, 0, 0.28, 0), pos = UDim2.new(0.01, 0, 0.02, 0) })

	local streakNum = label(root, {
		text   = tostring(streakVal and streakVal.Value or 0),
		size   = UDim2.new(0.17, 0, 0.22, 0),
		pos    = UDim2.new(0.12, 0, 0.05, 0),
		color  = COL_STREAK,
		stroke = 0.4,
	})

	label(root, { text = "🏆",  size = UDim2.new(0.09, 0, 0.28, 0), pos = UDim2.new(0.35, 0, 0.02, 0) })

	local winsNum = label(root, {
		text   = tostring(winsVal and winsVal.Value or 0),
		size   = UDim2.new(0.14, 0, 0.22, 0),
		pos    = UDim2.new(0.45, 0, 0.05, 0),
		color  = COL_WINS,
		stroke = 0.4,
	})

	label(root, { text = "🧠",  size = UDim2.new(0.09, 0, 0.28, 0), pos = UDim2.new(0.65, 0, 0.02, 0) })

	local iqNum = label(root, {
		text   = tostring(iqVal and iqVal.Value or 100),
		size   = UDim2.new(0.20, 0, 0.22, 0),
		pos    = UDim2.new(0.75, 0, 0.05, 0),
		color  = COL_IQ,
		stroke = 0.4,
	})

	-- ── Row 2 · Player name ────────────────────────────────────────────────────
	--   Y spans 0.34 → 0.72  (38% of height)
	label(root, {
		text   = player.Name,
		size   = UDim2.new(0.96, 0, 0.38, 0),
		pos    = UDim2.new(0.02, 0, 0.34, 0),
		color  = COL_NAME,
		stroke = 0,
	})

	-- ── Row 3 · Rank ───────────────────────────────────────────────────────────
	--   Y spans 0.75 → 0.97  (22% of height)
	label(root, {
		text   = "Player",
		size   = UDim2.new(0.90, 0, 0.22, 0),
		pos    = UDim2.new(0.05, 0, 0.75, 0),
		color  = COL_RANK,
		font   = Enum.Font.Gotham,
	})

	-- ── Live updates ───────────────────────────────────────────────────────────
	if winsVal   then winsVal.Changed:Connect(  function(v) winsNum.Text   = tostring(v) end) end
	if iqVal     then iqVal.Changed:Connect(    function(v) iqNum.Text     = tostring(v) end) end
	if streakVal then streakVal.Changed:Connect(function(v) streakNum.Text = tostring(v) end) end
end

-- ── Wire up all players ───────────────────────────────────────────────────────
local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
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
