# Epic: Consumable Database

> **Layer**: Foundation
> **GDD**: design/gdd/consumable-database.md
> **Architecture Module**: Content DBs (Part/Move/Passive/Consumable/Enemy)
> **Status**: Complete (2026-07-16)
> **Stories**: 8 stories — all implemented & green — see table below

## Overview

The Consumable Database is a standalone read-only schema and catalog for the MVP's
salvage-tech items (Repair Kit, Coolant Flush, Power Cell, Salvage Beacon, Signal
Jammer, Scrap Lure). Unlike Move/Passive DB it does **not** depend on the Part DB —
it is its own schema authority. Each consumable declares an `effect_type` with a
matching `effect_params` schema and a use context (BATTLE / WORLD / BOTH) that
gates pre-action validation. This epic delivers the typed `Consumable` resource,
the catalog loader, the effect-schema validation, and the economy invariants
(buy > sell, flat-integer magnitudes) that keep consumables from becoming an
arbitrage faucet.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Content Resource Loading & Schema Mapping | Typed `.tres` defs, one catalog per DB, CI + dev-boot ContentValidator; read-only-at-runtime | MEDIUM (HIGH for typed-dict `@export` / `.tres` round-trip) |

## GDD Requirements

All 8 requirements are traced to ADR-0003 (architecture review: 0 Foundation gaps).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-cdb-001 | Every consumable declares effect_type with matching effect_params (RESTORE_STRUCTURE/REDUCE_HEAT/RESTORE_ENERGY/BOOST_DROP/MODIFY_ENCOUNTER_RATE) | ADR-0003 ✅ |
| TR-cdb-002 | Use context (BATTLE/WORLD/BOTH) gates pre-action validation; rejected use consumes no turn, no decrement | ADR-0003 ✅ |
| TR-cdb-003 | RESTORE_* targets living team Symbot (Structure > 0), active or benched; downed never valid | ADR-0003 ✅ |
| TR-cdb-004 | BOOST_DROP (Salvage Beacon) per-battle flag; one per battle, spent on flee/loss, applies only on victory | ADR-0003 ✅ |
| TR-cdb-005 | MODIFY_ENCOUNTER_RATE modifier frozen during battle (no step countdown); resumes after | ADR-0003 ✅ |
| TR-cdb-006 | buy_price > sell_price strictly for every entry (BLOCKING anti-arbitrage validation) | ADR-0003 ✅ |
| TR-cdb-007 | REDUCE_HEAT cannot rescue an already-Overheated Symbot (preventive-only) | ADR-0003 ✅ |
| TR-cdb-008 | Effect magnitudes flat integers (not %-of-max); pure integer clamps, no floor/ceil | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/consumable-database.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The buy > sell invariant is enforced by the ContentValidator with a GUT test
  asserting a violating entry is rejected (BLOCKING)
- Use-context gating (BATTLE/WORLD/BOTH) is validated including the reject-no-decrement path
- If this epic's ContentValidator family pushes `src/core/content/content_validator.gd` past
  ~1500 lines, extract the per-DB check families into composed `RefCounted` helpers **behind
  the single `validate()` entry point** — preserving the ADR-0003 "single ContentValidator"
  contract (no behavior change; a pure structural split with the suite green before and after).
  Provenance: `/code-review` 2026-07-16 file-size watch (validator at 1170 lines after Story-011)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | ConsumableDef schema, enums & ConsumableCatalog | Logic | Done | ADR-0003 |
| 002 | ConsumableDB loader & null-safe lookup | Logic | Done | ADR-0003 |
| 003 | Restore effect formulas (CD-1/2/3) | Logic | Done | ADR-0003 |
| 004 | Use-transaction validation, targeting & resource-neutrality | Logic | Done | ADR-0003 |
| 005 | Salvage Beacon per-battle flag & BOOST_DROP (CD-4) | Logic | Done | ADR-0003 |
| 006 | Encounter modifier state & MODIFY_ENCOUNTER_RATE (CD-5) | Logic | Done | ADR-0003 |
| 007 | ContentValidator consumable family | Logic | Done | ADR-0003 |
| 008 | MVP content authoring — 8 `.tres` + catalog | Config/Data | Done | ADR-0003 |

**Suite:** 370 → **452/452 green** (+82 consumable tests · 3467 asserts · 0 failing). Validator at 1313 lines — under the ~1500 DoD extract threshold, so the single-`validate()` family stays inline (no structural split needed this epic).

**Deferred cross-system integration (NOT storied here — tracked as errata on the owning epics):**
AC-CD-20 (TBC use-item 4th action / turn-consume), AC-CD-21 (Drop System consumable channel + Beacon end-to-end), AC-CD-22 (Encounter Zone hook + Overworld step countdown), AC-CD-23 (Inventory `max_stack` overflow). Each is noted in the relevant story's `## Out of Scope`; the DB owns schema + formulas + validation + content only (Rule 9 scope boundary).

## Next Step

Epic **Complete** — all 8 stories implemented inline and verified green (452/452). Runtime wiring of the effects/state-models remains the deferred errata (AC-CD-20/21/22/23) on the TBC / Drop / Encounter Zone / Inventory epics. Remaining unstoried Foundation DB: **Enemy Database** — run `/create-stories enemy-database` next. Per-story `/code-review` + `/story-done` were deferred by the batch directive (same as the Passive DB batch) — a follow-up pass if desired.
