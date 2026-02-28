-- StreakAnnouncer.lua
-- Announces win streaks to all players in the server.
-- Guards: threshold filter → per-player cooldown → cross-server gate.
--!strict

local MessagingService  = game:GetService("MessagingService")
local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local streakEvent  = remoteEvents:WaitForChild("StreakAnnounce")

local SERVER_ID = game.JobId

local TOPIC = "WinStreak_v1"

-- Only streaks >= 5 are worth announcing locally
local THRESHOLDS = {5, 10, 15, 20}
local THRESHOLD_SET: {[number]: boolean} = {}
for _, v in ipairs(THRESHOLDS) do THRESHOLD_SET[v] = true end

-- Cross-server only for truly impressive streaks
local CROSS_SERVER_MIN = 10

-- A player can only trigger one announcement every 2 minutes
local PLAYER_COOLDOWN = 120
local lastAnnounced: {[number]: number} = {}

Players.PlayerRemoving:Connect(function(player)
	lastAnnounced[player.UserId] = nil
end)

local MESSAGES: {[number]: string} = {
	[5]  = "is on fire! 5-win streak!",
	[10] = "is UNSTOPPABLE! 10-win streak!",
	[15] = "is a MONSTER! 15-win streak!",
	[20] = "is LEGENDARY! 20-win streak!",
}

local StreakAnnouncer = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function fireLocally(playerName: string, streak: number)
	local msg = MESSAGES[streak]
	if not msg then return end
	for _, player in ipairs(Players:GetPlayers()) do
		streakEvent:FireClient(player, playerName, streak, msg)
	end
end

-- ── Subscribe at require-time ──────────────────────────────────────────────

local subOk, subErr = pcall(function()
	MessagingService:SubscribeAsync(TOPIC, function(message)
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(message.Data)
		end)
		if not ok then return end
		if decoded.fromServerId == SERVER_ID then return end
		fireLocally(decoded.playerName, decoded.streak)
	end)
end)
if not subOk then
	warn("[StreakAnnouncer] SubscribeAsync failed:", subErr)
end

-- ── Public API ─────────────────────────────────────────────────────────────

function StreakAnnouncer.CheckAndAnnounce(player: Player, streak: number)
	-- 1. Threshold filter
	if not THRESHOLD_SET[streak] then return end

	-- 2. Per-player cooldown
	local now = tick()
	local last = lastAnnounced[player.UserId] or 0
	if now - last < PLAYER_COOLDOWN then return end
	lastAnnounced[player.UserId] = now

	-- 3. Fire locally (always)
	fireLocally(player.Name, streak)

	-- 4. Cross-server gate
	if streak < CROSS_SERVER_MIN then return end
	local payload = HttpService:JSONEncode({
		fromServerId = SERVER_ID,
		playerName   = player.Name,
		streak       = streak,
	})
	pcall(function()
		MessagingService:PublishAsync(TOPIC, payload)
	end)
end

return StreakAnnouncer
