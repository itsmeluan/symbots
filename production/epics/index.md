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
| [Encounter Zone](encounter-zone/EPIC.md) | Core | Encounter Zone | design/gdd/encounter-zone.md | 8 stories | Ready |
| [Drop System](drop-system/EPIC.md) | Core | Drop System | design/gdd/drop-system.md | 9 stories | Ready |

## Layer Status

- **Foundation** — ✅ **fully Complete** as of 2026-07-16. All 6 epics done & green: Part Database (11), Move Database (6), Passive Database (7), Consumable Database (8), Enemy Database (10), Damage Formula (3). Enemy Database closed with Story 010 — 8 WILD + 2 BOSS `EnemyDef` `.tres` + `enemy_catalog.tres` authored, blocking CI gate `ok==true` / 0 errors / 0 warnings; a prerequisite `ironclad_aegis_frame` Thermal Rare was added (part catalog 15→16). **Full suite 631/631 GUT green, 3853 asserts.** All traced to Accepted ADRs (ADR-0003 content DBs, ADR-0005/0006 damage formula). 0 Foundation coverage gaps. Follow-up (non-blocking): enemy skill IDs are forward-refs the Move DB content pass owes.
- **Core** — ✅ **epicked 2026-07-16** (5 epics). **3 of 5 Core epics closed through the lean per-story `/code-review` + `/story-done` gate**: Symbot Assembly (7/7), **Synergy System** (5/5, closed 2026-07-17 — `SynergySystem`/`SynergyTierDef` in `src/core/synergy/`, 32 GUT tests; the gate re-verified all 26 ACs by scenario content and confirmed the 3 DoD-gate tests genuinely discriminating; 0 code gaps → 0 tech-debt entries; synergy tier `.tres` content is a deferred later pass on OQ-1/2/3, SYN-F4 consumer-owned and now discharged by TBC), and **Turn-Based Combat** (14/14, closed 2026-07-17 — `BattleController` FSM + pipeline in `src/core/battle/`; the gate added 5 discriminating tests closing AC-TBC-10/11/18 Logic gaps; 1 ADVISORY tracked — `BattleController` is a DI `RefCounted`, not the ADR-0007 slot-11 autoload). **Full suite 762/762 green, 4268 asserts.** **Encounter Zone is now storied (8 stories, 2026-07-17 — Ready, not yet implemented)**: 6 Logic, 1 Integration, 1 Config/Data covering all 10 TR-ez requirements; 40 BLOCKING + 11 ADVISORY ACs stored, 9 DEFERRED ACs recorded as write-the-stub-now integration notes, and the real MVP zone `.tres` deferred as a content pass (needs the ~8-WILD roster + Art Bible terrain enum, OQ-EZ-1) — engine + linters built against DI seams + fixtures, mirroring the Synergy-tier deferral. **Drop System is now storied too (9 stories, 2026-07-17 — Ready, not yet implemented)**: 8 Logic (Ready) covering all 12 TR-drop requirements + all 30 numbered BLOCKING ACs, and 1 Integration (Story 009, **Blocked** on the Not-Started Save/Load system) holding the gated release-blocker AC-DS-28 (pity-counter persistence). 4 deferred ADs (AD-1/3/4/5) recorded as write-the-stub-now integration notes; the DS-F-LEVEL cross-system gate (AC-ELZS-11) is owned by the Encounter Zone erratum. **All 5 Core epics are now storied.** All have Approved GDDs and full ADR coverage (ADR-0005 stat pipeline, ADR-0006 RNG/determinism, ADR-0007 TBC FSM, plus ADR-0001/0002/0003). 0 untraced requirements. **Next: `/sprint-plan new`** (all epics storied), then implement Encounter Zone + Drop System via `/story-readiness` → `/dev-story`.
- **Feature** — not yet epicked
- **Presentation** — not yet epicked

## Next Step

✅ **Foundation fully Complete (631/631 GUT).** **Core layer 3 of 5 closed through the lean per-story
`/code-review` + `/story-done` gate** — Symbot Assembly (7/7), **Synergy System** (5/5, 2026-07-17),
and **Turn-Based Combat** (14/14, 2026-07-17); suite now **762/762 GUT green, 4268 asserts**.
**All 5 Core epics are now storied**: Encounter Zone (8 stories) and **Drop System (9 stories,
2026-07-17 — 8 Logic Ready + 1 Integration Blocked on Save/Load)** are Ready but not yet implemented.

**Next: `/sprint-plan new`** — every epic now has stories, so the path is to plan the sprint, then
implement Encounter Zone + Drop System via `/story-readiness` → `/dev-story` (start each epic at
story 001, the anchor). Then `/gate-check production` — Foundation + Core epics are the
Pre-Production → Production gate.

Two open threads to schedule into the sprint:
- **Story DS-009 is Blocked** on the Not-Started Save/Load system (ADR-0001 must define the
  pity-map serialization interface); AC-DS-28 is a release-blocker, so Save/Load must land before ship.
- The deferred cross-system errata (Encounter Zone spawn-exclusion AC-ED-11, TBC null-element path
  AC-ED-16, Drop break-event dedup AC-ED-12, DS-F-LEVEL gate AC-ELZS-11) land as these epics implement.
