--[[
    plugins/combine_systems/sv/sv_combine.lua
    COMBINE SYSTEMS
    ============================================================
    Advanced Combine-faction tools:
    - OTA deployment authorization system
    - Scanner drone simulation
    - Sector control and lockdown management
    - Biometric terminal access
    - Checkpoint roster management
    - Anti-citizen escalation ladder
    - Civil scanner photography bounties
    - Combine command uplink
    ============================================================
--]]

HL2RP.Combine = HL2RP.Combine or {}

-- ============================================================
-- SECTOR CONTROL SYSTEM
-- The city is divided into sectors, each with a security level
-- ============================================================

HL2RP.Combine.Sectors = {
    SECTOR_A = {
        id           = "SECTOR_A",
        label        = "Sector A — Administrative",
        securityLevel= 3,    -- 1=low 2=medium 3=high 4=lockdown
        lockedDown   = false,
        permits      = { "housing", "work", "curfew" },  -- Required to enter
        patrolSquad  = nil,
        description  = "Houses the Bureau and CP command. Restricted to authorized personnel.",
    },
    SECTOR_B = {
        id           = "SECTOR_B",
        label        = "Sector B — Residential",
        securityLevel= 1,
        lockedDown   = false,
        permits      = {},
        patrolSquad  = nil,
        description  = "Primary residential block. Most citizens live here.",
    },
    SECTOR_C = {
        id           = "SECTOR_C",
        label        = "Sector C — Industrial",
        securityLevel= 2,
        lockedDown   = false,
        permits      = { "work" },
        patrolSquad  = nil,
        description  = "CWU labor district. Work permit required during shift hours.",
    },
    SECTOR_D = {
        id           = "SECTOR_D",
        label        = "Sector D — Outskirts",
        securityLevel= 1,
        lockedDown   = false,
        permits      = { "travel" },
        patrolSquad  = nil,
        description  = "Border sector with wasteland access. Travel permit required.",
    },
    SECTOR_CP = {
        id           = "SECTOR_CP",
        label        = "CP Command — Restricted",
        securityLevel= 4,
        lockedDown   = true,
        permits      = {},   -- CP faction only — no permit bypasses this
        factionOnly  = { "cp", "ota", "admin_bureau" },
        description  = "Civil Protection headquarters. Unauthorized entry is lethal.",
    },
}

-- Lockdown a sector
function HL2RP.Combine.LockdownSector(sectorID, officerPly, reason)
    local sector = HL2RP.Combine.Sectors[sectorID]
    if not sector then return false, "unknown_sector" end

    sector.lockedDown    = true
    sector.lockedBy      = IsValid(officerPly) and officerPly:GetCharacter():GetName() or "System"
    sector.lockdownAt    = os.time()
    sector.lockdownReason= reason or "Unspecified"

    HL2RP.Dispatch.SectorBroadcast(sectorID,
        string.format("LOCKDOWN: %s is now under lockdown. All unauthorized personnel must evacuate immediately.", sector.label))
    HL2RP.Tension.Modify("sector_lockdown", 10)

    HL2RP.Log("COMBINE", IsValid(officerPly) and officerPly:Name() or "system",
        "SectorLockdown", sectorID, reason or "")
    return true
end

function HL2RP.Combine.LiftLockdown(sectorID, officerPly)
    local sector = HL2RP.Combine.Sectors[sectorID]
    if not sector then return false end
    sector.lockedDown = false
    HL2RP.Dispatch.SectorBroadcast(sectorID,
        string.format("NOTICE: Lockdown on %s has been lifted. Citizens may resume authorized movement.", sector.label))
    HL2RP.Log("COMBINE", IsValid(officerPly) and officerPly:Name() or "system",
        "LockdownLifted", sectorID, "")
end

-- Check if player can enter a sector
function HL2RP.Combine.CanEnterSector(ply, sectorID)
    local sector = HL2RP.Combine.Sectors[sectorID]
    if not sector then return true end  -- Unknown sector = open

    local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")

    -- Faction override
    if sector.factionOnly then
        for _, f in ipairs(sector.factionOnly) do
            if fID == f then return true end
        end
        -- OTA can always enter
        if fID == "ota" then return true end
    end

    -- Lockdown: only CP/OTA
    if sector.lockedDown then
        return fID == "cp" or fID == "ota" or HL2RP.HasRank(ply, "admin")
    end

    -- Permit check
    for _, permitType in ipairs(sector.permits or {}) do
        if not HL2RP.Permits.IsValid(ply, permitType) then
            return false, permitType
        end
    end

    return true
end

-- ============================================================
-- OTA DEPLOYMENT SYSTEM
-- OTA cannot just spawn in — they need authorization
-- ============================================================

HL2RP.Combine.OTADeployments = {}  -- Active deployment orders

function HL2RP.Combine.AuthorizeOTADeployment(gridLeaderPly, reason, sectors)
    local fID  = gridLeaderPly:GetCharacter() and gridLeaderPly:GetCharacter():GetVar("faction")
    local rank = HL2RP.GetRankIndex(gridLeaderPly)

    if fID ~= "cp" or rank < 4 then  -- Elite+ required
        return HL2RP.Notify(gridLeaderPly, "Only CP Elites and above can authorize OTA deployment.", "error")
    end

    local deployID = "OTA_DEPLOY_" .. tostring(os.time())
    HL2RP.Combine.OTADeployments[deployID] = {
        id           = deployID,
        authorizedBy = gridLeaderPly:GetCharacter():GetName(),
        reason       = reason,
        sectors      = sectors or {},
        authorizedAt = os.time(),
        active       = true,
    }

    -- Notify OTA players
    HL2RP.Events.NotifyFaction("ota",
        string.format("[DEPLOYMENT ORDER] Authorized by %s — Reason: %s — Sectors: %s",
            gridLeaderPly:GetCharacter():GetName(), reason, table.concat(sectors or {}, ", ")), "error")

    -- CP Dispatch
    HL2RP.Dispatch.CPSend(string.format(
        "OTA DEPLOYMENT AUTHORIZED: %s — Sectors affected: %s",
        reason, table.concat(sectors or {}, ", ")), gridLeaderPly)

    HL2RP.Tension.Modify("ota_deploy", 15)
    HL2RP.Log("COMBINE", gridLeaderPly:Name(), "OTADeployment", deployID, reason)
    return deployID
end

-- ============================================================
-- SCANNER DRONE SYSTEM
-- Periodic visual sweeps of active players
-- Resistance/high-suspicion players risk detection
-- ============================================================

local DRONE_INTERVAL  = 180   -- Every 3 minutes
local DRONE_FIND_HIGH = 0.6   -- 60% chance to flag suspicion>75 player
local DRONE_FIND_MED  = 0.2   -- 20% chance to flag suspicion>50 player

timer.Create("HL2RP_ScannerDronePass", DRONE_INTERVAL, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:GetCharacter() then continue end
        local suspicion = ply:GetCharacter():GetVar("suspicion") or 0
        local fID       = ply:GetCharacter():GetVar("faction")

        -- CP and OTA are never scanned
        if fID == "cp" or fID == "ota" then continue end

        local detected = false
        if suspicion >= 75 and math.random() < DRONE_FIND_HIGH then
            detected = true
        elseif suspicion >= 50 and math.random() < DRONE_FIND_MED then
            detected = true
        end

        if detected then
            -- Alert CP
            HL2RP.Events.NotifyFaction("cp",
                string.format("[SCANNER] Person of interest located: %s — Position flagged.",
                    ply:GetCharacter():GetName()), "warning")

            -- Notify target ominously
            HL2RP.Notify(ply, "A scanner drone passes overhead. Its lens lingers on you.", "warning")

            -- Increase suspicion slightly
            ply:GetCharacter():SetVar("suspicion",
                math.min(100, suspicion + 5))

            HL2RP.Log("COMBINE", "scanner_drone", "Detected", ply:Name(),
                string.format("suspicion=%d", suspicion))
        end
    end
end)

-- ============================================================
-- BIOMETRIC TERMINAL
-- Players can check their own status / CP can run checks
-- ============================================================

function HL2RP.Combine.BiometricScan(scannerPly, targetPly)
    if not IsValid(scannerPly) or not IsValid(targetPly) then return end

    local fID = scannerPly:GetCharacter() and scannerPly:GetCharacter():GetVar("faction")
    if fID ~= "cp" and fID ~= "ota" and fID ~= "admin_bureau" and not HL2RP.HasRank(scannerPly, "moderator") then
        return HL2RP.Notify(scannerPly, "You are not authorized to use biometric scanners.", "error")
    end

    local char      = targetPly:GetCharacter()
    if not char then return end

    local cid       = char:GetVar("cid") or "UNREGISTERED"
    local loyalty   = char:GetVar("loyaltyScore") or 0
    local suspicion = char:GetVar("suspicion") or 0
    local crimes    = char:GetVar("crimeRecord") or {}
    local permits   = char:GetVar("permits") or {}
    local hasWarrant= HL2RP.Arrests.HasWarrant(char:GetName())

    local lLabel = HL2RP.Progression.GetLoyaltyLabel(loyalty)
    local sLabel = HL2RP.Progression.GetSuspicionLabel(suspicion)

    scannerPly:ChatPrint("╔══════════ BIOMETRIC SCAN ══════════╗")
    scannerPly:ChatPrint(string.format("║ CID:       %-26s ║", cid))
    scannerPly:ChatPrint(string.format("║ Name:      %-26s ║", char:GetName()))
    scannerPly:ChatPrint(string.format("║ Loyalty:   %-3d  %-22s ║", loyalty, "(" .. lLabel .. ")"))
    scannerPly:ChatPrint(string.format("║ Suspicion: %-3d  %-22s ║", suspicion, "(" .. sLabel .. ")"))
    scannerPly:ChatPrint(string.format("║ Crimes:    %-26s ║", tostring(#crimes) .. " on record"))
    scannerPly:ChatPrint(string.format("║ Warrant:   %-26s ║", hasWarrant and "⚠ YES" or "No"))
    scannerPly:ChatPrint("╠══════════════ PERMITS ═════════════╣")
    local anyPermit = false
    for pType, pData in pairs(permits) do
        anyPermit = true
        local valid = not pData.revoked and not pData.forged
        scannerPly:ChatPrint(string.format("║  [%s] %-29s ║",
            valid and "✓" or "✗", pType))
    end
    if not anyPermit then
        scannerPly:ChatPrint("║  No permits registered.             ║")
    end
    scannerPly:ChatPrint("╚════════════════════════════════════╝")

    -- If wanted, alert
    if hasWarrant then
        HL2RP.Dispatch.CPSend(string.format(
            "[BIOMETRIC ALERT] Wanted individual identified: %s — %s",
            char:GetName(), scannerPly:GetCharacter():GetName() .. " at terminal"), scannerPly)
    end

    HL2RP.Log("COMBINE", scannerPly:Name(), "BiometricScan", targetPly:Name(), "")
end

-- ============================================================
-- ANTI-CITIZEN ESCALATION LADDER
-- Tracks a player's escalating anti-citizen status
-- ============================================================

HL2RP.Combine.AntiCitizenStatus = {
    [0] = { label = "Compliant",          color = Color(80,  200, 120), description = "No concerns." },
    [1] = { label = "Flagged",            color = Color(200, 200, 80),  description = "Minor violations noted." },
    [2] = { label = "Person of Interest", color = Color(220, 150, 50),  description = "Under passive monitoring." },
    [3] = { label = "Anti-Citizen",       color = Color(220, 80,  40),  description = "Active threat classification." },
    [4] = { label = "Hostile Element",    color = Color(200, 40,  40),  description = "Lethal force authorized." },
}

function HL2RP.Combine.GetACStatus(char)
    local crimes    = char:GetVar("crimeRecord") or {}
    local suspicion = char:GetVar("suspicion") or 0
    local loyalty   = char:GetVar("loyaltyScore") or 50

    local level = 0
    if #crimes >= 1  or suspicion >= 25 then level = 1 end
    if #crimes >= 3  or suspicion >= 50 then level = 2 end
    if #crimes >= 6  or suspicion >= 75 or loyalty < 20 then level = 3 end
    if #crimes >= 10 or suspicion >= 90 or loyalty < 5 then level = 4 end

    return HL2RP.Combine.AntiCitizenStatus[level], level
end

function HL2RP.Combine.EscalateACStatus(officerPly, targetPly, reason)
    if not IsValid(targetPly) or not targetPly:GetCharacter() then return end
    local char    = targetPly:GetCharacter()
    local status, level = HL2RP.Combine.GetACStatus(char)

    -- Apply escalation: add crime record entries and reduce loyalty
    HL2RP.Datafiles.LogCrime(officerPly, char, "Anti-citizen escalation: " .. (reason or ""), "major")
    local loyalty = char:GetVar("loyaltyScore") or 50
    char:SetVar("loyaltyScore", math.max(0, loyalty - 20))
    char:Save()

    local newStatus, newLevel = HL2RP.Combine.GetACStatus(char)
    HL2RP.Notify(targetPly, string.format("Your classification has been escalated to: %s", newStatus.label), "error")

    if IsValid(officerPly) then
        HL2RP.Notify(officerPly, string.format("Anti-citizen status escalated to Level %d: %s",
            newLevel, newStatus.label), "info")
    end

    -- Dispatch if hostile
    if newLevel >= 3 then
        HL2RP.Dispatch.CPSend(string.format(
            "[ANTI-CITIZEN] Level %d designation active: %s — All units be advised.",
            newLevel, char:GetName()), officerPly)
        HL2RP.Tension.Modify("ac_escalation", 8)
    end

    HL2RP.Log("COMBINE", IsValid(officerPly) and officerPly:Name() or "system",
        "ACEscalation", targetPly:Name(), string.format("Level %d | %s", newLevel, reason or ""))
end

-- ============================================================
-- CHECKPOINT ROSTER
-- CP can maintain a list of checked individuals per shift
-- ============================================================

HL2RP.Combine.CheckpointRoster = {}   -- checkpoint_id -> { entries }

function HL2RP.Combine.LogCheckpoint(officerPly, targetPly, result)
    if not IsValid(officerPly) or not IsValid(targetPly) then return end

    local cpID = "CP_" .. officerPly:GetCharacter():GetName()
    HL2RP.Combine.CheckpointRoster[cpID] = HL2RP.Combine.CheckpointRoster[cpID] or {}

    table.insert(HL2RP.Combine.CheckpointRoster[cpID], {
        citizen   = targetPly:GetCharacter():GetName(),
        result    = result or "clear",
        timestamp = os.date("%H:%M"),
    })
end

function HL2RP.Combine.ViewRoster(officerPly)
    if not IsValid(officerPly) then return end
    local cpID   = "CP_" .. officerPly:GetCharacter():GetName()
    local roster = HL2RP.Combine.CheckpointRoster[cpID] or {}

    if #roster == 0 then
        return HL2RP.Notify(officerPly, "No checkpoint entries this shift.", "info")
    end

    officerPly:ChatPrint("=== CHECKPOINT ROSTER ===")
    for _, e in ipairs(roster) do
        officerPly:ChatPrint(string.format("  [%s] %-24s — %s", e.timestamp, e.citizen, e.result))
    end
    officerPly:ChatPrint(string.format("Total processed: %d", #roster))
end

-- ============================================================
-- COMMANDS
-- ============================================================

nut.command.add("lockdown", {
    syntax  = "<sector_id> [reason]",
    desc    = "Initiate a sector lockdown (CP Officer+).",
    onRun   = function(ply, args)
        local fID  = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        local rank = HL2RP.GetRankIndex(ply)
        if (fID ~= "cp" or rank < 3) and not HL2RP.HasRank(ply, "moderator") then
            return HL2RP.Notify(ply, "Only CP Officers and above can initiate lockdowns.", "error")
        end
        local sectorID = args[1]
        local reason   = table.concat(args, " ", 2)
        HL2RP.Combine.LockdownSector(sectorID, ply, reason)
    end
})

nut.command.add("liftlockdown", {
    syntax  = "<sector_id>",
    desc    = "Lift a sector lockdown.",
    onRun   = function(ply, args)
        local fID  = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        local rank = HL2RP.GetRankIndex(ply)
        if (fID ~= "cp" or rank < 3) and not HL2RP.HasRank(ply, "moderator") then
            return HL2RP.Notify(ply, "Insufficient authority.", "error")
        end
        HL2RP.Combine.LiftLockdown(args[1], ply)
    end
})

nut.command.add("sectors", {
    desc  = "List all city sectors and their status.",
    onRun = function(ply)
        ply:ChatPrint("=== CITY SECTORS ===")
        for id, sector in pairs(HL2RP.Combine.Sectors) do
            local status = sector.lockedDown and "LOCKDOWN" or ("Level " .. sector.securityLevel)
            ply:ChatPrint(string.format("  [%-12s] %-8s — %s", id, status, sector.label))
        end
    end
})

nut.command.add("bioscan", {
    syntax  = "<player>",
    desc    = "Run a biometric scan on a player.",
    onRun   = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        HL2RP.Combine.BiometricScan(ply, target)
    end
})

nut.command.add("escalate", {
    syntax  = "<player> [reason]",
    desc    = "Escalate a player's anti-citizen classification.",
    onRun   = function(ply, args)
        local fID  = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        local rank = HL2RP.GetRankIndex(ply)
        if (fID ~= "cp" or rank < 3) and not HL2RP.HasRank(ply, "moderator") then
            return HL2RP.Notify(ply, "Insufficient authority.", "error")
        end
        local target = nut.util.FindPlayer(args[1])
        local reason = table.concat(args, " ", 2)
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        HL2RP.Combine.EscalateACStatus(ply, target, reason)
    end
})

nut.command.add("acstatus", {
    syntax  = "<player>",
    desc    = "Check anti-citizen classification of a player.",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if fID ~= "cp" and fID ~= "ota" and not HL2RP.HasRank(ply, "moderator") then
            return HL2RP.Notify(ply, "Not authorized.", "error")
        end
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) or not target:GetCharacter() then
            return HL2RP.Notify(ply, "Target not found.", "error")
        end
        local status, level = HL2RP.Combine.GetACStatus(target:GetCharacter())
        HL2RP.Notify(ply, string.format("%s — AC Level %d: %s",
            target:GetCharacter():GetName(), level, status.label), "info")
    end
})

nut.command.add("authota", {
    syntax  = "<reason> [sector1] [sector2]",
    desc    = "Authorize an OTA deployment (CP Elite+).",
    onRun   = function(ply, args)
        local reason  = args[1]
        local sectors = {}
        for i = 2, #args do table.insert(sectors, args[i]) end
        HL2RP.Combine.AuthorizeOTADeployment(ply, reason, sectors)
    end
})

nut.command.add("checkpointlog", {
    syntax  = "<player> <clear/flagged/arrested>",
    desc    = "Log a checkpoint interaction.",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if fID ~= "cp" then return HL2RP.Notify(ply, "CP only.", "error") end
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        HL2RP.Combine.LogCheckpoint(ply, target, args[2] or "clear")
        HL2RP.Notify(ply, "Checkpoint entry logged.", "success")
    end
})

nut.command.add("viewroster", {
    desc  = "View your checkpoint roster for this shift.",
    onRun = function(ply)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if fID ~= "cp" then return HL2RP.Notify(ply, "CP only.", "error") end
        HL2RP.Combine.ViewRoster(ply)
    end
})
