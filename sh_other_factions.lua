--[[
    plugins/radio_comms/cl/cl_radio.lua
    Client-side radio message display.
    Shows incoming radio messages with channel color coding.
    Scrambled channels display as static.
--]]

local radioMessages = {}     -- Recent messages for display
local MAX_MESSAGES  = 6
local DISPLAY_TIME  = 8      -- Seconds each message is visible

local function AddRadioMessage(prefix, body, color, scrambled)
    if scrambled then
        -- Replace with static noise
        body   = string.rep("█▒░", math.random(8, 16))
        prefix = "[???]"
        color  = Color(100, 100, 100)
    end

    table.insert(radioMessages, {
        prefix  = prefix,
        body    = body,
        color   = color,
        expires = CurTime() + DISPLAY_TIME,
    })

    -- Cap list
    if #radioMessages > MAX_MESSAGES then
        table.remove(radioMessages, 1)
    end

    -- Also print to chat
    chat.AddText(color, prefix .. ": ", Color(220, 220, 220), body)
end

net.Receive("HL2RP_RadioMessage", function()
    local prefix   = net.ReadString()
    local body     = net.ReadString()
    local color    = net.ReadColor()
    local scrambled= net.ReadBool()
    AddRadioMessage(prefix, body, color, scrambled)
end)

-- ============================================================
-- HUD: Radio message feed (top-left, subtle)
-- ============================================================
local FEED_X    = 10
local FEED_Y    = 200
local FEED_W    = 380
local LINE_H    = 18
local FADE_TIME = 1.5

hook.Add("HUDPaint", "HL2RP_RadioFeed", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetCharacter() then return end

    local now = CurTime()
    local y   = FEED_Y

    for i = #radioMessages, 1, -1 do
        local msg = radioMessages[i]
        if msg.expires < now then
            table.remove(radioMessages, i)
        else
            -- Fade calculation
            local remaining = msg.expires - now
            local alpha     = math.min(255, remaining < FADE_TIME and (remaining / FADE_TIME) * 255 or 255)

            -- Background
            surface.SetDrawColor(10, 12, 18, math.floor(alpha * 0.7))
            surface.DrawRect(FEED_X, y, FEED_W, LINE_H)

            -- Channel prefix
            draw.SimpleText(msg.prefix .. ": ",
                "DermaDefault", FEED_X + 4, y + 2,
                Color(msg.color.r, msg.color.g, msg.color.b, alpha),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            -- Body
            local prefixW = surface.GetTextSize(msg.prefix .. ": ")
            draw.SimpleText(msg.body,
                "DermaDefault", FEED_X + 4 + prefixW, y + 2,
                Color(210, 215, 220, alpha),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            y = y + LINE_H + 2
        end
    end
end)

-- ============================================================
-- Active channel indicator (bottom HUD)
-- ============================================================
net.Receive("HL2RP_RadioChannelSync", function()
    local channelID = net.ReadString()
    -- Store locally for display
    LocalPlayer().HL2RP_ActiveChannel = channelID
end)

hook.Add("HUDPaint", "HL2RP_RadioChannelIndicator", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetCharacter() then return end
    if not HL2RP.Radio.HasRadio(ply) then return end

    local chID  = ply.HL2RP_ActiveChannel or "OPEN_1"
    local ch    = HL2RP.Radio and HL2RP.Radio.ChannelMap and HL2RP.Radio.ChannelMap[chID]
    local label = ch and ch.label or chID

    local sw    = ScrW()
    local x, y  = sw - 200, 60
    surface.SetDrawColor(10, 12, 18, 160)
    surface.DrawRect(x, y, 190, 20)
    draw.SimpleText("📻 " .. label, "DermaDefault", x + 6, y + 3,
        ch and ch.color or Color(180, 200, 180), TEXT_ALIGN_LEFT)
end)
