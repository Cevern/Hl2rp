--[[
    plugins/economy/sv/sv_economy.lua
    ECONOMY SYSTEM
    ============================================================
    Handles:
    - Credit (token) balances
    - Salary payouts by faction rank
    - Fines
    - Transfers between players
    - Economy logging
    - Vendor purchase hooks
    ============================================================
--]]

HL2RP.Economy = HL2RP.Economy or {}

-- ============================================================
-- BALANCE OPERATIONS
-- ============================================================

function HL2RP.Economy.GetBalance(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return 0 end
    return ply:GetCharacter():GetVar("credits") or 0
end

function HL2RP.Economy.SetBalance(ply, amount)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    local capped = math.Clamp(math.floor(amount), 0, nut.config.get("maxCredits") or 99999)
    ply:GetCharacter():SetVar("credits", capped)
end

function HL2RP.Economy.Add(ply, amount, reason)
    if amount <= 0 then return end
    local old = HL2RP.Economy.GetBalance(ply)
    HL2RP.Economy.SetBalance(ply, old + amount)
    HL2RP.Notify(ply, string.format("+Ȼ%d — %s", amount, reason or "Payment"), "success")
    HL2RP.Log("ECONOMY", "system", "Add", ply:Name(), string.format("%d | reason=%s", amount, reason or "?"))
end

function HL2RP.Economy.Deduct(ply, amount, reason)
    if amount <= 0 then return false end
    local bal = HL2RP.Economy.GetBalance(ply)
    if bal < amount then
        HL2RP.Notify(ply, "Insufficient tokens.", "error")
        return false
    end
    HL2RP.Economy.SetBalance(ply, bal - amount)
    HL2RP.Notify(ply, string.format("-Ȼ%d — %s", amount, reason or "Payment"), "warning")
    HL2RP.Log("ECONOMY", "system", "Deduct", ply:Name(), string.format("%d | reason=%s", amount, reason or "?"))
    return true
end

function HL2RP.Economy.Transfer(fromPly, toPly, amount, reason)
    if not HL2RP.Economy.Deduct(fromPly, amount, "Transfer to " .. toPly:GetCharacter():GetName()) then
        return false
    end
    HL2RP.Economy.Add(toPly, amount, "Transfer from " .. fromPly:GetCharacter():GetName())
    return true
end

-- Fine a player with an optional logged charge
function HL2RP.Economy.Fine(targetPly, amount, charge, issuerPly)
    local result = HL2RP.Economy.Deduct(targetPly, amount, "Fine: " .. (charge or "Violation"))
    if result then
        HL2RP.Notify(targetPly, string.format("You have been fined Ȼ%d for: %s", amount, charge or "Violation"), "error")
        if IsValid(issuerPly) then
            HL2RP.Notify(issuerPly, string.format("Fined %s Ȼ%d.",
                targetPly:GetCharacter():GetName(), amount), "info")
        end
        -- Log crime
        HL2RP.Datafiles.LogCrime(issuerPly, targetPly:GetCharacter(), "Fine: " .. (charge or "Violation"), "minor")
    end
    return result
end

-- ============================================================
-- SALARY SYSTEM
-- ============================================================

-- Build salary table from faction rank data
local function GetSalaryForPlayer(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return 0 end
    local faction = HL2RP.GetFaction(ply)
    if not faction then return 0 end

    -- Check if on-duty (faction-based system can set this)
    if not ply:GetCharacter():GetVar("onDuty") and faction.name ~= "Citizen" then
        return 0
    end

    local rankIdx = HL2RP.GetRankIndex(ply)
    local rank    = faction.ranks and faction.ranks[rankIdx + 1]
    if rank and rank.pay then return rank.pay end

    return faction.pay or 0
end

local function PaySalaries()
    local taxRate = nut.config.get("taxRate") or 0.05
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetCharacter() then
            local salary = GetSalaryForPlayer(ply)
            if salary > 0 then
                local taxed = math.floor(salary * taxRate)
                local net   = salary - taxed
                HL2RP.Economy.Add(ply, net, "Salary")
            end
        end
    end
end

local salaryInterval = nut.config.get("salaryInterval") or 300
timer.Create("HL2RP_SalaryPayout", salaryInterval, 0, PaySalaries)

-- ============================================================
-- COMMANDS
-- ============================================================

nut.command.add("pay", {
    syntax  = "<player> <amount>",
    desc    = "Transfer tokens to another player.",
    onRun   = function(ply, args)
        local target = nut.util.FindPlayer(args[1])
        local amount = tonumber(args[2])

        if not IsValid(target) or not target:GetCharacter() then
            return HL2RP.Notify(ply, "Player not found.", "error")
        end
        if not amount or amount <= 0 then
            return HL2RP.Notify(ply, "Invalid amount.", "error")
        end
        if target == ply then
            return HL2RP.Notify(ply, "You cannot pay yourself.", "error")
        end

        HL2RP.Economy.Transfer(ply, target, amount, "Player transfer")
    end
})

nut.command.add("balance", {
    desc  = "Check your token balance.",
    onRun = function(ply)
        local bal = HL2RP.Economy.GetBalance(ply)
        HL2RP.Notify(ply, string.format("Balance: %s", HL2RP.FormatCredits(bal)), "info")
    end
})

nut.command.add("fine", {
    syntax  = "<player> <amount> <charge>",
    desc    = "Issue a fine to a player (CP/Bureau only).",
    onRun   = function(ply, args)
        local fID = ply:GetCharacter() and ply:GetCharacter():GetVar("faction")
        if not HL2RP.HasRank(ply, "moderator") and fID ~= "cp" and fID ~= "bureau" then
            return HL2RP.Notify(ply, "Not authorized to issue fines.", "error")
        end

        local target = nut.util.FindPlayer(args[1])
        local amount = tonumber(args[2])
        local charge = table.concat(args, " ", 3)

        if not IsValid(target) or not target:GetCharacter() then
            return HL2RP.Notify(ply, "Target not found.", "error")
        end
        if not amount or amount <= 0 then
            return HL2RP.Notify(ply, "Invalid amount.", "error")
        end

        HL2RP.Economy.Fine(target, amount, charge, ply)
    end
})

-- Admin only: grant or set credits
nut.command.add("setcredits", {
    adminOnly = true,
    syntax    = "<player> <amount>",
    desc      = "Set a player's credit balance (admin only).",
    onRun     = function(ply, args)
        if not HL2RP.HasRank(ply, "admin") then
            return HL2RP.Notify(ply, "Permission denied.", "error")
        end
        local target = nut.util.FindPlayer(args[1])
        local amount = tonumber(args[2])
        if not IsValid(target) or not target:GetCharacter() then
            return HL2RP.Notify(ply, "Target not found.", "error")
        end
        HL2RP.Economy.SetBalance(target, amount)
        HL2RP.Log("ECONOMY", ply:Name(), "SetCredits", target:Name(), tostring(amount))
        HL2RP.Notify(ply, string.format("Set %s balance to Ȼ%d.", target:GetCharacter():GetName(), amount), "info")
    end
})
