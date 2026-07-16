# Epic: Move Database

> **Layer**: Foundation
> **GDD**: design/gdd/move-database.md
> **Architecture Module**: Content DBs (Part/Move/Passive/Consumable/Enemy)
> **Status**: Complete (6/6 stories Done, 2026-07-16)
> **Stories**: 6 created (2026-07-16), all implemented + green — see the Stories table below

## Overview

The Move Database is the read-only schema and catalog for every move a Symbot can
use: the MOVE-CONTRACT-1 schema (behavior, power tier, damage type, element,
energy cost, targeting, break bias) plus the MOVE-F1 power-tier multiplier that
scales DF-1 output. It is queried by Assembly (to populate a build's 4-move pool)
and Turn-Based Combat (to resolve a used move). This epic delivers the typed
`Move` resource, the catalog loader, and the authoring rules that keep moves
legal — energy-cost bands per power tier, status-proc/element matching, the
REPAIR Energy-brake floor, and the ban on innate status riders (riders belong to
passives via the TBC Rule 13 registry).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Content Resource Loading & Schema Mapping | Typed `.tres` defs, one catalog per DB, CI + dev-boot ContentValidator; read-only-at-runtime | MEDIUM (HIGH for typed-dict `@export` / `.tres` round-trip) |

## GDD Requirements

All 10 requirements are traced to ADR-0003 (architecture review: 0 Foundation gaps).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-mdb-001 | MOVE-CONTRACT-1 schema: id, display_name, behavior, power_tier, damage_type, element, energy_cost, targeting, break_bias | ADR-0003 ✅ |
| TR-mdb-002 | DAMAGE moves require non-null power_tier → multiplier {0.70, 0.80, 1.00, 1.20, 1.40} | ADR-0003 ✅ |
| TR-mdb-003 | STATUS moves' status_proc.status_id matches move element (Volt→Shock, Thermal→Burn, Kinetic→Stagger) | ADR-0003 ✅ |
| TR-mdb-004 | DAMAGE energy_cost within tier band: LIGHT 5–8, STANDARD 12–18, HEAVY 22–30, SIGNATURE 32–40 | ADR-0003 ✅ |
| TR-mdb-005 | REPAIR moves author energy_cost > BASE_ENERGY_REGEN (≥11 at current 10) — anti-stall Energy-brake | ADR-0003 ✅ |
| TR-mdb-006 | UTILITY Vent moves reduce current_heat by vent_amount, floored at 0; only MVP UTILITY behavior | ADR-0003 ✅ |
| TR-mdb-007 | SCAN moves' scan_payload=BREAK_REGIONS delivers enemy break_regions + drop hints, persistent for battle | ADR-0003 ✅ |
| TR-mdb-008 | MOVE-F1 power multiplier applies post-DF-1 with epsilon 0.0001 for IEEE-754 rounding | ADR-0003 ✅ |
| TR-mdb-009 | Non-DAMAGE moves carry no innate status riders; riders only via passives (TBC Rule 13) | ADR-0003 ✅ |
| TR-mdb-010 | Core parts must not carry SKILL_UNLOCK upgrade effects (Part DB Core exception) | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/move-database.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- MOVE-F1 has a GUT unit test using discriminating fixtures (post-DF-1 multiply + epsilon)
- The ContentValidator rejects every authoring-rule violation above (CI + dev-boot)
- Referential integrity to the Part DB (active_skill_id resolution) is verified

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | MoveDef schema, enums & MoveCatalog | Logic | Complete | ADR-0003 |
| 002 | MoveDB loader & null-safe lookup | Logic | Complete | ADR-0003, ADR-0004 |
| 003 | MOVE-F1 — move power-multiply formula | Logic | Complete | ADR-0005 |
| 004 | Move schema-validation family | Logic | Complete | ADR-0003 |
| 005 | Move authoring-rule validation | Logic | Complete | ADR-0003 |
| 006 | Referential integrity — active_skill_id ↔ Move DB | Integration | Complete | ADR-0003 |

**Scope note:** this epic delivers the Move DB's static contract — schema, the MOVE-F1
formula, content validation, and Part↔Move referential integrity (the 10 TR-mdb
requirements). The GDD's *runtime* ACs — Basic Attack instantiation (AC-MDB-06),
SCAN reveal/persistence (AC-MDB-10/20), Vent heat-mutation (AC-MDB-11), status-proc
application (AC-MDB-09), `hit_resolved` emission (AC-MDB-19), SKILL_ENHANCE/UNLOCK
runtime (AC-MDB-12/13) — are **Turn-Based Combat-owned** and land in the TBC epic;
this epic authors the contract they fulfil. AC-MDB-05 (full DF-1→MOVE-F1→TBC-F5
pipeline) is verified once DF-1 (Damage-Formula epic) and TBC-F5 (TBC epic) exist in code.

## Next Step

Run `/story-readiness production/epics/move-database/story-001-movedef-schema-enums-catalog.md`
then `/dev-story` to begin implementation. Work stories in dependency order (each
story's `Depends on:` field is authoritative).
