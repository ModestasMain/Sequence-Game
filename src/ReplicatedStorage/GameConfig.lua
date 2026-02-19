-- GameConfig.lua
-- Configuration module for game settings

local GameConfig = {}

-- Game Settings
GameConfig.STARTING_LIVES = 3
GameConfig.GRID_SIZE = 3 -- 3x3 grid
GameConfig.SEQUENCE_DISPLAY_TIME = 0.5 -- seconds each square lights up
GameConfig.SEQUENCE_GAP_TIME = 0.2 -- seconds between squares
GameConfig.INPUT_TIMEOUT = 30 -- seconds to complete sequence

-- Rewards
GameConfig.WIN_COINS = 50
GameConfig.PARTICIPATION_COINS = 10
GameConfig.SOLO_CORRECT_COINS = 2

-- Lobby Settings
GameConfig.PLATFORM_WAIT_TIME = 3 -- seconds before game starts
GameConfig.PLAYERS_PER_GAME = 2

-- Colors
GameConfig.SQUARE_DEFAULT_COLOR = Color3.fromRGB(50, 50, 50)
GameConfig.SQUARE_HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 100)
GameConfig.SQUARE_ACTIVE_COLOR = Color3.fromRGB(100, 255, 100)
GameConfig.SQUARE_WRONG_COLOR = Color3.fromRGB(255, 50, 50)

return GameConfig
