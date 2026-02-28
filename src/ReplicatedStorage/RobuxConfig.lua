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
	{ Name = "100 Coins",  Icon = "💰", Amount = 100,  Robux = 25,  ProductId = 3541485910 },
	{ Name = "500 Coins",  Icon = "💰", Amount = 500,  Robux = 75,  ProductId = 3541485754 },
	{ Name = "1500 Coins", Icon = "💰", Amount = 1500, Robux = 175, ProductId = 3541486015 },
	{ Name = "5000 Coins", Icon = "💰", Amount = 5000, Robux = 499, ProductId = 3541486120 },
}

-- ── Reset IQ (Developer Product — reusable) ────────────────────────────────────
RobuxConfig.ResetIQ = {
	Name        = "Reset IQ",
	Description = "Resets your IQ back to 100",
	Icon        = "🔄",
	Robux       = 50,
	ProductId   = 3541486380,  -- paste your Developer Product ID here
}

-- ── Theme Game Passes ──────────────────────────────────────────────────────────
-- PassId = 0 hides the Robux button until you create the pass
RobuxConfig.ThemePasses = {
	Ocean      = { PassId = 1722527373, Robux = 100 },
	Forest     = { PassId = 1720783444, Robux = 100 },
	Neon       = { PassId = 1721099484, Robux = 150 },
	Sunset     = { PassId = 1722275410, Robux = 150 },
	Ice        = { PassId = 1722605448, Robux = 200 },
	Candy      = { PassId = 1721327515, Robux = 200 },
	Lava       = { PassId = 1721243402, Robux = 250 },
	Galaxy     = { PassId = 1720971483, Robux = 300 },
}

-- ── Title Game Passes ──────────────────────────────────────────────────────────
RobuxConfig.TitlePasses = {
	TouchGrass   = { PassId = 1721339419, Robux = 100 },
	TryingMyBest = { PassId = 1722347442, Robux = 150 },
	TheThinker   = { PassId = 1720759463, Robux = 200 },
	TheVeteran   = { PassId = 1721063350, Robux = 250 },
	SequenceKing = { PassId = 1721429440, Robux = 350 },
	PatternGod   = { PassId = 1722611351, Robux = 400 },
	TheChosenOne = { PassId = 1722437334, Robux = 600 },
}

-- ── Win Effects Case (Developer Product — reusable) ───────────────────────────
RobuxConfig.CaseProduct = {
	Name      = "Win Effects Case",
	Robux     = 25,
	ProductId = 3542871199,  -- paste your Developer Product ID here
}

-- ── Battle Pass (Developer Product — per season) ──────────────────────────
-- Set ProductId once you create the Developer Product in Creator Dashboard.
-- Keep in sync with BattlePassConfig.PREMIUM_PRODUCT_ID.
RobuxConfig.BattlePassProduct = {
	Name      = "Battle Pass",
	Robux     = 399,
	ProductId = 3546780752,
}

-- ── Sound Pack Game Passes ─────────────────────────────────────────────────────
RobuxConfig.SoundPasses = {
	Piano      = { PassId = 1720813462, Robux = 75  },
	Osu        = { PassId = 1720699504, Robux = 75  },
	Typewriter = { PassId = 1721615432, Robux = 100 },
	VineBoom   = { PassId = 1722455364, Robux = 150 },
}

return RobuxConfig
