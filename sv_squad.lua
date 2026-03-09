--[[
    ITEM LIBRARY
    All item definitions in one organized file.
    In production, split these across items/food/, items/medical/, etc.
    ============================================================
--]]

-- ============================================================
-- FOOD ITEMS
-- ============================================================

ITEM.name         = "Ration Pack"
ITEM.desc         = "A standard Combine-issued ration pack. Contains a measured daily caloric allocation. The label reads: 'City 45 Nutritional Unit 3-B.'"
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"  -- TODO: Replace with ration model
ITEM.width        = 1; ITEM.height = 1
ITEM.isContraband = false
ITEM.hungerRestore= 40
ITEM.thirstRestore= 10
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "hunger", self.hungerRestore, "restore")
    HL2RP.Needs.Consume(ply, "thirst", self.thirstRestore, "restore")
    HL2RP.Notify(ply, "You eat the ration pack. It tastes like compressed nutrients.", "info")
    self:Remove()
end

---

ITEM.name         = "Protein Bar (Synthetic)"
ITEM.desc         = "A dense, chalky bar of synthetic protein and compressed carbohydrates. Not appetizing. Functional."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.width        = 1; ITEM.height = 1
ITEM.hungerRestore= 25
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "hunger", self.hungerRestore, "restore")
    self:Remove()
end

---

ITEM.name         = "Canned Beans"
ITEM.desc         = "A dented can of preserved beans. Pre-war brand. Expired, probably. Still edible."
ITEM.model        = "models/props_junk/garbage_metalcan001a.mdl"
ITEM.isContraband = false
ITEM.hungerRestore= 30
ITEM.thirstRestore= 5
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "hunger", self.hungerRestore, "restore")
    HL2RP.Needs.Consume(ply, "thirst", self.thirstRestore, "restore")
    self:Remove()
end

---

ITEM.name         = "Stale Bread"
ITEM.desc         = "A chunk of bread that is past its prime. Still better than nothing."
ITEM.model        = "models/props_interiors/pot001.mdl"
ITEM.isContraband = false
ITEM.hungerRestore= 20
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "hunger", self.hungerRestore, "restore")
    self:Remove()
end

---

ITEM.name         = "Water Bottle"
ITEM.desc         = "A clean bottle of purified water. Combine filtration stamp visible on the cap."
ITEM.model        = "models/props_junk/garbage_plasticbottle01a.mdl"
ITEM.isContraband = false
ITEM.thirstRestore= 45
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "thirst", self.thirstRestore, "restore")
    self:Remove()
end

---

ITEM.name         = "Dirty Water"
ITEM.desc         = "Water collected from an uncertain source. Drinking it might help your thirst, but it could also make you ill."
ITEM.model        = "models/props_junk/garbage_plasticbottle01a.mdl"
ITEM.isContraband = false
ITEM.thirstRestore= 35
ITEM.illnessChance= 0.2
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "thirst", self.thirstRestore, "restore")
    if math.random() < self.illnessChance then
        local char = ply:GetCharacter()
        if char then
            local flags = char:GetVar("medicalFlags") or {}
            flags.illness = { name = "Waterborne Infection", severity = "mild", timestamp = os.date() }
            char:SetVar("medicalFlags", flags)
            HL2RP.Notify(ply, "You feel nauseous. The water may have been contaminated.", "warning")
        end
    end
    self:Remove()
end

---

ITEM.name         = "Contraband Alcohol"
ITEM.desc         = "Unlabeled spirits in a repurposed bottle. Possession is a citation offense. Drinking it reduces stress considerably."
ITEM.model        = "models/props_junk/garbage_plasticbottle01a.mdl"
ITEM.isContraband = true
ITEM.stressReduce = 25
ITEM.thirstRestore= 10
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "stress", self.stressReduce, "restore")
    HL2RP.Needs.Consume(ply, "thirst", self.thirstRestore, "restore")
    HL2RP.Notify(ply, "The alcohol burns as it goes down. You feel your tension ease slightly.", "info")
    self:Remove()
end

---

ITEM.name         = "Premium Meal Package"
ITEM.desc         = "A high-tier Combine nutrition allocation. Reserved for high-loyalty citizens and upper-tier workers. Significantly more palatable than standard rations."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = false
ITEM.hungerRestore= 70
ITEM.thirstRestore= 20
ITEM.stressReduce = 10
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "hunger", self.hungerRestore, "restore")
    HL2RP.Needs.Consume(ply, "thirst", self.thirstRestore, "restore")
    HL2RP.Needs.Consume(ply, "stress", self.stressReduce, "restore")
    self:Remove()
end

-- ============================================================
-- MEDICAL ITEMS
-- ============================================================

ITEM.name         = "Bandage"
ITEM.desc         = "Basic cloth bandage. Stops minor bleeding. Inadequate for serious wounds."
ITEM.model        = "models/Items/HealthKit.mdl"
ITEM.isContraband = false
ITEM.healAmount   = 10
ITEM.stopsBleeding= true
function ITEM:OnUse(ply)
    ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + self.healAmount))
    if ply:GetCharacter() then
        ply:GetCharacter():SetVar("bleeding", false)
    end
    HL2RP.Notify(ply, "You bandage your wound.", "info")
    self:Remove()
end

---

ITEM.name         = "Sterile Bandage"
ITEM.desc         = "A properly packaged sterile dressing. Significantly reduces infection risk."
ITEM.model        = "models/Items/HealthKit.mdl"
ITEM.isContraband = false
ITEM.healAmount   = 15
ITEM.stopsBleeding= true
ITEM.clearsInfection = true
function ITEM:OnUse(ply)
    ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + self.healAmount))
    if ply:GetCharacter() then
        ply:GetCharacter():SetVar("bleeding", false)
        local flags = ply:GetCharacter():GetVar("medicalFlags") or {}
        flags.minorInfection = nil
        ply:GetCharacter():SetVar("medicalFlags", flags)
    end
    self:Remove()
end

---

ITEM.name         = "Painkillers"
ITEM.desc         = "Standard analgesic tablets. Reduces pain, provides minor stress relief. Authorized for civilian use."
ITEM.model        = "models/Items/HealthKit.mdl"
ITEM.isContraband = false
ITEM.healAmount   = 5
ITEM.stressReduce = 15
function ITEM:OnUse(ply)
    ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + self.healAmount))
    HL2RP.Needs.Consume(ply, "stress", self.stressReduce, "restore")
    self:Remove()
end

---

ITEM.name         = "Antibiotics"
ITEM.desc         = "A course of broad-spectrum antibiotics. Treats bacterial infection. Requires medical authorization for unrestricted use."
ITEM.model        = "models/Items/HealthKit.mdl"
ITEM.isContraband = false
ITEM.requiresPermit = "medical"
ITEM.clearsIllness = true
function ITEM:OnUse(ply)
    local valid = HL2RP.Permits.IsValid(ply, "medical") or HL2RP.InFaction(ply, "medic")
    if not valid then
        HL2RP.Notify(ply, "This medication requires a medical authorization.", "error")
        return
    end
    if ply:GetCharacter() then
        local flags = ply:GetCharacter():GetVar("medicalFlags") or {}
        flags.illness = nil
        flags.minorInfection = nil
        ply:GetCharacter():SetVar("medicalFlags", flags)
    end
    HL2RP.Notify(ply, "You take the antibiotics. You should feel better within the day.", "success")
    self:Remove()
end

---

ITEM.name         = "Antitoxin"
ITEM.desc         = "Emergency antitoxin compound. Used in cases of environmental contamination or poisoning."
ITEM.model        = "models/Items/HealthKit.mdl"
ITEM.isContraband = false
ITEM.requiresPermit = "medical"
ITEM.healAmount   = 20
function ITEM:OnUse(ply)
    ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + self.healAmount))
    if ply:GetCharacter() then
        local flags = ply:GetCharacter():GetVar("medicalFlags") or {}
        flags.poisoning = nil
        flags.contamination = nil
        ply:GetCharacter():SetVar("medicalFlags", flags)
    end
    self:Remove()
end

---

ITEM.name         = "Stim Injector"
ITEM.desc         = "A pre-loaded adrenaline injector. Rapidly eliminates fatigue. Reserved for emergency use. Crash follows."
ITEM.model        = "models/Items/HealthKit.mdl"
ITEM.isContraband = true   -- Unauthorized use is contraband
ITEM.fatigueDrain = 80
function ITEM:OnUse(ply)
    HL2RP.Needs.Consume(ply, "fatigue", self.fatigueDrain, "restore")
    -- Crash: stress spikes after 2 minutes
    timer.Simple(120, function()
        if IsValid(ply) then
            HL2RP.Needs.Consume(ply, "stress", 30, "drain")
            HL2RP.Notify(ply, "The stimulant is wearing off. Your body crashes.", "warning")
        end
    end)
    HL2RP.Notify(ply, "Adrenaline floods your system. Fatigue vanishes briefly.", "info")
    self:Remove()
end

---

ITEM.name         = "Trauma Kit"
ITEM.desc         = "A full trauma response kit. Restores significant health. Requires basic medical knowledge to use effectively."
ITEM.model        = "models/Items/HealthKit.mdl"
ITEM.isContraband = false
ITEM.requiresPermit = "medical"
ITEM.healAmount   = 50
function ITEM:OnUse(ply)
    local valid = HL2RP.Permits.IsValid(ply, "medical") or HL2RP.InFaction(ply, "medic")
    if not valid then
        -- Can still use but less effective without training
        HL2RP.Notify(ply, "Without medical training, this kit is partially effective.", "warning")
        ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 25))
    else
        ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + self.healAmount))
    end
    self:Remove()
end

---

ITEM.name         = "Medical Scanner"
ITEM.desc         = "A handheld biometric scanner used by Civil Medical Authority staff to assess patient vitals."
ITEM.model        = "models/Items/HealthKit.mdl"
ITEM.isContraband = false
ITEM.requiresFaction = "medic"
function ITEM:OnUse(ply)
    -- TODO: Open medical scanner UI to assess nearby player
    HL2RP.Notify(ply, "Medical scanner activated. Approach a patient and use /scan <player>.", "info")
end

-- ============================================================
-- TOOLS
-- ============================================================

ITEM.name         = "Toolbox"
ITEM.desc         = "A worn but functional toolbox. Required for certain repair tasks."
ITEM.model        = "models/props_c17/toolbox01.mdl"
ITEM.isContraband = false
ITEM.allowedJobs  = { "repair", "maintenance" }

ITEM.name         = "Handheld Radio"
ITEM.desc         = "A civilian-model radio transceiver. Operates on standard open frequencies. Not encrypted."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = false
ITEM.radioType    = "civilian"
ITEM.frequency    = 0  -- Set on use

ITEM.name         = "Combine Radio"
ITEM.desc         = "CP-issue encrypted radio transceiver. Access restricted to authorized personnel."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true  -- Illegal for civilians
ITEM.requiresFaction = "cp"
ITEM.radioType    = "combine"
ITEM.encrypted    = true

ITEM.name         = "Flashlight"
ITEM.desc         = "A standard battery-powered flashlight. Essential in the lower districts."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = false

ITEM.name         = "Zip Ties"
ITEM.desc         = "Plastic restraints. Used by Civil Protection for detainment. Possession by civilians is suspicious."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.requiresFaction = "cp"

ITEM.name         = "Crowbar"
ITEM.desc         = "A heavy iron pry bar. Useful for many tasks. Not technically a weapon. Technically."
ITEM.model        = "models/weapons/w_crowbar.mdl"
ITEM.isContraband = false
ITEM.isWeapon     = true
ITEM.damage       = 20

ITEM.name         = "Lockpick Set"
ITEM.desc         = "A small set of picks and tension wrenches. Possession is a criminal offense. Extremely useful."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true

ITEM.name         = "Permit Printer"
ITEM.desc         = "A compact thermal printer loaded with permit-grade paper. Used by Bureau and CWU staff."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.requiresFaction = "bureau"

ITEM.name         = "Ration Stamp"
ITEM.desc         = "A physical coupon entitling the holder to one additional ration unit at the distribution terminal."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = false
ITEM.rationValue  = 1

-- ============================================================
-- DOCUMENTS
-- ============================================================

ITEM.name         = "Citizen Identification Card"
ITEM.desc         = "A laminated card bearing a photographic identification and CID number. Mandatory for all residents of City 45."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = false
ITEM.isDocument   = true

ITEM.name         = "Ration Allocation Card"
ITEM.desc         = "Tracks the holder's ration allocation status. Must be presented at distribution points."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = false
ITEM.isDocument   = true

ITEM.name         = "Fake ID Card"
ITEM.desc         = "A falsified identity card bearing a fabricated name and CID. High-quality forgery. Very illegal."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.isForged     = true
ITEM.detectChance = 0.2

ITEM.name         = "Work Permit"
ITEM.desc         = "An official document authorizing the holder to perform assigned labor within City 45."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = false
ITEM.isDocument   = true
ITEM.permitType   = "work"

ITEM.name         = "Arrest Report Pad"
ITEM.desc         = "A CP-issued notepad pre-formatted for incident reports. Required for formal arrest logging."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.requiresFaction = "cp"

ITEM.name         = "Evidence Bag"
ITEM.desc         = "A sealed evidence container used by Civil Protection to store confiscated materials."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.requiresFaction = "cp"
ITEM.isEvidenceBag = true

ITEM.name         = "Wanted Notice"
ITEM.desc         = "An official document declaring the named individual to be sought by Civil Protection."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isDocument   = true

-- ============================================================
-- CONTRABAND
-- ============================================================

ITEM.name         = "Rebel Pamphlet"
ITEM.desc         = "A crudely printed leaflet containing anti-Combine rhetoric and calls to action. Highly illegal. Dangerously persuasive."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.tensionGain  = 3
ITEM.suspicionGain= 15
function ITEM:OnFound(finder, owner)
    -- Called when CP finds this during a search
    HL2RP.Tension.Modify(finder:Name(), "crime_reported")
    HL2RP.Datafiles.LogCrime(finder, owner:GetCharacter(), "Rebel Propaganda Possession", "moderate")
end

ITEM.name         = "Encrypted Note"
ITEM.desc         = "A small slip of paper covered in cipher text. Could be resistance communications, black market arrangements, or something else entirely."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.isEncrypted  = true
ITEM.cipherKey    = ""  -- Set dynamically when created

ITEM.name         = "Hacked Radio"
ITEM.desc         = "A civilian radio modified to access encrypted frequencies. Illegal. Useful."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.radioType    = "hacked"
ITEM.canScanFreqs = true

ITEM.name         = "Permit Forgery Kit"
ITEM.desc         = "A collection of materials needed to replicate official permit documents. Highly illegal. Professionally made."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.durability   = 3   -- Can produce 3 forged permits before depleted

ITEM.name         = "Anti-Combine Graffiti Can"
ITEM.desc         = "A spray can loaded with vivid red paint and an accompanying stencil bearing resistance imagery."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.tensionGain  = 5
ITEM.suspicionGain= 10

ITEM.name         = "Illegal Ammunition"
ITEM.desc         = "Unlicensed ammunition rounds. Possession without a restricted goods permit is a major offense."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true

ITEM.name         = "Rebel Mask"
ITEM.desc         = "A cloth mask bearing resistance iconography. Wearing it during CP encounters increases suspicion considerably."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.suspicionGain= 20  -- On equip

ITEM.name         = "Smuggler's Satchel"
ITEM.desc         = "A reinforced bag with concealed compartments. Items stored inside are harder to detect in a search."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.concealBonus = 0.2  -- Reduces stash detection chance by 20%

-- ============================================================
-- CRAFTING MATERIALS
-- ============================================================

ITEM.name         = "Metal Scrap"
ITEM.desc         = "Salvaged metal pieces. Used in crafting makeshift tools and weapons."
ITEM.model        = "models/props_junk/PopCan01a.mdl"
ITEM.isCraftingMat = true
ITEM.stackable     = true
ITEM.maxStack      = 20

ITEM.name         = "Electronic Salvage"
ITEM.desc         = "Circuit boards and wiring salvaged from discarded Combine equipment."
ITEM.model        = "models/props_junk/PopCan01a.mdl"
ITEM.isCraftingMat = true
ITEM.stackable     = true
ITEM.maxStack      = 10

ITEM.name         = "Cloth Scraps"
ITEM.desc         = "Torn fabric pieces. Useful for crafting basic bandages and disguises."
ITEM.model        = "models/props_junk/PopCan01a.mdl"
ITEM.isCraftingMat = true
ITEM.stackable     = true
ITEM.maxStack      = 15

ITEM.name         = "Chemical Reagents"
ITEM.desc         = "A small vial of unidentified chemical compounds. Used in medication crafting."
ITEM.model        = "models/props_junk/PopCan01a.mdl"
ITEM.isCraftingMat = true
ITEM.isContraband  = true  -- Unauthorized possession

-- ============================================================
-- SUPPORTER COSMETICS
-- ============================================================

ITEM.name         = "Founder's Badge"
ITEM.desc         = "A small enamel pin bearing the emblem of City 45's founding supporters. Rare. Recognized."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isCosmetic   = true
ITEM.supporterOnly = "founder"

ITEM.name         = "Supporter Radio Skin (Silver)"
ITEM.desc         = "A custom housing wrap for your radio unit — sleek silver finish with subtle engravings."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isCosmetic   = true
ITEM.supporterOnly = "silver"
ITEM.appliesTo    = "radio"

ITEM.name         = "Custom Passport Border (Gold)"
ITEM.desc         = "A replacement passport document with an elegant gold-foil border. Cosmetic only."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isCosmetic   = true
ITEM.supporterOnly = "gold"

ITEM.name         = "Apartment Decoration Kit"
ITEM.desc         = "A collection of small prop items approved for residential use. Makes a housing unit feel more like home."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isCosmetic   = true
ITEM.supporterOnly = "silver"
ITEM.aptDecoration = true

ITEM.name         = "Exclusive Coat (Founders)"
ITEM.desc         = "A well-maintained long coat bearing subtle resistance-adjacent iconography. Exclusive to server founders. Cosmetic only — carries no special RP powers."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isCosmetic   = true
ITEM.supporterOnly = "founder"
ITEM.isClothing   = true

-- ============================================================
-- COMBINE / OTA EQUIPMENT (Faction-restricted)
-- ============================================================

ITEM.name         = "OTA Command Uplink"
ITEM.desc         = "A heavy-duty tactical uplink device used by OTA commanders to interface with Overwatch network systems."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.requiresFaction = "ota"
ITEM.isContraband = true  -- Civilians must not possess this

ITEM.name         = "CP ID Card"
ITEM.desc         = "A Civil Protection identification card embedded with unit data and sector clearance information."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.requiresFaction = "cp"

ITEM.name         = "Sector Key"
ITEM.desc         = "An encrypted access token granting entry to restricted Combine administrative sectors. Grid Leader issue."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.requiresFaction = "cp"
ITEM.requiredRank = 6  -- Grid Leader only

-- ============================================================
-- RESISTANCE EQUIPMENT
-- ============================================================

ITEM.name         = "Dead Drop Container"
ITEM.desc         = "A small waterproof container used to leave messages and supplies at pre-arranged locations."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.isDeadDrop   = true
ITEM.requiresFaction = "resistance"

ITEM.name         = "Resistance Signal Jammer"
ITEM.desc         = "A crude device that disrupts Combine scanners within a limited radius. Single-use. Extremely illegal."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.requiresFaction = "resistance"
ITEM.jamRadius    = 300   -- Units
ITEM.jamDuration  = 60    -- Seconds

ITEM.name         = "Vort Bio-Cell"
ITEM.desc         = "A bioluminescent cell derived from Vortigaunt energy. Can be used to power makeshift resistance devices."
ITEM.model        = "models/Items/combine_rifle_ammo01.mdl"
ITEM.isContraband = true
ITEM.requiresFaction = "vortigaunt"
