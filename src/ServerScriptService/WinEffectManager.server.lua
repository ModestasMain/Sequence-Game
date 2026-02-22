-- WinEffectManager.server.lua
-- Sends equipped win effect to client on join; handles buy/equip requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))
local WinEffectConfig   = require(ReplicatedStorage:WaitForChild("WinEffectConfig"))

local remoteEvents        = ReplicatedStorage:WaitForChild("RemoteEvents")
local winEffectDataEvent  = remoteEvents:WaitForChild("WinEffectData")
local buyWinEffectEvent   = remoteEvents:WaitForChild("BuyWinEffect")
local equipWinEffectEvent = remoteEvents:WaitForChild("EquipWinEffect")
local requestShopData     = remoteEvents:WaitForChild("RequestShopData")

local function sendWinEffectData(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	winEffectDataEvent:FireClient(player, data.OwnedWinEffects, data.EquippedWinEffect)
end

PlayerDataManager.OnDataLoaded.Event:Connect(sendWinEffectData)
requestShopData.OnServerEvent:Connect(sendWinEffectData)

local function isOwned(data, key)
	for _, k in ipairs(data.OwnedWinEffects) do
		if k == key then return true end
	end
	return false
end

buyWinEffectEvent.OnServerEvent:Connect(function(player, effectKey)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end

	local effect = WinEffectConfig.Effects[effectKey]
	if not effect then return end

	if not isOwned(data, effectKey) then
		if data.Coins < effect.Price then
			print("[WinEffect] " .. player.Name .. " can't afford: " .. effectKey)
			winEffectDataEvent:FireClient(player, data.OwnedWinEffects, data.EquippedWinEffect)
			return
		end
		data.Coins = data.Coins - effect.Price
		if player:FindFirstChild("leaderstats") then
			player.leaderstats.Coins.Value = data.Coins
		end
		table.insert(data.OwnedWinEffects, effectKey)
		print("[WinEffect] " .. player.Name .. " bought: " .. effectKey)
	end

	data.EquippedWinEffect = effectKey
	winEffectDataEvent:FireClient(player, data.OwnedWinEffects, data.EquippedWinEffect)

	task.spawn(function()
		PlayerDataManager:SaveData(player)
	end)
end)

equipWinEffectEvent.OnServerEvent:Connect(function(player, effectKey)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	if not isOwned(data, effectKey) then return end

	data.EquippedWinEffect = effectKey
	winEffectDataEvent:FireClient(player, data.OwnedWinEffects, data.EquippedWinEffect)

	task.spawn(function()
		PlayerDataManager:SaveData(player)
	end)
end)

print("[WinEffect] WinEffectManager loaded")
