--[[
    plugins/radio_comms/sh/sh_radio.lua
    RADIO & COMMUNICATIONS SYSTEM — Shared Definitions
    ============================================================
    Manages radio channels, frequencies, encryption,
    and communication tools across all factions.
    ============================================================
--]]

HL2RP.Radio = HL2RP.Radio or {}

-- ============================================================
-- CHANNEL DEFINITIONS
-- ============================================================

HL2RP.Radio.Channels = {
    -- Open civilian channels
    {
        id          = "OPEN_1",
        label       = "Open Channel 1",
        frequency   = 101.5,
        encrypted   = false,
        factionOnly = nil,
        color       = Color(180, 200, 180),
        description = "General open frequency. Anyone with a radio can listen.",
    },
    {
        id          = "OPEN_2",
        label       = "Open Channel 2",
        frequency   = 103.7,
        encrypted   = false,
        factionOnly = nil,
        color       = Color(180, 200, 180),
    },
    -- CP Dispatch
    {
        id          = "CP_DISPATCH",
        label       = "CP Dispatch",
        frequency   = 147.5,
        encrypted   = true,
        factionOnly = { "cp", "ota" },
        color       = Color(80, 140, 220),
        description = "Civil Protection encrypted dispatch. Monitored by Overwatch.",
    },
    -- OTA Command
    {
        id          = "OTA_COMMAND",
        label       = "OTA Command Net",
        frequency   = 162.3,
        encrypted   = true,
        factionOnly = { "ota" },
        color       = Color(60, 200, 120),
        description = "Overwatch Transhuman Arm command frequency.",
    },
    -- CWU Internal
    {
        id          = "CWU_INTERNAL",
        label       = "CWU Work Channel",
        frequency   = 108.0,
        encrypted   = false,
        factionOnly = { "cwu" },
        color       = Color(220, 200, 80),
        description = "Civil Workers Union internal coordination.",
    },
    -- Resistance (hidden)
    {
        id          = "RESISTANCE_NET",
        label       = "...",              -- Label hidden to non-members
        frequency   = 88.7,
        encrypted   = true,
        factionOnly = { "resistance" },
        hidden      = true,              -- Doesn't show in normal channel list
        color       = Color(200, 80, 80),
        scrambled   = true,              -- Appears as static to non-members
        description = "Resistance secure network. Do not broadcast location.",
    },
    -- Medical
    {
        id          = "MEDICAL_NET",
        label       = "Medical Emergency Net",
        frequency   = 121.5,
        encrypted   = false,
        factionOnly = { "medic", "cp" },
        color       = Color(200, 200, 255),
    },
    -- Bureau Admin
    {
        id          = "BUREAU_ADMIN",
        label       = "Bureau Administrative",
        frequency   = 155.0,
        encrypted   = true,
        factionOnly = { "admin_bureau", "cp" },
        color       = Color(240, 220, 140),
    },
}

-- Build lookup by ID
HL2RP.Radio.ChannelMap = {}
for _, ch in ipairs(HL2RP.Radio.Channels) do
    HL2RP.Radio.ChannelMap[ch.id] = ch
end

-- ============================================================
-- PLAYER RADIO STATE
-- Stored per-player: active channel, frequency
-- ============================================================

function HL2RP.Radio.GetChannel(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return nil end
    return ply:GetCharacter():GetVar("radioChannel") or "OPEN_1"
end

function HL2RP.Radio.SetChannel(ply, channelID)
    if not IsValid(ply) or not ply:GetCharacter() then return false end
    local ch = HL2RP.Radio.ChannelMap[channelID]
    if not ch then return false, "unknown_channel" end

    -- Check faction restriction
    if ch.factionOnly then
        local fID = ply:GetCharacter():GetVar("faction")
        local allowed = false
        for _, f in ipairs(ch.factionOnly) do
            if fID == f then allowed = true; break end
        end
        -- Also allow hacked radio to bypass
        local hasHackedRadio = false -- TODO: check inventory
        if not allowed and not hasHackedRadio and not HL2RP.HasRank(ply, "admin") then
            return false, "faction_restricted"
        end
    end

    ply:GetCharacter():SetVar("radioChannel", channelID)
    return true
end

-- Check if player has a functioning radio in inventory
function HL2RP.Radio.HasRadio(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return false end
    local inv = ply:GetCharacter():getInventory()
    if not inv then return false end
    return inv:hasItem("handheld_radio") or inv:hasItem("combine_radio") or inv:hasItem("hacked_radio")
end
