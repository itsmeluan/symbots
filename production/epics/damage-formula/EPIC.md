# Epic: Damage Formula

> **Layer**: Foundation
> **GDD**: design/gdd/damage-formula.md
> **Architecture Module**: Damage Formula (Foundation — pure)
> **Status**: Complete (all 3 stories closed 2026-07-16)
> **Stories**: 3 created (2026-07-16), 3 complete — see the Stories table below

## Overview

The Damage Formula is the single pure, stateless `compute_damage` function that
every damage calculation in the game routes through. It takes attack/defense
stats, damage type, attacker element and target core element, and an injected
crit multiplier, and returns a floored integer damage value ≥ DAMAGE_FLOOR. It
owns no state and reads no singletons — it lives in `src/core/stats/` as a static
function with dependency injection, so it is trivially unit-testable and
deterministic. This epic delivers that function plus the numeric-correctness
guarantees (float casts before division, type effectiveness applied before the
single floor, division-by-zero guard) and the crit-multiplier injection seam.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Stat Pipeline & Battle Snapshot | Pure formula core in `src/core/stats/`; single `compute_damage` composition point; DI RefCounted owners | MEDIUM (all APIs 4.1-era stable except typed dicts 4.4+) |
| ADR-0006: RNG Service & Determinism | `crit_mult` is injected (TBC vends `next_seed(&"crit")` → deterministic crit); formula never rolls its own RNG | MEDIUM (RNG API stable; PCG32 seed→sequence is engine-version-fragile) |

## GDD Requirements

All 6 requirements are traced (architecture review: 0 Foundation gaps).

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-df-001 | Pure stateless function: no runtime state, inputs → output only | ADR-0005 ✅ |
| TR-df-002 | Type effectiveness multiplier applied before floor(), not after | ADR-0005 ✅ |
| TR-df-003 | RNG injection: crit_mult must be a passable parameter, not hardcoded internally | ADR-0006 ✅ |
| TR-df-004 | Float division required: cast A, D to float before dividing to avoid integer truncation | ADR-0005 ✅ |
| TR-df-005 | Damage floor applies after floor(), via max(DAMAGE_FLOOR, result) | ADR-0005 ✅ |
| TR-df-006 | Division-by-zero guard: if A==0 AND D==0, return DAMAGE_FLOOR before division | ADR-0005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/damage-formula.md` are verified
- `compute_damage` has GUT unit tests using discriminating fixtures (inputs where
  float-cast vs integer-truncation, and before-floor vs after-floor type multiply,
  produce different outputs)
- The A==0 ∧ D==0 division-by-zero guard is tested at the boundary
- crit_mult is proven injectable (a test passes crit=1.0 and crit>1.0 and asserts both)
- The function reads no singleton and no engine RNG (verified by construction — pure static)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | DF-1 kernel — `compute_damage()` + `damage_floor` config | Logic | Complete | ADR-0005 (sec: ADR-0006) |
| 002 | Type-effectiveness lookup — `type_effectiveness()` + `type_chart` config | Logic | Complete | ADR-0005 |
| 003 | Damage-type routing + full routed composition | Logic | Complete | ADR-0005 |

**Scope note:** ADR-0005 pins the kernel signature `compute_damage(a, d, type_mult, cfg, log, crit_mult := 1.0)` (pre-bound A/D, pre-derived T). The GDD's blocking ACs, however, test the *routed* path (stats + `damage_type` + element → damage) and the *type-chart derivation* — so this epic ships all three layers: the pure kernel (001), the standalone type-effectiveness lookup that is the single source of truth for both DF-1 and the Combat UI pre-commit telegraph per GDD OQ-1 (002), and the routed composition that gives Turn-Based Combat its call contract (003). Config fields (`damage_floor`, `type_chart`) are appended to the existing `BalanceConfig` inside their consuming story (disjoint fields, append-only — no merge). Downstream: MOVE-F1 (Move DB, shipped) scales DF-1 output; the full DF-1→MOVE-F1→TBC-F5 pipeline (AC-MDB-05) verifies once TBC-F5 exists.

## Next Step

Run `/story-readiness production/epics/damage-formula/story-001-df1-kernel-compute-damage.md`
then `/dev-story` to begin implementation. Work stories in dependency order (001 → 002 → 003;
each story's `Depends on:` field is authoritative).
