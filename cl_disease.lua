--[[
    plugins/squad_system/sv/sv_squad.lua
    CP/OTA SQUAD SYSTEM
    ============================================================
    CP officers can form squads, assign roles, issue orders,
    share a private squad radio channel, track member positions,
    and follow patrol routes.

    Squad Leader commands: form, disband, invite, order, setrole
    Squad Members: accept, leave, status
    ============================================================
--]]

HL2RP.Squad = HL2RP.Squad or {}
HL2RP.Squad.Squads = {}   -- squadID -> squad table
HL2RP.Squad.Invites = {}  -- ply -> { from, squadID, expires }

util.AddNetworkString("HL2RP_SquadHUD")
util.AddNetworkString("HL2RP_SquadRadio")
util.AddNetworkString("HL2RP_SquadOrder")

-- ============================================================
-- SQUAD ROLES
-- ============================================================

HL2RP.Squad.Roles = {
    leader   = { label = "Squad Leader",  color = Color(220, 180, 60),  icon = "★" },
    point    = { label = "Point",         color = Color(80,  180, 220), icon = "▲" },
    flanker  = { label = "Flanker",       color = Color(220, 100, 60),  icon = "◆" },
    medic    = { label = "Field Medic",   color = Color(80,  220, 120), icon = "+" },
    heavy    = { label = "Heavy Support", color = Color(180, 80,  80),  icon = "■" },
    recon    = { label = "Recon",         color = Color(160, 120, 220), icon = "◉" },
}

-- ============================================================
-- FORM SQUAD
-- ============================================================

function HL2RP.Squad.Form(leaderPly, squadName)
    if not IsValid(leaderPly) or not leaderPly:GetCharacter() then return false end

    local fID  = leaderPly:GetCharacter():GetVar("faction")
    local rank = HL2RP.GetRankIndex(leaderPly)

    if (fID ~= "cp" or rank < 2) and fID ~= "ota" and not HL2RP.HasRank(leaderPly, "admin") then
        return HL2RP.Notify(leaderPly, "Only Senior CP+ or OTA can form squads.", "error")
    end

    -- Already in a squad?
    if HL2RP.Squad.GetSquad(leaderPly) then
        return HL2RP.Notify(leaderPly, "Leave your current squad first.", "error")
    end

    local squadID = "SQ_" .. tostring(os.time())
    HL2RP.Squad.Squads[squadID] = {
        id        = squadID,
        name      = squadName or ("Squad " .. squadID:sub(-4)),
        leader    = leaderPly,
        members   = {},   -- ply -> role
        orders    = {},
        formedAt  = os.time(),
        channel   = "SQUAD_" .. squadID:sub(-4),
    }

    local squad = HL2RP.Squad.Squads[squadID]
    squad.members[leaderPly] = "leader"
    leaderPly:GetCharacter():SetVar("squadID", squadID)

    HL2RP.Notify(leaderPly, string.format("Squad '%s' formed. Invite members with /squadinvite.", squad.name), "success")
    HL2RP.Squad.BroadcastHUD(squadID)
    HL2RP.Log("COMBINE", leaderPly:Name(), "SquadFormed", squadID, squad.name)
    return squadID
end

-- ============================================================
-- INVITE / ACCEPT
-- ============================================================

function HL2RP.Squad.Invite(leaderPly, targetPly)
    local squadID = leaderPly:GetCharacter() and leaderPly:GetCharacter():GetVar("squadID")
    if not squadID then return HL2RP.Notify(leaderPly, "You are not in a squad.", "error") end

    local squad = HL2RP.Squad.Squads[squadID]
    if not squad or squad.leader ~= leaderPly then
        return HL2RP.Notify(leaderPly, "Only the squad leader can invite.", "error")
    end

    if not IsValid(targetPly) or not targetPly:GetCharacter() then return end

    local fID = targetPly:GetCharacter():GetVar("faction")
    if fID ~= "cp" and fID ~= "ota" then
        return HL2RP.Notify(leaderPly, "Only CP/OTA can join squads.", "error")
    end

    HL2RP.Squad.Invites[targetPly] = { from = leaderPly, squadID = squadID, expires = CurTime() + 30 }
    HL2RP.Notify(targetPly, string.format("[SQUAD] %s invites you to join '%s'. /squadaccept to join.",
        leaderPly:GetCharacter():GetName(), squad.name), "info")
    HL2RP.Notify(leaderPly, string.format("Invite sent to %s.", targetPly:GetCharacter():GetName()), "success")
end

function HL2RP.Squad.Accept(ply)
    local invite = HL2RP.Squad.Invites[ply]
    if not invite or CurTime() > invite.expires then
        return HL2RP.Notify(ply, "No valid squad invite.", "error")
    end

    local squad = HL2RP.Squad.Squads[invite.squadID]
    if not squad then return HL2RP.Notify(ply, "Squad no longer exists.", "error") end

    squad.members[ply] = "point"  -- Default role
    ply:GetCharacter():SetVar("squadID", invite.squadID)
    HL2RP.Squad.Invites[ply] = nil

    HL2RP.Notify(ply, string.format("Joined squad '%s'.", squad.name), "success")
    HL2RP.Squad.RadioMsg(invite.squadID, nil, string.format("%s has joined the squad.",
        ply:GetCharacter():GetName()))
    HL2RP.Squad.BroadcastHUD(invite.squadID)
end

-- ============================================================
-- LEAVE / DISBAND
-- ============================================================

function HL2RP.Squad.Leave(ply)
    local squadID = ply:GetCharacter() and ply:GetCharacter():GetVar("squadID")
    if not squadID then return HL2RP.Notify(ply, "You are not in a squad.", "error") end

    local squad = HL2RP.Squad.Squads[squadID]
    if not squad then return end

    local name = ply:GetCharacter():GetName()
    squad.members[ply] = nil
    ply:GetCharacter():SetVar("squadID", nil)
    HL2RP.Notify(ply, "Left the squad.", "info")
    HL2RP.Squad.RadioMsg(squadID, nil, name .. " has left the squad.")

    -- If leader left, disband or promote
    if squad.leader == ply then
        -- Promote first remaining member or disband
        local newLeader = next(squad.members)
        if newLeader then
            squad.leader = newLeader
            squad.members[newLeader] = "leader"
            HL2RP.Squad.RadioMsg(squadID, nil, newLeader:GetCharacter():GetName() .. " is now squad leader.")
        else
            HL2RP.Squad.Disband(squadID)
            return
        end
    end
    HL2RP.Squad.BroadcastHUD(squadID)
end

function HL2RP.Squad.Disband(squadID)
    local squad = HL2RP.Squad.Squads[squadID]
    if not squad then return end

    for ply, _ in pairs(squad.members) do
        if IsValid(ply) and ply:GetCharacter() then
            ply:GetCharacter():SetVar("squadID", nil)
            HL2RP.Notify(ply, "The squad has been disbanded.", "warning")
        end
    end

    HL2RP.Squad.Squads[squadID] = nil
    HL2RP.Log("COMBINE", "system", "SquadDisbanded", squadID, "")
end

-- ============================================================
-- SQUAD RADIO
-- ============================================================

function HL2RP.Squad.RadioMsg(squadID, senderPly, message)
    local squad = HL2RP.Squad.Squads[squadID]
    if not squad then return end

    local senderName = senderPly and senderPly:GetCharacter() and
        senderPly:GetCharacter():GetName() or "[SQUAD]"

    for ply, _ in pairs(squad.members) do
        if IsValid(ply) then
            net.Start("HL2RP_SquadRadio")
                net.WriteString(senderName)
                net.WriteString(message)
            net.Send(ply)
        end
    end
end

-- ============================================================
-- ISSUE ORDER
-- ============================================================

HL2RP.Squad.OrderTypes = {
    advance  = { label = "ADVANCE",   color = Color(80,  200, 120), desc = "Move to marked position." },
    hold     = { label = "HOLD",      color = Color(220, 200, 60),  desc = "Hold current position." },
    retreat  = { label = "RETREAT",   color = Color(220, 80,  60),  desc = "Fall back immediately." },
    search   = { label = "SEARCH",    color = Color(80,  160, 220), desc = "Search the area thoroughly." },
    arrest   = { label = "ARREST",    color = Color(220, 140, 40),  desc = "Detain target on sight." },
    lethal   = { label = "LETHAL",    color = Color(200, 40,  40),  desc = "Lethal force authorised." },
    regroup  = { label = "REGROUP",   color = Color(160, 120, 220), desc = "All units return to leader." },
    cover    = { label = "COVER",     color = Color(120, 180, 220), desc = "Provide covering fire/position." },
}

function HL2RP.Squad.IssueOrder(leaderPly, orderType, detail)
    local squadID = leaderPly:GetCharacter() and leaderPly:GetCharacter():GetVar("squadID")
    if not squadID then return HL2RP.Notify(leaderPly, "Not in a squad.", "error") end

    local squad = HL2RP.Squad.Squads[squadID]
    if not squad or squad.leader ~= leaderPly then
        return HL2RP.Notify(leaderPly, "Only squad leader can issue orders.", "error")
    end

    local order = HL2RP.Squad.OrderTypes[orderType]
    if not order then return HL2RP.Notify(leaderPly, "Unknown order type.", "error") end

    local orderMsg = string.format("[ORDER: %s] %s — %s", order.label,
        order.desc, detail or "")

    for ply, _ in pairs(squad.members) do
        if IsValid(ply) then
            net.Start("HL2RP_SquadOrder")
                net.WriteString(order.label)
                net.WriteString(detail or order.desc)
                net.WriteColor(order.color)
            net.Send(ply)
        end
    end

    table.insert(squad.orders, { type = orderType, detail = detail, time = os.date("%H:%M") })
    HL2RP.Log("COMBINE", leaderPly:Name(), "SquadOrder", squadID, orderType)
end

-- ============================================================
-- SET ROLE
-- ============================================================

function HL2RP.Squad.SetRole(leaderPly, targetPly, role)
    local squadID = leaderPly:GetCharacter() and leaderPly:GetCharacter():GetVar("squadID")
    if not squadID then return HL2RP.Notify(leaderPly, "Not in a squad.", "error") end

    local squad = HL2RP.Squad.Squads[squadID]
    if not squad or squad.leader ~= leaderPly then
        return HL2RP.Notify(leaderPly, "Only leader can assign roles.", "error")
    end

    if not squad.members[targetPly] then
        return HL2RP.Notify(leaderPly, "Player not in your squad.", "error")
    end

    if not HL2RP.Squad.Roles[role] then
        return HL2RP.Notify(leaderPly, "Invalid role.", "error")
    end

    squad.members[targetPly] = role
    HL2RP.Notify(targetPly, string.format("Your squad role is now: %s",
        HL2RP.Squad.Roles[role].label), "info")
    HL2RP.Squad.BroadcastHUD(squadID)
    HL2RP.Squad.RadioMsg(squadID, nil, string.format("%s assigned as %s.",
        targetPly:GetCharacter():GetName(), HL2RP.Squad.Roles[role].label))
end

-- ============================================================
-- BROADCAST HUD DATA TO ALL MEMBERS
-- ============================================================

function HL2RP.Squad.BroadcastHUD(squadID)
    local squad = HL2RP.Squad.Squads[squadID]
    if not squad then return end

    for ply, _ in pairs(squad.members) do
        if not IsValid(ply) then continue end

        local memberData = {}
        for mPly, role in pairs(squad.members) do
            if IsValid(mPly) and mPly:GetCharacter() then
                local roleData = HL2RP.Squad.Roles[role] or HL2RP.Squad.Roles.point
                table.insert(memberData, {
                    name  = mPly:GetCharacter():GetName(),
                    role  = roleData.label,
                    hp    = mPly:Health(),
                    color = { r = roleData.color.r, g = roleData.color.g, b = roleData.color.b },
                    isMe  = mPly == ply,
                })
            end
        end

        net.Start("HL2RP_SquadHUD")
            net.WriteString(squad.name)
            net.WriteString(util.TableToJSON(memberData))
        net.Send(ply)
    end
end

-- Periodic HUD refresh (HP updates)
timer.Create("HL2RP_SquadHUDRefresh", 3, 0, function()
    for squadID, _ in pairs(HL2RP.Squad.Squads) do
        HL2RP.Squad.BroadcastHUD(squadID)
    end
end)

-- Utility
function HL2RP.Squad.GetSquad(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return nil end
    local squadID = ply:GetCharacter():GetVar("squadID")
    return squadID and HL2RP.Squad.Squads[squadID] or nil
end

-- Clean up on disconnect
hook.Add("PlayerDisconnected", "HL2RP_SquadLeaveOnDisconnect", function(ply)
    if IsValid(ply) and ply:GetCharacter() and ply:GetCharacter():GetVar("squadID") then
        HL2RP.Squad.Leave(ply)
    end
end)

-- ============================================================
-- COMMANDS
-- ============================================================

nut.command.add("squadform", {
    syntax = "<name>",
    desc   = "Form a new squad (Senior CP+).",
    onRun  = function(ply, args)
        HL2RP.Squad.Form(ply, table.concat(args, " "))
    end
})

nut.command.add("squadinvite", {
    syntax = "<player>",
    desc   = "Invite a CP/OTA player to your squad.",
    onRun  = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then return HL2RP.Notify(ply, "Player not found.", "error") end
        HL2RP.Squad.Invite(ply, target)
    end
})

nut.command.add("squadaccept", {
    desc = "Accept a squad invite.",
    onRun = function(ply) HL2RP.Squad.Accept(ply) end
})

nut.command.add("squadleave", {
    desc = "Leave your current squad.",
    onRun = function(ply) HL2RP.Squad.Leave(ply) end
})

nut.command.add("squaddisband", {
    desc = "Disband your squad (leader only).",
    onRun = function(ply)
        local squad = HL2RP.Squad.GetSquad(ply)
        if not squad then return HL2RP.Notify(ply, "Not in a squad.", "error") end
        if squad.leader ~= ply then return HL2RP.Notify(ply, "Leader only.", "error") end
        HL2RP.Squad.Disband(squad.id)
    end
})

nut.command.add("squadorder", {
    syntax = "<order> [detail]",
    desc   = "Issue an order to your squad. Orders: advance/hold/retreat/search/arrest/lethal/regroup/cover",
    onRun  = function(ply, args)
        local orderType = args[1]
        local detail    = table.concat(args, " ", 2)
        HL2RP.Squad.IssueOrder(ply, orderType, detail)
    end
})

nut.command.add("squadrole", {
    syntax = "<player> <role>",
    desc   = "Assign a role to a squad member.",
    onRun  = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then return HL2RP.Notify(ply, "Player not found.", "error") end
        HL2RP.Squad.SetRole(ply, target, args[2])
    end
})

nut.command.add("sq", {
    syntax = "<message>",
    desc   = "Send a squad radio message.",
    onRun  = function(ply, args)
        local squad = HL2RP.Squad.GetSquad(ply)
        if not squad then return HL2RP.Notify(ply, "Not in a squad.", "error") end
        HL2RP.Squad.RadioMsg(squad.id, ply, table.concat(args, " "))
    end
})

nut.command.add("squadstatus", {
    desc = "View your squad status.",
    onRun = function(ply)
        local squad = HL2RP.Squad.GetSquad(ply)
        if not squad then return HL2RP.Notify(ply, "Not in a squad.", "error") end
        ply:ChatPrint("=== SQUAD: " .. squad.name .. " ===")
        for mPly, role in pairs(squad.members) do
            if IsValid(mPly) and mPly:GetCharacter() then
                ply:ChatPrint(string.format("  [%s] %s — HP: %d",
                    HL2RP.Squad.Roles[role] and HL2RP.Squad.Roles[role].label or role,
                    mPly:GetCharacter():GetName(), mPly:Health()))
            end
        end
    end
})
