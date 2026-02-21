-- QuestManager.server.lua
-- Handles quest status requests and claim events from clients

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

local remoteEvents            = ReplicatedStorage:WaitForChild("RemoteEvents")
local questUpdateEvent        = remoteEvents:WaitForChild("QuestUpdate")
local claimQuestEvent         = remoteEvents:WaitForChild("ClaimQuest")
local requestQuestDataEvent   = remoteEvents:WaitForChild("RequestQuestData")

local function sendQuestStatus(player)
	local status = PlayerDataManager:GetQuestStatus(player)
	if status then
		questUpdateEvent:FireClient(player, status)
	end
end

-- Push quest status once data is loaded (fallback if client connects early)
PlayerDataManager.OnDataLoaded.Event:Connect(function(player)
	task.wait(0.5)
	sendQuestStatus(player)
end)

-- Client requests data on demand (fixes timer showing --:--:-- on join)
requestQuestDataEvent.OnServerEvent:Connect(function(player)
	sendQuestStatus(player)
end)

-- Handle quest claim requests from the client
claimQuestEvent.OnServerEvent:Connect(function(player, questIndex)
	if type(questIndex) ~= "number" then return end
	PlayerDataManager:ClaimQuest(player, questIndex)
end)

print("[Quest] QuestManager loaded")
