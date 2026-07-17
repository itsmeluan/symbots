# Story 007: Beacon (×2.0) & DS-F-LEVEL rate injection

> **Epic**: Drop System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/drop-system.md`
**Requirement**: `TR-drop-011`, `TR-drop-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: RNG Service & Determinism (primary); ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: The Beacon (`beacon_multiplier = 2.0`) and DS-F-LEVEL `level_rarity_mult` are extra factors inside the DS-1 product before the `[0,1]` clamp; both feed the injected seeded roll (ADR-0006). The level band and part rarity are read from content (ADR-0003).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: This story supplies the non-trivial values for the two factors that Story 001 hosted as `1.0` defaults. `beacon_factor = 2.0` only on **VICTORY** when `beacon_used_this_battle`; it multiplies **part** rates, never the consumable channel. `level_rarity_mult = LEVEL_RARITY_MULTS[level_band(enemy.level)][rarity]` — **only Rare is scaled** (EARLY 0.5 / MID 1.0 / HIGH 1.5); Common/Boss-grade/Prototype rows are all 1.0. `level_band`: `< LEVEL_BAND_MID_FLOOR(3)` = EARLY, `< LEVEL_BAND_HIGH_FLOOR(6)` = MID, else HIGH. All listed products are exact in IEEE 754 — no epsilon. The Prototype all-1.0 row is load-bearing for DS-2's `N_PROTO_PITY` calibration — do not scale it.

**Control Manifest Rules (this layer)**:
- Required: pure core; injected seeded RNG; the observable `beacon_drop_multiplier_applied` flag set on VICTORY-with-Beacon; level band + rarity read read-only from content.
- Forbidden: global `randf()`; applying the Beacon to the consumable channel; scaling the Prototype `level_rarity_mult` row; content-enum reordering.
- Guardrail: a pity-guaranteed part ignores the Beacon (guarantee is pre-roll — the Beacon changes odds, not pity bookkeeping).

---

## Acceptance Criteria

*From GDD `design/gdd/drop-system.md`, scoped to this story:*

- [ ] **AC-DS-31** (BLOCKING, Unit): Salvage Beacon injection (Rule 12a) **+ DS-F-LEVEL level factor** (ELZS erratum). Rare part base 0.25, no conditions.
  - **Scenario A** (Beacon, MID band): `beacon_used_this_battle = true`, enemy level 4 (MID, mult 1.0) → rate = clamp(0.25 × 1.0 × 2.0) = **0.50**; draw 0.40 (< 0.50) → drops, `beacon_drop_multiplier_applied == true`. Discriminator: a no-injection impl uses 0.25 and does **not** drop at 0.40.
  - **Scenario A2** (Beacon, HIGH band — DS-F-LEVEL discriminator): `beacon_used_this_battle = true`, enemy level 6 (HIGH, mult 1.5) → rate = clamp(0.25 × 1.5 × 2.0) = **0.75**; draw 0.60 (< 0.75) → drops. Discriminator: an impl wiring Beacon but ignoring `level_rarity_mult` returns 0.50, so 0.60 ≥ 0.50 → does not drop — caught.
  - **Scenario B** (flee, no injection): `beacon_used_this_battle = true`, outcome `FLED` → awards nothing, `beacon_drop_multiplier_applied == false` (Rule 1 victory-only).
  - **Scenario C** (clamp): Common base 0.70 with Beacon → clamp(0.70 × 1.0 × 2.0) = **1.0** (guaranteed; Common mult always 1.0).
  - **Scenario D** (pity-guaranteed ignores Beacon): a pity-guaranteed part with Beacon active drops exactly once and the multiplier is not applied to a rate (guarantee is pre-roll, Rule 12b).
  - FAIL: A no drop at 0.40 (Beacon missing); A2 drops at 0.60 with impl ignoring level factor; B applies the multiplier or awards on flee; the Beacon boosts the consumable channel; D double-drops or applies the multiplier to a guaranteed part.

---

## Implementation Notes

*Derived from ADR-0006 + ADR-0003 Implementation Guidelines:*

- Replace Story 001's `1.0` defaults with the real factors inside the DS-1 product, before the clamp: `effective_drop_rate = clamp(base × level_rarity_mult × Π(conditions) × beacon_factor, 0, 1)`.
- `beacon_factor = BEACON_MULTIPLIER (2.0)` when `beacon_used_this_battle == true` **and** outcome is VICTORY; else 1.0. On VICTORY-with-Beacon set the observable `beacon_drop_multiplier_applied = true`; on flee/loss the Beacon is spent with no effect and the flag stays `false` (AC-DS-31 B).
- `level_rarity_mult = LEVEL_RARITY_MULTS[level_band(enemy.level)][rarity(p)]`, with `level_band` parameterized by `LEVEL_BAND_MID_FLOOR = 3` / `LEVEL_BAND_HIGH_FLOOR = 6`. Only the Rare column varies (0.5 / 1.0 / 1.5); all other rarity rows are 1.0 (AC-DS-31 A2/C). Do not scale the Prototype row (DS-2 calibration depends on it).
- The Beacon multiplies **part** rates only — never the separate consumable channel (Rule 12).
- A pity-guaranteed part (Stories 004/005) is resolved pre-roll and is unaffected by the Beacon: it drops exactly once and no multiplier is applied to any rate (AC-DS-31 D). Its pity counter advances/resets on the post-Beacon outcome exactly as an unboosted roll would.
- **Production interface obligation (AC-ELZS-11 Done condition, DS-F-LEVEL section):** document which class owns `effective_drop_rate()` and whether it accepts `enemy_level: int` directly (resolving the mult internally) or a pre-computed mult — AC-ELZS-11's integration fixtures bind to whichever form is documented. That integration test (`tests/integration/drop_system/`) is the ELZS erratum's Done gate; this story's unit AC-DS-31 covers the injection math.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the DS-1 clamp/roll shape with 1.0-default factors (this story fills in the real values).
- Story 002: condition multiplier assembly (the `Π(conditions)` factor).
- Stories 004/005: the pity systems (this story only asserts a guaranteed part *ignores* the Beacon).
- **Deferred:** AC-ELZS-11's full DS-F-LEVEL **integration** test is the ELZS erratum story's Done gate (cross-system) — this story delivers the unit-level injection (AC-DS-31) that it builds on.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these. Unit test with injected seeded RNG + a battle-context stub exposing `beacon_used_this_battle` and `enemy.level`.*

- **AC-DS-31 A**: Beacon MID.
  - Given: Rare 0.25, Beacon on, level 4, draw 0.40.
  - Then: rate 0.50, drops, `beacon_drop_multiplier_applied == true`.
  - Edge cases: no-injection impl (0.25) fails.
- **AC-DS-31 A2**: Beacon HIGH (level factor).
  - Given: Rare 0.25, Beacon on, level 6, draw 0.60.
  - Then: rate 0.75, drops.
  - Edge cases: level-ignoring impl (0.50) fails at 0.60.
- **AC-DS-31 B**: flee.
  - Given: Beacon on, outcome FLED.
  - Then: nothing awarded, flag == false.
- **AC-DS-31 C**: clamp.
  - Given: Common 0.70, Beacon on.
  - Then: rate clamps to 1.0 (guaranteed).
- **AC-DS-31 D**: guaranteed ignores Beacon.
  - Given: a pity-guaranteed part, Beacon on.
  - Then: drops exactly once; multiplier not applied to a rate.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/drop_system/beacon_level_injection_test.gd` — must exist and pass. (The DS-F-LEVEL cross-system integration gate AC-ELZS-11 lives in `tests/integration/drop_system/` and is owned by the ELZS erratum Done condition.)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DS-1 factor slots) + Story 005 (a pity-guaranteed part for Scenario D; Story 004 equally supplies one).
- Unlocks: None (feeds the deferred AC-ELZS-11 integration gate).
