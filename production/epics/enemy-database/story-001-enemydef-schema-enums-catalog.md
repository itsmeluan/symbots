# Story 001: EnemyDef schema, enums & EnemyCatalog

> **Epic**: Enemy Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: `TR-edb-001` (typed schema), `TR-edb-011` (stat-key vocabulary), `TR-edb-014` (break_regions `region_fraction` field)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Content ships as typed `.tres` `Resource` defs resolved through one explicit catalog Resource; enums are 1-based with `0 = INVALID` sentinel and APPEND-ONLY; `&""` is the null-equivalent StringName.

**Engine**: Godot 4.7 | **Risk**: MEDIUM (typed-`Array[EnemyDef]` + nested `break_regions`/`loot_pool` dict shapes on the 4.7 `.tres` round-trip — the same HIGH-risk path Part-DB Story 001 spiked)
**Engine Notes**: Mirror `PartDef`/`MoveDef`/`PassiveDef`. `EnemyDef extends Resource`, `@export` every field. Enum `EnemyClass { INVALID = 0, WILD = 1, BOSS = 2 }` — `ELITE`/`RIVAL` are **reserved (do not add yet)** per GDD tier note; APPEND-ONLY. `core_element` reuses the existing `Element` enum and is **nullable** (`&""`/INVALID sentinel — the null-element enemy is a legal authored state, AC-ED-16 integration deferred). `break_regions` and `loot_pool` are `Array[Dictionary]` with the GDD-specified key sets (String keys, matching the Part-DB `_check_boss_break_condition` convention — NOT StringName). Include the ELZS erratum fields `level`, `xp_value`, `completion_bonus_xp`.

**Control Manifest Rules (this layer)**:
- Required: typed `.tres` def + one catalog Resource; enums 1-based with INVALID=0, APPEND-ONLY; `@export` typed fields — source: ADR-0003
- Forbidden: reordering/renumbering enum members; adding `ELITE`/`RIVAL` before their systems exist; hardcoded stat values (data-driven only) — source: ADR-0003 / coding-standards
- Guardrail: schema only — no validation logic here (Stories 004–009), no formula math (Story 003)

---

## Acceptance Criteria

*From GDD Schema section + AC-ED-01 (schema shape portion only — validation lives in Story 004):*

- [ ] `EnemyDef extends Resource` declares all 15 fields with correct static types:
  `id: StringName`, `display_name: String`, `enemy_class: EnemyClass`, `tier: int`,
  `core_element` (Element, nullable), `stats: Dictionary` (11-stat block), `skills: Array[StringName]`,
  `ai_profile: StringName`, `break_regions: Array[Dictionary]`, `loot_pool: Array[Dictionary]`,
  `spawn_enabled: bool`, `flavor_text: String`, `level: int`, `xp_value: int`, `completion_bonus_xp: int`
- [ ] `EnemyClass` enum: `INVALID = 0, WILD = 1, BOSS = 2` (ELITE/RIVAL reserved, not declared)
- [ ] `break_regions` entry shape documented: `region_id`, `region_fraction`, `break_hp`, `break_event`, `loot_*` linkage keys (String keys)
- [ ] `loot_pool` entry shape documented: part `id`, `drop_condition`/`break_event` linkage, `enabled` (String keys)
- [ ] `EnemyCatalog extends Resource` exposes `@export var entries: Array[EnemyDef]`
- [ ] A hand-authored `EnemyDef` `.tres` with nested `break_regions`/`loot_pool`/`stats` round-trips headless: load → every field (incl. nested dict values + StringName keys) equals what was saved

---

## Implementation Notes

*Derived from ADR-0003 + the Part/Move/Passive schema precedent:*

Copy the `PartDef` file layout. `class_name EnemyDef`. Put the enum at the top with the INVALID=0 sentinel. Doc-comment each field with its GDD-sourced meaning and legal range (ranges are *validated* in Stories 004–009, but document them here so the schema is self-describing). The `stats` block keys are the 11-stat vocabulary (TR-edb-011) — document the canonical key set; the dead-data keys (cooling/energy_capacity/recharge — enemies don't use them) are documented as "author 0, warned by Story 005". `EnemyCatalog` mirrors `PartCatalog`/`PassiveCatalog` exactly. **Do not** add an `EnemyDB` loader here (Story 002) or any `_validate_*` method (Stories 004–009). Verify the typed-Dictionary/nested-array `.tres` round-trip headless — this is the one genuinely post-cutoff-risky part; if it fails, it blocks the whole epic (escalate, do not work around).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `EnemyDB` loader + `get_enemy` null-safe lookup
- Story 003: EDB-1 `break_hp` derivation formula
- Stories 004–009: all ContentValidator checks (schema presence, stats, break regions, loot, density, ELZS fields)
- Story 010: authored enemy roster `.tres`

---

## QA Test Cases

- **AC-1** (schema shape): all 15 fields present with correct types
  - Given: a fresh `EnemyDef.new()`
  - When: introspect exported properties
  - Then: every field exists with the declared static type; `enemy_class` defaults to `INVALID`
  - Edge cases: a missing field or a wrong type (e.g. `skills: Array` untyped) fails the check
- **AC-2** (enum contract): `EnemyClass` members and values
  - Given: the `EnemyClass` enum
  - When: read member values
  - Then: `INVALID==0, WILD==1, BOSS==2`; `ELITE`/`RIVAL` are absent
  - Edge cases: a 0-based enum (WILD==0) fails — INVALID sentinel is mandatory
- **AC-3** (nested `.tres` round-trip): the HIGH-risk 4.7 path
  - Given: an `EnemyDef` `.tres` with ≥2 `break_regions`, ≥3 `loot_pool` entries, a full `stats` dict, and StringName `id`/`skills`
  - When: `load()` it headless
  - Then: every scalar, every nested dict value, and every StringName key equals the saved value
  - Edge cases: a StringName-key that deserializes as String, or a truncated nested array, fails — this is the round-trip guarantee the epic depends on

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/enemy_database/enemy_def_schema_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (schema is the epic root)
- Unlocks: Stories 002–010 (every downstream story reads this schema)
