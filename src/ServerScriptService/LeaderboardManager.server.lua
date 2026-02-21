-- LeaderboardManager.server.lua
-- Populates the four in-world leaderboards (Wins, IQ, Coins, Solo) with top player data

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local TOP_COUNT = 10
local UPDATE_INTERVAL = 60 -- seconds between refreshes

-- OrderedDataStores (must match keys used in PlayerDataManager)
local WinsStore          = DataStoreService:GetOrderedDataStore("Leaderboard_Wins")
local IQStore            = DataStoreService:GetOrderedDataStore("Leaderboard_IQ")
local CoinsStore         = DataStoreService:GetOrderedDataStore("Leaderboard_Coins")
local SoloHighScoreStore = DataStoreService:GetOrderedDataStore("Leaderboard_SoloHighScore")

-- Wait for scene to load
local leaderboardsFolder = game.Workspace:WaitForChild("Lobby"):WaitForChild("Leaderboards")

local CONFIGS = {
	{
		part  = leaderboardsFolder:WaitForChild("Wins Leaderboard"),
		store = WinsStore,
		title = "TOP WINS",
	},
	{
		part  = leaderboardsFolder:WaitForChild("IQ Leaderboard"),
		store = IQStore,
		title = "TOP IQ",
	},
	{
		part  = leaderboardsFolder:WaitForChild("Coins Leaderboard"),
		store = CoinsStore,
		title = "TOP COINS",
	},
	{
		part  = leaderboardsFolder:WaitForChild("Solo Leaderboard"),
		store = SoloHighScoreStore,
		title = "TOP SOLO SCORE",
	},
}

local function updateBoard(config)
	local part     = config.part
	local store    = config.store
	local titleStr = config.title

	local gui      = part:FindFirstChild("SurfaceGui")
	local template = part:FindFirstChild("Template")
	if not gui or not template then
		warn("LeaderboardManager: missing SurfaceGui or Template on " .. part.Name)
		return
	end

	local mainFrame = gui:FindFirstChild("MainFrame")
	if not mainFrame then return end

	-- Set the board title
	local titleLabel = mainFrame:FindFirstChild("Title")
	if titleLabel then
		titleLabel.Text = titleStr
	end

	local playersFrame = mainFrame:FindFirstChild("Players")
	if not playersFrame then return end

	local scroll = playersFrame:FindFirstChild("Scroll")
	if not scroll then return end

	-- Remove previous rows
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Fetch top entries (descending)
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok then
		warn("LeaderboardManager: GetSortedAsync failed for " .. titleStr .. " - " .. tostring(pages))
		return
	end

	local entries = pages:GetCurrentPage()

	for rank, entry in ipairs(entries) do
		local userId = tonumber(entry.key)
		local value  = entry.value

		-- Resolve display name (may yield)
		local playerName = "Unknown"
		local nameOk, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if nameOk then playerName = name end

		-- Resolve headshot thumbnail
		local thumb = ""
		local thumbOk, url = pcall(
			Players.GetUserThumbnailAsync, Players,
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
		if thumbOk then thumb = url end

		-- Clone template row
		local row = template:Clone()
		row.Name        = "Row_" .. rank
		row.LayoutOrder = rank
		row.Visible     = true
		row.Parent      = scroll

		local rankLabel = row:FindFirstChild("Rank")
		if rankLabel then rankLabel.Text = "#" .. rank end

		local nameLabel = row:FindFirstChild("PlrName")
		if nameLabel then nameLabel.Text = playerName end

		local amountLabel = row:FindFirstChild("Amount")
		if amountLabel then amountLabel.Text = tostring(value) end

		local icon = row:FindFirstChild("PlayerIcon")
		if icon then icon.Image = thumb end
	end
end

local function refreshAll()
	for _, cfg in ipairs(CONFIGS) do
		local ok, err = pcall(updateBoard, cfg)
		if not ok then
			warn("LeaderboardManager: updateBoard error - " .. tostring(err))
		end
		task.wait(2) -- space requests to avoid rate limits
	end
end

-- Refresh loop
task.spawn(function()
	task.wait(5) -- give PlayerDataManager time to load players first
	while true do
		refreshAll()
		task.wait(UPDATE_INTERVAL)
	end
end)
