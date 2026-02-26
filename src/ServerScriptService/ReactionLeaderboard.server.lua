-- ReactionLeaderboard.server.lua
-- Stores each player's personal best reaction time in an OrderedDataStore.
-- Broadcasts top 10 to all clients whenever a new best is set.

local DataStoreService  = game:GetService("DataStoreService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local scoreEvent         = remoteEvents:WaitForChild("ReactionScore")
local leaderboardEvent   = remoteEvents:WaitForChild("ReactionLeaderboard")

local reactionStore = DataStoreService:GetOrderedDataStore("ReactionTimes_v1")

local BOARD_SIZE       = 10
local BROADCAST_COOLDOWN = 5  -- seconds minimum between full broadcasts

local lastBroadcast = 0

-- ─── Read top 10 ──────────────────────────────────────────────────────────
local function getTop10()
	local ok, result = pcall(function()
		local pages = reactionStore:GetSortedAsync(true, BOARD_SIZE) -- ascending = fastest first
		return pages:GetCurrentPage()
	end)
	if not ok then
		warn("[ReactionLB] GetSortedAsync failed:", result)
		return {}
	end

	local entries = {}
	for rank, entry in ipairs(result) do
		local userId = tonumber(entry.key)
		local ms     = entry.value
		local name   = "Unknown"
		local nameOk, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if nameOk then name = n end
		table.insert(entries, { rank = rank, name = name, ms = ms })
	end
	return entries
end

-- ─── Broadcast to all clients ─────────────────────────────────────────────
local function broadcast()
	local now = tick()
	if now - lastBroadcast < BROADCAST_COOLDOWN then return end
	lastBroadcast = now

	local data = getTop10()
	for _, player in ipairs(Players:GetPlayers()) do
		leaderboardEvent:FireClient(player, data)
	end
end

-- ─── Send leaderboard to a single newly joined player ─────────────────────
Players.PlayerAdded:Connect(function(player)
	task.wait(4) -- wait for the client to fully load
	local data = getTop10()
	leaderboardEvent:FireClient(player, data)
end)

-- ─── Handle score submission from client ──────────────────────────────────
scoreEvent.OnServerEvent:Connect(function(player, ms)
	-- Validate
	if type(ms) ~= "number" then return end
	ms = math.round(ms)
	if ms < 50 or ms > 5000 then return end -- sanity bounds

	local userId = tostring(player.UserId)

	-- Only save if it's a personal best
	local currentBest
	local getOk, val = pcall(reactionStore.GetAsync, reactionStore, userId)
	if getOk then currentBest = val end

	if currentBest == nil or ms < currentBest then
		local saveOk, err = pcall(reactionStore.SetAsync, reactionStore, userId, ms)
		if saveOk then
			print(string.format("[ReactionLB] %s — new best: %d ms", player.Name, ms))
			broadcast()
		else
			warn("[ReactionLB] SetAsync failed:", err)
		end
	end
end)

print("[ReactionLB] loaded")
