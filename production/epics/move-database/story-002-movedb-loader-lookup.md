# Story 002: MoveDB loader & null-safe lookup

> **Epic**: Move Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/move-database.md`
**Requirement**: `TR-mdb-001` (the lookup contract of MOVE-CONTRACT-1)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading (primary — load/index/expose read-only); ADR-0004: Scene Management & Boot (secondary — autoload is a THIN HOST, no work in `_ready`)
**ADR Decision Summary**: DB singletons load a catalog into an O(1) id→def index and vend the SHARED frozen def; unknown id returns `null` (callers must null-check); no `DirAccess` in the load path; fatal reporting routes through an injected `LogSink`, never `push_error()`.

**Engine**: Godot 4.7 | **Risk**: LOW (mirror of `PartDB`)
**Engine Notes**: `Dictionary.get(id)` returns `null` for a missing key AND for `&""`/`null` args (both coerce to a missing key) — this is the null contract, no extra guard needed. The `-> MoveDef` annotation does NOT protect callers from null (GDScript object types are nullable).

**Control Manifest Rules (this layer)**:
- Required: Read content exclusively via the DB singleton's typed getters (`content_db_lookup`); defs are frozen shared instances — source: ADR-0003
- Forbidden: `DirAccess` directory listing in the load path (`content_directory_scanning`); I/O or cross-autoload reads in `_ready` (`autoload_ready_work`); `push_error` from `src/` (`global_push_diagnostics`) — source: ADR-0003/0004/0002
- Guardrail: O(1) `Dictionary.get` lookups, no per-lookup allocation

---

## Acceptance Criteria

*From GDD EC-MDB-01 + AC-MDB-01 + ADR-0003 §3:*

- [ ] `MoveDB extends Node` (autoload-shaped, thin host — no work in `_ready`)
- [ ] `load_catalog(catalog: MoveCatalog, log_sink: LogSink) -> bool` indexes every entry by `id`; FATAL (returns false) on a null catalog slot (`content_null_entry`) or a duplicate id within the catalog (`content_duplicate_id`)
- [ ] `get_move(id: StringName) -> MoveDef` returns the shared frozen def, or `null` for any unknown id (incl. `&""` / null) — never throws — AC-MDB-01
- [ ] `has_move(id: StringName) -> bool` is the presence guard for the null contract
- [ ] All fatal reporting routes through the injected `LogSink` (dependency-injected, never a global `push_error`)

---

## Implementation Notes

*Derived from `part_db.gd` (the proven sibling) + ADR-0003 §3:*

Copy `src/core/content/part_db.gd` structure verbatim, substituting `MoveDef`/`MoveCatalog` and `"move"` in the `db` diagnostic detail. Same `_by_id: Dictionary[StringName, MoveDef]` index, same DI signature (`catalog` + `log_sink` as params so GUT drives the exact production path with fixtures). Do NOT wire the autoload into `project.godot` in this story — the BootScreen sequencer roster is fixed in ADR-0004 and its wiring is a boot-integration concern; this story delivers the class + DI-tested load/lookup.

---

## Out of Scope

- Story 001: the `MoveDef`/`MoveCatalog` schema (this story consumes them)
- Autoload registration in `project.godot` + BootScreen sequencing (ADR-0004 boot epic)
- Story 006: cross-DB referential integrity (`active_skill_id` → move resolution)

---

## QA Test Cases

- **AC-1** (AC-MDB-01): unknown-id null contract
  - Given: a `MoveDB` loaded with a small fixture catalog
  - When: `get_move(&"does_not_exist")`, `get_move(&"")`
  - Then: returns `null`, no error thrown
  - Edge cases: `has_move` returns false for the same ids; a known id returns the exact shared instance (identity, not a copy)
- **AC-2**: load fatals
  - Given: a catalog with (a) a null slot, (b) two entries sharing an id
  - When: `load_catalog(...)`
  - Then: returns `false`; the spy `LogSink` recorded `content_null_entry` / `content_duplicate_id` respectively
  - Edge cases: a clean catalog returns `true` and logs nothing

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/move_database/move_db_test.gd` — must exist and pass

**Status**: [x] Created & passing — `tests/unit/move_database/move_db_test.gd` (9 tests) + local `spy_log_sink.gd`. Full suite 184/184 green, 512 asserts (Godot 4.7 + GUT 9.7.1).

---

## Dependencies

- Depends on: Story 001 (schema)
- Unlocks: Story 006 (referential integrity reads the move index)
