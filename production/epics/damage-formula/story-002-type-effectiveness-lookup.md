# Story 002: Type-effectiveness lookup — `type_effectiveness()` + `type_chart` config

> **Epic**: Damage Formula
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/damage-formula.md`
**Requirement**: `TR-df-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Stat Pipeline & Battle Snapshot
**ADR Decision Summary**: The type-effectiveness multiplier `T` is derived from the locked Part DB Rule 6 chart (Volt/Thermal/Kinetic × ×1.5/×1.0/×0.75), which lives in `BalanceConfig.type_chart`. GDD Open Question 1's recommended resolution: expose the chart as **one standalone pure function** — `type_effectiveness(skill_element, target_core_element) -> float` — that DF-1 uses internally to bind `T` *and* the Combat UI calls directly for the pre-commit effectiveness telegraph, so the two readings can never disagree and the view never reimplements the chart (ADR-0008 `inline_stat_composition`).

**Engine**: Godot 4.7 | **Risk**: LOW-MEDIUM (pure `Dictionary.get` lookup; the only risk is the **nested** `type_chart` typed-Dictionary `.tres` round-trip — the same shared gate as `chassis_modifiers`, already exercised by the shipped stat pipeline)
**Engine Notes**: `type_chart` is a **new** `@export` on `BalanceConfig` (append-only — add after the last existing field). Store it nested `element → {element → float}` mirroring the existing `chassis_modifiers` shape, and read with `.get(key, {}).get(key, 1.0)` so any absent cell (null/unknown/Full-Vision-reserved element) degrades to ×1.0 (EC-04/EC-05) with no branch. Element keys are `PartDef.Element` enum values (`VOLT`/`THERMAL`/`KINETIC`), matching how the pipeline keys other enum tables. `null`/unrecognized element → ×1.0 fallback is a hard requirement, not a crash.

**Control Manifest Rules (this layer — Core)**:
- Required: the pure formula core lives in `src/core/stats/` (static, no autoload); a single `BalanceConfig` `.tres` is the sole tuning source; type-chart ratios are locked from Part DB Rule 6 — this system reads and applies, never redefines — source: ADR-0005 / ADR-0003
- Forbidden: reimplementing the chart anywhere else (`inline_stat_composition` — the Combat UI must call this function, not its own copy); reordering/renumbering the `PartDef.Element` enum used as keys (`content_enum_reordering`) — source: ADR-0005/0008/0003
- Guardrail: absent cell → ×1.0 via `.get()` default — no `assert`/error on unknown element (null-element targets are valid content) — source: GDD EC-04/EC-05

---

## Acceptance Criteria

*From GDD `design/gdd/damage-formula.md`, scoped to the pure chart lookup:*

- [ ] **AC-DF-08** — all 9 type-chart cells return the correct multiplier. `type_effectiveness(skill, core)` returns, for `(skill → core)`: VOLT→VOLT ×1.0, VOLT→THERMAL ×1.5, VOLT→KINETIC ×0.75, THERMAL→VOLT ×0.75, THERMAL→THERMAL ×1.0, THERMAL→KINETIC ×1.5, KINETIC→VOLT ×1.5, KINETIC→THERMAL ×0.75, KINETIC→KINETIC ×1.0 — zero failures across all 9
- [ ] **AC-DF-09** — null / unrecognized **target Core** element → ×1.0 (does not throw, does not default to ×1.5)
- [ ] **AC-DF-10** — null / unrecognized **skill** element → ×1.0 (neutral, not the ×1.5 super-effective result)
- [ ] `BalanceConfig.type_chart` added (append-only), authored in `assets/data/balance_config.tres` with all 9 locked Rule 6 cells, and round-trips correctly (nested typed-Dictionary `.tres` load — shared gate with `chassis_modifiers`)
- [ ] ContentValidator asserts `type_chart` shape: every value ∈ `{0.75, 1.0, 1.5}` and the 3×3 VOLT/THERMAL/KINETIC grid is complete (no missing cell for MVP elements)

---

## Implementation Notes

*Derived from ADR-0005 Layer 1 + GDD Rule 2 + Open Question 1:*

Add to `src/core/stats/damage_formula.gd` (same class as Story 001):

```gdscript
## Pure Part DB Rule 6 chart lookup — the SINGLE source of T for DF-1 (Story 003
## composition) AND the Combat UI pre-commit effectiveness glyph (OQ-1). Absent /
## null / unrecognized element on either side → ×1.0 (EC-04 / EC-05), never a throw.
static func type_effectiveness(skill_element, target_core_element,
        cfg: BalanceConfig) -> float:
    return float(cfg.type_chart.get(skill_element, {}).get(target_core_element, 1.0))
```

- Accept `skill_element` / `target_core_element` untyped (or as `Variant`) so a literal `null` (missing Core, missing element) reaches the `.get()` default cleanly — do not type them `int` (a null passed to an `int` param would error before the fallback runs). The nested-`.get()` default handles all of EC-04, EC-05, and any Full-Vision reserved element (`CRYO`/`CORROSIVE`/`DATA`) in one expression.
- **BalanceConfig**: append `@export var type_chart: Dictionary` after the last existing field, authored nested:

```gdscript
@export var type_chart: Dictionary = {
    PartDef.Element.VOLT:    {PartDef.Element.VOLT: 1.0, PartDef.Element.THERMAL: 1.5, PartDef.Element.KINETIC: 0.75},
    PartDef.Element.THERMAL: {PartDef.Element.VOLT: 0.75, PartDef.Element.THERMAL: 1.0, PartDef.Element.KINETIC: 1.5},
    PartDef.Element.KINETIC: {PartDef.Element.VOLT: 1.5, PartDef.Element.THERMAL: 0.75, PartDef.Element.KINETIC: 1.0},
}
```

  Then author the same values into `assets/data/balance_config.tres` and confirm the nested Dictionary survives the `.tres` round-trip (load the resource in the test, assert a couple of cells).
- **ContentValidator**: extend the balance family — for each of VOLT/THERMAL/KINETIC as skill element, assert the inner dict exists and each of the 3 core-element cells is present and ∈ `{0.75, 1.0, 1.5}`. Emit e.g. `content_balance_type_chart_malformed` on a missing/out-of-set cell. Mirror the existing gated-family pattern (`_cfg != null`).
- **Do not redefine ratios**: the values are locked in Part DB Rule 6 (GDD Rule 2 states "This GDD does not redefine them"). ContentValidator's fixture check should compare against the GDD-quoted constants, matching the BalanceConfig-vs-GDD drift guard the ADR describes.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: the `compute_damage` kernel and `damage_floor` — this story derives `T`, it does not apply it to damage
- **Story 003**: calling `type_effectiveness` inside the routed composition and asserting the resulting **final_damage** integers (this story asserts the **multiplier**, not the damage)
- Combat UI's actual pre-commit glyph rendering — Presentation layer; it will *call* this function

---

## QA Test Cases

*Authored inline (lean mode — no qa-plan exists). Automated unit specs.*

- **AC-DF-08** (9-cell matrix):
  - Given: `cfg = BalanceConfig.new()`
  - When: `type_effectiveness(skill, core, cfg)` for each of the 9 `(skill, core)` pairs
  - Then: assert each returns its expected multiplier (parameterized: 9 sub-assertions, values `{1.0, 1.5, 0.75}` per the AC-DF-08 table)
  - Edge cases: use `is_equal_approx` for the float compare; the three distinct values {0.75, 1.0, 1.5} are themselves discriminating (a swapped cell fails)
- **AC-DF-09** (null core → neutral):
  - When: `type_effectiveness(PartDef.Element.VOLT, null, cfg)` → `assert_eq(result, 1.0)`
  - Edge cases: also assert a Full-Vision reserved / unknown int core value → 1.0 (no throw)
- **AC-DF-10** (null skill → neutral):
  - When: `type_effectiveness(null, PartDef.Element.THERMAL, cfg)` → `assert_eq(result, 1.0)` (NOT 1.5)
- **type_chart .tres round-trip**:
  - Given: `load("res://assets/data/balance_config.tres")`
  - Then: assert `type_chart[VOLT][THERMAL] == 1.5` and `type_chart[THERMAL][VOLT] == 0.75` survive load (nested typed-Dictionary gate)
- **ContentValidator shape**:
  - Given: a `BalanceConfig` with a corrupted cell (e.g. `type_chart[VOLT][THERMAL] = 2.0`)
  - When: validate
  - Then: asserts `content_balance_type_chart_malformed`; a clean config validates silent

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage-formula/type_effectiveness_test.gd` — must exist and pass (9-cell matrix + null fallbacks + `.tres` round-trip). ContentValidator shape check may live alongside the existing balance-validator suite.

**Status**: [x] Created and passing — `tests/unit/damage-formula/type_effectiveness_test.gd` (14/14; suite 257/257 green, 2026-07-16)

---

## Dependencies

- Depends on: Story 001 (shares `damage_formula.gd` + `balance_config.gd` / `.tres`; append after to avoid a merge on the same files)
- Unlocks: Story 003 (routed composition calls this lookup); Combat UI pre-commit telegraph (later epic) reuses this exact function

---

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 5/5 passing (AC-DF-08 9-cell matrix, AC-DF-09 null core, AC-DF-10 null skill, `.tres` nested round-trip, ContentValidator shape) — all COVERED by unit tests, none deferred.
**Deviations**: None. Manifest v2026-07-14 == current (no drift). ADR-0005 compliant (pure Layer-1 static fn, single composition point, append-only Layer-4 `type_chart`, data-driven Rule 6 ratios). No out-of-scope files.
**Test Evidence**: Logic — `tests/unit/damage-formula/type_effectiveness_test.gd` (14/14; full suite 257/257 green).
**Code Review**: Complete — `/code-review` verdict APPROVED WITH SUGGESTIONS. GDScript specialist clean (untyped `Variant` params confirmed correct 4.7 idiom for null-key EC-04/05 fallback); QA testability review flagged 3 advisory test-hardening gaps, all since **resolved** in the test file:
  1. `content_balance_type_chart_malformed` `reason` discriminator now asserted in all 3 rejection tests (was code-only).
  2. Added `test_validator_rejects_scalar_row` — `missing_row` via present-but-scalar row (was only tested via absent key).
  3. Added `test_validator_rejects_non_numeric_cell` — pins the validator as the pre-flight gate for garbage cell types (documents why the runtime lookup may assume well-typed cells).
