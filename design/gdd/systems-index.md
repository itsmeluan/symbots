# Systems Index: Symbots

> **Status**: Draft
> **Created**: 2026-07-09
> **Last Updated**: 2026-07-11 (Part-Break System GDD authored — Designed, pending fresh-session /design-review. Creates 3 erratum obligations on Approved docs: TBC, Move DB, Drop System)
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
| 2 | Enemy Database | Foundation | MVP | Approved | design/gdd/enemy-database.md | Part Database |
| 3 | Damage Formula System | Foundation | MVP | Approved | design/gdd/damage-formula.md | Part Database |
| 4 | Symbot Assembly System | Gameplay | MVP | Approved | design/gdd/symbot-assembly.md | Part Database |
| 5 | Synergy System | Gameplay | MVP | Approved | design/gdd/synergy-system.md | Part Database, Symbot Assembly |
| 6 | Turn-Based Combat System | Gameplay | MVP | Approved | design/gdd/turn-based-combat.md | Damage Formula, Symbot Assembly, Enemy Database, Synergy, Part Database |
| 7 | Encounter Zone System | World | MVP | Not Started | — | Enemy Database |
| 8 | Drop System | Economy | MVP | Approved (2026-07-11, re-review punch-list applied) | design/gdd/drop-system.md | Part Database, Enemy Database |
| 9 | Part-Break System | Gameplay | MVP | Designed (2026-07-11, pending review) | design/gdd/part-break.md | Turn-Based Combat, Drop System |
| 10 | Enemy AI System | Gameplay | MVP | Not Started | — | Turn-Based Combat, Enemy Database |
| 11 | Inventory System | Economy | MVP | Not Started | — | Part Database |
| 12 | Zone & World Map System | World | MVP | Not Started | — | Encounter Zone |
| 13 | World Loot System (inferred) | World | MVP | Not Started | — | Part Database, Zone & World Map |
| 14 | Exploration Progress System (inferred) | World | MVP | Not Started | — | Zone & World Map |
| 15 | Workshop System | Economy | MVP | Not Started | — | Symbot Assembly, Inventory |
| 16 | Overworld Navigation (inferred) | World | MVP | Not Started | — | Zone & World Map, Encounter Zone |
| 17 | Save/Load System | Persistence | MVP | Not Started | — | Inventory, Workshop, Exploration Progress |
| 18 | Workshop UI | UI | MVP | Not Started | — | Workshop System, Synergy System |
| 19 | Combat UI | UI | MVP | Not Started | — | Turn-Based Combat, Part-Break System |
| 20 | World Map UI (inferred) | UI | MVP | Not Started | — | Zone & World Map, Exploration Progress |
| 21 | Audio System | Audio | MVP (basic SFX) → Alpha (full) | Not Started | — | Turn-Based Combat, Part-Break System |
| 22 | Main Menu & Settings (inferred) | UI | MVP | Not Started | — | Save/Load |
| 23 | NPC System (inferred) | Meta | Vertical Slice | Not Started | — | Turn-Based Combat, Zone & World Map |
| 24 | Tutorial System (inferred) | Meta | Vertical Slice | Not Started | — | Workshop UI, Combat UI, Workshop System |
| 25 | Blueprint Crafting System | Economy | Alpha | Not Started | — | Part Database, Inventory |
| 26 | Part Upgrade System | Economy | Alpha | Not Started | — | Part Database, Inventory |
| 27 | Endgame Loop System | Gameplay | Alpha | Not Started | — | All MVP Systems |
| 28 | PvP System | Meta | Full Vision | Not Started | — | Turn-Based Combat, Synergy, Save/Load, Networking |

---

## Categories

| Category | Description | Systems in Symbots |
|----------|-------------|-------------------|
| **Foundation** | Data schemas and formulas everything else reads | Part Database, Enemy Database, Damage Formula System |
| **Gameplay** | The systems that make building and battling fun | Symbot Assembly, Synergy, Turn-Based Combat, Part-Break, Enemy AI, Endgame Loop |
| **World** | Exploration, zones, and loot in the overworld | Encounter Zone, Zone & World Map, World Loot, Exploration Progress, Overworld Navigation |
| **Economy** | Parts flowing in and out of the player's hands | Drop System, Inventory, Workshop, Blueprint Crafting, Part Upgrade |
| **Persistence** | Saving and loading game state between sessions | Save/Load System |
| **UI** | Player-facing screens and information displays | Workshop UI, Combat UI, World Map UI, Main Menu & Settings |
| **Audio** | Sound effects and music throughout the game | Audio System |
| **Meta** | Systems outside the main loop | NPC System, Tutorial System, PvP System |

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

### Core Layer (depends on Foundation)

4. **Symbot Assembly System** — composes a Symbot from 6 slots; reads part stats from Part Database
5. **Synergy System** — detects active element sets from equipped parts; reads synergy tags from Part Database and slot state from Assembly
6. **Turn-Based Combat System** — resolves turn order, moves, damage, and status; reads from Damage Formula, Assembly, and Enemy Database
7. **Encounter Zone System** — defines which enemy types spawn in which zone; reads from Enemy Database
8. **Drop System** — defines what falls from a defeated enemy or broken part; reads from Part Database and Enemy Database

### Feature Layer (depends on Core)

9. **Part-Break System** — tracks break HP per enemy part region; integrates into Combat for targeting; feeds guaranteed drops to Drop System
10. **Enemy AI System** — selects enemy actions using elemental and strategic heuristics; reads from Combat and Enemy Database
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
24. **Tutorial System** — first-session onboarding: workshop tutorial, first combat guide, break targeting explanation
25. **Blueprint Crafting System** — the **Designs** layer: rare blueprint/template drops that let the player **fabricate part instances on demand** (paying Scrap currency + materials) instead of re-rolling the RNG drop. Deterministic/targeted acquisition on top of the RNG loop; fabricated parts are instances like any other. (Economy model set 2026-07-10, HOLISM-01 — see part-database.md DB5.)
26. **Part Upgrade System** — enhance individual parts with materials; tuning layer on top of base part stats
27. **Endgame Loop System** — challenge zones with scaling difficulty and rare-tier part pools; the post-story grind
28. **PvP System** — build-vs-build asynchronous or real-time matches; requires networking infrastructure

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
| 24 | Tutorial System | Vertical Slice | Polish | ux-designer, game-designer | M |
| 25 | Blueprint Crafting System | Alpha | Polish | economy-designer, game-designer | L |
| 26 | Part Upgrade System | Alpha | Polish | economy-designer | M |
| 27 | Endgame Loop System | Alpha | Polish | game-designer, economy-designer | L |
| 28 | PvP System | Full Vision | Polish | network-programmer, game-designer | L |

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
| Total systems identified | 30 |
| Design docs started | 10 |
| Design docs reviewed | 8 |
| Design docs approved | 8 |
| MVP systems designed | 10 / 22 |
| Vertical Slice systems designed | 0 / 2 |
| Alpha systems designed | 0 / 3 |
| Full Vision systems designed | 0 / 1 |

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
