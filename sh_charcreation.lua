--[[
    plugins/supporter_donor/sh/sh_supporter.lua
    SUPPORTER / DONOR TIER SYSTEM
    ============================================================
    Cosmetic-first, non-pay-to-win supporter tiers.
    All combat and gameplay advantages are strictly cosmetic,
    QoL, prestige, or administrative convenience.
    ============================================================
--]]

HL2RP.Supporter = HL2RP.Supporter or {}

-- ============================================================
-- TIER DEFINITIONS
-- ============================================================

HL2RP.Supporter.Tiers = {
    supporter = {
        id          = "supporter",
        label       = "Supporter",
        color       = Color(100, 200, 140),
        chatPrefix  = "[S]",
        chatColor   = Color(100, 200, 140),
        perks = {
            extraCharSlots      = 1,        -- +1 character slot
            oocNameplate        = true,     -- Colored name in OOC
            customDesc          = true,     -- Extended character description (768 chars)
            supporterTag        = true,     -- /tags command shows [Supporter]
            reservedSlot        = false,
            extraStorageSlots   = 0,
            customPassportBorder= "supporter_basic",
            emotePack           = "supporter_emotes",
            priorityQueue       = false,
            customGraffiti      = false,
            donorLocker         = false,
        },
    },

    bronze = {
        id          = "bronze",
        label       = "Bronze Supporter",
        color       = Color(180, 120, 60),
        chatPrefix  = "[B]",
        chatColor   = Color(200, 140, 80),
        perks = {
            extraCharSlots      = 1,
            oocNameplate        = true,
            customDesc          = true,
            supporterTag        = true,
            reservedSlot        = false,
            extraStorageSlots   = 3,
            customPassportBorder= "supporter_bronze",
            emotePack           = "supporter_emotes",
            customGraffiti      = true,     -- Custom graffiti spray pack
            donorLocker         = false,
            priorityQueue       = false,
            customTitle         = true,     -- Can set a custom character title
        },
    },

    silver = {
        id          = "silver",
        label       = "Silver Supporter",
        color       = Color(180, 190, 200),
        chatPrefix  = "[Ag]",
        chatColor   = Color(190, 200, 215),
        perks = {
            extraCharSlots      = 2,
            oocNameplate        = true,
            customDesc          = true,
            supporterTag        = true,
            reservedSlot        = true,     -- Reserved server slot
            extraStorageSlots   = 5,
            customPassportBorder= "supporter_silver",
            emotePack           = "supporter_emotes_extended",
            customGraffiti      = true,
            donorLocker         = true,     -- Private in-game storage locker
            priorityQueue       = true,
            customTitle         = true,
            aptDecorations      = true,     -- Extra apartment decoration items
            radioSkin           = "silver_radio",
        },
    },

    gold = {
        id          = "gold",
        label       = "Gold Supporter",
        color       = Color(230, 200, 60),
        chatPrefix  = "[Au]",
        chatColor   = Color(240, 210, 80),
        perks = {
            extraCharSlots      = 3,
            oocNameplate        = true,
            customDesc          = true,
            supporterTag        = true,
            reservedSlot        = true,
            extraStorageSlots   = 8,
            customPassportBorder= "supporter_gold",
            emotePack           = "supporter_emotes_full",
            customGraffiti      = true,
            donorLocker         = true,
            priorityQueue       = true,
            customTitle         = true,
            aptDecorations      = true,
            radioSkin           = "gold_radio",
            pacExtraPermissions = true,     -- Extra PAC editor allowance
            customInventoryTheme= true,     -- Custom inventory panel skin
            profileBanner       = true,     -- Forum-ready profile banner hook
            nameplateFlair      = "gold",   -- Animated OOC gold nameplate
        },
    },

    founder = {
        id          = "founder",
        label       = "Founder",
        color       = Color(200, 160, 255),
        chatPrefix  = "[FOUND]",
        chatColor   = Color(210, 170, 255),
        perks = {
            extraCharSlots      = 4,
            oocNameplate        = true,
            customDesc          = true,
            supporterTag        = true,
            reservedSlot        = true,
            extraStorageSlots   = 10,
            customPassportBorder= "supporter_founder",
            emotePack           = "supporter_emotes_full",
            customGraffiti      = true,
            donorLocker         = true,
            priorityQueue       = true,
            customTitle         = true,
            aptDecorations      = true,
            radioSkin           = "founder_radio",
            pacExtraPermissions = true,
            customInventoryTheme= true,
            profileBanner       = true,
            nameplateFlair      = "founder",
            founderBadge        = true,     -- Unique in-game founder badge item
            exclusiveClothing   = true,     -- Unique lore-safe clothing variants
        },
    },
}

-- Get a player's supporter tier (checks NutScript usergroup or stored var)
function HL2RP.Supporter.GetTier(ply)
    if not IsValid(ply) then return nil end

    -- Check in order of precedence
    local group = ply:GetUserGroup()
    local tierMap = {
        founder   = "founder",
        gold      = "gold",
        silver    = "silver",
        bronze    = "bronze",
        supporter = "supporter",
        vip       = "supporter",  -- Map legacy VIP to supporter
    }
    return tierMap[group]
end

-- Get the perk table for a player
function HL2RP.Supporter.GetPerks(ply)
    local tierID = HL2RP.Supporter.GetTier(ply)
    if not tierID then return {} end
    local tier = HL2RP.Supporter.Tiers[tierID]
    return tier and tier.perks or {}
end

-- Check if a player has a specific perk
function HL2RP.Supporter.HasPerk(ply, perkKey)
    local perks = HL2RP.Supporter.GetPerks(ply)
    return perks[perkKey] == true or (type(perks[perkKey]) == "number" and perks[perkKey] > 0)
end

-- Get numeric perk value (e.g. extra storage slots)
function HL2RP.Supporter.GetPerkValue(ply, perkKey)
    local perks = HL2RP.Supporter.GetPerks(ply)
    return perks[perkKey] or 0
end
