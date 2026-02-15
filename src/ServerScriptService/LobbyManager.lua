-- LobbyManager.lua
-- Manages lobby platforms and matchmaking

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local LobbyManager = {}
LobbyManager.ActivePlatforms = {}

-- Platform class
local Platform = {}
Platform.__index = Platform

function Platform.new(platformModel)
	local self = setmetatable({}, Platform)
	self.Model = platformModel
	self.LeftPart = platformModel:FindFirstChild("Left")
	self.RightPart = platformModel:FindFirstChild("Right")
	self.Players = {}
	self.PlayerDebounce = {} -- Track which players are on the platform
	self.InUse = false
	self.Countdown = nil

	-- Find the player count label
	self.PlayerCountLabel = nil
	local labelPart = platformModel:FindFirstChild("Label")
	if labelPart then
		local surfaceGui = labelPart:FindFirstChild("SurfaceGui")
		if surfaceGui then
			self.PlayerCountLabel = surfaceGui:FindFirstChild("PlayerCount")
		end
	end

	-- Set up touch detection
	if self.LeftPart then
		self.LeftPart.Touched:Connect(function(hit)
			self:OnTouch(hit, "Left")
		end)
		self.LeftPart.TouchEnded:Connect(function(hit)
			self:OnTouchEnded(hit, "Left")
		end)
	end

	if self.RightPart then
		self.RightPart.Touched:Connect(function(hit)
			self:OnTouch(hit, "Right")
		end)
		self.RightPart.TouchEnded:Connect(function(hit)
			self:OnTouchEnded(hit, "Right")
		end)
	end

	return self
end

function Platform:UpdatePlayerCount()
	if self.PlayerCountLabel then
		local count = #self.Players
		self.PlayerCountLabel.Text = count .. "/2 Players"

		-- Change color based on count
		if count == 0 then
			self.PlayerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		elseif count == 1 then
			self.PlayerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		else
			self.PlayerCountLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
	end
end

function Platform:OnTouch(hit, side)
	if self.InUse then return end

	-- Only check for HumanoidRootPart to avoid multiple touches from different body parts
	if hit.Name ~= "HumanoidRootPart" then return end

	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if not humanoid then return end

	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end

	-- Debounce: Check if player is already registered on this platform
	if self.PlayerDebounce[player.UserId] then return end

	-- Mark player as on platform (debounce)
	self.PlayerDebounce[player.UserId] = true

	-- Check if player already in the players list
	for _, p in pairs(self.Players) do
		if p == player then return end
	end

	-- Add player to platform
	table.insert(self.Players, player)
	print(player.Name .. " stepped on " .. side .. " platform")

	-- Update player count display
	self:UpdatePlayerCount()

	-- Check if we have 2 players
	if #self.Players >= GameConfig.PLAYERS_PER_GAME then
		self:StartCountdown()
	end
end

function Platform:OnTouchEnded(hit, side)
	if self.InUse then return end

	-- Only check for HumanoidRootPart to avoid false triggers
	if hit.Name ~= "HumanoidRootPart" then return end

	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if not humanoid then return end

	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if not player then return end

	-- Only process if player is actually on this platform
	if not self.PlayerDebounce[player.UserId] then return end

	-- Small delay to verify player actually left (prevents false triggers from shifting weight)
	task.wait(0.3)

	-- Check if player's HumanoidRootPart is still touching the platform
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local hrp = character.HumanoidRootPart
		local touching = hrp:GetTouchingParts()

		for _, part in ipairs(touching) do
			if part == self.LeftPart or part == self.RightPart then
				-- Still touching, don't remove
				return
			end
		end
	end

	-- Player actually left the platform
	self.PlayerDebounce[player.UserId] = nil

	-- Remove player from platform
	for i, p in pairs(self.Players) do
		if p == player then
			table.remove(self.Players, i)
			print(player.Name .. " left the platform")

			-- Update player count display
			self:UpdatePlayerCount()

			-- Cancel countdown if started
			if self.Countdown then
				task.cancel(self.Countdown)
				self.Countdown = nil
				print("Countdown cancelled - player left")
			end
			break
		end
	end
end

function Platform:StartCountdown()
	if self.Countdown then return end

	print("Starting countdown for platform...")

	self.Countdown = task.spawn(function()
		task.wait(GameConfig.PLATFORM_WAIT_TIME)

		-- Verify we still have 2 players
		if #self.Players >= GameConfig.PLAYERS_PER_GAME and not self.InUse then
			self:StartGame()
		else
			print("Not enough players, countdown cancelled")
			self.Countdown = nil
		end
	end)
end

function Platform:StartGame()
	if self.InUse then return end

	self.InUse = true
	local player1 = self.Players[1]
	local player2 = self.Players[2]

	print("Starting game between " .. player1.Name .. " and " .. player2.Name)

	-- Get GameManager and start game
	local GameManager = require(script.Parent:WaitForChild("GameManager"))
	GameManager:StartGame(player1, player2, self)
end

function Platform:Reset()
	self.InUse = false
	self.Players = {}
	self.PlayerDebounce = {}
	self.Countdown = nil
	print("Platform reset and ready for new players")
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
end

-- Initialize on server start
task.wait(1) -- Wait for workspace to load
LobbyManager:Initialize()

return LobbyManager
