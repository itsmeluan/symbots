# Story 001: Engine spike — typed-dict `.tres` round-trip gate

> **Epic**: Part Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-001`, `TR-part-002` (this spike de-risks the `Dictionary[StringName, int]` schema surface both require)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Content ships as typed `.tres` Resource entries with every field `@export`ed and statically typed; `stat_bonuses` is a `Dictionary[StringName, int]`. ADR-0003 is Accepted **but its acceptance does not waive verification gate item #2** — this story IS that gate.

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: `Dictionary[StringName, int]` `@export` inspector authoring and `.tres` round-trip are **post-cutoff (4.4+) and UNVERIFIED**. Known failure modes: keys may deserialize as `String` not `StringName`; typed-dict `.get()` may return `Variant` under a typed function return. This is the single load-bearing Foundation engine unknown. **If the gate fails, the fallback (untyped `Dictionary` + validator-enforced schema) requires an explicit ADR-0003 amendment — never a silent in-place downgrade** (ADR-0003 Risks table).

**Control Manifest Rules (this layer)**:
- Required: Content ships as typed `.tres` defs resolved through explicit catalog reference chains via `ResourceLoader`; content-def `@export` enums declare explicit integer values starting at 1 and are APPEND-ONLY — source: ADR-0003
- Forbidden: Never list content directories with `DirAccess` in the load path (`content_directory_scanning`) — source: ADR-0003
- Guardrail: Boot load + index of ~130 records is sub-millisecond; no per-lookup allocations

---

## Acceptance Criteria

*From ADR-0003 Verification Required item (2) + Validation Criteria, scoped to this spike:*

- [ ] `@export var stat_bonuses: Dictionary[StringName, int]` authors correctly in the Godot 4.6 inspector (typed key/value editing)
- [ ] After writing to a `.tres` file and reloading via `ResourceLoader.load()`, every key is still `StringName` (NOT `String`-coerced) and every value is still `int`
- [ ] A typed function returning the dict's value type (e.g. `func get_bonus(k: StringName) -> int: return stat_bonuses.get(k, 0)`) compiles and returns a usable `int` (not `Variant`)
- [ ] The round-trip is exercised **headless** (`godot --headless`) so editor-cache Resource instances never contaminate the result
- [ ] Finding is documented (PASS → proceed to Story 002; FAIL → ADR-0003 amendment required before any content authoring)

---

## Implementation Notes

*Derived from ADR-0003 §1 (Typed Resource classes) + Risks table:*

Build the minimal `PartDef`-shaped probe: a `class_name` script extending `Resource` with a single `@export var stat_bonuses: Dictionary[StringName, int]`. Author one instance as a `.tres`, reload it headless, and assert key/value runtime types with `typeof()` / `is` checks — do NOT trust the inspector display alone. The `&"key"` StringName literal is the authoring form. Prove the negative too: assert that a key read back is NOT a plain `String`. Keep the probe isolated; it is a throwaway that produces a finding, not shipped schema (Story 002 builds the real `PartDef`).

This finding is **reused across the other four content-DB epics** (Move/Passive/Consumable/Enemy) — record it where those epics can cite it (epic DoD references "reuse the finding").

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the full `PartDef` schema, all fields, enums, `PartCatalog`
- Story 003: the `PartDB` loader / indexing / getters
- Nested-Resource load chains (BreakRegionDef inside EnemyDef) — that is verification item #3, owned by the Enemy DB epic

---

## QA Test Cases

*Extracted from ADR-0003 verification item #2. Developer implements against these.*

- **AC-1**: Typed-dict `.tres` round-trip preserves StringName keys and int values
  - Given: a `Resource` with `@export var stat_bonuses: Dictionary[StringName, int]` authored to `.tres` with keys `&"structure"`, `&"armor"`
  - When: the `.tres` is reloaded via `ResourceLoader.load()` in a headless run
  - Then: for every key `k`, `typeof(k) == TYPE_STRING_NAME` (assert NOT `TYPE_STRING`); for every value `v`, `typeof(v) == TYPE_INT`
  - Edge cases: empty dict `{}`; a key authored as plain String (must round-trip in a distinguishable way or be rejected); single-entry dict; verify the negative — a `String` key must NOT silently pass as StringName

- **AC-2**: Typed return usability
  - Given: the reloaded def and a typed accessor `func get_bonus(k: StringName) -> int`
  - When: `get_bonus(&"structure")` is called
  - Then: returns a value where `typeof(result) == TYPE_INT`, usable in integer arithmetic without cast
  - Edge cases: missing key returns the `0` default typed as int, not `null`

---

## Test Evidence

**Story Type**: Integration (engine spike)
**Required evidence**:
- `tests/unit/part_database/tres_typed_dict_roundtrip_test.gd` — headless GUT test asserting the type-preservation above — must exist and pass
- A short finding note (PASS/FAIL + any coercion observed) recorded for reuse by the other content-DB epics

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (first story; this is the gate)
- Unlocks: Story 002 (and, transitively, every other Part DB story + all content authoring project-wide)
