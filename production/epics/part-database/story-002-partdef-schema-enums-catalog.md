# Story 002: PartDef schema + enums + PartCatalog

> **Epic**: Part Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-15

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-001`, `TR-part-006`, `TR-part-020`, `TR-part-021`, `TR-part-025`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Each GDD entity becomes a `class_name` script extending `Resource` with every field `@export`ed and statically typed; enums are declared on the def class with explicit integer values starting at 1 (0 = reserved/invalid), append-only. `PartCatalog` is a trivial `Resource` with `@export var entries: Array[PartDef]`.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `.tres` stores enum values as raw integers — every content enum uses explicit values from 1, and values are APPEND-ONLY (never reorder/insert/renumber or already-authored `.tres` silently corrupts). `@export` cannot express `StringName | null`; the project convention is `&""` = "no reference" (each nullable field carries a doc comment stating empty means "none"). Depends on Story 001's typed-dict verdict for `stat_bonuses`.

**Control Manifest Rules (this layer)**:
- Required: Content defs and catalogs are frozen shared instances; content-def `@export` enums declare explicit integer values starting at 1 (0 = reserved/invalid) and are APPEND-ONLY — source: ADR-0003
- Forbidden: Never reorder/insert/renumber existing content-def enum values (`content_enum_reordering`) — source: ADR-0003
- Guardrail: All defs resident permanently — trivially small; no per-lookup allocations

---

## Acceptance Criteria

*From GDD `design/gdd/part-database.md` Rule 1 + Rule 8 + AC-20/21/24, scoped to schema shape only (validation logic is Stories 007–009):*

- [ ] `PartDef extends Resource` declares every Rule 1 field, `@export`ed and statically typed (`id: StringName`, `display_name: String`, `stat_bonuses: Dictionary[StringName, int]`, `synergy_tags: Array[StringName]`, `drop_conditions: Array[Dictionary]`, `upgrade_effects: Array[Dictionary]`, `level_growth: Dictionary[String, int]`, etc.)
- [ ] Enums `SlotType` (8 MVP values), `Rarity` (4), `Element` (VOLT/THERMAL/KINETIC MVP + reserved), `DamageType` (PHYSICAL/ENERGY MVP + reserved), `ChassisArchetype` (5) are declared on the def class with explicit integer values starting at 1
- [ ] Reserved-for-Full-Vision fields exist in the schema and default null/empty in MVP: `motherboard_slot_type`, `ram_cost`, `weight_class`, `modification_slots` (TR-part-025)
- [ ] `sprite_id: StringName` field present (non-null/non-empty enforced later by AC-24) (TR-part-020)
- [ ] `upgrade_effects` entries carry the shape `{tier, effect_type, description, skill_id}` with `effect_type ∈ {SKILL_UNLOCK, SKILL_ENHANCE}` (TR-part-021)
- [ ] `chassis_archetype` typed to the enum, nullable (`&""`/null-equivalent convention); required-CHASSIS / must-be-null-otherwise is validator-enforced later (TR-part-006)
- [ ] `class_name PartCatalog extends Resource` with `@export var entries: Array[PartDef]`
- [ ] Every nullable `StringName` field carries a doc comment: `&""` means "none"
- [ ] All `class_name` def scripts parse cleanly (CI parse gate — a parse-broken def silently fails class registration)

---

## Implementation Notes

*Derived from ADR-0003 §1 (Typed Resource classes) + §2 (Catalog Resource):*

Follow the ADR-0003 class table exactly: `PartDef` gets the 11-stat `stat_bonuses: Dictionary[StringName, int]`; `active_skill_id`/`passive_id` are `StringName` with `&""` = null-equivalent; `level_growth` is non-empty only on CORE parts (schema allows the field on all; the CORE-only rule is validator-enforced in Story 009). Enum declaration form: `enum SlotType { CORE = 1, CHASSIS = 2, CHIPSET = 3, ENERGY_CELL = 4, HEAD = 5, ARMS = 6, LEGS = 7, WEAPON = 8 }` — 0 stays reserved/invalid to catch stale defaults. Include Full-Vision-reserved enum members ONLY if you can guarantee append-only ordering; otherwise omit them until needed (MVP content must never use them — AC-21).

This story is data-shape only: NO formula logic (Stories 004–006), NO validation logic (Stories 007–009), NO loader (Story 003). The deliverable is the classes that everything else types against.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `PartDB` singleton, `load_catalog`, `get_part`/`has_part`
- Stories 004–006: Formulas 1/2/2b/3
- Stories 007–009: the ContentValidator families that enforce field rules
- Story 010: authoring actual `.tres` content

---

## QA Test Cases

*Extracted from GDD AC-20/21/24 + ADR-0003 parse gate. Schema-shape assertions only.*

- **AC-1**: PartDef declares all Rule 1 fields with correct static types
  - Given: a freshly instantiated `PartDef`
  - When: each `@export` property is inspected
  - Then: every Rule 1 field exists with the type from the schema table; `stat_bonuses` is `Dictionary[StringName, int]`; `synergy_tags` is `Array[StringName]`
  - Edge cases: reserved fields (`motherboard_slot_type`, `ram_cost`, `weight_class`, `modification_slots`) exist and read as null/empty on a default instance

- **AC-2**: Enums use explicit integer values from 1
  - Given: `PartDef.SlotType` and the other four enums
  - When: values are read
  - Then: `SlotType.CORE == 1` … `SlotType.WEAPON == 8`; no enum member equals 0; a default (un-set) enum field reads as 0/invalid, distinguishable from any real value
  - Edge cases: assert 0 is NOT a valid MVP value for any content enum

- **AC-3**: PartCatalog holds a typed entries array
  - Given: a `PartCatalog` instance
  - When: `entries` is inspected
  - Then: type is `Array[PartDef]`; empty by default
  - Edge cases: appending a non-PartDef must fail the type check

- **AC-4**: All def scripts parse cleanly (CI parse gate)
  - Given: the `class_name` scripts `PartDef`, `PartCatalog`
  - When: headless script/parse discovery runs
  - Then: both register their `class_name` with zero parse errors
  - Edge cases: none

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/part_database/part_def_schema_test.gd` — must exist and pass (field presence, types, enum integer values, catalog typing)

**Status**: [x] Created and passing — `tests/unit/part_database/part_def_schema_test.gd` (13 tests green; full part_database suite 18/18, 119 asserts, Godot 4.7 + GUT 9.7.1)

---

## Dependencies

- Depends on: Story 001 (typed-dict `.tres` verdict determines whether `stat_bonuses` stays `Dictionary[StringName, int]` or takes the ADR-0003 fallback)
- Unlocks: Story 003, Story 004, Story 006, Story 007

## Completion Notes
**Completed**: 2026-07-15
**Criteria**: 9/9 (8 verified via tests + code review; AC "upgrade_effects entry shape" correctly DEFERRED to Story 009 validator — schema ships `Array[Dictionary]`, per-entry shape not enforceable at schema level)
**Deviations**: ADVISORY — reserved fields = 6 in code (`+critical_output, +firewall`, per TR-part-025 source-of-truth) vs 4 named in GDD Rule 1 / story AC. Code is correct; GDD/story text is the stale side. Logged to tech-debt register.
**Test Evidence**: Logic — `tests/unit/part_database/part_def_schema_test.gd` (18/18 suite green, 119 asserts). BLOCKING gate satisfied.
**Code Review**: Complete — `/code-review` APPROVED (no blocking issues). Enum `= 0` sentinel confirmed warning-free under Godot 4.7 via headless `--check-only`.
