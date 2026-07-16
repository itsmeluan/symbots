# Story 003: Stacking-policy defaults by behavior_class

> **Epic**: Passive Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/passive-database.md`
**Requirement**: `TR-pdb-004` (stacking policy is derived from `behavior_class`, not authored freehand)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Content semantics live in the pure def/catalog tier; a single canonical mapping (one source of truth) drives derived fields so authored data and runtime resolution never diverge.

**Engine**: Godot 4.7 | **Risk**: LOW (pure enum→enum table; no engine API surface)
**Engine Notes**: A `behavior_class → StackingPolicy` default is a static lookup table (`const`/dict) — one authority the validator (Story 004) and any tooling both read. Per GDD Rule 4, `passive_class` does **not** participate — the default keys on `behavior_class` only.

**Control Manifest Rules (this layer)**:
- Required: Gameplay values are data-driven from a single source of truth; no magic numbers scattered across call sites — source: coding-standards / ADR-0003
- Forbidden: Deriving stacking from `passive_class` (that field is display metadata, Rule 4) — source: GDD Rule 4
- Guardrail: pure function / const table — no allocation, deterministic

---

## Acceptance Criteria

*From GDD Rule 4 + TR-pdb-004:*

- [ ] A canonical `behavior_class → StackingPolicy` default table exists as one source of truth:
  - `STATUS_RIDER → UNIQUE_PER_TRIGGER`
  - `STAT_AURA → UNIQUE`
  - `STRUCTURAL_EFFECT → UNIQUE`
  - `RESOURCE_EFFECT → STACKABLE`
- [ ] The default for every `BehaviorClass` value is defined (no gaps; INVALID/0 excluded)
- [ ] The derivation is a pure lookup (same input → same output, no side effects)

---

## Implementation Notes

*Derived from GDD Rule 4:*

Implement as a `const` dictionary or a small pure static function on `PassiveDef` (or a `PassiveRules` helper) — whichever mirrors how Move DB kept its band/tier tables. This table is the **default**; Story 004 uses it to validate that an authored `stacking_policy` matches the `behavior_class` default (an authoring guard — an author who sets a non-default policy is flagged). Keep the table adjacent to the schema so a future behavior_class addition forces a compile-visible gap. No runtime stacking *execution* here — that is TBC Rule 13 (dedup / STACKABLE accumulation).

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 004: the validator that *asserts* authored `stacking_policy` matches this default
- TBC epic: the runtime dedup / accumulation behaviour verified by AC-PDB-07 (UNIQUE_PER_TRIGGER fires once), AC-PDB-09 (UNIQUE applies once), AC-PDB-D3 (STACKABLE doubles). This story provides the *policy table* those runtime rules consume.

---

## QA Test Cases

- **AC-1** (TR-pdb-004): default table correctness
  - Given: the `behavior_class → StackingPolicy` default table
  - When: each `BehaviorClass` value is looked up
  - Then: `STATUS_RIDER→UNIQUE_PER_TRIGGER`, `STAT_AURA→UNIQUE`, `STRUCTURAL_EFFECT→UNIQUE`, `RESOURCE_EFFECT→STACKABLE`
  - Edge cases: every non-INVALID `BehaviorClass` has an entry (assert count == enum count − 1); the INVALID/0 sentinel maps to nothing / is excluded
- **AC-2**: purity/determinism
  - Given: the same `behavior_class`
  - When: looked up repeatedly
  - Then: identical `StackingPolicy` each time, no state mutation

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/passive_database/passive_stacking_policy_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (enums `BehaviorClass` / `StackingPolicy` must exist)
- Unlocks: Story 004 (validator asserts authored policy matches this default)
