# Story 003: PartDB singleton — load / index / expose read-only

> **Epic**: Part Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-018` (+ GDD AC-14 `get_part` null contract, AC-02 in-catalog uniqueness fatal-at-load)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Each DB is an autoload that at boot loads its catalog into a read-only indexed singleton. `load_catalog(catalog, log_sink) -> bool` is DI (fatal on null entry / duplicate id); `get_part(id) -> PartDef` is O(1) and returns NULL for unknown ids (callers MUST null-check — the typed annotation does not prevent null); `has_part(id) -> bool` is the guard. Defs are frozen shared instances — mutation and `duplicate()`/`duplicate_deep()` are forbidden.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: The autoload is a **thin host** — no I/O, catalog loads, signal connections, or cross-autoload reads in `_ready` (`autoload_ready_work` forbidden; ADR-0004). Actual load is driven explicitly by the BootScreen sequencer (ADR-0004), not `_ready`. `-> PartDef` compiles and runs while silently delivering null — the null-check discipline is real, not decorative. Content must be loaded via the catalog reference chain through `ResourceLoader`; NO `DirAccess` scanning anywhere in the load path.

**Control Manifest Rules (this layer)**:
- Required: Read content exclusively via the DB singletons' typed getters (`content_db_lookup` contract); content defs/catalogs are frozen shared instances — source: ADR-0003
- Required: Never do I/O, catalog loads, signal connections, or cross-autoload reads in an autoload `_ready` — thin hosts only — source: ADR-0004
- Forbidden: Never mutate a content def/catalog field at runtime; never call `duplicate()`/`duplicate_deep()` on any def or catalog (`runtime_content_mutation`); never list content directories with `DirAccess` (`content_directory_scanning`) — source: ADR-0003
- Guardrail: runtime lookups O(1) `Dictionary.get`; no per-lookup allocations

---

## Acceptance Criteria

*From ADR-0003 §3/§4 + GDD AC-14 + AC-02 + EC-04, scoped to the loader/index/getter contract:*

- [ ] `load_catalog(catalog: PartCatalog, log_sink: LogSink) -> bool` indexes entries into `Dictionary[StringName, PartDef]` keyed by `id`
- [ ] A null entry in the catalog array is FATAL — logs `content_null_entry` via LogSink and returns `false`
- [ ] A duplicate `id` within the catalog is FATAL — logs `content_duplicate_id` via LogSink and returns `false` (AC-02)
- [ ] `get_part(id)` returns the correct `PartDef` for a valid id; returns `null` (no crash) for unknown id, `""`, and `null` argument (AC-14)
- [ ] `has_part(id)` returns `true`/`false` matching index membership
- [ ] A `drop_enabled = false` part is still returned in full by `get_part` and reads `drop_enabled == false` — it is NOT deleted (TR-part-018 / EC-04; the drop-table *exclusion* is Drop System's concern, out of scope here)
- [ ] Def immutability: a field snapshot of a returned def before/after use is identical; `duplicate()` on a def still shares nested references (proving `duplicate()` is not a safe copy) — ADR-0003 Validation Criteria
- [ ] No `DirAccess` usage anywhere under the content load path (static grep test)
- [ ] `load_catalog` is exercised by GUT with a fixture catalog — no autoload coupling in the logic (DI)

---

## Implementation Notes

*Derived from ADR-0003 §3 sketch + §4 read-only contract:*

Mirror the ADR-0003 `part_db.gd` sketch: `_by_id: Dictionary[StringName, PartDef]`; loop `catalog.entries`, null-check each (fatal), dup-check `_by_id.has(def.id)` (fatal), else index. `get_part` is `return _by_id.get(id)` — the `.get()` returns null for missing keys, satisfying the null contract for unknown/`""`/`null` inputs. Keep the autoload a thin host: the autoload script exposes `load_catalog`/`get_part`/`has_part`, but the BootScreen sequencer (ADR-0004) calls `load_catalog` — never `_ready`. There is NO defensive copying on lookup; frozen-shared + the `runtime_content_mutation` ban is the strategy.

`LogSink` comes from ADR-0002 (injected diagnostics channel) — route all fatal reporting through it; never `push_error()` from `src/`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the `PartDef`/`PartCatalog` classes this loader indexes
- Stories 007–009: the ContentValidator (a separate DI `RefCounted`, not the loader)
- Drop System epic: `DropSystem.build_drop_table` exclusion of `drop_enabled = false` parts (GDD AC-15a full)
- Assembly/Inventory epics: GDD AC-15b (DEFERRED — cross-system round-trip)
- ADR-0004 boot wiring / autoload roster slotting (final sequencing lives in the Scene/Boot epic)

---

## QA Test Cases

*Extracted from GDD AC-14 + AC-02 + EC-04 + ADR-0003 Validation Criteria.*

- **AC-1**: `get_part` null contract
  - Given: a `PartDB` loaded with a fixture catalog containing `boltwell_spark_core`
  - When: `get_part("boltwell_spark_core")`, `get_part("nonexistent_id_xyz")`, `get_part("")`, `get_part(null)` are called
  - Then: first returns a non-null `PartDef` whose `id` matches; the other three return `null` with no exception
  - Edge cases: `""` and `null` argument must not crash

- **AC-2**: Fatal on duplicate id / null entry
  - Given: a fixture catalog with two entries sharing `id`, and separately one with a `null` array slot
  - When: `load_catalog` runs on each
  - Then: returns `false`; LogSink received `content_duplicate_id` / `content_null_entry` respectively
  - Edge cases: a valid catalog returns `true` and LogSink received no error

- **AC-3**: Disabled part remains valid (TR-part-018 / EC-04)
  - Given: a part authored with `drop_enabled = false`
  - When: `get_part(that_id)` is called
  - Then: returns the full valid entry; `.drop_enabled == false`; the def is byte-for-byte the authored one (not deleted, not mutated)
  - Edge cases: none — this is the Part DB half only; drop-table exclusion is Drop System

- **AC-4**: Def immutability / duplicate() is not a safe copy
  - Given: a returned def and a battle-sim-like read pass
  - When: field values are snapshotted before and after
  - Then: snapshots are identical; separately, `def.duplicate()` still shares nested `Array`/`Dictionary` references (asserting the `runtime_content_mutation` ban is load-bearing)
  - Edge cases: none

- **AC-5**: No DirAccess in load path
  - Given: the content load-path sources
  - When: a static grep test scans them
  - Then: zero `DirAccess` references
  - Edge cases: none

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/part_database/part_db_loader_test.gd` — must exist and pass (getters, fatal-load paths, immutability, DirAccess grep)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (needs `PartDef` + `PartCatalog`)
- Unlocks: Story 010 (content authoring loads through this DB); consumers project-wide read via `PartDB.get_part`
