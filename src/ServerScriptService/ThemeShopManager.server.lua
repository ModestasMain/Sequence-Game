-- ThemeShopManager.server.lua
-- Creates floating spinning theme previews above chest parts so players can
-- see and buy themes directly in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ThemeConfig = require(ReplicatedStorage:WaitForChild("ThemeConfig"))
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

local themeDataEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ThemeData")

-- Paid themes to display (Default is free so we skip it)
local PAID_THEMES = { "Ocean", "Neon", "Sunset", "Ice" }

local chestsModel = game.Workspace:WaitForChild("Chests")

-- Sort chests by X position for consistent left-to-right assignment
local chestParts = {}
for _, p in ipairs(chestsModel:GetChildren()) do
	if p:IsA("BasePart") then
		table.insert(chestParts, p)
	end
end
table.sort(chestParts, function(a, b)
	return a.Position.X < b.Position.X
end)

-- Use the 4 most central chests (indices 3-6 of 8 sorted by X)
local START_INDEX = math.max(1, math.floor((#chestParts - #PAID_THEMES) / 2) + 1)

local function isOwned(ownedList, key)
	for _, k in ipairs(ownedList) do
		if k == key then return true end
	end
	return false
end

local function buildBillboard(parent, theme)
	local c = theme.Colors

	-- Stud-based size: scales with world zoom/distance (never use pixel offset here)
	local bb = Instance.new("BillboardGui")
	bb.Name = "ThemeBillboard"
	bb.Size = UDim2.new(7, 0, 9, 0)      -- 7 studs wide × 9 studs tall
	bb.StudsOffset = Vector3.new(0, 7, 0) -- 7 studs above the cube centre
	bb.AlwaysOnTop = true
	bb.ResetOnSpawn = false
	bb.Parent = parent

	-- Outer card — scale fills the entire billboard
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = c.Panel
	card.BorderSizePixel = 0
	card.Parent = bb
	Instance.new("UICorner", card).CornerRadius = UDim.new(0.06, 0)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop    = UDim.new(0.03, 0)
	pad.PaddingBottom = UDim.new(0.03, 0)
	pad.PaddingLeft   = UDim.new(0.04, 0)
	pad.PaddingRight  = UDim.new(0.04, 0)
	pad.Parent = card

	-- Theme name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.17, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = theme.Name:upper() .. " THEME"
	nameLabel.TextColor3 = c.Highlight
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = card

	-- Mini 3×3 color grid preview
	local gridBg = Instance.new("Frame")
	gridBg.Size = UDim2.new(1, 0, 0.52, 0)
	gridBg.Position = UDim2.new(0, 0, 0.19, 0)
	gridBg.BackgroundColor3 = c.Panel
	gridBg.BorderSizePixel = 0
	gridBg.Parent = card
	Instance.new("UICorner", gridBg).CornerRadius = UDim.new(0.04, 0)

	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop    = UDim.new(0.04, 0)
	gridPad.PaddingBottom = UDim.new(0.04, 0)
	gridPad.PaddingLeft   = UDim.new(0.04, 0)
	gridPad.PaddingRight  = UDim.new(0.04, 0)
	gridPad.Parent = gridBg

	-- CellSize in scale so the grid always fills its container proportionally
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.3, 0, 0.3, 0)
	layout.CellPadding = UDim2.new(0.02, 0, 0.02, 0)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = gridBg

	-- 9 cells: corners = Square, cross arms = Highlight, centre = Active
	local cellColors = {
		c.Square,    c.Highlight, c.Square,
		c.Highlight, c.Active,    c.Highlight,
		c.Square,    c.Highlight, c.Square,
	}
	for i, color in ipairs(cellColors) do
		local cell = Instance.new("Frame")
		cell.BackgroundColor3 = color
		cell.BorderSizePixel = 0
		cell.LayoutOrder = i
		cell.Parent = gridBg
		Instance.new("UICorner", cell).CornerRadius = UDim.new(0.1, 0)
	end

	-- Price badge
	local priceBg = Instance.new("Frame")
	priceBg.Size = UDim2.new(1, 0, 0.19, 0)
	priceBg.Position = UDim2.new(0, 0, 0.79, 0)
	priceBg.BackgroundColor3 = c.Highlight
	priceBg.BorderSizePixel = 0
	priceBg.Parent = card
	Instance.new("UICorner", priceBg).CornerRadius = UDim.new(0.35, 0)

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Size = UDim2.new(1, 0, 1, 0)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = "♦ " .. theme.Price .. " Coins"
	priceLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	priceLabel.TextScaled = true
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.Parent = priceBg
end

-- Give time for PlayerDataManager to load players and world to settle
task.wait(3)

local displays = {}

for i, themeKey in ipairs(PAID_THEMES) do
	local chest = chestParts[START_INDEX + i - 1]
	if not chest then continue end

	local theme = ThemeConfig.Themes[themeKey]

	-- Hide the chest — cube replaces it visually
	chest.Transparency = 1
	chest.CanCollide = false

	-- Cube sits at the same height as the chest centre
	local baseY = chest.Position.Y

	-- Spinning display cube
	local displayPart = Instance.new("Part")
	displayPart.Name = themeKey .. "_Display"
	displayPart.Size = Vector3.new(3, 3, 3)
	displayPart.Anchored = true
	displayPart.CanCollide = false
	displayPart.CastShadow = false
	displayPart.Color = theme.Colors.Panel
	displayPart.Material = Enum.Material.SmoothPlastic
	displayPart.CFrame = CFrame.new(chest.Position.X, baseY, chest.Position.Z)
	displayPart.Parent = chestsModel

	buildBillboard(displayPart, theme)

	-- ProximityPrompt on the cube itself (chest is now invisible)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = themeKey .. "_Prompt"
	prompt.ActionText = "Purchase"
	prompt.ObjectText = themeKey .. " Theme — " .. theme.Price .. " Coins"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent = displayPart

	local price = theme.Price
	prompt.Triggered:Connect(function(player)
		local data = PlayerDataManager.PlayerData[player.UserId]
		if not data then return end

		if isOwned(data.OwnedThemes, themeKey) then
			-- Already owned: equip it
			data.EquippedTheme = themeKey
			PlayerDataManager:SaveData(player)
			themeDataEvent:FireClient(player, data.OwnedThemes, data.EquippedTheme)
			print("[ThemeShop] " .. player.Name .. " equipped " .. themeKey)
			return
		end

		if data.Coins < price then
			print("[ThemeShop] " .. player.Name .. " cannot afford " .. themeKey .. " (" .. data.Coins .. "/" .. price .. ")")
			return
		end

		-- Deduct coins and grant theme
		PlayerDataManager:AddCoins(player, -price)
		table.insert(data.OwnedThemes, themeKey)
		PlayerDataManager:SaveData(player)
		themeDataEvent:FireClient(player, data.OwnedThemes, data.EquippedTheme)
		print("[ThemeShop] " .. player.Name .. " bought " .. themeKey)
	end)

	table.insert(displays, {
		part   = displayPart,
		chest  = chest,
		baseY  = baseY,
		phase  = (i - 1) * (math.pi / 2), -- stagger so they don't all bob in sync
	})
end

-- Animation: gentle bob + continuous spin + subtle tilt
local t = 0
RunService.Heartbeat:Connect(function(dt)
	t = t + dt
	for _, d in ipairs(displays) do
		local bob  = math.sin(t * 1.3 + d.phase) * 0.45
		local tilt = math.sin(t * 0.6 + d.phase) * 0.12
		local spin = t * 0.65 + d.phase
		d.part.CFrame = CFrame.new(d.chest.Position.X, d.baseY + bob, d.chest.Position.Z)
			* CFrame.fromEulerAnglesYXZ(tilt, spin, 0)
	end
end)

print("[ThemeShop] " .. #displays .. " theme displays created")
