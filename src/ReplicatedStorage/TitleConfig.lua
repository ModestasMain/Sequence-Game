-- TitleConfig.lua
-- IQ-based automatic titles and purchasable cosmetic titles

local TitleConfig = {}

-- IQ tiers — checked highest first, first match wins
-- These are FREE and auto-assigned based on current IQ
TitleConfig.IQTiers = {
	{ minIQ = 500, text = "Sequence God",   color = Color3.fromRGB(255, 220, 80)  },
	{ minIQ = 400, text = "Prodigy",        color = Color3.fromRGB(255, 160, 40)  },
	{ minIQ = 300, text = "Genius",         color = Color3.fromRGB(255, 210, 0)   },
	{ minIQ = 250, text = "Mastermind",     color = Color3.fromRGB(180, 80, 255)  },
	{ minIQ = 200, text = "Strategist",     color = Color3.fromRGB(60, 210, 100)  },
	{ minIQ = 160, text = "Sharp Mind",     color = Color3.fromRGB(0, 210, 255)   },
	{ minIQ = 135, text = "Pattern Seeker", color = Color3.fromRGB(120, 180, 255) },
	{ minIQ = 110, text = "Apprentice",     color = Color3.fromRGB(220, 220, 220) },
	{ minIQ = 90,  text = "Novice",         color = Color3.fromRGB(160, 160, 160) },
	{ minIQ = 60,  text = "Forgetful",      color = Color3.fromRGB(255, 140, 60)  },
	{ minIQ = 1,   text = "Amnesiac",       color = Color3.fromRGB(255, 70, 70)   },
}

-- Purchasable titles — equipping one overrides the IQ tier title
-- Display order in the world shop
TitleConfig.ShopOrder = {
	"BrainRot", "TouchGrass", "TryingMyBest",
	"TheThinker", "TheVeteran",
	"SequenceKing", "PatternGod",
	"TheChosenOne",
}

TitleConfig.Titles = {
	-- ── Funny / Cheap ───────────────────────────────────────────────────────
	BrainRot = {
		Name  = "Brain Rot",
		Price = 150,
		Color = Color3.fromRGB(120, 210, 100),
	},
	TouchGrass = {
		Name  = "Touch Grass",
		Price = 200,
		Color = Color3.fromRGB(80, 190, 80),
	},
	TryingMyBest = {
		Name  = "Trying My Best",
		Price = 250,
		Color = Color3.fromRGB(200, 200, 200),
	},

	-- ── Mid Tier ────────────────────────────────────────────────────────────
	TheThinker = {
		Name  = "The Thinker",
		Price = 400,
		Color = Color3.fromRGB(100, 160, 255),
	},
	TheVeteran = {
		Name  = "The Veteran",
		Price = 500,
		Color = Color3.fromRGB(190, 150, 80),
	},

	-- ── Prestigious ─────────────────────────────────────────────────────────
	SequenceKing = {
		Name  = "Sequence King",
		Price = 750,
		Color = Color3.fromRGB(255, 215, 0),
	},
	PatternGod = {
		Name  = "Pattern God",
		Price = 900,
		Color = Color3.fromRGB(0, 220, 255),
	},

	-- ── Ultra Rare ──────────────────────────────────────────────────────────
	TheChosenOne = {
		Name  = "The Chosen One",
		Price = 1500,
		Color = Color3.fromRGB(255, 240, 160),
	},
}

-- Returns the title text and color for a given IQ + optional equipped title key
function TitleConfig.GetTitle(iq, equippedKey)
	if equippedKey and equippedKey ~= "" then
		local t = TitleConfig.Titles[equippedKey]
		if t then return t.Name, t.Color end
	end
	for _, tier in ipairs(TitleConfig.IQTiers) do
		if iq >= tier.minIQ then
			return tier.text, tier.color
		end
	end
	return "Novice", Color3.fromRGB(160, 160, 160)
end

return TitleConfig
