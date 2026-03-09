--[[
    factions/sh_citizen.lua
    FACTION: Citizens
    ============================================================
    The backbone of City 45. Citizens are the oppressed masses
    living under Combine rule. They must survive through ration
    allocation, work permits, and compliance—or risk being
    flagged as anti-citizens. Their gameplay centers on
    survival, social connection, labor, and a slow-burning
    choice between compliance and resistance.
    ============================================================
--]]

FACTION.name        = "Citizen"
FACTION.desc        = "A resident of City 45 living under Combine occupation. Survival requires compliance, resourcefulness, and knowing when to keep your head down."
FACTION.color       = Color(180, 190, 200)
FACTION.isDefault   = true
FACTION.isPublic    = true
FACTION.pay         = 0          -- Base salary (0 = no automatic salary; jobs give payouts)
FACTION.payLimit    = 200        -- Max credit payout from job tasks
FACTION.models      = {
    "models/humans/group01/male_01.mdl",
    "models/humans/group01/male_02.mdl",
    "models/humans/group01/male_03.mdl",
    "models/humans/group01/male_04.mdl",
    "models/humans/group01/male_05.mdl",
    "models/humans/group01/male_06.mdl",
    "models/humans/group01/male_07.mdl",
    "models/humans/group01/male_08.mdl",
    "models/humans/group01/male_09.mdl",
    "models/humans/group01/female_01.mdl",
    "models/humans/group01/female_02.mdl",
    "models/humans/group01/female_03.mdl",
    "models/humans/group01/female_04.mdl",
    "models/humans/group01/female_05.mdl",
    "models/humans/group01/female_06.mdl",
}

FACTION.defaultFlags  = ""           -- No special flags by default
FACTION.whitelist     = false         -- No whitelist required
FACTION.canWhitelist  = false

-- ============================================================
-- RANK STRUCTURE
-- Citizens don't have formal ranks, but track social standing.
-- ============================================================
FACTION.ranks = {
    { name = "Citizen",           loyaltyMin = 0   },
    { name = "Compliant Citizen", loyaltyMin = 25  },
    { name = "Model Citizen",     loyaltyMin = 75  },
}

-- ============================================================
-- STARTING LOADOUT
-- ============================================================
function FACTION:GetDefaultItems()
    return {
        "id_card",
        "ration_card",
    }
end

-- ============================================================
-- RESTRICTIONS
-- ============================================================
FACTION.canOwnWeapons    = false   -- Weapons require a restricted goods permit
FACTION.canEnterCP       = false   -- Cannot enter CP sectors without authorization
FACTION.subjectToCurfew  = true    -- Must obey curfew
FACTION.subjectToRations = true    -- Must use ration card for food

-- ============================================================
-- RELATIONS TO OTHER FACTIONS
-- ============================================================
FACTION.relations = {
    loyalist    = "cautious",      -- Informers; distrust but politeness
    cwu         = "neutral",       -- Fellow workers
    cp          = "fearful",       -- Authority with power over life
    ota         = "terrified",     -- Rarely seen, deeply feared
    resistance  = "sympathetic",   -- Many secretly support but are afraid
    vortigaunt  = "uncertain",     -- Strange and alien but not hostile
    smuggler    = "opportunistic", -- Access to food and contraband
    medic       = "trusting",      -- Healthcare providers
}

-- ============================================================
-- PROGRESSION PATH
-- Citizens can be recruited into:
--   CWU (labor / work permit path)
--   Resistance (underground path)
--   Loyalist (collaboration path)
--   Civil Medical (skill + application path)
-- ============================================================

-- ============================================================
-- FACTION HOOKS
-- ============================================================

function FACTION:OnCharCreated(ply, character)
    -- Give new citizens their basic papers
    character:SetVar("permits", {})
    character:SetVar("loyaltyScore", 10)
    character:SetVar("suspicion", 0)
    character:SetVar("rationStatus", "allocated")
    character:SetVar("crimeRecord", {})
    character:SetVar("apartmentID", nil)
    character:SetVar("employmentStatus", "unemployed")
end

function FACTION:OnSpawn(ply)
    -- Strip any leftover weapons (server ensures compliance)
    for _, w in ipairs(ply:GetWeapons()) do
        if not table.HasValue({"hands"}, w:GetClass()) then
            ply:StripWeapon(w:GetClass())
        end
    end
    ply:Give("hands")
end
