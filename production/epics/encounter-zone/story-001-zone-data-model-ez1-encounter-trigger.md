# Story 001: Zone data model & EZ-1 encounter trigger

> **Epic**: Encounter Zone System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/encounter-zone.md`
**Requirement**: `TR-ez-001`, `TR-ez-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism (primary); ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: A fresh `RandomNumberGenerator` is seeded from an injected int and passed into the resolution unit — never the global `randf()`; `src/core/` stays pure. Zone/terrain/spawn definitions are typed `.tres`-backed value objects read through the content catalog, never mutated at runtime.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: EZ-1 is a pure float comparison (`rng.randf() < effective_rate`); `randf()` is half-open `[0.0, 1.0)` on 4.7 as on prior versions — the `rate = 1.0 → always triggers` / `rate = 0.0 → never triggers` boundaries depend on that half-openness. Injected RNG is mandatory: without it the `<` boundary discriminator (AC-EZ-03) is unreachable. No `floor()/round()/ceil()` in EZ-1 — no epsilon nudge, no float scan required.

**Control Manifest Rules (this layer)**:
- Required: pure formula core in `src/core/encounter_zone/`; DI `RefCounted` owner (not an autoload); randomness injected as `seed: int` / `RandomNumberGenerator`; diagnostics routed through an injected LogSink (`warn(code, detail)`).
- Forbidden: global `randf()`/`randi()`; constructing `RngService` from inside `src/core/`; `push_warning()`/`push_error()` from `src/`; runtime mutation or `duplicate()` of content defs; content-enum reordering.
- Guardrail: turn-based, no per-frame polling — resolution is called on a step event, not `_process`.

---

## Acceptance Criteria

*From GDD `design/gdd/encounter-zone.md`, scoped to this story:*

- [ ] **AC-EZ-01** (BLOCKING, Unit): `encounter_rate = 0.0` never triggers. GIVEN rate 0.0 and any seed, WHEN EZ-1 runs 10,000 steps, THEN `triggered == false` every step.
- [ ] **AC-EZ-02** (BLOCKING, Unit): legal rate boundaries + out-of-range clamping *(verifies EC-EZ-05)*. **A:** rate 1.0, 10,000 steps → triggers every step. **B:** rate 1.5 → content error logged, effective rate clamped to 1.0. **C:** rate −0.3 → error logged, clamped to 0.0, never triggers. The content-error log is the observable proving clamping.
- [ ] **AC-EZ-03** (BLOCKING, Unit): `<` operator discrimination via injected draws. GIVEN a mock RNG returning scripted draws `[0.14, 0.15, 0.16]` at rate 0.15, THEN `triggered == [true, false, false]`. The `0.15` draw is the discriminator: strict `<` yields `false` (a `<=` impl yields `true`).
- [ ] **AC-EZ-59** (BLOCKING, Unit): EZ-1 encounter-rate modifier hook. **A (Jammer):** rate 0.15, `active_modifier = 0.1` → `effective_rate == 0.015` (exact); a draw of `0.10` → `triggered == false`, where base 0.15 would have fired (0.10 < 0.15) — the single draw discriminates hook-applied vs hook-ignored. **B (Lure, no clamp):** rate 0.35, `active_modifier = 2.5` → `effective_rate == 0.875` (exact, NOT clamped to 1.0). **C (identity):** no modifier → `active_modifier == 1.0`, base EZ-1 unchanged. **D (clamp ceiling):** rate 0.5, `active_modifier = 2.5` → `clamp(1.25) == 1.0`. `0.15×0.1`, `0.35×2.5` exact in IEEE-754 — no epsilon.
- [ ] **AC-EZ-57** (BLOCKING, Unit): zone-level `spawn_enabled == false` → all patches inert (Rule 1 / EC-EZ-10). GIVEN a zone `spawn_enabled = false` with a valid populated terrain patch, WHEN a step is taken, THEN EZ-1 never rolls, EZ-2 is never called, no `enemy_id` resolved, no crash. Discriminator: an impl checking only enemy-level `spawn_enabled` still triggers — assert zero encounters.

---

## Implementation Notes

*Derived from ADR-0006 + ADR-0003 Implementation Guidelines:*

- Define the value types in `src/core/encounter_zone/`: `ZoneDef` (`zone_id`, `display_name`, `terrain_patches: Array[TerrainPatch]`, `boss_encounters: Array[BossEncounter]`, `spawn_enabled: bool`, `enemy_level_floor: int`, `enemy_level_roof: int`), `TerrainPatch` (`terrain_type` enum, `enemy_subpool: Array[SpawnEntry]`, `encounter_rate: float`, `density_class` enum), `SpawnEntry` (`enemy_id: StringName`, `spawn_weight: int`, `is_farmable_target: bool = false`), and the `BossEncounter` shape (fields filled by Stories 005–007). Match the Rule 1/2/6 schema tables exactly; do not reorder enum members.
- The resolution host is a DI `RefCounted` (e.g. `EncounterResolver`) constructed with an injected `RandomNumberGenerator`, a LogSink, and an Enemy-DB reader interface — no autoload, no global RNG, no `RngService` construction inside core.
- EZ-1: `effective_rate = clampf(encounter_rate * active_modifier, 0.0, 1.0)`, then `triggered = rng.randf() < effective_rate`. `active_modifier` is a passed-in parameter (default `1.0`); Encounter Zone reads it, never stores it. Out-of-range **authored** `encounter_rate` (< 0 or > 1) is a content error logged via LogSink and clamped (AC-EZ-02 B/C) — distinct from the *modifier* clamp (AC-EZ-59 D).
- Zone-level `spawn_enabled == false` short-circuits before EZ-1: the resolver returns "no encounter" without rolling and without touching EZ-2 (AC-EZ-57).
- Route every diagnostic through the injected LogSink `warn(code, detail)`; never `push_warning`/`push_error` from `src/`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: EZ-2 weighted enemy selection (the cumulative-weight walk).
- Story 003: sub-pool validity filtering & empty-pool sentinel.
- Stories 005–007: boss-gate evaluation, sequencing, repeat policy, gate-param validation (only the `BossEncounter` field shapes are declared here).
- Story 008: content-validation linters (density-band rates, MVP scope counts, terrain identity).
- **Deferred integration (not this story, not any MVP story):** live Overworld Navigation step-driving of EZ-1 (AC-EZ-41), and the `active_modifier` originating from a live consumable/traversal context (AC-EZ-59 exercises the hook with the modifier passed in directly).

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-EZ-01**: rate-0 never fires.
  - Given: `ZoneDef` with one patch at `encounter_rate = 0.0`, `spawn_enabled = true`; a seeded `RandomNumberGenerator`.
  - When: EZ-1 evaluated 10,000 steps.
  - Then: `triggered == false` on every step.
  - Edge cases: repeat with two different seeds — still all-false.
- **AC-EZ-02**: rate boundaries + clamp.
  - Given: patches at rates 1.0, 1.5, −0.3; a spy LogSink.
  - When: EZ-1 evaluated (10,000 steps at 1.0; ≥1 step at 1.5 and −0.3).
  - Then: 1.0 → triggers every step; 1.5 → LogSink error recorded, behaves as 1.0; −0.3 → LogSink error recorded, never triggers.
  - Edge cases: assert the error `code`/`detail` names the out-of-range value.
- **AC-EZ-03**: `<` discrimination.
  - Given: a mock RNG scripted to return `[0.14, 0.15, 0.16]`; patch rate 0.15.
  - When: EZ-1 evaluated three steps.
  - Then: `[true, false, false]`.
  - Edge cases: the `0.15` step is the sole `<` vs `<=` discriminator — assert `false` explicitly.
- **AC-EZ-59**: modifier hook.
  - Given: seeded/mock RNG; `active_modifier` passed per scenario.
  - When: EZ-1 evaluated with the scenario's rate + modifier.
  - Then: A → `effective_rate == 0.015` and the `0.10` draw yields `false`; B → `effective_rate == 0.875` (assert not 1.0); C → `active_modifier == 1.0` reproduces base EZ-1; D → `effective_rate == 1.0`.
  - Edge cases: assert `0.15*0.1` and `0.35*2.5` with `is_equal_approx` tolerance ≤ 1e-9 (products are exact).
- **AC-EZ-57**: zone inert.
  - Given: `ZoneDef.spawn_enabled = false` with a valid populated patch; spy EZ-1/EZ-2.
  - When: a step is taken on that patch.
  - Then: EZ-1 roll count == 0, EZ-2 call count == 0, no resolved `enemy_id`, no crash.
  - Edge cases: enemy-level `spawn_enabled` still `true` in the patch — proves the guard is zone-level, not enemy-level.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/encounter_zone/ez1_encounter_trigger_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (anchor story — establishes the value types + resolver host all other stories build on).
- Unlocks: Story 002, Story 003, Story 005, Story 008.
