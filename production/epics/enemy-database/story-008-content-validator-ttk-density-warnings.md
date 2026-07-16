# Story 008: ContentValidator harvest-decision, TTK & density/spawn warnings

> **Epic**: Enemy Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: `TR-edb-007` (EDB-2 TTK calibration), `TR-edb-010` (harvest-decision `loot_pool > break_regions`), `TR-edb-020` (null-element density cap)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Same single ContentValidator, "extend never fork"; this family extends `_validate_enemy_catalog`. EDB-2 is an **ADVISORY computed check** (pacing sanity, not a hard gate); the harvest-decision rule is the one **BLOCKING** check here.

**Engine**: Godot 4.7 | **Risk**: MEDIUM (EDB-2 is a dual-channel armor/resist TTK computation over `BalanceConfig` — a float band comparison; keep it ADVISORY so a near-boundary tune doesn't red the build)
**Engine Notes**: **BLOCKING** (TR-edb-010): every enemy must satisfy `loot_pool.size() > break_regions.size()` — the harvest-decision invariant (there must be at least one non-break drop so breaking is a *choice*, not the only path). **ADVISORY** (TR-edb-007/EDB-2): compute a rough time-to-kill using the GDD EDB-2 calibration (dual-channel — armor vs a kinetic attacker, resist vs an elemental attacker) against the `BalanceConfig` reference attacker; a TTK outside the GDD pacing band → warning naming the id + computed TTK. **ADVISORY** (TR-edb-020): a null-`core_element` enemy count exceeding the GDD density cap → warning (null-element is a legal but rationed authored state). **ADVISORY**: a `spawn_enabled == false` BOSS → progression warning (a disabled boss silently removes a gate). Error codes: `content_enemy_harvest_decision` (error), warn codes `content_enemy_ttk_out_of_band`, `content_enemy_null_element_density`, `content_enemy_boss_spawn_disabled`.

**Control Manifest Rules (this layer)**:
- Required: harvest-decision is BLOCKING; TTK/density/spawn checks are ADVISORY (`_warn` only); EDB-2 reads the single `BalanceConfig` reference attacker; diagnostics via injected `LogSink` — source: ADR-0003 / GDD EDB-2
- Forbidden: making TTK a hard error (it's a tuning advisory); re-deriving balance constants inline (read `BalanceConfig`); `push_error`/`push_warning` — source: ADR-0003/0005
- Guardrail: file-size DoD trigger still applies (see Story 004)

---

## Acceptance Criteria

*From GDD AC-ED-14 (TTK), AC-ED-15 (density + harvest-decision), AC-ED-17 (spawn-disabled BOSS):*

- [x] **Harvest-decision** (AC-ED-15c/TR-edb-010, BLOCKING): `loot_pool.size() ≤ break_regions.size()` → error naming the id; strictly-greater → no error — `enemy_validator.gd:762`, tests `test_harvest_*`
- [x] **EDB-2 TTK band** (AC-ED-14, ADVISORY): computed dual-channel TTK outside the GDD pacing band → warning naming id + computed TTK (armor and resist channels each evaluated) — `enemy_validator.gd:787`, tests `test_ttk_*`
- [x] **Content density** (AC-ED-15a/b, ADVISORY): pool/region density counts outside the GDD guideline → warning — `enemy_validator.gd:839`, tests `test_density_*`
- [x] **Null-element density** (AC-ED-15d/TR-edb-020, ADVISORY): null-`core_element` enemy count over the GDD cap → warning — `enemy_validator.gd:874`, tests `test_null_element_*`
- [x] **Spawn-disabled BOSS** (AC-ED-17, ADVISORY): a BOSS with `spawn_enabled == false` → progression warning — `enemy_validator.gd:862`, tests `test_spawn_*`
- [x] Error code `content_enemy_harvest_decision`; warn codes `content_enemy_ttk_out_of_band`, `content_enemy_density_guideline`, `content_enemy_null_element_density`, `content_enemy_boss_spawn_disabled`

---

## Implementation Notes

*Derived from ADR-0003 + GDD Formula EDB-2 + ADR-0005 `BalanceConfig`:*

Add to the Story-004 family: `_check_enemy_harvest_decision` (the sole BLOCKING check — `loot_pool.size() > break_regions.size()`), `_check_enemy_ttk_band` (compute EDB-2 both channels against the injected `BalanceConfig` reference attacker; warn on out-of-band — python3-verify the band edges since it's float), `_check_enemy_content_density` (warn), `_check_enemy_null_element_density` (catalog-level count, warn), `_check_enemy_boss_spawn` (warn). The harvest-decision check is the one that must go red in CI — a `≥` off-by-one impl (allowing equal) is the canonical discriminator (equal counts mean breaking is forced, violating the design intent). Keep EDB-2 strictly `_warn` — it's a pacing smell, and a legitimately spiky boss may sit outside the band by design; the warning surfaces it for a human, it does not block. Read all bands/caps from the GDD + `BalanceConfig`; invent nothing.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006/007: break-region validity and loot referential/rarity (this story counts them for density, doesn't re-validate them)
- Encounter Zone (AC-ED-11, DEFERRED): the spawn-table *exclusion* of `spawn_enabled == false` enemies at runtime (this story only *warns* about disabled BOSSes at author time)
- TBC (AC-ED-16, DEFERRED): the null-element *damage path* (this story only rations null-element *authoring density*)

---

## QA Test Cases

- **AC-1** (AC-ED-15c harvest-decision): the BLOCKING discriminator
  - Given: an enemy with `loot_pool.size()==2, break_regions.size()==2` (equal); another `3` vs `2`
  - When: validate
  - Then: equal → error; 3-vs-2 → no error
  - Edge cases: a `≥` impl wrongly passes the equal case — equal counts force breaking, violating the design; 1-vs-2 (fewer loot than regions) → error
- **AC-2** (AC-ED-14 TTK, ADVISORY): dual-channel band
  - Given: an enemy tuned inside the band; one with armor so high the kinetic channel TTK exceeds the band
  - When: validate
  - Then: in-band → no warning; out-of-band → warning naming id + computed TTK; never an error
  - Edge cases: the resist channel is evaluated independently — a high-resist enemy warns on the elemental channel even if the armor channel is fine
- **AC-3** (AC-ED-17 spawn-disabled BOSS): progression warning
  - Given: a BOSS `spawn_enabled == false`; a WILD `spawn_enabled == false`
  - When: validate
  - Then: BOSS → warning; WILD → no warning (only BOSSes gate progression)
- **AC-4** (AC-ED-15d null-element density, ADVISORY): rationed authoring
  - Given: a catalog whose null-`core_element` count exceeds the GDD cap; one within cap
  - When: validate
  - Then: over-cap → warning; within → none

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/enemy_density_validator_test.gd` — must exist and pass

**Status**: [x] Created — 21 test functions, all green. Full suite 612/612 passing (was 591; +21 this story, sibling fixtures repaired for the new BLOCKING harvest-decision + WILD/BOSS density bands). TTK integer-ceil arithmetic python3-verified (zero divergences vs `math.ceil`; reproduces both GDD worked fixtures dmg 48→TTK 9, dmg 24→TTK 17).

---

## Dependencies

- Depends on: Story 001 (schema), Story 004 (`_validate_enemy_catalog` family), Story 007 (loot pool counts), ADR-0005 `BalanceConfig` (EDB-2 reference attacker)
- Unlocks: Story 010 (authored roster passes harvest-decision + advisory bands)
