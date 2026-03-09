--[[
    factions/sh_cwu.lua
    FACTION: Civil Workers' Union (CWU)
    ============================================================
    The organized labor force under Combine sanction. CWU
    workers are given work permits, modest salaries, and
    slightly better rations in exchange for loyalty and
    productivity. They run city services, distribute goods,
    and maintain infrastructure. Middle ground between
    full citizen and collaborator.
    ============================================================
--]]
if SERVER then

FACTION.name        = "Civil Workers' Union"
FACTION.desc        = "The sanctioned labor organization of City 45. CWU members operate city services, distribute rations, and keep the infrastructure functioning under Combine oversight."
FACTION.color       = Color(210, 170, 60)
FACTION.isDefault   = false
FACTION.isPublic    = true          -- Open application, no strict whitelist
FACTION.whitelist   = false
FACTION.pay         = 60
FACTION.payLimit    = 0

FACTION.models = {
    "models/humans/group01/male_01.mdl",
    "models/humans/group01/male_02.mdl",
    "models/humans/group01/male_03.mdl",
    "models/humans/group01/male_07.mdl",
    "models/humans/group01/female_01.mdl",
    "models/humans/group01/female_04.mdl",
}

FACTION.ranks = {
    [1] = { name = "Worker",             pay = 50,  taskMultiplier = 1.0,  description = "Entry level. Basic labor tasks." },
    [2] = { name = "Certified Worker",   pay = 70,  taskMultiplier = 1.2,  description = "Passed basic training. More task options." },
    [3] = { name = "Shift Supervisor",   pay = 100, taskMultiplier = 1.4,  description = "Oversees a work shift. Can assign basic tasks." },
    [4] = { name = "Administrator",      pay = 140, taskMultiplier = 1.6,  description = "CWU management. Access to permit office functions." },
    [5] = { name = "Senior Administrator",pay= 190, taskMultiplier = 2.0,  description = "Top CWU rank. Liaises with City Bureau." },
}

FACTION.uniformRequired    = true
FACTION.canAccessTaskBoard = true
FACTION.canIssueWorkPermits= true    -- Administrator rank and above
FACTION.subjectToCurfew    = false   -- Work shifts may run past curfew
FACTION.extraRationAllocation = 1    -- +1 ration per cycle

function FACTION:GetDefaultItems()
    return { "cwu_uniform", "cwu_id_card", "work_permit", "task_clipboard" }
end

end -- SERVER block end (illustrative — in real NS all files are shared unless in sv/cl subfolder)

--[[
    factions/sh_loyalist.lua
    FACTION: Loyalist
    ============================================================
    Citizens who have chosen to collaborate with the Combine
    in exchange for privilege. They act as informers, assist
    CP, and enjoy better rations and city access. Distrusted
    by other citizens. A morally grey faction.
    ============================================================
--]]

FACTION = FACTION or {}  -- Reset for separate file use in practice

FACTION.name        = "Loyalist"
FACTION.desc        = "A citizen who has formally aligned with the Combine administration. Loyalists enjoy elevated privileges at the cost of trust from their peers."
FACTION.color       = Color(200, 220, 140)
FACTION.isDefault   = false
FACTION.isPublic    = true
FACTION.whitelist   = false
FACTION.pay         = 90

FACTION.ranks = {
    [1] = { name = "Loyalist",           loyaltyReq = 50  },
    [2] = { name = "Senior Loyalist",    loyaltyReq = 75  },
    [3] = { name = "City Informant",     loyaltyReq = 90, canFileCitizenReport = true },
}

FACTION.canReportCitizens   = true
FACTION.canAccessCPScanner  = false   -- Not a CP; can assist but not act independently
FACTION.betterRationTier    = "standard_plus"
FACTION.extraSectorAccess   = { "LOYALIST_LOUNGE", "RATION_PRIORITY_LINE" }

FACTION.models = {
    "models/humans/group01/male_04.mdl",
    "models/humans/group01/male_09.mdl",
    "models/humans/group01/female_02.mdl",
    "models/humans/group01/female_05.mdl",
}

function FACTION:GetDefaultItems()
    return { "loyalist_badge", "id_card", "ration_card_plus" }
end

--[[
    factions/sh_vortigaunt.lua
    FACTION: Vortigaunt
    ============================================================
    Former slaves of the Combine, now cautious allies of the
    resistance and neutral parties in the city. Vortigaunts
    possess unique biological abilities—healing, energy
    manipulation—and carry deep spiritual RP flavor.
    ============================================================
--]]

FACTION.name        = "Vortigaunt"
FACTION.desc        = "Alien beings of deep spiritual and biological power. The Vortigaunts navigate City 45 as perpetual outsiders, offering healing and wisdom to those they trust."
FACTION.color       = Color(80, 200, 130)
FACTION.isDefault   = false
FACTION.isPublic    = false
FACTION.whitelist   = true
FACTION.pay         = 0

FACTION.models = {
    "models/vortigaunt_slave.mdl",
    "models/vortigaunt_slave2.mdl",
}

FACTION.ranks = {
    [1] = { name = "Bound",       description = "Under restrictive city registration." },
    [2] = { name = "Free",        description = "Has earned limited city movement rights." },
    [3] = { name = "Resonant",    description = "Trusted by resistance and respected by aware citizens." },
    [4] = { name = "Elder Vort",  description = "A elder figure. Spiritual authority and deep knowledge.", isElite = true },
}

FACTION.specialAbilities = {
    "vort_heal",          -- Can heal allies using vort energy (limited use, cooldown)
    "vort_zap",           -- Electrical shock ability (self-defense)
    "vort_sense",         -- Can sense nearby contraband / hidden players (minor)
    "vort_ritual",        -- Extended emote ritual with visible particle effects
}

FACTION.speechStyle     = "vort"      -- Triggers Vortigaunt speech formatting in chat
FACTION.subjectToLabor  = true        -- Combine still tries to press Vorts into labor
FACTION.resistanceAligned = true      -- Naturally sympathetic to resistance

function FACTION:GetDefaultItems()
    return { "vort_bio_cell", "vort_satchel" }
end

--[[
    factions/sh_smuggler.lua
    FACTION: Black Market Operative
--]]

FACTION.name        = "Black Market Operative"
FACTION.desc        = "A smuggler operating in the grey and black markets of City 45. Supplies contraband, forged papers, and illegal goods to those willing to pay."
FACTION.color       = Color(140, 80, 180)
FACTION.isDefault   = false
FACTION.isPublic    = false
FACTION.whitelist   = true
FACTION.pay         = 0   -- Earns from trade only

FACTION.ranks = {
    [1] = { name = "Peddler",   description = "Small-time dealer. Limited contacts." },
    [2] = { name = "Dealer",    description = "Established network. Mid-tier goods access." },
    [3] = { name = "Broker",    description = "Runs a regular operation. Can fence higher-tier items." },
    [4] = { name = "Kingpin",   description = "Controls supply routes. Elite contraband access.", isElite = true },
}

FACTION.hiddenFaction      = true
FACTION.showAsCitizen      = true
FACTION.canRunBlackMarket  = true
FACTION.canFenceItems      = true
FACTION.blackMarketSlots   = 12       -- Vendor inventory size

function FACTION:GetDefaultItems()
    return { "fake_id_card", "lockpick_set", "smuggler_satchel" }
end

--[[
    factions/sh_medic.lua
    FACTION: Civil Medical Authority
--]]

FACTION.name        = "Civil Medical Authority"
FACTION.desc        = "Government-sanctioned medical personnel. Provides healthcare to citizens under Combine administrative oversight."
FACTION.color       = Color(220, 220, 255)
FACTION.isDefault   = false
FACTION.isPublic    = true
FACTION.whitelist   = false
FACTION.pay         = 110

FACTION.ranks = {
    [1] = { name = "Orderly",          pay = 80,  canUseAdvancedMeds = false },
    [2] = { name = "Medic",            pay = 110, canUseAdvancedMeds = true  },
    [3] = { name = "Senior Medic",     pay = 150, canPerformSurgery  = true  },
    [4] = { name = "Chief Physician",  pay = 200, canIssuemedicalPermits = true },
}

FACTION.canIssuemedicalPermit = true
FACTION.canAccessMedBay       = true
FACTION.extraMedSupplies      = true

function FACTION:GetDefaultItems()
    return { "medic_kit", "medical_permit", "medic_uniform", "medic_scanner" }
end

--[[
    factions/sh_admin_bureau.lua
    FACTION: City Administration Bureau
--]]

FACTION.name        = "City Administration Bureau"
FACTION.desc        = "The civilian-facing administrative arm of Combine governance. Handles permits, housing, data records, and civil compliance enforcement."
FACTION.color       = Color(240, 230, 180)
FACTION.isDefault   = false
FACTION.isPublic    = false
FACTION.whitelist   = true
FACTION.pay         = 170

FACTION.ranks = {
    [1] = { name = "Clerk",             pay = 120, canEditPermits = false },
    [2] = { name = "Senior Clerk",      pay = 150, canEditPermits = true  },
    [3] = { name = "Bureau Officer",    pay = 190, canEditDatafiles = true },
    [4] = { name = "Director",          pay = 250, canPromoteClerks = true, canFlagAntiCitizen = true },
}

FACTION.canIssuePermits         = true
FACTION.canEditCitizenRecords   = true
FACTION.canManageHousing        = true
FACTION.canAccessAllDatafiles   = true

function FACTION:GetDefaultItems()
    return { "bureau_id", "permit_printer", "datafile_tablet" }
end
