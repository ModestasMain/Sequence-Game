-- LobbyMusic.client.lua
-- Plays lobby music, fades out when a game starts, fades back in when it ends.

local TweenService     = game:GetService("TweenService")
local SoundService     = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
local showGameUI    = remoteEvents:WaitForChild("ShowGameUI")
local gameResult    = remoteEvents:WaitForChild("GameResult")

local music = SoundService:WaitForChild("LobbyMusic")
local LOBBY_VOLUME = 0.4
local FADE_TIME    = 1.5

local function fadeTo(targetVolume)
	TweenService:Create(music, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {
		Volume = targetVolume
	}):Play()
end

-- Start playing immediately
music:Play()

-- Fade out when a game begins
showGameUI.OnClientEvent:Connect(function()
	fadeTo(0)
end)

-- Fade back in when the game ends (result screen shown)
gameResult.OnClientEvent:Connect(function()
	fadeTo(LOBBY_VOLUME)
end)
