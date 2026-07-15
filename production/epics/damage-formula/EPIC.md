# Epic: Damage Formula

> **Layer**: Foundation
> **GDD**: design/gdd/damage-formula.md
> **Architecture Module**: Damage Formula (Foundation — pure)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories damage-formula`

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

## Next Step

Run `/create-stories damage-formula` to break this epic into implementable stories.
