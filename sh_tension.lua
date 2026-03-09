--[[
    plugins/needs_system/sv/sv_needs.lua
    Server-side needs processing.
    Runs drain timer, applies debuffs, syncs to clients.
--]]

local TICK_INTERVAL = 60  -- Process needs every 60 seconds

-- Initialize a character's needs on spawn
hook.Add("PlayerSpawn", "HL2RP_NeedsInit", function(ply)
    if not nut.config.get("needsEnabled") then return end
    if not IsValid(ply) or not ply:GetCharacter() then return end

    local char = ply:GetCharacter()
    -- Initialize if not yet set
    for _, need in ipairs(HL2RP.Needs.Types) do
        if char:GetVar(need.key) == nil then
            char:SetVar(need.key, 80)  -- Start at 80% satisfied
        end
    end
    -- Sync all need values to client
    HL2RP.Needs.SyncAll(ply)
end)

-- Drain timer
timer.Create("HL2RP_NeedsDrain", TICK_INTERVAL, 0, function()
    if not nut.config.get("needsEnabled") then return end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:GetCharacter() then continue end
        local char = ply:GetCharacter()

        for _, need in ipairs(HL2RP.Needs.Types) do
            local rate    = nut.config.get(need.configRate) or 0.5
            local current = char:GetVar(need.key) or 100
            local newVal

            if need.invert then
                -- Fatigue and stress increase over time
                newVal = math.Clamp(current + rate, need.min, need.max)
            else
                newVal = math.Clamp(current - rate, need.min, need.max)
            end

            char:SetVar(need.key, newVal)
        end

        HL2RP.Needs.ApplyDebuffs(ply)
        HL2RP.Needs.SyncAll(ply)
    end
end)

-- Apply movement / HP debuffs based on needs
function HL2RP.Needs.ApplyDebuffs(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    local char  = ply:GetCharacter()
    local speed = 1.0

    local hunger  = char:GetVar("hunger", 100)
    local thirst  = char:GetVar("thirst", 100)
    local fatigue = char:GetVar("fatigue", 0)
    local stress  = char:GetVar("stress", 0)

    -- Speed penalty from fatigue
    if fatigue >= 90 then
        speed = 0.5
    elseif fatigue >= 75 then
        speed = 0.75
    end

    -- HP drain from starvation
    if hunger <= 0 then
        local dmg = nut.config.get("starvationDamage") or 1
        ply:SetHealth(math.max(1, ply:Health() - dmg))
        HL2RP.Notify(ply, "You are starving. Find food immediately.", "error")
    elseif hunger <= 10 then
        HL2RP.Notify(ply, "You are dangerously malnourished.", "warning")
    end

    -- HP drain from dehydration
    if thirst <= 0 then
        local dmg = nut.config.get("dehydrationDamage") or 2
        ply:SetHealth(math.max(1, ply:Health() - dmg))
        HL2RP.Notify(ply, "Severe dehydration. Find water immediately.", "error")
    elseif thirst <= 10 then
        HL2RP.Notify(ply, "You are severely dehydrated.", "warning")
    end

    -- Stress debuffs (future: accuracy reduction, chat disturbance)
    if stress >= 95 then
        HL2RP.Notify(ply, "Your nerves are shattered. Your hands tremble.", "warning")
    end

    -- Apply speed modifier
    ply:SetRunSpeed(math.floor(200 * speed))
    ply:SetWalkSpeed(math.floor(100 * speed))
end

-- Sync a single need to a player's client
function HL2RP.Needs.Sync(ply, key, value)
    net.Start("HL2RP_NeedsSync")
        net.WriteString(key)
        net.WriteFloat(value)
    net.Send(ply)
end

-- Sync all needs
function HL2RP.Needs.SyncAll(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    local char = ply:GetCharacter()
    for _, need in ipairs(HL2RP.Needs.Types) do
        HL2RP.Needs.Sync(ply, need.key, char:GetVar(need.key) or 100)
    end
end

-- Consume a need (e.g., eating food restores hunger)
-- direction: "restore" increases satisfaction, "drain" decreases it
function HL2RP.Needs.Consume(ply, needKey, amount, direction)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    local char   = ply:GetCharacter()
    local need   = nil
    for _, n in ipairs(HL2RP.Needs.Types) do
        if n.key == needKey then need = n; break end
    end
    if not need then return end

    local current = char:GetVar(needKey) or 50
    local newVal

    if direction == "restore" then
        if need.invert then
            newVal = math.Clamp(current - amount, need.min, need.max)
        else
            newVal = math.Clamp(current + amount, need.min, need.max)
        end
    else
        if need.invert then
            newVal = math.Clamp(current + amount, need.min, need.max)
        else
            newVal = math.Clamp(current - amount, need.min, need.max)
        end
    end

    char:SetVar(needKey, newVal)
    HL2RP.Needs.Sync(ply, needKey, newVal)
end

util.AddNetworkString("HL2RP_NeedsSync")
