# Story 002: PassiveDB loader & null-safe lookup

> **Epic**: Passive Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/passive-database.md`
**Requirement**: `TR-pdb-001` (catalog read via a typed getter; the loader half of the schema+lookup pair)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: One catalog per DB loaded once at boot into a read-only index; lookups go through a typed getter that returns the frozen shared def or a null/`&""` sentinel on miss — never a crash, never a directory scan.

**Engine**: Godot 4.7 | **Risk**: LOW (index build + dictionary lookup; no post-cutoff API surface)
**Engine Notes**: Build the id→def index once from `PassiveCatalog.entries`; do not `preload`/`DirAccess`-scan per lookup. A missing id returns `null` (typed `PassiveDef` getter) — the caller decides fallback (Part DB / TBC log the content error, per EC-PDB-01).

**Control Manifest Rules (this layer)**:
- Required: Content resolved through an explicit catalog index; defs are frozen shared instances, read-only at runtime — source: ADR-0003
- Forbidden: Never `duplicate()`/`duplicate_deep()` a returned def; never scan the content dir in the load path (`content_dir_scan`) — source: ADR-0003
- Guardrail: O(1) `.has()`/lookup; the index is built once at load, not per query

---

## Acceptance Criteria

*From GDD EC-PDB-01 + AC-PDB-01:*

- [ ] `PassiveDB` builds an id→`PassiveDef` index from a loaded `PassiveCatalog`
- [ ] A typed getter (e.g. `get_passive(id: StringName) -> PassiveDef`) returns the frozen shared def for a present id
- [ ] A lookup for a `passive_id` with **no** catalog entry returns `null` and **never throws** — **AC-PDB-01** *(verifies EC-PDB-01)*
- [ ] The returned def is the shared instance (identity-stable across repeated lookups) — not a copy

---

## Implementation Notes

*Derived from ADR-0003 §2 + GDD EC-PDB-01:*

Mirror `MoveDB` (`src/core/content/move_db.gd` equivalent) exactly. Inject the catalog (dependency injection over a hard singleton reference, per coding standards) so tests can mount a fixture catalog. Return `null` on miss — do not raise, do not return a placeholder def. The unknown-id ripple (TBC Rule 13 skip + log per EC-TBC-08) is TBC's concern; this story only guarantees the null-safe *lookup*. No mutation of returned defs.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 001: the `PassiveDef`/`PassiveCatalog` schema itself
- Stories 004/005: content validation of catalog entries
- Story 006: the cross-DB `passive_ids` membership set + `content_dangling_passive_ref` wiring (that is Part-DB→Passive resolution, distinct from this in-DB getter)
- TBC epic: the runtime skip-and-log on unknown id (EC-PDB-02 / AC-PDB-02) — TBC's Rule 13 registry is the execution authority

---

## QA Test Cases

- **AC-1** (AC-PDB-01): null-safe miss
  - Given: a `PassiveDB` built from a catalog that does **not** contain `&"nonexistent_passive"`
  - When: `get_passive(&"nonexistent_passive")` is called
  - Then: it returns `null` and raises nothing
  - Edge cases: `&""` (empty StringName) lookup returns `null`; lookup against an empty catalog returns `null`
- **AC-2**: present-id hit + identity stability
  - Given: a `PassiveDB` built from a catalog containing `&"volt_shock_on_hit"`
  - When: `get_passive(&"volt_shock_on_hit")` is called twice
  - Then: both calls return the same non-null `PassiveDef` instance (shared, not duplicated)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/passive_database/passive_db_loader_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema must exist to index)
- Unlocks: Stories 004, 005, 006 (validators run over a loaded catalog), Story 007 (riders load through the DB)
