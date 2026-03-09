--[[
    plugins/radio_comms/sv/sv_radio.lua
    Server-side radio transmission handling.
--]]

util.AddNetworkString("HL2RP_RadioMessage")
util.AddNetworkString("HL2RP_RadioChannelSync")

-- ============================================================
-- SEND A RADIO MESSAGE
-- ============================================================

function HL2RP.Radio.Send(channelID, message, senderPly)
    local ch = HL2RP.Radio.ChannelMap[channelID]
    if not ch then return false end

    local senderName = "Unknown"
    local senderFaction = nil

    if IsValid(senderPly) and senderPly:GetCharacter() then
        senderName    = senderPly:GetCharacter():GetName()
        senderFaction = senderPly:GetCharacter():GetVar("faction")

        -- Must have a radio
        if not HL2RP.Radio.HasRadio(senderPly) then
            HL2RP.Notify(senderPly, "You need a radio to transmit.", "error")
            return false
        end
    end

    -- Build display string
    local prefix
    if ch.encrypted then
        prefix = string.format("[%s][ENCRYPTED] %s", ch.label, senderName)
    else
        prefix = string.format("[%s] %s", ch.label, senderName)
    end

    -- Range check for non-encrypted channels
    local rangeCheck = not ch.encrypted
    local range      = nut.config.get("radioRange") or 600

    -- Deliver to eligible players
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:GetCharacter() then continue end

        local plyChan = HL2RP.Radio.GetChannel(ply)
        if plyChan ~= channelID then continue end

        -- Faction check
        if ch.factionOnly then
            local fID    = ply:GetCharacter():GetVar("faction")
            local allowed = false
            for _, f in ipairs(ch.factionOnly) do
                if fID == f then allowed = true; break end
            end
            if not allowed then continue end
        end

        -- Range check for open channels
        if rangeCheck and IsValid(senderPly) then
            if ply:GetPos():Distance(senderPly:GetPos()) > range then continue end
        end

        -- Send the message
        net.Start("HL2RP_RadioMessage")
            net.WriteString(prefix)
            net.WriteString(message)
            net.WriteColor(ch.color or Color(180, 200, 180))
            net.WriteBool(ch.scrambled or false)
        net.Send(ply)
    end

    HL2RP.Log("RADIO", senderName, "Transmitted", channelID, message)
    return true
end

-- ============================================================
-- COMMANDS
-- ============================================================

nut.command.add("radio", {
    syntax  = "<message>",
    desc    = "Transmit on your active radio channel.",
    onRun   = function(ply, args)
        if not HL2RP.Radio.HasRadio(ply) then
            return HL2RP.Notify(ply, "You don't have a radio.", "error")
        end
        local msg     = table.concat(args, " ")
        local channel = HL2RP.Radio.GetChannel(ply)
        if not msg or #msg < 1 then return end
        HL2RP.Radio.Send(channel, msg, ply)
    end
})

nut.command.add("setchannel", {
    syntax  = "<channel_id>",
    desc    = "Switch your radio to a different channel.",
    onRun   = function(ply, args)
        if not HL2RP.Radio.HasRadio(ply) then
            return HL2RP.Notify(ply, "You don't have a radio.", "error")
        end
        local ok, err = HL2RP.Radio.SetChannel(ply, args[1])
        if ok then
            HL2RP.Notify(ply, "Radio channel set to: " .. (args[1] or ""), "info")
        else
            HL2RP.Notify(ply, "Failed: " .. (err or "unknown"), "error")
        end
    end
})

nut.command.add("channels", {
    desc  = "List available radio channels.",
    onRun = function(ply)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        ply:ChatPrint("=== RADIO CHANNELS ===")
        for _, ch in ipairs(HL2RP.Radio.Channels) do
            if ch.hidden then continue end  -- Skip hidden channels
            -- Only show faction channels if you're in that faction
            if ch.factionOnly then
                local show = false
                for _, f in ipairs(ch.factionOnly) do
                    if fID == f then show = true; break end
                end
                if not show and not HL2RP.HasRank(ply, "admin") then continue end
            end
            ply:ChatPrint(string.format("  [%-16s] %.1f MHz %s", ch.id, ch.frequency, ch.encrypted and "[ENC]" or ""))
        end
        ply:ChatPrint("Use /setchannel <id> to switch.")
    end
})

-- Dead drop note system (Resistance)
nut.command.add("dropenote", {
    syntax  = "<message>",
    desc    = "Leave an encrypted dead drop note at your location.",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if fID ~= "resistance" and fID ~= "smuggler" then
            return HL2RP.Notify(ply, "You don't know how to leave dead drops.", "error")
        end

        local inv = ply:GetCharacter():getInventory()
        if not inv or not inv:hasItem("dead_drop_container") then
            return HL2RP.Notify(ply, "You need a dead drop container.", "error")
        end

        local msg = table.concat(args, " ")
        if not msg or #msg < 3 then return end

        -- Store as world entity (simplified: stored as server data)
        local dropID  = "DROP_" .. tostring(os.time()) .. "_" .. math.random(1000, 9999)
        local pos     = ply:GetPos()

        HL2RP.Radio.DeadDrops = HL2RP.Radio.DeadDrops or {}
        HL2RP.Radio.DeadDrops[dropID] = {
            message   = msg,
            by        = ply:GetCharacter():GetName(),
            pos       = pos,
            createdAt = os.time(),
            faction   = fID,
        }

        inv:remove("dead_drop_container")
        HL2RP.Notify(ply, "Dead drop left at your location.", "success")
        HL2RP.Log("RESISTANCE", ply:Name(), "DeadDropLeft", dropID, msg)
    end
})

nut.command.add("collectdrop", {
    syntax  = "<drop_id>",
    desc    = "Collect a dead drop message.",
    onRun   = function(ply, args)
        local dropID = args[1]
        local drop   = HL2RP.Radio.DeadDrops and HL2RP.Radio.DeadDrops[dropID]

        if not drop then
            return HL2RP.Notify(ply, "No dead drop found with that ID.", "error")
        end

        -- Must be within range
        if ply:GetPos():Distance(drop.pos) > 100 then
            return HL2RP.Notify(ply, "You are not close enough to collect this drop.", "error")
        end

        ply:ChatPrint("=== DEAD DROP MESSAGE ===")
        ply:ChatPrint(drop.message)
        ply:ChatPrint("=========================")

        -- Remove after collection
        HL2RP.Radio.DeadDrops[dropID] = nil
        HL2RP.Log("RESISTANCE", ply:Name(), "DeadDropCollected", dropID, "")
    end
})
