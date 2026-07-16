# Story 005: ContentValidator enemy stat-block family

> **Epic**: Enemy Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: `TR-edb-005` (WILD power cap ≤39), `TR-edb-006` (WILD power derivation proof), `TR-edb-011` (stat-key vocabulary + A/D range [0,110]), `TR-edb-012` (dead-data stat warn)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Same single ContentValidator, "extend never fork"; diagnostics via injected `LogSink`; this family extends `_validate_enemy_catalog` created in Story 004.

**Engine**: Godot 4.7 | **Risk**: LOW-MEDIUM (integer range checks + safe `Dictionary.get` access on the `stats` block; no floats)
**Engine Notes**: Read `stats` via `.get(key, <default>)` so a missing key is caught by the presence check (Story 004), never a hard index crash. The 11-stat vocabulary (TR-edb-011) is the allow-list; an unknown key → warning (typo guard). The dead-data keys (`cooling`, `energy_capacity`, `recharge` — enemies never consume energy/heat) must be authored `0`; non-zero → warning (TR-edb-012). Error codes: `content_enemy_stat_*`.

**Control Manifest Rules (this layer)**:
- Required: safe `.get` access on `stats`; range checks against GDD-sourced bounds; diagnostics via injected `LogSink` — source: ADR-0003
- Forbidden: `push_error`/`push_warning`; modifying sibling families; hardcoded bounds not traceable to the GDD — source: ADR-0002/0003
- Guardrail: file-size DoD trigger still applies (see Story 004)

---

## Acceptance Criteria

*From GDD AC-ED-05 + Rule (stat ranges), TR-edb-005/006/011/012:*

- [ ] **structure ≥ 1** (AC-ED-05): `structure == 0` or negative → error naming the id (a 0-structure enemy is un-fightable)
- [ ] **A/D/power ∈ [0, 110]** (AC-ED-05/TR-edb-011): armor, resist, and power outside `[0,110]` → error; boundary values `0` and `110` → no error
- [ ] **WILD power cap ≤ 39** (AC-ED-06/TR-edb-005): a `WILD` enemy with `power > 39` → error; a `BOSS` at `power = 40` → no error (cap is WILD-only)
- [ ] **Unknown stat key** (TR-edb-011, ADVISORY): a `stats` key outside the 11-stat vocabulary → warning naming the key (typo guard)
- [ ] **Dead-data stat** (TR-edb-012, ADVISORY): non-zero `cooling`/`energy_capacity`/`recharge` on an enemy → warning (enemies don't use these)
- [ ] Error codes: `content_enemy_stat_structure_invalid`, `content_enemy_stat_out_of_range`, `content_enemy_stat_wild_power_cap`, plus warn codes `content_enemy_stat_unknown_key`, `content_enemy_stat_dead_data`

---

## Implementation Notes

*Derived from ADR-0003 + the Part-DB stat-budget validator precedent:*

Add per-check methods to the Story-004 `_validate_enemy_catalog` family: `_check_enemy_stat_structure` (≥1), `_check_enemy_stat_ranges` (A/D/power ∈ [0,110]), `_check_enemy_wild_power_cap` (gated on `enemy_class == WILD`), `_check_enemy_stat_unknown_keys` (allow-list diff → warn), `_check_enemy_stat_dead_data` (warn). Pull the 11-stat vocabulary and the `[0,110]` / `≤39` bounds from the GDD Rule/Tuning tables — no invented numbers. **Boundary fixtures are mandatory**: `power=110` (pass), `power=111` (fail), `power=0` (pass), `structure=0` (fail), a WILD `power=40` (fail) vs a BOSS `power=40` (pass) — the WILD-vs-BOSS split is the discriminator that a class-blind cap impl fails.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: presence/type of the `stats` field itself (this story assumes the field exists and checks its *values*)
- Story 006: break-region math
- Story 008: TTK calibration (which *reads* armor/resist but is ADVISORY and lives there)

---

## QA Test Cases

- **AC-1** (AC-ED-05 structure): un-fightable guard
  - Given: `structure = 0`; `structure = 1`
  - When: validate
  - Then: 0 → error; 1 → no error
  - Edge cases: negative structure → error
- **AC-2** (AC-ED-05 ranges): boundary discrimination
  - Given: `power = 110`, `power = 111`, `armor = 0`, `resist = 120`
  - When: validate
  - Then: 110 & 0 → no error; 111 & 120 → error naming stat + id
  - Edge cases: a `< 110` (exclusive) impl wrongly rejects the legal 110 boundary
- **AC-3** (AC-ED-06 WILD power cap): class-aware cap
  - Given: a WILD enemy `power = 40`; a BOSS enemy `power = 40`
  - When: validate
  - Then: WILD → error; BOSS → no error
  - Edge cases: a class-blind impl wrongly errors the BOSS; WILD `power = 39` → no error
- **AC-4** (TR-edb-011/012 warnings): typo + dead-data
  - Given: a `stats` key `"powr"` (typo); `cooling = 12`
  - When: validate
  - Then: each → ADVISORY warning naming the key; a clean 11-stat block with dead-data all 0 → no warnings

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/enemy_stat_validator_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema), Story 004 (the `_validate_enemy_catalog` family + dispatch seam)
- Unlocks: Story 010 (authored rosters pass this stat validation)
