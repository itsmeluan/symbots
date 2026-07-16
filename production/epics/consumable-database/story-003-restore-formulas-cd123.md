# Story 003: Restore effect formulas (CD-1 / CD-2 / CD-3)

> **Epic**: Consumable Database
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/consumable-database.md`
**Requirement**: `TR-cdb-003` (RESTORE_* semantics), `TR-cdb-008` (flat-integer magnitudes; pure integer clamps, no floor/ceil)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Content declares data; effect magnitudes are flat integers read from `effect_params`. (Pure-formula-core discipline aligns with ADR-0005 — the restore functions are pure and side-effect-free, taking current/max/amount and returning the new value.)

**Engine**: Godot 4.7 | **Risk**: LOW (pure integer `min`/`max` clamps — GDD Formulas section states explicitly: **no `floor()`/`ceil()`, no python3 float scan required**)
**Engine Notes**: CD-1/2/3 are pure integer arithmetic. Read `max_structure`/`max_energy` from the *runtime* target (a leveled CORE carries a higher cap) — **never hardcode 120 or 594**. AC-CD-03 case C (`max_energy=147`) is the sole catch for a hardcoded-ceiling bug.

**Control Manifest Rules (this layer)**:
- Required: Gameplay values data-driven — `amount` comes from `effect_params`, never a magic literal in the formula — source: coding-standards / ADR-0003
- Forbidden: hardcoding a resource cap; `floor()`/`ceil()` in an integer-clamp formula — source: GDD Formulas
- Guardrail: pure functions, no RNG, no state read beyond the passed args

---

## Acceptance Criteria

*From GDD Formulas CD-1 / CD-2 / CD-3, verified by AC-CD-01 / 02 / 03:*

- [ ] **CD-1 RESTORE_STRUCTURE**: `new_structure = min(max_structure, current_structure + amount)` — AC-CD-01
- [ ] **CD-2 REDUCE_HEAT**: `new_heat = max(0, current_heat − amount)` — AC-CD-02
- [ ] **CD-3 RESTORE_ENERGY**: `new_energy = min(max_energy, current_energy + amount)`, reading the runtime `max_energy` (not a hardcoded 120) — AC-CD-03
- [ ] `amount` is read from `effect_params`, not a literal in the formula

---

## Implementation Notes

*Derived from GDD Formulas Section (CD-1/2/3):*

Implement three pure functions (e.g. on a `ConsumableEffects` helper in `src/core/content/` or `src/core/stats/`, DI-testable, no autoload dependency). Each takes plain ints and returns an int — no target object mutation here (application to a live Symbot is the TBC erratum, AC-CD-20 DEFERRED; this story delivers the pure math the erratum will call). The worked examples in the GDD are discriminating — reproduce them as fixtures. **CD-3 case C is mandatory**: `max_energy=147, current=130, amount=25 → 147` catches a hardcoded-120 cap that every other CD-3 case would pass silently.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 004: the use-transaction wrapper (validate → apply → decrement), rejections, targeting
- Story 005: BOOST_DROP (CD-4)
- Story 006: MODIFY_ENCOUNTER_RATE (CD-5)
- **TBC erratum** (AC-CD-20, DEFERRED): applying the returned value to a live Symbot as a turn-consuming action — this story is the pure math only

---

## QA Test Cases

- **AC-1** (AC-CD-01): CD-1 applies + caps
  - Given: Weld Patch `amount=25`
  - When: `restore_structure(current=50, max=60, amount=25)`
  - Then: `== 60` (clamped, not 75)
  - Edge cases: `restore_structure(30, 594, 50) == 80` (no clamp) — both cases required so a wrong-formula-but-correct-clamp can't pass; an impl omitting `min()` returns 75 in the first case
- **AC-2** (AC-CD-02): CD-2 applies + floors
  - Given: Coolant Flush `amount=50`
  - When: `reduce_heat(current=30, amount=50)`
  - Then: `== 0` (floored, not −20)
  - Edge cases: `reduce_heat(80, 50) == 30`; an impl omitting `max(0,…)` returns −20
- **AC-3** (AC-CD-03): CD-3 applies + caps at runtime max
  - Given: Power Cell `amount=25`
  - When: `restore_energy(current=90, max=100, amount=25)`
  - Then: `== 100` (clamped, not 115)
  - Edge cases: `restore_energy(50, 80, 25) == 75`; **case C `restore_energy(130, 147, 25) == 147`** — the sole catch for a hardcoded-120 ceiling against an L10 leveled core

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/consumable_database/restore_formulas_test.gd` — must exist and pass

**Status**: [x] Passing — full GUT suite 452/452 green (2026-07-16)

---

## Dependencies

- Depends on: Story 001 (schema — `effect_params.amount`)
- Unlocks: Story 004 (use-transaction calls these), TBC erratum (AC-CD-20)
