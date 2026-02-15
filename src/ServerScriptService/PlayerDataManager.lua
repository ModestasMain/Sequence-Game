-- PlayerDataManager.lua
-- Manages player stats, coins, and data persistence

local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("PlayerStats_v1")

local PlayerDataManager = {}
PlayerDataManager.PlayerData = {} -- Cache for active players

-- Default player data structure
local function getDefaultData()
	return {
		Wins = 0,
		Losses = 0,
		Coins = 0,
		GamesPlayed = 0,
		HighestSequence = 0
	}
end

-- Load player data
function PlayerDataManager:LoadData(player)
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync("Player_" .. player.UserId)
	end)

	if success and data then
		self.PlayerData[player.UserId] = data
	else
		self.PlayerData[player.UserId] = getDefaultData()
		warn("Could not load data for " .. player.Name .. ", using defaults")
	end

	-- Create leaderstats
	self:CreateLeaderstats(player)
end

-- Save player data
function PlayerDataManager:SaveData(player)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	local success, err = pcall(function()
		PlayerDataStore:SetAsync("Player_" .. player.UserId, data)
	end)

	if not success then
		warn("Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

-- Create leaderstats folder
function PlayerDataManager:CreateLeaderstats(player)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = data.Wins
	wins.Parent = leaderstats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats
end

-- Update player stats
function PlayerDataManager:AddWin(player, coinsEarned)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	data.Wins = data.Wins + 1
	data.Coins = data.Coins + coinsEarned
	data.GamesPlayed = data.GamesPlayed + 1

	-- Update leaderstats
	if player:FindFirstChild("leaderstats") then
		player.leaderstats.Wins.Value = data.Wins
		player.leaderstats.Coins.Value = data.Coins
	end

	self:SaveData(player)
end

function PlayerDataManager:AddLoss(player, coinsEarned)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	data.Losses = data.Losses + 1
	data.Coins = data.Coins + coinsEarned
	data.GamesPlayed = data.GamesPlayed + 1

	-- Update leaderstats
	if player:FindFirstChild("leaderstats") then
		player.leaderstats.Coins.Value = data.Coins
	end

	self:SaveData(player)
end

function PlayerDataManager:UpdateHighestSequence(player, sequenceLength)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	if sequenceLength > data.HighestSequence then
		data.HighestSequence = sequenceLength
		self:SaveData(player)
	end
end

-- Initialize
game.Players.PlayerAdded:Connect(function(player)
	PlayerDataManager:LoadData(player)
end)

game.Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager:SaveData(player)
	PlayerDataManager.PlayerData[player.UserId] = nil
end)

return PlayerDataManager
