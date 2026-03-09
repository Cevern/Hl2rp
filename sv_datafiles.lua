--[[
    factions/sh_cp.lua
    FACTION: Civil Protection (CP)
    ============================================================
    The front-line law enforcement arm of the Combine's urban
    control apparatus. CPs are former humans conscripted or
    seduced into service by the promise of better rations and
    protection. They enforce the rules, conduct arrests,
    administer the city, and serve as the visible face of
    Combine authority. Gameplay centers on patrol, enforcement,
    dispatch coordination, and career advancement.
    ============================================================
--]]

FACTION.name        = "Civil Protection"
FACTION.desc        = "City 45's front-line enforcement unit. Uphold Combine law, maintain order, and advance through the ranks by demonstrating loyalty and operational efficiency."
FACTION.color       = Color(60, 100, 160)
FACTION.isDefault   = false
FACTION.isPublic    = false         -- Requires admin whitelist
FACTION.whitelist   = true
FACTION.pay         = 80            -- Per salary cycle
FACTION.payLimit    = 0             -- Salaried; no cap restriction

FACTION.models = {
    "models/police.mdl",
    "models/combine_soldier.mdl",   -- Officer tier
}

-- ============================================================
-- RANK STRUCTURE
-- ============================================================
FACTION.ranks = {
    [1] = {
        name         = "Recruit (RCT)",
        pay          = 60,
        flags        = "",
        equipment    = {"stun_baton", "cp_radio"},
        description  = "Newly inducted CP unit. Limited authority. Under supervision.",
        reqPlaytime  = 0,
        reqCommends  = 0,
    },
    [2] = {
        name         = "Unit (OFC)",
        pay          = 80,
        flags        = "c",     -- Can carry sidearm
        equipment    = {"stun_baton", "cp_pistol", "cp_radio", "zipties"},
        description  = "Standard patrol officer. Can conduct searches and issue fines.",
        reqPlaytime  = 600,     -- 10h on-duty time
        reqCommends  = 1,
    },
    [3] = {
        name         = "Senior Unit (SECU)",
        pay          = 110,
        flags        = "cs",    -- Sidearm + shotgun clearance
        equipment    = {"stun_baton", "cp_pistol", "cp_shotgun", "cp_radio", "zipties", "evidence_bag"},
        description  = "Experienced unit with detain and evidence authority.",
        reqPlaytime  = 1800,
        reqCommends  = 3,
    },
    [4] = {
        name         = "Officer (OFCR)",
        pay          = 150,
        flags        = "csw",   -- Full standard loadout
        equipment    = {"stun_baton", "cp_pistol", "cp_smg", "cp_radio", "zipties", "evidence_bag", "warrant_pad"},
        description  = "Field officer with warrant and squad leadership capabilities.",
        reqPlaytime  = 3600,
        reqCommends  = 5,
        canIssueWarrant = true,
    },
    [5] = {
        name         = "Elite (ELT)",
        pay          = 200,
        flags        = "cswt",  -- + tactical tools
        equipment    = {"stun_baton", "cp_pistol", "cp_smg", "cp_radio", "zipties", "evidence_bag", "warrant_pad", "raid_kit"},
        description  = "Special operations officer. Can authorize raids and interface with OTA.",
        reqPlaytime  = 7200,
        reqCommends  = 8,
        canAuthorizeRaid = true,
    },
    [6] = {
        name         = "Grid Leader (GRID)",
        pay          = 280,
        flags        = "cswta", -- All CP flags
        equipment    = {"stun_baton", "cp_pistol", "cp_smg", "cp_radio", "zipties", "evidence_bag", "warrant_pad", "raid_kit", "sector_key"},
        description  = "Sector commander. Manages patrol assignments and liaises with OTA.",
        reqPlaytime  = 14400,
        reqCommends  = 12,
        canPromote   = true,    -- Can promote up to Senior Unit
        canAuthorizeRaid = true,
    },
}

-- ============================================================
-- CID TAG SYSTEM
-- Each CP unit gets a unique Combine Identification tag
-- ============================================================
FACTION.cidPrefix   = "CP-45-"      -- e.g. CP-45-0117

-- ============================================================
-- DISPATCH RADIO
-- ============================================================
FACTION.radioChannel     = "CP_DISPATCH"
FACTION.radioEncrypted   = true
FACTION.radioFrequency   = 147.5    -- Civilian scanners cannot reach this

-- ============================================================
-- SQUAD SYSTEM
-- ============================================================
FACTION.squads = {
    "Alpha",
    "Bravo",
    "Charlie",
    "Delta",
    "Echo",
    "Foxtrot",
}

-- ============================================================
-- ENFORCEMENT TOOLS
-- ============================================================
FACTION.canDetain        = true
FACTION.canSearch        = true
FACTION.canConfiscate    = true
FACTION.canArrest        = true
FACTION.canIssueWarrant  = true    -- OFC and above
FACTION.canAccessDatafile= true
FACTION.canEnterSectors  = { "CP_HQ", "DETENTION", "ARMORY" }

-- ============================================================
-- DISPATCH CODES
-- ============================================================
FACTION.dispatchCodes = {
    ["10-0"]  = "Officer needs assistance",
    ["10-1"]  = "Signal weak",
    ["10-4"]  = "Acknowledged",
    ["10-7"]  = "Off duty",
    ["10-8"]  = "On duty / in service",
    ["10-15"] = "Suspect in custody",
    ["10-20"] = "What is your location?",
    ["10-31"] = "Crime in progress",
    ["10-54"] = "Dead body reported",
    ["10-65"] = "Anti-citizen confirmed",
    ["10-90"] = "Contraband detected",
    ["CODE3"] = "Emergency response – lights and dispatch",
    ["CODE6"] = "Apartment inspection authorized",
    ["CODE7"] = "Curfew violation",
    ["CODE9"] = "Request OTA support",
}

-- ============================================================
-- RESTRICTED AREAS
-- CP can lock down and restrict access to areas
-- ============================================================
FACTION.lockdownCapability = true
FACTION.canIssueBOLO       = true

-- ============================================================
-- STARTING LOADOUT
-- ============================================================
function FACTION:GetDefaultItems()
    return {
        "cp_id_card",
        "cp_radio",
        "stun_baton",
        "arrest_report_pad",
        "zipties",
    }
end

-- ============================================================
-- ON SPAWN
-- ============================================================
function FACTION:OnSpawn(ply)
    local rankIdx = HL2RP.GetRankIndex(ply)
    local rank    = FACTION.ranks[rankIdx + 1] or FACTION.ranks[1]
    -- Give rank-appropriate equipment
    for _, item in ipairs(rank.equipment or {}) do
        ply:Give(item)
    end
    ply:SetArmor(50)
end

-- ============================================================
-- LOYALTY EVALUATION
-- CP can request loyalty interviews from citizens
-- Outcome affects citizen loyalty score
-- ============================================================
FACTION.canConductLoyaltyInterview = true
FACTION.loyaltyInterviewCooldown   = 3600  -- Once per character per hour
