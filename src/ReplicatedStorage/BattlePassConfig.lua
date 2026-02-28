-- BattlePassConfig.lua
-- All Battle Pass constants: season, tiers, XP sources, and rewards.

local BattlePassConfig = {}

-- ── Season ─────────────────────────────────────────────────────────────────
-- Increment this number to start a new season (resets all player progress).
BattlePassConfig.SEASON       = 1
BattlePassConfig.MAX_TIERS    = 30
BattlePassConfig.XP_PER_TIER  = 500

-- Developer Product ID for the premium pass (399 R$).
-- TODO: Create a Developer Product at create.roblox.com → Monetization → Developer Products
--       then paste the numeric ID here. Set to 0 to hide the buy button.
BattlePassConfig.PREMIUM_PRODUCT_ID = 3546780752
BattlePassConfig.PREMIUM_ROBUX      = 399

-- ── XP Sources ─────────────────────────────────────────────────────────────
BattlePassConfig.XP = {
	WIN_1V1       = 100,
	LOSS_1V1      = 30,
	QUEST_CLAIMED = 150,
	SOLO_PLAYED   = 25,
}

-- ── Tier Rewards ───────────────────────────────────────────────────────────
-- Each tier: free track always gives coins.
-- Premium track gives more coins and exclusive titles at key tiers.
-- title key must match an entry in TitleConfig.Titles.
BattlePassConfig.TIERS = {
	[1]  = { free = {coins=25},  premium = {coins=50}  },
	[2]  = { free = {coins=25},  premium = {coins=50}  },
	[3]  = { free = {coins=50},  premium = {coins=75}  },
	[4]  = { free = {coins=50},  premium = {coins=75}  },
	[5]  = { free = {coins=100}, premium = {coins=100, title="SeasonRookie"} },

	[6]  = { free = {coins=25},  premium = {coins=75}  },
	[7]  = { free = {coins=25},  premium = {coins=75}  },
	[8]  = { free = {coins=50},  premium = {coins=100} },
	[9]  = { free = {coins=50},  premium = {coins=100} },
	[10] = { free = {coins=150}, premium = {coins=200, title="Tactician"} },

	[11] = { free = {coins=25},  premium = {coins=100} },
	[12] = { free = {coins=50},  premium = {coins=100} },
	[13] = { free = {coins=50},  premium = {coins=125} },
	[14] = { free = {coins=75},  premium = {coins=125} },
	[15] = { free = {coins=200}, premium = {coins=300} },

	[16] = { free = {coins=50},  premium = {coins=125} },
	[17] = { free = {coins=75},  premium = {coins=150} },
	[18] = { free = {coins=75},  premium = {coins=150} },
	[19] = { free = {coins=100}, premium = {coins=175} },
	[20] = { free = {coins=250}, premium = {coins=400, title="EliteTactician"} },

	[21] = { free = {coins=75},  premium = {coins=175} },
	[22] = { free = {coins=100}, premium = {coins=200} },
	[23] = { free = {coins=100}, premium = {coins=200} },
	[24] = { free = {coins=150}, premium = {coins=250} },
	[25] = { free = {coins=300}, premium = {coins=500} },

	[26] = { free = {coins=100}, premium = {coins=250} },
	[27] = { free = {coins=150}, premium = {coins=250} },
	[28] = { free = {coins=150}, premium = {coins=300} },
	[29] = { free = {coins=200}, premium = {coins=300} },
	[30] = { free = {coins=500}, premium = {coins=750, title="SeasonVeteran"} },
}

-- Derive current tier from total XP (0-indexed: 0 = no tier reached yet)
function BattlePassConfig.GetTier(xp: number): number
	return math.min(math.floor(xp / BattlePassConfig.XP_PER_TIER), BattlePassConfig.MAX_TIERS)
end

-- XP needed to reach the next tier
function BattlePassConfig.XPToNextTier(xp: number): number
	local tier = BattlePassConfig.GetTier(xp)
	if tier >= BattlePassConfig.MAX_TIERS then return 0 end
	return BattlePassConfig.XP_PER_TIER - (xp % BattlePassConfig.XP_PER_TIER)
end

return BattlePassConfig
