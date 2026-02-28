-- BattlePassManager.lua (ModuleScript — required by GameManager, QuestManager etc.)
-- Manages Battle Pass XP, tier claiming, and premium access.
--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(script.Parent:WaitForChild("PlayerDataManager"))
local BattlePassConfig  = require(ReplicatedStorage:WaitForChild("BattlePassConfig"))
local RobuxConfig       = require(ReplicatedStorage:WaitForChild("RobuxConfig"))

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local bpDataEvent     = remoteEvents:WaitForChild("BattlePassData")
local claimTierEvent  = remoteEvents:WaitForChild("ClaimBattlePassTier")
local buyPremiumEvent = remoteEvents:WaitForChild("BuyBattlePassPremium")

-- BindableEvent so RobuxManager can notify us when the BP product is purchased
local bpGranted = Instance.new("BindableEvent")
bpGranted.Name   = "BattlePassGranted"
bpGranted.Parent = script.Parent

-- ── Helpers ────────────────────────────────────────────────────────────────

local function isPremiumValid(data: {}): boolean
	return data.BattlePassPremium == true
		and data.BattlePassSeason  == BattlePassConfig.SEASON
end

local function sendBPState(player: Player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	bpDataEvent:FireClient(player, {
		xp             = data.BattlePassXP,
		tier           = BattlePassConfig.GetTier(data.BattlePassXP),
		maxTiers       = BattlePassConfig.MAX_TIERS,
		xpPerTier      = BattlePassConfig.XP_PER_TIER,
		freeClaimed    = data.BattlePassFreeClaimed,
		premiumClaimed = data.BattlePassPremiumClaimed,
		premium        = isPremiumValid(data),
		season         = BattlePassConfig.SEASON,
		productId      = RobuxConfig.BattlePassProduct.ProductId,
		robux          = BattlePassConfig.PREMIUM_ROBUX,
		tiers          = BattlePassConfig.TIERS,
	})
end

-- ── Grant premium ──────────────────────────────────────────────────────────

local function grantPremium(player: Player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	if isPremiumValid(data) then return end

	data.BattlePassPremium = true
	data.BattlePassSeason  = BattlePassConfig.SEASON
	PlayerDataManager:DebouncedSave(player)
	sendBPState(player)
	print(string.format("[BattlePass] %s granted premium (Season %d)", player.Name, BattlePassConfig.SEASON))
end

-- ── Add XP ─────────────────────────────────────────────────────────────────

local function addXP(player: Player, source: string)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	local amount = BattlePassConfig.XP[source]
	if not amount then return end

	local oldTier = BattlePassConfig.GetTier(data.BattlePassXP)
	data.BattlePassXP += amount
	local newTier = BattlePassConfig.GetTier(data.BattlePassXP)

	PlayerDataManager:DebouncedSave(player)
	sendBPState(player)

	if newTier > oldTier then
		print(string.format("[BattlePass] %s reached Tier %d", player.Name, newTier))
	end
end

-- ── Claim tier reward ──────────────────────────────────────────────────────

local function claimTier(player: Player, tierNum: number, track: string)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	if tierNum < 1 or tierNum > BattlePassConfig.MAX_TIERS then return end
	if BattlePassConfig.GetTier(data.BattlePassXP) < tierNum then return end

	local tierConfig = BattlePassConfig.TIERS[tierNum]
	if not tierConfig then return end

	if track == "free" then
		if data.BattlePassFreeClaimed[tierNum] then return end
		data.BattlePassFreeClaimed[tierNum] = true
		local reward = tierConfig.free
		if reward.coins then PlayerDataManager:AddCoins(player, reward.coins) end

	elseif track == "premium" then
		if not isPremiumValid(data) then return end
		if data.BattlePassPremiumClaimed[tierNum] then return end
		data.BattlePassPremiumClaimed[tierNum] = true
		local reward = tierConfig.premium
		if reward.coins then PlayerDataManager:AddCoins(player, reward.coins) end
		if reward.title then
			local owned = false
			for _, k in ipairs(data.OwnedTitles) do
				if k == reward.title then owned = true; break end
			end
			if not owned then table.insert(data.OwnedTitles, reward.title) end
		end
	else
		return
	end

	PlayerDataManager:DebouncedSave(player)
	sendBPState(player)
	print(string.format("[BattlePass] %s claimed Tier %d (%s)", player.Name, tierNum, track))
end

-- ── Wire events (runs at require-time) ────────────────────────────────────

claimTierEvent.OnServerEvent:Connect(function(player, tierNum, track)
	if type(tierNum) ~= "number" then return end
	if type(track)   ~= "string" then return end
	claimTier(player, tierNum, track)
end)

buyPremiumEvent.OnServerEvent:Connect(function(player)
	local productId = RobuxConfig.BattlePassProduct.ProductId
	if productId == 0 then return end
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data or isPremiumValid(data) then return end
	MarketplaceService:PromptProductPurchase(player, productId)
end)

bpGranted.Event:Connect(grantPremium)

PlayerDataManager.OnDataLoaded.Event:Connect(function(player)
	task.wait(0.5)
	sendBPState(player)
end)

-- ── Public API ─────────────────────────────────────────────────────────────

local BattlePassManager = {}

function BattlePassManager.AddXP(player: Player, source: string)
	addXP(player, source)
end

return BattlePassManager
