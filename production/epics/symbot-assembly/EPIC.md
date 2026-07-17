# Epic: Symbot Assembly System

> **Layer**: Core
> **GDD**: design/gdd/symbot-assembly.md
> **Architecture Module**: Symbot Assembly (Core)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories symbot-assembly`

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

## Next Step

Run `/create-stories symbot-assembly` to break this epic into implementable stories.
