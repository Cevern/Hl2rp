--[[
    plugins/weapons_combat/sv/sv_combat.lua
    WEAPONS & COMBAT SYSTEM
    ============================================================
    HL2RP combat is heavily restricted — firearms are contraband.
    This plugin:
    - Manages weapon whitelisting per faction
    - Tracks injuries and permanent debuffs from damage
    - Handles /me-style combat for melee RP
    - Enforces weapon restrictions and contraband flagging
    - Manages non-lethal takedowns
    - Provides CP lethal authorization ladder
    - Logs all combat incidents
    ============================================================
--]]

HL2RP.Combat = HL2RP.Combat or {}

-- ============================================================
-- FACTION WEAPON WHITELIST
-- ============================================================

HL2RP.Combat.AllowedWeapons = {
    citizen     = { "weapon_crowbar", "weapon_fists" },
    loyalist    = { "weapon_crowbar", "weapon_fists" },
    cwu         = { "weapon_crowbar", "weapon_fists" },
    medic       = { "weapon_crowbar", "weapon_fists", "weapon_medkit" },
    vortigaunt  = { "weapon_crowbar", "weapon_fists" },  -- Abilities handle zap
    resistance  = { "weapon_crowbar", "weapon_fists", "weapon_pistol", "weapon_smg1", "weapon_shotgun" },
    smuggler    = { "weapon_crowbar", "weapon_fists", "weapon_pistol" },
    cp          = { "weapon_stunstick", "weapon_pistol", "weapon_smg1", "weapon_fists" },
    ota         = { "weapon_stunstick", "weapon_ar2", "weapon_smg1", "weapon_pistol",
                    "weapon_shotgun", "weapon_crossbow", "weapon_fists" },
    admin_bureau= { "weapon_fists" },
}

-- CP lethal force authorization per rank
HL2RP.Combat.CPLethalAuth = {
    [0] = false,   -- RCT: non-lethal only
    [1] = false,   -- Officer: non-lethal only
    [2] = true,    -- Senior: authorized vs Level 3+ AC or direct attack
    [3] = true,
    [4] = true,
    [5] = true,
}

-- ============================================================
-- WEAPON SPAWN / DROP RESTRICTION
-- ============================================================

hook.Add("PlayerSpawnedSENT", "HL2RP_WeaponSpawnCheck", function(ply, ent)
    if not HL2RP.HasRank(ply, "admin") then
        ent:Remove()
    end
end)

hook.Add("PlayerCanPickupWeapon", "HL2RP_WeaponPickupCheck", function(ply, wep)
    if not IsValid(ply) or not IsValid(wep) then return false end
    if HL2RP.HasRank(ply, "moderator") then return true end

    local char = ply:GetCharacter()
    if not char then return false end

    local fID     = char:GetVar("faction") or "citizen"
    local allowed = HL2RP.Combat.AllowedWeapons[fID] or {}
    local wClass  = wep:GetClass()

    for _, w in ipairs(allowed) do
        if w == wClass then return true end
    end

    HL2RP.Notify(ply, "You are not authorized to carry this weapon.", "error")
    return false
end)

-- ============================================================
-- INJURY SYSTEM
-- Tracks damage taken and applies lasting debuffs
-- ============================================================

HL2RP.Combat.Injuries = {}  -- ply -> { type, severity, healedAt }

local InjuryTypes = {
    {
        id       = "leg_injury",
        label    = "Leg Injury",
        threshold= 40,    -- Below 40 HP when hit
        speedMult= 0.75,
        duration = 600,
        message  = "Your leg is injured. Movement is impaired.",
    },
    {
        id       = "arm_injury",
        label    = "Arm Injury",
        threshold= 35,
        message  = "Your arm is injured. Combat effectiveness reduced.",
        duration = 480,
    },
    {
        id       = "concussion",
        label    = "Concussion",
        threshold= 25,
        duration = 300,
        message  = "You're concussed. Vision and coordination affected.",
    },
}

hook.Add("EntityTakeDamage", "HL2RP_InjurySystem", function(target, dmginfo)
    if not target:IsPlayer() then return end
    if not IsValid(target) or not target:GetCharacter() then return end

    local newHp   = target:Health() - dmginfo:GetDamage()
    local attacker= dmginfo:GetAttacker()

    -- Check for injury triggers
    for _, itype in ipairs(InjuryTypes) do
        if newHp <= itype.threshold and not (HL2RP.Combat.Injuries[target] and
           HL2RP.Combat.Injuries[target][itype.id]) then

            -- Assign injury
            HL2RP.Combat.Injuries[target]           = HL2RP.Combat.Injuries[target] or {}
            HL2RP.Combat.Injuries[target][itype.id] = {
                injuredAt = CurTime(),
                healAt    = CurTime() + itype.duration,
            }

            HL2RP.Notify(target, itype.message, "error")

            -- Speed penalty
            if itype.speedMult then
                target:SetRunSpeed(target:GetRunSpeed() * itype.speedMult)
                target:SetWalkSpeed(target:GetWalkSpeed() * itype.speedMult)
            end

            -- Auto-heal timer
            timer.Simple(itype.duration, function()
                if IsValid(target) then
                    HL2RP.Combat.ClearInjury(target, itype.id)
                end
            end)

            break  -- One injury at a time
        end
    end

    -- Combat logging
    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= target then
        local aName = attacker:GetCharacter() and attacker:GetCharacter():GetName() or attacker:Name()
        local tName = target:GetCharacter() and target:GetCharacter():GetName() or target:Name()
        HL2RP.Log("CRIME", aName, "DamageDealt", tName,
            string.format("dmg=%.0f weapon=%s", dmginfo:GetDamage(),
            IsValid(dmginfo:GetInflictor()) and dmginfo:GetInflictor():GetClass() or "unknown"))
    end
end)

function HL2RP.Combat.ClearInjury(ply, injuryID)
    if not IsValid(ply) then return end
    if HL2RP.Combat.Injuries[ply] then
        HL2RP.Combat.Injuries[ply][injuryID] = nil
    end
    -- Restore speed
    local speed = nut.config.get("walkSpeed") or 150
    ply:SetWalkSpeed(speed)
    ply:SetRunSpeed(nut.config.get("runSpeed") or 200)
    HL2RP.Notify(ply, "Your injury has improved.", "info")
end

-- ============================================================
-- NON-LETHAL TAKEDOWN
-- CP only. Incapacitates without killing.
-- ============================================================

function HL2RP.Combat.Takedown(officerPly, targetPly)
    if not IsValid(officerPly) or not IsValid(targetPly) then return end

    local fID = officerPly:GetCharacter() and officerPly:GetCharacter():GetVar("faction")
    if fID ~= "cp" and fID ~= "ota" and not HL2RP.HasRank(officerPly, "moderator") then
        return HL2RP.Notify(officerPly, "Only CP/OTA can use non-lethal takedowns.", "error")
    end

    if officerPly:GetPos():Distance(targetPly:GetPos()) > 80 then
        return HL2RP.Notify(officerPly, "Too far for a takedown.", "error")
    end

    -- Drop target to 1 HP
    targetPly:SetHealth(1)

    -- Slow them drastically for 20s
    targetPly:SetRunSpeed(30)
    targetPly:SetWalkSpeed(30)
    targetPly:SetJumpPower(0)
    targetPly:GetCharacter():SetVar("takenDown", true)

    timer.Simple(20, function()
        if IsValid(targetPly) and targetPly:GetCharacter() then
            targetPly:GetCharacter():SetVar("takenDown", false)
            targetPly:SetRunSpeed(nut.config.get("runSpeed") or 200)
            targetPly:SetWalkSpeed(nut.config.get("walkSpeed") or 150)
            targetPly:SetJumpPower(160)
        end
    end)

    local oName = officerPly:GetCharacter():GetName()
    local tName = targetPly:GetCharacter():GetName()
    local range = 200

    for _, ply in ipairs(player.GetAll()) do
        if ply:GetPos():Distance(officerPly:GetPos()) <= range then
            ply:ChatPrint(string.format("* %s takes %s down with a non-lethal strike.", oName, tName))
        end
    end

    HL2RP.Notify(targetPly, "You have been taken down. You cannot move effectively.", "error")
    HL2RP.Log("ENFORCEMENT", officerPly:Name(), "Takedown", targetPly:Name(), "nonlethal")
end

-- ============================================================
-- LETHAL FORCE CHECK
-- ============================================================

function HL2RP.Combat.IsLethalAuthorized(officerPly, targetPly)
    if not IsValid(officerPly) or not IsValid(targetPly) then return false end
    if HL2RP.HasRank(officerPly, "admin") then return true end

    local fID  = officerPly:GetCharacter() and officerPly:GetCharacter():GetVar("faction")
    local rank = HL2RP.GetRankIndex(officerPly)

    -- OTA is always authorized
    if fID == "ota" then return true end

    -- CP: rank must allow lethal
    if fID == "cp" then
        if not HL2RP.Combat.CPLethalAuth[rank] then return false end
    else
        return false  -- Other factions not authorized for sanctioned lethal
    end

    -- Target must be AC Level 3+, or have a lethal warrant
    if IsValid(targetPly) and targetPly:GetCharacter() then
        local _, acLevel = HL2RP.Combine.GetACStatus(targetPly:GetCharacter())
        if acLevel >= 3 then return true end
        if HL2RP.Arrests.HasWarrant(targetPly:GetCharacter():GetName(), "lethal") then return true end
    end

    return false
end

-- ============================================================
-- /me COMBAT SYSTEM
-- Structured /me for melee exchanges with dice outcomes
-- ============================================================

HL2RP.Combat.PendingExchanges = {}  -- ply -> { target, action, expires }

function HL2RP.Combat.InitiateMelee(ply, targetPly, action)
    if not IsValid(ply) or not IsValid(targetPly) then return end

    if ply:GetPos():Distance(targetPly:GetPos()) > 120 then
        return HL2RP.Notify(ply, "Too far for a melee exchange.", "error")
    end

    HL2RP.Combat.PendingExchanges[ply] = {
        target  = targetPly,
        action  = action,
        expires = CurTime() + 30,
    }

    local pName = ply:GetCharacter():GetName()
    local tName = targetPly:GetCharacter():GetName()

    -- Notify both
    ply:ChatPrint(string.format("Combat initiated vs %s. /%s to respond within 30s.",
        tName, "mele"))
    targetPly:ChatPrint(string.format(
        "%s attempts: \"%s\" — Respond with /mele <dodge/block/counter/yield>", pName, action))
end

function HL2RP.Combat.ResolveMelee(targetPly, response)
    -- Find who initiated against this player
    local initiatorPly, exchange = nil, nil
    for ply, ex in pairs(HL2RP.Combat.PendingExchanges) do
        if IsValid(ply) and ex.target == targetPly and CurTime() < ex.expires then
            initiatorPly = ply
            exchange     = ex
            break
        end
    end

    if not initiatorPly then
        return HL2RP.Notify(targetPly, "No pending melee exchange.", "error")
    end

    HL2RP.Combat.PendingExchanges[initiatorPly] = nil

    local iName = initiatorPly:GetCharacter():GetName()
    local tName = targetPly:GetCharacter():GetName()

    -- Resolution based on response
    local outcomes = {
        dodge   = { desc = "narrowly dodges the strike, creating distance.", iDmg = 0,  tDmg = 0  },
        block   = { desc = "absorbs the strike but takes reduced impact.",   iDmg = 0,  tDmg = 5  },
        counter = { desc = "turns the attack back, landing a counter blow.", iDmg = 15, tDmg = 5  },
        yield   = { desc = "doesn't resist and takes the full impact.",      iDmg = 0,  tDmg = 20 },
    }

    local outcome = outcomes[response] or outcomes.yield

    -- Broadcast to nearby players
    local range = 200
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetPos():Distance(initiatorPly:GetPos()) <= range then
            ply:ChatPrint(string.format("* %s attempts %s — %s %s",
                iName, exchange.action, tName, outcome.desc))
        end
    end

    -- Apply damage
    if outcome.iDmg > 0 then
        initiatorPly:TakeDamage(outcome.iDmg, targetPly, targetPly)
    end
    if outcome.tDmg > 0 then
        targetPly:TakeDamage(outcome.tDmg, initiatorPly, initiatorPly)
    end

    HL2RP.Log("CRIME", iName, "MeleeCombat", tName, response)
end

-- ============================================================
-- COMMANDS
-- ============================================================

nut.command.add("takedown", {
    syntax  = "<player>",
    desc    = "Non-lethal takedown of a target (CP/OTA only).",
    onRun   = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        HL2RP.Combat.Takedown(ply, target)
    end
})

nut.command.add("lethcheck", {
    syntax  = "<player>",
    desc    = "Check if lethal force is authorized against a target.",
    onRun   = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        local auth = HL2RP.Combat.IsLethalAuthorized(ply, target)
        HL2RP.Notify(ply, string.format("Lethal force vs %s: %s",
            target:GetCharacter() and target:GetCharacter():GetName() or target:Name(),
            auth and "AUTHORIZED" or "NOT AUTHORIZED"), auth and "success" or "error")
    end
})

nut.command.add("attack", {
    syntax  = "<player> <action_description>",
    desc    = "Initiate a structured melee action. Target must respond within 30s.",
    onRun   = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        local action = table.concat(args, " ", 2)
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        if not action or #action < 3 then return HL2RP.Notify(ply, "Describe your action.", "error") end
        HL2RP.Combat.InitiateMelee(ply, target, action)
    end
})

nut.command.add("mele", {
    syntax  = "<dodge/block/counter/yield>",
    desc    = "Respond to an incoming melee action.",
    onRun   = function(ply, args)
        local response = args[1]
        if not response then
            return HL2RP.Notify(ply, "Options: dodge, block, counter, yield", "info")
        end
        HL2RP.Combat.ResolveMelee(ply, response:lower())
    end
})

nut.command.add("myinjuries", {
    desc  = "Check your current injuries.",
    onRun = function(ply)
        local injuries = HL2RP.Combat.Injuries[ply]
        if not injuries or not next(injuries) then
            return HL2RP.Notify(ply, "No active injuries.", "info")
        end
        ply:ChatPrint("=== ACTIVE INJURIES ===")
        for id, inj in pairs(injuries) do
            local remaining = math.max(0, math.floor(inj.healAt - CurTime()))
            ply:ChatPrint(string.format("  %s — heals in %ds", id, remaining))
        end
    end
})

nut.command.add("healinjury", {
    syntax  = "<player> <injury_id>",
    desc    = "Manually heal an injury (Medical/Admin).",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if fID ~= "medic" and not HL2RP.HasRank(ply, "moderator") then
            return HL2RP.Notify(ply, "Medic/Admin only.", "error")
        end
        local target    = nut.util.FindPlayer(args[1])
        local injuryID  = args[2]
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        HL2RP.Combat.ClearInjury(target, injuryID)
        HL2RP.Notify(ply, string.format("Cleared injury '%s' on %s.", injuryID,
            target:GetCharacter() and target:GetCharacter():GetName() or target:Name()), "success")
    end
})
