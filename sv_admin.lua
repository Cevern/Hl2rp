--[[
    plugins/logging/sv/sv_logging.lua
    COMPREHENSIVE LOGGING SYSTEM
    ============================================================
    Logs all significant server actions to:
    - In-memory ring buffer (fast access for /adminlogs)
    - Flat file logs (persistent, organized by category)
    - Console output with color coding
    Categories: ECONOMY, ENFORCEMENT, PERMITS, DATAFILE,
    HOUSING, CRAFTING, BLACKMARKET, RESISTANCE, EVENTS,
    ADMIN, LABOR, RADIO, SUPPORTER, TENSION, AHELP
    ============================================================
--]]

HL2RP.Logger = HL2RP.Logger or {}

-- ============================================================
-- LOG CATEGORIES & COLORS
-- ============================================================

HL2RP.Logger.Categories = {
    ECONOMY     = Color(80,  200, 120),
    ENFORCEMENT = Color(80,  140, 220),
    PERMITS     = Color(200, 200, 100),
    DATAFILE    = Color(160, 200, 200),
    HOUSING     = Color(200, 160, 80),
    CRAFTING    = Color(140, 200, 160),
    BLACKMARKET = Color(160, 80,  200),
    RESISTANCE  = Color(200, 80,  80),
    EVENTS      = Color(220, 180, 60),
    ADMIN       = Color(255, 100, 100),
    LABOR       = Color(180, 200, 120),
    RADIO       = Color(100, 200, 200),
    SUPPORTER   = Color(200, 200, 255),
    TENSION     = Color(220, 130, 40),
    AHELP       = Color(255, 80,  80),
    CRIME       = Color(220, 60,  60),
    WARRANT     = Color(200, 100, 40),
    CONTRABAND  = Color(200, 80,  160),
}

-- ============================================================
-- RING BUFFER (in-memory)
-- ============================================================

local BUFFER_SIZE = 500
HL2RP.Logger.Buffer = {}

-- ============================================================
-- WRITE A LOG ENTRY
-- ============================================================

function HL2RP.Logger.Write(category, actor, action, target, detail)
    local timestamp = os.date("[%Y-%m-%d %H:%M:%S]")
    local entry = {
        timestamp = timestamp,
        category  = category or "GENERAL",
        actor     = actor or "system",
        action    = action or "unknown",
        target    = target or "unknown",
        detail    = detail or "",
    }

    -- Add to ring buffer
    table.insert(HL2RP.Logger.Buffer, entry)
    if #HL2RP.Logger.Buffer > BUFFER_SIZE then
        table.remove(HL2RP.Logger.Buffer, 1)
    end

    -- Console output with color
    local catColor = HL2RP.Logger.Categories[category] or Color(180, 180, 180)
    local line = string.format("%s [%-12s] Actor=%-16s Action=%-20s Target=%-16s | %s",
        timestamp, category, entry.actor, entry.action, entry.target, entry.detail)

    MsgC(catColor, line .. "\n")

    -- File output (organized by date)
    HL2RP.Logger.WriteFile(category, line)
end

-- ============================================================
-- FILE LOGGING
-- ============================================================

function HL2RP.Logger.WriteFile(category, line)
    local dateStr  = os.date("%Y-%m-%d")
    local filename = string.format("hl2rp_logs/%s_%s.log", category:lower(), dateStr)

    -- Ensure directory exists
    if not file.Exists("hl2rp_logs", "DATA") then
        file.CreateDir("hl2rp_logs")
    end

    local existing = ""
    if file.Exists(filename, "DATA") then
        existing = file.Read(filename, "DATA") or ""
    end

    file.Write(filename, existing .. line .. "\n")
end

-- ============================================================
-- QUERY BUFFER
-- ============================================================

function HL2RP.Logger.Query(filters)
    -- filters: { category, actor, action, target, limit }
    local results = {}
    local limit   = filters.limit or 50

    for i = #HL2RP.Logger.Buffer, 1, -1 do
        local entry = HL2RP.Logger.Buffer[i]
        local match = true

        if filters.category and entry.category ~= filters.category:upper() then match = false end
        if filters.actor    and not entry.actor:lower():find(filters.actor:lower()) then match = false end
        if filters.action   and not entry.action:lower():find(filters.action:lower()) then match = false end
        if filters.target   and not entry.target:lower():find(filters.target:lower()) then match = false end

        if match then
            table.insert(results, entry)
            if #results >= limit then break end
        end
    end

    return results
end

-- ============================================================
-- ADMIN LOG VIEWER COMMANDS
-- ============================================================

nut.command.add("adminlogs", {
    syntax  = "[category] [limit]",
    desc    = "View the admin log buffer. Optionally filter by category.",
    onRun   = function(ply, args)
        if not HL2RP.HasRank(ply, "moderator") then
            return HL2RP.Notify(ply, "Permission denied.", "error")
        end

        local category = args[1] and args[1]:upper() or nil
        local limit    = tonumber(args[2]) or 30

        local results = HL2RP.Logger.Query({ category = category, limit = limit })

        if #results == 0 then
            return HL2RP.Notify(ply, "No log entries found.", "info")
        end

        ply:ChatPrint(string.format("=== LOGS [%s] — Last %d entries ===",
            category or "ALL", #results))

        for _, entry in ipairs(results) do
            ply:ChatPrint(string.format("%s [%s] %s > %s on %s | %s",
                entry.timestamp, entry.category, entry.actor,
                entry.action, entry.target, entry.detail))
        end
    end
})

nut.command.add("playerlogs", {
    syntax  = "<player>",
    desc    = "View all log entries related to a specific player.",
    onRun   = function(ply, args)
        if not HL2RP.HasRank(ply, "moderator") then
            return HL2RP.Notify(ply, "Permission denied.", "error")
        end
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then
            return HL2RP.Notify(ply, "Player not found.", "error")
        end

        local name    = target:Name()
        local results = HL2RP.Logger.Query({ actor = name, limit = 50 })
        -- Also find as target
        local asTarget= HL2RP.Logger.Query({ target = name, limit = 50 })

        ply:ChatPrint("=== PLAYER LOGS: " .. name .. " ===")
        ply:ChatPrint("[AS ACTOR]")
        for _, e in ipairs(results) do
            ply:ChatPrint(string.format("  %s [%s] %s on %s", e.timestamp, e.category, e.action, e.target))
        end
        ply:ChatPrint("[AS TARGET]")
        for _, e in ipairs(asTarget) do
            ply:ChatPrint(string.format("  %s [%s] %s by %s", e.timestamp, e.category, e.action, e.actor))
        end
    end
})

nut.command.add("clearlogs", {
    desc    = "Clear the in-memory log buffer (does not delete files).",
    onRun   = function(ply)
        if not HL2RP.HasRank(ply, "superadmin") then
            return HL2RP.Notify(ply, "Permission denied.", "error")
        end
        HL2RP.Logger.Buffer = {}
        HL2RP.Notify(ply, "Log buffer cleared.", "info")
        HL2RP.Log("ADMIN", ply:Name(), "ClearedLogs", "buffer", "")
    end
})

-- ============================================================
-- CONNECT / DISCONNECT LOGGING
-- ============================================================

hook.Add("PlayerInitialSpawn", "HL2RP_LogConnect", function(ply)
    HL2RP.Logger.Write("ADMIN", ply:Name(), "Connected",
        ply:SteamID(), ply:IPAddress())
end)

hook.Add("PlayerDisconnected", "HL2RP_LogDisconnect", function(ply)
    HL2RP.Logger.Write("ADMIN", ply:Name(), "Disconnected",
        ply:SteamID(), "")
end)

-- ============================================================
-- SPAWN / ITEM LOGGING
-- ============================================================

hook.Add("HL2RP_AdminSpawnItem", "LogItemSpawn", function(staff, target, itemID)
    HL2RP.Logger.Write("ADMIN", staff:Name(), "SpawnedItem", target:Name(), itemID)
end)

hook.Add("HL2RP_ItemConsumed", "LogItemConsumed", function(ply, itemID)
    HL2RP.Logger.Write("LABOR", ply:Name(), "ItemConsumed", itemID, "")
end)
