--[[
    plugins/needs_system/cl/cl_needs_hud.lua
    Client-side HUD for the needs system.
    Renders a subtle side panel showing nutrition, hydration,
    fatigue, and stress bars in a lore-fitting aesthetic.
--]]

local needsData = {}

-- Receive need updates from server
net.Receive("HL2RP_NeedsSync", function()
    local key   = net.ReadString()
    local value = net.ReadFloat()
    needsData[key] = value
end)

-- ============================================================
-- HUD RENDERING
-- ============================================================
local PANEL_W       = 140
local PANEL_H       = 110
local BAR_H         = 10
local BAR_SPACING   = 22
local PANEL_ALPHA   = nut.config.get("needsHUDAlpha") or 200
local FONT_LABEL    = "Trebuchet18"  -- Adjust to your server's registered fonts

local COLOR_BG      = Color(10, 10, 14, PANEL_ALPHA)
local COLOR_BORDER  = Color(60, 80, 100, 180)
local COLOR_LABEL   = Color(180, 190, 200)
local COLOR_WARN    = Color(220, 160, 60)
local COLOR_CRIT    = Color(220, 60, 60)

local function GetBarColor(need, value)
    local thresh = HL2RP.Needs.DebuffThresholds[need.key]
    if not thresh then return need.color end

    if need.invert then
        if value >= thresh.critical then return COLOR_CRIT end
        if value >= thresh.severe   then return COLOR_WARN end
    else
        if value <= thresh.critical then return COLOR_CRIT end
        if value <= thresh.severe   then return COLOR_WARN end
    end

    return need.color
end

hook.Add("HUDPaint", "HL2RP_NeedsHUD", function()
    if not nut.config.get("needsEnabled") then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetCharacter() then return end

    local sw, sh = ScrW(), ScrH()
    local px = sw - PANEL_W - 10
    local py = sh - PANEL_H - 80   -- Above the standard HUD area

    -- Background panel
    draw.RoundedBox(4, px, py, PANEL_W, PANEL_H, COLOR_BG)
    surface.SetDrawColor(COLOR_BORDER)
    surface.DrawOutlinedRect(px, py, PANEL_W, PANEL_H, 1)

    -- Title
    draw.SimpleText("BIOMETRIC STATUS", "DermaDefault", px + PANEL_W / 2, py + 5,
        Color(100, 140, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    -- Draw each need bar
    for i, need in ipairs(HL2RP.Needs.Types) do
        local val = needsData[need.key] or 100
        local bx  = px + 6
        local by  = py + 18 + (i - 1) * BAR_SPACING
        local bw  = PANEL_W - 12

        -- Label
        draw.SimpleText(need.label, "DermaDefault", bx, by, COLOR_LABEL)

        -- Bar background
        surface.SetDrawColor(30, 30, 40, 200)
        surface.DrawRect(bx, by + 11, bw, BAR_H)

        -- Bar fill
        local fillPct
        if need.invert then
            fillPct = 1 - (val / 100)   -- Inverted: full bar = bad
        else
            fillPct = val / 100
        end

        local barColor = GetBarColor(need, val)
        surface.SetDrawColor(barColor.r, barColor.g, barColor.b, 220)
        surface.DrawRect(bx, by + 11, math.floor(bw * fillPct), BAR_H)

        -- Critical flash
        if (not need.invert and val <= 10) or (need.invert and val >= 95) then
            if (CurTime() % 1) > 0.5 then
                surface.SetDrawColor(220, 60, 60, 80)
                surface.DrawRect(bx, by + 11, bw, BAR_H)
            end
        end
    end
end)

-- ============================================================
-- SCREEN EFFECT: Stress / Exhaustion vignette
-- ============================================================
hook.Add("RenderScreenspaceEffects", "HL2RP_NeedsVignette", function()
    local fatigue = needsData["fatigue"] or 0
    local stress  = needsData["stress"]  or 0

    if fatigue < 75 and stress < 70 then return end

    local maxEffect = math.max(
        math.Clamp((fatigue - 75) / 25, 0, 1),
        math.Clamp((stress - 70) / 30, 0, 1)
    )

    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = -0.05 * maxEffect,
        ["$pp_colour_contrast"]   = 1 + 0.1 * maxEffect,
        ["$pp_colour_colour"]     = 1 - 0.4 * maxEffect,
    })
end)
