--[[
    plugins/npcs_vendors/cl/cl_vendor_ui.lua
    CLIENT-SIDE VENDOR MENU
    ============================================================
    Renders interactive vendor panels when opened by server.
    Handles: food stall, permit office, bulletin board,
    fence, housing terminal.
    ============================================================
--]]

local activeVendorMenu = nil

-- ============================================================
-- OPEN VENDOR MENU
-- ============================================================

net.Receive("HL2RP_OpenVendorMenu", function()
    local vendorID = net.ReadString()
    HL2RP.OpenVendorMenu(vendorID)
end)

function HL2RP.OpenVendorMenu(vendorID)
    if IsValid(activeVendorMenu) then activeVendorMenu:Remove() end

    local frame = vgui.Create("DFrame")
    frame:SetSize(440, 520)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:MakePopup()
    activeVendorMenu = frame

    -- Custom paint
    frame.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(12, 16, 24, 240))
        draw.RoundedBox(4, 0, 0, w, 32, Color(20, 40, 80, 240))
        surface.SetDrawColor(40, 70, 120, 200)
        surface.DrawRect(0, 32, w, 1)
    end

    -- Title
    local title = vgui.Create("DLabel", frame)
    title:SetPos(12, 6)
    title:SetSize(420, 22)
    title:SetFont("HL2RP_HUD_Title")
    title:SetTextColor(Color(180, 210, 255))

    -- Content panel
    local content = vgui.Create("DScrollPanel", frame)
    content:SetPos(8, 40)
    content:SetSize(424, 468)

    if vendorID == "food_stall" then
        title:SetText("CWU Approved Food Stall")
        HL2RP.BuildShopPanel(content, vendorID, {
            { id = "protein_bar",  label = "Protein Bar",    price = 8,  desc = "High-protein ration supplement." },
            { id = "canned_beans", label = "Canned Beans",   price = 12, desc = "Standard caloric content. Filling." },
            { id = "stale_bread",  label = "Bread (Stale)",  price = 5,  desc = "Yesterday's allocation. Still edible." },
            { id = "water_bottle", label = "Water Bottle",   price = 6,  desc = "Filtered water. Approved by the CMA." },
        })

    elseif vendorID == "cwu_bulletin" then
        title:SetText("CWU Bulletin Board — Available Tasks")
        HL2RP.BuildBulletinPanel(content)

    elseif vendorID == "permit_office" then
        title:SetText("Civil Permit Office")
        HL2RP.BuildPermitPanel(content)

    elseif vendorID == "wasteland_fence" then
        title:SetText("... (Shady Vendor)")
        HL2RP.BuildShopPanel(content, vendorID, {
            { id = "contraband_alcohol",  label = "Contraband Spirits", price = 40,  desc = "Illegal. Worth it." },
            { id = "lockpick_set",        label = "Lockpicks",          price = 80,  desc = "Don't get caught." },
            { id = "rebel_pamphlet",      label = "Reading Material",   price = 20,  desc = "Very illegal." },
            { id = "illegal_ammo",        label = "Loose Rounds",       price = 60,  desc = "For the weapon you don't have." },
            { id = "encrypted_note_blank",label = "Blank Cipher Sheet", price = 25,  desc = "Write your own truth." },
        })

    else
        title:SetText("Terminal")
        local lbl = vgui.Create("DLabel", content)
        lbl:SetText("No menu available for this vendor.")
        lbl:SetTextColor(Color(180, 180, 180))
        lbl:SizeToContents()
    end

    -- Close button
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(400, 6)
    closeBtn:SetSize(32, 22)
    closeBtn:SetText("✕")
    closeBtn:SetFont("HL2RP_HUD_Small")
    closeBtn:SetTextColor(Color(200, 80, 80))
    closeBtn.Paint = function(s, w, h)
        if s:IsHovered() then
            draw.RoundedBox(2, 0, 0, w, h, Color(60, 20, 20, 200))
        end
    end
    closeBtn.DoClick = function() frame:Remove() end
end

-- ============================================================
-- SHOP PANEL BUILDER
-- ============================================================

function HL2RP.BuildShopPanel(parent, vendorID, items)
    local y = 4
    for _, item in ipairs(items) do
        local row = vgui.Create("DPanel", parent)
        row:SetPos(4, y)
        row:SetSize(410, 68)
        row.Paint = function(s, w, h)
            local bg = s:IsHovered() and Color(25, 45, 80, 200) or Color(15, 20, 35, 200)
            draw.RoundedBox(3, 0, 0, w, h, bg)
            surface.SetDrawColor(40, 60, 100, 120)
            surface.DrawRect(0, h - 1, w, 1)
        end

        local nameLabel = vgui.Create("DLabel", row)
        nameLabel:SetPos(10, 6)
        nameLabel:SetSize(260, 18)
        nameLabel:SetFont("HL2RP_HUD_Title")
        nameLabel:SetTextColor(Color(210, 220, 235))
        nameLabel:SetText(item.label)

        local priceLabel = vgui.Create("DLabel", row)
        priceLabel:SetPos(280, 6)
        priceLabel:SetSize(120, 18)
        priceLabel:SetFont("HL2RP_HUD_Title")
        priceLabel:SetTextColor(Color(100, 220, 140))
        priceLabel:SetText("Ȼ" .. item.price)
        priceLabel:SetContentAlignment(6)

        local descLabel = vgui.Create("DLabel", row)
        descLabel:SetPos(10, 26)
        descLabel:SetSize(300, 16)
        descLabel:SetFont("HL2RP_HUD_Small")
        descLabel:SetTextColor(Color(140, 150, 165))
        descLabel:SetText(item.desc or "")

        local buyBtn = vgui.Create("DButton", row)
        buyBtn:SetPos(310, 22)
        buyBtn:SetSize(90, 28)
        buyBtn:SetText("BUY")
        buyBtn:SetFont("HL2RP_HUD_Small")
        buyBtn:SetTextColor(Color(220, 235, 255))
        buyBtn.Paint = function(s, w, h)
            local bg = s:IsHovered() and Color(40, 80, 160) or Color(25, 55, 110)
            draw.RoundedBox(3, 0, 0, w, h, bg)
        end
        buyBtn.DoClick = function()
            net.Start("HL2RP_VendorPurchase")
                net.WriteString(vendorID)
                net.WriteString(item.id)
            net.SendToServer()
        end

        y = y + 74
    end
end

-- ============================================================
-- BULLETIN BOARD PANEL
-- ============================================================

function HL2RP.BuildBulletinPanel(parent)
    -- Request task data from server or display cached
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(8, 8)
    lbl:SetSize(400, 16)
    lbl:SetFont("HL2RP_HUD_Small")
    lbl:SetTextColor(Color(160, 200, 160))
    lbl:SetText("Use /tasklist in chat to view available tasks, then /taskaccept <id>.")

    local hint = vgui.Create("DLabel", parent)
    hint:SetPos(8, 32)
    hint:SetSize(400, 100)
    hint:SetFont("HL2RP_HUD_Small")
    hint:SetTextColor(Color(120, 130, 145))
    hint:SetText("Complete tasks to earn credits and build your work record.\n\nTask payouts scale with your faction rank.\n\nUse /taskstatus to check your active task.")
    hint:SetWrap(true)
end

-- ============================================================
-- PERMIT PANEL
-- ============================================================

function HL2RP.BuildPermitPanel(parent)
    local types = {
        { id = "work",           label = "Work Permit",              desc = "Required for employment in certain sectors." },
        { id = "curfew",         label = "Curfew Extension Permit",  desc = "Allows movement after hours." },
        { id = "medical",        label = "Medical Access Permit",    desc = "Access to free Medical Bay treatment." },
        { id = "travel",         label = "Travel Permit",            desc = "Required for Sector D outskirts access." },
        { id = "business",       label = "Business Permit",          desc = "Required to post adverts and operate trade." },
        { id = "housing",        label = "Housing Permit",           desc = "Required for apartment assignment." },
    }

    local y = 4
    for _, pt in ipairs(types) do
        local row = vgui.Create("DPanel", parent)
        row:SetPos(4, y)
        row:SetSize(410, 60)
        row.Paint = function(s, w, h)
            draw.RoundedBox(3, 0, 0, w, h, Color(15, 20, 35, 200))
            surface.SetDrawColor(40, 60, 100, 100)
            surface.DrawRect(0, h - 1, w, 1)
        end

        local nameLabel = vgui.Create("DLabel", row)
        nameLabel:SetPos(10, 5)
        nameLabel:SetSize(280, 18)
        nameLabel:SetFont("HL2RP_HUD_Title")
        nameLabel:SetTextColor(Color(210, 220, 235))
        nameLabel:SetText(pt.label)

        local descLabel = vgui.Create("DLabel", row)
        descLabel:SetPos(10, 24)
        descLabel:SetSize(290, 14)
        descLabel:SetFont("HL2RP_HUD_Small")
        descLabel:SetTextColor(Color(130, 140, 155))
        descLabel:SetText(pt.desc)

        local applyBtn = vgui.Create("DButton", row)
        applyBtn:SetPos(310, 14)
        applyBtn:SetSize(90, 30)
        applyBtn:SetText("APPLY")
        applyBtn:SetFont("HL2RP_HUD_Small")
        applyBtn:SetTextColor(Color(220, 235, 255))
        applyBtn.Paint = function(s, w, h)
            local bg = s:IsHovered() and Color(40, 80, 140) or Color(25, 55, 100)
            draw.RoundedBox(3, 0, 0, w, h, bg)
        end
        applyBtn.DoClick = function()
            RunConsoleCommand("say", "/permitapply " .. pt.id)
            notification.AddLegacy("Application submitted: " .. pt.label, NOTIFY_GENERIC, 4)
        end

        y = y + 66
    end
end
