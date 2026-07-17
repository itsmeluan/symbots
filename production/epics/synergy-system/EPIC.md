# Epic: Synergy System

> **Layer**: Core
> **GDD**: design/gdd/synergy-system.md
> **Architecture Module**: Synergy (Core)
> **Status**: Done — all 5 stories implemented & tested 2026-07-16 (engine complete; content authoring deferred, see below)
> **Stories**: 5 stories, all Done — SynergySystem engine implemented, 32 GUT tests green

## Overview

The Synergy System detects active element/manufacturer sets from a build's equipped
parts and produces the cumulative bonus block the stat pipeline folds in at the single
SYN-F4 composition point. It owns one `cached_bonus_block` (never null) and exposes
`evaluate(parts)` (emits `synergy_changed`), `evaluate_silent(parts)` (no emit — the
battle path), and a pure read-only `preview()`. Tier activation is AND-logic over all
constituent tag counts (SYN-F2); bonuses at every active tier stack additively; combined
synergies stack on top of their constituents. Effect dedup is keep-first in **alphabetical
tier-ID registration order** — the load-bearing determinism rule, which rides on a
`String(tier_id)` sort (a StringName intern trap flagged in ADR-0008).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Stat Pipeline & Battle Snapshot | Single SYN-F4 composition point; cached bonus block frozen at BATTLE_INIT (behavioral contract) | MEDIUM |
| ADR-0003: Content Resource Loading & Schema Mapping | Reads Part DB synergy tags via typed catalog; null tags treated as [] | MEDIUM |
| ADR-0002: Event Bus & Signal Architecture | Owner-declared `synergy_changed`; `evaluate` always emits per Rule 7; diagnostics via injected LogSink | LOW |
| ADR-0008: UI Architecture & Screen Contracts | `preview()` is the pure-core reuse point for hypothetical stat display — never reimplemented for UI | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-syn-001 | Tag count is pure sum per SYN-F1; each part contributes all tags including duplicates | ADR-0005 ✅ |
| TR-syn-002 | Tier activation (SYN-F2) requires ALL constituent tag counts met (AND logic) | ADR-0005 ✅ |
| TR-syn-003 | Bonus blocks cumulative at all active tiers; both 3-piece and 5-piece stack | ADR-0005 ✅ |
| TR-syn-004 | Combined synergies stack additively with constituent bonuses, not replacement | ADR-0005 ✅ |
| TR-syn-005 | Effect deduplication keep-first in registration order (alphabetical tier ID) | ADR-0005 ✅ |
| TR-syn-006 | Registration order determined by alphabetical tier-ID sort, not content-file order | ADR-0005 ✅ |
| TR-syn-007 | Tier with empty requirements or min_count<1 skipped with content error logged | ADR-0002 ✅ |
| TR-syn-008 | Cached bonus block frozen during battle (behavioral contract, not self-lock) | ADR-0005 ✅ |
| TR-syn-009 | preview() call is pure read-only: no cache write, no signal emit | ADR-0008 ✅ |
| TR-syn-010 | SYN-F4 effective stat formula: max(0, base + synergy_delta) — consumer responsibility | ADR-0005 ✅ |
| TR-syn-011 | evaluate() always emits signal per Rule 7, even if bonus_block identical | ADR-0002 ✅ |
| TR-syn-012 | active_synergies list must be Array[StringName] never null, including empty build | ADR-0005 ✅ |
| TR-syn-013 | Null synergy_tags treated as [] (no tags); iteration must guard against null | ADR-0003 ✅ |
| TR-syn-014 | Unregistered effect IDs pass through unfiltered; skip-and-log is TBC responsibility | ADR-0005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/synergy-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The alphabetical tier-ID dedup order has a GUT test with a discriminating fixture proving
  the `String(tier_id)` sort — not content-file order — decides keep-first
- `preview()` and `evaluate_silent()` are proven emit-free / cache-write-free by test

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | SynergySystem core — SYN-F1 counting, SYN-F2 activation, evaluate() + synergy_changed | Logic | Done | ADR-0005 (primary), ADR-0002 | TR-syn-001/002/007/011/012/013 |
| 002 | Cumulative & combined tier aggregation (SYN-F3 stat_delta) | Logic | Done | ADR-0005 | TR-syn-003/004 |
| 003 | Effect dedup & alphabetical tier-ID ordering (SYN-F3 effects) | Logic | Done | ADR-0005 | TR-syn-005/006/014 |
| 004 | evaluate_silent() battle path (no emit, no self-lock) | Logic | Done | ADR-0005 (primary), ADR-0002 | TR-syn-008 |
| 005 | preview() pure read-only hypothetical | Logic | Done | ADR-0008 (primary), ADR-0005 | TR-syn-009 |

**5 stories, all Logic.** Build order: **001 (anchor) → {002, 003, 004, 005}** — 002–005 all depend on 001 and are mutually independent. Story 001 delivers the `SynergySystem` RefCounted owner + `SynergyTierDef` runtime type + the count→activate→evaluate spine; 002 adds `stat_delta` depth, 003 the effect dedup/ordering (carries the AC-SYN-05b DoD gate), 004 the silent battle path, 005 the read-only `preview()`.

**Coverage**: TR-syn-001…009, 011…014 covered. **TR-syn-010 (SYN-F4 `max(0, base+delta)`) is deliberately NOT storied here** — it is **consumer-owned** (AC-SYN-06 / AC-SYN-10), applied in TBC + Workshop UI at `StatMath.effective_stat` / `CombatantSnapshot.effective_stat` per ADR-0005 / the control manifest. It discharges when those consumers are built.

**Deferred / out of scope (not stories):**
- **Synergy tier `.tres` content authoring** — blocked on OQ-1 (data format: dedicated `SynergyDatabase.tres` vs part of Part DB), OQ-2 (MVP stat values + 7-tier cumulative-budget validation), OQ-3 (feasible effect IDs from the TBC GDD registry). These stories build the **engine** against an injected `Array[SynergyTierDef]` DI test seam; real content is a later pass once those OQs resolve.
- **SYN-F4 consumer application** — see TR-syn-010 above.

## Implementation Record (2026-07-16)

All 5 stories implemented inline and verified:
- **Production**: `src/core/synergy/synergy_system.gd` (`SynergySystem` — 3 entry points over one private `_compute` core), `src/core/synergy/synergy_tier_def.gd` (`SynergyTierDef` DI value object).
- **Tests**: 5 GUT suites under `tests/unit/synergy/` (32 tests total), + `synergy_fixtures.gd` / `spy_log_sink.gd` support. Full suite **689/689 green, 4024 asserts** (baseline 657/657 → +32).
- **DoD gates proven**: AC-SYN-05b `String(tier_id)` sort discriminator (reverse-alpha fixture); `evaluate_silent()` emit-free; `preview()` cache-write-free / emit-free incl. the AC-SYN-13 B add-only delta-shortcut discriminator.
- **Deferred as designed**: SYN-F4 (TR-syn-010) consumer-owned; synergy tier `.tres` content blocked on OQ-1/2/3 — engine built against the injected `Array[SynergyTierDef]` seam.

## Next Step

Synergy engine is complete. Remaining before this epic fully closes to content: resolve OQ-1/2/3 and author the synergy tier `.tres` roster (a later content pass). Next Core epic: continue with `/create-stories` for the next Core-layer system, or `/create-epics` if Core epics remain undefined.
