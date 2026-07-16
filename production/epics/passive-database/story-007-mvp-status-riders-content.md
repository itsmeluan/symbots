# Story 007: Three MVP status riders — content authoring

> **Epic**: Passive Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/passive-database.md`
**Requirement**: `TR-pdb-005` (three MVP status riders authored) + `TR-pdb-003` (scope semantics: `WEAPON_ONLY` vs `ANY_DAMAGE`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Content ships as typed `.tres` defs listed in an explicit catalog; every authored def must pass the `ContentValidator` before it is considered shippable. Read-only, frozen at load.

**Engine**: Godot 4.7 | **Risk**: LOW (data authoring against a validated schema; `.tres` round-trip already proven)
**Engine Notes**: Author three `PassiveDef` `.tres` files and register them in the `PassiveCatalog`. The **runtime firing** of these riders (status application, duration, scope gating) is owned by TBC's Rule 13 executor — this story verifies the authored *catalog-contract values* only (trigger / scope / behavior_class / stacking_policy / status payload). The GDD's AC-PDB-04/05/06 runtime assertions are re-verified in the TBC epic against these same defs.

**Control Manifest Rules (this layer)**:
- Required: Content is typed `.tres` in the catalog manifest and passes the `ContentValidator` (CI + dev-boot) — source: ADR-0003
- Forbidden: No directory scanning to discover the riders (`content_dir_scan`); no runtime mutation of the authored defs — source: ADR-0003
- Guardrail: defs are frozen shared instances, read-only at runtime

---

## Acceptance Criteria

*From GDD Rule 5 + TR-pdb-005; catalog-contract portion of AC-PDB-04/05/06:*

- [ ] `volt_shock_on_hit` authored: `behavior_class = STATUS_RIDER`, `trigger_category = ON_HIT`, `scope = ANY_DAMAGE`, `stacking_policy = UNIQUE_PER_TRIGGER`, status payload = Shock / `duration = 1` — **AC-PDB-04** (contract)
- [ ] `thermal_burn_on_weapon` authored: `STATUS_RIDER`, `ON_HIT`, `scope = WEAPON_ONLY`, `UNIQUE_PER_TRIGGER`, status payload = Burn / `duration = 2` — **AC-PDB-05** (contract) / **TR-pdb-003** (scope)
- [ ] `kinetic_stagger_on_hit` authored: `STATUS_RIDER`, `ON_HIT`, `scope = ANY_DAMAGE`, `UNIQUE_PER_TRIGGER`, status payload = Stagger / `duration = 1` — **AC-PDB-06** (contract)
- [ ] All three riders are registered in the `PassiveCatalog` and **pass every `ContentValidator` family** (Stories 004 + 005) with zero errors
- [ ] All three ids resolve through the referential-integrity seam (Story 006) — a Part authoring `passive_id = &"volt_shock_on_hit"` produces no `content_dangling_passive_ref`

---

## Implementation Notes

*Derived from GDD Rule 5 + Rule 3a:*

Author the three `.tres` under the Passive content dir and add them to the `PassiveCatalog` manifest (explicit list — no scan). Their `stacking_policy` must equal the `STATUS_RIDER` default (`UNIQUE_PER_TRIGGER`, Story 003) or Story 004's validator flags them. `passive_class` = `STATUS_RIDER` (metadata). The status name + duration live in `behavior_params` per the STATUS_RIDER payload shape (Story 005 validates the key set). These three riders are *deliberately flat* (they fire identically regardless of build depth per OQ-PDB-1 charter) — do NOT add investment-scaling here; that is the separate OQ-PDB-1 content pass. Evidence is both a GUT content test (asserting the authored contract values) and a smoke check that the catalog loads + validates clean at boot.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- **TBC epic (Rule 13 executor)**: the *runtime* firing verified by the full AC-PDB-04/05/06 (Shock/Burn/Stagger actually applied on hit, scope gating at fire time, NEGATIVE cases like REPAIR-move-applies-nothing), AC-PDB-07/08 (stacking dedup + alphabetical proc-log order), AC-PDB-09/10/11/17 (aura/structure runtime). This story only authors and contract-verifies the defs those tests consume.
- **OQ-PDB-1 content pass (game-designer)**: the MVP Core passive roster (`ON_BATTLE_START`/`ON_OVERHEAT`/`PERSISTENT` Core traits, capped at 5 mechanically-distinct Cores) and the deferred AC-PDB-D1–D4 they activate. Critical-path but a separate content charter, not this Foundation story.

---

## QA Test Cases

- **AC-1** (AC-PDB-04 contract): volt_shock_on_hit values
  - Given: the authored `volt_shock_on_hit.tres` loaded via `PassiveDB`
  - When: its fields are read
  - Then: `behavior_class == STATUS_RIDER`, `trigger_category == ON_HIT`, `scope == ANY_DAMAGE`, `stacking_policy == UNIQUE_PER_TRIGGER`, payload names Shock with `duration == 1`
- **AC-2** (AC-PDB-05 contract / TR-pdb-003): thermal_burn_on_weapon values
  - Given: the authored `thermal_burn_on_weapon.tres`
  - When: read
  - Then: `scope == WEAPON_ONLY`, payload Burn `duration == 2`, all other STATUS_RIDER fields as specified
- **AC-3** (AC-PDB-06 contract): kinetic_stagger_on_hit values
  - Given: the authored `kinetic_stagger_on_hit.tres`
  - When: read
  - Then: `scope == ANY_DAMAGE`, payload Stagger `duration == 1`, all other fields as specified
- **AC-4**: catalog validates clean
  - Given: the `PassiveCatalog` containing all three riders
  - When: the full `ContentValidator` runs
  - Then: zero errors across every Passive family; the three ids are present in the `passive_ids` membership set

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-passive-riders-[date].md` (catalog loads + validates clean at boot) **and** `tests/unit/content/passive_riders_content_test.gd` (authored contract values)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (riders load through `PassiveDB`), Story 004 + Story 005 (riders must pass every validator family), Story 006 (ids resolvable via the referential seam)
- Unlocks: TBC Rule 13 dispatch epic (runtime firing of AC-PDB-04–11, 17 against these defs); Part-DB Rare+ Core `passive_id` authoring once OQ-PDB-1 lands
