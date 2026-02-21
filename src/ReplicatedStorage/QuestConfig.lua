-- QuestConfig.lua
-- Defines the daily quests. Shared between client and server.

local QuestConfig = {}

QuestConfig.RESET_INTERVAL = 86400 -- 24 hours in seconds

QuestConfig.QUESTS = {
	{ type = "play_solo",   name = "Solo Run",      desc = "Play 1 solo game",          target = 1,  reward = 25  },
	{ type = "play_1v1",    name = "Competitor",    desc = "Play 3 1v1 matches",         target = 3,  reward = 50  },
	{ type = "win_1v1",     name = "Victorious",    desc = "Win 5 1v1 matches",          target = 5,  reward = 100 },
	{ type = "solo_seq_8",  name = "Sharp Mind",    desc = "Reach sequence 8 in Solo",   target = 8,  reward = 60  },
	{ type = "solo_seq_12", name = "Deep Memory",   desc = "Reach sequence 12 in Solo",  target = 12, reward = 100 },
}

return QuestConfig
