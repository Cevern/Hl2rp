--[[
    factions/sh_resistance.lua
    FACTION: The Resistance
    ============================================================
    Underground network fighting back against the Combine.
    Resistance members operate covertly—most appear as ordinary
    citizens until activated. Gameplay emphasizes secrecy,
    trust networks, sabotage, intel gathering, contraband, and
    organized cell structure. High risk, high meaning.
    ============================================================
--]]

FACTION.name        = "Resistance"
FACTION.desc        = "A network of survivors and fighters operating in the shadows of City 45. Oppose Combine authority through intelligence, supply lines, and careful coordination."
FACTION.color       = Color(180, 80, 60)
FACTION.isDefault   = false
FACTION.isPublic    = false
FACTION.whitelist   = true
FACTION.pay         = 0             -- Resistance earns through tasks
FACTION.payLimit    = 500

-- Resistance members LOOK like citizens — they use citizen models
FACTION.models = {
    "models/humans/group01/male_01.mdl",
    "models/humans/group01/male_02.mdl",
    "models/humans/group01/male_03.mdl",
    "models/humans/group01/male_05.mdl",
    "models/humans/group01/male_07.mdl",
    "models/humans/group01/female_01.mdl",
    "models/humans/group01/female_03.mdl",
    "models/humans/group01/female_06.mdl",
}

FACTION.ranks = {
    [1] = {
        name        = "Contact",
        description = "Newly recruited sympathizer. Not yet trusted with operational knowledge.",
        access      = { deadDrops = false, safehouses = false, weapons = false },
        payPerMission = 20,
    },
    [2] = {
        name        = "Runner",
        description = "Trusted courier and logistics operative. Moves supplies and messages.",
        access      = { deadDrops = true, safehouses = false, weapons = false },
        payPerMission = 40,
    },
    [3] = {
        name        = "Cell Member",
        description = "Active resistance operative. Participates in operations and defends safe houses.",
        access      = { deadDrops = true, safehouses = true, weapons = true },
        payPerMission = 70,
    },
    [4] = {
        name        = "Operative",
        description = "Experienced operator trusted with sensitive intelligence and supply coordination.",
        access      = { deadDrops = true, safehouses = true, weapons = true, intel = true },
        payPerMission = 100,
    },
    [5] = {
        name        = "Cell Leader",
        description = "Commands a cell. Coordinates operations and recruits new contacts.",
        access      = { deadDrops = true, safehouses = true, weapons = true, intel = true, recruit = true },
        payPerMission = 150,
        canRecruit  = true,
    },
}

-- ============================================================
-- IDENTITY PROTECTION
-- ============================================================
FACTION.hiddenFaction       = true      -- Faction name hidden from /factioninfo
FACTION.showAsCitizen       = true      -- Appears as "Citizen" to non-resistance inspectors
FACTION.identityMaskable    = true      -- Can use disguise items

-- ============================================================
-- SUSPICION / HEAT SYSTEM
-- Resistance members accrue suspicion (0–100)
-- High suspicion increases CP patrol attention
-- ============================================================
FACTION.hasSuspicionMeter   = true
FACTION.suspicionThresholds = {
    [25]  = "You are drawing mild attention.",
    [50]  = "You are under passive surveillance.",
    [75]  = "You are a person of interest. Extreme caution advised.",
    [90]  = "You are marked as an anti-citizen. Remain hidden.",
    [100] = "You have been fully compromised. Immediate danger.",
}

-- ============================================================
-- RESISTANCE RADIO
-- ============================================================
FACTION.radioChannel     = "RESISTANCE_NET"
FACTION.radioEncrypted   = true
FACTION.radioFrequency   = 88.7         -- Secret frequency
FACTION.radioScrambled   = true         -- Audio is garbled to non-members

-- ============================================================
-- SAFEHOUSE SYSTEM
-- ============================================================
FACTION.canMarkSafehouses   = true      -- Cell Leaders can designate safehouses
FACTION.safehouseStorageSlots = 20      -- Communal storage in safehouses

-- ============================================================
-- CRAFTING BONUSES
-- ============================================================
FACTION.craftingBonus       = true      -- Resistance has access to makeshift weapon recipes

-- ============================================================
-- COVERT COMMUNICATION
-- ============================================================
FACTION.canLeaveDeadDrops   = true
FACTION.canSendEncryptedNotes = true

function FACTION:GetDefaultItems()
    return {
        "rebel_pamphlet",      -- Lore item; increases suspicion if found
        "encrypted_note_blank",
        "fake_id_card",        -- A forged civilian ID
    }
end

function FACTION:OnCharCreated(ply, character)
    character:SetVar("suspicion", 0)
    character:SetVar("cellID", nil)
    character:SetVar("missionCount", 0)
    character:SetVar("resistanceRep", 0)
end

function FACTION:OnSpawn(ply)
    -- Resistance starts with no visible weapons — they must acquire them
    ply:Give("hands")
end
