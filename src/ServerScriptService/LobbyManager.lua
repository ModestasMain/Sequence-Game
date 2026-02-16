-- LobbyManager.lua
-- Manages lobby platforms - JoinScreen system handles matchmaking via ProximityPrompt

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local LobbyManager = {}
LobbyManager.ActivePlatforms = {}

-- Platform class (minimal - used for GameManager compatibility)
local Platform = {}
Platform.__index = Platform

function Platform.new(platformModel)
	local self = setmetatable({}, Platform)
	self.Model = platformModel
	self.LeftPart = platformModel:FindFirstChild("Left")
	self.RightPart = platformModel:FindFirstChild("Right")
	self.InUse = false
	return self
end

function Platform:Reset()
	self.InUse = false
	print("Platform " .. self.Model.Name .. " reset and ready for new players")
end

-- Initialize all platforms in Lobby folder
function LobbyManager:Initialize()
	local lobby = game.Workspace:WaitForChild("Lobby")

	for _, platformModel in pairs(lobby:GetChildren()) do
		if platformModel:IsA("Model") and platformModel:FindFirstChild("Left") and platformModel:FindFirstChild("Right") then
			local platform = Platform.new(platformModel)
			table.insert(self.ActivePlatforms, platform)
			print("Initialized platform: " .. platformModel.Name)
		end
	end

	print("LobbyManager initialized - JoinScreen handles matchmaking")
end

-- Initialize on server start
task.wait(1)
LobbyManager:Initialize()

return LobbyManager
