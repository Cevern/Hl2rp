--[[
    plugins/supporter_donor/sv/sv_supporter.lua
    Server-side supporter system enforcement and admin tools.
--]]

util.AddNetworkString("HL2RP_SupporterSync")

-- Sync supporter tier to client on connect
hook.Add("PlayerSpawn", "HL2RP_SupporterSync", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        local tierID = HL2RP.Supporter.GetTier(ply)
        net.Start("HL2RP_SupporterSync")
            net.WriteString(tierID or "")
        net.Send(ply)
    end)
end)

-- Apply extra character slots on character list load
hook.Add("NutCharacterLoaded", "HL2RP_SupporterCharSlots", function(ply)
    if not IsValid(ply) then return end
    local extra = HL2RP.Supporter.GetPerkValue(ply, "extraCharSlots")
    if extra > 0 then
        -- NutScript max chars is typically set per schema
        -- This hook signals the character system to allow extra slots
        -- Implementation depends on NutScript version
        ply:SetNWInt("HL2RP_ExtraCharSlots", extra)
    end
end)

-- Apply extra storage slots
hook.Add("PlayerSpawn", "HL2RP_SupporterStorage", function(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    local extra = HL2RP.Supporter.GetPerkValue(ply, "extraStorageSlots")
    if extra > 0 then
        -- Signal inventory system to expand
        ply:SetNWInt("HL2RP_ExtraInvSlots", extra)
    end
end)

-- Reserved slot: kick lowest-priority player if server is full
-- (This is handled by the server slot reservation plugin — hook provided here)
hook.Add("CheckPassword", "HL2RP_ReservedSlot", function(steamID64, ipAddress, svPassword, clPassword, name)
    -- If server is at max players, check if connecting player has reserved slot perk
    -- NutScript handles this differently — stub for integration
end)

-- ============================================================
-- ADMIN COMMANDS
-- ============================================================

-- Assign supporter tier manually
nut.command.add("setsupporter", {
    adminOnly = true,
    syntax    = "<player> <tier>",
    desc      = "Assign a supporter tier to a player.",
    onRun     = function(ply, args)
        if not HL2RP.HasRank(ply, "admin") then
            return HL2RP.Notify(ply, "Permission denied.", "error")
        end

        local target = nut.util.FindPlayer(args[1])
        local tierID = args[2]

        if not IsValid(target) then
            return HL2RP.Notify(ply, "Player not found.", "error")
        end

        if not HL2RP.Supporter.Tiers[tierID] then
            return HL2RP.Notify(ply, "Unknown tier: " .. tostring(tierID) ..
                ". Valid tiers: supporter, bronze, silver, gold, founder", "error")
        end

        -- Set usergroup (integrates with NutScript usergroup system)
        target:SetUserGroup(tierID)

        -- Re-sync to client
        net.Start("HL2RP_SupporterSync")
            net.WriteString(tierID)
        net.Send(target)

        HL2RP.Notify(target, string.format("Your supporter tier has been updated to: %s. Thank you for your support!",
            HL2RP.Supporter.Tiers[tierID].label), "success")
        HL2RP.Notify(ply, string.format("Set %s to %s tier.", target:Name(), tierID), "info")
        HL2RP.Log("SUPPORTER", ply:Name(), "TierAssigned", target:Name(), tierID)
    end
})

-- Remove supporter tier
nut.command.add("removesupporter", {
    adminOnly = true,
    syntax    = "<player>",
    desc      = "Remove a player's supporter tier.",
    onRun     = function(ply, args)
        if not HL2RP.HasRank(ply, "admin") then
            return HL2RP.Notify(ply, "Permission denied.", "error")
        end
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then
            return HL2RP.Notify(ply, "Player not found.", "error")
        end
        target:SetUserGroup("user")
        net.Start("HL2RP_SupporterSync")
            net.WriteString("")
        net.Send(target)
        HL2RP.Notify(ply, "Supporter tier removed from " .. target:Name(), "info")
        HL2RP.Log("SUPPORTER", ply:Name(), "TierRemoved", target:Name(), "")
    end
})

-- View player supporter status
nut.command.add("supporterstatus", {
    syntax  = "<player>",
    desc    = "Check a player's supporter tier.",
    onRun   = function(ply, args)
        if not HL2RP.HasRank(ply, "moderator") then
            return HL2RP.Notify(ply, "Permission denied.", "error")
        end
        local target = nut.util.FindPlayer(args[1])
        if not IsValid(target) then
            return HL2RP.Notify(ply, "Player not found.", "error")
        end
        local tierID = HL2RP.Supporter.GetTier(target)
        if tierID then
            HL2RP.Notify(ply, string.format("%s is a %s.",
                target:Name(), HL2RP.Supporter.Tiers[tierID].label), "info")
        else
            HL2RP.Notify(ply, target:Name() .. " has no supporter tier.", "info")
        end
    end
})

-- ============================================================
-- EXCLUSIVE COSMETIC ITEMS (Supporter-gated)
-- ============================================================

-- Founder badge item hook
hook.Add("HL2RP_ItemEquip", "HL2RP_FounderBadgeCheck", function(ply, itemID)
    if itemID == "founder_badge" then
        if not HL2RP.Supporter.HasPerk(ply, "founderBadge") then
            HL2RP.Notify(ply, "This item is exclusive to Founders.", "error")
            return false  -- Block equip
        end
    end
end)

-- Donor locker access
HL2RP.Supporter.DonorLockers = {}  -- playerSteamID -> { items }

function HL2RP.Supporter.GetDonorLocker(ply)
    if not IsValid(ply) then return nil end
    if not HL2RP.Supporter.HasPerk(ply, "donorLocker") then
        HL2RP.Notify(ply, "Donor locker requires Silver tier or above.", "error")
        return nil
    end
    local sid = ply:SteamID()
    HL2RP.Supporter.DonorLockers[sid] = HL2RP.Supporter.DonorLockers[sid] or { items = {} }
    return HL2RP.Supporter.DonorLockers[sid]
end
