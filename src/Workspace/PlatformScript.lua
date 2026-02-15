-- PlatformScript.lua
-- Place this script inside each Platform model in the Lobby
-- This is a simplified version - the main logic is in LobbyManager

local platform = script.Parent
local leftPart = platform:WaitForChild("Left")
local rightPart = platform:WaitForChild("Right")

-- Visual setup
leftPart.BrickColor = BrickColor.new("Bright green")
leftPart.Material = Enum.Material.Neon
leftPart.Anchored = true
leftPart.CanCollide = true
leftPart.Size = Vector3.new(6, 1, 6)

rightPart.BrickColor = BrickColor.new("Bright green")
rightPart.Material = Enum.Material.Neon
rightPart.Anchored = true
rightPart.CanCollide = true
rightPart.Size = Vector3.new(6, 1, 6)

-- Position them side by side
rightPart.Position = leftPart.Position + Vector3.new(8, 0, 0)

-- Create label
local labelPart = Instance.new("Part")
labelPart.Name = "Label"
labelPart.Size = Vector3.new(14, 0.2, 6)
labelPart.Position = leftPart.Position + Vector3.new(4, 2, 0)
labelPart.Anchored = true
labelPart.CanCollide = false
labelPart.Transparency = 1
labelPart.Parent = platform

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Face = Enum.NormalId.Top
surfaceGui.Parent = labelPart

local textLabel = Instance.new("TextLabel")
textLabel.Name = "PlayerCount"
textLabel.Size = UDim2.new(1, 0, 1, 0)
textLabel.BackgroundTransparency = 1
textLabel.Text = "0/2 Players"
textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
textLabel.TextScaled = true
textLabel.Font = Enum.Font.GothamBlack
textLabel.Parent = surfaceGui

-- Store reference for LobbyManager to update
platform:SetAttribute("PlayerCountLabel", true)

print("Platform " .. platform.Name .. " initialized")
