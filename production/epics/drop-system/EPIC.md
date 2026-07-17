# Epic: Drop System

> **Layer**: Core
> **GDD**: design/gdd/drop-system.md
> **Architecture Module**: Drop System (Core)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories drop-system`

## Overview

The Drop System decides what falls from a defeated enemy and its broken part regions,
then hands rolled part instances (and consumables) to Inventory. It consumes the 8-field
`battle_ended` (VICTORY-only) with the deduplicated `fired_break_events` set from
Part-Break, and rolls each unique pool part-ID once in **ascending-ID order** using an
**injected seeded RNG** for reproducibility. It owns the pity system: per-Prototype credit
(threshold `N_PROTO_PITY × condition-count`) and per-Boss-grade break counter
(`M_BOSS_PITY = 8`), both persisted across sessions. The determinism-critical rule is
that **pity is checked before the RNG draw** — a guaranteed drop skips the draw so the
stream never desyncs. DS-1 layers level-rarity and Beacon (×2.0) multipliers before
condition multipliers; drops emerge at `upgrade_tier=0`; Scrap yield is rarity-ordered
(Common < Rare < Prototype < Boss-grade, never inverted).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: RNG Service & Determinism | Injected seeded `RandomNumberGenerator`; pity checked BEFORE the draw (guaranteed drop skips draw → no stream desync); ascending-ID roll order; `src/core` pure | MEDIUM |
| ADR-0002: Event Bus & Signal Architecture | Consumes the 8-field COMBAT `battle_ended`; reads `fired_break_events` + still-live break pools; diagnostics via injected LogSink | LOW |
| ADR-0003: Content Resource Loading & Schema Mapping | Reads Part/Enemy DB drop config via typed catalog; unknown condition keys logged + skipped, never crash | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-drop-001 | RNG draws seeded, deterministic, part-ID-ascending roll order for reproducibility | ADR-0006 ✅ |
| TR-drop-002 | Pool part-ID deduplication: one roll per unique ID; duplicates contribute zero extra rolls | ADR-0006 ✅ |
| TR-drop-003 | Pity counters persist across sessions (Prototype credit, Boss-grade break counter) | ADR-0006 ✅ |
| TR-drop-004 | Consumes battle_ended VICTORY-only; fired_break_events as deduplicated Set from Part-Break | ADR-0002 ✅ |
| TR-drop-005 | Pity-guaranteed drops skip RNG draw; stream position stays synchronized with non-guaranteed rolls | ADR-0006 ✅ |
| TR-drop-006 | Unknown condition keys logged as content error, skipped, no crash; multiplier not applied | ADR-0003 ✅ |
| TR-drop-007 | Prototype pity: credit threshold = N_PROTO_PITY × C (C = condition count); increments by conditions fired | ADR-0006 ✅ |
| TR-drop-008 | Boss-grade pity: M_BOSS_PITY = 8 consecutive qualifying-break failures triggers guarantee | ADR-0006 ✅ |
| TR-drop-009 | Scrap yield per-rarity ordering invariant: Common < Rare < Prototype < Boss-grade, never inverted | ADR-0003 ✅ |
| TR-drop-010 | Drop output: new part instances at upgrade_tier=0, handed to Inventory; pity counter reset/updated | ADR-0002 ✅ |
| TR-drop-011 | Beacon multiplier (2.0) injected into effective_drop_rate on VICTORY when beacon_used_this_battle | ADR-0006 ✅ |
| TR-drop-012 | Level-rarity multiplier (DS-F-LEVEL) injected into DS-1 before condition multipliers; Prototype row = 1.0 | ADR-0006 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/drop-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Determinism has a GUT test: a fixed injected seed reproduces the exact drop set, and a
  pity-guaranteed drop is proven to skip the draw without desyncing subsequent rolls
- The Prototype and Boss-grade pity thresholds, ascending-ID roll order, and rarity-ordered
  Scrap yield each have discriminating fixtures

## Next Step

Run `/create-stories drop-system` to break this epic into implementable stories.
