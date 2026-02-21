-- TutorialManager.server.lua
-- Fires TutorialShow to first-time players, marks tutorial seen on completion.

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local PlayerDataManager  = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

local remoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local tutorialShowEvent  = remoteEvents:WaitForChild("TutorialShow")
local tutorialDoneEvent  = remoteEvents:WaitForChild("TutorialDone")

-- After data loads, send tutorial if player hasn't seen it
-- TESTING: always show tutorial regardless of flag
PlayerDataManager.OnDataLoaded.Event:Connect(function(player)
	task.wait(1) -- let the client finish loading its UI
	tutorialShowEvent:FireClient(player)
end)

-- Mark tutorial as seen when the player dismisses it
tutorialDoneEvent.OnServerEvent:Connect(function(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if data then
		data.HasSeenTutorial = true
		PlayerDataManager:DebouncedSave(player)
		print("[Tutorial] Marked as seen for", player.Name)
	end
end)

print("[Tutorial] TutorialManager loaded")
