# City 45: Under Occupation — HL2RP NutScript Schema
## Complete Setup & Administration Guide
### Version 1.0.0

---

## TABLE OF CONTENTS

1. Overview
2. Installation
3. Folder Structure
4. Configuration
5. Factions Reference
6. Plugin Overview
7. Item System
8. Economy Balancing
9. Supporter / Donor System
10. Admin Guide
11. Command Reference
12. Expanding the Schema
13. Performance Notes
14. Balancing Notes

---

## 1. OVERVIEW

City 45: Under Occupation is a full-featured NutScript schema for Half-Life 2 Roleplay. It is designed for serious, immersive community RP servers with long-term character development, deep faction systems, and a living-world event framework.

**Core Design Pillars:**
- Roleplay-first over action gameplay
- Meaningful progression that takes time
- A city that reacts to player actions (tension system)
- Factions with purpose, restrictions, and depth
- Fair supporter perks that don't break gameplay balance
- Strong admin tooling for running a healthy server

---

## 2. INSTALLATION

### Requirements
- Garry's Mod dedicated server
- NutScript framework (https://github.com/rebel1324/NutScript) installed to `garrysmod/gamemodes/nutscript`
- A compatible HL2RP map (recommended: rp_city45_v2, rp_c18_v1, or similar)

### Steps

1. Copy the `hl2rp/` folder into `garrysmod/gamemodes/`
2. Rename if needed to match your intended schema folder name
3. In `schema/meta/schema.lua`, update:
   - `SCHEMA.steamgroup`
   - `SCHEMA.discord`
   - `SCHEMA.website`
4. Copy all plugin folders from `plugins/` into your schema's plugin directory
5. Start the server with `+gamemode nutscript +map rp_yourchosenmap`
6. Open the config file at `schema/config/sh_config.lua` and tune values for your server
7. Assign yourself admin via `ulx adduser <yourname> superadmin` in console

### Database
NutScript uses SQLite by default. For production servers, configure NutScript to use MySQL via its built-in MySQL module. Character data, permits, and apartments are saved through NutScript's character system plus flat-file JSON for apartments and logs.

---

## 3. FOLDER STRUCTURE

```
hl2rp/
├── schema/
│   ├── meta/
│   │   └── schema.lua              # Schema identity
│   ├── config/
│   │   └── sh_config.lua           # ALL tunable values
│   ├── languages/
│   │   └── sh_language.lua         # Localizable strings
│   ├── libs/
│   │   └── sh_util.lua             # Shared utility library
│   ├── factions/
│   │   ├── sh_citizen.lua
│   │   ├── sh_cp.lua
│   │   ├── sh_ota.lua
│   │   ├── sh_resistance.lua
│   │   └── sh_other_factions.lua   # CWU, Loyalist, Vort, Smuggler, Medic, Bureau
│   ├── items/
│   │   └── sh_items.lua            # Full item library
│   └── ui/
│       ├── cl_mainhud.lua          # Main HUD
│       └── panels/                 # Individual UI panels
│
├── plugins/
│   ├── needs_system/               # Hunger/thirst/fatigue/stress
│   ├── tension_meter/              # City tension tracking
│   ├── permits_papers/             # Document and permit system
│   ├── datafiles/                  # Citizen records
│   ├── economy/                    # Credits, salaries, fines
│   ├── apartments/                 # Housing system
│   ├── arrests_enforcement/        # CP enforcement toolkit
│   ├── city_events/                # Dynamic world events
│   ├── dispatch/                   # Announcements and broadcasts
│   ├── black_market/               # Underground economy
│   ├── crafting/                   # Item crafting
│   ├── cwu_labor/                  # Task board and jobs
│   ├── radio_comms/                # Radio channels
│   ├── chat_classes/               # /me /it /y /w etc.
│   ├── character_creation/         # Backgrounds, traits, flaws
│   ├── progression/                # Ranks, commendations, reputation
│   ├── supporter_donor/            # Tier system and perks
│   ├── admin_tools/                # Admin utilities
│   ├── logging/                    # Audit trail
│   ├── vortigaunt/                 # Vort abilities and flavor
│   ├── resistance/                 # Resistance cells, sabotage
│   ├── civilian_depth/             # Interviews, journals, rumors
│   └── combine_systems/            # CP/OTA tactical tools
│
└── docs/
    └── README.md                   # This file
```

---

## 4. CONFIGURATION

All configuration is in `schema/config/sh_config.lua`. Key values:

| Key | Default | Description |
|-----|---------|-------------|
| `startingCredits` | 50 | Credits new characters receive |
| `salaryInterval` | 300 | Seconds between salary payouts |
| `needsEnabled` | true | Toggle the needs (hunger etc.) system |
| `hungerRate` | 0.5 | Hunger drain per minute |
| `tensionLockdownThresh` | 80 | Tension level that triggers lockdown |
| `eventInterval` | 600 | Min seconds between random events |
| `apartmentRent` | 20 | Credits deducted per rent cycle |
| `permitExpiry` | 72 | Hours before permits expire |
| `forgeryDetectChance` | 0.25 | Chance a forged doc is caught |
| `promotionCooldown` | 86400 | Seconds between rank promotions (24h) |
| `radioRange` | 600 | Units range for civilian radio |
| `curfewStartHour` | 22 | Hour curfew begins |
| `curfewEndHour` | 6 | Hour curfew ends |

---

## 5. FACTIONS REFERENCE

| Faction | Whitelist | Pay/Cycle | Purpose |
|---------|-----------|-----------|---------|
| Citizen | No | 0 | Default survival faction |
| Loyalist | No | 90 | Collaborator, informant path |
| Civil Workers' Union | No | 60–190 | Labor, distribution, admin |
| Civil Protection | Yes | 60–280 | Law enforcement |
| Overwatch Transhuman Arm | Yes | 300–600 | Elite Combine military |
| Resistance | Yes | 0 (mission-based) | Underground anti-Combine |
| Vortigaunt | Yes | 0 | Alien spiritual/biological |
| Black Market Operative | Yes | 0 (trade-based) | Underground economy |
| Civil Medical Authority | No | 80–200 | Healthcare |
| City Administration Bureau | Yes | 120–250 | Permits, housing, records |

### Whitelist Process
To whitelist a player, use:
```
/whitelist <player> <faction_id>
```
Faction IDs: `cp`, `ota`, `resistance`, `vortigaunt`, `smuggler`, `admin_bureau`

---

## 6. PLUGIN OVERVIEW

### Needs System
Tracks hunger, thirst, fatigue, and stress (0–100). Drain rates are configurable. At 0, HP drain begins. Client HUD shows bars with color warnings. Disable in config with `needsEnabled = false`.

### Tension Meter
Global 0–100 value tracking city volatility. Increases from crime, sabotage, and events. Decays over time. At 80: lockdown broadcasts. At 90: OTA deployment alert. Affects black market prices and event frequency.

### Permits & Papers
Physical item + character data system. Permits have expiry times and can be forged. `/issuepermit`, `/revokepermit`, `/inspectpapers`, `/forgepermit`.

### Datafiles
Tiered citizen records. Citizens see limited data; CP sees enforcement records; Bureau sees everything. All reads/writes are logged. `/viewdatafile`, `/addnote`.

### Economy
Credits (tokens), salaries by faction rank, fines, transfers. `/pay`, `/balance`, `/fine`, `/setcredits`.

### Apartments
Assignment, rent cycles, eviction, hidden stash (with detection chance). `/assignapt`, `/evict`, `/aptinspect`.

### Arrests & Enforcement
Full CP toolkit. Detain, search, confiscate, formal arrest with timers. Warrant system and BOLO notices. `/detain`, `/release`, `/search`, `/arrest`, `/warrant`, `/charges`.

### City Events
9 scripted event types firing randomly based on tension and time. Admins can manually start/stop. Events affect dispatch, tension, and faction behavior.

### Dispatch
City-wide broadcast system with ambient announcement pool, curfew triggers, CP-only dispatch channel, and propaganda terminal support.

### Black Market
Hidden vendor system with rotating stock, reputation gates, code-phrase access, and police sting risk. Dynamic pricing affected by city tension.

### Crafting
Recipe-based system with ingredient consumption, workbench requirements, craft timers, and faction restrictions. Illegal items raise suspicion.

### CWU Labor
Task board with 11 legal and 5 illegal job types. Dynamic board refreshes every 30 minutes. Payouts scale by faction rank. `/tasklist`, `/taskaccept`, `/taskcomplete`.

### Radio
Multi-channel radio with faction-gated encrypted channels. Range checks for open channels. Dead drop note system for resistance. `/radio`, `/setchannel`, `/channels`.

### Progression
Rank advancement with commendation requirements and cooldowns. Loyalty score (compliance) and suspicion heat (resistance) tracking. Social standing system. `/promote`, `/demote`, `/commend`, `/demerit`, `/mystatus`.

### Supporter/Donor
5 tiers: Supporter, Bronze, Silver, Gold, Founder. All perks are cosmetic, QoL, or prestige. No combat advantages. Admin assigns via `/setsupporter`.

### Civilian Depth
Loyalty interview mini-system, citizen informant reporting, rumor spreading, character journal, scar/injury notes.

### Vortigaunt
Heal, Zap, Sense, and Ritual abilities with cooldowns and rank scaling. Unique speech formatting in chat. `/vheal`, `/vzap`, `/vsense`, `/vritual`.

### Resistance
Cell system, heat tracking, disguise items, sabotage objectives, safehouse designation. `/createcell`, `/recruitcell`, `/sabotage`, `/disguise`.

---

## 7. ITEM SYSTEM

Items are defined in `schema/items/sh_items.lua`. Key properties:

| Property | Type | Description |
|----------|------|-------------|
| `isContraband` | bool | Flags as illegal; causes issues if found in search |
| `isDocument` | bool | Physical paper document |
| `permitType` | string | Links to a permit type |
| `hungerRestore` | number | Hunger restored on use |
| `thirstRestore` | number | Thirst restored on use |
| `stressReduce` | number | Stress reduced on use |
| `healAmount` | number | HP restored on use |
| `requiresFaction` | string | Faction ID required to use |
| `isCosmetic` | bool | Cosmetic-only item |
| `supporterOnly` | string | Tier required to equip |

---

## 8. ECONOMY BALANCING

**Starting state:** Citizens have Ȼ50. Ration packs cost ~Ȼ15 on the black market.

**Salary scale:**
- Citizen: Ȼ0 (tasks only)
- CWU Worker: Ȼ50/cycle
- CP Recruit: Ȼ60/cycle
- CP Grid Leader: Ȼ280/cycle
- OTA Commander: Ȼ600/cycle

**Balancing tips:**
- Keep `salaryInterval` at 300–600 seconds (5–10 min) for active servers
- Black market markup of 1.75× means contraband costs ~1.75× base price, scaling higher with tension
- Task payouts range from Ȼ12–150; illegal tasks pay more but risk suspicion
- Apartments rent Ȼ20 per 48h — affordable for employed citizens, tight for unemployed

---

## 9. SUPPORTER / DONOR SYSTEM

### Tier Assignment
```
/setsupporter <player> <tier>
```
Tiers: `supporter`, `bronze`, `silver`, `gold`, `founder`

### What Each Tier Gets

| Perk | Supporter | Bronze | Silver | Gold | Founder |
|------|-----------|--------|--------|------|---------|
| Extra char slots | +1 | +1 | +2 | +3 | +4 |
| OOC nameplate | ✓ | ✓ | ✓ | ✓ | ✓ |
| Reserved slot | ✗ | ✗ | ✓ | ✓ | ✓ |
| Extra storage | 0 | +3 | +5 | +8 | +10 |
| Donor locker | ✗ | ✗ | ✓ | ✓ | ✓ |
| Custom graffiti | ✗ | ✓ | ✓ | ✓ | ✓ |
| PAC+ permissions | ✗ | ✗ | ✗ | ✓ | ✓ |
| Founder badge | ✗ | ✗ | ✗ | ✗ | ✓ |

**Critical Rule:** No donor tier gives combat advantages, better weapons, or unfair RP power. All perks are cosmetic, convenience, or prestige.

---

## 10. ADMIN GUIDE

### Essential First Steps
1. Assign yourself superadmin
2. Whitelist your test accounts for factions you want to test
3. Set tension to 0 via console: `lua_run HL2RP.Tension.current = 0`
4. Create test apartments with `/assignapt <plyname> apt_001`

### Moderation Commands
| Command | Use |
|---------|-----|
| `/warn <ply> <reason>` | Issue a warning |
| `/warnings <ply>` | View warnings |
| `/addnoteadmin <ply> <note>` | Add private staff note |
| `/whitelist <ply> <faction>` | Whitelist for faction |
| `/unwhitelist <ply> <faction>` | Remove whitelist |
| `/commend <ply> <reason>` | Issue commendation |
| `/demerit <ply> <reason>` | Issue demerit |
| `/promote <ply>` | Promote one rank |
| `/demote <ply> [reason]` | Demote one rank |

### Event Management
| Command | Use |
|---------|-----|
| `/startevent <id>` | Manually start an event |
| `/endevent <id>` | End an event |
| `/listevents` | List all events |
| `/pauseevents` | Toggle auto event scheduling |

### Audit & Logs
| Command | Use |
|---------|-----|
| `/adminlogs [category] [limit]` | View log buffer |
| `/playerlogs <ply>` | View all logs for a player |
| `/economyaudit` | View all player balances |

---

## 11. COMMAND REFERENCE (QUICK)

### Citizens
`/pay` `/balance` `/tasklist` `/taskaccept` `/taskcomplete` `/journal` `/addscar` `/rumor` `/report` `/mystatus` `/craft` `/recipes` `/radio` `/setchannel` `/dropenote` `/collectdrop`

### CP
`/detain` `/release` `/search` `/arrest` `/charges` `/warrant` `/fine` `/revokepermit` `/issuepermit` `/inspectpapers` `/viewdatafile` `/addnote` `/dispatch` `/broadcast` `/startinterview` `/iq`

### Resistance
`/createcell` `/recruitcell` `/cellinfo` `/setsafehouse` `/sabotage` `/disguise` `/removedisguise` `/anon` `/dropenote` `/forgepermit`

### CWU
`/taskaccept` `/taskcomplete` `/union` `/assignapt`

### Vortigaunt
`/vheal` `/vzap` `/vsense` `/vritual`

### Admin/Staff
`/warn` `/warnings` `/addnoteadmin` `/whitelist` `/unwhitelist` `/commend` `/demerit` `/promote` `/demote` `/setcredits` `/setsupporter` `/removesupporter` `/startevent` `/endevent` `/listevents` `/adminlogs` `/playerlogs` `/broadcast` `/propaganda`

---

## 12. EXPANDING THE SCHEMA

### Adding a New Faction
1. Create `schema/factions/sh_yourfaction.lua`
2. Define all FACTION.* properties
3. Add ranks, equipment, relations
4. Add faction ID to any relevant access lists in permits, datafiles, radio channels

### Adding New Items
1. Add to `schema/items/sh_items.lua` or a new category file
2. Define: name, desc, model, isContraband, and an OnUse function
3. If it restores needs, call `HL2RP.Needs.Consume()`
4. If it's a permit, set `permitType`

### Adding New Events
1. Add an entry to `HL2RP.Events.Definitions` in `plugins/city_events/sv/sv_events.lua`
2. Define: `onStart`, `onEnd`, `weight`, `tensionGain`, `duration`, `requirements`
3. Events fire automatically based on weight — no other registration needed

### Adding New Tasks
1. Add to `HL2RP.Labor.LegalTasks` or `HL2RP.Labor.IllegalTasks`
2. Set `payout`, `duration`, `category`, optional `requiredItem`, `factionBonus`

### Adding New Crafting Recipes
1. Add to `HL2RP.Crafting.Recipes` in `plugins/crafting/sv/sv_crafting.lua`
2. Define ingredients, result, craftTime, workbench requirement, and faction restriction

### Adding a Map Integration
1. Place `hl2rp_workbench` entities in Hammer for crafting benches
2. Place `hl2rp_sabotage_target` entities for resistance sabotage objectives
3. Place `hl2rp_vendor_*` entities for NPC vendors (see npcs_vendors plugin)
4. Define apartment IDs matching your map's residential entity names

---

## 13. PERFORMANCE NOTES

- The needs system runs every 60 seconds — minimal overhead
- The tension meter decays every 60 seconds — minimal overhead
- Task board refreshes every 30 minutes
- Black market vendor restocks every hour
- Log buffer caps at 500 entries to avoid memory growth
- Net messages use string compression where possible
- All server-authoritative checks prevent client abuse
- Avoid running more than 3 concurrent events (configurable)

---

## 14. BALANCING NOTES

**Citizen progression to resistance is intentionally slow.** A player should spend meaningful time as a citizen before earning a resistance whitelist. This creates RP history and makes resistance players feel earned.

**CP should not be the default faction for new players.** CP is whitelisted and requires demonstrated understanding of the server's rules and RP standards.

**The tension meter creates natural ebb and flow.** Don't forcibly keep it at 0 — let it rise and fall organically. High tension makes for better RP.

**Black market prices should feel risky.** The 1.75× markup plus tension scaling means contraband is a luxury. Adjust `blackMarketMarkup` if your economy feels off.

**Salary cycles matter.** If salaries feel too generous, increase the interval. If players can't afford rent, lower it or raise CWU task payouts.

---

*City 45: Under Occupation — Built for serious HL2RP communities.*
*Expand freely. Credit appreciated but not required.*
