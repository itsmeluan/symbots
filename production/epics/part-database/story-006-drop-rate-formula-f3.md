# Story 006: Formula 3 — effective drop rate

> **Epic**: Part Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-016`, `TR-part-017`, `TR-part-007` (F3 side — the ≥500 authoring rule itself is validated in Story 008)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: `base_drop_rate` is NOT a per-part field — the Drop System looks up the rarity-constant base from tuning config using the part's `rarity` enum. Formula 3 is a pure deterministic function of `rarity` + matching `drop_conditions`; the RNG *draw* against the resulting probability belongs to the Drop System (ADR-0006/0007), not here.

**Engine**: Godot 4.6 | **Risk**: LOW (pure math)
**Engine Notes**: This is a pure `clamp(base × Πmultipliers, 0.0, 1.0)` — **no RNG here** (RNG vending is the Drop System's, per ADR-0006/0007). Float-equality caution: `0.25 × 1.5 × 1.3 == 0.48750000000000004` in IEEE 754 — new float-product assertions MUST use tolerance (`< 1e-9`). Verified-exact boundaries (`0.001 × 999 == 0.999`, `0.001 × 1000 == 1.0`) may use strict `==`.

**Control Manifest Rules (this layer)**:
- Required: Content read via `PartDef` typed getters; `base_drop_rate` sourced from rarity config, not a per-part field — source: ADR-0003
- Guardrail: pure function, no allocations

---

## Acceptance Criteria

*From GDD Formula 3 + Rule 8/9 + AC-09:*

- [ ] `effective_drop_rate = clamp(base_drop_rate × product(multiplier for each matching condition), 0.0, 1.0)`
- [ ] Per-rarity base rates sourced from config: Common 0.70, Rare 0.25, Boss-grade 0.001, Prototype 0.05 (TR-part-016)
- [ ] Matching `drop_conditions` multipliers stack multiplicatively; all matching conditions evaluated
- [ ] Boss-grade boundary behavior: no conditions → 0.001 (NOT 0.0); ×500 → 0.5; ×999 → 0.999 (clamp does not trigger until exactly 1.0); ×1000 → 1.0 (TR-part-007 side)
- [ ] Prototype gradient: partial condition firing yields a partial rate, never all-or-nothing; 3× ×1.5 conditions → 0.05 × 1.5³ = 0.16875 (~17%, in the 15–20% band) (TR-part-017)
- [ ] Output always clamped to [0.0, 1.0] even when the raw product exceeds 1.0

---

## Implementation Notes

*Derived from GDD Formula 3:*

Pure function, e.g. `compute_effective_drop_rate(rarity, matching_conditions: Array[Dictionary]) -> float`. Look up `base_drop_rate` from the rarity→base config table (do NOT read a per-part base field — it does not exist). Fold the matching conditions' multipliers with a product, then `clamp(…, 0.0, 1.0)`. This function computes the *probability*; it does not draw against it — the RNG draw is the Drop System's, and this function must stay free of any `RandomNumberGenerator` call (keeps it trivially unit-testable and deterministic).

Note the multiplicative-formula invariant: `BASE_DROP_BOSS_GRADE` must be 0.001, never 0.00 (a zero base makes every multiplier inert). The ≥500 authoring *rule* (that every boss-grade part must carry such a condition) is enforced by the validator in Story 008 (AC-11) — this story only implements the math that makes ≥500 → 0.5.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: AC-11 validator (every Boss-grade part *has* a ≥500 condition) — content authoring rule
- Drop System epic: the RNG draw against this probability; Bernoulli-per-pool-part rolling; pity floor (EC-16); break-condition probability (DB3)
- Part-Break epic: `P(break_condition_fires)` — the upstream probability that a condition matches

---

## QA Test Cases

*Extracted from GDD AC-09 — exact where verified, tolerance where float-product.*

- **AC-1** (GDD AC-09 (a)(b)(c)): Boss-grade clamp boundaries
  - Given: a Boss-grade part (base 0.001)
  - When: no matching conditions; ×1000 condition; ×999 condition
  - Then: `0.001` (NOT 0.0); `1.0` (clamp of 0.001×1000); strictly `0.999` (NOT 1.0) — an implementation that rounds up before clamping fails the ×999 case
  - Edge cases: these three are verified-exact in IEEE 754 → strict `==` allowed

- **AC-2** (GDD AC-09 (d)): Rare multiplicative stack with tolerance
  - Given: Rare part (base 0.25), multipliers ×1.5 and ×1.3
  - When: `compute_effective_drop_rate`
  - Then: `abs(result − 0.4875) < 1e-9` — NOT strict `== 0.4875` (real value is `0.48750000000000004`)
  - Edge cases: any new float-product assertion uses tolerance

- **AC-3** (TR-part-017): Prototype gradient
  - Given: Prototype (base 0.05) with three ×1.5 conditions
  - When: 0, 1, 2, 3 conditions fire
  - Then: `0.05`, `0.075`, `~0.1125`, `0.16875` (~17%, within 15–20% band) — each step strictly increases; no all-or-nothing gate
  - Edge cases: use tolerance for the 2-condition case (float product)

- **AC-4**: Clamp above 1.0
  - Given: Common (base 0.70) with two favorable multipliers whose product exceeds 1.0/0.70
  - When: computed
  - Then: result is exactly `1.0` (clamped), never > 1.0
  - Edge cases: raw product > 1.0 must not leak through

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/part_database/drop_rate_formula_test.gd` — must exist and pass (boundaries, tolerance, gradient, clamp)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (`PartDef` supplies `rarity`, `drop_conditions`)
- Unlocks: Story 010 (content drop-condition authoring); Drop System epic consumes this probability
