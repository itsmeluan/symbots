# Story 009: ContentValidator — cross-DB referential integrity + level fields

> **Epic**: Part Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-011`, `TR-part-012`, `TR-part-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: The referential-integrity validation family checks Part→Move / Part→Passive resolution across catalogs. The validator is fully DI — it takes all loaded catalogs, so cross-DB checks run against fixture Move/Passive catalogs in unit tests and against the real catalogs at CI/dev-boot. Cross-DB references are `StringName` IDs (`&""` = none), never Resource links.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: This is Integration because it crosses catalog boundaries (Part↔Move↔Passive). AC-13 uses `MoveDatabase.has_skill(id)` / `PassiveDatabase.has_passive(id)` — but the validator resolves against the injected catalogs directly (DI), so it does NOT require the Move/Passive DB *epics* to be built: unit tests supply fixture Move/Passive catalogs. Move DB and Passive DB GDDs are Approved and their `has_*` interfaces are defined, so AC-13 is ACTIVE (not deferred).

**Control Manifest Rules (this layer)**:
- Required: Cross-DB references are `StringName` IDs — never direct Resource references across catalogs — source: ADR-0003
- Required: Route diagnostics through the injected `LogSink` — source: ADR-0002
- Guardrail: linear pass; debug/CI only

---

## Acceptance Criteria

*From GDD AC-13 + Core Progression erratum (level_requirement / level_growth):*

- [ ] AC-13: every non-null (`!= &""`) `active_skill_id` resolves to an existing Move DB entry; every non-null `passive_id` resolves to an existing Passive DB entry — zero dangling references (TR-part-013)
- [ ] `level_requirement` respects rarity floors: COMMON≥1, RARE≥3, BOSS_GRADE≥6, PROTOTYPE≥8; a part may exceed its floor, never go below; `null`/0 defaults to 1 (TR-part-011)
- [ ] `level_growth` is non-empty ONLY on CORE-slot parts; empty/null on all non-CORE parts (TR-part-012)
- [ ] The referential family runs via DI over injected Part + Move + Passive catalogs — exercised in unit tests with fixture Move/Passive catalogs, and mounted on the real catalogs at CI/dev-boot

---

## Implementation Notes

*Derived from ADR-0003 §5 (referential integrity family) + Core Progression erratum 2026-07-12:*

Add these families to the shared `ContentValidator` (Stories 007/008). For AC-13, iterate every part; for each non-`&""` `active_skill_id`, assert the Move catalog contains it; likewise `passive_id` against the Passive catalog. The validator takes the aggregate `ContentCatalogs` (all 6) so the Move/Passive catalogs are already in hand — resolve against them, not against a live autoload (keeps the check DI-testable per ADR-0003).

`level_requirement` floors are per-rarity constants (1/3/6/8) — source from the CP registry constants, not hardcoded. `level_growth` CORE-only: assert `slot_type == CORE or level_growth.is_empty()`. These two fields are CP-defined but hosted in `PartDef` (Core Progression erratum) — Part DB stores + content-validates them; CP owns their runtime meaning. AC-CP-20 (rarity floor) and AC-CP-22 (no-power-stats/25% ceiling) are DoD gates on the Part DB erratum — coordinate with the Core Progression epic if the 25%-ceiling check lands here vs there (this story owns the rarity-floor + CORE-only structural checks; the CP-specific stat-composition checks may belong to the CP epic).

Ship discriminating corrupted fixtures: a dangling `active_skill_id`; a RARE part with `level_requirement = 2` (below floor 3); a non-CORE part with a non-empty `level_growth`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 007/008: schema, enum, content-rule, budget families
- Move DB / Passive DB epics: the actual Move/Passive catalogs + their own validators (this story only checks Part→Move/Passive *resolution*)
- Core Progression epic: the runtime *meaning* of `level_requirement` (equip gate) and `level_growth` (CP-F3 per-level derivation); AC-CP-22 stat-composition specifics if scoped to CP
- Story 010: authoring content + CI wiring

---

## QA Test Cases

*Extracted from GDD AC-13 + Core Progression erratum fields.*

- **AC-1** (GDD AC-13): referential integrity Part→Move/Passive
  - Given: fixture Part + Move + Passive catalogs — one part with `active_skill_id` pointing at a non-existent Move id; one with a valid one; one Core with `passive_id` pointing at a non-existent Passive id
  - When: `validate` runs over the injected catalogs
  - Then: dangling references ERROR; valid references pass; `&""` (none) is skipped, not flagged
  - Edge cases: a part with both fields `&""` passes (Common); dangling `passive_id` on a Boss part errors

- **AC-2** (TR-part-011): level_requirement rarity floors
  - Given: a RARE part with `level_requirement = 2`; a BOSS_GRADE with `= 6`; a COMMON with `= null`
  - When: validated
  - Then: first ERROR (below floor 3); second passes (meets floor 6); third passes (null → defaults to 1, ≥ COMMON floor 1)
  - Edge cases: a RARE with `level_requirement = 8` passes (may exceed floor)

- **AC-3** (TR-part-012): level_growth CORE-only
  - Given: a non-CORE part with `level_growth = {"structure": 2}`; a CORE part with `level_growth = {"energy_capacity": 3}`; a non-CORE with empty `level_growth`
  - When: validated
  - Then: first ERROR; second and third pass
  - Edge cases: a CORE part with empty `level_growth` passes (allowed, just no growth)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/content/part_referential_integrity_test.gd` — must exist and pass; uses fixture Move/Passive catalogs; discriminating corrupted fixtures for dangling ref, sub-floor level, misplaced level_growth

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 (extends the same `ContentValidator`)
- Unlocks: Story 010 (CI mount runs referential integrity against real Part + Move + Passive catalogs)
