-- QuickJoinUI.client.lua
-- Portrait cards at the top of the screen when a player is waiting at a 1v1 table.
-- Cards are stacked horizontally (one per waiting platform).

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local quickJoinNotify = remoteEvents:WaitForChild("QuickJoinNotify")
local quickJoinRequest = remoteEvents:WaitForChild("QuickJoinRequest")
local showGameUI      = remoteEvents:WaitForChild("ShowGameUI")

local inGame = false
local cards  = {}   -- [platformName] = Frame

-- ── ScreenGui ─────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "QuickJoinUI"
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 10
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

-- Container: wide strip at top-center, auto-sizes in X as cards are added
-- Height = 17% of screen. Width grows with UIListLayout content.
local container = Instance.new("Frame")
container.Name          = "Container"
container.AnchorPoint   = Vector2.new(0.5, 0)
container.Position      = UDim2.new(0.5, 0, 0.13, 0)
container.Size          = UDim2.new(0, 0, 0.17, 0)   -- height fixed; width auto
container.AutomaticSize = Enum.AutomaticSize.X
container.BackgroundTransparency = 1
container.Parent        = screenGui

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection       = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
listLayout.Padding             = UDim.new(0, 8)
listLayout.Parent              = container

-- ── Card factory ──────────────────────────────────────────────────────────────
local CARD_W = 100   -- px — portrait card width
-- height = 100% of container = 17% of screen height

local function dismissCard(platformName)
	local card = cards[platformName]
	if not card then return end
	cards[platformName] = nil

	TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position             = UDim2.new(0, 0, -1.2, 0),
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.22, function()
		if card and card.Parent then card:Destroy() end
	end)
end

local function createCard(platformName, userId, playerName, gridSize)
	if cards[platformName] then return end
	if inGame then return end

	-- ── Outer card ────────────────────────────────────────────────────────────
	local card = Instance.new("Frame")
	card.Name                   = "Card_" .. platformName
	card.Size                   = UDim2.new(0, CARD_W, 1, 0)   -- fixed px wide, full container height
	card.BackgroundColor3       = Color3.fromRGB(18, 18, 28)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel        = 0
	card.ClipsDescendants       = true
	card.Parent                 = container
	cards[platformName]         = card

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent       = card

	local stroke = Instance.new("UIStroke")
	stroke.Color        = Color3.fromRGB(80, 220, 100)
	stroke.Thickness    = 1.5
	stroke.Transparency = 0.45
	stroke.Parent       = card

	-- ── Avatar (top 58% of card, square via AspectRatioConstraint) ───────────
	local avatarFrame = Instance.new("Frame")
	avatarFrame.AnchorPoint         = Vector2.new(0.5, 0)
	avatarFrame.Position            = UDim2.new(0.5, 0, 0.04, 0)
	avatarFrame.Size                = UDim2.new(0.82, 0, 0.58, 0)
	avatarFrame.BackgroundColor3    = Color3.fromRGB(40, 40, 55)
	avatarFrame.BorderSizePixel     = 0
	avatarFrame.Parent              = card

	local afCorner = Instance.new("UICorner")
	afCorner.CornerRadius = UDim.new(0.08, 0)
	afCorner.Parent       = avatarFrame

	-- Force square via AspectRatioConstraint (width is the smaller axis on portrait cards)
	local arc = Instance.new("UIAspectRatioConstraint")
	arc.AspectRatio  = 1
	arc.DominantAxis = Enum.DominantAxis.Width
	arc.Parent       = avatarFrame

	local avatar = Instance.new("ImageLabel")
	avatar.Size                 = UDim2.new(1, 0, 1, 0)
	avatar.BackgroundTransparency = 1
	avatar.Image                = ""
	avatar.ScaleType            = Enum.ScaleType.Fit
	avatar.Parent               = avatarFrame

	local avCorner = Instance.new("UICorner")
	avCorner.CornerRadius = UDim.new(0.08, 0)
	avCorner.Parent = avatar

	-- Load headshot
	task.spawn(function()
		local ok, url = pcall(
			Players.GetUserThumbnailAsync, Players,
			userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150
		)
		if ok and avatar.Parent then avatar.Image = url end
	end)

	-- ── Name label (below avatar) ─────────────────────────────────────────────
	local nameLabel = Instance.new("TextLabel")
	nameLabel.AnchorPoint          = Vector2.new(0.5, 0)
	nameLabel.Position             = UDim2.new(0.5, 0, 0.65, 0)
	nameLabel.Size                 = UDim2.new(0.95, 0, 0.12, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text                 = playerName
	nameLabel.TextColor3           = Color3.fromRGB(220, 220, 220)
	nameLabel.TextScaled           = true
	nameLabel.Font                 = Enum.Font.GothamBold
	nameLabel.TextTruncate         = Enum.TextTruncate.AtEnd
	nameLabel.Parent               = card

	-- ── JOIN button (bottom of card) ──────────────────────────────────────────
	local joinBtn = Instance.new("TextButton")
	joinBtn.AnchorPoint      = Vector2.new(0.5, 1)
	joinBtn.Position         = UDim2.new(0.5, 0, 0.97, 0)
	joinBtn.Size             = UDim2.new(0.88, 0, 0.19, 0)
	joinBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
	joinBtn.Text             = "JOIN"
	joinBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	joinBtn.TextScaled       = true
	joinBtn.Font             = Enum.Font.GothamBold
	joinBtn.BorderSizePixel  = 0
	joinBtn.Parent           = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0.3, 0)
	btnCorner.Parent       = joinBtn

	joinBtn.MouseEnter:Connect(function()
		TweenService:Create(joinBtn, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(70, 230, 100),
		}):Play()
	end)
	joinBtn.MouseLeave:Connect(function()
		TweenService:Create(joinBtn, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(50, 200, 80),
		}):Play()
	end)

	joinBtn.Activated:Connect(function()
		dismissCard(platformName)
		quickJoinRequest:FireServer(platformName)
	end)

	-- Slide in from above
	card.Position = UDim2.new(0, 0, -1.2, 0)
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()
end

-- ── Game state — hide all cards while in a game ───────────────────────────────
showGameUI.OnClientEvent:Connect(function(showing)
	inGame = showing
	if showing then
		for name in pairs(cards) do
			dismissCard(name)
		end
	end
end)

-- ── Server notifications ──────────────────────────────────────────────────────
quickJoinNotify.OnClientEvent:Connect(function(showing, platformName, userId, playerName, gridSize)
	if showing then
		createCard(platformName, userId, playerName, gridSize)
	else
		dismissCard(platformName)
	end
end)
