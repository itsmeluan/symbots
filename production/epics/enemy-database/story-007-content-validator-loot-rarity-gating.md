# Story 007: ContentValidator loot-pool, rarity & boss-grade gating family

> **Epic**: Enemy Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: `TR-edb-018` (loot referential integrity + dedup + all-disabled fail), `TR-edb-008` (boss-grade exclusivity: BOSS 1–2, WILD forbidden), `TR-edb-013` (boss-grade product invariant ×500 ≥ 0.5), `TR-edb-009` (floor-loot rarity: Rare/Boss-grade carry ≥1 break condition), `TR-edb-023` (ungated pool parts must be Common), `TR-edb-024` (≥2 break-gated parts advisory)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Same single ContentValidator, "extend never fork"; this family extends `_validate_enemy_catalog`; referential integrity resolves against the **now-Complete Part DB** via `PartDatabase.get_part(id)` (injected, not a hard singleton).

**Engine**: Godot 4.7 | **Risk**: MEDIUM (cross-DB referential resolution; the boss-grade product invariant is a float chain — watch IEEE-754 on the `× 500` gate)
**Engine Notes**: Loot referential integrity resolves each `loot_pool` entry's part `id` through an **injected Part-DB lookup** (Part DB is Complete — wire it live; keep it DI so the unit builds a fake part index). Rarity rules (TR-edb-013): a `WILD` enemy may not carry a boss-grade-exclusive part; a `BOSS` may carry 1–2 boss-grade exclusives. Boss-grade gating (TR-edb-009): the product invariant that a boss-grade drop's expected yield over the gate (`× 500` per the GDD) stays `≥ 0.5` — a break-gated drop must actually be obtainable. Floor-loot rarity (TR-edb-018): the always-available (floor) loot must not exceed the GDD's rarity ceiling. Min break-gated parts (TR-edb-023): a BOSS must gate ≥2 distinct parts behind break regions. Dedup (TR-edb-024): duplicate part ids in one `loot_pool` → warning. A `loot_pool` with **every** entry `enabled == false` → error (an enemy that can drop nothing). Error codes: `content_enemy_loot_*`.

**Control Manifest Rules (this layer)**:
- Required: injected Part-DB lookup for referential checks; class-aware rarity rules; product-invariant math from the GDD; diagnostics via injected `LogSink` — source: ADR-0003 / GDD Rules
- Forbidden: hard `PartDatabase` singleton reference in the unit path; `push_error`/`push_warning`; rarity thresholds not traceable to the GDD — source: ADR-0002/0003
- Guardrail: file-size DoD trigger still applies (see Story 004)

---

## Acceptance Criteria

*From GDD AC-ED-04 (referential), AC-ED-06 (rarity rules), AC-ED-09 (boss-grade gating), AC-ED-18 (floor-loot rarity), AC-ED-19 (min break-gated parts):*

- [ ] **Referential integrity** (AC-ED-04): a `loot_pool` part `id` that the Part DB can't resolve → error naming enemy + part id; all-resolvable → no error
- [ ] **Class/pool rarity** (AC-ED-06): a `WILD` enemy carrying a boss-grade-exclusive part → error; a `BOSS` carrying 1–2 boss-grade exclusives → no error; a `BOSS` carrying 0 or >2 → the GDD-specified verdict (0 may be advisory, >2 error)
- [ ] **Boss-grade gating invariant** (AC-ED-09): a break-gated boss-grade drop whose expected-yield product falls below the GDD floor (0.5 over `× 500`) → error (unobtainable gate)
- [ ] **Floor-loot rarity** (AC-ED-18, ADVISORY): floor (always-available) loot above the GDD rarity ceiling → warning
- [ ] **Min break-gated parts** (AC-ED-19, ADVISORY): a BOSS gating <2 distinct parts behind breaks → warning
- [ ] **All-disabled pool**: every `loot_pool` entry `enabled == false` → error
- [ ] **Dedup** (TR-edb-024, ADVISORY): a duplicate part id within one `loot_pool` → warning
- [ ] Error codes: `content_enemy_loot_unresolved_part`, `content_enemy_loot_rarity_violation`, `content_enemy_loot_boss_grade_ungated`, `content_enemy_loot_all_disabled`, plus warn codes `content_enemy_loot_floor_rarity`, `content_enemy_loot_min_break_gated`, `content_enemy_loot_duplicate_part`

---

## Implementation Notes

*Derived from ADR-0003 + GDD Rules (loot/rarity/gating) + the Part-DB referential seam precedent:*

Add to the Story-004 family: `_check_enemy_loot_referential` (injected Part-DB `Callable`/interface — Part DB is Complete, but keep the seam so the unit builds a fake `has_part`/`get_part`), `_check_enemy_loot_rarity` (class-aware, reads the part's rarity from the resolved `PartDef`), `_check_enemy_loot_boss_grade_gating` (the product-invariant math — pull the `× 500` and `≥ 0.5` from the GDD, python3-verify the boundary fixture since it's a float chain), `_check_enemy_loot_floor_rarity` (warn), `_check_enemy_loot_min_break_gated` (warn, BOSS-only), `_check_enemy_loot_all_disabled`, `_check_enemy_loot_dedup` (warn). The referential check depends on Story 006's region↔loot connectivity being satisfied — these two families compose (connectivity = "region points at a loot entry that exists"; this story = "that loot entry's part id resolves and obeys rarity"). Discriminating fixtures: a WILD carrying a boss-grade part (error) vs a BOSS carrying the same (ok); a boss-grade drop just below vs just above the 0.5 gate floor.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: region↔loot *connectivity* (this story checks the loot entries' *validity*, assuming connectivity holds)
- Story 008: harvest-decision density (`loot_pool > break_regions`) and TTK — those are density/pacing, not referential/rarity
- Drop System (AC-ED-12, DEFERRED): the runtime roll that *awards* these parts

---

## QA Test Cases

- **AC-1** (AC-ED-04 referential): unresolved part
  - Given: a `loot_pool` entry `id = &"part_ghost"` absent from the injected Part DB; another that resolves
  - When: validate
  - Then: ghost → error naming enemy + part; resolvable → no error
  - Edge cases: an empty Part DB makes every entry error (proves the seam is consulted)
- **AC-2** (AC-ED-06 rarity): class-aware boss-grade
  - Given: a WILD carrying a boss-grade-exclusive part; a BOSS carrying the same
  - When: validate
  - Then: WILD → error; BOSS → no error
  - Edge cases: a BOSS carrying 3 boss-grade exclusives → error (>2); a class-blind impl mis-handles both
- **AC-3** (AC-ED-09 boss-grade gating): the product invariant
  - Given: a break-gated boss-grade drop just below the 0.5 floor; one just above
  - When: validate
  - Then: below → error (unobtainable); above → no error
  - Edge cases: python3-verify the boundary; a float-drift impl mis-classifies the exact-0.5 case
- **AC-4** (all-disabled): drop-nothing enemy
  - Given: a `loot_pool` with every entry `enabled == false`
  - When: validate
  - Then: error
  - Edge cases: one enabled entry among disabled → no error
- **AC-5** (AC-ED-18/19/dedup warnings): advisory pacing
  - Given: floor loot above the rarity ceiling; a BOSS gating only 1 part; a duplicate part id in a pool
  - When: validate
  - Then: each → ADVISORY warning; a clean roster → none

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/enemy_loot_validator_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema), Story 004 (`_validate_enemy_catalog` family), Story 006 (region↔loot connectivity), Part DB (Complete — provides the referential lookup)
- Unlocks: Story 008 (harvest-decision density reads the validated loot pool), Story 010 (authored loot passes)
