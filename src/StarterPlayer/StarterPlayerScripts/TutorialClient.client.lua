-- TutorialClient.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")

local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local showEvent    = remoteEvents:WaitForChild("TutorialShow")
local doneEvent    = remoteEvents:WaitForChild("TutorialDone")

local COL_CARD     = Color3.fromRGB(18, 18, 22)
local COL_TITLE_BG = Color3.fromRGB(28, 28, 34)
local COL_ROW      = Color3.fromRGB(26, 26, 32)
local COL_STROKE   = Color3.fromRGB(55, 55, 65)
local COL_WHITE    = Color3.fromRGB(255, 255, 255)
local COL_GRAY     = Color3.fromRGB(180, 180, 190)
local COL_BTN      = Color3.fromRGB(240, 240, 245)
local COL_BTN_HOV  = Color3.fromRGB(210, 210, 220)

local STEPS = {
	{ icon = "👁",  title = "Watch the Sequence",   desc = "Tiles on the grid light up one by one.\nMemorize the exact order." },
	{ icon = "🎯",  title = "Repeat It Exactly",    desc = "Click the tiles in the same order.\nOne mistake costs a life!" },
	{ icon = "❤",   title = "Don't Lose All Lives", desc = "You get 3 lives per game.\nOutlast your opponent to win." },
}

local function make(className, parent, props)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function buildTutorial()
	local existing = playerGui:FindFirstChild("TutorialScreen")
	if existing then existing:Destroy() end

	local screenGui = make("ScreenGui", playerGui, {
		Name           = "TutorialScreen",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		ResetOnSpawn   = false,
		DisplayOrder   = 999,
	})

	-- Dim overlay
	make("Frame", screenGui, {
		Size                   = UDim2.fromScale(1, 1),
		BackgroundColor3       = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		BorderSizePixel        = 0,
		ZIndex                 = 10,
	})

	-- Card (scale-based, centered)
	local card = make("Frame", screenGui, {
		Size             = UDim2.fromScale(0.34, 0.72),
		Position         = UDim2.fromScale(0.5, 0.5),
		AnchorPoint      = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COL_CARD,
		BorderSizePixel  = 0,
		ZIndex           = 11,
	})
	make("UICorner", card, { CornerRadius = UDim.new(0, 14) })
	make("UIStroke", card, { Color = COL_STROKE, Thickness = 1.5 })

	-- Stack sections using UIListLayout
	local list = make("UIListLayout", card, {
		FillDirection      = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder          = Enum.SortOrder.LayoutOrder,
		Padding            = UDim.new(0, 0),
	})

	-- Title bar (16% height)
	local titleBar = make("Frame", card, {
		Size             = UDim2.fromScale(1, 0.16),
		BackgroundColor3 = COL_TITLE_BG,
		BorderSizePixel  = 0,
		ZIndex           = 12,
		LayoutOrder      = 0,
	})
	make("UICorner", titleBar, { CornerRadius = UDim.new(0, 14) })
	-- Cover bottom corners of title bar
	make("Frame", titleBar, {
		Size             = UDim2.new(1, 0, 0.5, 0),
		Position         = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = COL_TITLE_BG,
		BorderSizePixel  = 0,
		ZIndex           = 12,
	})
	make("TextLabel", titleBar, {
		Size                   = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text                   = "🧠  HOW TO PLAY",
		TextColor3             = COL_WHITE,
		Font                   = Enum.Font.GothamBold,
		TextScaled             = true,
		ZIndex                 = 13,
	})

	-- Step rows (22% each, 3 rows = 66%)
	for i, step in ipairs(STEPS) do
		local row = make("Frame", card, {
			Size             = UDim2.fromScale(1, 0.22),
			BackgroundColor3 = COL_CARD,
			BorderSizePixel  = 0,
			ZIndex           = 12,
			LayoutOrder      = i,
		})

		local inner = make("Frame", row, {
			Size             = UDim2.new(1, -24, 1, -14),
			Position         = UDim2.fromScale(0.5, 0.5),
			AnchorPoint      = Vector2.new(0.5, 0.5),
			BackgroundColor3 = COL_ROW,
			BorderSizePixel  = 0,
			ZIndex           = 12,
		})
		make("UICorner", inner, { CornerRadius = UDim.new(0, 10) })
		make("UIStroke", inner, { Color = COL_STROKE, Thickness = 1 })

		-- Icon (left 20%)
		make("TextLabel", inner, {
			Size                   = UDim2.fromScale(0.18, 1),
			Position               = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			Text                   = step.icon,
			TextScaled             = true,
			Font                   = Enum.Font.GothamBold,
			ZIndex                 = 13,
		})

		-- Title (top-right)
		make("TextLabel", inner, {
			Size                   = UDim2.fromScale(0.78, 0.42),
			Position               = UDim2.fromScale(0.20, 0.06),
			BackgroundTransparency = 1,
			Text                   = step.title,
			TextColor3             = COL_WHITE,
			Font                   = Enum.Font.GothamBold,
			TextScaled             = true,
			TextXAlignment         = Enum.TextXAlignment.Left,
			ZIndex                 = 13,
		})

		-- Desc (bottom-right)
		make("TextLabel", inner, {
			Size                   = UDim2.fromScale(0.78, 0.46),
			Position               = UDim2.fromScale(0.20, 0.50),
			BackgroundTransparency = 1,
			Text                   = step.desc,
			TextColor3             = COL_GRAY,
			Font                   = Enum.Font.Gotham,
			TextScaled             = true,
			TextXAlignment         = Enum.TextXAlignment.Left,
			TextWrapped            = true,
			ZIndex                 = 13,
		})
	end

	-- Button row (18% height, remaining)
	local btnRow = make("Frame", card, {
		Size             = UDim2.fromScale(1, 0.18),
		BackgroundColor3 = COL_CARD,
		BorderSizePixel  = 0,
		ZIndex           = 12,
		LayoutOrder      = 4,
	})

	local playBtn = make("TextButton", btnRow, {
		Size             = UDim2.new(0.55, 0, 0.6, 0),
		Position         = UDim2.fromScale(0.5, 0.5),
		AnchorPoint      = Vector2.new(0.5, 0.5),
		BackgroundColor3 = COL_BTN,
		BorderSizePixel  = 0,
		Text             = "Let's Play!",
		TextColor3       = Color3.fromRGB(20, 20, 26),
		Font             = Enum.Font.GothamBold,
		TextScaled       = true,
		ZIndex           = 12,
	})
	make("UICorner", playBtn, { CornerRadius = UDim.new(0.3, 0) })

	playBtn.MouseEnter:Connect(function()
		TweenService:Create(playBtn, TweenInfo.new(0.15), { BackgroundColor3 = COL_BTN_HOV }):Play()
	end)
	playBtn.MouseLeave:Connect(function()
		TweenService:Create(playBtn, TweenInfo.new(0.15), { BackgroundColor3 = COL_BTN }):Play()
	end)
	playBtn.MouseButton1Click:Connect(function()
		doneEvent:FireServer()
		screenGui:Destroy()
	end)

	-- Fade in
	screenGui.Parent = playerGui
end

-- Show 2 seconds after load for testing; switch to event-only after confirmed working
task.wait(2)
buildTutorial()

showEvent.OnClientEvent:Connect(buildTutorial)
