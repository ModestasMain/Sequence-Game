-- ThemeConfig.lua
-- Defines all purchasable UI themes for the sequence game board.
--
-- SquareIcon: Unicode character shown as a semi-transparent overlay on each grid square.
--   Tinted with Colors.Highlight so it blends with the theme palette.
--   Set to "" for flat color only (Default theme).
--
-- Sounds.Click:   single sound played on every square click; pitch varies by grid position.
-- Sounds.Correct: played when the player completes a correct sequence.
-- Sounds.Wrong:   played on a wrong input.
--   Find free audio in the Creator Marketplace (search terms noted per theme).
--   Leave "" to use no theme sound for that event.

local ThemeConfig = {}

-- Display order in the shop
ThemeConfig.Order = {"Default", "Ocean", "Forest", "Neon", "Sunset", "Ice", "Candy", "Lava", "Galaxy"}

ThemeConfig.Themes = {

	-- ── FREE ──────────────────────────────────────────────────────────────────

	Default = {
		Name        = "Default",
		Price       = 0,
		SquareIcon  = "",     -- no overlay; flat color only
		Sounds      = nil,    -- uses original per-position sounds from SequenceSounds
		Colors = {
			Panel      = Color3.fromRGB(30, 30, 30),
			Square     = Color3.fromRGB(50, 50, 50),
			Highlight  = Color3.fromRGB(255, 255, 100),
			Active     = Color3.fromRGB(100, 255, 100),
			Wrong      = Color3.fromRGB(255, 50, 50),
			HeartAlive = Color3.fromRGB(255, 68, 102),
			HeartDead  = Color3.fromRGB(80, 80, 80),
		},
	},

	-- ── TIER 1 (400 coins) ────────────────────────────────────────────────────

	Ocean = {
		Name        = "Ocean",
		Price       = 400,
		SquareIcon  = "◇",   -- white diamond — water-drop/wave shape
		Sounds = {
			Click   = "",   -- search: "water drop" / "water drip" audio
			Correct = "",   -- search: "ocean wave" / "water success" audio
			Wrong   = "",   -- search: "underwater bubble" / "splash" audio
		},
		Colors = {
			Panel      = Color3.fromRGB(10, 25, 50),
			Square     = Color3.fromRGB(20, 60, 100),
			Highlight  = Color3.fromRGB(0, 220, 255),
			Active     = Color3.fromRGB(0, 200, 180),
			Wrong      = Color3.fromRGB(255, 80, 80),
			HeartAlive = Color3.fromRGB(0, 200, 255),
			HeartDead  = Color3.fromRGB(40, 60, 80),
		},
	},

	Forest = {
		Name        = "Forest",
		Price       = 400,
		SquareIcon  = "✿",   -- florette — leaf/flower shape
		Sounds = {
			Click   = "",   -- search: "wood knock" / "leaf rustle" audio
			Correct = "",   -- search: "birds chirping" / "nature success" audio
			Wrong   = "",   -- search: "branch snap" / "nature error" audio
		},
		Colors = {
			Panel      = Color3.fromRGB(12, 28, 12),
			Square     = Color3.fromRGB(28, 58, 22),
			Highlight  = Color3.fromRGB(100, 220, 50),
			Active     = Color3.fromRGB(170, 255, 60),
			Wrong      = Color3.fromRGB(210, 60, 40),
			HeartAlive = Color3.fromRGB(80, 210, 80),
			HeartDead  = Color3.fromRGB(35, 55, 30),
		},
	},

	-- ── TIER 2 (550 coins) ────────────────────────────────────────────────────

	Neon = {
		Name        = "Neon",
		Price       = 550,
		SquareIcon  = "◈",   -- diamond circuit — electric/cyberpunk
		Sounds = {
			Click   = "",   -- search: "synth beep" / "electronic click" audio
			Correct = "",   -- search: "synth success" / "electric chime" audio
			Wrong   = "",   -- search: "electric zap" / "synth error" audio
		},
		Colors = {
			Panel      = Color3.fromRGB(2, 0, 8),
			Square     = Color3.fromRGB(10, 0, 28),
			Highlight  = Color3.fromRGB(0, 255, 200),
			Active     = Color3.fromRGB(255, 0, 220),
			Wrong      = Color3.fromRGB(0, 255, 80),
			HeartAlive = Color3.fromRGB(0, 200, 255),
			HeartDead  = Color3.fromRGB(20, 5, 40),
		},
	},

	Sunset = {
		Name        = "Sunset",
		Price       = 550,
		SquareIcon  = "★",   -- classic star — sun/warmth
		Sounds = {
			Click   = "",   -- search: "marimba note" / "xylophone tap" audio
			Correct = "",   -- search: "warm chime" / "marimba success" audio
			Wrong   = "",   -- search: "low thud" / "error drum" audio
		},
		Colors = {
			Panel      = Color3.fromRGB(40, 15, 5),
			Square     = Color3.fromRGB(80, 35, 10),
			Highlight  = Color3.fromRGB(255, 140, 0),
			Active     = Color3.fromRGB(255, 200, 0),
			Wrong      = Color3.fromRGB(200, 0, 50),
			HeartAlive = Color3.fromRGB(255, 100, 50),
			HeartDead  = Color3.fromRGB(60, 30, 20),
		},
	},

	-- ── TIER 3 (750 coins) ────────────────────────────────────────────────────

	Ice = {
		Name        = "Ice",
		Price       = 750,
		SquareIcon  = "◎",   -- concentric rings — frozen crystal/ice core
		Sounds = {
			Click   = "",   -- search: "crystal ping" / "glass tap" audio
			Correct = "",   -- search: "ice chime" / "glass bell success" audio
			Wrong   = "",   -- search: "ice crack" / "glass shatter" audio
		},
		Colors = {
			Panel      = Color3.fromRGB(0, 4, 18),
			Square     = Color3.fromRGB(5, 18, 55),
			Highlight  = Color3.fromRGB(190, 235, 255),
			Active     = Color3.fromRGB(255, 255, 255),
			Wrong      = Color3.fromRGB(255, 20, 110),
			HeartAlive = Color3.fromRGB(110, 195, 255),
			HeartDead  = Color3.fromRGB(10, 30, 70),
		},
	},

	Candy = {
		Name        = "Candy",
		Price       = 750,
		SquareIcon  = "❀",   -- white florette — sweet/bubblegum
		Sounds = {
			Click   = "",   -- search: "pop bubble" / "candy click" audio
			Correct = "",   -- search: "cute jingle" / "sweet success" audio
			Wrong   = "",   -- search: "cartoon boing" / "cute error" audio
		},
		Colors = {
			Panel      = Color3.fromRGB(35, 10, 35),
			Square     = Color3.fromRGB(130, 35, 95),
			Highlight  = Color3.fromRGB(255, 100, 210),
			Active     = Color3.fromRGB(255, 60, 190),
			Wrong      = Color3.fromRGB(0, 220, 220),
			HeartAlive = Color3.fromRGB(255, 130, 190),
			HeartDead  = Color3.fromRGB(60, 25, 55),
		},
	},

	-- ── TIER 4 (900-1200 coins) ──────────────────────────────────────────────

	Lava = {
		Name        = "Lava",
		Price       = 900,
		SquareIcon  = "▲",   -- volcanic triangle — eruption/magma
		Sounds = {
			Click   = "",   -- search: "fire crackle" / "ember pop" audio
			Correct = "",   -- search: "fire roar" / "lava rumble success" audio
			Wrong   = "",   -- search: "explosion rumble" / "fire error" audio
		},
		Colors = {
			Panel      = Color3.fromRGB(5, 0, 0),
			Square     = Color3.fromRGB(38, 5, 0),
			Highlight  = Color3.fromRGB(255, 115, 0),
			Active     = Color3.fromRGB(255, 230, 0),
			Wrong      = Color3.fromRGB(255, 0, 20),
			HeartAlive = Color3.fromRGB(255, 85, 0),
			HeartDead  = Color3.fromRGB(42, 8, 0),
		},
	},

	Galaxy = {
		Name        = "Galaxy",
		Price       = 1200,
		SquareIcon  = "◉",   -- planetary eye — cosmic void/nebula core
		Sounds = {
			Click   = "",   -- search: "space blip" / "cosmic click" audio
			Correct = "",   -- search: "space success" / "cosmic chime" audio
			Wrong   = "",   -- search: "space error" / "cosmic buzz" audio
		},
		Colors = {
			Panel      = Color3.fromRGB(1, 0, 8),
			Square     = Color3.fromRGB(8, 2, 32),
			Highlight  = Color3.fromRGB(155, 0, 255),
			Active     = Color3.fromRGB(255, 80, 255),
			Wrong      = Color3.fromRGB(255, 25, 75),
			HeartAlive = Color3.fromRGB(175, 55, 255),
			HeartDead  = Color3.fromRGB(14, 4, 48),
		},
	},
}

return ThemeConfig
