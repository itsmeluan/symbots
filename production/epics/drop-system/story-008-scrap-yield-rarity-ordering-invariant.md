# Story 008: Scrap yield & rarity-ordering invariant

> **Epic**: Drop System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Per-rarity Scrap yields are data-driven constants exposed through a typed accessor; the rarity-ordering invariant (`COMMON < RARE < PROTOTYPE < BOSS_GRADE`) is a hard build-failing guard, never inverted.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: A `get_scrap_yield(rarity) -> int` accessor over four constants (owned per Rule 9; the source side of the scrap sink). The ordering invariant is asserted **programmatically** (three boolean comparisons), not in prose — an inverted step must fail the test. Values are `@export` defaults on the balance config, not hardcoded literals in logic (per the balance-config discipline). Note the ordering is **not** numeric-rarity-index order: PROTOTYPE yield (35) sits between RARE (20) and BOSS_GRADE (60) deliberately.

**Control Manifest Rules (this layer)**:
- Required: yields sourced from the balance config (`@export` defaults), read read-only; the ordering invariant enforced as an assertion.
- Forbidden: hardcoded yield literals inside logic; content-enum reordering; runtime mutation of the yield table.
- Guardrail: `COMMON < RARE < PROTOTYPE < BOSS_GRADE` supersedes the individual safe ranges — no legal retune may invert it.

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [ ] **AC-DS-19** (BLOCKING, Unit): Scrap yield per rarity + ordering invariant *(verifies R9)*. VALUE assertions (four, exact): `get_scrap_yield(COMMON) == 5`, `get_scrap_yield(RARE) == 20`, `get_scrap_yield(PROTOTYPE) == 35`, `get_scrap_yield(BOSS_GRADE) == 60`. ORDERING assertions (three explicit booleans, evaluated programmatically): `get_scrap_yield(COMMON) < get_scrap_yield(RARE)`; `get_scrap_yield(RARE) < get_scrap_yield(PROTOTYPE)`; `get_scrap_yield(PROTOTYPE) < get_scrap_yield(BOSS_GRADE)`. FAIL: any value wrong, or any ordering assertion false (an inverted step — e.g. Prototype ≥ Boss-grade — rewards scrapping the rarer part).

---

## Implementation Notes

*Derived from ADR-0003 Implementation Guidelines:*

- Expose `get_scrap_yield(rarity) -> int` backed by the balance config's per-rarity Scrap yield constants: Common 5, Rare 20, Prototype 35, Boss-grade 60 (Tuning Knobs). These are `@export` defaults on the balance config, not literals in the accessor.
- Assert the four exact values AND the three ordering booleans programmatically (AC-DS-19). The ordering invariant is the load-bearing guard: it must be evaluated as `<` comparisons, not documented in a comment.
- The Scrap **yield** (source) is owned here; the player-initiated scrap **action** is Inventory's (AD-4, deferred — Advisory), and the sink (material-gated upgrading) is Workshop's. This story implements only the yield accessor + invariant.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The player-initiated scrap action + batch-scrap UX (Inventory, AD-4, deferred).
- The Scrap sink / upgrade-cost curve (Part Upgrade / Workshop, Not Started).
- The drop-roll pity/emit path (Stories 001–007) — Scrap yield is independent of the roll pass.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-DS-19**: yields + ordering.
  - Given: `get_scrap_yield` over all four rarities.
  - Then: values 5 / 20 / 35 / 60 exactly.
  - Then: `COMMON < RARE`, `RARE < PROTOTYPE`, `PROTOTYPE < BOSS_GRADE` all true (evaluated programmatically).
  - Edge cases: any inverted step (e.g. Prototype ≥ Boss-grade) fails the build.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/drop_system/scrap_yield_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (the DropSystem host that exposes the accessor).
- Unlocks: None.
