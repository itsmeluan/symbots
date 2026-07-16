# Story 002: EnemyDB loader & null-safe lookup

> **Epic**: Enemy Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: `TR-edb-001` (catalog-resolved read-only DB)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: One read-only DB host per catalog; lookups are null-safe (unknown id → null, never an exception); the DB is a thin loader over the catalog, not a mutable store.

**Engine**: Godot 4.7 | **Risk**: LOW (thin dictionary loader over the Story-001 catalog — the proven Move/Passive DB pattern)
**Engine Notes**: Mirror `MoveDB`/`PassiveDB`. Build an `id → EnemyDef` index from `catalog.entries` at load. `get_enemy(id: StringName) -> EnemyDef` returns `null` for unknown/`&""`/null id — no `push_error`, no crash. Read-only at runtime (no setters).

**Control Manifest Rules (this layer)**:
- Required: null-safe lookup (unknown → null); read-only DB; built from the injected catalog — source: ADR-0003
- Forbidden: throwing/`push_error` on unknown id; mutating the catalog at runtime; global singleton state for lookups (DI-testable) — source: ADR-0003 / coding-standards
- Guardrail: O(1) id lookup (indexed dict, not a linear scan per call)

---

## Acceptance Criteria

*From GDD `design/gdd/enemy-database.md`, AC-ED-10:*

- [ ] `get_enemy(id)` returns the matching `EnemyDef` for a known id
- [ ] `get_enemy` returns `null` for an unknown id, `&""`, and `null` — no exception, no diagnostic
- [ ] The DB is built from an injected `EnemyCatalog` (DI-testable, no hard autoload dependency in the unit)
- [ ] Lookup is index-backed (constant-time), not a per-call linear scan

---

## Implementation Notes

*Derived from ADR-0003 + the `MoveDB`/`PassiveDB` loaders:*

Copy `move_db.gd`/`passive_db.gd`. Constructor/`load_from(catalog)` walks `catalog.entries`, building `_by_id: Dictionary[StringName, EnemyDef]`. `get_enemy(id)` is `_by_id.get(id, null)`. Optionally expose `has_enemy(id) -> bool` and `all_enemies() -> Array[EnemyDef]` if the sibling DBs do. No validation here — a malformed catalog is Stories 004–009's concern; the loader just indexes what it's given. Keep it injection-testable: the unit test constructs a catalog in-memory and asserts lookups without touching the filesystem.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the schema + catalog this loads
- Stories 004–009: catalog validation (the loader trusts its input)
- Story 003: `break_hp` formula

---

## QA Test Cases

- **AC-1** (known lookup): `get_enemy` resolves an authored id
  - Given: a catalog with an enemy `id = &"wild_rustling"`
  - When: `get_enemy(&"wild_rustling")`
  - Then: returns that exact `EnemyDef`
  - Edge cases: two enemies with distinct ids both resolve independently
- **AC-2** (null-safe unknowns): the no-crash contract
  - Given: the same catalog
  - When: `get_enemy(&"does_not_exist")`, `get_enemy(&"")`, `get_enemy(null)`
  - Then: each returns `null`, raises nothing, emits no diagnostic
  - Edge cases: a `push_error`-on-miss impl fails the "no diagnostic" assertion
- **AC-3** (DI-constructed): no autoload/filesystem dependency
  - Given: an in-memory `EnemyCatalog` built in the test
  - When: the DB is constructed from it and queried
  - Then: lookups succeed with no file I/O

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_database/enemy_db_lookup_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema + catalog)
- Unlocks: any consumer that resolves enemies by id (TBC battle-init, Encounter Zone spawn — deferred integrations)
