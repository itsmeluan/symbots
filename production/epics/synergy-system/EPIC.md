# Epic: Synergy System

> **Layer**: Core
> **GDD**: design/gdd/synergy-system.md
> **Architecture Module**: Synergy (Core)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories synergy-system`

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

## Next Step

Run `/create-stories synergy-system` to break this epic into implementable stories.
