-- AnnouncementBanner.client.lua
-- Shows a sliding bottom toast for IQ milestones and win streaks.
--!strict

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local announceEvent   = remoteEvents:WaitForChild("IQMilestoneAnnounce")
local streakEvent     = remoteEvents:WaitForChild("StreakAnnounce")
local TitleConfig     = require(ReplicatedStorage:WaitForChild("TitleConfig"))

-- ── Milestone flavour — uses the same IQ tier names as the game ────────────

local function getMilestoneLabel(iq: number): (string, Color3)
	return TitleConfig.GetTitle(iq, nil)
end

-- ── Banner state ────────────────────────────────────────────────────────────

local currentGui: ScreenGui? = nil
local dismissThread: thread? = nil

-- mainText: top line, badgeText: bottom coloured label, iconEmoji, accentColor
local function showBanner(mainText: string, badgeText: string, iconEmoji: string, accentColor: Color3)
	-- Destroy any existing banner
	if currentGui and currentGui.Parent then
		currentGui:Destroy()
	end
	if dismissThread then
		task.cancel(dismissThread)
		dismissThread = nil
	end

	-- ── Build GUI ──
	local gui = Instance.new("ScreenGui")
	gui.Name           = "AnnouncementBanner"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn   = false
	gui.DisplayOrder   = 120
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent         = playerGui
	currentGui         = gui

	-- Centered pill — only 42% wide so it doesn't cover side stats
	local bar = Instance.new("Frame", gui)
	bar.Size             = UDim2.new(0.42, 0, 0.07, 0)
	bar.AnchorPoint      = Vector2.new(0.5, 1)
	bar.Position         = UDim2.fromScale(0.5, 1.08)  -- starts off-screen below
	bar.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	bar.BorderSizePixel  = 0
	bar.ZIndex           = 2
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

	-- Accent line at the top of the bar
	local accent = Instance.new("Frame", bar)
	accent.Size             = UDim2.new(1, 0, 0, 3)
	accent.Position         = UDim2.new(0, 0, 0, 0)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel  = 0
	accent.ZIndex           = 3

	-- Icon
	local icon = Instance.new("TextLabel", bar)
	icon.Size                   = UDim2.new(0.1, 0, 1, 0)
	icon.Position               = UDim2.fromScale(0.02, 0)
	icon.BackgroundTransparency = 1
	icon.Text                   = iconEmoji
	icon.TextScaled             = true
	icon.ZIndex                 = 3

	-- Main message
	local msg = Instance.new("TextLabel", bar)
	msg.Size                   = UDim2.new(0.78, 0, 0.55, 0)
	msg.Position               = UDim2.fromScale(0.14, 0.08)
	msg.BackgroundTransparency = 1
	msg.TextScaled             = true
	msg.Font                   = Enum.Font.GothamBold
	msg.TextXAlignment         = Enum.TextXAlignment.Left
	msg.ZIndex                 = 3
	msg.TextColor3             = Color3.fromRGB(240, 240, 240)
	msg.Text                   = mainText

	-- Badge label
	local badge = Instance.new("TextLabel", bar)
	badge.Size                   = UDim2.new(0.78, 0, 0.38, 0)
	badge.Position               = UDim2.fromScale(0.14, 0.58)
	badge.BackgroundTransparency = 1
	badge.TextScaled             = true
	badge.Font                   = Enum.Font.GothamBold
	badge.TextXAlignment         = Enum.TextXAlignment.Left
	badge.ZIndex                 = 3
	badge.TextColor3             = accentColor
	badge.Text                   = badgeText

	-- ── Slide in ──
	TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.97),
	}):Play()

	-- ── Auto-dismiss after 5s ──
	dismissThread = task.delay(5, function()
		dismissThread = nil
		if not gui.Parent then return end
		TweenService:Create(bar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(0.5, 1.08),
		}):Play()
		task.wait(0.3)
		if gui.Parent then gui:Destroy() end
	end)
end

-- ── Streak flavour ──────────────────────────────────────────────────────────

local function getStreakColor(streak: number): Color3
	if streak >= 20 then return Color3.fromRGB(255, 215,   0) end  -- gold
	if streak >= 10 then return Color3.fromRGB(255, 100,  30) end  -- deep orange
	if streak >= 5  then return Color3.fromRGB(255, 160,  30) end  -- orange
	return                     Color3.fromRGB(255, 200, 100)        -- light orange
end

-- ── Listen ──────────────────────────────────────────────────────────────────

announceEvent.OnClientEvent:Connect(function(playerName: string, iq: number)
	local label, accentColor = getMilestoneLabel(iq)
	local isLocal = (playerName == player.Name)
	local mainText = isLocal
		and string.format("You reached %d IQ!", iq)
		or  string.format("%s reached %d IQ!", playerName, iq)
	showBanner(mainText, label, "🧠", accentColor)
end)

streakEvent.OnClientEvent:Connect(function(playerName: string, streak: number, msg: string)
	local isLocal  = (playerName == player.Name)
	local color    = getStreakColor(streak)
	local mainText = isLocal and ("You " .. msg) or (playerName .. " " .. msg)
	showBanner(mainText, tostring(streak) .. "-WIN STREAK", "🔥", color)
end)
