-- FavouritePrompt.client.lua
-- Shows the native Roblox favourite dialog when the server fires FavouriteShow.
-- Marks HasSeenFavouritePrompt permanently only if the player clicks Yes.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local AvatarEditorService = game:GetService("AvatarEditorService")

local remoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local favouriteShowEvent = remoteEvents:WaitForChild("FavouriteShow")
local favouriteDoneEvent = remoteEvents:WaitForChild("FavouriteDone")

favouriteShowEvent.OnClientEvent:Connect(function()
	AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
end)

-- If the player clicked Yes on the native dialog, mark permanently so it never shows again
AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(didFavourite)
	if didFavourite then
		favouriteDoneEvent:FireServer()
	end
end)

print("[FavouritePrompt] loaded")
