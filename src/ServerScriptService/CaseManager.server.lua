-- CaseManager.server.lua
-- Handles case opening: coins path and Robux path.
-- Awards win effects via weighted random; duplicates give +10 IQ and +50 coins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local Players           = game:GetService("Players")

local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))
local WinEffectConfig   = require(ReplicatedStorage:WaitForChild("WinEffectConfig"))

local remoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local openCaseEvent      = remoteEvents:WaitForChild("OpenCase")
local caseResultEvent    = remoteEvents:WaitForChild("CaseResult")
local winEffectDataEvent = remoteEvents:WaitForChild("WinEffectData")

-- BindableEvent so RobuxManager can trigger a Robux-paid case open
local caseGranted = Instance.new("BindableEvent")
caseGranted.Name   = "CaseGranted"
caseGranted.Parent = game.ServerScriptService

local CASE_COIN_COST   = 300
local DUPLICATE_IQ     = 10
local DUPLICATE_COINS  = 50
local WIN_SLOT         = 33   -- which tile (1-indexed) the winner lands on
local TOTAL_TILES      = 40

-- Build weighted pool from effects that have a Weight field (excludes Default)
local SPIN_EFFECTS   = {}
local TOTAL_WEIGHT   = 0
for _, key in ipairs(WinEffectConfig.Order) do
	local e = WinEffectConfig.Effects[key]
	if e.Weight then
		table.insert(SPIN_EFFECTS, { key = key, weight = e.Weight })
		TOTAL_WEIGHT = TOTAL_WEIGHT + e.Weight
	end
end

local function pickRandomEffect()
	local roll = math.random(1, TOTAL_WEIGHT)
	local cumulative = 0
	for _, entry in ipairs(SPIN_EFFECTS) do
		cumulative = cumulative + entry.weight
		if roll <= cumulative then return entry.key end
	end
	return SPIN_EFFECTS[1].key
end

local function isOwned(data, key)
	for _, k in ipairs(data.OwnedWinEffects) do
		if k == key then return true end
	end
	return false
end

-- Debounce: per-player, cleared after animation finishes (7 s)
local debounce = {}

local function openCase(player, isPaid)
	if debounce[player.UserId] then return end
	debounce[player.UserId] = true

	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then debounce[player.UserId] = nil; return end

	-- Deduct coins for the coins path
	if not isPaid then
		if data.Coins < CASE_COIN_COST then
			caseResultEvent:FireClient(player, nil, nil, false, 0, 0, "NotEnoughCoins")
			debounce[player.UserId] = nil
			return
		end
		data.Coins = data.Coins - CASE_COIN_COST
		if player:FindFirstChild("leaderstats") then
			player.leaderstats.Coins.Value = data.Coins
		end
	end

	-- Pick the winning effect and build the 40-tile spin sequence
	local winEffect = pickRandomEffect()
	local spinSequence = {}
	for i = 1, TOTAL_TILES do
		if i == WIN_SLOT then
			spinSequence[i] = winEffect
		else
			spinSequence[i] = SPIN_EFFECTS[math.random(1, #SPIN_EFFECTS)].key
		end
	end

	-- Determine reward
	local isDuplicate = isOwned(data, winEffect)
	if isDuplicate then
		data.IQ = data.IQ + DUPLICATE_IQ
		if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("IQ") then
			player.leaderstats.IQ.Value = data.IQ
		end
		local iqStore = DataStoreService:GetOrderedDataStore("Leaderboard_IQ")
		pcall(function() iqStore:SetAsync(tostring(player.UserId), data.IQ) end)
		PlayerDataManager:AddCoins(player, DUPLICATE_COINS)
	else
		table.insert(data.OwnedWinEffects, winEffect)
		data.EquippedWinEffect = winEffect
		winEffectDataEvent:FireClient(player, data.OwnedWinEffects, data.EquippedWinEffect)
	end

	task.spawn(function() PlayerDataManager:SaveData(player) end)

	-- Send spin sequence and result to client
	caseResultEvent:FireClient(player, spinSequence, winEffect, isDuplicate, DUPLICATE_IQ, DUPLICATE_COINS)
	print(string.format("[Case] %s opened a case → %s (duplicate: %s)", player.Name, winEffect, tostring(isDuplicate)))

	-- Release debounce after animation completes
	task.delay(8, function()
		debounce[player.UserId] = nil
	end)
end

openCaseEvent.OnServerEvent:Connect(function(player)
	openCase(player, false)
end)

caseGranted.Event:Connect(function(player)
	openCase(player, true)
end)

Players.PlayerRemoving:Connect(function(player)
	debounce[player.UserId] = nil
end)

print("[Case] CaseManager loaded")
