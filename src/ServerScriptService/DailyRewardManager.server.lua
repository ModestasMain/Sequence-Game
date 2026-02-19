-- DailyRewardManager.server.lua
-- Handles daily reward claiming with 24-hour cooldown

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

local DAILY_COINS = 20
local COOLDOWN_SECONDS = 86400 -- 24 hours

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local claimDailyEvent = remoteEvents:WaitForChild("ClaimDaily")
local dailyStatusEvent = remoteEvents:WaitForChild("DailyStatus")

local function getTimeRemaining(lastClaim)
	local now = os.time()
	local elapsed = now - lastClaim
	local remaining = COOLDOWN_SECONDS - elapsed
	return math.max(0, remaining)
end

local function sendStatus(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end
	local timeRemaining = getTimeRemaining(data.LastDailyClaim or 0)
	dailyStatusEvent:FireClient(player, timeRemaining)
end

-- Send status when player joins (data may not be loaded yet, wait a moment)
game.Players.PlayerAdded:Connect(function(player)
	task.wait(2) -- wait for PlayerDataManager:LoadData to finish
	sendStatus(player)
end)

-- Handle claim request
claimDailyEvent.OnServerEvent:Connect(function(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if not data then return end

	local timeRemaining = getTimeRemaining(data.LastDailyClaim or 0)
	if timeRemaining > 0 then
		-- Still on cooldown, just resend status (client shouldn't have allowed this)
		dailyStatusEvent:FireClient(player, timeRemaining)
		return
	end

	-- Grant reward
	data.LastDailyClaim = os.time()
	PlayerDataManager:AddCoins(player, DAILY_COINS)
	print("[Daily] " .. player.Name .. " claimed daily reward: " .. DAILY_COINS .. " coins")

	-- Tell client the new cooldown
	dailyStatusEvent:FireClient(player, COOLDOWN_SECONDS)
end)

print("[Daily] DailyRewardManager loaded")
