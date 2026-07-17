# Epic: Encounter Zone System

> **Layer**: Core
> **GDD**: design/gdd/encounter-zone.md
> **Architecture Module**: Encounter Zone (Core)
> **Status**: Done — all 8 stories implemented & closed 2026-07-17
> **Stories**: 8 stories (6 Logic, 1 Integration, 1 Config/Data) — all Done

## Overview

The Encounter Zone System decides which enemy spawns when the player steps through a
zone and governs boss-gate progression. It owns per-zone spawn tables (terrain patches
with weighted, farmable-tagged enemy sub-pools) and gate semantics. EZ-1 rolls an
encounter against `effective_rate = clamp(encounter_rate × active_modifier, 0, 1)` using
an **injected seeded RNG** (repel/lure consumables feed the modifier); EZ-2 selects an
enemy from the valid sub-pool (excluding `spawn_enabled=false`, wrong class, non-positive
weight). Boss gates are re-evaluated on `encounter_resolved` and boss-approach queries —
never mid-battle — using the cumulative, never-resetting WIN_COUNT counter, with Boss 2
sequencing behind a `requires_defeated` prerequisite. Gates default **LOCKED** on any
missing/unresolvable parameter (fail-safe, never fail-open).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: RNG Service & Determinism | Fresh `RandomNumberGenerator` per pass, seeded from an injected int; never global `randf()`; `src/core` stays pure | MEDIUM |
| ADR-0003: Content Resource Loading & Schema Mapping | Reads Enemy DB sub-pools via typed catalog; validates `spawn_enabled`/class/weight; never mutates defs | MEDIUM |
| ADR-0002: Event Bus & Signal Architecture | Gate re-eval consumes `encounter_resolved` (the ADR-0002 renamed WORLD-side signal); diagnostics via injected LogSink | LOW |
| ADR-0007: Turn-Based Combat State Machine & Battle Orchestrator | Gate re-evaluation is bounded to battle-lifecycle boundaries (never mid-battle), consistent with the FSM's emit seam | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ez-001 | Zone defines terrain patches, each with weighted spawn pool (enemy_id, spawn_weight, is_farmable_target) | ADR-0003 ✅ |
| TR-ez-002 | Enemy subpool validation: exclude entries with spawn_enabled=false, wrong enemy_class, weight≤0 | ADR-0003 ✅ |
| TR-ez-003 | EZ-1 encounter-rate modifier hook: effective_rate = clamp(encounter_rate × active_modifier, 0, 1) | ADR-0006 ✅ |
| TR-ez-004 | Boss gate re-evaluated on encounter_resolved + boss-approach query; never mid-battle | ADR-0002 ✅ |
| TR-ez-005 | WIN_COUNT counter cumulative, all-time, zone-wide, never-resetting; wins-only (fled/lost excluded) | ADR-0007 ✅ |
| TR-ez-006 | Boss 2 requires_defeated sequencing: gate met only when win threshold AND named boss defeated_once | ADR-0007 ✅ |
| TR-ez-007 | LIGHTER_REGATE delta-measured: win_count − wins_at_last_defeat (snapshot per-boss per defeat) | ADR-0007 ✅ |
| TR-ez-008 | Boss gate defaults LOCKED on missing gate_params, unresolvable prerequisite, or reserved gate type | ADR-0007 ✅ |
| TR-ez-009 | Identity-enemy invariant per terrain: each patch has ≥1 enemy_id appearing in no other patch in zone | ADR-0003 ✅ |
| TR-ez-010 | Farmable-target weight floor: is_farmable_target=true entries ≥20% of patch total_weight, else warning | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/encounter-zone.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- EZ-1 rate clamp and EZ-2 weighted selection are tested with an injected deterministic RNG
  (fixed seed → reproducible enemy pick)
- The gate fail-safe (LOCKED on missing/unresolvable params) and `requires_defeated` sequencing
  have discriminating GUT fixtures; a broken prerequisite ref never fails open

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | Zone data model & EZ-1 encounter trigger | Logic | Done | ADR-0006 (primary), ADR-0003 | TR-ez-001, TR-ez-003 |
| 002 | EZ-2 weighted enemy selection | Logic | Done | ADR-0006 | TR-ez-001 |
| 003 | Sub-pool validation & empty-pool sentinel | Logic | Done | ADR-0003 (primary), ADR-0002 | TR-ez-002 |
| 004 | WILD/BOSS encounter handoff to TBC | Integration | Done | ADR-0007 (primary), ADR-0002 | TR-ez-001 |
| 005 | Boss gate WIN_COUNT first-access & sequencing | Logic | Done | ADR-0007 (primary), ADR-0002 | TR-ez-004, TR-ez-005, TR-ez-006, TR-ez-008 |
| 006 | Repeat policy — LIGHTER_REGATE delta re-gate & ALWAYS_OPEN | Logic | Done | ADR-0007 | TR-ez-005, TR-ez-007 |
| 007 | Gate params validation & reserved-gate fail-safe | Logic | Done | ADR-0007 (primary), ADR-0003 | TR-ez-008 |
| 008 | Content-validation linters | Config/Data | Done | ADR-0003 | TR-ez-009, TR-ez-010 |

**8 stories: 6 Logic, 1 Integration, 1 Config/Data.** Build order: **001 (anchor) → {002, 003, 005, 008}**; **004** depends on 002 + 003; **006** and **007** depend on 005. Story 001 delivers the `ZoneDef`/`TerrainPatch`/`SpawnEntry`/`BossEncounter` value types + the injected-RNG/LogSink/Enemy-DB resolver host + EZ-1; 002 the EZ-2 weighted walk; 003 the `filter_valid` sub-pool exclusions + empty-pool sentinel; 004 the WILD/BOSS handoff to a stub TBC; 005 the WIN_COUNT first-access + `requires_defeated` sequencing (with the fail-safe LOCKED broken-ref); 006 the delta re-gate + ALWAYS_OPEN; 007 gate-param validation + reserved-gate fail-safe; 008 the offline content linters.

**Coverage**: all 10 TR-ez requirements covered. **40 BLOCKING** ACs (Unit/Integration) + **11 ADVISORY** (Content Validation, Story 008) are stored now. The GDD's **60 ACs** map as: 001 → AC-EZ-01/02/03/57/59; 002 → 04–09; 003 → 26–30/32/33; 004 → 15; 005 → 16–20/40a/56/58; 006 → 21/22/23/39/52; 007 → 24/25/31/34–38; 008 → 10–14/47–51/54.

**Deferred integration (9 DEFERRED ACs — not stories; write-the-stub-now, activate-when-the-Not-Started-system-ships):** AC-EZ-40b (live Exploration Progress), 41 (EZ-1 only on terrain tiles), 42 (sentinel → no transition), 43/44 (win-counter + `defeated_once` save/reload persistence), 45 (terrain_type from tile), 46 (reachable boss map presence), 53 (`FULL_REGATE` reserved behavior), 55 (WIN_COUNT wins-only across flee/loss). These await Overworld Navigation (#16), Zone & World Map (#12), and Exploration Progress (#14). Each blocked AC's stub note lives in the relevant story's Out of Scope.

**Deferred content pass (not a story):** the real MVP zone `.tres` (one zone, 3–4 terrain patches drawn from ~8 WILD enemies, 2 bosses on the shared WIN_COUNT counter) is authored later — it needs the ~8-WILD roster and the finalized Art Bible terrain enum (OQ-EZ-1). Story 008 builds and proves the content linters **against fixtures now**; the real content is validated by those same linters when authored. This parallels the Synergy-tier `.tres` deferral — engine + linters built against DI seams + fixtures, content later.

## Next Step

**Epic complete (2026-07-17).** All 8 stories implemented, tested, and closed. The engine + offline content linters are built and proven against DI seams and fixtures; the real MVP zone `.tres` (one zone, 3–4 patches from ~8 WILD, 2 bosses) remains a deferred authoring pass (OQ-EZ-1) that these linters will validate. With Drop System also closed, the **Core layer is complete (5/5 epics)** — next is the Technical Setup → Pre-Production gate (`/test-setup`, `/ux-design`).
