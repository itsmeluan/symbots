# Epic: Drop System

> **Layer**: Core
> **GDD**: design/gdd/drop-system.md
> **Architecture Module**: Drop System (Core)
> **Status**: Ready
> **Stories**: 9 stories (2026-07-17) — 8 Logic (Ready) + 1 Integration (Blocked on Save/Load)

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

## Stories

| # | Story | Type | Status | ADR (primary) |
|---|-------|------|--------|---------------|
| 001 | DropSystem host, VICTORY trigger & DS-1 roll core | Logic | Ready | ADR-0006 |
| 002 | Condition assembly — exact match, stacking, unknown key | Logic | Ready | ADR-0003 |
| 003 | Pool iteration — dedup, independent rolls, empty pool | Logic | Ready | ADR-0006 |
| 004 | Prototype gradient pity (DS-2) | Logic | Ready | ADR-0006 |
| 005 | Boss-grade deterministic floor pity (DS-3) | Logic | Ready | ADR-0006 |
| 006 | Determinism — ID-order, stream-sync, reproducibility | Logic | Ready | ADR-0006 |
| 007 | Beacon (×2.0) & DS-F-LEVEL rate injection | Logic | Ready | ADR-0006 |
| 008 | Scrap yield & rarity-ordering invariant | Logic | Ready | ADR-0003 |
| 009 | Pity-counter persistence across save/load | Integration | **Blocked** (Save/Load) | ADR-0006 |

**Build order**: 001 (anchor) → 002 / 003 / 004 / 005 / 008 (all depend only on 001) →
006 (composes 004 + 005) → 007 (needs 001 + a pity-guaranteed part from 005) →
009 (Integration, gated on the Not-Started Save/Load system; depends 004 + 005).

**Coverage**: all 12 TR-drop requirements mapped; all 30 numbered BLOCKING ACs +
the 1 gated release-blocker (AC-DS-28) placed —
001: AC-DS-03/04/05/11/20/27 · 002: AC-DS-22/23/07/25 · 003: AC-DS-12/08/06 ·
004: AC-DS-13/14/29/15 · 005: AC-DS-16/17/09/30/24/01/26 · 006: AC-DS-21/10/18/02 ·
007: AC-DS-31 · 008: AC-DS-19 · 009: AC-DS-28 (gated).

**Deferred integration notes** (author the stub now, wire later — not story-blocking):
- **AD-1** outcome-fact provenance (drop resolution emits an auditable outcome fact) — deferred design.
- **AD-3** loot / drop-summary screen — Presentation tier, deferred.
- **AD-4** player-initiated scrap **action** + batch-scrap UX — Inventory-owned, deferred (Story 008 delivers only the yield source).
- **AD-5** Part-Break → Drop qualifying-break contract — owned by the COMBAT/Part-Break seam; the deduplicated `fired_break_events` Set it produces is consumed here (Story 005).
- **AC-ELZS-11** DS-F-LEVEL cross-system **integration** gate lives in `tests/integration/drop_system/` and is owned by the Encounter Zone erratum Done condition; Story 007 delivers the unit-level injection (AC-DS-31) it builds on.

## Next Step

Stories are written. Run `/story-readiness production/epics/drop-system/story-001-dropsystem-host-victory-trigger-ds1-roll-core.md`
→ `/dev-story` to begin implementation from the anchor. Work stories in `Depends on:` order.
Story 009 stays **Blocked** until the Save/Load system (ADR-0001) defines the pity-map
serialization interface.
