# Epics Index

Last Updated: 2026-07-17
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
| [Synergy System](synergy-system/EPIC.md) | Core | Synergy | design/gdd/synergy-system.md | 5 stories | ✅ Complete |
| [Turn-Based Combat](turn-based-combat/EPIC.md) | Core | Turn-Based Combat | design/gdd/turn-based-combat.md | 14 stories | ✅ Complete |
| [Encounter Zone](encounter-zone/EPIC.md) | Core | Encounter Zone | design/gdd/encounter-zone.md | 8 stories | ✅ Complete |
| [Drop System](drop-system/EPIC.md) | Core | Drop System | design/gdd/drop-system.md | 9 stories | ✅ Complete (9/9, DS-009 closed 2026-07-17) |
| [Save/Load](save-load/EPIC.md) | Foundation | Save/Load | docs/architecture/adr-0001-save-load.md | 6 stories | ✅ Complete (6/6, 2026-07-17) |

## Layer Status

- **Foundation** — ✅ **fully Complete** as of 2026-07-16. All 6 epics done & green: Part Database (11), Move Database (6), Passive Database (7), Consumable Database (8), Enemy Database (10), Damage Formula (3). Enemy Database closed with Story 010 — 8 WILD + 2 BOSS `EnemyDef` `.tres` + `enemy_catalog.tres` authored, blocking CI gate `ok==true` / 0 errors / 0 warnings; a prerequisite `ironclad_aegis_frame` Thermal Rare was added (part catalog 15→16). **Full suite 631/631 GUT green, 3853 asserts.** All traced to Accepted ADRs (ADR-0003 content DBs, ADR-0005/0006 damage formula). 0 Foundation coverage gaps. Follow-up (non-blocking): enemy skill IDs are forward-refs the Move DB content pass owes.
- **Core** — ✅ **fully Complete as of 2026-07-17** (5 epics, all closed through the lean per-story `/code-review` + `/story-done` gate): Symbot Assembly (7/7), Synergy System (5/5), Turn-Based Combat (14/14), **Encounter Zone (8/8, closed 2026-07-17)**, and **Drop System (9/9, closed 2026-07-17 — DS-009 unblocked & Done once the Save/Load epic landed)**. **Full suite 913/913 GUT green, 4740 asserts.** Encounter Zone shipped `EncounterResolver` + `ZoneContentLinter` in `src/core/encounter_zone/` (value types `ZoneDef`/`TerrainPatch`/`SpawnEntry`/`BossEncounter`; EZ-1 rate clamp, EZ-2 weighted walk, sub-pool `filter_valid`, WILD/BOSS TBC handoff, WIN_COUNT first-access + `requires_defeated` sequencing, LIGHTER_REGATE delta re-gate + ALWAYS_OPEN, gate-param validation + reserved-gate fail-safe LOCKED, and 11 ADVISORY offline content linters proven against fixtures) — the real MVP zone `.tres` remains a deferred content pass (OQ-EZ-1). Drop System shipped all 8 Logic stories + the DS-009 Integration capstone (pity-counter persistence AC-DS-28) — the release-blocker is **cleared**: the Save/Load Foundation epic (SL-1..SL-6, ADR-0001) landed the provider-envelope system and the `&"drop"` provider, and DS-009's integration test round-trips both pity maps through the real path with post-reload boundary semantics intact. Remaining deferred integration ACs (EZ 9, Drop 3) recorded as write-the-stub-now notes; the DS-F-LEVEL cross-system gate (AC-ELZS-11) is discharged by the Encounter Zone erratum. All traced to Accepted ADRs (ADR-0005 stat pipeline, ADR-0006 RNG/determinism, ADR-0007 TBC FSM, ADR-0001/0002/0003). 0 untraced Core requirements. **Next: the Technical Setup → Pre-Production gate** (`/test-setup`, `/ux-design`).
- **Feature** — not yet epicked
- **Presentation** — not yet epicked

## Next Step

✅ **Foundation fully Complete (6/6).** ✅ **Core layer fully Complete (5/5) as of 2026-07-17** —
Symbot Assembly (7/7), Synergy System (5/5), Turn-Based Combat (14/14), Encounter Zone (8/8), and
Drop System (9/9, DS-009 Done). ✅ **Save/Load Foundation epic Complete (6/6)** — the first
persistence system, shipping the ADR-0001 provider-envelope engine + the `&"drop"` provider.
**Full suite 913/913 GUT green, 4740 asserts.** Every Core system is built and tested against DI
seams + fixtures; the two deferred content passes (the MVP zone `.tres`, OQ-EZ-1; the synergy tier
`.tres`) are authored later against the same linters.

**Next: the Technical Setup → Pre-Production gate.** Foundation + Core code layers are done, so the
path is `/test-setup` (scaffold CI + tests/integration structure) and `/ux-design`
(interaction-patterns + accessibility-requirements), then `/gate-check production`.

Remaining thread before ship:
- The deferred cross-system errata (Encounter Zone spawn-exclusion AC-ED-11, TBC null-element path
  AC-ED-16, Drop break-event dedup AC-ED-12, DS-F-LEVEL gate AC-ELZS-11) — verify each is discharged.
  *(The DS-009 release-blocker is now cleared — Save/Load landed and DS-009 passes.)*
