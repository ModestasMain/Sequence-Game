-- SoundConfig.lua
-- Defines purchasable click sound packs for the sequence game.
--
-- Click:   short sound pitched per grid position using PITCH_MAP in SequenceClient.
-- Correct: one-shot played when a full sequence is completed correctly.
-- Wrong:   one-shot played on a wrong input / timer expiry.
--
-- Leave Click/Correct/Wrong as nil → falls back to Default per-position sounds.

local SoundConfig = {}

-- Display order in the shop
SoundConfig.Order = { "Default", "Piano", "Osu", "Typewriter", "VineBoom" }

SoundConfig.Packs = {

	-- ── FREE ──────────────────────────────────────────────────────────────────

	Default = {
		Name        = "Default",
		Price       = 0,
		Icon        = "🎵",
		Color       = Color3.fromRGB(200, 200, 200),
		Description = "Original per-note sequence sounds",
		-- nil = use per-position SequenceSounds (original behaviour)
		Click   = nil,
		Correct = nil,
		Wrong   = "rbxassetid://2979857617",  -- incorrect
	},

	-- ── TIER 1 (75 coins) ─────────────────────────────────────────────────────

	Piano = {
		Name        = "Piano",
		Price       = 150,
		Icon        = "🎹",
		Color       = Color3.fromRGB(255, 220, 150),
		Description = "Smooth piano key taps",
		Click   = "rbxassetid://140142170634722",  -- piano note
		Correct = "rbxassetid://140142170634722",  -- piano note (high pitch)
		Wrong   = "rbxassetid://2979857617",  -- incorrect
	},

	Osu = {
		Name        = "Osu!",
		Price       = 150,
		Icon        = "⭕",
		Color       = Color3.fromRGB(255, 100, 200),
		Description = "The iconic osu! hit circle sound",
		Click   = "rbxassetid://7147454322",  -- osu! hitsound
		Correct = "rbxassetid://7147454322",  -- same, high pitch
		Wrong   = "rbxassetid://2979857617",  -- incorrect
	},

	-- ── TIER 2 (125 coins) ────────────────────────────────────────────────────

	Typewriter = {
		Name        = "Typewriter",
		Price       = 250,
		Icon        = "⌨️",
		Color       = Color3.fromRGB(180, 220, 255),
		Description = "Satisfying mechanical keyboard clicks",
		Click   = "rbxassetid://88849202777032",  -- typewriter click
		Correct = "rbxassetid://88849202777032",  -- same, high pitch
		Wrong   = "rbxassetid://2979857617",  -- incorrect
	},

	-- ── TIER 3 (200 coins) ─────────────────────────────────────────────────────

	VineBoom = {
		Name        = "Vine Boom",
		Price       = 400,
		Icon        = "💥",
		Color       = Color3.fromRGB(255, 80, 80),
		Description = "Every click is a BOOM. You're welcome.",
		Click   = "rbxassetid://7147226095",  -- vine boom (pitched per position)
		Correct = "rbxassetid://7147484622",  -- vine boom HD (CORRECT)
		Wrong   = "rbxassetid://5044897021",  -- bruh
	},
}

return SoundConfig
