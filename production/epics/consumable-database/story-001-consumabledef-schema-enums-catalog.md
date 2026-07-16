# Story 001: ConsumableDef schema, enums & ConsumableCatalog

> **Epic**: Consumable Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/consumable-database.md`
**Requirement**: `TR-cdb-001` (typed `.tres` def declaring `effect_type` + matching `effect_params`; one catalog per DB)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Typed `Resource` def per entity, all fields `@export` + typed; enums declare explicit integer values starting at 1 (0 = reserved/invalid) and are APPEND-ONLY; cross-DB references are `StringName` IDs (`&""` = none), never `Resource` links; one `Catalog` resource per DB (explicit manifest, no directory scanning).

**Engine**: Godot 4.7 | **Risk**: MEDIUM (typed-field `.tres` round-trip; `Dictionary[StringName,int]` was proven by Part-DB Story 001. `effect_params` here is an *untyped* `Dictionary`, strictly safer, so no new spike is required)
**Engine Notes**: `effect_params` is `Dictionary`/`{}` — its key set is per-`effect_type` (validated in Story 007; the schema stores it untyped). All new enums start at 1 (0 = INVALID sentinel) and are APPEND-ONLY. `consumable_id` is a `StringName` (`&""` = null-equivalent / invalid).

**Control Manifest Rules (this layer)**:
- Required: Content ships as typed `.tres` defs resolved through an explicit catalog; `@export` enums start at 1 (0 reserved) and are APPEND-ONLY — source: ADR-0003
- Forbidden: Never reorder/insert/renumber existing content-def enum values (`content_enum_reordering`); never `duplicate()`/mutate a content def; never `DirAccess`-scan the content dir in the load path — source: ADR-0003
- Guardrail: def is a frozen shared instance, read-only at runtime

---

## Acceptance Criteria

*From GDD Rule 1 + Rule 2, backing the schema for AC-CD-15/17/18/19:*

- [ ] `ConsumableDef extends Resource` with `class_name ConsumableDef`; every field `@export` + statically typed
- [ ] Fields (Rule 1 table): `consumable_id: StringName`, `display_name: String`, `rarity: Rarity`, `effect_type: EffectType`, `effect_params: Dictionary`, `use_context: UseContext`, `target: Target`, `max_stack: int`, `buy_price: int`, `sell_price: int`
- [ ] Enums with explicit int values from 1 (0 = INVALID/reserved), APPEND-ONLY: `Rarity {COMMON, RARE, PROTOTYPE, BOSS_GRADE}`, `EffectType {RESTORE_STRUCTURE, REDUCE_HEAT, RESTORE_ENERGY, BOOST_DROP, MODIFY_ENCOUNTER_RATE}`, `UseContext {BATTLE, WORLD, BOTH}`, `Target {LIVING_TEAM_MEMBER, CURRENT_BATTLE, OVERWORLD}`
- [ ] A `ConsumableDef.new()` bare instance has all enums at the 0 INVALID sentinel and `effect_params == {}`
- [ ] `ConsumableCatalog extends Resource` with `class_name ConsumableCatalog`, `@export var entries: Array[ConsumableDef]`

---

## Implementation Notes

*Derived from ADR-0003 §1–2 + GDD Rule 1 / Rule 2:*

Mirror `PartDef`/`PartCatalog`, `MoveDef`/`MoveCatalog`, `PassiveDef`/`PassiveCatalog` exactly. All enums default to their 0 INVALID sentinel; `effect_params` defaults to `{}`. `buy_price`/`sell_price` are authored now but inert in MVP (no shops) — they still ship as typed fields (the `buy > sell` invariant is enforced in Story 007). `effect_params` stays *untyped* `Dictionary` — the per-`effect_type` key set (`amount:int` / `multiplier:float` / `{rate_multiplier:float, duration_steps:int}`) is a validator concern (Story 007), not a schema-type concern. Doc-comment every public field. No logic in this story beyond the schema. Verify a round-trip `.tres` save/load preserves the enum ints and the `effect_params` dict headlessly.

Place `consumable_def.gd` and `consumable_catalog.gd` in `src/core/content/` alongside the other DB schema files.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 002: the `ConsumableDB` loader/index and null-safe lookup
- Story 003: the CD-1/2/3 restore formulas
- Story 004: use-transaction validation, targeting, resource-neutrality
- Stories 005/006: Beacon flag / encounter-modifier runtime state
- Story 007: all ContentValidator checks (`effect_params` shape, `buy > sell`, unknown `effect_type`, roster)
- Story 008: the 8 MVP `.tres` entries + catalog
- **Cross-system integration** (AC-CD-20/21/22/23): TBC use-item action, Drop channel, Encounter Zone hook, Inventory overflow — owned by those epics' errata, NOT this DB. This story authors the static *contract* only.

---

## QA Test Cases

- **AC-1**: schema shape
  - Given: a fully-populated `ConsumableDef`
  - When: the fields are read
  - Then: all 10 fields (`consumable_id, display_name, rarity, effect_type, effect_params, use_context, target, max_stack, buy_price, sell_price`) are present and statically typed
  - Edge cases: a `ConsumableDef.new()` bare instance has all 4 enums at 0 (INVALID) and `effect_params == {}`
- **AC-2**: enum integrity
  - Given: each of the 4 enums
  - When: values are read
  - Then: no value is 0 (0 stays reserved/INVALID); values are contiguous from 1; `Rarity` has no `BOSS_GRADE` gap (it is present as a reserved value but unauthored in MVP)
- **AC-3**: `.tres` round-trip
  - Given: a `ConsumableDef` saved to a `.tres` then loaded headlessly
  - When: the loaded def is read
  - Then: every enum int and the `effect_params` dict match the saved values exactly (e.g. `{"amount": 50}` and `{"rate_multiplier": 0.1, "duration_steps": 20}`)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/consumable_database/consumable_def_schema_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Part-DB Story 001 spike already de-risked typed-field `.tres` round-trips)
- Unlocks: Story 002 (loader), Story 003 (formulas read the schema), Story 007 (validation reads the schema), Story 008 (content authored against the schema)
