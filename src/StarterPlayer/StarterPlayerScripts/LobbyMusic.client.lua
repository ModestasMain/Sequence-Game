-- LobbyMusic.client.lua
-- Plays lobby music, fades out when a game starts, fades back in when it ends.
-- Exposes a BindableEvent "MusicToggled" in PlayerGui for the Settings toggle.

local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local showGameUI   = remoteEvents:WaitForChild("ShowGameUI")
local gameResult   = remoteEvents:WaitForChild("GameResult")

local music        = SoundService:WaitForChild("LobbyMusic")
local LOBBY_VOLUME = 0.4
local FADE_TIME    = 1.5
local musicEnabled = true

local function fadeTo(targetVolume)
	TweenService:Create(music, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {
		Volume = targetVolume
	}):Play()
end

-- BindableEvent so the Settings UI can toggle music from a separate LocalScript
local toggleEvent = Instance.new("BindableEvent")
toggleEvent.Name  = "MusicToggled"
toggleEvent.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

toggleEvent.Event:Connect(function(enabled)
	musicEnabled = enabled
	if enabled then
		fadeTo(LOBBY_VOLUME)
	else
		fadeTo(0)
	end
end)

-- Start playing immediately
music:Play()

-- Fade out when a game begins
showGameUI.OnClientEvent:Connect(function()
	fadeTo(0)
end)

-- Fade back in when the game ends (only if music is still enabled)
gameResult.OnClientEvent:Connect(function()
	if musicEnabled then
		fadeTo(LOBBY_VOLUME)
	end
end)
