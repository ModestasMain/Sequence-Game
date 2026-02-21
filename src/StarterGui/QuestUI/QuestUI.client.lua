-- QuestUI.client.lua
-- Populates and updates the daily quest panel inside ButtonsUI.Frames.Skins.
-- Open/close animation is handled by the existing Tween LocalScript on the Skins button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local player = Players.LocalPlayer

local remoteEvents          = ReplicatedStorage:WaitForChild("RemoteEvents")
local questUpdateEvent      = remoteEvents:WaitForChild("QuestUpdate")
local claimQuestEvent       = remoteEvents:WaitForChild("ClaimQuest")
local requestQuestDataEvent = remoteEvents:WaitForChild("RequestQuestData")

local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))

-- Wait for ButtonsUI to be cloned into PlayerGui
local playerGui  = player:WaitForChild("PlayerGui")
local buttonsUI  = playerGui:WaitForChild("ButtonsUI")
local skinsFrame = buttonsUI:WaitForChild("Frames"):WaitForChild("Skins")
local timerLabel = skinsFrame:WaitForChild("TimerLabel")
local questScroll = skinsFrame:WaitForChild("QuestScroll")

-- Gather quest row references (cards live inside QuestScroll)
local questRows = {}
for i = 1, #QuestConfig.QUESTS do
	local row = questScroll:WaitForChild("Quest" .. i)
	questRows[i] = {
		nameLabel     = row:WaitForChild("QuestName"),
		progressLabel = row:WaitForChild("ProgressLabel"),
		claimBtn      = row:WaitForChild("ClaimBtn"),
		coinIcon      = row:WaitForChild("ClaimBtn"):WaitForChild("CoinIcon"),
		row           = row,
	}
	-- Wire up claim button
	local idx = i
	row.ClaimBtn.MouseButton1Click:Connect(function()
		claimQuestEvent:FireServer(idx)
	end)
end

-- ── Timer countdown ───────────────────────────────────────────────────────────
local timeLeft   = nil  -- nil = no data yet
local dataLoaded = false

local function formatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", h, m, s)
end

task.spawn(function()
	while true do
		task.wait(1)
		if dataLoaded and timeLeft then
			if timeLeft > 0 then timeLeft -= 1 end
			timerLabel.Text = "Resets in: " .. formatTime(timeLeft)
		end
	end
end)

-- ── Update quest rows from server status ──────────────────────────────────────
local function updateQuestUI(status)
	if not status then return end

	dataLoaded = true
	timeLeft   = status.TimeLeft or 0
	timerLabel.Text = "Resets in: " .. formatTime(timeLeft)

	for i, quest in ipairs(QuestConfig.QUESTS) do
		local r       = questRows[i]
		local prog    = status.Progress[i] or 0
		local claimed = status.Claimed[i]  or false
		local done    = prog >= quest.target

		r.nameLabel.Text     = quest.name
		r.progressLabel.Text = quest.desc .. "  (" .. math.min(prog, quest.target) .. "/" .. quest.target .. ")"

		if claimed then
			r.claimBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
			r.claimBtn.Text             = "✓ Done"
			r.claimBtn.TextColor3       = Color3.fromRGB(90, 90, 110)
			r.coinIcon.Visible          = false
			r.row.BackgroundColor3      = Color3.fromRGB(32, 38, 32)
		elseif done then
			r.claimBtn.BackgroundColor3 = Color3.fromRGB(50, 160, 80)
			r.claimBtn.Text             = "+" .. quest.reward
			r.claimBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
			r.coinIcon.Visible          = true
			r.row.BackgroundColor3      = Color3.fromRGB(32, 42, 32)
		else
			r.claimBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 75)
			r.claimBtn.Text             = "+" .. quest.reward
			r.claimBtn.TextColor3       = Color3.fromRGB(180, 180, 210)
			r.coinIcon.Visible          = true
			r.row.BackgroundColor3      = Color3.fromRGB(38, 38, 44)
		end
	end
end

-- Listen for server pushes (e.g. after claiming a quest)
questUpdateEvent.OnClientEvent:Connect(updateQuestUI)

-- Request data immediately — this guarantees the timer shows correctly on join
requestQuestDataEvent:FireServer()

print("[QuestUI] Loaded for " .. player.Name)
