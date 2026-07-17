# Epic: Encounter Zone System

> **Layer**: Core
> **GDD**: design/gdd/encounter-zone.md
> **Architecture Module**: Encounter Zone (Core)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories encounter-zone`

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

## Next Step

Run `/create-stories encounter-zone` to break this epic into implementable stories.
