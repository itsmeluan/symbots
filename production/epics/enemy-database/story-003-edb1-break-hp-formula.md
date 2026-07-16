# Story 003: EDB-1 break_hp derivation formula (epsilon LOAD-BEARING)

> **Epic**: Enemy Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: `TR-edb-002` (break_hp derivation), `TR-edb-003` (`BREAK_HP_MIN` floor)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Formula math lives in a pure, DI-testable function; the DB stores the *derived* value and the validator (Story 006) asserts stored-equals-derived. This story owns the derivation function only.

**Engine**: Godot 4.7 | **Risk**: MEDIUM (IEEE-754 floor boundary — the `+0.0001` epsilon is **LOAD-BEARING**; see project memory `float-epsilon-empirics`)
**Engine Notes**: `EDB-1: break_hp = max(BREAK_HP_MIN, floor(structure × region_fraction + 0.0001))` with `BREAK_HP_MIN = 5`. The `+0.0001` epsilon prevents a value that is mathematically an integer (e.g. `180 × 0.35 = 63.0`) from landing at `62.9999999…` and flooring to 62. **python3-scan every fixture** before locking pass values (specialists have erred in BOTH directions on this project). Use discriminating inputs where `floor ≠ round ≠ ceil`.

**Control Manifest Rules (this layer)**:
- Required: pure function (inputs → int, no side effects, no global RNG); epsilon present exactly as `+0.0001`; `BREAK_HP_MIN` is a named constant, not a literal — source: ADR-0003 / coding-standards
- Forbidden: dropping/renaming the epsilon; using `round()`/`ceil()`; hardcoding `5` inline — source: GDD Formula EDB-1
- Guardrail: deterministic — same inputs always yield the same int (no time/seed dependence)

---

## Acceptance Criteria

*From GDD Formula EDB-1 + AC-ED-08:*

- [ ] `derive_break_hp(structure, region_fraction) -> int` implements `max(BREAK_HP_MIN, floor(structure × region_fraction + 0.0001))`
- [ ] `BREAK_HP_MIN == 5` as a named constant
- [ ] **Epsilon case** (the load-bearing assertion): `180 × 0.35 → 63` (NOT 62); at least one more exact-integer product proves the epsilon holds
- [ ] **Discriminating case**: `85 × 0.35 = 29.75 → 29` (floor ≠ round(30) ≠ ceil(30))
- [ ] **Floor guard**: a tiny product (e.g. `20 × 0.15 = 3.0 → max(5, 3) = 5`) clamps up to `BREAK_HP_MIN`
- [ ] All fixture pass-values python3-verified before commit (documented in the test header)

---

## Implementation Notes

*Derived from GDD Formula EDB-1 + project memory `float-epsilon-empirics`:*

One pure static function (or a `RefCounted` formula owner, matching how the Part-DB F2b formula is housed). `const BREAK_HP_MIN := 5`. Body: `return maxi(BREAK_HP_MIN, int(floor(structure * region_fraction + 0.0001)))`. Before writing the test, run each `(structure, region_fraction)` pair through `python3 -c "import math; print(math.floor(...))"` **with and without** the epsilon to confirm (a) the epsilon changes the result for the 63 case and (b) it does *not* wrongly bump the 29.75 case to 30. The 63 case is the whole reason the epsilon exists — if a future refactor drops it, that test must go red. Store nothing here; Story 006's `_check_enemy_break_region` calls this same function and asserts the authored `break_hp` equals the derived value.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the validator that asserts stored `break_hp` == `derive_break_hp(...)` and the `break_hp < structure` / bounds / connectivity checks
- Story 008: EDB-2 TTK calibration (a different, ADVISORY formula)
- Story 001: the `break_regions` schema field this value populates

---

## QA Test Cases

- **AC-1** (epsilon load-bearing): exact-integer product does not under-floor
  - Given: `structure=180, region_fraction=0.35` (product `63.0`)
  - When: `derive_break_hp(180, 0.35)`
  - Then: `== 63`
  - Edge cases: **remove the `+0.0001` and this must return 62** — that divergence is the epsilon's proof; add a second exact-product pair to guard
- **AC-2** (discriminating floor): non-integer product floors, not rounds
  - Given: `structure=85, region_fraction=0.35` (product `29.75`)
  - When: `derive_break_hp(85, 0.35)`
  - Then: `== 29` (a `round()` impl gives 30, a `ceil()` gives 30)
  - Edge cases: the epsilon must NOT push this to 30 — verify `29.75 + 0.0001` still floors to 29
- **AC-3** (BREAK_HP_MIN clamp): tiny product clamps up
  - Given: `structure=20, region_fraction=0.15` (product `3.0`)
  - When: `derive_break_hp(20, 0.15)`
  - Then: `== 5` (`max(5, 3)`)
  - Edge cases: a no-floor `max` impl on a `4.9` product still yields 5; a missing clamp yields 3 and fails

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_database/break_hp_formula_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema defines `structure`/`region_fraction`/`break_hp`)
- Unlocks: Story 006 (validator asserts stored == derived using this function)
