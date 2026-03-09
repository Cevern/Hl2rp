--[[
    config/sh_config.lua
    Master configuration file for City 45 HL2RP
    All gameplay-tuning values live here. Edit freely.
--]]

local Config = nut.config

-- ============================================================
-- ECONOMY
-- ============================================================
Config.set("startingCredits",       50,    "Starting credits for new characters.")
Config.set("maxCredits",            99999, "Maximum credits a character can hold.")
Config.set("creditName",            "tokens", "In-universe currency name.")
Config.set("salaryInterval",        300,   "Seconds between salary payouts.")
Config.set("taxRate",               0.05,  "Fraction of salary taken as tax for govt faction.")
Config.set("blackMarketMarkup",     1.75,  "Price multiplier for black market items.")
Config.set("rationTokenValue",      5,     "Credit value of one ration token.")

-- ============================================================
-- NEEDS SYSTEM
-- ============================================================
Config.set("needsEnabled",          true,  "Enable hunger/thirst/fatigue system.")
Config.set("hungerRate",            0.5,   "Hunger loss per minute (0–100 scale).")
Config.set("thirstRate",            0.8,   "Thirst loss per minute.")
Config.set("fatigueRate",           0.3,   "Fatigue gain per minute.")
Config.set("stressRate",            0.2,   "Stress gain per minute under suppression events.")
Config.set("needsHUDAlpha",         200,   "HUD panel alpha for needs display.")
Config.set("starvationDamage",      1,     "HP loss per tick when hunger = 0.")
Config.set("dehydrationDamage",     2,     "HP loss per tick when thirst = 0.")

-- ============================================================
-- PERMITS & PAPERS
-- ============================================================
Config.set("permitExpiry",          72,    "Hours until permits expire (0 = never).")
Config.set("forgeryDetectChance",   0.25,  "Chance (0–1) that a forged doc is detected on inspection.")
Config.set("rationCycleHours",      24,    "Hours between ration distribution cycles.")

-- ============================================================
-- TENSION METER
-- ============================================================
Config.set("tensionMax",            100,   "Maximum tension value.")
Config.set("tensionDecayRate",      0.5,   "Tension decay per minute when calm.")
Config.set("tensionCrimeGain",      5,     "Tension gain per criminal act detected.")
Config.set("tensionSabotageGain",   15,    "Tension gain from resistance sabotage.")
Config.set("tensionLockdownThresh", 80,    "Tension level that triggers district lockdown.")
Config.set("tensionOTAThresh",      90,    "Tension level that triggers OTA deployment alert.")

-- ============================================================
-- CITY EVENTS
-- ============================================================
Config.set("eventInterval",         600,   "Minimum seconds between random world events.")
Config.set("eventVariance",         300,   "Random seconds added to event interval.")
Config.set("maxActiveEvents",       3,     "Max concurrent active events.")

-- ============================================================
-- APARTMENTS
-- ============================================================
Config.set("apartmentRent",         20,    "Credits deducted per rent cycle.")
Config.set("rentCycleHours",        48,    "Hours between rent deductions.")
Config.set("evictionGracePeriod",   1,     "Rent cycles before eviction for non-payment.")
Config.set("maxRoomates",           3,     "Max characters sharing one apartment.")
Config.set("hiddenStashDetectChance", 0.15,"Chance a stash is found during apartment search.")

-- ============================================================
-- COMBAT & WEAPONS
-- ============================================================
Config.set("civilianWeaponsAllowed", false,"Allow civilians to carry weapons without permits.")
Config.set("melee_damage_mult",      1.0,  "Damage multiplier for melee weapons.")
Config.set("combatLogTimeout",       10,   "Seconds after last damage before combat log clears.")

-- ============================================================
-- PROGRESSION
-- ============================================================
Config.set("promotionCooldown",      86400, "Seconds between rank promotions (24h default).")
Config.set("loyaltyGainRate",        1,     "Loyalty points gained per compliant interaction.")
Config.set("loyaltyLossRate",        5,     "Loyalty points lost per violation.")
Config.set("suspicionDecayRate",     2,     "Resistance suspicion decay per hour offline.")

-- ============================================================
-- SUPPORTER / DONOR
-- ============================================================
Config.set("supporterExtraCharSlots", 1,   "Extra character slots for Supporter tier.")
Config.set("goldExtraCharSlots",      2,   "Extra character slots for Gold tier.")
Config.set("donorStorageBonus",       5,   "Extra inventory slots for donors (Gold+).")
Config.set("donorNameplateEnabled",   true,"Show supporter nameplate in OOC.")

-- ============================================================
-- RADIO
-- ============================================================
Config.set("radioRange",            600,   "Units range for handheld radio transmission.")
Config.set("combineEncryptionKey",  "CMBN-ALPHA-7", "Default Combine encryption prefix.")
Config.set("resistanceFreqRange",   true,  "Allow resistance to use hidden frequencies.")

-- ============================================================
-- GENERAL RP
-- ============================================================
Config.set("curfewStartHour",       22,    "In-game hour curfew begins (0–23).")
Config.set("curfewEndHour",         6,     "In-game hour curfew ends.")
Config.set("characterNameMin",      3,     "Min character name length.")
Config.set("characterNameMax",      48,    "Max character name length.")
Config.set("descMaxLength",         512,   "Max character description length.")
Config.set("meMaxLength",           256,   "Max /me action length.")
Config.set("oocCooldown",           5,     "OOC message cooldown in seconds.")
Config.set("serverTimezone",        "UTC", "Timezone label shown in server time displays.")
