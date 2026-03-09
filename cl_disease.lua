--[[
    plugins/needs_system/sh/sh_needs.lua
    NEEDS SYSTEM - Hunger / Thirst / Fatigue / Stress
    ============================================================
    Tracks four survival needs for all characters.
    Values range from 0 to 100.
    At 0: debuffs activate (slowdown, HP drain, UI warnings).
    At 100: fully satisfied.
    Configurable severity and rate — can be disabled per server.
    ============================================================
--]]

HL2RP.Needs = HL2RP.Needs or {}

-- Need definitions: key, display name, icon color, drain rate per minute
HL2RP.Needs.Types = {
    { key = "hunger",  label = "Nutrition",  color = Color(220, 160, 80),  configRate = "hungerRate",  min = 0, max = 100 },
    { key = "thirst",  label = "Hydration",  color = Color(80, 180, 220),  configRate = "thirstRate",  min = 0, max = 100 },
    { key = "fatigue", label = "Fatigue",    color = Color(140, 120, 200), configRate = "fatigueRate", min = 0, max = 100, invert = true },
    { key = "stress",  label = "Stress",     color = Color(200, 80, 80),   configRate = "stressRate",  min = 0, max = 100, invert = true },
}

-- Debuff thresholds
HL2RP.Needs.DebuffThresholds = {
    hunger  = { warn = 25, severe = 10, critical = 0 },
    thirst  = { warn = 20, severe = 10, critical = 0 },
    fatigue = { warn = 75, severe = 90, critical = 100 },  -- Inverted
    stress  = { warn = 70, severe = 85, critical = 100 },
}
