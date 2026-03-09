--[[
    plugins/npcs_vendors/sv/sv_vendors.lua
    NPC VENDOR & TERMINAL SYSTEM
    ============================================================
    Scriptable NPC interaction points:
    - Ration distribution vendor
    - Legal food stall
    - Permit office terminal
    - Housing terminal
    - Medical bay attendant
    - CWU bulletin board
    - Propaganda terminal
    - Contraband fence (hidden, code-phrase gated)
    ============================================================
--]]

HL2RP.Vendors = HL2RP.Vendors or {}

-- ============================================================
-- VENDOR DEFINITIONS
-- ============================================================

HL2RP.Vendors.Definitions = {

    -- --------------------------------------------------------
    -- RATION DISTRIBUTION POINT
    -- --------------------------------------------------------
    ration_vendor = {
        id          = "ration_vendor",
        label       = "Ration Distribution Terminal",
        model       = "models/combine_soldier.mdl",  -- Combine attendant
        description = "Issue rations to registered citizens.",
        factionAccess = nil,  -- Anyone
        cooldown    = 86400,   -- One ration per 24h
        cooldownVar = "lastRationCollect",
        interact    = function(ply)
            if not IsValid(ply) or not ply:GetCharacter() then return end
            local char     = ply:GetCharacter()
            local lastTime = char:GetVar("lastRationCollect") or 0
            local cooldown = 86400

            if (os.time() - lastTime) < cooldown then
                local remaining = cooldown - (os.time() - lastTime)
                local hours = math.floor(remaining / 3600)
                local mins  = math.floor((remaining % 3600) / 60)
                return HL2RP.Notify(ply, string.format(
                    "Ration already collected. Next in %dh %dm.", hours, mins), "warning")
            end

            -- Loyalty affects ration quality
            local loyalty = char:GetVar("loyaltyScore") or 50
            local inv     = char:getInventory()
            if not inv then return end

            if loyalty >= 76 then
                inv:add("premium_meal")
                inv:add("water_bottle")
                HL2RP.Notify(ply, "Model Citizen ration: Premium meal and fresh water issued.", "success")
            elseif loyalty >= 51 then
                inv:add("ration_pack")
                inv:add("water_bottle")
                HL2RP.Notify(ply, "Compliant Citizen ration: Standard ration pack issued.", "success")
            elseif loyalty >= 26 then
                inv:add("ration_pack")
                HL2RP.Notify(ply, "Standard ration issued.", "success")
            else
                inv:add("stale_bread")
                HL2RP.Notify(ply, "Reduced ration issued. Improve your compliance record.", "warning")
            end

            char:SetVar("lastRationCollect", os.time())
            char:Save()
            HL2RP.Log("ECONOMY", ply:Name(), "RationCollected", "ration_vendor",
                string.format("loyalty=%d", loyalty))
        end,
    },

    -- --------------------------------------------------------
    -- LEGAL FOOD STALL (CWU operated)
    -- --------------------------------------------------------
    food_stall = {
        id          = "food_stall",
        label       = "CWU Approved Food Stall",
        model       = "models/kleiner.mdl",
        description = "Purchase approved food items with tokens.",
        factionAccess = nil,
        stock = {
            { id = "protein_bar",   price = 8,  label = "Protein Bar"    },
            { id = "canned_beans",  price = 12, label = "Canned Beans"   },
            { id = "stale_bread",   price = 5,  label = "Bread (Stale)"  },
            { id = "water_bottle",  price = 6,  label = "Water Bottle"   },
        },
        interact = function(ply)
            -- Opens a shop menu on client
            net.Start("HL2RP_OpenVendorMenu")
                net.WriteString("food_stall")
            net.Send(ply)
        end,
    },

    -- --------------------------------------------------------
    -- PERMIT OFFICE TERMINAL
    -- --------------------------------------------------------
    permit_office = {
        id          = "permit_office",
        label       = "Civil Permit Office",
        model       = "models/mossman.mdl",
        description = "Apply for authorized permits. Wait times apply.",
        factionAccess = nil,
        permitApplications = {},  -- pending applications
        interact    = function(ply)
            if not IsValid(ply) or not ply:GetCharacter() then return end
            net.Start("HL2RP_OpenVendorMenu")
                net.WriteString("permit_office")
            net.Send(ply)
        end,
    },

    -- --------------------------------------------------------
    -- HOUSING TERMINAL
    -- --------------------------------------------------------
    housing_terminal = {
        id          = "housing_terminal",
        label       = "Housing Assignment Terminal",
        model       = "models/combine_soldier.mdl",
        description = "Register for housing or check apartment status.",
        interact    = function(ply)
            if not IsValid(ply) or not ply:GetCharacter() then return end
            local char    = ply:GetCharacter()
            local aptID   = char:GetVar("apartment")

            if aptID then
                local apt = HL2RP.Apartments and HL2RP.Apartments.Registry and HL2RP.Apartments.Registry[aptID]
                if apt then
                    ply:ChatPrint("=== HOUSING STATUS ===")
                    ply:ChatPrint(string.format("  Unit:    %s", apt.label or aptID))
                    ply:ChatPrint(string.format("  Tier:    %s", apt.tier or "Standard"))
                    ply:ChatPrint(string.format("  Rent:    Ȼ%d per cycle", apt.rent or 20))
                    ply:ChatPrint(string.format("  Balance: Ȼ%d", HL2RP.Economy.GetBalance(ply)))
                    return
                end
            end

            -- Not assigned — check waitlist
            local waitlist = HL2RP.Vendors.HousingWaitlist or {}
            local position = nil
            for i, entry in ipairs(waitlist) do
                if entry.charID == char:GetID() then position = i; break end
            end

            if position then
                HL2RP.Notify(ply, string.format("You are #%d on the housing waitlist.", position), "info")
            else
                -- Add to waitlist
                HL2RP.Vendors.HousingWaitlist = HL2RP.Vendors.HousingWaitlist or {}
                table.insert(HL2RP.Vendors.HousingWaitlist, {
                    charID    = char:GetID(),
                    name      = char:GetName(),
                    appliedAt = os.date("%Y-%m-%d %H:%M"),
                })
                HL2RP.Notify(ply, "Added to housing waitlist. An officer will process your application.", "success")
            end
        end,
    },

    -- --------------------------------------------------------
    -- MEDICAL BAY ATTENDANT
    -- --------------------------------------------------------
    medical_bay = {
        id          = "medical_bay",
        label       = "Medical Bay",
        model       = "models/mossman.mdl",
        description = "Basic medical services for registered citizens.",
        cooldown    = 3600,  -- 1 hour between free treatments
        cooldownVar = "lastMedicalVisit",
        interact    = function(ply)
            if not IsValid(ply) or not ply:GetCharacter() then return end
            local char    = ply:GetCharacter()
            local lastMed = char:GetVar("lastMedicalVisit") or 0

            if (os.time() - lastMed) < 3600 then
                local remaining = 3600 - (os.time() - lastMed)
                return HL2RP.Notify(ply, string.format(
                    "You were seen recently. Return in %d minutes.", math.ceil(remaining / 60)), "warning")
            end

            local hp     = ply:Health()
            local maxHp  = ply:GetMaxHealth()

            if hp >= maxHp * 0.9 then
                return HL2RP.Notify(ply, "You don't require immediate medical attention.", "info")
            end

            -- Check if citizen has medical access
            local hasPermit = HL2RP.Permits and HL2RP.Permits.IsValid(ply, "medical")
            local fID       = char:GetVar("faction")
            local isMedic   = fID == "medic"
            local cost      = hasPermit and 0 or 25

            if not hasPermit and not isMedic then
                if HL2RP.Economy.GetBalance(ply) < cost then
                    return HL2RP.Notify(ply, string.format(
                        "Medical permit required or Ȼ%d for walk-in treatment. Insufficient funds.", cost), "error")
                end
                HL2RP.Economy.Deduct(ply, cost, "Walk-in medical treatment")
            end

            -- Heal to 80%
            ply:SetHealth(math.min(maxHp, math.max(hp, math.floor(maxHp * 0.8))))
            -- Reduce needs
            HL2RP.Needs.Consume(ply, "stress", 20, "restore")

            char:SetVar("lastMedicalVisit", os.time())
            char:Save()

            HL2RP.Notify(ply, string.format("Treated. Health restored to %d/%d.",
                ply:Health(), maxHp), "success")
            HL2RP.Log("ECONOMY", ply:Name(), "MedicalVisit", "medical_bay",
                cost > 0 and string.format("cost=Ȼ%d", cost) or "free")
        end,
    },

    -- --------------------------------------------------------
    -- CWU BULLETIN BOARD
    -- --------------------------------------------------------
    cwu_bulletin = {
        id          = "cwu_bulletin",
        label       = "CWU Bulletin Board",
        model       = nil,  -- Static prop, no NPC
        description = "View available work tasks and union announcements.",
        interact    = function(ply)
            net.Start("HL2RP_OpenVendorMenu")
                net.WriteString("cwu_bulletin")
            net.Send(ply)
        end,
    },

    -- --------------------------------------------------------
    -- PROPAGANDA TERMINAL
    -- (Reduces stress if interacted with — dark humor)
    -- --------------------------------------------------------
    propaganda_terminal = {
        id          = "propaganda_terminal",
        label       = "Civil Information Terminal",
        model       = nil,
        description = "Access approved civil information and wellness programs.",
        cooldown    = 1800,
        cooldownVar = "lastPropagandaView",
        interact    = function(ply)
            if not IsValid(ply) or not ply:GetCharacter() then return end
            local char    = ply:GetCharacter()
            local lastTime= char:GetVar("lastPropagandaView") or 0

            local slogans = {
                "Remember: Compliance is safety. Safety is life.",
                "The Combine Administration thanks you for your service.",
                "Report suspicious activity. A safer city is everyone's city.",
                "Your ration status is tied to your community contribution.",
                "Civil Protection is your friend. Cooperation is appreciated.",
                "City 45 Wellness Program: Breathe. Comply. Prosper.",
                "Unauthorized information is dangerous information.",
                "Your loyalty has been noted and appreciated.",
            }

            if (os.time() - lastTime) >= 1800 then
                HL2RP.Needs.Consume(ply, "stress", 8, "restore")
                char:SetVar("lastPropagandaView", os.time())
            end

            local slogan = slogans[math.random(#slogans)]
            ply:ChatPrint("[ CIVIL INFORMATION TERMINAL ]")
            ply:ChatPrint("  \"" .. slogan .. "\"")
            ply:ChatPrint("[ Have a productive cycle, Citizen. ]")
        end,
    },

    -- --------------------------------------------------------
    -- WASTELAND FENCE (contraband dealer, hidden)
    -- --------------------------------------------------------
    wasteland_fence = {
        id          = "wasteland_fence",
        label       = "??",  -- Shown as generic citizen to outsiders
        model       = "models/kleiner.mdl",
        description = "A shady figure. They don't look like they work here.",
        hidden      = true,
        codePhrase  = "the birds fly south in winter",
        interact    = function(ply)
            if not IsValid(ply) or not ply:GetCharacter() then return end
            local char = ply:GetCharacter()

            -- Check if player has said the code phrase recently
            if not ply.saidFenceCode then
                HL2RP.Notify(ply, "He doesn't seem to acknowledge you.", "info")
                return
            end

            local bmRep = char:GetVar("blackMarketRep") or 0
            if bmRep < 5 then
                HL2RP.Notify(ply, "\"I don't know you. Move along.\"", "warning")
                return
            end

            net.Start("HL2RP_OpenVendorMenu")
                net.WriteString("wasteland_fence")
            net.Send(ply)
        end,
    },
}

-- ============================================================
-- VENDOR MENU NET STRINGS
-- ============================================================
util.AddNetworkString("HL2RP_OpenVendorMenu")
util.AddNetworkString("HL2RP_VendorPurchase")
util.AddNetworkString("HL2RP_VendorMenuData")

-- ============================================================
-- PURCHASE HANDLER
-- ============================================================

net.Receive("HL2RP_VendorPurchase", function(len, ply)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    local vendorID = net.ReadString()
    local itemID   = net.ReadString()

    local vendor = HL2RP.Vendors.Definitions[vendorID]
    if not vendor or not vendor.stock then return end

    local stockEntry = nil
    for _, s in ipairs(vendor.stock) do
        if s.id == itemID then stockEntry = s; break end
    end

    if not stockEntry then return end

    local price = stockEntry.price
    if HL2RP.Economy.GetBalance(ply) < price then
        return HL2RP.Notify(ply, string.format("Insufficient credits. Need Ȼ%d.", price), "error")
    end

    local inv = ply:GetCharacter():getInventory()
    if not inv then return end

    HL2RP.Economy.Deduct(ply, price, "Vendor: " .. (stockEntry.label or itemID))
    inv:add(itemID)
    HL2RP.Notify(ply, string.format("Purchased: %s for Ȼ%d.", stockEntry.label or itemID, price), "success")
    HL2RP.Log("ECONOMY", ply:Name(), "VendorPurchase", vendorID, itemID)
end)

-- ============================================================
-- PERMIT APPLICATION PROCESSING
-- Players apply at terminal, admins approve/deny via command
-- ============================================================

HL2RP.Vendors.PermitApplications = {}

function HL2RP.Vendors.ApplyForPermit(ply, permitType)
    if not IsValid(ply) or not ply:GetCharacter() then return false end

    local validTypes = { "housing", "work", "curfew", "medical", "travel", "business" }
    local valid = false
    for _, v in ipairs(validTypes) do if v == permitType then valid = true; break end end
    if not valid then
        return HL2RP.Notify(ply, "Invalid permit type.", "error")
    end

    local charName = ply:GetCharacter():GetName()

    -- Already applied?
    for _, app in ipairs(HL2RP.Vendors.PermitApplications) do
        if app.charName == charName and app.permitType == permitType and not app.decided then
            return HL2RP.Notify(ply, "You already have a pending application for this permit.", "warning")
        end
    end

    table.insert(HL2RP.Vendors.PermitApplications, {
        charName  = charName,
        ply       = ply,
        permitType= permitType,
        appliedAt = os.date("%Y-%m-%d %H:%M"),
        decided   = false,
        reason    = nil,
    })

    -- Alert bureau/CP
    HL2RP.Events.NotifyFaction("admin_bureau",
        string.format("[PERMIT APPLICATION] %s applied for: %s", charName, permitType), "info")
    HL2RP.Events.NotifyFaction("cp",
        string.format("[PERMIT APPLICATION] %s applied for: %s", charName, permitType), "info")

    HL2RP.Notify(ply, string.format(
        "Permit application for '%s' submitted. An officer will review your request.", permitType), "success")
end

-- ============================================================
-- COMMANDS
-- ============================================================

nut.command.add("permitapply", {
    syntax  = "<permit_type>",
    desc    = "Apply for a permit at the permit office.",
    onRun   = function(ply, args)
        local permitType = args[1]
        if not permitType then
            return HL2RP.Notify(ply, "Permit types: housing, work, curfew, medical, travel, business", "info")
        end
        HL2RP.Vendors.ApplyForPermit(ply, permitType)
    end
})

nut.command.add("permitapps", {
    desc  = "View pending permit applications (Bureau/CP/Admin).",
    onRun = function(ply)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if not HL2RP.HasRank(ply, "moderator") and fID ~= "cp" and fID ~= "admin_bureau" then
            return HL2RP.Notify(ply, "Not authorized.", "error")
        end

        local apps = HL2RP.Vendors.PermitApplications
        if #apps == 0 then return HL2RP.Notify(ply, "No pending applications.", "info") end

        ply:ChatPrint("=== PERMIT APPLICATIONS ===")
        for i, app in ipairs(apps) do
            if not app.decided then
                ply:ChatPrint(string.format("  [%d] %s — %s (Applied: %s)",
                    i, app.charName, app.permitType, app.appliedAt))
            end
        end
        ply:ChatPrint("Use /approveapp <n> or /denyapp <n> to process.")
    end
})

nut.command.add("approveapp", {
    syntax  = "<application_number>",
    desc    = "Approve a permit application.",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if not HL2RP.HasRank(ply, "moderator") and fID ~= "cp" and fID ~= "admin_bureau" then
            return HL2RP.Notify(ply, "Not authorized.", "error")
        end
        local idx = tonumber(args[1])
        local app = HL2RP.Vendors.PermitApplications[idx]
        if not app or app.decided then return HL2RP.Notify(ply, "Invalid application.", "error") end

        app.decided = true
        -- Issue permit to target player
        if IsValid(app.ply) and app.ply:GetCharacter() then
            HL2RP.Permits.Issue(ply, app.ply, app.permitType)
        end
        HL2RP.Notify(ply, string.format("Application #%d approved: %s / %s", idx, app.charName, app.permitType), "success")
    end
})

nut.command.add("denyapp", {
    syntax  = "<application_number> [reason]",
    desc    = "Deny a permit application.",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if not HL2RP.HasRank(ply, "moderator") and fID ~= "cp" and fID ~= "admin_bureau" then
            return HL2RP.Notify(ply, "Not authorized.", "error")
        end
        local idx    = tonumber(args[1])
        local reason = table.concat(args, " ", 2)
        local app    = HL2RP.Vendors.PermitApplications[idx]
        if not app or app.decided then return HL2RP.Notify(ply, "Invalid application.", "error") end

        app.decided = true
        if IsValid(app.ply) then
            HL2RP.Notify(app.ply, string.format(
                "Your permit application for '%s' was denied. %s", app.permitType, reason or ""), "error")
        end
        HL2RP.Notify(ply, string.format("Application #%d denied.", idx), "info")
    end
})

nut.command.add("vendorinteract", {
    syntax  = "<vendor_id>",
    desc    = "Interact with a nearby vendor (debug/fallback).",
    onRun   = function(ply, args)
        local vendorID = args[1]
        local vendor   = HL2RP.Vendors.Definitions[vendorID]
        if not vendor then
            return HL2RP.Notify(ply, "Unknown vendor.", "error")
        end
        if vendor.interact then vendor.interact(ply) end
    end
})

nut.command.add("viewwaitlist", {
    desc  = "View the housing waitlist (Bureau/Admin).",
    onRun = function(ply)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if not HL2RP.HasRank(ply, "moderator") and fID ~= "admin_bureau" then
            return HL2RP.Notify(ply, "Not authorized.", "error")
        end
        local wl = HL2RP.Vendors.HousingWaitlist or {}
        if #wl == 0 then return HL2RP.Notify(ply, "No waitlist entries.", "info") end
        ply:ChatPrint("=== HOUSING WAITLIST ===")
        for i, e in ipairs(wl) do
            ply:ChatPrint(string.format("  [%d] %s — Applied: %s", i, e.name, e.appliedAt))
        end
    end
})
