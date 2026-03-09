--[[
    schema/libs/sh_vortspeak.lua
    VORTIGAUNT SPEECH FORMATTING
    ============================================================
    Shared utility for applying Vortigaunt speech
    flavor to chat messages. Called by the chat class
    and vortigaunt plugin.
    ============================================================
--]]

-- Vort vocabulary additions and substitutions
local VORT_SUBSTITUTIONS = {
    ["I"]        = "The Freeman's allies",
    ["you"]      = "the flesh-bound",
    ["the"]      = "the",
    ["Combine"]  = "the Enslavers",
    ["humans"]   = "the brief ones",
    ["friend"]   = "soul-kin",
    ["enemy"]    = "shadow-bringer",
    ["eat"]      = "take sustenance",
    ["run"]      = "flee upon many legs",
    ["help"]     = "extend the vortessence",
    ["hurt"]     = "wound the essence",
    ["die"]      = "return to the flow",
    ["dead"]     = "beyond the current",
    ["alive"]    = "still within the flow",
    ["city"]     = "the pen of stone",
    ["freedom"]  = "the open current",
    ["work"]     = "the bound labor",
    ["rest"]     = "stillness within the flow",
    ["pain"]     = "the severing sting",
    ["fight"]    = "the great churning",
    ["war"]      = "the long severing",
}

-- Vort sentence prefixes (randomly prepended)
local VORT_PREFIXES = {
    "The vortessence whispers — ",
    "Ah, the currents say — ",
    "Yes, yes — ",
    "We perceive — ",
    "The flow speaks — ",
    "In the great current — ",
    "",  -- Sometimes no prefix
    "",
    "",
}

-- Vort suffixes
local VORT_SUFFIXES = {
    " — the current carries it.",
    " — so speaks the essence.",
    " — this the Freeman's allies have seen.",
    " — yes.",
    "",
    "",
    "",
}

function HL2RP.VortigauntFormat(msg)
    if not msg then return "" end

    -- Apply word substitutions (case-insensitive)
    local result = msg
    for from, to in pairs(VORT_SUBSTITUTIONS) do
        result = result:gsub("(%f[%a])" .. from .. "(%f[%A])", to)
    end

    -- Random prefix/suffix
    local prefix = VORT_PREFIXES[math.random(#VORT_PREFIXES)]
    local suffix = VORT_SUFFIXES[math.random(#VORT_SUFFIXES)]

    return prefix .. result .. suffix
end

-- Vort ability flavor text for /vritual
HL2RP.VortRitualTexts = {
    healing  = {
        "The vortessence flows between us, mending what the Enslavers have torn.",
        "Still your breath. The current knows where the wound is.",
        "Pain is merely the flow meeting resistance. We smooth it now.",
    },
    sensing  = {
        "The currents carry impressions of the hidden. We read them.",
        "Ah — the shadow-threads are visible to those who look.",
        "Something moves beneath the surface of things. We sense it.",
    },
    commune  = {
        "We reach through the vortessence to touch that which cannot be touched.",
        "The great current stretches across all. Even here. Even now.",
        "In the pen of stone, the flow still moves. Listen.",
    },
    warning  = {
        "The currents are troubled. Something comes that should not.",
        "We have seen this shape before — in the long severing.",
        "The flesh-bound cannot see it, but the vortessence screams.",
    },
}

function HL2RP.GetVortFlavor(category)
    local pool = HL2RP.VortRitualTexts[category]
    if not pool then return "The current speaks." end
    return pool[math.random(#pool)]
end
