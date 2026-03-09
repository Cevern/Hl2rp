--[[
    plugins/char_death/sv/sv_death.lua
    CHARACTER DEATH & INHERITANCE SYSTEM
    ============================================================
    Permanent character death (CK - Character Kill):
    - Must be agreed upon by both parties (or admin-enforced)
    - Triggers a death ceremony sequence
    - Unlocks "will" system — leave items/notes to someone
    - Adds to Memorial Wall (persistent remembrance)
    - Legacy: new character can inherit one trait from the dead
    - CP can file an "official" execution record
    - Resistance honors fallen members on their board
    - Character name blacklisted for 7 days
    ============================================================
--]]

HL2RP.CharDeath = HL2RP.CharDeath or {}
HL2RP.CharDeath.PendingCK   = {}    -- ply -> { requestedBy, reason, expires }
HL2RP.CharDeath.MemorialWall= {}    -- { name, faction, cause, date, eulogist }[]
HL2RP.CharDeath.Wills       = {}    -- steamID -> { beneficiary, items, note }
HL2RP.CharDeath.BlacklistNames = {} -- name -> expires (timestamp)

util.AddNetworkString("HL2RP_CKConfirm")
util.AddNetworkString("HL2RP_MemorialSync")

-- ============================================================
-- REQUEST CK (CHARACTER KILL)
-- ============================================================

function HL2RP.CharDeath.RequestCK(requesterPly, targetPly, reason)
    if not IsValid(requesterPly) or not IsValid(targetPly) then return false end

    -- Must be staff or CP Officer+ for official CK
    local fID  = requesterPly:GetCharacter() and requesterPly:GetCharacter():GetVar("faction")
    local rank = HL2RP.GetRankIndex(requesterPly)
    local isStaff = HL2RP.HasRank(requesterPly, "moderator")
    local isCP    = fID == "cp" and rank >= 3

    if not isStaff and not isCP then
        return HL2RP.Notify(requesterPly, "Only CP Officers+ or staff can issue CK requests.", "error")
    end

    HL2RP.CharDeath.PendingCK[targetPly] = {
        requestedBy = requesterPly,
        reason      = reason or "Unspecified",
        expires     = CurTime() + 120,  -- 2 min to decide
    }

    HL2RP.Notify(targetPly,
        string.format("[CK REQUEST] %s has issued a Character Kill request: %s\nType /acceptck or /denyck within 2 minutes.",
            requesterPly:GetCharacter():GetName(), reason), "error")

    HL2RP.Notify(requesterPly,
        string.format("CK request issued to %s. Awaiting response.", targetPly:GetCharacter():GetName()), "info")

    HL2RP.Log("ADMIN", requesterPly:Name(), "CKRequest", targetPly:Name(), reason)
    return true
end

-- Admin-force CK (no consent)
function HL2RP.CharDeath.ForceCK(adminPly, targetPly, reason)
    if not HL2RP.HasRank(adminPly, "admin") then
        return HL2RP.Notify(adminPly, "Admin only.", "error")
    end
    HL2RP.CharDeath.Execute(targetPly, adminPly, reason, true)
end

-- ============================================================
-- ACCEPT/DENY CK
-- ============================================================

function HL2RP.CharDeath.AcceptCK(ply)
    local ck = HL2RP.CharDeath.PendingCK[ply]
    if not ck or CurTime() > ck.expires then
        return HL2RP.Notify(ply, "No pending CK request.", "error")
    end
    HL2RP.CharDeath.PendingCK[ply] = nil
    HL2RP.CharDeath.Execute(ply, ck.requestedBy, ck.reason, false)
end

function HL2RP.CharDeath.DenyCK(ply)
    local ck = HL2RP.CharDeath.PendingCK[ply]
    if not ck then return HL2RP.Notify(ply, "No pending CK request.", "error") end
    HL2RP.CharDeath.PendingCK[ply] = nil
    if IsValid(ck.requestedBy) then
        HL2RP.Notify(ck.requestedBy, string.format("%s denied the CK request.",
            ply:GetCharacter():GetName()), "warning")
    end
    HL2RP.Notify(ply, "CK request denied.", "info")
end

-- ============================================================
-- EXECUTE CHARACTER DEATH
-- ============================================================

function HL2RP.CharDeath.Execute(ply, killer, reason, forced)
    if not IsValid(ply) or not ply:GetCharacter() then return false end

    local char     = ply:GetCharacter()
    local charName = char:GetName()
    local faction  = char:GetVar("faction") or "citizen"
    local date     = os.date("%Y-%m-%d")
    local killerName = (IsValid(killer) and killer:GetCharacter() and killer:GetCharacter():GetName()) or "Unknown"

    -- Run will before deletion
    HL2RP.CharDeath.ExecuteWill(ply)

    -- Memorial entry
    table.insert(HL2RP.CharDeath.MemorialWall, {
        name       = charName,
        faction    = faction,
        cause      = reason or "Unknown",
        killedBy   = killerName,
        date       = date,
        forced     = forced,
        legacy     = char:GetVar("background") or "none",
        eulogist   = nil,
        eulogy     = nil,
    })

    -- Name blacklist
    HL2RP.CharDeath.BlacklistNames[charName:lower()] = os.time() + (7 * 86400)

    -- Resistance honor fallen
    if faction == "resistance" then
        HL2RP.Events.NotifyFaction("resistance",
            string.format("[FALLEN] %s has been killed. %s. We remember.", charName, reason or ""), "error")
    end

    -- CP log execution
    if IsValid(killer) and killer:GetCharacter() and
       killer:GetCharacter():GetVar("faction") == "cp" then
        HL2RP.Events.NotifyFaction("cp",
            string.format("[EXECUTION RECORD] %s terminated. Reason: %s.", charName, reason or ""), "info")
        HL2RP.Dispatch.CPSend(string.format("[CONFIRMED] Anti-citizen %s neutralized.", charName), killer)
    end

    -- Broadcast death to nearby players
    local range = 400
    for _, p in ipairs(player.GetAll()) do
        if p:GetPos():Distance(ply:GetPos()) <= range then
            p:ChatPrint(string.format("[ %s has died. %s ]", charName, reason or ""))
        end
    end

    -- Sync memorial
    HL2RP.CharDeath.SyncMemorial()

    -- Delete character (NutScript)
    ply:TakeDamage(ply:Health() + 100, ply, ply)
    timer.Simple(2, function()
        if IsValid(ply) then
            -- Force character deletion
            char:delete()
            HL2RP.Notify(ply, string.format(
                "Your character '%s' has died permanently. Create a new character.\nYou may inherit one trait from %s on your next character.",
                charName, charName), "error")
        end
    end)

    HL2RP.Log("ADMIN", IsValid(killer) and killer:Name() or "system",
        "CharacterKill", charName, string.format("reason=%s forced=%s", reason or "?", tostring(forced)))
    return true
end

-- ============================================================
-- WILL SYSTEM
-- ============================================================

function HL2RP.CharDeath.WriteWill(ply, beneficiaryName, note)
    if not IsValid(ply) or not ply:GetCharacter() then return false end
    local sid = ply:SteamID()

    HL2RP.CharDeath.Wills[sid] = {
        beneficiary = beneficiaryName,
        note        = note or "",
        items       = {},   -- Filled from inventory on death
        written     = os.date("%Y-%m-%d"),
    }
    HL2RP.Notify(ply, string.format("Will written. Beneficiary: %s.", beneficiaryName), "success")
    HL2RP.Log("HOUSING", ply:Name(), "WillWritten", beneficiaryName, note or "")
end

function HL2RP.CharDeath.ExecuteWill(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    local sid  = ply:SteamID()
    local will = HL2RP.CharDeath.Wills[sid]
    if not will then return end

    -- Find beneficiary online
    local beneficiary = nil
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:GetCharacter() and
           p:GetCharacter():GetName():lower() == will.beneficiary:lower() then
            beneficiary = p
            break
        end
    end

    if IsValid(beneficiary) and beneficiary:GetCharacter() then
        -- Transfer credits (half)
        local credits = HL2RP.Economy.GetBalance(ply)
        if credits > 0 then
            local inheritance = math.floor(credits * 0.5)
            HL2RP.Economy.Add(beneficiary, inheritance, "Inheritance from " .. ply:GetCharacter():GetName())
            HL2RP.Notify(beneficiary, string.format(
                "[WILL] %s left you Ȼ%d and a note: \"%s\"",
                ply:GetCharacter():GetName(), inheritance, will.note), "info")
        else
            HL2RP.Notify(beneficiary, string.format(
                "[WILL] %s left you a note: \"%s\"",
                ply:GetCharacter():GetName(), will.note), "info")
        end
    end

    HL2RP.CharDeath.Wills[sid] = nil
end

-- ============================================================
-- LEGACY TRAIT (for next character)
-- ============================================================

HL2RP.CharDeath.LegacyTraits = {
    -- From resistance: survivor instinct
    resistance  = { id = "survivor",        label = "Survivor",         desc = "Reduced fatigue drain from stress." },
    -- From CP: trained discipline
    cp          = { id = "disciplined",     label = "Disciplined",      desc = "Slower needs decay." },
    -- From medic: medical knowledge
    medic       = { id = "field_medic",     label = "Field Medic",      desc = "Self-bandaging costs fewer supplies." },
    -- From CWU: labor experience
    cwu         = { id = "labor_veteran",   label = "Labor Veteran",    desc = "Tasks complete 15% faster." },
    -- From citizen default: adaptable
    citizen     = { id = "adaptable",       label = "Adaptable",        desc = "Slightly better black market prices." },
    -- From vortigaunt: vortessence sensitivity
    vortigaunt  = { id = "vort_touched",    label = "Vort-Touched",     desc = "Healed more effectively by Vortigaunts." },
}

function HL2RP.CharDeath.ApplyLegacy(ply, deadFaction)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    local trait = HL2RP.CharDeath.LegacyTraits[deadFaction]
    if not trait then return end

    ply:GetCharacter():SetVar("legacyTrait", trait.id)
    ply:GetCharacter():Save()
    HL2RP.Notify(ply, string.format("[LEGACY] Inherited trait from your previous character: %s — %s",
        trait.label, trait.desc), "info")
end

-- ============================================================
-- EULOGY SYSTEM
-- ============================================================

function HL2RP.CharDeath.AddEulogy(adminOrPlayerPly, deadName, eulogy)
    for i, entry in ipairs(HL2RP.CharDeath.MemorialWall) do
        if entry.name:lower() == deadName:lower() then
            entry.eulogist = IsValid(adminOrPlayerPly) and
                adminOrPlayerPly:GetCharacter() and
                adminOrPlayerPly:GetCharacter():GetName() or "Anonymous"
            entry.eulogy   = eulogy
            HL2RP.CharDeath.SyncMemorial()
            HL2RP.Notify(adminOrPlayerPly, "Eulogy added to the memorial wall.", "success")
            return true
        end
    end
    return false
end

-- ============================================================
-- SYNC MEMORIAL
-- ============================================================

function HL2RP.CharDeath.SyncMemorial()
    local json = util.TableToJSON(HL2RP.CharDeath.MemorialWall)
    net.Start("HL2RP_MemorialSync")
        net.WriteString(json)
    net.Broadcast()
end

hook.Add("PlayerInitialSpawn", "HL2RP_MemorialJoinSync", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end
        net.Start("HL2RP_MemorialSync")
            net.WriteString(util.TableToJSON(HL2RP.CharDeath.MemorialWall))
        net.Send(ply)
    end)
end)

-- ============================================================
-- NAME BLACKLIST CHECK
-- ============================================================

hook.Add("nut.char.Created", "HL2RP_NameBlacklist", function(char, ply)
    local name = char:GetName():lower()
    local expires = HL2RP.CharDeath.BlacklistNames[name]
    if expires and os.time() < expires then
        local days = math.ceil((expires - os.time()) / 86400)
        -- Prevent char creation (NutScript hook)
        return false, string.format(
            "This name belongs to a recently deceased character. Available in %d days.", days)
    end
end)

-- ============================================================
-- COMMANDS
-- ============================================================

nut.command.add("requestck", {
    syntax = "<player> [reason]",
    desc   = "Request a character kill on a player (CP Officer+/Staff).",
    onRun  = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        local reason = table.concat(args, " ", 2)
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        HL2RP.CharDeath.RequestCK(ply, target, reason)
    end
})

nut.command.add("acceptck", {
    desc = "Accept a character kill request.",
    onRun = function(ply) HL2RP.CharDeath.AcceptCK(ply) end
})

nut.command.add("denyck", {
    desc = "Deny a character kill request.",
    onRun = function(ply) HL2RP.CharDeath.DenyCK(ply) end
})

nut.command.add("forceck", {
    syntax = "<player> [reason]",
    desc   = "Force a character kill without consent (Admin).",
    onRun  = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        local reason = table.concat(args, " ", 2)
        if not IsValid(target) then return HL2RP.Notify(ply, "Target not found.", "error") end
        HL2RP.CharDeath.ForceCK(ply, target, reason)
    end
})

nut.command.add("writewill", {
    syntax = "<beneficiary_name> [note]",
    desc   = "Write your character's will (leave items/credits to someone on death).",
    onRun  = function(ply, args)
        local ben  = args[1]
        local note = table.concat(args, " ", 2)
        if not ben then return HL2RP.Notify(ply, "Specify a beneficiary name.", "error") end
        HL2RP.CharDeath.WriteWill(ply, ben, note)
    end
})

nut.command.add("memorial", {
    desc = "View the memorial wall.",
    onRun = function(ply)
        if #HL2RP.CharDeath.MemorialWall == 0 then
            return HL2RP.Notify(ply, "The memorial wall is empty.", "info")
        end
        ply:ChatPrint("=== MEMORIAL WALL — CITY 45 ===")
        for _, e in ipairs(HL2RP.CharDeath.MemorialWall) do
            ply:ChatPrint(string.format("  [%s] %s (%s) — %s", e.date, e.name, e.faction, e.cause))
            if e.eulogy then
                ply:ChatPrint(string.format('    "%s" — %s', e.eulogy, e.eulogist or "?"))
            end
        end
    end
})

nut.command.add("eulogy", {
    syntax = "<dead_character_name> <eulogy_text>",
    desc   = "Add a eulogy to a fallen character on the memorial wall.",
    onRun  = function(ply, args)
        local name   = args[1]
        local eulogy = table.concat(args, " ", 2)
        if not name or not eulogy then return HL2RP.Notify(ply, "Provide name and eulogy.", "error") end
        local ok = HL2RP.CharDeath.AddEulogy(ply, name, eulogy)
        if not ok then HL2RP.Notify(ply, "Character not found on memorial wall.", "error") end
    end
})

nut.command.add("applylegacy", {
    syntax = "<dead_faction_id>",
    desc   = "Apply a legacy trait from your previous character (once per new character).",
    onRun  = function(ply, args)
        if not ply:GetCharacter() then return end
        if ply:GetCharacter():GetVar("legacyTrait") then
            return HL2RP.Notify(ply, "Already applied a legacy trait.", "error")
        end
        HL2RP.CharDeath.ApplyLegacy(ply, args[1])
    end
})
