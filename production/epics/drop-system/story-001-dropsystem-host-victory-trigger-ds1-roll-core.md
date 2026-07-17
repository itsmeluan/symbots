# Story 001: DropSystem host, VICTORY-only trigger & DS-1 roll core

> **Epic**: Drop System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-004`, `TR-drop-010`, `TR-drop-001` (partial)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism (primary); ADR-0002: Event Bus & Signal Architecture; ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: The roll draws from an injected, seeded `RandomNumberGenerator` and `src/core` stays pure (ADR-0006). The system consumes the 8-field COMBAT `battle_ended` and resolves **only on VICTORY**; diagnostics go through an injected LogSink (ADR-0002). Per-rarity base rates are read read-only through the typed Part-DB catalog (ADR-0003).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Pure core in `src/core/drop_system/`, a DI `RefCounted` host — no autoload, no scene. Randomness is an injected `RandomNumberGenerator` (never global `randf()`). Float assertions use `abs(x − expected) < 1e-9`; the DS-1 comparison is **strict `<`** (`randf()` returns `[0.0, 1.0)`). Build the **canonical DS-1** shape now with `level_rarity_mult` and `beacon_factor` present as factors defaulting to `1.0` — Story 007 supplies their non-trivial values. Do NOT code the `base × Π(conditions)` form alone (it structurally cannot host DS-F-LEVEL / Beacon later).

**Control Manifest Rules (this layer)**:
- Required: pure core in `src/core/drop_system/`; injected seeded RNG (`RandomNumberGenerator`); diagnostics via LogSink `warn(code, detail)`; content defs read-only via the injected catalog.
- Forbidden: global `randf()`/`randi()`; `RngService` referenced from `src/core/`; `push_warning`/`push_error` from `src/`; runtime content-def mutation/`duplicate()`.
- Guardrail: single synchronous resolution pass triggered by `battle_ended(VICTORY, …)` — no runtime state machine.

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [ ] **AC-DS-03** (BLOCKING, Unit): rate > 1.0 pre-clamp guarantees the drop *(verifies EC-DS-04)*. Common `scrap_bolt` (0.70), `arm_broken`(×1.5)+`targeting_active`(×1.3) fired (product 1.365 → clamp 1.0). Draw 0.001 → drops; draw 0.99 → drops; `effective_drop_rate == 1.0` both. FAIL: returned unclamped 1.365, or drop false for any draw < 1.0.
- [ ] **AC-DS-04** (BLOCKING, Unit): strict-`<` boundary — the canonical `<` vs `<=` discriminator. Rare `servo_arm`, rate 0.25. Draw 0.25 → `false` (0.25 not < 0.25); draw 0.24 → `true`. FAIL: draw 0.25 returns true (indicates `<=`).
- [ ] **AC-DS-05** (BLOCKING, Unit): no conditions fired → base rates *(verifies EC-DS-01)*. Pool [Common 0.70, Rare 0.25, Boss-grade 0.001], empty fired set, draws (ID-asc) 0.65/0.20/0.0005 → all drop at base. Boss-grade draw 0.002 → no drop (0.002 ≥ 0.001). FAIL: conditions applied on empty set; Boss-grade treated as rate 0.0.
- [ ] **AC-DS-11** (BLOCKING, Unit): victory-only gate. `scrap_bolt`, RNG always 0.65 (< 0.70). VICTORY → one emit; DEFEAT → zero emits, RNG not called; FLED → zero emits, RNG not called. FAIL: non-VICTORY drops; VICTORY zero despite 0.65 < 0.70.
- [ ] **AC-DS-20** (BLOCKING, Unit): instances emitted at `upgrade_tier = 0` for all rarities *(verifies R8)*. One part per rarity (`armor_bolt` Common 0.70, `core_shield` Prototype 0.05, `forge_core` Boss-grade 0.001, `servo_arm` Rare 0.25); draws ID-asc [0.0009, 0.0009, 0.0009, 0.0009] (all < 0.001, tightest strict-`<` boundary) → 4 instances, each `upgrade_tier == 0`. FAIL: any tier ≠ 0; Boss-grade fails to drop at 0.0009.
- [ ] **AC-DS-27** (BLOCKING, Unit): Phase-6 output list contract. Pool `servo_arm` (Rare 0.25), no conditions, draw 0.20 (< 0.25) → resolution returns a list with exactly one `PartInstance{part_id: 'servo_arm', upgrade_tier: 0}`. FAIL: list null/empty; wrong part_id; tier ≠ 0.

---

## Implementation Notes

*Derived from ADR-0006 + ADR-0002 + ADR-0003 Implementation Guidelines:*

- Create the `DropSystem` `RefCounted` in `src/core/drop_system/` with constructor injection: seeded `RandomNumberGenerator`, LogSink, Part-DB reader (base rates + `drop_conditions`/`rarity`/`drop_enabled`), Enemy-DB loot-pool reader, Inventory sink interface.
- Resolution is a single synchronous pass entered only on `battle_ended(outcome == VICTORY, enemy_id, fired_break_events)`. `DEFEAT`/`FLED` return immediately with zero emits and no RNG call (AC-DS-11).
- **Canonical DS-1** per rolled part: `effective_drop_rate = clamp(base_drop_rate[rarity] × level_rarity_mult × Π(matching condition mults) × beacon_factor, 0, 1)`. In this story `level_rarity_mult = 1.0` and `beacon_factor = 1.0` (Story 007 replaces the defaults). Roll: `drops = pity_guaranteed OR (rng.randf() < effective_drop_rate)` — **strict `<`** (AC-DS-04). `pity_guaranteed` is always `false` here (pity is Stories 004/005).
- Clamp is `clamp(..., 0, 1)` → a product > 1.0 becomes 1.0 → always drops since `randf() < 1.0` (AC-DS-03).
- Each successful roll instantiates a **new** part instance at `upgrade_tier = 0` and hands it to the Inventory sink; the resolution also returns the Phase-6 drop list (AC-DS-20/27).
- Roll parts in **ID-ascending order** — the full ordering/determinism proof is Story 006, but establish the sorted iteration here so later stories inherit it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: condition exact-match, multiplicative stacking, unknown-key tolerance (this story evaluates the clamp/roll with an already-assembled multiplier product).
- Story 003: unique-ID dedup, pool-dilution independence, empty/disabled-pool handling.
- Stories 004/005: the two pity systems (`pity_guaranteed` is hard-`false` here).
- Story 006: the full ID-ascending order + reproducibility proof.
- Story 007: non-trivial `level_rarity_mult` / `beacon_factor` values (they are 1.0 defaults here).
- Story 008: Scrap yield.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these. Stub the RNG by subclassing `RandomNumberGenerator` and overriding `randf()` to return the stated draw.*

- **AC-DS-03**: pre-clamp > 1.0.
  - Given: Common `scrap_bolt` 0.70, `arm_broken`+`targeting_active` fired (product 1.365).
  - Then: `effective_drop_rate == 1.0`; draws 0.001 and 0.99 both drop.
  - Edge cases: assert rate not returned as 1.365.
- **AC-DS-04**: strict-`<`.
  - Given: Rare `servo_arm` 0.25.
  - Then: draw 0.25 → false; draw 0.24 → true.
  - Edge cases: 0.25 exactly representable — a `<=` impl returns true and fails.
- **AC-DS-05**: base rates on empty set.
  - Given: pool [0.70, 0.25, 0.001], empty fired set, draws 0.65/0.20/0.0005.
  - Then: all drop; then Boss-grade draw 0.002 → no drop.
  - Edge cases: Boss-grade must be ~0.001, never 0.0.
- **AC-DS-11**: victory-only gate.
  - Given: `scrap_bolt`, RNG always 0.65.
  - Then: VICTORY → 1 emit; DEFEAT → 0 emits + RNG uncalled; FLED → 0 emits + RNG uncalled.
- **AC-DS-20**: tier=0 all rarities.
  - Given: one part per rarity, draws all 0.0009.
  - Then: 4 instances, each `upgrade_tier == 0`.
  - Edge cases: 0.0009 < 0.001 must drop; 0.001 would not (strict `<`).
- **AC-DS-27**: Phase-6 list.
  - Given: `servo_arm` 0.25, draw 0.20.
  - Then: returned list has exactly one `PartInstance{part_id:'servo_arm', upgrade_tier:0}`.
  - Edge cases: assert not null/empty, correct part_id.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/drop_system/ds1_roll_core_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (anchor).
- Unlocks: Stories 002, 003, 004, 005, 008 (all build on the host + DS-1 roll loop).
