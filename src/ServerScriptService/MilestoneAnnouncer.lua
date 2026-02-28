-- MilestoneAnnouncer.lua
-- Broadcasts IQ milestones cross-server via MessagingService.
-- Require this module from PlayerDataManager (server-side only).
--!strict

local MessagingService = game:GetService("MessagingService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local announceEvent   = remoteEvents:WaitForChild("IQMilestoneAnnounce")

local SERVER_ID = game.JobId  -- unique per server; empty string in Studio (safe)

local TOPIC = "IQMilestone_v1"

-- Sorted ascending — we announce the highest milestone crossed in one IQ jump
local MILESTONES = {150, 200, 250, 300, 400, 500, 750, 1000}

local MilestoneAnnouncer = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function fireLocally(playerName: string, iq: number)
	for _, player in ipairs(Players:GetPlayers()) do
		announceEvent:FireClient(player, playerName, iq)
	end
end

-- ── Subscribe at require-time (runs once when first required) ─────────────

local subOk, subErr = pcall(function()
	MessagingService:SubscribeAsync(TOPIC, function(message)
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(message.Data)
		end)
		if not ok then return end
		-- Skip our own publishes — we already showed them locally
		if decoded.fromServerId == SERVER_ID then return end
		fireLocally(decoded.playerName, decoded.iq)
	end)
end)
if not subOk then
	warn("[MilestoneAnnouncer] SubscribeAsync failed:", subErr)
end

-- ── Public API ─────────────────────────────────────────────────────────────

-- Call after updating a player's IQ.
-- oldIQ / newIQ are the values before and after the change.
function MilestoneAnnouncer.CheckAndAnnounce(player: Player, oldIQ: number, newIQ: number)
	-- Find the highest milestone crossed in this single IQ change
	local crossed: number? = nil
	for _, milestone in ipairs(MILESTONES) do
		if oldIQ < milestone and newIQ >= milestone then
			crossed = milestone
		end
	end
	if not crossed then return end

	-- Show in this server immediately (no round-trip delay)
	fireLocally(player.Name, crossed)

	-- Publish to every other server
	local payload = HttpService:JSONEncode({
		fromServerId = SERVER_ID,
		playerName   = player.Name,
		iq           = crossed,
	})
	local pubOk, pubErr = pcall(function()
		MessagingService:PublishAsync(TOPIC, payload)
	end)
	if not pubOk then
		warn("[MilestoneAnnouncer] PublishAsync failed:", pubErr)
	end
end

return MilestoneAnnouncer
