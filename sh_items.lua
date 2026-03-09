--[[
    plugins/apartments/sv/sv_apartments.lua
    APARTMENT / HOUSING SYSTEM
    ============================================================
    Manages:
    - Apartment assignment and ownership
    - Rent collection
    - Eviction
    - Storage permissions
    - Roommate access
    - Hidden stash system
    - Apartment inspection
    - Admin management tools
    ============================================================
--]]

HL2RP.Apartments = HL2RP.Apartments or {}

-- In-memory apartment registry (populated from map entities or a config file)
-- Each entry: { id, label, ownerCharID, roommates, rentPaid, stash, locked }
-- TODO: Load from nut's SQL persistence on startup

-- ============================================================
-- CORE OPERATIONS
-- ============================================================

function HL2RP.Apartments.Assign(targetPly, apartmentID, byPly)
    if not IsValid(targetPly) or not targetPly:GetCharacter() then return false end
    local char = targetPly:GetCharacter()

    -- Check if apartment is already occupied
    local existing = HL2RP.Apartments.Registry[apartmentID]
    if existing and existing.ownerCharID and existing.ownerCharID ~= char:GetID() then
        return false, "occupied"
    end

    -- Initialize apartment entry
    HL2RP.Apartments.Registry[apartmentID] = HL2RP.Apartments.Registry[apartmentID] or {}
    local apt = HL2RP.Apartments.Registry[apartmentID]

    apt.ownerCharID = char:GetID()
    apt.ownerName   = char:GetName()
    apt.assignedAt  = os.time()
    apt.rentPaid    = true
    apt.roommates   = apt.roommates or {}
    apt.stash       = apt.stash or {}
    apt.locked      = false

    char:SetVar("apartmentID", apartmentID)
    char:SetVar("rentStatus", "current")
    char:Save()

    HL2RP.Apartments.Save()
    HL2RP.Notify(targetPly, string.format("You have been assigned apartment %s.", apartmentID), "success")

    if IsValid(byPly) then
        HL2RP.Log("HOUSING", byPly:Name(), "ApartmentAssigned", targetPly:Name(), apartmentID)
    end

    return true
end

function HL2RP.Apartments.Evict(targetPly, apartmentID, reason, byPly)
    if not IsValid(targetPly) or not targetPly:GetCharacter() then return end
    local char = targetPly:GetCharacter()

    local apt = HL2RP.Apartments.Registry[apartmentID]
    if not apt then return end

    apt.ownerCharID = nil
    apt.ownerName   = nil
    apt.roommates   = {}

    char:SetVar("apartmentID", nil)
    char:SetVar("rentStatus", "evicted")
    char:Save()

    HL2RP.Apartments.Save()
    HL2RP.Notify(targetPly, string.format("You have been evicted from apartment %s. Reason: %s", apartmentID, reason or "Non-payment"), "error")

    if IsValid(byPly) then
        HL2RP.Log("HOUSING", byPly:Name(), "Eviction", targetPly:Name(), reason or "Non-payment")
    end
end

function HL2RP.Apartments.AddRoomate(ownerPly, targetPly, apartmentID)
    if not IsValid(ownerPly) or not IsValid(targetPly) then return false end

    local apt = HL2RP.Apartments.Registry[apartmentID]
    if not apt then return false, "no_apartment" end

    local ownerChar = ownerPly:GetCharacter()
    if not ownerChar or apt.ownerCharID ~= ownerChar:GetID() then
        return false, "not_owner"
    end

    local maxRoomates = nut.config.get("maxRoomates") or 3
    if #apt.roommates >= maxRoomates then
        return false, "full"
    end

    local targetChar = targetPly:GetCharacter()
    if not targetChar then return false, "no_char" end

    table.insert(apt.roommates, { charID = targetChar:GetID(), name = targetChar:GetName() })
    targetChar:SetVar("apartmentID", apartmentID)
    targetChar:Save()
    HL2RP.Apartments.Save()

    HL2RP.Notify(targetPly, string.format("You now have access to apartment %s.", apartmentID), "info")
    return true
end

-- ============================================================
-- RENT SYSTEM
-- ============================================================

local function ProcessRent()
    local rentAmount  = nut.config.get("apartmentRent") or 20
    local gracePeriod = nut.config.get("evictionGracePeriod") or 1

    for aptID, apt in pairs(HL2RP.Apartments.Registry or {}) do
        if not apt.ownerCharID then continue end

        -- Find owner player
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:GetCharacter() and ply:GetCharacter():GetID() == apt.ownerCharID then
                local bal = HL2RP.Economy.GetBalance(ply)
                if bal >= rentAmount then
                    HL2RP.Economy.Deduct(ply, rentAmount, "Apartment rent: " .. aptID)
                    apt.missedRent = 0
                    HL2RP.Notify(ply, string.format("Rent deducted: Ȼ%d for apartment %s.", rentAmount, aptID), "info")
                else
                    apt.missedRent = (apt.missedRent or 0) + 1
                    HL2RP.Notify(ply, "Insufficient tokens for rent. Warning issued.", "warning")
                    if apt.missedRent > gracePeriod then
                        HL2RP.Apartments.Evict(ply, aptID, "Non-payment of rent", nil)
                    end
                end
                break
            end
        end
    end
end

local rentCycleSeconds = (nut.config.get("rentCycleHours") or 48) * 3600
timer.Create("HL2RP_RentCycle", rentCycleSeconds, 0, ProcessRent)

-- ============================================================
-- HIDDEN STASH SYSTEM
-- ============================================================

function HL2RP.Apartments.AddToStash(char, apartmentID, itemID, amount)
    local apt = HL2RP.Apartments.Registry[apartmentID]
    if not apt then return false end
    if apt.ownerCharID ~= char:GetID() then return false end

    apt.stash = apt.stash or {}
    apt.stash[itemID] = (apt.stash[itemID] or 0) + (amount or 1)
    HL2RP.Apartments.Save()
    return true
end

function HL2RP.Apartments.SearchStash(apartmentID)
    local detectChance = nut.config.get("hiddenStashDetectChance") or 0.15
    local apt = HL2RP.Apartments.Registry[apartmentID]
    if not apt or not apt.stash or not next(apt.stash) then
        return false, {}
    end

    if math.random() < detectChance then
        return true, apt.stash
    end

    return false, {}
end

-- ============================================================
-- PERSISTENCE (simplified save/load)
-- ============================================================

HL2RP.Apartments.Registry = HL2RP.Apartments.Registry or {}

function HL2RP.Apartments.Save()
    local data = util.TableToJSON(HL2RP.Apartments.Registry)
    file.Write("hl2rp_apartments.json", data)
end

function HL2RP.Apartments.Load()
    if file.Exists("hl2rp_apartments.json", "DATA") then
        local data = file.Read("hl2rp_apartments.json", "DATA")
        HL2RP.Apartments.Registry = util.JSONToTable(data) or {}
    end
end

hook.Add("Initialize", "HL2RP_ApartmentsLoad", HL2RP.Apartments.Load)

-- ============================================================
-- COMMANDS
-- ============================================================

nut.command.add("assignapt", {
    syntax  = "<player> <apartment_id>",
    desc    = "Assign an apartment to a player (Bureau/Admin).",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if not HL2RP.HasRank(ply, "moderator") and fID ~= "bureau" and fID ~= "admin_bureau" then
            return HL2RP.Notify(ply, "Not authorized.", "error")
        end
        local target = nut.util.FindPlayer(args[1])
        local aptID  = args[2]
        if not IsValid(target) or not aptID then
            return HL2RP.Notify(ply, "Invalid arguments.", "error")
        end
        local ok, err = HL2RP.Apartments.Assign(target, aptID, ply)
        if not ok then
            HL2RP.Notify(ply, "Failed: " .. (err or "unknown"), "error")
        end
    end
})

nut.command.add("evict", {
    syntax  = "<player> [reason]",
    desc    = "Evict a player from their apartment (Bureau/Admin).",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if not HL2RP.HasRank(ply, "moderator") and fID ~= "bureau" and fID ~= "admin_bureau" then
            return HL2RP.Notify(ply, "Not authorized.", "error")
        end
        local target = nut.util.FindPlayer(args[1])
        local reason = table.concat(args, " ", 2)
        if not IsValid(target) or not target:GetCharacter() then
            return HL2RP.Notify(ply, "Target not found.", "error")
        end
        local aptID = target:GetCharacter():GetVar("apartmentID")
        if not aptID then
            return HL2RP.Notify(ply, "This character has no apartment assigned.", "error")
        end
        HL2RP.Apartments.Evict(target, aptID, reason, ply)
    end
})

nut.command.add("aptinspect", {
    syntax  = "<apartment_id>",
    desc    = "Inspect an apartment's stash (CP/Admin).",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if not HL2RP.HasRank(ply, "moderator") and fID ~= "cp" and fID ~= "ota" then
            return HL2RP.Notify(ply, "Not authorized.", "error")
        end
        local aptID = args[1]
        local found, stash = HL2RP.Apartments.SearchStash(aptID)
        if found then
            HL2RP.Notify(ply, "Hidden stash detected!", "error")
            for itemID, qty in pairs(stash) do
                ply:ChatPrint(string.format("  - %s x%d", itemID, qty))
            end
            HL2RP.Tension.Modify(ply:Name(), "contraband_found")
        else
            HL2RP.Notify(ply, "No hidden contraband detected.", "info")
        end
        HL2RP.Log("HOUSING", ply:Name(), "AptInspection", aptID, found and "stash_found" or "clear")
    end
})
