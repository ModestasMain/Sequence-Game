-- TitleManager.server.lua
-- Handles BuyTitle / EquipTitle RemoteEvents and sends TitleData to clients

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))
local TitleConfig       = require(ReplicatedStorage:WaitForChild("TitleConfig"))

local remoteEvents   = ReplicatedStorage:WaitForChild("RemoteEvents")
local buyTitleEvent  = remoteEvents:WaitForChild("BuyTitle")
local equipTitleEvent = remoteEvents:WaitForChild("EquipTitle")
local titleDataEvent = remoteEvents:WaitForChild("TitleData")

local function sendTitleData(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	titleDataEvent:FireClient(player, data.OwnedTitles, data.EquippedTitle)
end

-- Send on join (wait for PlayerDataManager to finish loading)
Players.PlayerAdded:Connect(function(player)
	task.wait(2.5)
	sendTitleData(player)
end)

-- Buy
buyTitleEvent.OnServerEvent:Connect(function(player, titleKey)
	local ok, msg = PlayerDataManager:BuyTitle(player, titleKey)
	if ok then
		-- Auto-equip on purchase
		PlayerDataManager:EquipTitle(player, titleKey)
		sendTitleData(player)
		print("[TitleManager] " .. player.Name .. " bought & equipped: " .. titleKey)
	else
		print("[TitleManager] " .. player.Name .. " buy failed (" .. titleKey .. "): " .. msg)
	end
end)

-- Equip / unequip
equipTitleEvent.OnServerEvent:Connect(function(player, titleKey)
	PlayerDataManager:EquipTitle(player, titleKey) -- empty string = unequip
	sendTitleData(player)
end)

print("[TitleManager] loaded")
