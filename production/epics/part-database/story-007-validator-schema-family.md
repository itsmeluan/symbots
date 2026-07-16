# Story 007: ContentValidator — schema & enum-integrity family

> **Epic**: Part Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-15

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-001`, `TR-part-002`, `TR-part-003`, `TR-part-006`, `TR-part-015`, `TR-part-020`, `TR-part-021`, `TR-part-025` (validation side)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: A single `ContentValidator` (plain `RefCounted`, fully DI — takes all loaded catalogs + a `LogSink`) produces `{ok: bool, errors: Array[Dictionary], warnings: Array[Dictionary]}`. Two mounts, one validator: CI-blocking headless GUT + dev-boot fail-loud (release skips). This story builds the validator scaffold and the schema/enum/nullability/range validation families for Part DB.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Validator is a plain `RefCounted` — no autoload coupling; test fixtures build the `ContentCatalogs` aggregate directly. Report ERRORS via `LogSink.error(code, detail)` — NEVER `push_error()` from `src/` (`global_push_diagnostics` forbidden; invisible to GUT). Each validation family cites its GDD AC in the test name (e.g. `test_ac_01_required_fields`) so `/story-done` traceability picks it up.

**Control Manifest Rules (this layer)**:
- Required: Route all diagnostics through the injected `LogSink` — source: ADR-0002
- Forbidden: Never call `push_warning()`/`push_error()` from `src/` (`global_push_diagnostics`) — source: ADR-0002
- Guardrail: dev-boot validation is one linear pass over all catalogs (debug builds only); zero cost in release

---

## Acceptance Criteria

*From GDD AC-01/02/03/17/18/20/21/22/24 (schema & enum-integrity family):*

- [ ] `ContentValidator` scaffold: `RefCounted`, DI (`validate(catalogs, log_sink) -> Dictionary`), returns `{ok, errors, warnings}`; ERRORS routed through LogSink (TR-part-001)
- [ ] AC-01: every part has all required fields non-null/non-wrong-type for its rarity; rarity-gated nullability incl. the CORE exception (Core never has `active_skill_id` at any rarity; Rare+ Core requires `passive_id`) (TR-part-003)
- [ ] AC-02: every part `id` globally unique (`set.size() == entries.size()`)
- [ ] AC-03: every `slot_type` ∈ the 8 MVP enum values
- [ ] AC-17: `stat_bonuses.get("recharge", 0)` ∈ [0, 15] for every part (TR-part-002)
- [ ] AC-18: only ENERGY_CELL and CORE parts carry non-zero `recharge` (TR-part-002)
- [ ] AC-20: every CHASSIS part has a valid non-null `chassis_archetype`; every non-CHASSIS part has `chassis_archetype == null` (TR-part-006)
- [ ] AC-21: `manufacturer`/`element`/`damage_type`/`rarity` all within MVP enum sets; NO Full-Vision-reserved values (CRYO/CORROSIVE/DATA) appear (TR-part-025)
- [ ] AC-22: `heat_generation` ∈ [0, 40]; parts with `active_skill_id == null` have `heat_generation == 0` (TR-part-015 — Part DB share only; the THERMAL +5 runtime bonus is Combat/TBC)
- [ ] AC-24: every part has non-null, non-empty `sprite_id` (TR-part-020)

---

## Implementation Notes

*Derived from ADR-0003 §5 (validation gate) + GDD ACs listed:*

Build the `ContentValidator` as the ADR-0003 sketch: `class_name ContentValidator extends RefCounted`, `validate(catalogs: ContentCatalogs, log_sink: LogSink) -> Dictionary`. This story delivers the scaffold + the schema/enum families; Stories 008–009 extend the SAME validator with more families (do not fork). Each check appends a structured `{code, detail}` to `errors` and calls `log_sink.error(...)`. `ok` is `errors.is_empty()`.

The rarity-gated nullability check (AC-01) is the subtle one — implement the CORE exception explicitly: non-Core uses the standard table (Common: no skill/no passive; Rare+ non-Core: skill required; Boss/Proto: passive required); Core uses the exception (no active skill at any rarity; Rare+ Core requires passive). Use the `&""`-as-null convention from ADR-0003 (empty StringName = "none").

Per ADR-0003 Validation Criteria: ship a deliberately-corrupted fixture per family that fails its named test — proving the validator *discriminates* (a validator that never fires is worthless).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: content-rule/budget/synergy family (AC-04/10/11/12/19/23)
- Story 009: cross-DB referential integrity (AC-13) + level_requirement/level_growth
- Story 010: authoring the real content + wiring the CI mount
- Combat/TBC: Formula 5 THERMAL +5 heat runtime bonus

---

## QA Test Cases

*Extracted from GDD AC-01/02/03/17/18/20/21/22/24. Each pairs a clean fixture (passes) with a corrupted fixture (must fail).*

- **AC-1** (GDD AC-01): required fields + rarity nullability incl. CORE exception
  - Given: fixtures — (a) a valid part set; (b) a Common with a non-null `active_skill_id`; (c) a Core (any rarity) with a non-null `active_skill_id`; (d) a Rare Core with null `passive_id`
  - When: `validate` runs
  - Then: (a) `ok == true`; (b)(c)(d) each produce an ERROR and `ok == false`
  - Edge cases: Common Core has neither skill nor passive (valid); Boss non-Core with null `passive_id` (error)

- **AC-2** (GDD AC-02): global id uniqueness
  - Given: a catalog with two entries sharing `id`
  - When: validated
  - Then: ERROR; `set.size() != entries.size()`
  - Edge cases: unique-id catalog passes

- **AC-3** (GDD AC-03/20/21): enum-set membership
  - Given: fixtures with an out-of-set `slot_type`; a CHASSIS with null `chassis_archetype`; a non-CHASSIS with a non-null one; a part with `element = CRYO`
  - When: validated
  - Then: each is an ERROR
  - Edge cases: all-valid enums pass; CORE with `chassis_archetype == null` passes

- **AC-4** (GDD AC-17/18): recharge range + slot gating
  - Given: a HEAD part with `recharge = 5`; an ENERGY_CELL with `recharge = 20`; an ENERGY_CELL with `recharge = 15`
  - When: validated
  - Then: first ERROR (non-EnergyCell/Core carries recharge), second ERROR (out of [0,15]), third passes
  - Edge cases: part with no `recharge` key treated as 0, passes

- **AC-5** (GDD AC-22/24): heat range + null-skill heat + sprite_id
  - Given: a part with `heat_generation = 41`; a null-skill part with `heat_generation = 5`; a part with `sprite_id == ""`
  - When: validated
  - Then: each is an ERROR
  - Edge cases: null-skill part with `heat_generation = 0` passes

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/content/part_validator_schema_test.gd` — must exist and pass; includes a discriminating corrupted fixture per family

**Status**: [x] Created and passing — `tests/unit/content/part_validator_schema_test.gd` (31 tests; full suite 85/85, 239 asserts, Godot 4.7 + GUT 9.7.1). Every AC family pairs a clean fixture (passes) with a deliberately-corrupted one that fails its named test — proving the validator discriminates (ADR-0003 validation criteria).

---

## Dependencies

- Depends on: Story 002 (`PartDef`/`PartCatalog` to validate)
- Unlocks: Story 008, Story 009 (extend this validator), Story 010 (CI mount runs it on real content)

---

## Completion Notes
**Completed**: 2026-07-15
**Criteria**: 10/10 passing (scaffold + AC-01/02/03/17/18/20/21/22/24). All COVERED by named tests.
**Files created**:
- `src/core/content/content_validator.gd` — `class_name ContentValidator extends RefCounted`; `validate(catalogs: ContentCatalogs, log_sink: LogSink) -> Dictionary` returning `{ok, errors, warnings}`; `ok == errors.is_empty()`; every finding mirrored to the injected `LogSink.error(code, detail)` in lock-step. Schema/enum/nullability/range families for the Part DB.
- `src/core/content/content_catalogs.gd` — `class_name ContentCatalogs extends RefCounted`; the DI aggregate the validator takes (one `parts: PartCatalog` slot; APPEND-ONLY as future DBs land — ADR-0003/0004 infra).
- `tests/unit/content/part_validator_schema_test.gd` — 31 tests; new `tests/unit/content/` dir (auto-discovered via `.gutconfig.json` `include_subdirs`).
**Deviations** (all advisory, logged to `docs/tech-debt-register.md`):
1. **`ContentCatalogs` born without a home story** — the `validate(catalogs, …)` signature needs an aggregate type; only `PartCatalog` exists (other DBs unstoried), so a minimal RefCounted bundle was created (like `LogSink`/`StatMath` born in earlier stories). Append future catalogs; never reorder.
2. **`damage_type` gating interpretation (NEEDS USER CONFIRMATION)** — AC-21 lists `damage_type` among always-required MVP enums, but `damage_type` is skill-delivered: a no-skill part (e.g. any Core) legitimately has the unset `0`. Interpretation shipped: **reserved values (DATA/TRUE) rejected on every part; a valid MVP value required only when `active_skill_id != &""`.** Confirm this matches the GDD's intent for skill-less parts.
3. **Stale engine label** — story-007 Context reads "Godot 4.6" (line 20); folds into the 4.6→4.7 re-validation sweep.
4. **Reserved-element code reuse** — a reserved element (CRYO/CORROSIVE/DATA) is flagged with the generic `content_invalid_element` code rather than a distinct "reserved" code. The AC only requires it be flagged; distinct-code granularity is a nicety Story 008/009 can add if useful.
**Verification note**: integer-range checks only (recharge [0,15], heat [0,40]) — no floor/ceil/epsilon, so no `python3` Fraction-oracle scan needed (that guidance targets rounding formulas). Boundary coverage: recharge 15 passes / 20 errors; heat 41 errors.
**Test Evidence**: Logic — `tests/unit/content/part_validator_schema_test.gd` (BLOCKING gate satisfied; discriminating corrupted fixture per family per ADR-0003).
**Code Review**: Complete — inline (lean mode; subagents unavailable — persistent "Usage credits" API error). ADR-0003 compliant (DI `RefCounted`, `{ok, errors, warnings}`, `LogSink`-routed, no `push_error`/`DirAccess`/`duplicate()`); ADR-0002 §5 compliant (all diagnostics via injected sink). Methods small, single-responsibility, doc-commented; enum sets are named consts (no magic values).
