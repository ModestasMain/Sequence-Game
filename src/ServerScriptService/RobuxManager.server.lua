-- RobuxManager.server.lua
-- Handles all Robux purchases:
--   Developer Products → coin bundles, Reset IQ  (ProcessReceipt)
--   Game Passes        → themes, titles, sounds   (PromptGamePassPurchaseFinished + join check)

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService   = game:GetService("DataStoreService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))
local RobuxConfig       = require(ReplicatedStorage:WaitForChild("RobuxConfig"))

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local themeDataEvent  = remoteEvents:WaitForChild("ThemeData")
local titleDataEvent  = remoteEvents:WaitForChild("TitleData")
local soundDataEvent  = remoteEvents:WaitForChild("SoundData")

-- ── Grant helpers ──────────────────────────────────────────────────────────────

local function grantTheme(player, key)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	for _, k in ipairs(data.OwnedThemes) do
		if k == key then return end  -- already owned
	end
	table.insert(data.OwnedThemes, key)
	themeDataEvent:FireClient(player, data.OwnedThemes, data.EquippedTheme)
	PlayerDataManager:DebouncedSave(player)
	print(string.format("[Robux] %s unlocked theme: %s", player.Name, key))
end

local function grantTitle(player, key)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	for _, k in ipairs(data.OwnedTitles) do
		if k == key then return end
	end
	table.insert(data.OwnedTitles, key)
	titleDataEvent:FireClient(player, data.OwnedTitles, data.EquippedTitle)
	PlayerDataManager:DebouncedSave(player)
	print(string.format("[Robux] %s unlocked title: %s", player.Name, key))
end

local function grantSound(player, key)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	for _, k in ipairs(data.OwnedSounds) do
		if k == key then return end
	end
	table.insert(data.OwnedSounds, key)
	soundDataEvent:FireClient(player, data.OwnedSounds, data.EquippedSound)
	PlayerDataManager:DebouncedSave(player)
	print(string.format("[Robux] %s unlocked sound: %s", player.Name, key))
end

-- ── Developer Products (ProcessReceipt) ───────────────────────────────────────
-- ProcessReceipt MUST return PurchaseGranted or NotProcessedYet — never error out

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	-- Coin bundles
	for _, bundle in ipairs(RobuxConfig.CoinBundles) do
		if bundle.ProductId == productId and productId ~= 0 then
			PlayerDataManager:AddCoins(player, bundle.Amount)
			print(string.format("[Robux] %s purchased %s (+%d coins)", player.Name, bundle.Name, bundle.Amount))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- Reset IQ
	if RobuxConfig.ResetIQ.ProductId == productId and productId ~= 0 then
		data.IQ = 100
		if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("IQ") then
			player.leaderstats.IQ.Value = 100
		end
		-- Sync leaderboard ordered store
		local IQOrderedStore = DataStoreService:GetOrderedDataStore("Leaderboard_IQ")
		pcall(function() IQOrderedStore:SetAsync(tostring(player.UserId), 100) end)
		PlayerDataManager:DebouncedSave(player)
		print(string.format("[Robux] %s reset IQ to 100", player.Name))
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Unknown product — don't block future retries
	warn(string.format("[Robux] Unknown ProductId %d for %s", productId, player.Name))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ── Game Passes (on purchase) ──────────────────────────────────────────────────

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end

	for key, info in pairs(RobuxConfig.ThemePasses) do
		if info.PassId == gamePassId and gamePassId ~= 0 then
			grantTheme(player, key)
			return
		end
	end

	for key, info in pairs(RobuxConfig.TitlePasses) do
		if info.PassId == gamePassId and gamePassId ~= 0 then
			grantTitle(player, key)
			return
		end
	end

	for key, info in pairs(RobuxConfig.SoundPasses) do
		if info.PassId == gamePassId and gamePassId ~= 0 then
			grantSound(player, key)
			return
		end
	end
end)

-- ── On join: grant any passes the player already owns ─────────────────────────

local function checkPassesOnJoin(player)
	-- PlayerDataManager.OnDataLoaded already guarantees data is in cache
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end

	for key, info in pairs(RobuxConfig.ThemePasses) do
		if info.PassId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, info.PassId)
			if ok and owns then grantTheme(player, key) end
		end
	end

	for key, info in pairs(RobuxConfig.TitlePasses) do
		if info.PassId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, info.PassId)
			if ok and owns then grantTitle(player, key) end
		end
	end

	for key, info in pairs(RobuxConfig.SoundPasses) do
		if info.PassId ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, info.PassId)
			if ok and owns then grantSound(player, key) end
		end
	end
end

-- Run pass checks only after data is confirmed loaded
PlayerDataManager.OnDataLoaded.Event:Connect(function(player)
	task.spawn(checkPassesOnJoin, player)
end)

-- Handle any players already in-game when this script loads
for _, player in ipairs(game.Players:GetPlayers()) do
	if PlayerDataManager.PlayerData[player.UserId] then
		task.spawn(checkPassesOnJoin, player)
	end
end

print("[Robux] RobuxManager loaded")
