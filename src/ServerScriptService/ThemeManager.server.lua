-- ThemeManager.server.lua
-- Handles theme purchases and equipping

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ThemeConfig = require(ReplicatedStorage:WaitForChild("ThemeConfig"))
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

local remoteEvents        = ReplicatedStorage:WaitForChild("RemoteEvents")
local buyThemeEvent       = remoteEvents:WaitForChild("BuyTheme")
local equipThemeEvent     = remoteEvents:WaitForChild("EquipTheme")
local themeDataEvent      = remoteEvents:WaitForChild("ThemeData")
local requestShopData     = remoteEvents:WaitForChild("RequestShopData")

local function isOwned(ownedThemes, key)
	for _, k in ipairs(ownedThemes) do
		if k == key then return true end
	end
	return false
end

local function sendThemeData(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	themeDataEvent:FireClient(player, data.OwnedThemes, data.EquippedTheme)
end

-- Send theme data as soon as PlayerDataManager signals data is ready
PlayerDataManager.OnDataLoaded.Event:Connect(sendThemeData)

-- Resend when client requests a shop refresh (e.g. on shop open)
requestShopData.OnServerEvent:Connect(sendThemeData)

-- Handle buy request
buyThemeEvent.OnServerEvent:Connect(function(player, themeKey)
	local theme = ThemeConfig.Themes[themeKey]
	if not theme then return end

	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end

	-- Already owned — resync client so it shows correct state
	if isOwned(data.OwnedThemes, themeKey) then
		sendThemeData(player)
		return
	end

	-- Check coins
	if data.Coins < theme.Price then
		print("[Theme] " .. player.Name .. " can't afford " .. themeKey)
		return
	end

	-- Deduct coins and grant theme
	PlayerDataManager:AddCoins(player, -theme.Price)
	table.insert(data.OwnedThemes, themeKey)
	PlayerDataManager:SaveData(player)

	print("[Theme] " .. player.Name .. " bought theme: " .. themeKey)
	sendThemeData(player)
end)

-- Handle equip request
equipThemeEvent.OnServerEvent:Connect(function(player, themeKey)
	if not ThemeConfig.Themes[themeKey] then return end

	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end

	if not isOwned(data.OwnedThemes, themeKey) then return end

	data.EquippedTheme = themeKey
	PlayerDataManager:SaveData(player)

	print("[Theme] " .. player.Name .. " equipped theme: " .. themeKey)
	sendThemeData(player)
end)

print("[Theme] ThemeManager loaded")
