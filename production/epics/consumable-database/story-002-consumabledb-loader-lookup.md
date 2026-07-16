# Story 002: ConsumableDB loader & null-safe lookup

> **Epic**: Consumable Database
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/consumable-database.md`
**Requirement**: `TR-cdb-001` (catalog-driven load; read-only-at-runtime host)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: One catalog resource per DB loaded through an explicit manifest (no directory scanning); the DB is a read-only host that indexes catalog entries by ID and vends null-safe lookups; defs are frozen shared instances (never duplicated/mutated).

**Engine**: Godot 4.7 | **Risk**: LOW (mirrors the established `PartDB`/`MoveDB`/`PassiveDB` loaders exactly)
**Engine Notes**: Build the `consumable_id → ConsumableDef` index once at load; `get_consumable(id)` returns `null` for an unknown id (never crashes). Duplicate-id detection at load emits a diagnostic via the injected log sink (same pattern as the other loaders), not `push_error`.

**Control Manifest Rules (this layer)**:
- Required: Load through the explicit catalog manifest; DB read-only at runtime — source: ADR-0003
- Forbidden: `DirAccess`-scan the content dir; `duplicate()`/mutate a def; global `push_error`/`push_warning` diagnostics (`global_push_diagnostics`) — source: ADR-0002/0003
- Guardrail: index is built once; lookup is O(1) and null-safe

---

## Acceptance Criteria

*From GDD Rule 1 + Rule 9 (read-only host):*

- [ ] `ConsumableDB` loads a `ConsumableCatalog` and indexes every entry by `consumable_id`
- [ ] `get_consumable(id: StringName) -> ConsumableDef` returns the matching def, or `null` for an unknown id (no crash)
- [ ] Loading is null-safe: a null/empty catalog yields an empty index and lookups return `null`, not a crash
- [ ] Defs are returned as frozen shared instances — the DB never `duplicate()`s or mutates a def

---

## Implementation Notes

*Derived from ADR-0003 §2 + the existing `PassiveDB`/`MoveDB` loaders:*

Mirror `passive_db.gd`/`move_db.gd`: a thin host that takes a `ConsumableCatalog` (injected or loaded), builds a `Dictionary[StringName, ConsumableDef]` index, and vends `get_consumable`. Keep it DI-testable — the loader accepts a catalog argument so a unit test can pass a hand-built `ConsumableCatalog.new()` with no file I/O. Whether `ConsumableDB` is an autoload slot is out of scope here (the autoload roster is fixed at 11 per ADR-0004/0007); this story delivers the loader class + lookup. Duplicate-id at load is a content error surfaced through the log sink at validation time (Story 007) — the loader's index simply last-wins or first-wins consistently with the sibling loaders; match whichever the existing loaders do.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 001: the `ConsumableDef`/`ConsumableCatalog` schema (this story consumes it)
- Story 003: the restore formulas
- Story 007: duplicate-id / roster / schema *validation* (this story only indexes; the validator reports content errors)
- Story 008: the authored `.tres` catalog the real boot loads

---

## QA Test Cases

- **AC-1**: index + lookup
  - Given: a `ConsumableCatalog` with 3 hand-built defs (`weld_patch`, `repair_kit`, `coolant_flush`)
  - When: `get_consumable(&"repair_kit")` is called
  - Then: the matching `ConsumableDef` is returned
  - Edge cases: `get_consumable(&"does_not_exist")` returns `null`; `get_consumable(&"")` returns `null`
- **AC-2**: null-safe empty load
  - Given: a `ConsumableDB` built from a null or empty catalog
  - When: any lookup runs
  - Then: returns `null` with no crash
- **AC-3**: shared-instance integrity
  - Given: a def fetched from the DB
  - When: it is compared to the catalog entry
  - Then: it is the same instance (not a duplicate); the DB exposes no mutation path

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/consumable_database/consumable_db_loader_test.gd` — must exist and pass

**Status**: [x] Passing — full GUT suite 452/452 green (2026-07-16)

---

## Dependencies

- Depends on: Story 001 (schema)
- Unlocks: Story 003 (formulas fetch defs), Story 004 (use-transaction fetches defs)
