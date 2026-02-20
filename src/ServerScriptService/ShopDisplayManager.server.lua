-- ShopDisplayManager.server.lua
-- Creates all floating theme + title + sound displays around the lobby island perimeter.
-- Each display hides the ground beneath it, spins + bobs, and has a ProximityPrompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local ThemeConfig       = require(ReplicatedStorage:WaitForChild("ThemeConfig"))
local TitleConfig       = require(ReplicatedStorage:WaitForChild("TitleConfig"))
local SoundConfig       = require(ReplicatedStorage:WaitForChild("SoundConfig"))
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

local remoteEvents   = ReplicatedStorage:WaitForChild("RemoteEvents")
local themeDataEvent = remoteEvents:WaitForChild("ThemeData")
local titleDataEvent = remoteEvents:WaitForChild("TitleData")
local soundDataEvent = remoteEvents:WaitForChild("SoundData")

local chestsModel = game.Workspace:WaitForChild("Chests")

-- ── Anchor: move "ShopAnchor" in Workspace.Chests to reposition everything ────
-- Items spread in the -Z direction from the anchor's position.
-- Spacing and sizes below are hardcoded; only the anchor's world position matters.
local anchor = chestsModel:WaitForChild("ShopAnchor")
anchor.Transparency = 1
anchor.CanCollide   = false

local ITEM_SPACING   = 12   -- studs between each item
local SECTION_GAP    = 16   -- extra gap between titles and themes sections

-- ── Build display list from anchor ────────────────────────────────────────────
local TITLE_KEYS = { "BrainRot", "TouchGrass", "TryingMyBest", "TheThinker", "TheVeteran", "SequenceKing", "PatternGod", "TheChosenOne" }
local THEME_KEYS = { "Ocean", "Forest", "Neon", "Sunset", "Ice", "Candy", "Lava", "Galaxy" }
local SOUND_KEYS = { "Piano", "Osu", "Typewriter", "VineBoom" }

local DISPLAYS = {}
local zOffset = 0

for _, key in ipairs(TITLE_KEYS) do
	table.insert(DISPLAYS, { pos = (anchor.CFrame * CFrame.new(0, 0, zOffset)).Position, type = "title", key = key })
	zOffset -= ITEM_SPACING
end

zOffset -= SECTION_GAP

for _, key in ipairs(THEME_KEYS) do
	table.insert(DISPLAYS, { pos = (anchor.CFrame * CFrame.new(0, 0, zOffset)).Position, type = "theme", key = key })
	zOffset -= ITEM_SPACING
end

-- Sounds turn perpendicular: go in +Z world direction (local -X with Y=90 anchor)
-- so they stay within the island instead of continuing off-edge
local turnLocalZ = zOffset + ITEM_SPACING  -- local Z of the last theme
for i, key in ipairs(SOUND_KEYS) do
	local pos = (anchor.CFrame * CFrame.new(-i * ITEM_SPACING, 0, turnLocalZ)).Position
	table.insert(DISPLAYS, { pos = pos, type = "sound", key = key })
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function isOwned(list, key)
	for _, k in ipairs(list) do if k == key then return true end end
	return false
end

local function addCorner(parent, radius)
	Instance.new("UICorner", parent).CornerRadius = radius
end

-- ── Billboard builder ─────────────────────────────────────────────────────────

local function buildThemeBillboard(parent, theme)
	local c = theme.Colors

	local bb = Instance.new("BillboardGui")
	bb.Size         = UDim2.new(7, 0, 9, 0)
	bb.StudsOffset  = Vector3.new(0, 7, 0)
	bb.AlwaysOnTop  = true
	bb.ResetOnSpawn = false
	bb.Parent       = parent

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = c.Panel
	card.BorderSizePixel  = 0
	card.Parent = bb
	addCorner(card, UDim.new(0.06, 0))

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.03, 0); pad.PaddingBottom = UDim.new(0.03, 0)
	pad.PaddingLeft = UDim.new(0.04, 0); pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.17, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = theme.Name:upper() .. " THEME"
	nameLabel.TextColor3 = c.Highlight
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = card

	local gridBg = Instance.new("Frame")
	gridBg.Size = UDim2.new(1, 0, 0.52, 0)
	gridBg.Position = UDim2.new(0, 0, 0.19, 0)
	gridBg.BackgroundColor3 = c.Panel
	gridBg.BorderSizePixel  = 0
	gridBg.Parent = card
	addCorner(gridBg, UDim.new(0.04, 0))

	local gPad = Instance.new("UIPadding")
	gPad.PaddingTop = UDim.new(0.04, 0); gPad.PaddingBottom = UDim.new(0.04, 0)
	gPad.PaddingLeft = UDim.new(0.04, 0); gPad.PaddingRight = UDim.new(0.04, 0)
	gPad.Parent = gridBg

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.3, 0, 0.3, 0)
	layout.CellPadding = UDim2.new(0.02, 0, 0.02, 0)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment   = Enum.VerticalAlignment.Center
	layout.Parent = gridBg

	local cells = { c.Square, c.Highlight, c.Square, c.Highlight, c.Active, c.Highlight, c.Square, c.Highlight, c.Square }
	for i, col in ipairs(cells) do
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = col; cell.BorderSizePixel = 0; cell.LayoutOrder = i
		cell.Parent = gridBg
		addCorner(cell, UDim.new(0.1, 0))
	end

	local priceBg = Instance.new("Frame")
	priceBg.Size = UDim2.new(1, 0, 0.19, 0)
	priceBg.Position = UDim2.new(0, 0, 0.79, 0)
	priceBg.BackgroundColor3 = c.Highlight
	priceBg.BorderSizePixel  = 0
	priceBg.Parent = card
	addCorner(priceBg, UDim.new(0.35, 0))

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(1, 0, 1, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = "♦ " .. theme.Price .. " Coins"
	priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	priceLabel.TextScaled = true
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.Parent = priceBg
end

local function buildTitleBillboard(parent, title)
	local c = title.Color

	local bb = Instance.new("BillboardGui")
	bb.Size         = UDim2.new(6, 0, 5, 0)
	bb.StudsOffset  = Vector3.new(0, 6, 0)
	bb.AlwaysOnTop  = true
	bb.ResetOnSpawn = false
	bb.Parent       = parent

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = bb
	addCorner(card, UDim.new(0.08, 0))

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.05, 0); pad.PaddingBottom = UDim.new(0.05, 0)
	pad.PaddingLeft = UDim.new(0.05, 0); pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = card

	local typeLabel = Instance.new("TextLabel")
	typeLabel.Size = UDim2.new(1, 0, 0.2, 0)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Text = "TITLE"
	typeLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	typeLabel.TextScaled = true
	typeLabel.Font = Enum.Font.Gotham
	typeLabel.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.38, 0)
	nameLabel.Position = UDim2.new(0, 0, 0.2, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = title.Name
	nameLabel.TextColor3 = c
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Parent = card

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(0.8, 0, 0.02, 0)
	divider.Position = UDim2.new(0.1, 0, 0.6, 0)
	divider.BackgroundColor3 = c
	divider.BorderSizePixel = 0
	divider.Parent = card

	local priceBg = Instance.new("Frame")
	priceBg.Size = UDim2.new(1, 0, 0.28, 0)
	priceBg.Position = UDim2.new(0, 0, 0.68, 0)
	priceBg.BackgroundColor3 = c
	priceBg.BackgroundTransparency = 0.3
	priceBg.BorderSizePixel = 0
	priceBg.Parent = card
	addCorner(priceBg, UDim.new(0.3, 0))

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(1, 0, 1, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = "♦ " .. title.Price .. " Coins"
	priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	priceLabel.TextScaled = true
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.Parent = priceBg
end

local function buildSoundBillboard(parent, pack)
	local c = pack.Color

	local bb = Instance.new("BillboardGui")
	bb.Size         = UDim2.new(5, 0, 4, 0)
	bb.StudsOffset  = Vector3.new(0, 5, 0)
	bb.AlwaysOnTop  = true
	bb.ResetOnSpawn = false
	bb.Parent       = parent

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = bb
	addCorner(card, UDim.new(0.08, 0))

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.05, 0); pad.PaddingBottom = UDim.new(0.05, 0)
	pad.PaddingLeft = UDim.new(0.05, 0); pad.PaddingRight = UDim.new(0.05, 0)
	pad.Parent = card

	local typeLabel = Instance.new("TextLabel")
	typeLabel.Size = UDim2.new(1, 0, 0.18, 0)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Text = "SOUND PACK"
	typeLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	typeLabel.TextScaled = true
	typeLabel.Font = Enum.Font.Gotham
	typeLabel.Parent = card

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(0.25, 0, 0.32, 0)
	iconLabel.Position = UDim2.new(0, 0, 0.18, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = pack.Icon
	iconLabel.TextScaled = true
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.72, 0, 0.32, 0)
	nameLabel.Position = UDim2.new(0.26, 0, 0.18, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = pack.Name
	nameLabel.TextColor3 = c
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, 0, 0.18, 0)
	descLabel.Position = UDim2.new(0, 0, 0.50, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = pack.Description
	descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	descLabel.TextScaled = true
	descLabel.Font = Enum.Font.Gotham
	descLabel.Parent = card

	local priceBg = Instance.new("Frame")
	priceBg.Size = UDim2.new(1, 0, 0.22, 0)
	priceBg.Position = UDim2.new(0, 0, 0.74, 0)
	priceBg.BackgroundColor3 = c
	priceBg.BackgroundTransparency = 0.3
	priceBg.BorderSizePixel = 0
	priceBg.Parent = card
	addCorner(priceBg, UDim.new(0.3, 0))

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(1, 0, 1, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = "♦ " .. pack.Price .. " Coins"
	priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	priceLabel.TextScaled = true
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.Parent = priceBg
end

-- ── Create all displays ───────────────────────────────────────────────────────

task.wait(3)

local animated = {}

for i, cfg in ipairs(DISPLAYS) do
	local isTheme = cfg.type == "theme"
	local isSound = cfg.type == "sound"
	local color, price

	if isTheme then
		local t = ThemeConfig.Themes[cfg.key]
		color = t.Colors.Panel
		price = t.Price
	elseif isSound then
		local t = SoundConfig.Packs[cfg.key]
		color = t.Color
		price = t.Price
	else
		local t = TitleConfig.Titles[cfg.key]
		color = t.Color
		price = t.Price
	end

	-- Display cube
	local part = Instance.new("Part")
	part.Name       = cfg.key .. "_ShopDisplay"
	part.Size       = isTheme and Vector3.new(3, 3, 3) or Vector3.new(2, 2, 2)
	part.Anchored   = true
	part.CanCollide = false
	part.CastShadow = false
	part.Color      = color
	part.Material   = (isTheme or isSound) and Enum.Material.SmoothPlastic or Enum.Material.Neon
	part.CFrame     = CFrame.new(cfg.pos)
	part.Parent     = chestsModel

	-- Billboard
	if isTheme then
		buildThemeBillboard(part, ThemeConfig.Themes[cfg.key])
	elseif isSound then
		buildSoundBillboard(part, SoundConfig.Packs[cfg.key])
	else
		buildTitleBillboard(part, TitleConfig.Titles[cfg.key])
	end

	-- ProximityPrompt
	local displayName
	if isTheme then
		displayName = cfg.key .. " Theme"
	elseif isSound then
		displayName = SoundConfig.Packs[cfg.key].Name .. " Sound Pack"
	else
		displayName = TitleConfig.Titles[cfg.key].Name .. " Title"
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText            = "Buy / Equip"
	prompt.ObjectText            = displayName .. " — " .. price .. " Coins"
	prompt.HoldDuration          = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent                = part

	local capturedKey  = cfg.key
	local capturedType = cfg.type

	prompt.Triggered:Connect(function(player)
		local data = PlayerDataManager.PlayerData[player.UserId]
		if not data then return end

		if capturedType == "theme" then
			local theme = ThemeConfig.Themes[capturedKey]
			if isOwned(data.OwnedThemes, capturedKey) then
				data.EquippedTheme = capturedKey
				PlayerDataManager:SaveData(player)
				themeDataEvent:FireClient(player, data.OwnedThemes, data.EquippedTheme)
			elseif data.Coins >= theme.Price then
				PlayerDataManager:AddCoins(player, -theme.Price)
				table.insert(data.OwnedThemes, capturedKey)
				PlayerDataManager:SaveData(player)
				themeDataEvent:FireClient(player, data.OwnedThemes, data.EquippedTheme)
				print("[ShopDisplay] " .. player.Name .. " bought theme: " .. capturedKey)
			else
				print("[ShopDisplay] " .. player.Name .. " can't afford theme: " .. capturedKey)
			end
		elseif capturedType == "sound" then
			local pack = SoundConfig.Packs[capturedKey]
			local alreadyOwned = false
			for _, k in ipairs(data.OwnedSounds) do if k == capturedKey then alreadyOwned = true; break end end

			if not alreadyOwned then
				if data.Coins < pack.Price then
					print("[ShopDisplay] " .. player.Name .. " can't afford sound: " .. capturedKey)
				else
					-- Update memory immediately, save in background
					data.Coins = data.Coins - pack.Price
					if player:FindFirstChild("leaderstats") then
						player.leaderstats.Coins.Value = data.Coins
					end
					table.insert(data.OwnedSounds, capturedKey)
					data.EquippedSound = capturedKey
					soundDataEvent:FireClient(player, data.OwnedSounds, data.EquippedSound)
					task.spawn(function() PlayerDataManager:SaveData(player) end)
					print("[ShopDisplay] " .. player.Name .. " bought sound: " .. capturedKey)
				end
			else
				-- Toggle equip/unequip
				data.EquippedSound = (data.EquippedSound == capturedKey) and "Default" or capturedKey
				soundDataEvent:FireClient(player, data.OwnedSounds, data.EquippedSound)
				task.spawn(function() PlayerDataManager:SaveData(player) end)
			end
		else
			local ok, msg = PlayerDataManager:BuyTitle(player, capturedKey)
			if ok then
				PlayerDataManager:EquipTitle(player, capturedKey)
				local d = PlayerDataManager.PlayerData[player.UserId]
				titleDataEvent:FireClient(player, d.OwnedTitles, d.EquippedTitle)
				print("[ShopDisplay] " .. player.Name .. " bought title: " .. capturedKey)
			elseif msg == "Already owned" then
				-- Toggle equip/unequip
				if data.EquippedTitle == capturedKey then
					PlayerDataManager:EquipTitle(player, "")
				else
					PlayerDataManager:EquipTitle(player, capturedKey)
				end
				local d = PlayerDataManager.PlayerData[player.UserId]
				titleDataEvent:FireClient(player, d.OwnedTitles, d.EquippedTitle)
			else
				print("[ShopDisplay] " .. player.Name .. " can't buy title: " .. capturedKey .. " (" .. msg .. ")")
			end
		end
	end)

	table.insert(animated, {
		part  = part,
		baseY = cfg.pos.Y,
		phase = (i - 1) * (math.pi * 2 / #DISPLAYS),
		speed = isTheme and 0.65 or 0.4,
	})
end

-- ── Animation loop ────────────────────────────────────────────────────────────
local t = 0
RunService.Heartbeat:Connect(function(dt)
	t = t + dt
	for _, d in ipairs(animated) do
		local bob  = math.sin(t * 1.2 + d.phase) * 0.45
		local tilt = math.sin(t * 0.6 + d.phase) * 0.1
		local spin = t * d.speed + d.phase
		d.part.CFrame = CFrame.new(d.part.Position.X, d.baseY + bob, d.part.Position.Z)
			* CFrame.fromEulerAnglesYXZ(tilt, spin, 0)
	end
end)

print("[ShopDisplay] " .. #animated .. " displays created around the island")
