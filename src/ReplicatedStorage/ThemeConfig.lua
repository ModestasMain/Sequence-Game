-- ThemeConfig.lua
-- Defines all purchasable UI themes for the sequence game board

local ThemeConfig = {}

-- Display order in the shop
ThemeConfig.Order = {"Default", "Ocean", "Neon", "Sunset", "Ice"}

ThemeConfig.Themes = {
	Default = {
		Name  = "Default",
		Price = 0,
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

	Ocean = {
		Name  = "Ocean",
		Price = 150,
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

	Neon = {
		Name  = "Neon",
		Price = 200,
		Colors = {
			Panel      = Color3.fromRGB(10, 0, 20),
			Square     = Color3.fromRGB(30, 10, 50),
			Highlight  = Color3.fromRGB(200, 0, 255),
			Active     = Color3.fromRGB(255, 0, 150),
			Wrong      = Color3.fromRGB(0, 255, 80),
			HeartAlive = Color3.fromRGB(255, 0, 200),
			HeartDead  = Color3.fromRGB(50, 20, 60),
		},
	},

	Sunset = {
		Name  = "Sunset",
		Price = 200,
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

	Ice = {
		Name  = "Ice",
		Price = 300,
		Colors = {
			Panel      = Color3.fromRGB(15, 20, 40),
			Square     = Color3.fromRGB(40, 55, 90),
			Highlight  = Color3.fromRGB(140, 210, 255),
			Active     = Color3.fromRGB(200, 240, 255),
			Wrong      = Color3.fromRGB(255, 100, 200),
			HeartAlive = Color3.fromRGB(100, 200, 255),
			HeartDead  = Color3.fromRGB(40, 55, 80),
		},
	},
}

return ThemeConfig
