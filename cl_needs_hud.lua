--[[
    schema/ui/cl_mainhud.lua
    MAIN HUD — City 45 HL2RP
    ============================================================
    Lore-fitting HUD replacing default GMod elements.
    Shows: Health, Armor, Needs, Character Name, Faction,
    Tension indicator, Curfew status, Detention status,
    Active task, Wanted status.
    Combine aesthetic: clean, angular, muted blue-grey.
    ============================================================
--]]

-- ============================================================
-- SUPPRESS DEFAULT HUD ELEMENTS
-- ============================================================
local HIDE_HUD = {
    ["CHudHealth"]      = true,
    ["CHudBattery"]     = true,
    ["CHudAmmo"]        = true,
    ["CHudSecondaryAmmo"]= true,
    ["CHudCrosshair"]   = true,
}

hook.Add("HUDShouldDraw", "HL2RP_HideDefault", function(name)
    if HIDE_HUD[name] then return false end
end)

-- ============================================================
-- FONTS
-- ============================================================
surface.CreateFont("HL2RP_HUD_Title", { font = "Trebuchet MS", size = 14, weight = 600 })
surface.CreateFont("HL2RP_HUD_Small", { font = "Trebuchet MS", size = 11, weight = 400 })
surface.CreateFont("HL2RP_HUD_Tiny",  { font = "Trebuchet MS", size = 10, weight = 300 })
surface.CreateFont("HL2RP_Dispatch",  { font = "Courier New",  size = 13, weight = 500 })
surface.CreateFont("HL2RP_Tension",   { font = "Trebuchet MS", size = 16, weight = 700 })

-- ============================================================
-- COLORS
-- ============================================================
local C_BG        = Color(8,  12, 18, 200)
local C_BORDER    = Color(40, 70, 110, 180)
local C_ACCENT    = Color(60, 130, 200)
local C_HEALTH_H  = Color(80, 200, 120)
local C_HEALTH_M  = Color(200, 180, 60)
local C_HEALTH_L  = Color(200, 60, 60)
local C_ARMOR     = Color(80, 140, 220)
local C_TEXT      = Color(190, 200, 215)
local C_DIM       = Color(120, 130, 145)
local C_DANGER    = Color(220, 60, 60)
local C_CURFEW    = Color(200, 160, 40)

-- ============================================================
-- CLIENT STATE
-- ============================================================
local tensionValue  = 0
local isCurfew      = false
local isDetained    = false
local activeTask    = nil
local isWanted      = false

net.Receive("HL2RP_TensionUpdate", function()
    tensionValue = net.ReadFloat()
end)

-- ============================================================
-- HELPERS
-- ============================================================

local function DrawRoundBar(x, y, w, h, fraction, barColor, bgColor)
    bgColor = bgColor or Color(20, 25, 35, 180)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(x, y, w, h)
    if fraction > 0 then
        surface.SetDrawColor(barColor)
        surface.DrawRect(x, y, math.floor(w * math.Clamp(fraction, 0, 1)), h)
    end
    surface.SetDrawColor(C_BORDER)
    surface.DrawOutlinedRect(x, y, w, h, 1)
end

-- ============================================================
-- MAIN HUD PAINT
-- ============================================================
hook.Add("HUDPaint", "HL2RP_MainHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetCharacter() then return end

    local sw, sh = ScrW(), ScrH()
    local char   = ply:GetCharacter()

    -- --------------------------------------------------------
    -- BOTTOM LEFT: Health & Armor
    -- --------------------------------------------------------
    local bx, by = 10, sh - 90
    local bw, bh = 200, 80

    surface.SetDrawColor(C_BG)
    surface.DrawRect(bx, by, bw, bh)
    surface.SetDrawColor(C_BORDER)
    surface.DrawOutlinedRect(bx, by, bw, bh, 1)

    -- Character name
    draw.SimpleText(char:GetName(), "HL2RP_HUD_Title",
        bx + 6, by + 5, C_TEXT, TEXT_ALIGN_LEFT)

    -- Faction + Rank
    local faction  = HL2RP.GetFaction(ply)
    local fLabel   = faction and faction.name or "Unknown"
    local rankName = HL2RP.GetRankName(ply)
    draw.SimpleText(fLabel .. " — " .. rankName, "HL2RP_HUD_Small",
        bx + 6, by + 20, C_DIM, TEXT_ALIGN_LEFT)

    -- Health bar
    local hp     = ply:Health()
    local maxHp  = ply:GetMaxHealth()
    local hpFrac = hp / math.max(1, maxHp)
    local hpCol  = hpFrac > 0.6 and C_HEALTH_H or hpFrac > 0.3 and C_HEALTH_M or C_HEALTH_L

    draw.SimpleText("HP", "HL2RP_HUD_Small", bx + 6, by + 36, C_DIM)
    DrawRoundBar(bx + 30, by + 37, bw - 36, 10, hpFrac, hpCol)
    draw.SimpleText(hp, "HL2RP_HUD_Tiny", bx + bw - 30, by + 37, C_TEXT, TEXT_ALIGN_RIGHT)

    -- Armor bar
    local ar     = ply:Armor()
    local arFrac = ar / 100
    draw.SimpleText("AR", "HL2RP_HUD_Small", bx + 6, by + 52, C_DIM)
    DrawRoundBar(bx + 30, by + 53, bw - 36, 10, arFrac, C_ARMOR)
    draw.SimpleText(ar, "HL2RP_HUD_Tiny", bx + bw - 30, by + 53, C_TEXT, TEXT_ALIGN_RIGHT)

    -- --------------------------------------------------------
    -- BOTTOM LEFT (above health): Active task
    -- --------------------------------------------------------
    if activeTask then
        local tx, ty = bx, by - 28
        surface.SetDrawColor(C_BG)
        surface.DrawRect(tx, ty, bw, 24)
        surface.SetDrawColor(C_BORDER)
        surface.DrawOutlinedRect(tx, ty, bw, 24, 1)
        draw.SimpleText("TASK: " .. activeTask, "HL2RP_HUD_Small",
            tx + 6, ty + 5, Color(220, 200, 80))
    end

    -- --------------------------------------------------------
    -- TOP CENTER: Tension meter
    -- --------------------------------------------------------
    local tw  = 220
    local tx  = (sw / 2) - (tw / 2)
    local ty  = 10

    local tensionState = HL2RP.Tension and HL2RP.Tension.GetState() or
        { label = "STABLE", color = Color(60, 200, 100) }
    local tensionFrac  = tensionValue / 100

    surface.SetDrawColor(C_BG)
    surface.DrawRect(tx, ty, tw, 32)
    surface.SetDrawColor(C_BORDER)
    surface.DrawOutlinedRect(tx, ty, tw, 32, 1)

    -- Tension bar
    DrawRoundBar(tx + 4, ty + 18, tw - 8, 8, tensionFrac, tensionState.color)

    -- Label
    draw.SimpleText("CITY TENSION: " .. tensionState.label, "HL2RP_HUD_Title",
        tx + tw / 2, ty + 4, tensionState.color, TEXT_ALIGN_CENTER)

    -- --------------------------------------------------------
    -- TOP RIGHT: Curfew + detained status
    -- --------------------------------------------------------
    local sx = sw - 180
    local sy = 10

    -- Curfew indicator
    if HL2RP.IsCurfew and HL2RP.IsCurfew() then
        surface.SetDrawColor(Color(40, 30, 10, 200))
        surface.DrawRect(sx, sy, 170, 22)
        draw.SimpleText("⚠ CURFEW IN EFFECT", "HL2RP_HUD_Small",
            sx + 85, sy + 4, C_CURFEW, TEXT_ALIGN_CENTER)
        sy = sy + 28
    end

    -- Detained indicator
    if char:GetVar("detained") then
        surface.SetDrawColor(Color(40, 10, 10, 220))
        surface.DrawRect(sx, sy, 170, 22)
        draw.SimpleText("⚠ DETAINED", "HL2RP_HUD_Small",
            sx + 85, sy + 4, C_DANGER, TEXT_ALIGN_CENTER)
        sy = sy + 28
    end

    -- Wanted indicator
    if isWanted then
        if (CurTime() % 1) > 0.5 then  -- Flash
            surface.SetDrawColor(Color(60, 10, 10, 220))
            surface.DrawRect(sx, sy, 170, 22)
        end
        draw.SimpleText("⚠ WARRANT ACTIVE", "HL2RP_HUD_Small",
            sx + 85, sy + 4, C_DANGER, TEXT_ALIGN_CENTER)
    end

    -- --------------------------------------------------------
    -- CID display (bottom right, very subtle)
    -- --------------------------------------------------------
    local cid = char:GetVar("cid") or ""
    draw.SimpleText(cid, "HL2RP_HUD_Tiny",
        sw - 10, sh - 10, C_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end)

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================

local notifications = {}
local NOTIF_DURATION = 5

local NOTIF_STYLES = {
    info    = { bg = Color(20, 40, 70, 220),   border = Color(60,  120, 200), icon = "ℹ" },
    success = { bg = Color(20, 50, 30, 220),   border = Color(60,  180, 100), icon = "✓" },
    warning = { bg = Color(50, 40, 10, 220),   border = Color(200, 160, 40),  icon = "⚠" },
    error   = { bg = Color(60, 15, 15, 230),   border = Color(200, 60,  60),  icon = "✗" },
    combine = { bg = Color(10, 30, 60, 230),   border = Color(60,  140, 220), icon = "▶" },
}

net.Receive("HL2RP_Notify", function()
    local msg      = net.ReadString()
    local notifType= net.ReadString()
    table.insert(notifications, {
        msg     = msg,
        type    = notifType,
        expires = CurTime() + NOTIF_DURATION,
        created = CurTime(),
    })
    if #notifications > 6 then table.remove(notifications, 1) end
end)

hook.Add("HUDPaint", "HL2RP_Notifications", function()
    local sw, sh = ScrW(), ScrH()
    local now    = CurTime()
    local y      = sh - 200

    for i = #notifications, 1, -1 do
        local n = notifications[i]
        if n.expires < now then
            table.remove(notifications, i)
        else
            local style   = NOTIF_STYLES[n.type] or NOTIF_STYLES.info
            local age     = now - n.created
            local fade    = math.min(1, age / 0.2)   -- Fade in
            local fadeOut = math.max(0, (n.expires - now) / 1.0)  -- Fade out
            local alpha   = math.floor(255 * math.min(fade, fadeOut))

            local nw = 340
            local nh = 26
            local nx = sw - nw - 12

            surface.SetDrawColor(style.bg.r, style.bg.g, style.bg.b, alpha)
            surface.DrawRect(nx, y, nw, nh)
            surface.SetDrawColor(style.border.r, style.border.g, style.border.b, alpha)
            surface.DrawOutlinedRect(nx, y, nw, nh, 1)
            -- Accent strip
            surface.SetDrawColor(style.border.r, style.border.g, style.border.b, alpha)
            surface.DrawRect(nx, y, 3, nh)

            draw.SimpleText(style.icon .. " " .. n.msg, "HL2RP_HUD_Small",
                nx + 10, y + 6, Color(210, 215, 225, alpha), TEXT_ALIGN_LEFT)

            y = y - nh - 4
        end
    end
end)

-- ============================================================
-- DISPATCH OVERLAY (brief full-screen text)
-- ============================================================

local dispatchMessages = {}
local DISPATCH_DURATION = 10

net.Receive("HL2RP_Dispatch", function()
    local msg      = net.ReadString()
    local category = net.ReadString()
    table.insert(dispatchMessages, {
        msg      = msg,
        category = category,
        expires  = CurTime() + DISPATCH_DURATION,
    })
    if #dispatchMessages > 3 then table.remove(dispatchMessages, 1) end
end)

hook.Add("HUDPaint", "HL2RP_DispatchOverlay", function()
    local now = CurTime()
    local sw  = ScrW()
    local y   = 60

    for i = #dispatchMessages, 1, -1 do
        local d = dispatchMessages[i]
        if d.expires < now then
            table.remove(dispatchMessages, i)
        else
            local remaining = d.expires - now
            local alpha     = math.min(255, remaining < 2 and remaining * 127 or 220)

            -- Background bar
            local tw = math.min(sw - 40, #d.msg * 7 + 20)
            local x  = (sw / 2) - (tw / 2)

            surface.SetDrawColor(10, 15, 30, math.floor(alpha * 0.85))
            surface.DrawRect(x, y, tw, 22)
            surface.SetDrawColor(60, 100, 160, alpha)
            surface.DrawOutlinedRect(x, y, tw, 22, 1)

            draw.SimpleText(d.msg, "HL2RP_Dispatch",
                sw / 2, y + 3, Color(180, 210, 255, alpha), TEXT_ALIGN_CENTER)

            y = y + 28
        end
    end
end)
