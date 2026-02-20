-- SoundManager.server.lua
-- Sends the player's owned/equipped sound pack to the client on join.
-- Handles buy/equip requests from the in-game shop UI.
-- Fires client IMMEDIATELY after updating in-memory data; saves in background.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))
local SoundConfig       = require(ReplicatedStorage:WaitForChild("SoundConfig"))

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local soundDataEvent  = remoteEvents:WaitForChild("SoundData")
local buySoundEvent   = remoteEvents:WaitForChild("BuySound")
local equipSoundEvent = remoteEvents:WaitForChild("EquipSound")

local function sendSoundData(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	soundDataEvent:FireClient(player, data.OwnedSounds, data.EquippedSound)
end

game.Players.PlayerAdded:Connect(function(player)
	task.wait(2)
	sendSoundData(player)
end)

local function isSoundOwned(data, key)
	for _, k in ipairs(data.OwnedSounds) do
		if k == key then return true end
	end
	return false
end

buySoundEvent.OnServerEvent:Connect(function(player, soundKey)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end

	local pack = SoundConfig.Packs[soundKey]
	if not pack then return end

	if not isSoundOwned(data, soundKey) then
		if data.Coins < pack.Price then
			print("[Sound] " .. player.Name .. " can't afford: " .. soundKey)
			return
		end
		-- Update coins in memory immediately
		data.Coins = data.Coins - pack.Price
		if player:FindFirstChild("leaderstats") then
			player.leaderstats.Coins.Value = data.Coins
		end
		table.insert(data.OwnedSounds, soundKey)
		print("[Sound] " .. player.Name .. " bought: " .. soundKey)
	end

	data.EquippedSound = soundKey

	-- Fire client instantly — don't wait for saves
	soundDataEvent:FireClient(player, data.OwnedSounds, data.EquippedSound)

	-- Save in background
	task.spawn(function()
		PlayerDataManager:SaveData(player)
	end)
end)

equipSoundEvent.OnServerEvent:Connect(function(player, soundKey)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	if not isSoundOwned(data, soundKey) then return end

	data.EquippedSound = soundKey

	-- Fire client instantly
	soundDataEvent:FireClient(player, data.OwnedSounds, data.EquippedSound)

	task.spawn(function()
		PlayerDataManager:SaveData(player)
	end)
end)

print("[Sound] SoundManager loaded")
