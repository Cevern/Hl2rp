--[[
    plugins/squad_system/cl/cl_squad.lua
    SQUAD HUD + RADIO
    Shows squad member list, HP bars, roles, and incoming orders.
--]]

local squadName   = nil
local squadMembers= {}
local pendingOrder= nil
local orderExpires= 0

net.Receive("HL2RP_SquadHUD", function()
    squadName    = net.ReadString()
    squadMembers = util.JSONToTable(net.ReadString()) or {}
end)

net.Receive("HL2RP_SquadRadio", function()
    local sender  = net.ReadString()
    local message = net.ReadString()
    chat.AddText(Color(80, 180, 220), "[SQ] ", Color(180, 220, 255), sender .. ": ", Color(220, 230, 240), message)
end)

net.Receive("HL2RP_SquadOrder", function()
    local label   = net.ReadString()
    local detail  = net.ReadString()
    local color   = net.ReadColor()
    pendingOrder  = { label = label, detail = detail, color = color }
    orderExpires  = CurTime() + 12
    surface.PlaySound("buttons/button14.wav")
end)

-- ============================================================
-- SQUAD MEMBER HUD  (right side panel)
-- ============================================================

hook.Add("HUDPaint", "HL2RP_SquadPanel", function()
    if not squadName or #squadMembers == 0 then return end

    local sw    = ScrW()
    local bx    = sw - 195
    local by    = 130
    local bw    = 185
    local entry = 36

    -- Panel background
    surface.SetDrawColor(8, 12, 20, 200)
    surface.DrawRect(bx - 4, by - 4, bw + 8, #squadMembers * entry + 28)
    surface.SetDrawColor(40, 80, 160, 180)
    surface.DrawOutlinedRect(bx - 4, by - 4, bw + 8, #squadMembers * entry + 28, 1)

    draw.SimpleText(squadName, "HL2RP_HUD_Title",
        bx + bw/2, by - 1, Color(140, 180, 255), TEXT_ALIGN_CENTER)

    local y = by + 18
    for _, m in ipairs(squadMembers) do
        local col = Color(m.color.r, m.color.g, m.color.b)
        local hp  = math.Clamp(m.hp or 0, 0, 100)

        -- Role colour strip
        surface.SetDrawColor(col.r, col.g, col.b, 160)
        surface.DrawRect(bx, y, 3, entry - 4)

        -- Name
        local nameCol = m.isMe and Color(220, 240, 255) or Color(175, 185, 200)
        draw.SimpleText(m.name, "HL2RP_HUD_Small", bx + 8, y + 2, nameCol)
        draw.SimpleText(m.role, "HL2RP_HUD_Tiny",  bx + 8, y + 16, Color(col.r, col.g, col.b, 200))

        -- HP bar
        local barW = bw - 20
        surface.SetDrawColor(20, 25, 35, 200)
        surface.DrawRect(bx + 8, y + 27, barW, 5)
        local hpCol = hp > 60 and Color(60, 200, 80) or hp > 30 and Color(200, 180, 40) or Color(200, 60, 60)
        surface.SetDrawColor(hpCol)
        surface.DrawRect(bx + 8, y + 27, math.floor(barW * (hp/100)), 5)

        y = y + entry
    end

    -- Order banner
    if pendingOrder and CurTime() < orderExpires then
        local fade = math.min(1, (orderExpires - CurTime()) / 2)
        local a    = math.floor(fade * 255)
        local oc   = pendingOrder.color
        local ox   = sw/2
        local oy   = 55

        surface.SetDrawColor(10, 14, 25, a)
        surface.DrawRect(ox - 220, oy, 440, 46)
        surface.SetDrawColor(oc.r, oc.g, oc.b, a)
        surface.DrawRect(ox - 220, oy, 440, 3)
        surface.DrawOutlinedRect(ox - 220, oy, 440, 46, 1)

        draw.SimpleText("ORDER: " .. pendingOrder.label, "HL2RP_HUD_Title",
            ox, oy + 5, Color(oc.r, oc.g, oc.b, a), TEXT_ALIGN_CENTER)
        draw.SimpleText(pendingOrder.detail, "HL2RP_HUD_Small",
            ox, oy + 24, Color(200, 210, 230, a), TEXT_ALIGN_CENTER)
    end
end)
