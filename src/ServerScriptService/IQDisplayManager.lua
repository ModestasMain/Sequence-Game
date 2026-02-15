-- IQDisplayManager.lua
-- Creates and updates IQ displays above player heads

local Players = game:GetService("Players")

local IQDisplayManager = {}

-- Create IQ display above player's head
function IQDisplayManager:CreateDisplay(player)
	-- Wait for character to load
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1) -- Small delay to ensure head is loaded

		local head = character:WaitForChild("Head", 5)
		if not head then return end

		-- Remove old display if it exists
		local oldDisplay = head:FindFirstChild("IQDisplay") :: Instance?
		if oldDisplay then
			oldDisplay:Destroy()
		end

		-- Create BillboardGui
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "IQDisplay"
		billboardGui.Size = UDim2.new(0, 200, 0, 50)
		billboardGui.StudsOffset = Vector3.new(0, 3, 0)  -- Above head
		billboardGui.AlwaysOnTop = true
		billboardGui.Parent = head

		-- Background Frame
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 1, 0)
		frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		frame.BackgroundTransparency = 0.3
		frame.BorderSizePixel = 0
		frame.Parent = billboardGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame

		-- IQ Text Label
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "IQText"
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = "IQ: 100"
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextSize = 24
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextStrokeTransparency = 0.5
		textLabel.Parent = frame

		-- Update IQ value
		self:UpdateDisplay(player)
	end)

	-- If character already exists, create display
	if player.Character then
		local character = player.Character
		task.spawn(function()
			task.wait(0.1)
			local head = character:FindFirstChild("Head")
			if not head then return end

			-- Remove old display if it exists
			local oldDisplay = head:FindFirstChild("IQDisplay") :: Instance?
			if oldDisplay then
				oldDisplay:Destroy()
			end

			-- Create BillboardGui
			local billboardGui = Instance.new("BillboardGui")
			billboardGui.Name = "IQDisplay"
			billboardGui.Size = UDim2.new(0, 200, 0, 50)
			billboardGui.StudsOffset = Vector3.new(0, 3, 0)
			billboardGui.AlwaysOnTop = true
			billboardGui.Parent = head

			-- Background Frame
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(1, 0, 1, 0)
			frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			frame.BackgroundTransparency = 0.3
			frame.BorderSizePixel = 0
			frame.Parent = billboardGui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = frame

			-- IQ Text Label
			local textLabel = Instance.new("TextLabel")
			textLabel.Name = "IQText"
			textLabel.Size = UDim2.new(1, 0, 1, 0)
			textLabel.BackgroundTransparency = 1
			textLabel.Text = "IQ: 100"
			textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			textLabel.TextSize = 24
			textLabel.Font = Enum.Font.GothamBold
			textLabel.TextStrokeTransparency = 0.5
			textLabel.Parent = frame

			-- Update IQ value
			self:UpdateDisplay(player)
		end)
	end
end

-- Update IQ display text
function IQDisplayManager:UpdateDisplay(player)
	if not player.Character then return end
	local head = player.Character:FindFirstChild("Head")
	if not head then return end

	local display = head:FindFirstChild("IQDisplay")
	if not display then return end

	local textLabel = display:FindFirstChild("Frame"):FindFirstChild("IQText")
	if not textLabel then return end

	-- Get IQ from leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local iqValue = leaderstats:FindFirstChild("IQ")
	if not iqValue then return end

	local iq = iqValue.Value

	-- Update text
	textLabel.Text = "IQ: " .. tostring(iq)

	-- Color based on IQ level
	if iq >= 200 then
		textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)  -- Gold
	elseif iq >= 150 then
		textLabel.TextColor3 = Color3.fromRGB(138, 43, 226)  -- Purple
	elseif iq >= 120 then
		textLabel.TextColor3 = Color3.fromRGB(0, 191, 255)  -- Blue
	elseif iq >= 100 then
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)  -- White
	elseif iq >= 80 then
		textLabel.TextColor3 = Color3.fromRGB(255, 165, 0)  -- Orange
	else
		textLabel.TextColor3 = Color3.fromRGB(255, 100, 100)  -- Red
	end
end

-- Initialize for all players
Players.PlayerAdded:Connect(function(player)
	IQDisplayManager:CreateDisplay(player)

	-- Listen for IQ changes
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local iqValue = leaderstats:WaitForChild("IQ", 10)
		if iqValue then
			iqValue.Changed:Connect(function()
				IQDisplayManager:UpdateDisplay(player)
			end)
		end
	end
end)

-- Handle existing players (in case script loads after players join)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		IQDisplayManager:CreateDisplay(player)

		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local iqValue = leaderstats:FindFirstChild("IQ")
			if iqValue then
				iqValue.Changed:Connect(function()
					IQDisplayManager:UpdateDisplay(player)
				end)
			end
		end
	end)
end

return IQDisplayManager
