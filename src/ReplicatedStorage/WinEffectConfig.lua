-- WinEffectConfig.lua
-- Defines purchasable win celebration effects.
-- Each effect is a different particle animation that plays on the win screen.

local WinEffectConfig = {}

-- Display order in the shop
WinEffectConfig.Order = {"Default", "Fireworks", "MoneyRain", "Galaxy", "Lightning"}

WinEffectConfig.Effects = {

	-- ── FREE ──────────────────────────────────────────────────────────────────

	Default = {
		Name        = "Default",
		Price       = 0,
		Icon        = "🎊",
		Color       = Color3.fromRGB(200, 200, 200),
		Description = "Classic confetti burst",
	},

	-- ── TIER 1 (250 coins) ────────────────────────────────────────────────────

	Fireworks = {
		Name        = "Fireworks",
		Price       = 250,
		Icon        = "🎆",
		Color       = Color3.fromRGB(255, 100, 50),
		Description = "Rockets explode across the screen",
		Weight      = 40,
	},

	-- ── TIER 2 (350 coins) ────────────────────────────────────────────────────

	MoneyRain = {
		Name        = "Money Rain",
		Price       = 350,
		Icon        = "💰",
		Color       = Color3.fromRGB(255, 215, 50),
		Description = "Gold coins rain from the sky",
		Weight      = 30,
	},

	-- ── TIER 3 (500 coins) ────────────────────────────────────────────────────

	Galaxy = {
		Name        = "Galaxy",
		Price       = 500,
		Icon        = "🌌",
		Color       = Color3.fromRGB(120, 80, 255),
		Description = "Stars swirl out from the center",
		Weight      = 20,
	},

	-- ── TIER 4 (600 coins) ────────────────────────────────────────────────────

	Lightning = {
		Name        = "Lightning",
		Price       = 600,
		Icon        = "⚡",
		Color       = Color3.fromRGB(200, 150, 255),
		Description = "Electric lightning storm",
		Weight      = 10,
	},
}

return WinEffectConfig
