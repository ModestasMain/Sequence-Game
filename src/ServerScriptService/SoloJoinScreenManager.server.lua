-- SoloJoinScreenManager.server.lua
-- Handles Press E to Join for solo platforms

local SoloJoinScreenManager = {}

function SoloJoinScreenManager:SetupPlatform(platformModel)
	local joinScreen = platformModel:FindFirstChild("JoinScreen")
	if not joinScreen then return end

	local gui = joinScreen:FindFirstChild("JoinGui")
	local joinPrompt = joinScreen:FindFirstChild("JoinPrompt")
	if not gui or not joinPrompt then return end

	-- Update prompt text for solo
	joinPrompt.ActionText = "Play Solo"
	joinPrompt.ObjectText = "Solo Memory Sequence"

	local gameInProgress = false
	local debounce = {}

	-- UI Elements
	local bgFrame = Instance.new("Frame")
	bgFrame.Size = UDim2.new(1, 0, 1, 0)
	bgFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bgFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 80)
	titleLabel.Position = UDim2.new(0, 0, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "SOLO MODE"
	titleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	titleLabel.TextSize = 40
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextStrokeTransparency = 0
	titleLabel.Parent = bgFrame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0, 40)
	subtitleLabel.Position = UDim2.new(0, 0, 0, 100)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "How far can you go?"
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	subtitleLabel.TextSize = 24
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Parent = bgFrame

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -40, 0, 80)
	infoLabel.Position = UDim2.new(0, 20, 0, 160)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "3 Lives\nSequence grows each round\nSee how far you can get!"
	infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	infoLabel.TextSize = 22
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.Parent = bgFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 40)
	statusLabel.Position = UDim2.new(0, 0, 1, -60)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Press E to Play"
	statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	statusLabel.TextSize = 28
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextStrokeTransparency = 0.5
	statusLabel.Parent = bgFrame

	local function updateDisplay()
		if gameInProgress then
			statusLabel.Text = "Game In Progress..."
			statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		else
			statusLabel.Text = "Press E to Play"
			statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		end
	end

	joinPrompt.Triggered:Connect(function(player)
		print("[SoloJoin] E pressed by " .. player.Name .. " on " .. platformModel.Name)

		if debounce[player.UserId] then return end
		debounce[player.UserId] = true
		task.delay(2, function()
			debounce[player.UserId] = nil
		end)

		if gameInProgress then return end

		gameInProgress = true
		joinPrompt.Enabled = false
		updateDisplay()

		print("[SoloJoin] Starting solo game for " .. player.Name)

		local SoloGameManager = require(game.ServerScriptService:WaitForChild("SoloGameManager"))

		local platformObj = {
			Model = platformModel,
			LeftPart = platformModel:FindFirstChild("Left"),
			RightPart = platformModel:FindFirstChild("Right")
		}

		function platformObj:Reset()
			gameInProgress = false
			joinPrompt.Enabled = true
			updateDisplay()
			print("[SoloJoin] " .. platformModel.Name .. " reset")
		end

		SoloGameManager:StartGame(player, platformObj)
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		debounce[player.UserId] = nil
	end)

	updateDisplay()
	print("[SoloJoin] Setup complete for " .. platformModel.Name)
end

function SoloJoinScreenManager:Initialize()
	local workspace = game.Workspace

	for _, child in pairs(workspace:GetChildren()) do
		if child:IsA("Model") and child.Name:match("^SoloPlatform") and child:FindFirstChild("JoinScreen") then
			self:SetupPlatform(child)
		end
	end

	print("[SoloJoin] All solo platforms initialized")
end

task.wait(2)
SoloJoinScreenManager:Initialize()

return SoloJoinScreenManager
