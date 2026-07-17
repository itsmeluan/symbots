# Story 003: Sub-pool validation & empty-pool sentinel

> **Epic**: Encounter Zone System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/encounter-zone.md`
**Requirement**: `TR-ez-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping (primary); ADR-0002: Event Bus & Signal Architecture
**ADR Decision Summary**: Sub-pool entries are validated against the typed Enemy-DB catalog (class, `spawn_enabled`, weight) *before* selection; defs are never mutated. Diagnostics (content errors/warnings) flow through the injected LogSink, not the global logger.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: `filter_valid` runs before EZ-2 and recomputes `total_weight` from survivors. The sentinel is `StringName("")` (empty StringName) — the caller treats it as "no encounter this step" and starts no battle. Enemy-DB reads go through the injected reader interface (a stub in tests); no `DirAccess` content-directory scanning, no def mutation.

**Control Manifest Rules (this layer)**:
- Required: read-only Enemy-DB access via injected reader; diagnostics via LogSink `warn(code, detail)`; pure core in `src/core/encounter_zone/`.
- Forbidden: mutating or `duplicate()`-ing Enemy defs; `push_warning`/`push_error` from `src/`; content-directory `DirAccess` scanning.
- Guardrail: severity discipline — missing/wrong-class/negative-weight = **error**; zero-weight = **warning** (distinct severities, AC-EZ-32 vs 33).

---

## Acceptance Criteria

*From GDD `design/gdd/encounter-zone.md`, scoped to this story:*

- [ ] **AC-EZ-26** (BLOCKING, Unit): empty sub-pool *(verifies EC-EZ-01)*. GIVEN `enemy_subpool = []`, forced EZ-1 trigger, THEN EZ-2 returns `StringName("")`, content error logged (naming `terrain_type` + `zone_id`), no crash, stub caller starts no battle.
- [ ] **AC-EZ-27** (BLOCKING, Unit): disabled enemy excluded *(verifies EC-EZ-02 + EC-EZ-10)*. pool `{iron_crawler w10, retired_bot w10}`, `retired_bot spawn_enabled=false`, 1,000 draws → `retired_bot` never returned, `iron_crawler` all 1,000, no error for iron_crawler.
- [ ] **AC-EZ-28** (BLOCKING, Unit): missing enemy excluded + error. pool `{known_enemy w10, ghost_id w5}`, `ghost_id` has no entry → error logged naming ghost_id, contributes 0 to `total_weight`, only `known_enemy` returned.
- [ ] **AC-EZ-29** (BLOCKING, Unit): all-disabled drains to empty → chains to EC-EZ-01 (sentinel + error). Tests composition of EC-EZ-02 exclusion into EC-EZ-01.
- [ ] **AC-EZ-30** (BLOCKING, Unit): BOSS in terrain pool excluded *(verifies EC-EZ-03)*. `{iron_crawler w10 WILD, zone_boss_1 w5 BOSS}` → error naming zone_boss_1 + slot, excluded from `total_weight`, only iron_crawler returned.
- [ ] **AC-EZ-32** (BLOCKING, Unit): `spawn_weight = 0` excluded with **warning** *(verifies EC-EZ-04 — zero)*. `{iron_crawler w10, empty_shell w0, volt_drone w5}` → warning (not error) for empty_shell, `total_weight = 15`, empty_shell never returned.
- [ ] **AC-EZ-33** (BLOCKING, Unit): negative weight → **error**, excluded *(verifies EC-EZ-04 — negative)*. `{iron_crawler w10, corrupt_entry w−3}` → error (severity distinct from the w0 warning), excluded, `total_weight = 10`.

---

## Implementation Notes

*Derived from ADR-0003 + ADR-0002 Implementation Guidelines:*

- Implement `filter_valid(raw_subpool) -> Array[SpawnEntry]`: exclude an entry when its `enemy_id` resolves to no Enemy-DB entry (error), resolves to a `spawn_enabled == false` entry (silent exclusion, no error — retirement is graceful per EC-EZ-10), resolves to a non-`WILD` class in a terrain slot (error), or has `spawn_weight <= 0` (weight 0 → **warning**; weight < 0 → **error**). Recompute `total_weight` from survivors only.
- Missing-ID is an error *and* an exclusion; disabled is exclusion *without* error. Keep the two apart — AC-EZ-27 asserts no error fires for the surviving enemy, AC-EZ-28 asserts an error fires for the missing one.
- Empty-after-filter (or empty as authored) → return sentinel `StringName("")` and log a content error naming `terrain_type` + `zone_id` (EC-EZ-01). The forced-trigger caller must observe the sentinel and start no battle.
- Zero vs negative weight carry **distinct severities** by design (EC-EZ-04) — surface the severity in the LogSink call so AC-EZ-32/33 can assert on it.
- All Enemy-DB reads go through the injected reader stub; never touch the real catalog files or mutate a def.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the cumulative-weight walk itself (this story feeds it a clean pool).
- Story 007: WILD-in-boss-slot handling (AC-EZ-31) — the *boss-slot* class check lives with gate-param validation; this story owns only the BOSS-in-*terrain*-pool exclusion (AC-EZ-30).
- Story 008: the offline content-validation linters (this story's checks run in the live resolution path, not as an offline linter).

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-EZ-26**: empty pool.
  - Given: patch with `enemy_subpool = []`; spy LogSink; forced EZ-1 trigger; stub caller.
  - When: resolution runs.
  - Then: EZ-2 returns `StringName("")`; error logged naming terrain_type + zone_id; caller records zero battles started.
- **AC-EZ-27**: disabled excluded.
  - Given: `{iron_crawler w10, retired_bot w10}`, `retired_bot spawn_enabled=false`; seeded RNG.
  - When: 1,000 selections.
  - Then: iron_crawler 1,000, retired_bot 0; no error for iron_crawler.
- **AC-EZ-28**: missing excluded + error.
  - Given: `{known_enemy w10, ghost_id w5}`, `ghost_id` absent from stub DB.
  - When: filter + selections.
  - Then: error names ghost_id; `total_weight == 10`; only known_enemy returned.
- **AC-EZ-29**: drains to empty.
  - Given: pool where every entry is `spawn_enabled=false`.
  - When: filter + forced trigger.
  - Then: sentinel `StringName("")` + EC-EZ-01 error.
- **AC-EZ-30**: BOSS in terrain pool.
  - Given: `{iron_crawler w10 WILD, zone_boss_1 w5 BOSS}` in a terrain patch.
  - When: filter + selections.
  - Then: error names zone_boss_1 + slot; `total_weight == 10`; only iron_crawler returned.
- **AC-EZ-32**: zero weight → warning.
  - Given: `{iron_crawler w10, empty_shell w0, volt_drone w5}`.
  - When: filter + selections.
  - Then: **warning** (assert severity) for empty_shell; `total_weight == 15`; empty_shell never returned.
- **AC-EZ-33**: negative weight → error.
  - Given: `{iron_crawler w10, corrupt_entry w−3}`.
  - When: filter.
  - Then: **error** (assert severity, distinct from the w0 warning); excluded; `total_weight == 10`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/encounter_zone/ez2_subpool_validation_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (value types + resolver host + injected Enemy-DB reader).
- Unlocks: Story 004 (handoff resolves against a validated pool).
