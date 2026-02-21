-- PlayerDataManager.lua
-- Manages player stats, coins, and data persistence

local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("PlayerStats_v1")

-- Ordered stores for leaderboard ranking (must match keys in LeaderboardManager)
local WinsOrderedStore         = DataStoreService:GetOrderedDataStore("Leaderboard_Wins")
local IQOrderedStore           = DataStoreService:GetOrderedDataStore("Leaderboard_IQ")
local CoinsOrderedStore        = DataStoreService:GetOrderedDataStore("Leaderboard_Coins")
local SoloHighScoreOrderedStore = DataStoreService:GetOrderedDataStore("Leaderboard_SoloHighScore")

local QuestConfig = require(game.ReplicatedStorage:WaitForChild("QuestConfig"))

local function syncStat(store, userId, value)
	pcall(function()
		store:SetAsync(tostring(userId), math.max(0, math.floor(value)))
	end)
end

local PlayerDataManager = {}
PlayerDataManager.PlayerData  = {} -- Cache for active players
PlayerDataManager.OnDataLoaded = Instance.new("BindableEvent") -- Fires when a player's data is ready

-- Debounced save: collapses rapid successive saves into one write
local pendingSaves = {}
function PlayerDataManager:DebouncedSave(player)
	if pendingSaves[player.UserId] then
		task.cancel(pendingSaves[player.UserId])
	end
	pendingSaves[player.UserId] = task.delay(3, function()
		pendingSaves[player.UserId] = nil
		self:SaveData(player)
	end)
end

-- Default quest state (sized to match current QuestConfig.QUESTS length)
local function defaultQuestData()
	local n = #QuestConfig.QUESTS
	local progress, claimed = {}, {}
	for i = 1, n do progress[i] = 0; claimed[i] = false end
	return {
		LastReset = 0,
		Progress  = progress,
		Claimed   = claimed,
	}
end

-- Default player data structure
local function getDefaultData()
	return {
		Wins = 0,
		Losses = 0,
		Coins = 0,
		GamesPlayed = 0,
		HighestSequence = 0,
		IQ = 100,  -- Starting IQ rating (ELO-style)
		Streak = 0,
		LastDailyClaim = 0,
		OwnedThemes = {"Default"},
		EquippedTheme = "Default",
		OwnedTitles = {},
		EquippedTitle = "",  -- empty = use IQ auto-title
		OwnedSounds = {"Default"},
		EquippedSound = "Default",
		DailyQuests = defaultQuestData(),
		HasSeenTutorial = false,
	}
end

-- Reset quests if the 24-hour window has passed
local function resetQuestsIfNeeded(data)
	local q = data.DailyQuests
	if not q then
		data.DailyQuests = defaultQuestData()
		return
	end
	local elapsed = os.time() - (q.LastReset or 0)
	if elapsed >= QuestConfig.RESET_INTERVAL then
		data.DailyQuests = defaultQuestData()
		data.DailyQuests.LastReset = os.time()
	end
end

-- Load player data
function PlayerDataManager:LoadData(player)
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync("Player_" .. player.UserId)
	end)

	if success and data then
		-- Migrate old data
		if not data.IQ then data.IQ = 100 end
		if not data.Streak then data.Streak = 0 end
		if not data.LastDailyClaim then data.LastDailyClaim = 0 end
		if not data.OwnedThemes then data.OwnedThemes = {"Default"} end
		if not data.EquippedTheme then data.EquippedTheme = "Default" end
		if not data.OwnedTitles then data.OwnedTitles = {} end
		if not data.EquippedTitle then data.EquippedTitle = "" end
		if not data.OwnedSounds then data.OwnedSounds = {"Default"} end
		if not data.EquippedSound then data.EquippedSound = "Default" end
		if not data.DailyQuests then data.DailyQuests = defaultQuestData() end
		if data.HasSeenTutorial == nil then data.HasSeenTutorial = false end
		-- Reset quest data if quest count changed (e.g. after a quest config update)
		local n = #QuestConfig.QUESTS
		if not data.DailyQuests.Progress or #data.DailyQuests.Progress ~= n then
			data.DailyQuests = defaultQuestData()
		end

		self.PlayerData[player.UserId] = data
	else
		self.PlayerData[player.UserId] = getDefaultData()
		warn("Could not load data for " .. player.Name .. ", using defaults")
	end

	-- Reset quests if daily window has passed
	resetQuestsIfNeeded(self.PlayerData[player.UserId])

	-- Sync current values to ordered leaderboard stores
	task.spawn(function()
		local d = self.PlayerData[player.UserId]
		syncStat(WinsOrderedStore,  player.UserId, d.Wins)
		syncStat(IQOrderedStore,    player.UserId, d.IQ or 100)
		syncStat(CoinsOrderedStore, player.UserId, d.Coins)
		-- Only sync solo high score if the player actually has one (avoid 0 entries)
		if (d.HighestSequence or 0) > 0 then
			syncStat(SoloHighScoreOrderedStore, player.UserId, d.HighestSequence)
		end
	end)

	-- Create leaderstats
	self:CreateLeaderstats(player)

	-- Signal that this player's data is in cache and ready
	self.OnDataLoaded:Fire(player)
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

	local iq = Instance.new("IntValue")
	iq.Name = "IQ"
	iq.Value = data.IQ or 100
	iq.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = data.Wins
	wins.Parent = leaderstats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = leaderstats

	local streak = Instance.new("IntValue")
	streak.Name = "Streak"
	streak.Value = data.Streak or 0
	streak.Parent = leaderstats

	local equippedTitle = Instance.new("StringValue")
	equippedTitle.Name = "EquippedTitle"
	equippedTitle.Value = data.EquippedTitle or ""
	equippedTitle.Parent = leaderstats
end

-- ── Streak Multiplier ─────────────────────────────────────────────────────────
-- Returns the coin multiplier for the given streak count (after applying this win)
function PlayerDataManager:GetStreakMultiplier(newStreak)
	if newStreak >= 5 then
		return 2.0
	elseif newStreak >= 3 then
		return 1.5
	end
	return 1.0
end

-- ── Update player stats ───────────────────────────────────────────────────────
-- Returns: finalCoins (after multiplier), newStreak, multiplier
function PlayerDataManager:AddWin(player, baseCoins)
	local data = self.PlayerData[player.UserId]
	if not data then return baseCoins, 1, 1.0 end

	data.Wins = data.Wins + 1
	data.GamesPlayed = data.GamesPlayed + 1
	data.Streak = (data.Streak or 0) + 1

	local newStreak   = data.Streak
	local multiplier  = self:GetStreakMultiplier(newStreak)
	local finalCoins  = math.floor(baseCoins * multiplier)

	data.Coins = data.Coins + finalCoins

	-- Update leaderstats
	if player:FindFirstChild("leaderstats") then
		player.leaderstats.Wins.Value = data.Wins
		player.leaderstats.Coins.Value = data.Coins
		if player.leaderstats:FindFirstChild("Streak") then
			player.leaderstats.Streak.Value = newStreak
		end
	end

	task.spawn(function()
		syncStat(WinsOrderedStore,  player.UserId, data.Wins)
		syncStat(CoinsOrderedStore, player.UserId, data.Coins)
	end)

	self:DebouncedSave(player)
	return finalCoins, newStreak, multiplier
end

function PlayerDataManager:AddCoins(player, amount)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	data.Coins = data.Coins + amount

	if player:FindFirstChild("leaderstats") then
		player.leaderstats.Coins.Value = data.Coins
	end

	task.spawn(function()
		syncStat(CoinsOrderedStore, player.UserId, data.Coins)
	end)

	self:DebouncedSave(player)
end

function PlayerDataManager:AddLoss(player, coinsEarned)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	data.Losses = data.Losses + 1
	data.Coins = data.Coins + coinsEarned
	data.GamesPlayed = data.GamesPlayed + 1
	data.Streak = 0

	-- Update leaderstats
	if player:FindFirstChild("leaderstats") then
		player.leaderstats.Coins.Value = data.Coins
		if player.leaderstats:FindFirstChild("Streak") then
			player.leaderstats.Streak.Value = 0
		end
	end

	task.spawn(function()
		syncStat(CoinsOrderedStore, player.UserId, data.Coins)
	end)

	self:DebouncedSave(player)
end

-- Returns true if this is a new personal best
function PlayerDataManager:UpdateHighestSequence(player, sequenceLength)
	local data = self.PlayerData[player.UserId]
	if not data then return false end

	if sequenceLength > (data.HighestSequence or 0) then
		data.HighestSequence = sequenceLength
		task.spawn(function()
			syncStat(SoloHighScoreOrderedStore, player.UserId, sequenceLength)
		end)
		self:DebouncedSave(player)
		return true
	end
	return false
end

-- Calculate IQ change using ELO system
function PlayerDataManager:CalculateIQChange(winnerIQ, loserIQ, didWin)
	local K = 32  -- Maximum IQ change per game

	-- Calculate expected win probability
	local expectedScore = 1 / (1 + 10 ^ ((loserIQ - winnerIQ) / 400))

	-- Actual score: 1 for win, 0 for loss
	local actualScore = didWin and 1 or 0

	-- Calculate IQ change
	local iqChange = math.floor(K * (actualScore - expectedScore))

	return iqChange
end

-- Update IQ for both winner and loser
function PlayerDataManager:UpdateIQ(winner, loser)
	local winnerData = self.PlayerData[winner.UserId]
	local loserData = self.PlayerData[loser.UserId]

	if not winnerData or not loserData then return end

	local winnerIQ = winnerData.IQ or 100
	local loserIQ = loserData.IQ or 100

	-- Calculate IQ changes
	local winnerGain = self:CalculateIQChange(winnerIQ, loserIQ, true)
	local loserLoss = self:CalculateIQChange(loserIQ, winnerIQ, false)

	-- Update IQs (minimum IQ is 1)
	winnerData.IQ = math.max(1, winnerIQ + winnerGain)
	loserData.IQ = math.max(1, loserIQ + loserLoss)

	-- Update leaderstats
	if winner:FindFirstChild("leaderstats") and winner.leaderstats:FindFirstChild("IQ") then
		winner.leaderstats.IQ.Value = winnerData.IQ
	end

	if loser:FindFirstChild("leaderstats") and loser.leaderstats:FindFirstChild("IQ") then
		loser.leaderstats.IQ.Value = loserData.IQ
	end

	print(string.format("IQ Update: %s (%d → %d, %+d) defeated %s (%d → %d, %d)",
		winner.Name, winnerIQ, winnerData.IQ, winnerGain,
		loser.Name, loserIQ, loserData.IQ, loserLoss))

	task.spawn(function()
		syncStat(IQOrderedStore, winner.UserId, winnerData.IQ)
		syncStat(IQOrderedStore, loser.UserId,  loserData.IQ)
	end)

	self:DebouncedSave(winner)
	self:DebouncedSave(loser)
end

-- ── Quest System ──────────────────────────────────────────────────────────────

-- Returns a table with quest status for the client
function PlayerDataManager:GetQuestStatus(player)
	local data = self.PlayerData[player.UserId]
	if not data then return nil end
	resetQuestsIfNeeded(data)

	local timeLeft = math.max(0, QuestConfig.RESET_INTERVAL - (os.time() - (data.DailyQuests.LastReset or 0)))
	return {
		Progress  = data.DailyQuests.Progress,
		Claimed   = data.DailyQuests.Claimed,
		TimeLeft  = timeLeft,
	}
end

-- Update progress for a quest type. questType matches QuestConfig.QUESTS[i].type
-- value = amount to add (for "solo_seq" it sets the max rather than adding)
function PlayerDataManager:UpdateQuestProgress(player, questType, value)
	local data = self.PlayerData[player.UserId]
	if not data then return end
	resetQuestsIfNeeded(data)

	local q = data.DailyQuests
	local changed = false

	for i, quest in ipairs(QuestConfig.QUESTS) do
		if quest.type == questType and not q.Claimed[i] then
			-- solo_seq_* types track the highest value reached (not additive)
			if questType == "solo_seq_8" or questType == "solo_seq_12" then
				if value > q.Progress[i] then
					q.Progress[i] = math.min(value, quest.target)
					changed = true
				end
			else
				-- Additive progress, cap at target
				if q.Progress[i] < quest.target then
					q.Progress[i] = math.min(q.Progress[i] + value, quest.target)
					changed = true
				end
			end
		end
	end

	if changed then
		self:DebouncedSave(player)
		-- Fire quest update to client (QuestManager handles this event connection)
		local remoteEvents = game.ReplicatedStorage:WaitForChild("RemoteEvents")
		local questUpdateEvent = remoteEvents:WaitForChild("QuestUpdate")
		questUpdateEvent:FireClient(player, self:GetQuestStatus(player))
	end
end

-- Claim reward for a completed quest
function PlayerDataManager:ClaimQuest(player, questIndex)
	local data = self.PlayerData[player.UserId]
	if not data then return false, "No data" end
	resetQuestsIfNeeded(data)

	local quest = QuestConfig.QUESTS[questIndex]
	if not quest then return false, "Invalid quest" end

	local q = data.DailyQuests
	if q.Claimed[questIndex] then return false, "Already claimed" end
	if q.Progress[questIndex] < quest.target then return false, "Not complete" end

	q.Claimed[questIndex] = true
	self:AddCoins(player, quest.reward)

	print(string.format("[Quest] %s claimed quest %d (%s): +%d coins", player.Name, questIndex, quest.name, quest.reward))

	local remoteEvents = game.ReplicatedStorage:WaitForChild("RemoteEvents")
	local questUpdateEvent = remoteEvents:WaitForChild("QuestUpdate")
	questUpdateEvent:FireClient(player, self:GetQuestStatus(player))

	self:DebouncedSave(player)
	return true, quest.reward
end

-- ── Shop ──────────────────────────────────────────────────────────────────────

local function isTitleOwned(ownedList, key)
	for _, k in ipairs(ownedList) do
		if k == key then return true end
	end
	return false
end

function PlayerDataManager:BuyTitle(player, titleKey)
	local TitleConfig = require(game.ReplicatedStorage:WaitForChild("TitleConfig"))
	local title = TitleConfig.Titles[titleKey]
	if not title then return false, "Invalid title" end

	local data = self.PlayerData[player.UserId]
	if not data then return false, "No data" end

	if isTitleOwned(data.OwnedTitles, titleKey) then return false, "Already owned" end

	if data.Coins < title.Price then return false, "Not enough coins" end

	self:AddCoins(player, -title.Price)
	table.insert(data.OwnedTitles, titleKey)
	self:DebouncedSave(player)
	return true, "Purchased"
end

function PlayerDataManager:EquipTitle(player, titleKey)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	-- Empty string unequips (reverts to IQ-based title)
	if titleKey ~= "" and not isTitleOwned(data.OwnedTitles, titleKey) then return end

	data.EquippedTitle = titleKey
	if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("EquippedTitle") then
		player.leaderstats.EquippedTitle.Value = titleKey
	end
	self:DebouncedSave(player)
end

local function isSoundOwned(ownedList, key)
	for _, k in ipairs(ownedList) do
		if k == key then return true end
	end
	return false
end

function PlayerDataManager:BuySound(player, soundKey)
	local SoundConfig = require(game.ReplicatedStorage:WaitForChild("SoundConfig"))
	local pack = SoundConfig.Packs[soundKey]
	if not pack then return false, "Invalid sound" end

	local data = self.PlayerData[player.UserId]
	if not data then return false, "No data" end

	if isSoundOwned(data.OwnedSounds, soundKey) then return false, "Already owned" end

	if data.Coins < pack.Price then return false, "Not enough coins" end

	self:AddCoins(player, -pack.Price)
	table.insert(data.OwnedSounds, soundKey)
	self:DebouncedSave(player)
	return true, "Purchased"
end

function PlayerDataManager:EquipSound(player, soundKey)
	local data = self.PlayerData[player.UserId]
	if not data then return end

	if soundKey ~= "Default" and not isSoundOwned(data.OwnedSounds, soundKey) then return end

	data.EquippedSound = soundKey
	self:DebouncedSave(player)
end

-- Initialize
game.Players.PlayerAdded:Connect(function(player)
	PlayerDataManager:LoadData(player)
end)

game.Players.PlayerRemoving:Connect(function(player)
	if pendingSaves[player.UserId] then
		task.cancel(pendingSaves[player.UserId])
		pendingSaves[player.UserId] = nil
	end
	PlayerDataManager:SaveData(player)
	PlayerDataManager.PlayerData[player.UserId] = nil
end)

-- Load data for any players already in game.
-- task.defer ensures all other scripts have connected to OnDataLoaded before we fire it.
task.defer(function()
	for _, player in ipairs(game.Players:GetPlayers()) do
		PlayerDataManager:LoadData(player)
	end
end)

return PlayerDataManager
