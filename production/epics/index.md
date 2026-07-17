# Epics Index

Last Updated: 2026-07-16
Engine: Godot 4.7

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [Part Database](part-database/EPIC.md) | Foundation | Part Database | design/gdd/part-database.md | 11 stories | Complete |
| [Move Database](move-database/EPIC.md) | Foundation | Move Database | design/gdd/move-database.md | 6 stories | Complete |
| [Passive Database](passive-database/EPIC.md) | Foundation | Passive Database | design/gdd/passive-database.md | 7 stories | Complete |
| [Consumable Database](consumable-database/EPIC.md) | Foundation | Consumable Database | design/gdd/consumable-database.md | 8 stories | Complete |
| [Enemy Database](enemy-database/EPIC.md) | Foundation | Enemy Database | design/gdd/enemy-database.md | 10 stories | Complete |
| [Damage Formula](damage-formula/EPIC.md) | Foundation | Damage Formula | design/gdd/damage-formula.md | 3 stories | Complete |
| [Symbot Assembly](symbot-assembly/EPIC.md) | Core | Symbot Assembly | design/gdd/symbot-assembly.md | 7 stories | ✅ Complete |
| [Synergy System](synergy-system/EPIC.md) | Core | Synergy | design/gdd/synergy-system.md | Not yet created | Ready |
| [Turn-Based Combat](turn-based-combat/EPIC.md) | Core | Turn-Based Combat | design/gdd/turn-based-combat.md | Not yet created | Ready |
| [Encounter Zone](encounter-zone/EPIC.md) | Core | Encounter Zone | design/gdd/encounter-zone.md | Not yet created | Ready |
| [Drop System](drop-system/EPIC.md) | Core | Drop System | design/gdd/drop-system.md | Not yet created | Ready |

## Layer Status

- **Foundation** — ✅ **fully Complete** as of 2026-07-16. All 6 epics done & green: Part Database (11), Move Database (6), Passive Database (7), Consumable Database (8), Enemy Database (10), Damage Formula (3). Enemy Database closed with Story 010 — 8 WILD + 2 BOSS `EnemyDef` `.tres` + `enemy_catalog.tres` authored, blocking CI gate `ok==true` / 0 errors / 0 warnings; a prerequisite `ironclad_aegis_frame` Thermal Rare was added (part catalog 15→16). **Full suite 631/631 GUT green, 3853 asserts.** All traced to Accepted ADRs (ADR-0003 content DBs, ADR-0005/0006 damage formula). 0 Foundation coverage gaps. Follow-up (non-blocking): enemy skill IDs are forward-refs the Move DB content pass owes.
- **Core** — ✅ **epicked 2026-07-16** (5 epics). **Symbot Assembly is the first Core epic implemented + closed** (7/7 stories through the per-story `/code-review` + `/story-done` gate 2026-07-16; full suite 657/657 GUT green, 3934 asserts, 53 scripts). Remaining 4 still Ready-unstoried: Synergy, Turn-Based Combat, Encounter Zone, Drop System — the gameplay loop that reads the Foundation DBs. All have Approved GDDs and full ADR coverage (ADR-0005 stat pipeline, ADR-0006 RNG/determinism, ADR-0007 TBC FSM, plus ADR-0002/0003). 0 untraced requirements. **Next: `/create-stories synergy-system`** (the SYN-F4 composition point Assembly's `final_stat` feeds into).
- **Feature** — not yet epicked
- **Presentation** — not yet epicked

## Next Step

✅ **Foundation fully Complete (631/631 GUT).** **Core layer in progress** — Symbot Assembly is
implemented + closed (7/7, per-story gate; suite now 657/657 GUT green). 4 Core epics remain
Ready-unstoried: Synergy, Turn-Based Combat, Encounter Zone, Drop System.

**Next: `/create-stories synergy-system`** (the SYN-F4 composition point Assembly's snapshot
folds in), then **`turn-based-combat`** (the largest — 42 requirements — consuming both), then
**`encounter-zone`** and **`drop-system`** (both RNG-injected, independent of each other). Then
`/gate-check production` — Foundation + Core epics are the Pre-Production → Production gate.

The deferred cross-system errata (Encounter Zone spawn-exclusion AC-ED-11, TBC null-element path
AC-ED-16, Drop break-event dedup AC-ED-12) land as these epics are storied.
