# Epic: Symbot Assembly System

> **Layer**: Core
> **GDD**: design/gdd/symbot-assembly.md
> **Architecture Module**: Symbot Assembly (Core)
> **Status**: ✅ Complete
> **Stories**: 7/7 Complete — closed through the per-story `/code-review` + `/story-done` gate 2026-07-16

## Overview

Symbot Assembly composes a Symbot from its 8 equipment slots and is the **sole
executor of the stat-derivation pipeline**. It owns the `SymbotBuild` manifest and
computes `final_stat` in the ADR-0005 order — SA-F1 (Part DB Formula 1/2/2b) →
CP-F3 (level growth) → SYN-F4 (synergy delta) — flooring once post-chassis-multiply.
It exposes `equip_part()`, `get_final_stat()`, and an SA-F2 delta preview that does a
full hypothetical recompute with no writes or signals. Equip is atomic (no empty
slots; always replacement) and calls `CoreProgression.can_equip` first (the one
upward gate call in the architecture). Final stats are locked at battle start and
never recomputed mid-combat.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Stat Pipeline & Battle Snapshot | Pure formula core in `src/core/stats/`; DI RefCounted owners; single SA-F1→CP-F3→SYN-F4 composition point; final stats frozen at BATTLE_INIT | MEDIUM |
| ADR-0003: Content Resource Loading & Schema Mapping | Reads Part DB stats/upgrades via typed catalog getters; never mutates defs | MEDIUM |
| ADR-0002: Event Bus & Signal Architecture | Owner-declared typed signals `part_equipped` / `stats_changed`; self-sufficient read-only payloads | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-sa-001 | Stat derivation pipeline (SA-F1) is sole executor of Part DB Formula 1/2/2b | ADR-0005 ✅ |
| TR-sa-002 | Per-part upgrades: Formula 2 (base≥0) or Formula 2b (base<0) applied then summed | ADR-0005 ✅ |
| TR-sa-003 | Chassis modifier applied to summed stats, then floor() post-multiplication | ADR-0005 ✅ |
| TR-sa-004 | CP-F3 level-growth added post-chassis-multiply, pre-synergy (Rule 6 step 4b) | ADR-0005 ✅ |
| TR-sa-005 | SA-F2 delta preview requires full hypothetical recompute (all 8 parts, not partial diff) | ADR-0005 ✅ |
| TR-sa-006 | Final stats locked at battle start; no recomputation during combat | ADR-0005 ✅ |
| TR-sa-007 | No empty slots permitted: equip is atomic, slots always filled via replacement | ADR-0005 ✅ |
| TR-sa-008 | Move pool fixed ordering: Basic, WEAPON skill, HEAD skill, ARMS skill (may be null) | ADR-0003 ✅ |
| TR-sa-009 | Passive pool order: CORE, LEGS, then remaining slots in slot-type order | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/symbot-assembly.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The SA-F1→CP-F3→SYN-F4 composition order has a GUT test with a discriminating fixture
  (a case where a wrong ordering, or flooring at the wrong step, produces a different result)
- The SA-F2 preview is proven pure (no signal emit, no cache/build mutation) by test

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | StatPipeline SA-F1 execution core (steps 1–4) | Logic | Complete | ADR-0005 | TR-sa-001/002/003 |
| 002 | SymbotBuild owner & equip mechanics (Rule 3) | Integration | Complete | ADR-0005 | TR-sa-007 |
| 003 | Eager recompute & chassis-swap correctness | Logic | Complete | ADR-0005 | TR-sa-006 |
| 004 | Move pool derivation | Logic | Complete | ADR-0005 | TR-sa-008 |
| 005 | Passive pool derivation | Logic | Complete | ADR-0005 | TR-sa-009 |
| 006 | SA-F2 preview_swap (stat delta) | Logic | Complete | ADR-0005 | TR-sa-005 |
| 007 | CP-F3 level-growth step (4b) & pipeline ordering | Integration | Complete | ADR-0005 | TR-sa-004 |

**Implemented 2026-07-16** — all 7 stories: production code in `src/core/stats/`
(`part_instance.gd`, `stat_pipeline.gd`, `symbot_build.gd`; `canonical_stat_keys`
added to `balance_config.gd`) + 7 GUT files (`tests/unit/symbot_assembly/` ×5,
`tests/integration/symbot_assembly/` ×2). Suite green at **657 tests / 53 scripts**
(was 631/46; +26 tests).

**Coverage**: all 9 TR-sa IDs and all 15 GDD ACs (AC-SA-01…15) covered exactly once.

**Build order**: 001 → 002 → {003, 004, 005, 006, 007}. Story 002 is the anchor
(the `SymbotBuild` owner); 003–007 depend on it. Story 007 carries a **binding
cross-system DoD gate** (AC-SA-15 = Core Progression AC-CP-18).

**Injected upstream collaborators** (stubbed in tests, not blockers — no Proposed
ADR involved): **Inventory** (system Not Started) and **CoreProgression** (GDD
Approved, no code yet). Both are DI collaborators per ADR-0005's testability mandate.

## Next Step

**Epic closed (2026-07-16).** All 7 stories implemented, green, and formally closed through
the per-story `/code-review` + `/story-done` gate (lean/inline mode). Baseline: full GUT suite
**657/657 green, 3934 asserts, 53 scripts** (Godot 4.7 headless) — one run validates all 7
markdown-only closures. Each story now carries `Status: Complete` + `## Completion Notes`
(verdict / criteria / deviations / test evidence / code review).

Gate findings: 6/7 stories APPROVED clean; Story 006 APPROVED WITH NOTES — one ADVISORY
latent-limitation logged to `docs/tech-debt-register.md` (SA-F2 preview previews the candidate
`PartDef` at tier +0; a future Workshop-UI preview of an owned instance at tier > 0 needs an
instance-taking overload). Story 007's binding cross-system DoD gate (AC-SA-15 = Core
Progression AC-CP-18, the 160-not-168 CP-F3 ordering discriminator) is **green and discharged**.

Core layer forward progress: `/create-stories synergy-system` (its BATTLE_INIT path snapshots
Assembly's `final_stat` and folds SYN-F4 on top — the composition point Assembly deliberately
leaves out per Rule 8).
