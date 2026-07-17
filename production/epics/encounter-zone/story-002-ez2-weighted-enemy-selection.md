# Story 002: EZ-2 weighted enemy selection

> **Epic**: Encounter Zone System
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/encounter-zone.md`
**Requirement**: `TR-ez-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism
**ADR Decision Summary**: A fresh `RandomNumberGenerator` seeded from an injected int drives the weighted draw; never the global `randi()`. A fixed seed reproduces the exact enemy pick, which is what makes the boundary ACs testable.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: EZ-2 is pure integer arithmetic — `randi_range(1, total_weight)` (inclusive both ends) walked against a running cumulative with `roll <= cumulative`. No `floor/round/ceil`, no epsilon. The `[1, total]` inclusive range + `<=` walk is load-bearing: a `randi_range(0, total-1)` draw makes the last entry unreachable (AC-EZ-07), and a `roll < cumulative` walk misplaces every boundary (AC-EZ-05/06). Injected RNG mandatory.

**Control Manifest Rules (this layer)**:
- Required: pure core in `src/core/encounter_zone/`; injected `RandomNumberGenerator`; typed return (`StringName`).
- Forbidden: global `randi()`/`randf()`; `push_warning`/`push_error` from `src/`; content-def mutation.
- Guardrail: `total_weight` recomputed fresh each draw from the survivor set (no cached mutable weight state).

---

## Acceptance Criteria

*From GDD `design/gdd/encounter-zone.md`, scoped to this story:*

*Canonical fixture (all EZ-2 ACs): `iron_crawler`(w10, cum 10), `volt_drone`(w6, cum 16), `rust_hulk`(w4, cum 20); `total_weight = 20`; all WILD + `spawn_enabled` in stub Enemy DB.*

- [x] **AC-EZ-04** (BLOCKING, Unit): distribution. GIVEN the fixture and a freshly-seeded RNG (seed 99) created within the test, 10,000 draws, THEN iron_crawler ∈ [4750, 5250], volt_drone ∈ [2750, 3250], rust_hulk ∈ [1750, 2250]. Discriminator: a weight-ignoring uniform impl gives ~3333 each → fails all three bands.
- [x] **AC-EZ-05** (BLOCKING, Unit): boundary roll = **10** → `iron_crawler` (`<=` lower boundary). A `roll < cumulative` impl falls through to `volt_drone` — assert `iron_crawler`.
- [x] **AC-EZ-06** (BLOCKING, Unit): boundary roll = **16** → `volt_drone` (middle boundary). A `<` impl continues to `rust_hulk` — assert `volt_drone`.
- [x] **AC-EZ-07** (BLOCKING, Unit): boundary roll = **20** → `rust_hulk` (upper boundary). Catches the `randi_range(0, total−1)` off-by-one (max roll 19 would make `rust_hulk` unreachable) — assert on roll = 20 specifically.
- [x] **AC-EZ-08** (BLOCKING, Unit): interior rolls (regression baseline). Roll 7 → iron_crawler; 13 → volt_drone; 19 → rust_hulk.
- [x] **AC-EZ-09** (BLOCKING, Unit): single-entry pool. GIVEN `{iron_crawler, w1}`, `total_weight = 1`, `randi_range(1,1)` always 1, THEN returns `iron_crawler`, no error, no divide-by-zero.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

- Implement EZ-2 exactly per the GDD pseudocode: `total_weight = sum(e.spawn_weight for e in subpool)`; `roll = rng.randi_range(1, total_weight)`; walk `cumulative += e.spawn_weight; if roll <= cumulative: return e.enemy_id`. Use `randi_range(1, total_weight)` (inclusive), NOT `randi() % total` and NOT a `[0, …]` draw.
- The `subpool` passed here is the **already-filtered** survivor pool (Story 003 owns `filter_valid`); this story assumes clean, positive-weight entries. Keep the two concerns separate — EZ-2 walks, Story 003 filters.
- Typed `StringName` return. A trailing `return StringName("")` after the loop is required for a typed return even though it is unreachable with valid input (the empty-pool sentinel path is Story 003's).
- Do not special-case the single-entry pool — the general walk already returns the sole member at `roll = 1` (AC-EZ-09 proves no guard needed).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `filter_valid` exclusions (disabled/missing/wrong-class/weight≤0) and the empty-pool sentinel `StringName("")` + LogSink error. EZ-2 here receives a pre-filtered pool.
- Story 004: handing the selected `enemy_id` to TBC with WILD/BOSS context.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-EZ-04**: distribution.
  - Given: canonical 3-enemy fixture; a `RandomNumberGenerator` seeded 99 created inside the test.
  - When: 10,000 selections.
  - Then: counts fall in the three ±5–6σ bands.
  - Edge cases: a uniform impl (~3333 each) must fail — assert all three bands, not just one.
- **AC-EZ-05 / 06 / 07**: boundary rolls.
  - Given: canonical fixture; a mock RNG returning the exact roll (10, 16, 20 respectively).
  - When: one selection each.
  - Then: `iron_crawler`, `volt_drone`, `rust_hulk` respectively.
  - Edge cases: these three are the sole `<=`-vs-`<` and inclusive-range discriminators — assert each explicitly.
- **AC-EZ-08**: interior baseline.
  - Given: canonical fixture; mock RNG returning 7, 13, 19.
  - When: three selections.
  - Then: iron_crawler, volt_drone, rust_hulk.
- **AC-EZ-09**: single-entry.
  - Given: `{iron_crawler, w1}`; RNG (any).
  - When: one selection.
  - Then: `iron_crawler`; no error logged; no divide-by-zero.
  - Edge cases: assert `total_weight == 1` and `randi_range(1,1) == 1`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/encounter_zone/ez2_weighted_selection_test.gd` — must exist and pass.

**Status**: [x] Complete — `tests/unit/encounter_zone/ez2_weighted_selection_test.gd`, 6 tests, all green (GUT 9.7.1, Godot 4.7.stable). Covers AC-EZ-04 (10,000-draw seed-99 distribution), AC-EZ-05/06/07 (boundary rolls 10/16/20, three separate tests), AC-EZ-08 (interior 7/13/19), AC-EZ-09 (single-entry pool).

---

## Completion Notes (2026-07-17)

- Added `EncounterResolver.select_enemy(subpool) -> StringName` (EZ-2): `roll = randi_range(1, total_weight)` inclusive, walked `cumulative += spawn_weight; if roll <= cumulative: return enemy_id`. `total_weight` is recomputed fresh from the passed pool each call — no cached mutable weight state (Control Manifest guardrail).
- **The two load-bearing choices are both asserted by discriminating fixtures.** The `[1, total]` INCLUSIVE draw keeps the last entry reachable (AC-EZ-07 asserts roll 20 → `rust_hulk`; a `randi_range(0, total-1)` max of 19 would strand it). The `roll <= cumulative` walk lands every boundary on the correct entry (AC-EZ-05 roll 10 → `iron_crawler`, AC-EZ-06 roll 16 → `volt_drone`; a `<` walk falls through both). No single-entry special-case — the general walk returns the sole member at `roll = 1` (AC-EZ-09).
- **Int-RNG double.** Draws dispatch via `_rng.call(&"randi_range", from, to)` for the same ptrcall-override reason as `_draw_randf` (RNG-ptrcall memory). Added `tests/unit/encounter_zone/ez_rng_int_doubles.gd` (`QueuedInt`, overrides `randi_range` with `@warning_ignore("native_method_override")`, mirrors the Drop System float doubles). The `from`/`to` args are ignored — the scripted roll is asserted to sit in range by the caller. The distribution test (AC-EZ-04) uses a real seed-99 `RandomNumberGenerator` created inside the test (determinism per ADR-0006).
- EZ-2 assumes a CLEAN, positive-weight pre-filtered pool — `filter_valid` (disabled/missing/wrong-class/weight≤0) and the empty-pool sentinel are Story 003's. The trailing `return StringName("")` is an unreachable-with-valid-input typed-return guard, NOT the empty-pool path. No new global `class_name` (a method on the existing resolver), so the full suite rose by exactly +6 to **80 scripts / 814 tests / 4434 asserts**.

---

## Dependencies

- Depends on: Story 001 (value types + resolver host).
- Unlocks: Story 004 (WILD handoff selects via EZ-2).
