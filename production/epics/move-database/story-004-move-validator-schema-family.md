# Story 004: Move schema-validation family

> **Epic**: Move Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/move-database.md`
**Requirement**: `TR-mdb-001` (schema enforcement); schema side of `TR-mdb-006` (Vent targeting) and the `DAMAGE`-requires-`power_tier` invariant behind `TR-mdb-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: `ContentValidator extends RefCounted` returns `{ok, errors, warnings}`; diagnostics route through an injected `LogSink` spy (never `push_error`); it runs as a CI-blocking gate + dev-boot check over the `ContentCatalogs` aggregate.

**Engine**: Godot 4.7 | **Risk**: LOW (extends the proven `ContentValidator`)
**Engine Notes**: The `ContentValidator` tooling already exists (Part-DB Stories 007–009). The Move DB content ACs are labelled ADVISORY-DEFERRED in the GDD (the *CI content-authoring gate* waits for real move `.tres` content), but the validator LOGIC + fixture unit tests are implementable now — identical to how the Part-DB validator was built and tested against fixtures before content existed.

**Control Manifest Rules (this layer)**:
- Required: content validation is a CI-blocking gate + dev-boot check; diagnostics via injected `LogSink` — source: ADR-0003
- Forbidden: `push_error`/`push_warning` from `src/` (`global_push_diagnostics`) — route through the sink — source: ADR-0002
- Guardrail: validator is pure over the injected aggregate; no I/O, no globals

---

## Acceptance Criteria

*From GDD AC-MDB-18, AC-MDB-21, EC-MDB-04 (authoring side):*

- [ ] Append `moves: MoveCatalog` to `ContentCatalogs` (APPEND-ONLY) and dispatch `_validate_move(move)` for each entry
- [ ] AC-MDB-18: a well-formed `DAMAGE` move carries all required fields (`id, display_name, behavior, power_tier, damage_type, element, energy_cost, targeting`); a missing/empty required field errors naming the move `id` — `content_move_missing_field`
- [ ] DAMAGE→`power_tier`: a `DAMAGE` move with a null (0 reserved) `power_tier` errors — `content_damage_move_missing_power_tier` (EC-MDB-04 authoring gate; runtime `STANDARD` fallback is TBC's concern)
- [ ] AC-MDB-21: `REPAIR` and `UTILITY`(Vent) moves must have `targeting == SELF`; a non-SELF REPAIR/UTILITY errors — `content_move_bad_targeting`
- [ ] Clean fixtures (one well-formed move per behavior class) produce zero errors/warnings

---

## Implementation Notes

*Derived from `content_validator.gd` `_validate_part` dispatch + GDD Rule 1/2:*

Add a `_validate_moves(catalogs)` loop mirroring the part loop, guarded so it only runs when `catalogs.moves != null` (prior-story part fixtures that mount no move catalog stay green — same gating discipline as the `balance != null` / `references_mounted` gates). Each check is a small `_check_*` function emitting a `StringName` code + detail dict via the existing `_error`. Required-field emptiness uses the same `&""`/0-sentinel tests the Part validator uses. Pair every check with a CLEAN fixture (passes) and a CORRUPTED one (must fail) per ADR-0003's validation criteria.

---

## Out of Scope

- Story 005: cross-field authoring rules (energy band, REPAIR brake, status↔element, non-DAMAGE rider, Core skill-unlock)
- Story 006: cross-DB referential integrity
- TBC runtime fallbacks (null `power_tier` → STANDARD at runtime; stray `power_tier` on non-DAMAGE ignored)

---

## QA Test Cases

- **AC-1** (AC-MDB-18): required fields + no part-only fields
  - Given: a `DAMAGE` move missing `display_name` (`&""`); separately a well-formed move
  - When: validate
  - Then: the first logs `content_move_missing_field` naming the id; the well-formed one is clean
  - Edge: `MoveDef` exposes no `heat_generation`/`ammo_cost` (schema-level, asserted in Story 001; re-confirmed here structurally)
- **AC-2** (DAMAGE power_tier): `DAMAGE` move with `power_tier` at the 0 sentinel → `content_damage_move_missing_power_tier`; a non-DAMAGE move with null `power_tier` is clean
- **AC-3** (AC-MDB-21): a `REPAIR` with `targeting=ENEMY` and a Vent `UTILITY` with `targeting=ENEMY` each → `content_move_bad_targeting`; the same moves with `SELF` are clean

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/move_database/move_validator_schema_test.gd` — must exist and pass

**Status**: [x] Created & passing — `tests/unit/move_database/move_validator_schema_test.gd` (15 tests: clean multi-behavior baseline, moves==null skip, AC-1 required fields incl. energy_cost-0-legal + non-DAMAGE-needs-no-damage_type, AC-2 DAMAGE power_tier gate, AC-3 REPAIR/UTILITY SELF targeting incl. DAMAGE-ENEMY-allowed, null-entry fatal). Validator extended with `_validate_move_catalog`/`_validate_move`/`_check_move_required_fields`/`_check_damage_power_tier`/`_check_move_targeting` + `SELF_TARGET_BEHAVIORS` const; `moves: MoveCatalog` appended to `ContentCatalogs` (append-only). Error codes: `content_move_missing_field`, `content_damage_move_missing_power_tier`, `content_move_bad_targeting`, `content_null_entry` (db=move). Full suite **209/209 green, 2834 asserts** (Godot 4.7 + GUT 9.7.1).

---

## Dependencies

- Depends on: Story 001 (schema + catalog)
- Unlocks: Story 005 (authoring-rule checks extend the same `_validate_move` dispatch)
