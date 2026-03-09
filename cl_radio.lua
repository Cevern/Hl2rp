--[[
    libs/sh_util.lua
    Shared utility library for City 45 HL2RP
    Helper functions used across all modules.
--]]

HL2RP = HL2RP or {}

-- ============================================================
-- STRING HELPERS
-- ============================================================

--- Truncate a string to maxLen, appending "..." if truncated.
function HL2RP.Truncate(str, maxLen)
    if #str <= maxLen then return str end
    return str:sub(1, maxLen - 3) .. "..."
end

--- Format credits with the currency symbol.
function HL2RP.FormatCredits(amount)
    return string.format("Ȼ%d", math.floor(amount))
end

--- Format a Unix timestamp into a readable date string.
function HL2RP.FormatDate(timestamp)
    return os.date("%Y-%m-%d %H:%M", timestamp)
end

--- Pad a string to a given width (left-align).
function HL2RP.PadRight(str, width, char)
    char = char or " "
    str = tostring(str)
    while #str < width do str = str .. char end
    return str
end

--- Format combine-style speech (uppercase + stutter codes).
function HL2RP.CombineFormat(msg)
    return "[" .. string.upper(msg) .. "]"
end

--- Format Vortigaunt speech flavor.
function HL2RP.VortigauntFormat(msg)
    -- Capitalize first letter, italicize flavor words
    return "~" .. msg:sub(1,1):upper() .. msg:sub(2) .. "~"
end

-- ============================================================
-- PERMISSION HELPERS
-- ============================================================

--- Check if a player has a given NutScript usergroup or higher.
local ranks = { user = 0, supporter = 1, vip = 2, moderator = 3, admin = 4, superadmin = 5 }
function HL2RP.HasRank(ply, minRank)
    local r = ranks[ply:GetUserGroup()] or 0
    local m = ranks[minRank] or 0
    return r >= m
end

--- Check if a player's active character belongs to a faction.
function HL2RP.InFaction(ply, factionID)
    if not IsValid(ply) or not ply:GetCharacter() then return false end
    return ply:GetCharacter():GetVar("faction") == factionID
end

--- Check if a player holds a valid permit of a given type.
function HL2RP.HasPermit(ply, permitType)
    if not IsValid(ply) or not ply:GetCharacter() then return false end
    local permits = ply:GetCharacter():GetVar("permits") or {}
    local p = permits[permitType]
    if not p then return false end
    -- Check expiry
    local expiry = nut.config.get("permitExpiry") or 0
    if expiry > 0 and (os.time() - (p.issued or 0)) > expiry * 3600 then
        return false, "expired"
    end
    return not p.forged, p.forged and "forged" or nil
end

--- Returns true if it is currently curfew time on the server.
function HL2RP.IsCurfew()
    local h = tonumber(os.date("%H"))
    local start = nut.config.get("curfewStartHour") or 22
    local stop  = nut.config.get("curfewEndHour")   or 6
    if start > stop then
        return h >= start or h < stop
    else
        return h >= start and h < stop
    end
end

-- ============================================================
-- FACTION UTILITIES
-- ============================================================

--- Get the faction table for a player's active character.
function HL2RP.GetFaction(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return nil end
    local fID = ply:GetCharacter():GetVar("faction")
    return nut.faction.get(fID)
end

--- Get the rank index for a player within their faction.
function HL2RP.GetRankIndex(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return 0 end
    return ply:GetCharacter():GetVar("rankIndex") or 0
end

--- Get the rank name for a player.
function HL2RP.GetRankName(ply)
    local faction = HL2RP.GetFaction(ply)
    if not faction then return "Unknown" end
    local idx = HL2RP.GetRankIndex(ply)
    local ranks = faction.ranks or {}
    return (ranks[idx + 1] and ranks[idx + 1].name) or "Recruit"
end

-- ============================================================
-- NOTIFICATION HELPERS
-- ============================================================
if SERVER then
    --- Send a themed notification to a player.
    --- notifType: "info", "warning", "error", "success", "combine"
    function HL2RP.Notify(ply, msg, notifType)
        notifType = notifType or "info"
        net.Start("HL2RP_Notify")
            net.WriteString(msg)
            net.WriteString(notifType)
        net.Send(ply)
    end

    --- Broadcast a message to all players in a radius.
    function HL2RP.NotifyRadius(origin, radius, msg, notifType)
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:GetPos():Distance(origin) <= radius then
                HL2RP.Notify(ply, msg, notifType)
            end
        end
    end

    --- Log an action to the admin log system.
    function HL2RP.Log(category, actor, action, target, detail)
        if HL2RP.Logger then
            HL2RP.Logger.Write(category, actor, action, target, detail)
        end
        local str = string.format("[%s][%s] Actor=%s Action=%s Target=%s | %s",
            os.date("%H:%M"), category, tostring(actor), action, tostring(target), detail or "")
        MsgC(Color(180, 220, 255), str .. "\n")
    end
end

-- ============================================================
-- CHARACTER DATA HELPERS
-- ============================================================

--- Safely get a character variable with fallback default.
function HL2RP.GetCharVar(ply, key, default)
    if not IsValid(ply) or not ply:GetCharacter() then return default end
    local v = ply:GetCharacter():GetVar(key)
    return (v ~= nil) and v or default
end

--- Safely set a character variable.
function HL2RP.SetCharVar(ply, key, value)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    ply:GetCharacter():SetVar(key, value)
end

-- ============================================================
-- TABLE UTILITIES
-- ============================================================

--- Deep copy a table.
function HL2RP.DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = (type(v) == "table") and HL2RP.DeepCopy(v) or v
    end
    return copy
end

--- Count entries in a hash table.
function HL2RP.TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- Weighted random selection from a table of {item, weight} pairs.
function HL2RP.WeightedRandom(pool)
    local total = 0
    for _, v in ipairs(pool) do total = total + (v[2] or 1) end
    local r = math.random() * total
    for _, v in ipairs(pool) do
        r = r - (v[2] or 1)
        if r <= 0 then return v[1] end
    end
    return pool[#pool][1]
end
