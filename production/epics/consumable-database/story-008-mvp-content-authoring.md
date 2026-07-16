# Story 008: MVP content authoring — 8 consumable `.tres` + catalog

> **Epic**: Consumable Database
> **Status**: Done
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/consumable-database.md`
**Requirement**: `TR-cdb-001` (realized content), `TR-cdb-006` (buy>sell per entry), `TR-cdb-008` (flat-integer magnitudes) — all realized as authored data
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping — pure data configuration against the Story-001 schema.
**ADR Decision Summary**: Content ships as typed `.tres` defs resolved through one explicit catalog; validated at CI + dev-boot by the ContentValidator.

**Engine**: Godot 4.7 | **Risk**: LOW (data authoring against a proven schema; validated by Story 007's family)
**Engine Notes**: Author 8 `ConsumableDef` `.tres` in `assets/data/consumables/` + one `ConsumableCatalog` `.tres` in `assets/data/catalogs/` referencing all 8 (mirrors the passive catalog). All values come from GDD Rule 10 + Tuning Knobs — no invented numbers. `effect_params` uses the per-type key set; StringName keys where the sibling `.tres` do.

**Control Manifest Rules (this layer)**:
- Required: content is data-driven `.tres`, resolved via the explicit catalog; passes the ContentValidator at CI/boot — source: ADR-0003
- Forbidden: `BOSS_GRADE` consumable (reserved); `buy_price ≤ sell_price`; magic magnitudes not traceable to the GDD Tuning Knobs — source: GDD Rule 8 / Rule 10
- Guardrail: exactly 8 entries, 6 effect concepts, no BOSS_GRADE (AC-CD-18)

---

## Acceptance Criteria

*From GDD Rule 10 + Tuning Knobs, realizing AC-CD-18/19:*

- [ ] 8 `ConsumableDef` `.tres` authored with the exact GDD values:
  - Weld Patch (COMMON, RESTORE_STRUCTURE `amount=25`, BOTH, buy 12 / sell 2, max_stack 20)
  - Repair Kit (RARE, RESTORE_STRUCTURE `amount=50`, BOTH, buy 36 / sell 8, max_stack 10)
  - Field Forge (PROTOTYPE, RESTORE_STRUCTURE `amount=120`, BOTH, buy 75 / sell 15, max_stack 5)
  - Coolant Flush (COMMON, REDUCE_HEAT `amount=50`, BOTH, buy 12 / sell 2, max_stack 20)
  - Power Cell (COMMON, RESTORE_ENERGY `amount=25`, BOTH, buy 12 / sell 2, max_stack 20)
  - Salvage Beacon (RARE, BOOST_DROP `multiplier=2.0`, BATTLE, buy 48 / sell 10, max_stack 10)
  - Signal Jammer (RARE, MODIFY_ENCOUNTER_RATE `{rate_multiplier=0.1, duration_steps=20}`, WORLD, buy 45 / sell 10, max_stack 10)
  - Scrap Lure (COMMON, MODIFY_ENCOUNTER_RATE `{rate_multiplier=2.5, duration_steps=15}`, WORLD, buy 15 / sell 3, max_stack 20)
- [ ] `target` coherent per entry: restoratives `LIVING_TEAM_MEMBER`, Beacon `CURRENT_BATTLE`, Jammer/Lure `OVERWORLD` (AC-CD-19)
- [ ] One `ConsumableCatalog` `.tres` references all 8; the ContentValidator (Story 007) passes with 0 errors, 0 roster/coherence warnings

---

## Implementation Notes

*Derived from GDD Rule 10 + Tuning Knobs tables:*

Every number is in the GDD — do not invent. Effect magnitudes from the Effect-magnitudes table; prices from the Buy/sell table; stack caps from the Stack-caps table (C20 / R10 / P5). Wire the catalog exactly like `assets/data/catalogs/passive_catalog.tres`. After authoring, run the suite headless — Story 007's `_validate_consumable_catalog` must pass clean. Produce a smoke doc recording the validator pass + a spot-check that each `effect_params` round-trips.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 007: the validator family that lints this content (this story produces the content it lints)
- The runtime that *applies* these effects (Stories 003–006 deliver the logic; TBC/Drop/EZ errata wire it live)
- Icons / VFX (VA-1/2/3 — Art Bible / Combat UI, not this DB)

---

## QA Test Cases

**Config/Data — smoke check:**

- **Setup**: load the authored `ConsumableCatalog` headless through the ContentValidator (Story 007 family active)
- **Verify**: 8 entries; each `effect_params` well-formed per `effect_type`; every `buy_price > sell_price`; no `BOSS_GRADE`; context/target coherent per entry
- **Pass condition**: validator returns `ok == true`, 0 errors, 0 roster/coherence warnings; full GUT suite green

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass — `production/qa/smoke-consumables-[date].md`

**Status**: [x] Passing — full GUT suite 452/452 green (2026-07-16)

---

## Dependencies

- Depends on: Story 001 (schema), Story 007 (validator lints this content)
- Unlocks: Drop System / TBC / Encounter Zone errata (they read this authored content)
