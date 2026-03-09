--[[
    HL2RP: CITY 45 - NutScript Schema
    ============================================================
    Theme:    Half-Life 2 Roleplay / Combine Occupation
    Engine:   Garry's Mod + NutScript Framework
    Author:   [Your Community Name]
    Version:  1.0.0
    ============================================================
    A fully custom, production-grade HL2RP schema featuring:
    - 12+ factions with rank ladders and whitelists
    - Deep citizen/CWU/CP/OTA/Resistance gameplay loops
    - Permit, datafile, and housing systems
    - Dynamic city tension meter and event framework
    - Black market, crafting, and contraband systems
    - Supporter/donor tiers with cosmetic-only perks
    - Comprehensive admin tooling and logging
    ============================================================
--]]

SCHEMA.name        = "City 45: Under Occupation"
SCHEMA.author      = "Your Community"
SCHEMA.desc        = "A gritty, immersive Half-Life 2 Roleplay server set in the occupied City 45. Survive, comply, or resist."
SCHEMA.version     = "1.0.0"
SCHEMA.steamgroup  = "" -- Fill in your Steam group ID
SCHEMA.discord     = "" -- Fill in your Discord invite
SCHEMA.website     = "" -- Fill in your website

-- Core plugin flags (set false to disable a module)
SCHEMA.modules = {
    needs_system       = true,   -- Hunger, thirst, fatigue, stress
    permits_papers     = true,   -- Document and permit system
    datafiles          = true,   -- Citizen record / datafile system
    apartments         = true,   -- Housing assignment and management
    economy            = true,   -- Credits, salaries, vendors
    black_market       = true,   -- Underground economy
    crafting           = true,   -- Salvage and crafting system
    cwu_labor          = true,   -- CWU task board and labor jobs
    dispatch           = true,   -- City announcements and CP dispatch
    arrests            = true,   -- CP enforcement / arrest system
    city_events        = true,   -- Dynamic world events
    tension_meter      = true,   -- Global city tension tracking
    radio_comms        = true,   -- Radio channels and comms
    progression        = true,   -- Rank/rep/loyalty progression
    supporter_donor    = true,   -- Supporter tier system
    reputation         = true,   -- Character reputation tracking
    resistance         = true,   -- Resistance-specific systems
    combine_systems    = true,   -- Combine-specific tools
    vortigaunt         = true,   -- Vortigaunt flavor and abilities
    civilian_depth     = true,   -- Extra citizen gameplay
    jobs_tasks         = true,   -- Task board system
    logging            = true,   -- Admin log system
    admin_tools        = true,   -- Extended admin utilities
}
