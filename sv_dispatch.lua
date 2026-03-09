--[[
    factions/sh_ota.lua
    FACTION: Overwatch Transhuman Arm (OTA)
    ============================================================
    The elite military wing of the Combine. OTA soldiers are
    heavily augmented, deployed only for high-priority threats.
    Strictly whitelisted. Event-driven deployment. These are
    not patrol officers—they are weapons.
    ============================================================
--]]

FACTION.name        = "Overwatch Transhuman Arm"
FACTION.desc        = "Elite Combine military unit. Deployed for high-priority engagements, resistance suppression, and critical infrastructure defense."
FACTION.color       = Color(40, 160, 100)
FACTION.isDefault   = false
FACTION.isPublic    = false
FACTION.whitelist   = true
FACTION.pay         = 400
FACTION.payLimit    = 0

FACTION.models = {
    "models/combine_soldier.mdl",
    "models/combine_super_soldier.mdl",
    "models/combine_soldier_prisonguard.mdl",
}

FACTION.ranks = {
    [1] = { name = "Transhuman (OTA-1)", pay = 300, equipment = {"ota_pulse_rifle", "ota_pistol", "ota_radio", "ota_armor"} },
    [2] = { name = "Specialist (OTA-2)", pay = 380, equipment = {"ota_pulse_rifle", "ota_pistol", "ota_radio", "ota_armor", "ota_scanner"} },
    [3] = { name = "Sergeant (OTA-3)",   pay = 450, equipment = {"ota_pulse_rifle", "ota_pistol", "ota_radio", "ota_heavy_armor", "ota_scanner", "ota_grenade"} },
    [4] = { name = "Commander (OTA-CMD)",pay = 600, equipment = {"ota_pulse_rifle", "ota_pistol", "ota_radio", "ota_heavy_armor", "ota_scanner", "ota_grenade", "ota_command_uplink"} },
}

FACTION.restrictions = {
    deployOnlyDuringEvents = true,       -- Must have admin/event authorization to deploy
    requiresEventActivation = true,
    canAccessAllSectors    = true,
    canOverrideCPOrders    = true,
    immuneToCurfew         = true,
    canExecuteAntiCitizens = true,       -- Lore-appropriate lethal force
}

FACTION.radioChannel   = "OTA_COMMAND"
FACTION.radioEncrypted = true
FACTION.voiceDistortion = true          -- HUD shows garbled voice effect

function FACTION:GetDefaultItems()
    return { "ota_id_uplink", "ota_radio" }
end

function FACTION:OnSpawn(ply)
    local rankIdx = HL2RP.GetRankIndex(ply)
    local rank    = FACTION.ranks[rankIdx + 1] or FACTION.ranks[1]
    for _, item in ipairs(rank.equipment or {}) do ply:Give(item) end
    ply:SetHealth(150)
    ply:SetArmor(100)
end
