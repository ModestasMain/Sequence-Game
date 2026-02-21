-- IQPedestalManager.server.lua
-- Builds a 1st/2nd/3rd place podium showing top IQ player characters
-- All sizes are in studs. Move the "IQPodium" model in Studio to reposition.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")

local IQStore = DataStoreService:GetOrderedDataStore("Leaderboard_IQ")

-- ── Podium world anchor ────────────────────────────────────────────────────────
-- Move/rotate the "IQPodiumAnchor" part in Workspace.Lobby to reposition the podium.
local anchorPart = game.Workspace.Lobby:WaitForChild("IQPodiumAnchor")
local function getAnchor()
	-- Snap Y to ground (Y=0) so the platforms always sit on the floor,
	-- but preserve the part's X/Z position and Y-axis rotation.
	local cf = anchorPart.CFrame
	return CFrame.new(cf.X, 0, cf.Z) * CFrame.fromEulerAnglesYXZ(0, math.atan2(-cf.LookVector.X, -cf.LookVector.Z), 0)
end

-- ── Platform layout ────────────────────────────────────────────────────────────
-- xOffset: left/right of center, height: stud height of the block
local RANKS = {
	[1] = { xOffset =  0, height = 5,   color = Color3.fromRGB(255, 215,  60), medal = "🥇", label = "1ST" },
	[2] = { xOffset = -8, height = 3.5, color = Color3.fromRGB(200, 200, 200), medal = "🥈", label = "2ND" },
	[3] = { xOffset =  8, height = 2.5, color = Color3.fromRGB(205, 127,  50), medal = "🥉", label = "3RD" },
}

local PLAT_W = 6   -- platform width  (studs)
local PLAT_D = 6   -- platform depth  (studs)

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function buildPlatforms(parent)
	for rank, spec in pairs(RANKS) do
		local plat = Instance.new("Part")
		plat.Name        = "Platform" .. rank
		plat.Anchored    = true
		plat.CanCollide  = true
		plat.CastShadow  = true
		plat.Size        = Vector3.new(PLAT_W, spec.height, PLAT_D)
		plat.Color       = spec.color
		plat.Material    = Enum.Material.SmoothPlastic
		plat.TopSurface  = Enum.SurfaceType.Smooth
		plat.BottomSurface = Enum.SurfaceType.Smooth
		-- Bottom of platform sits at Y=0 (ground)
		plat.CFrame      = getAnchor() * CFrame.new(spec.xOffset, spec.height / 2, 0)
		plat.Parent      = parent

		-- Step number on front face
		local sg = Instance.new("SurfaceGui")
		sg.Face          = Enum.NormalId.Front
		sg.PixelsPerStud = 40
		sg.Parent        = plat

		local lbl = Instance.new("TextLabel")
		lbl.Size                 = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text                 = rank == 1 and "1" or rank == 2 and "2" or "3"
		lbl.TextColor3           = Color3.fromRGB(255, 255, 255)
		lbl.TextScaled           = true
		lbl.Font                 = Enum.Font.GothamBold
		lbl.TextTransparency     = 0.3
		lbl.Parent               = sg

		-- UIStroke for depth
		local stroke = Instance.new("UIStroke")
		stroke.Color     = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 3
		stroke.Parent    = lbl
	end
end

-- Place a character model on top of a platform
local function placeCharacter(userId, rank, spec, iqValue)
	-- Guard against invalid IDs (can happen in Studio with no real DataStore data)
	if not userId or userId <= 0 then
		warn("[IQPodium] Skipping invalid userId:", userId)
		return
	end

	local descOk, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
	if not descOk then
		warn("[IQPodium] GetHumanoidDescriptionFromUserId failed for", userId, desc)
		return
	end

	local rigOk, rig = pcall(
		Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15
	)
	if not rigOk then
		warn("[IQPodium] CreateHumanoidModelFromDescription failed for", userId, rig)
		return
	end

	rig.Name = "PodiumChar_" .. rank

	local hum = rig:FindFirstChildWhichIsA("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.MaxHealth = math.huge
		hum.Health    = math.huge
	end

	-- Parent first so Motor6D joints initialise and place all limbs into T-pose
	rig.Parent = game.Workspace.IQPodium
	task.wait()  -- one frame for joints to settle

	-- Now anchor every part in their T-pose positions
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored   = true
			part.CanCollide = false
		end
	end

	-- Move the fully-assembled rig onto the platform
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if hrp then
		rig.PrimaryPart = hrp
		local hipHeight  = hum and hum.HipHeight or 1.35
		local rootHeight = hipHeight + 1.3  -- HRP sits ~this far above the floor for R15

		local anchor   = getAnchor()
		local worldPos = anchor * Vector3.new(spec.xOffset, spec.height + rootHeight, -0.5)
		rig:PivotTo(CFrame.new(worldPos) * CFrame.fromEulerAnglesYXZ(0, math.atan2(-anchor.LookVector.X, -anchor.LookVector.Z), 0))
	end

	-- ── BillboardGui above head (stud-scaled) ────────────────────────────────
	local head = rig:FindFirstChild("Head")
	if not head then return end

	local nameOk, playerName = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if not nameOk then playerName = "???" end

	local bb = Instance.new("BillboardGui")
	bb.Size          = UDim2.new(9, 0, 3.5, 0)   -- 9 × 3.5 studs
	bb.StudsOffset   = Vector3.new(0, 3.5, 0)     -- float above the head
	bb.AlwaysOnTop   = true
	bb.ResetOnSpawn  = false
	bb.LightInfluence = 0
	bb.Parent        = head

	-- Medal + rank row
	local medalLabel = Instance.new("TextLabel")
	medalLabel.Size                 = UDim2.new(1, 0, 0.35, 0)
	medalLabel.Position             = UDim2.new(0, 0, 0, 0)
	medalLabel.BackgroundTransparency = 1
	medalLabel.Text                 = spec.medal .. "  " .. spec.label
	medalLabel.TextColor3           = spec.color
	medalLabel.TextScaled           = true
	medalLabel.Font                 = Enum.Font.GothamBold
	medalLabel.Parent               = bb
	local ms = Instance.new("UIStroke"); ms.Color = Color3.new(0,0,0); ms.Thickness = 2; ms.Parent = medalLabel

	-- Player name row
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size                 = UDim2.new(1, 0, 0.33, 0)
	nameLabel.Position             = UDim2.new(0, 0, 0.35, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                 = playerName
	nameLabel.TextColor3           = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled           = true
	nameLabel.Font                 = Enum.Font.GothamBold
	nameLabel.Parent               = bb
	local ns = Instance.new("UIStroke"); ns.Color = Color3.new(0,0,0); ns.Thickness = 2; ns.Parent = nameLabel

	-- IQ value row
	local iqLabel = Instance.new("TextLabel")
	iqLabel.Size                 = UDim2.new(1, 0, 0.30, 0)
	iqLabel.Position             = UDim2.new(0, 0, 0.70, 0)
	iqLabel.BackgroundTransparency = 1
	iqLabel.Text                 = "🧠 " .. iqValue .. " IQ"
	iqLabel.TextColor3           = Color3.fromRGB(100, 220, 255)
	iqLabel.TextScaled           = true
	iqLabel.Font                 = Enum.Font.Gotham
	iqLabel.Parent               = bb
	local is = Instance.new("UIStroke"); is.Color = Color3.new(0,0,0); is.Thickness = 2; is.Parent = iqLabel
end

-- ── Main build function ───────────────────────────────────────────────────────

local function buildPodium()
	-- Clean previous
	local old = game.Workspace:FindFirstChild("IQPodium")
	if old then old:Destroy() end

	local model = Instance.new("Model")
	model.Name   = "IQPodium"
	model.Parent = game.Workspace

	buildPlatforms(model)

	-- Fetch top 3 IQ scores
	local ok, pages = pcall(function()
		return IQStore:GetSortedAsync(false, 3)
	end)
	if not ok then
		warn("[IQPodium] GetSortedAsync failed:", pages)
		return
	end

	local entries = pages:GetCurrentPage()
	for rank, entry in ipairs(entries) do
		local spec    = RANKS[rank]
		local userId  = tonumber(entry.key)
		local iqValue = entry.value
		task.spawn(placeCharacter, userId, rank, spec, iqValue)
		task.wait(1)   -- stagger API calls
	end
end

-- ── Entry point ───────────────────────────────────────────────────────────────

task.wait(8)   -- let PlayerDataManager and world finish loading
buildPodium()

-- Refresh every 5 minutes
while true do
	task.wait(300)
	buildPodium()
end
