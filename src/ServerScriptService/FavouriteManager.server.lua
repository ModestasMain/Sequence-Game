-- FavouriteManager.server.lua
-- Fires FavouriteShow to players who haven't dismissed the prompt with "Yes".
-- Marks HasSeenFavouritePrompt when the player clicks Yes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(game.ServerScriptService:WaitForChild("PlayerDataManager"))

local remoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local favouriteShowEvent = remoteEvents:WaitForChild("FavouriteShow")
local favouriteDoneEvent = remoteEvents:WaitForChild("FavouriteDone")

-- After data loads, show prompt if player hasn't clicked Yes before
PlayerDataManager.OnDataLoaded.Event:Connect(function(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if data and not data.HasSeenFavouritePrompt then
		task.wait(1)
		favouriteShowEvent:FireClient(player)
	end
end)

-- Player clicked Yes — mark permanently so it never shows again
favouriteDoneEvent.OnServerEvent:Connect(function(player)
	local data = PlayerDataManager.PlayerData[player.UserId]
	if data then
		data.HasSeenFavouritePrompt = true
		PlayerDataManager:DebouncedSave(player)
		print("[Favourite] Marked as seen for", player.Name)
	end
end)

print("[Favourite] FavouriteManager loaded")
