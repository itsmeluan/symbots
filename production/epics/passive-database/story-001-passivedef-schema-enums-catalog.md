# Story 001: PassiveDef schema, enums & PassiveCatalog

> **Epic**: Passive Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/passive-database.md`
**Requirement**: `TR-pdb-001` (+ the schema fields backing `TR-pdb-003` `scope` and `TR-pdb-006` `behavior_params`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Typed `Resource` def per entity, all fields `@export` + typed; enums declare explicit integer values starting at 1 (0 = reserved/invalid) and are APPEND-ONLY; cross-DB references are `StringName` IDs (`&""` = none), never `Resource` links; one `Catalog` resource per DB (explicit manifest, no directory scanning).

**Engine**: Godot 4.7 | **Risk**: MEDIUM (typed-field `.tres` round-trip; the `Dictionary[StringName,int]` case was proven by Part-DB Story 001. `behavior_params` here is an *untyped* `Dictionary`, strictly safer, so no new spike is required)
**Engine Notes**: `behavior_params` is `Dictionary`/`{}` (its key set is per-`behavior_class`, validated in Story 005 — the schema stores it untyped). Reuse existing enums where an authority already exists (e.g. status names / `final_stat` keys are `StringName` values inside `behavior_params`, not new enums). All new enums start at 1 (0 = INVALID sentinel) and are APPEND-ONLY.

**Control Manifest Rules (this layer)**:
- Required: Content ships as typed `.tres` defs resolved through an explicit catalog; `@export` enums start at 1 (0 reserved) and are APPEND-ONLY — source: ADR-0003
- Forbidden: Never reorder/insert/renumber existing content-def enum values (`content_enum_reordering`); never `duplicate()`/mutate a content def; never `DirAccess`-scan the content dir in the load path — source: ADR-0003
- Guardrail: def is a frozen shared instance, read-only at runtime

---

## Acceptance Criteria

*From GDD Rule 1 + Rule 3a + AC-PDB-03:*

- [ ] `PassiveDef extends Resource` with `class_name PassiveDef`; every field `@export` + statically typed
- [ ] Fields: `id: StringName`, `display_name: String`, `short_description: String`, `trigger_category: TriggerCategory`, `behavior_class: BehaviorClass`, `scope: Scope`, `stacking_policy: StackingPolicy`, `passive_class: PassiveClass`, `behavior_params: Dictionary`
- [ ] Enums with explicit int values from 1 (0 = INVALID/reserved): `BehaviorClass {STATUS_RIDER, STAT_AURA, RESOURCE_EFFECT, STRUCTURAL_EFFECT}`, `TriggerCategory {ON_HIT, ON_TURN_START, ON_BATTLE_START, ON_OVERHEAT, PERSISTENT}`, `Scope {ANY_DAMAGE, WEAPON_ONLY}`, `StackingPolicy {UNIQUE_PER_TRIGGER, UNIQUE, STACKABLE}`, `PassiveClass {STATUS_RIDER, CORE_TRAIT, UPGRADE_PASSIVE}`
- [ ] A well-formed entry carries all required fields (`id`, `display_name`, `short_description`, `trigger_category`, `behavior_class`, `stacking_policy`, `passive_class`) and does **NOT** carry `heat_generation` or `energy_cost` (those stay on the Part) — **AC-PDB-03**
- [ ] `PassiveCatalog extends Resource` with `class_name PassiveCatalog`, `@export var entries: Array[PassiveDef]`

---

## Implementation Notes

*Derived from ADR-0003 §1–2 + GDD Rule 1 / Rule 3a:*

Mirror `MoveDef`/`MoveCatalog` and `PartDef`/`PartCatalog` exactly. All enums default to their 0 INVALID sentinel; `scope` is meaningful only for `STATUS_RIDER` (validation in Story 004 enforces legal pairings). `behavior_params` defaults to `{}`. `heat_generation`/`energy_cost` are deliberately ABSENT from `PassiveDef` (Rule 1: they live on the Part). `passive_class` is pure authoring/display metadata — it does NOT drive resolution or stacking (Rule 4 defaults key on `behavior_class`, assigned in Story 003). Doc-comment every public field. No logic in this story beyond the schema itself. Verify a round-trip `.tres` save/load preserves the enum ints and the `behavior_params` dict headlessly.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 002: the `PassiveDB` loader/index and null-safe lookup (AC-PDB-01)
- Story 003: stacking-policy default derivation per `behavior_class` (TR-pdb-004)
- Stories 004/005: all validation (legality matrix, behavior_params, STRUCTURAL non-negative, Core restriction)
- Story 006: referential integrity / `passive_ids` wiring
- Story 007: the three MVP status-rider `.tres` content
- TBC epic (Rule 13 executor): every runtime behaviour — status application, stacking dedup, aura folding, structure clamps (AC-PDB-04–11, 17). This story authors the static *contract* only.

---

## QA Test Cases

- **AC-1** (AC-PDB-03): well-formed record shape
  - Given: a fully-populated `PassiveDef`
  - When: the fields are read
  - Then: all 7 required fields (`id, display_name, short_description, trigger_category, behavior_class, stacking_policy, passive_class`) are present and typed; `PassiveDef` exposes no `heat_generation`/`energy_cost` property
  - Edge cases: a `PassiveDef.new()` bare instance has all enums at the 0 INVALID sentinel and `behavior_params == {}`
- **AC-2**: enum integrity
  - Given: each of the 5 enums
  - When: values are read
  - Then: no value is 0 (0 stays reserved/INVALID); values are contiguous from 1
- **AC-3**: `.tres` round-trip
  - Given: a `PassiveDef` saved to a `.tres` then loaded headlessly
  - When: the loaded def is read
  - Then: every enum int and the `behavior_params` dict match the saved values exactly

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/passive_database/passive_def_schema_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Part-DB Story 001 spike already de-risked typed-field `.tres` round-trips)
- Unlocks: Story 002 (loader), Story 003 (stacking defaults read `BehaviorClass`), Stories 004/005/006 (validation reads the schema)
