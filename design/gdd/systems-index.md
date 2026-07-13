# Systems Index: Symbots

> **Status**: Draft
> **Created**: 2026-07-09
> **Last Updated**: 2026-07-12 (**+2 systems captured** mid-#12 Zone & World Map design (user decision): **#10b Symbot Core Progression (Leveling)** — MVP Gameplay; the CORE is the Symbot's non-fungible *leveled* anchor, core level ← **battle XP only** (unbuyable — Scrap only upgrades parts), gates equipping high-tier parts via `level_requirement`, bounded stat growth as one of three progression legs, bench XP-share; fills symbot-assembly.md's open "CORE identity mechanical enforcement" obligation; **pending obligations before its design pass: game-concept anti-pillar revision + CD sign-off, errata to Approved Symbot Assembly + Part Database**. **#29 Auto-Adventure Dispatch** — Full Vision Meta (endgame idle/dispatch for XP+items). Totals 32→34; MVP designed denom 23→24; Full Vision denom 1→2. Zone & World Map #12 resumes (edge model unaffected). Prior: **Consumable Database (#1c) AUTHORED → Designed** via /design-system (lean; systems-designer + economy-designer + qa-lead consulted for Formulas/ACs). 8-item roster, schema + Rules 1–10 + CD-1..CD-5 formulas (all epsilon-exempt) + 24 ACs (18 BLOCKING/2 ADV/4 DEFERRED) + buy/sell pricing (buy>sell invariant). Registry: 8 items + 5 formulas + 10 constants added (YAML validated). Design docs started 11→12; MVP designed 11→12/23. **3 pending errata** (TBC use-item action / Drop consumable channel + Beacon / Encounter Zone EZ-1 modifier hook) to apply on approval. Next: fresh-session /design-review. **New deferred system #23a Key Item System** (Meta, Vertical Slice) — story/plot key items (unique, non-consumable, un-scrappable) that gate narrative/world progression; explicitly NOT the Consumable Database, NOT a rarity tier. Totals 31→32; Vertical Slice denom 2→3. Also flagged: NPC shops as a post-MVP consumable faucet (MVP is drops-only). **SCOPE ADDITION — Consumable items pulled into MVP** (user decision). New Foundation system **#1c Consumable Database** added (standalone schema authority; no Part DB dependency; design-order slot 10a, before Inventory #11). MVP drop taxonomy is now **parts + scrap + consumables** (designs/blueprints stay Alpha per HOLISM-01). Initial roster (6, world-themed salvage-tech): **Repair Kit** (Structure heal, tiered), **Coolant Flush** (Heat dump), **Power Cell** (Energy restore), **Salvage Beacon** (drop-odds boost → Drop System conditions), **Signal Jammer** (repel), **Scrap Lure** (lure). Drop source = **global level/rarity-scaled table** (no Enemy DB errata). **Pending errata (to be authored in the Consumable DB GDD):** (1) **TBC** — add `use item` to the battle action set (Rule 3: move/switch/flee → +use-item; consumes the turn, no Heat/Energy cost) + AC; (2) **Drop System** — consumables as a level/rarity-scaled drop output class + Salvage Beacon → drop-condition multiplier feedback; (3) **Encounter Zone** — un-defer OQ-EZ-4: add an `encounter_rate` modifier hook to EZ-1 (Signal Jammer / Scrap Lure) + ACs. Each errata'd Approved doc needs a light re-review touch. Totals: 30→31 identified; MVP designed denominator 22→23. Prior same-day: Encounter Zone (#7) **APPROVED** — 3rd-round confirmation re-review, fresh-session full-panel /design-review (5 specialists + CD). **All five specialists returned ZERO blocking**; the Round 2 delta re-gate, `is_farmable_target`, and `requires_defeated` sequencing all verified correct at the discriminator level (LIGHTER_REGATE→ALWAYS_OPEN collapse genuinely closed; AC-EZ-22 central discriminator). CD verdict APPROVED WITH ONE MINOR REVISION — the lone survivor of the mature-doc triage, a spec-silent fail-safe gap on `requires_defeated` naming a non-existent boss, was closed same session: **EC-EZ-12 + AC-EZ-58** (broken-ref → fail-safe LOCKED, never fail-open). Two converged recommendations folded in: **Tuning Knob warning 5** (re-gate × density coupling) + **`is_farmable_target` authoring criterion**. 58→59 ACs (39 BLOCKING). No Round 4. **All 11 MVP GDDs authored so far are now Approved.** Prior 2026-07-12 (2nd round, NEEDS REVISION → punch-list): delta re-gate, Boss-1-first sequencing, is_farmable_target field. Prior 2026-07-11: Full-panel /design-review (5 specialists + CD): 4 blockers + 4 recommended resolved same session. **WAVE gate cut to Reserved** (off-pillar + wave_pools undefined) → both MVP bosses now WIN_COUNT on a shared cumulative zone-win counter (Boss 1 @ 6, Boss 2 @ 10). WIN_COUNT semantic made normative (Rule 8a, cumulative/all-time/wins-only). AC-EZ-25 ADVISORY→BLOCKING; AC-EZ-40 split 40a/40b; terrain identity+weight-floor guardrail (Rule 2a). 52→56 ACs. gate_type taxonomy now: OPEN/WIN_COUNT authorable, WAVE/REACH/DUNGEON_RUSH reserved. Prior: Turn-Based Combat **APPROVED** — Part-Break erratum fix-confirmation re-review, 2 AC-integrity blockers fixed; all 4 propagation/errata applied; /consistency-check PASS.)
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Symbots is a creature-collection RPG where the player builds and customizes a team
of modular robots (Symbots) from collected parts, then battles enemies to earn more
parts. The game requires three interconnected system families: a **data and formula
layer** that defines what parts, enemies, and damage look like; a **gameplay layer**
that governs the build loop, combat, and exploration; and a **presentation layer**
of UI, audio, and persistence that makes the loop accessible on mobile. Twenty-two
systems are required for a playable MVP spanning one zone with two bosses. The Part
Database is the central bottleneck — nine other systems depend on it and it must be
designed first.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Part Database | Foundation | MVP | Approved | design/gdd/part-database.md | — |
| 1a | Move Database | Foundation | MVP | Approved | design/gdd/move-database.md | Part Database |
| 1b | Passive Database | Foundation | MVP | Approved | design/gdd/passive-database.md | Part Database |
| 1c | Consumable Database | Foundation | MVP | Approved (2026-07-12, full-panel /design-review — NEEDS REVISION → 5 surgical blockers fixed same session; systems-designer IEEE-754 blocker refuted by python3 scan) | design/gdd/consumable-database.md | — (standalone schema authority; unlike 1a/1b it does **not** depend on Part Database) |
| 2 | Enemy Database | Foundation | MVP | Approved | design/gdd/enemy-database.md | Part Database |
| 3 | Damage Formula System | Foundation | MVP | Approved | design/gdd/damage-formula.md | Part Database |
| 4 | Symbot Assembly System | Gameplay | MVP | Approved | design/gdd/symbot-assembly.md | Part Database |
| 5 | Synergy System | Gameplay | MVP | Approved | design/gdd/synergy-system.md | Part Database, Symbot Assembly |
| 6 | Turn-Based Combat System | Gameplay | MVP | Approved (2026-07-11, Part-Break erratum fix-confirmation re-review — 2 AC-integrity blockers fixed same session) | design/gdd/turn-based-combat.md | Damage Formula, Symbot Assembly, Enemy Database, Synergy, Part Database, Part-Break |
| 7 | Encounter Zone System | World | MVP | Approved (2026-07-12, 3rd-round confirmation re-review — zero blocking; one minor revision EC-EZ-12/AC-EZ-58 + 2 converged recommendations applied same session) | design/gdd/encounter-zone.md | Enemy Database |
| 8 | Drop System | Economy | MVP | Approved (2026-07-11, re-review punch-list applied) | design/gdd/drop-system.md | Part Database, Enemy Database |
| 9 | Part-Break System | Gameplay | MVP | Approved (2026-07-11, fix-confirmation re-review — 3 surgical fixes applied) | design/gdd/part-break.md | Turn-Based Combat, Drop System |
| 10 | Enemy AI System | Gameplay | MVP | Approved (2026-07-12, **2nd full-panel /design-review** reopened the 1st-pass approval — NEEDS REVISION → 5 blockers fixed & fix-confirmed same session. Two spec-wrong gaps in the flagship fix: B1 df1_preview += MOVE-F1 power-tier; B2 kill-securing invariant += STATUS_BASE_VALUE coeff, SBV range 2.0→1.5. +RNG int-seed contract, AC-EAI-04 split, GDScript AC traps. 18→19 ACs) | design/gdd/enemy-ai.md | Turn-Based Combat, Enemy Database |
| 10b | Symbot Core Progression (Leveling) | Gameplay | MVP | Approved (2026-07-12, full-panel /design-review — NEEDS REVISION → 9 blockers fixed same session: Rule 2 signal semantics, game-concept Core Fantasy, core acquisition + register_core interface, bench-lead-cap UI surface, CP-F1 rounding procedure, AC-CP-06 discriminating example, AC-CP-18 DEFERRED, AC-CP-03 on-threshold sub-case, AC-CP-09 interface. OQ-CP-7 bench dead zone added. Introduces Level Backbone; 3 errata pending TBC/Assembly/Part DB) | design/gdd/symbot-core-progression.md | Symbot Assembly, Part Database, Turn-Based Combat, Enemy Level & Zone Scaling |
| 10c | Enemy Level & Zone Scaling | World | MVP | Approved (2026-07-12, round-4 confirmation pass — all round-3 fixes verified; 2 new AC fixture blockers + 4 recommended applied same session. B1: AC-ELZS-05 Fixture F at-floor acceptance for F > 1; B2: AC-ELZS-04 floor=0 rejection. R: AC-09 L1 fixture, Enemy DB AC-ED-14 integration contract note, economy sensitivity redistribution stated, HIGH-overstated qualifying clause. CD: APPROVED, no round 5. **4 errata owed**: Enemy DB / Encounter Zone / Drop System+economy-model / ZWM) | design/gdd/enemy-level-zone-scaling.md | Enemy Database, Encounter Zone, Drop System, Zone & World Map |
| 11 | Inventory System | Economy | MVP | Approved (2026-07-12, full-panel /design-review — NEEDS REVISION → 5 surgical blockers fixed same session: `next_instance_id` counter persisted (EC-INV-07 save/load), `instance_id` retyped plain int, INV-1 negative-qty/retune-down guards (EC-INV-11), Scrap-add `{accepted,rejected}` contract, OQ-INV-1 tier-refund LOCKED 0%. CD approve-on-fix-confirmation) | design/gdd/inventory.md | Part Database |
| 12 | Zone & World Map System | World | MVP | Approved (2026-07-12, full-panel /design-review — NEEDS REVISION → 8 blockers fixed same session: ZWM-F1 boss_progress scope, missing-key EC-ZWM-12/AC-ZWM-19, zone_states_changed diff payload, LOCKED-origin outbound travel EC-ZWM-05/AC-ZWM-20, AC-ZWM-11 concrete fixture, AC-ZWM-17/18 signal contract, AC-ZWM-05 fixture gap. 15→20 ACs / 11→12 ECs) | design/gdd/zone-world-map.md | Encounter Zone |
| 13 | World Loot System (inferred) | World | MVP | Not Started | — | Part Database, Zone & World Map |
| 14 | Exploration Progress System | World | MVP | Designed (2026-07-13, /design-system lean — systems-designer + qa-lead consulted; pending fresh-session /design-review. Domain-registry persistence model: pull-at-save, two-phase restore, source-facts-only re-derivation, drift tolerance. 17 ECs / 15 BLOCKING + 2 DEFERRED ACs. Resolves EZ↔ZWM increment-ownership tension in ZWM's favor — 1 light EZ erratum owed on approval: Rule 8a hook wording) | design/gdd/exploration-progress.md | Zone & World Map, Symbot Core Progression; provisional: World Loot (#13 domain contract defined here) |
| 15 | Workshop System | Economy | MVP | Not Started | — | Symbot Assembly, Inventory |
| 16 | Overworld Navigation (inferred) | World | MVP | Not Started | — | Zone & World Map, Encounter Zone |
| 17 | Save/Load System | Persistence | MVP | Not Started | — | Inventory, Workshop, Exploration Progress |
| 18 | Workshop UI | UI | MVP | Not Started | — | Workshop System, Synergy System |
| 19 | Combat UI | UI | MVP | Not Started | — | Turn-Based Combat, Part-Break System |
| 20 | World Map UI (inferred) | UI | MVP | Not Started | — | Zone & World Map (the former Exploration Progress dep resolves to ZWM at runtime — EP has no queryable runtime state under its pull model; see exploration-progress.md Interactions) |
| 21 | Audio System | Audio | MVP (basic SFX) → Alpha (full) | Not Started | — | Turn-Based Combat, Part-Break System |
| 22 | Main Menu & Settings (inferred) | UI | MVP | Not Started | — | Save/Load |
| 23 | NPC System (inferred) | Meta | Vertical Slice | Not Started | — | Turn-Based Combat, Zone & World Map |
| 23a | Key Item System | Meta | Vertical Slice | Not Started | — | Exploration Progress, Inventory (story/plot key items — unique, non-consumable, un-scrappable; **NOT** the Consumable Database) |
| 24 | Tutorial System (inferred) | Meta | Vertical Slice | Not Started | — | Workshop UI, Combat UI, Workshop System |
| 25 | Blueprint Crafting System | Economy | Alpha | Not Started | — | Part Database, Inventory |
| 26 | Part Upgrade System | Economy | Alpha | Not Started | — | Part Database, Inventory |
| 27 | Endgame Loop System | Gameplay | Alpha | Not Started | — | All MVP Systems |
| 28 | PvP System | Meta | Full Vision | Not Started | — | Turn-Based Combat, Synergy, Save/Load, Networking |
| 29 | Auto-Adventure Dispatch | Meta | Full Vision | Not Started | — | Symbot Core Progression, Inventory (endgame idle/dispatch — send low-level cores on automatic runs for XP + items; anti-grind convenience for leveling alt cores) |

---

## Categories

| Category | Description | Systems in Symbots |
|----------|-------------|-------------------|
| **Foundation** | Data schemas and formulas everything else reads | Part Database, Move Database, Passive Database, Consumable Database, Enemy Database, Damage Formula System |
| **Gameplay** | The systems that make building and battling fun | Symbot Assembly, Synergy, Turn-Based Combat, Part-Break, Enemy AI, Symbot Core Progression, Endgame Loop |
| **World** | Exploration, zones, and loot in the overworld | Encounter Zone, Zone & World Map, World Loot, Exploration Progress, Overworld Navigation |
| **Economy** | Parts flowing in and out of the player's hands | Drop System, Inventory, Workshop, Blueprint Crafting, Part Upgrade |
| **Persistence** | Saving and loading game state between sessions | Save/Load System |
| **UI** | Player-facing screens and information displays | Workshop UI, Combat UI, World Map UI, Main Menu & Settings |
| **Audio** | Sound effects and music throughout the game | Audio System |
| **Meta** | Systems outside the main loop | NPC System, Key Item System, Tutorial System, PvP System, Auto-Adventure Dispatch |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | First playable (1 zone, 2 bosses) | Design FIRST |
| **Vertical Slice** | Required for one complete, polished, sharable experience | Playable demo / external playtest | Design SECOND |
| **Alpha** | All features present in rough form. Complete mechanical scope. | Alpha milestone | Design THIRD |
| **Full Vision** | Polish, platform features, and content-complete scope | Beta / Launch | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Part Database** — defines part schemas, stats, element types, slot types, and synergy tags; everything else reads from this
2. **Enemy Database** — defines enemy schemas, stat blocks, breakable part regions, and drop tables
3. **Damage Formula System** — defines all math: damage, type effectiveness, critical hits; depends on part stat definitions
- **Consumable Database** *(1c)* — standalone schema authority for consumable items (Repair Kit, Coolant Flush, Power Cell, Salvage Beacon, Signal Jammer, Scrap Lure); defines id, name, rarity, effect type/magnitude, use-context (battle/world/both), stack behavior. Effects are *read by* Turn-Based Combat (Structure/Heat/Energy restore, drop-boost), Drop System (consumables as a level/rarity-scaled drop class + Salvage Beacon feedback), and Encounter Zone (encounter-rate modifier for repel/lure). No upstream dependencies. (Scope added 2026-07-12 — consumables pulled into MVP.)

### Core Layer (depends on Foundation)

4. **Symbot Assembly System** — composes a Symbot from 6 slots; reads part stats from Part Database
5. **Synergy System** — detects active element sets from equipped parts; reads synergy tags from Part Database and slot state from Assembly
6. **Turn-Based Combat System** — resolves turn order, moves, damage, and status; reads from Damage Formula, Assembly, and Enemy Database
7. **Encounter Zone System** — defines which enemy types spawn in which zone; reads from Enemy Database
8. **Drop System** — defines what falls from a defeated enemy or broken part; reads from Part Database and Enemy Database

### Feature Layer (depends on Core)

9. **Part-Break System** — tracks break HP per enemy part region; integrates into Combat for targeting; feeds guaranteed drops to Drop System
10. **Enemy AI System** — selects enemy actions using elemental and strategic heuristics; reads from Combat and Enemy Database
- **Symbot Core Progression (Leveling)** *(10b)* — the CORE is the Symbot's non-fungible *leveled* anchor (element/identity/life). Core level rises from **battle XP only** (unbuyable; Scrap upgrades parts, never levels cores) and gates equipping high-level/high-rarity parts via a `level_requirement` field. Bounded per-stat growth makes leveling **one of three progression legs** (level cores / upgrade parts / hunt+craft), not the dominant lever. Benched Symbots earn partial XP (`BENCH_XP_SHARE`). Reads from Symbot Assembly (build/slots), Part Database (level_requirement), and Turn-Based Combat (XP award). **Fills symbot-assembly.md's open "CORE identity mechanical enforcement" Deferred Obligation.** *Requires a game-concept anti-pillar revision (+ CD sign-off) and errata to Approved Symbot Assembly + Part Database — executed in its own design pass. (Added 2026-07-12 — user decision; leveling pulled into MVP.)*
11. **Inventory System** — stores and organizes collected parts; reads from Part Database for metadata
12. **Zone & World Map System** — models the world graph: zones, connections, boss gates; reads from Encounter Zone
13. **World Loot System** — places static chests and hidden items in the overworld; reads from Part Database and Zone & World Map

### Integration Layer (depends on Feature)

14. **Exploration Progress System** — tracks which zones are cleared, bosses defeated, hidden items found; reads from Zone & World Map
15. **Workshop System** — manages the player's active builds: equip/unequip, compare, save build names; reads from Assembly, Inventory
16. **Overworld Navigation** — player movement through zone tiles; triggers Encounter Zone entries; reads from Zone & World Map
17. **Save/Load System** — serializes and persists Inventory, Workshop builds, Exploration Progress, and Settings to disk

### Presentation Layer (depends on Integration)

18. **Workshop UI** — visual interface for Workshop System; displays live stats, Synergy indicators, touch-optimized part picker
19. **Combat UI** — visual interface for Turn-Based Combat; displays HP, turn order, move list, break pips, and targeting
20. **World Map UI** — displays Zone & World Map with player location, zone status (locked/cleared/accessible)
21. **Audio System** — SFX bus for combat and UI feedback (MVP); music, ambient, and adaptive layers (Alpha)
22. **Main Menu & Settings** — start/continue game, volume sliders; reads from Save/Load System

### Polish Layer (depends on Presentation and Full MVP)

23. **NPC System** — rival Symbot Mechanics with unique builds; introduces new elements and synergies in story encounters
- **Key Item System** *(23a)* — defines story/plot **key items**: unique, non-consumable, un-scrappable, un-sellable items that gate narrative and world progression (a door key, a story macguffin, an access chip). Read by Exploration Progress (gating), stored by Inventory. **Not** drop-table-sourced or rarity-scaled — placed by story/quest design. Explicitly distinct from the Consumable Database (which owns *used-up* support items). Deferred to Vertical Slice alongside the story/NPC layer (story is out of MVP per game-concept.md).
24. **Tutorial System** — first-session onboarding: workshop tutorial, first combat guide, break targeting explanation
25. **Blueprint Crafting System** — the **Designs** layer: rare blueprint/template drops that let the player **fabricate part instances on demand** (paying Scrap currency + materials) instead of re-rolling the RNG drop. Deterministic/targeted acquisition on top of the RNG loop; fabricated parts are instances like any other. (Economy model set 2026-07-10, HOLISM-01 — see part-database.md DB5.)
26. **Part Upgrade System** — enhance individual parts with materials; tuning layer on top of base part stats
27. **Endgame Loop System** — challenge zones with scaling difficulty and rare-tier part pools; the post-story grind
28. **PvP System** — build-vs-build asynchronous or real-time matches; requires networking infrastructure
- **Auto-Adventure Dispatch** *(29)* — endgame idle/dispatch layer: send Symbots with low-level cores on automatic adventures to earn XP and items without manual battling. An anti-grind convenience for leveling alternate cores once the player has an established main team. Reads from Symbot Core Progression (XP award) and Inventory (item rewards). Deferred to Full Vision (endgame convenience, not core-loop critical). (Added 2026-07-12.)

---

## Recommended Design Order

Design MVP Foundation first, then MVP Core, then MVP Features in dependency order.
Independent systems at the same layer can be designed in parallel.

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Part Database | MVP | Foundation | game-designer, systems-designer | L |
| 2 | Damage Formula System | MVP | Foundation | systems-designer | S |
| 3 | Enemy Database | MVP | Foundation | game-designer | M |
| 4 | Symbot Assembly System | MVP | Core | game-designer | M |
| 5 | Synergy System | MVP | Core | systems-designer, game-designer | L |
| 6 | Turn-Based Combat System | MVP | Core | game-designer, systems-designer | L |
| 7 | Encounter Zone System | MVP | Core | game-designer | S |
| 8 | Drop System | MVP | Core | economy-designer | M |
| 9 | Part-Break System | MVP | Feature | systems-designer | M |
| 10 | Enemy AI System | MVP | Feature | game-designer | M |
| 10a | Consumable Database | MVP | Foundation | game-designer, economy-designer | M |
| 10b | Symbot Core Progression (Leveling) | MVP | Feature | game-designer, systems-designer | M | *(deps all Approved — designable now; needs concept revision + CD sign-off + Assembly/Part DB errata)* |
| 11 | Inventory System | MVP | Feature | game-designer | M |
| 12 | Zone & World Map System | MVP | Feature | level-designer, game-designer | M |
| 13 | World Loot System | MVP | Feature | level-designer | S |
| 14 | Exploration Progress System | MVP | Feature | game-designer | S |
| 15 | Workshop System | MVP | Integration | game-designer, ux-designer | M |
| 16 | Overworld Navigation | MVP | Integration | game-designer | M |
| 17 | Save/Load System | MVP | Integration | lead-programmer | L |
| 18 | Workshop UI | MVP | Presentation | ux-designer, ui-programmer | M |
| 19 | Combat UI | MVP | Presentation | ux-designer, ui-programmer | M |
| 20 | World Map UI | MVP | Presentation | ux-designer | S |
| 21 | Audio System (basic SFX) | MVP | Presentation | audio-director, sound-designer | M |
| 22 | Main Menu & Settings | MVP | Presentation | ux-designer | S |
| 23 | NPC System | Vertical Slice | Polish | narrative-director, game-designer | M |
| 23a | Key Item System | Vertical Slice | Polish | game-designer, narrative-director | S |
| 24 | Tutorial System | Vertical Slice | Polish | ux-designer, game-designer | M |
| 25 | Blueprint Crafting System | Alpha | Polish | economy-designer, game-designer | L |
| 26 | Part Upgrade System | Alpha | Polish | economy-designer | M |
| 27 | Endgame Loop System | Alpha | Polish | game-designer, economy-designer | L |
| 28 | PvP System | Full Vision | Polish | network-programmer, game-designer | L |
| 29 | Auto-Adventure Dispatch | Full Vision | Polish | game-designer, economy-designer | M |

*Effort: S = 1 session, M = 2-3 sessions, L = 4+ sessions. A session is one focused design conversation producing a complete GDD section.*

---

## Circular Dependencies

None detected. The dependency graph is a directed acyclic graph (DAG) with a clean
layered structure. Part Database sits at the root with no cycles back from dependent systems.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Part Database | Design | Central bottleneck — 9 systems depend on it directly. Schema decisions (slot types, stat names, synergy tags, break zones) are very hard to change after dependent GDDs are written. | Design first and most carefully. Do not start any dependent GDD until Part Database is approved. |
| Synergy System | Design | Multi-active synergies + investment scaling + cross-element combinations = complex rule set. Prototype revealed gaps in the original concept. | Design alongside Part Database; synergy tags are defined there. Formalize the 3 rules from the prototype report into acceptance criteria before writing any synergy code. |
| Save/Load System | Technical | Large part inventories on mobile require careful serialization from day 1. Changing the save schema post-launch can corrupt existing saves. | Architect this before any persistent data is designed. Define the schema contract first; gameplay system GDDs reference it. |
| Endgame Loop System | Scope | "Enough content" is undefined until Alpha playtesting reveals how fast players exhaust zones. Scope may expand significantly. | Design data compatibility (rare-tier flag on Part Database) in MVP; defer Endgame system design to Alpha. |
| PvP System | Technical + Scope | Networking, server infrastructure, anti-cheat, and separate balance pass required. Not viable for solo first game MVP. | Full Vision only. Do not scope-creep this into Alpha. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 35 |
| Design docs started | 18 |
| Design docs reviewed | 14 |
| Design docs approved | 16 |
| MVP systems designed | 20 / 25 |
| Vertical Slice systems designed | 0 / 3 |
| Alpha systems designed | 0 / 3 |
| Full Vision systems designed | 0 / 2 |

---

## Next Steps

- [x] Review and approve systems enumeration
- [x] Review and approve dependency mapping
- [x] Review and approve priority assignments
- [ ] Design **Part Database** GDD first — use `/design-system part-database`
- [ ] Design **Damage Formula System** GDD second (parallel with Part Database once schema is locked) — use `/design-system damage-formula`
- [ ] Run `/design-review` on each completed GDD before starting the next
- [ ] Run `/gate-check pre-production` when all MVP Foundation + Core GDDs are complete
- [ ] Build a Godot vertical slice when MVP Foundation GDDs are approved
