-- RobuxConfig.lua
-- Robux purchase IDs for all shop items, coin bundles, and Reset IQ.
--
-- SETUP INSTRUCTIONS:
-- 1. Go to create.roblox.com → select your game
-- 2. Game Passes (themes/titles/sounds — one-time permanent):
--      Monetization → Passes → Create a Pass
--      Copy the numeric Pass ID into the PassId field below
-- 3. Developer Products (coin bundles, Reset IQ — reusable):
--      Monetization → Developer Products → Create a Developer Product
--      Copy the numeric Product ID into the ProductId field below
-- 4. Set PassId / ProductId to 0 to hide the Robux button for that item

local RobuxConfig = {}

-- ── Coin Bundles (Developer Products — can be purchased multiple times) ────────
RobuxConfig.CoinBundles = {
	{ Name = "500 Coins",  Icon = "💰", Amount = 500,  Robux = 75,  ProductId = 0 },
	{ Name = "1500 Coins", Icon = "💰", Amount = 1500, Robux = 175, ProductId = 0 },
	{ Name = "5000 Coins", Icon = "💰", Amount = 5000, Robux = 499, ProductId = 0 },
}

-- ── Reset IQ (Developer Product — reusable) ────────────────────────────────────
RobuxConfig.ResetIQ = {
	Name        = "Reset IQ",
	Description = "Resets your IQ back to 100",
	Icon        = "🔄",
	Robux       = 50,
	ProductId   = 0,  -- paste your Developer Product ID here
}

-- ── Theme Game Passes ──────────────────────────────────────────────────────────
-- PassId = 0 hides the Robux button until you create the pass
RobuxConfig.ThemePasses = {
	Ocean      = { PassId = 0, Robux = 100 },
	Forest     = { PassId = 0, Robux = 100 },
	Neon       = { PassId = 0, Robux = 150 },
	Sunset     = { PassId = 0, Robux = 150 },
	Ice        = { PassId = 0, Robux = 200 },
	Candy      = { PassId = 0, Robux = 200 },
	Lava       = { PassId = 0, Robux = 250 },
	Galaxy     = { PassId = 0, Robux = 300 },
}

-- ── Title Game Passes ──────────────────────────────────────────────────────────
RobuxConfig.TitlePasses = {
	BrainRot     = { PassId = 0, Robux = 100 },
	TouchGrass   = { PassId = 0, Robux = 100 },
	TryingMyBest = { PassId = 0, Robux = 150 },
	TheThinker   = { PassId = 0, Robux = 200 },
	TheVeteran   = { PassId = 0, Robux = 250 },
	SequenceKing = { PassId = 0, Robux = 350 },
	PatternGod   = { PassId = 0, Robux = 400 },
	TheChosenOne = { PassId = 0, Robux = 600 },
}

-- ── Sound Pack Game Passes ─────────────────────────────────────────────────────
RobuxConfig.SoundPasses = {
	Piano      = { PassId = 0, Robux = 75  },
	Osu        = { PassId = 0, Robux = 75  },
	Typewriter = { PassId = 0, Robux = 100 },
	VineBoom   = { PassId = 0, Robux = 150 },
}

return RobuxConfig
