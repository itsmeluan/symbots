# Story 001: MoveDef schema, enums & MoveCatalog

> **Epic**: Move Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/move-database.md`
**Requirement**: `TR-mdb-001` (+ the schema fields backing `TR-mdb-006` `vent_amount` and `TR-mdb-007` `scan_payload`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Typed `Resource` def per entity, all fields `@export` + typed; enums declare explicit integer values starting at 1 (0 = reserved/invalid) and are APPEND-ONLY; cross-DB references are `StringName` IDs (`&""` = none), never `Resource` links; one `Catalog` resource per DB (explicit manifest, no directory scanning).

**Engine**: Godot 4.7 | **Risk**: MEDIUM (typed-field `.tres` round-trip; the `Dictionary[StringName,int]` case was proven by Part-DB Story 001 — `status_proc` here is an *untyped* `Dictionary`, which is strictly safer, so no new spike is required)
**Engine Notes**: `status_proc` is `Dictionary`/null and `target_profile` is `Array`/null (reserved) — both default to the safe empty/`null` sentinel. Reuse `PartDef.Element` and `PartDef.DamageType` for the `element`/`damage_type` fields (single enum source of truth across the Part/Move DBs) rather than re-declaring parallel enums.

**Control Manifest Rules (this layer)**:
- Required: Content ships as typed `.tres` defs resolved through an explicit catalog; `@export` enums start at 1 (0 reserved) and are APPEND-ONLY — source: ADR-0003
- Forbidden: Never reorder/insert/renumber existing content-def enum values (`content_enum_reordering`); `.tres` stores raw ints — source: ADR-0003
- Guardrail: def is a frozen shared instance, read-only at runtime

---

## Acceptance Criteria

*From GDD Rule 1 (MOVE-CONTRACT-1) + AC-MDB-18:*

- [ ] `MoveDef extends Resource` with `class_name MoveDef`; every field `@export` + statically typed
- [ ] Fields: `id: StringName`, `display_name: String`, `behavior: Behavior`, `power_tier: PowerTier`, `damage_type: PartDef.DamageType`, `element: PartDef.Element`, `energy_cost: int`, `status_proc: Dictionary`, `targeting: Targeting`, `break_bias: BreakBias`, `scan_payload: ScanPayload`, `vent_amount: int`, `target_profile: Array` (reserved)
- [ ] Enums with explicit int values from 1 (0 = reserved/invalid): `Behavior {DAMAGE, STATUS, REPAIR, SCAN, UTILITY}`, `PowerTier {BASIC, LIGHT, STANDARD, HEAVY, SIGNATURE}`, `Targeting {ENEMY, SELF}`, `BreakBias {STRUCTURE_HEAVY, BALANCED, BREAK_HEAVY}`, `ScanPayload {BREAK_REGIONS}`
- [ ] A well-formed `DAMAGE` record carries all required fields and does **not** carry `heat_generation` or `ammo_cost` (those stay on the Part) — AC-MDB-18
- [ ] `MoveCatalog extends Resource` with `class_name MoveCatalog`, `@export var entries: Array[MoveDef]`

---

## Implementation Notes

*Derived from ADR-0003 §1–2 + GDD Rule 1:*

Mirror `PartDef`/`PartCatalog` exactly. `break_bias` defaults to `BALANCED`; `power_tier`, `damage_type`, `element` default to the 0 reserved sentinel (meaningful only for `DAMAGE`; validation — Story 004/005 — enforces non-null `power_tier` on `DAMAGE`). `status_proc` defaults to `{}`, `target_profile` to `[]` (reserved — no MVP move authors it). `heat_generation`/`ammo_cost` are deliberately ABSENT from `MoveDef` (Rule 1: they live on the Part). Doc-comment every public field. No logic in this story beyond the schema itself.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 002: the `MoveDB` loader/index and null-safe lookup
- Story 003: MOVE-F1 (the `power_tier` → multiplier math)
- Stories 004/005: all validation (band checks, targeting, status-element, core skill-unlock)
- TBC epic: every runtime behaviour — Basic Attack instantiation (AC-MDB-06), SCAN reveal/persistence (AC-MDB-10/20), Vent heat-mutation (AC-MDB-11), status-proc application (AC-MDB-09), `hit_resolved` emission (AC-MDB-19), SKILL_ENHANCE/UNLOCK runtime (AC-MDB-12/13). This story authors the static *contract* only.

---

## QA Test Cases

- **AC-1** (AC-MDB-18): well-formed record shape
  - Given: a fully-populated `DAMAGE` `MoveDef`
  - When: the fields are read
  - Then: all 8 required fields (`id, display_name, behavior, power_tier, damage_type, element, energy_cost, targeting`) are present and typed; `MoveDef` exposes no `heat_generation`/`ammo_cost` property
  - Edge cases: a `MoveDef.new()` bare instance has all enums at the 0 reserved sentinel and `status_proc == {}`, `target_profile == []`
- **AC-2**: enum integrity
  - Given: each enum
  - When: values are read
  - Then: no value is 0 (0 stays reserved); values are contiguous from 1

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/move_database/move_def_schema_test.gd` — must exist and pass

**Status**: [x] Created & passing — `tests/unit/move_database/move_def_schema_test.gd` (15 tests). Full suite 175/175 green, 491 asserts (Godot 4.7 + GUT 9.7.1).

---

## Dependencies

- Depends on: None (Part-DB Story 001 spike already de-risked typed-field `.tres` round-trips)
- Unlocks: Story 002 (loader), Story 003 (formula reads `PowerTier`), Stories 004/005 (validation)
