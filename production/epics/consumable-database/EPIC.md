# Epic: Consumable Database

> **Layer**: Foundation
> **GDD**: design/gdd/consumable-database.md
> **Architecture Module**: Content DBs (Part/Move/Passive/Consumable/Enemy)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories consumable-database`

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

## Next Step

Run `/create-stories consumable-database` to break this epic into implementable stories.
