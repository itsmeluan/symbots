# Story 009: ContentValidator ELZS progression-field family (level / xp_value / completion_bonus_xp)

> **Epic**: Enemy Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/enemy-database.md` (ELZS erratum fields) — cross-refs `design/gdd/` ELZS `AC-ELZS-01/02`
**Requirement**: `TR-edb-015` (xp_value stored-equals-derived, CP-F4), `TR-edb-016` (completion_bonus_xp rules), `TR-edb-017` (level range)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Same single ContentValidator, "extend never fork"; this family extends `_validate_enemy_catalog`. The `xp_value` stored-equals-derived check mirrors the Part-DB CP-F4 pattern (store the derived value, validator re-derives and asserts equality).

**Engine**: Godot 4.7 | **Risk**: LOW-MEDIUM (CP-F4 is `(35 + level × 10) × role_mult` — a small integer/float chain; if `role_mult` is fractional, python3-verify the rounding rule so stored-equals-derived is exact)
**Engine Notes**: The Enemy schema *stores* the ELZS progression fields (Story 001) and this family *validates* them. `level ∈ [1, 10]` (TR-edb-017). `xp_value == derive_xp_value(level, role)` per CP-F4 `(35 + level × 10) × role_mult` (TR-edb-015) — reuse/import the ELZS formula owner, do NOT re-implement it here (single source of truth, same discipline as Story 006↔003). `completion_bonus_xp ≥ 0` and **zero unless the enemy is a BOSS** (TR-edb-016) — the one-time zone-completion bonus is a boss-only reward vector. Error codes: `content_enemy_progression_*`.

**Control Manifest Rules (this layer)**:
- Required: import the ELZS CP-F4 formula (no re-implementation); level range + completion-bonus rules from the GDD; diagnostics via injected `LogSink` — source: ADR-0003 / ELZS CP-F4
- Forbidden: re-deriving CP-F4 inline; allowing non-zero `completion_bonus_xp` on a non-BOSS; `push_error`/`push_warning` — source: ADR-0003 / GDD
- Guardrail: file-size DoD trigger still applies (see Story 004)

---

## Acceptance Criteria

*From ELZS AC-ELZS-01/02 realized in the Enemy schema, TR-edb-015/016/017:*

- [x] **level range** (TR-edb-017): `level < 1` or `level > 10` → error naming the id; `1` and `10` boundaries → no error — `enemy_validator.gd:_check_enemy_level_range`, tests `test_level_*`
- [x] **xp_value stored == derived** (TR-edb-015, CP-F4): authored `xp_value` ≠ `derive_xp_value(level, role)` → error naming id + both values; a correctly-authored value → no error — `XpRewardFormula.derive_xp_value` (single formula home) + `_check_enemy_xp_value`, tests `test_xp_value_*`
- [x] **completion_bonus_xp ≥ 0** (TR-edb-016): negative → error — `_check_enemy_completion_bonus`, `test_completion_bonus_negative_errors`
- [x] **completion_bonus_xp BOSS-only** (TR-edb-016): a non-BOSS with `completion_bonus_xp > 0` → error; a BOSS with a positive bonus → no error; any enemy with `0` → no error — `_check_enemy_completion_bonus`, tests `test_completion_bonus_*`
- [x] Error codes: `content_enemy_progression_level_range`, `content_enemy_progression_xp_mismatch`, `content_enemy_progression_bonus_negative`, `content_enemy_progression_bonus_non_boss`

---

## Implementation Notes

*Derived from ADR-0003 + ELZS CP-F4 + the Part-DB stored-equals-derived precedent:*

Add to the Story-004 family: `_check_enemy_level_range`, `_check_enemy_xp_value` (import the ELZS `derive_xp_value`/CP-F4 owner — if it doesn't yet exist as a shared function, that's a seam: implement the derivation in the ELZS formula home and call it, do NOT paste the math into the validator), `_check_enemy_completion_bonus` (≥0 AND zero-unless-BOSS). python3-verify the CP-F4 fixtures if `role_mult` is fractional so the stored-equals-derived compare is exact (same epsilon discipline as EDB-1). Discriminating fixtures: a non-BOSS with `completion_bonus_xp = 5` (error — the BOSS-only rule) vs a BOSS with `= 5` (ok); a `level = 0` and `level = 11` (both error) vs `1`/`10` (both ok); an `xp_value` off by the `role_mult` factor (catches a wrong-role or no-multiplier impl).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The ELZS epic itself: the CP-F4 formula *home*, XP *award* at battle-end, and core-level progression (this story only validates the Enemy schema's *stored* progression fields)
- Story 004: presence/type of these fields (this story checks their *values/ranges*)
- Story 008: pacing/TTK (a different advisory dimension)

---

## QA Test Cases

- **AC-1** (TR-edb-017 level range): boundary
  - Given: `level = 0`, `level = 1`, `level = 10`, `level = 11`
  - When: validate
  - Then: 0 & 11 → error; 1 & 10 → no error
  - Edge cases: an exclusive-bound impl wrongly rejects 1 or 10
- **AC-2** (TR-edb-015 xp stored == derived): CP-F4 parity
  - Given: `level = 3, role = <mult>` with the correctly-derived `xp_value`; the same with a value off by the `role_mult`
  - When: validate
  - Then: correct → no error; off → error naming id + both values
  - Edge cases: python3-verify the derived integer; a no-multiplier impl passes the wrong value
- **AC-3** (TR-edb-016 completion bonus): sign + BOSS-only
  - Given: a non-BOSS `completion_bonus_xp = 5`; a BOSS `= 5`; a non-BOSS `= 0`; any `= -1`
  - When: validate
  - Then: non-BOSS-positive → error; BOSS-positive → no error; zero → no error; negative → error
  - Edge cases: a class-blind impl wrongly passes the non-BOSS positive bonus

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/enemy_progression_validator_test.gd` — must exist and pass

**Status**: [x] Created — 11 test functions, all green. Full suite 623/623 passing (+11 this story; sibling enemy fixtures across schema/stat/break/loot/density tests updated to author CP-F4-valid `level`/`xp_value`). CP-F4 lives in a new shared formula home `src/core/content/xp_reward_formula.gd` (`XpRewardFormula.derive_xp_value`) — the validator imports it (no re-implementation, mirroring EDB-1's `BreakHpFormula`). Pure integer arithmetic (WILD ×1, BOSS ×2) — no epsilon; boundary xp values python3-verified (WILD lvl3=65, BOSS lvl3=130).

---

## Dependencies

- Depends on: Story 001 (schema stores the ELZS fields), Story 004 (`_validate_enemy_catalog` family), ELZS CP-F4 formula owner (imported — implement the shared derivation there if absent)
- Unlocks: Story 010 (authored progression fields pass), ELZS epic (consumes the validated per-enemy XP data)
