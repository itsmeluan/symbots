# Story 006: ContentValidator break-region family (EDB-3 + stored-equals-derived)

> **Epic**: Enemy Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/enemy-database.md`
**Requirement**: `TR-edb-002` (break_hp stored-equals-derived), `TR-edb-004` (break-region validity EDB-3), `TR-edb-014` (region_fraction bounds [0.15,0.55]), `TR-edb-021` (region break-event set semantics — shared event legal), `TR-edb-022` (minimum 1 break region)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Same single ContentValidator, "extend never fork"; this family extends `_validate_enemy_catalog`; the stored-equals-derived check calls Story 003's `derive_break_hp` (single source of truth for the formula).

**Engine**: Godot 4.7 | **Risk**: MEDIUM (float `region_fraction` bounds compared with an epsilon tolerance; the stored-equals-derived assertion must call the Story-003 function, not re-implement the epsilon)
**Engine Notes**: `EDB-3` region validity = every `break_regions` entry has a unique `region_id`, a `region_fraction` within GDD bounds (compare with ±1e-9 tolerance, not `==` on raw floats), `break_hp == derive_break_hp(structure, region_fraction)` (exact int compare — the formula owns the epsilon), `break_hp < structure` (a break can't require more HP than the enemy has), and each region is loot-connected. **≥1 region required.** A `break_event` shared across regions is **valid set semantics** (EC-ED-07) — do NOT flag it as a uniqueness violation; only `region_id` must be unique. Error codes: `content_enemy_break_*`.

**Control Manifest Rules (this layer)**:
- Required: call Story-003 `derive_break_hp` for the stored-equals-derived check (no re-implemented epsilon); float bounds via epsilon tolerance; diagnostics via injected `LogSink` — source: ADR-0003 / GDD EDB-1/EDB-3
- Forbidden: re-implementing the break_hp formula here; treating a shared `break_event` as a duplicate error; `==` float comparison on `region_fraction` — source: GDD EDB-1 / EC-ED-07
- Guardrail: file-size DoD trigger still applies (see Story 004)

---

## Acceptance Criteria

*From GDD AC-ED-07 (break-region validity), AC-ED-20 (positive shared break_event), EDB-1/EDB-3:*

- [ ] **≥1 region** (AC-ED-07/TR-edb-022): a `break_regions == []` enemy → error naming the id
- [ ] **stored == derived** (TR-edb-002): authored `break_hp` ≠ `derive_break_hp(structure, region_fraction)` → error naming id + region; the 7 known divergent-input fixtures (AC-ED-08 set) each resolve correctly through the shared formula
- [ ] **break_hp < structure**: a region whose `break_hp ≥ structure` → error
- [ ] **region_fraction bounds** (TR-edb-014): a fraction outside the GDD `[min, max]` (±1e-9 tolerance) → error; boundary values → no error
- [ ] **region_id uniqueness** (TR-edb-004): two regions on one enemy sharing a `region_id` → error
- [ ] **loot-connected**: a region referencing no loot linkage that any `loot_pool` entry resolves → error (orphan region)
- [ ] **shared break_event is legal** (AC-ED-20/EC-ED-07/TR-edb-021): two regions with the same `break_event` but distinct `region_id` → **no error** (set semantics, not a duplicate)
- [ ] Error codes: `content_enemy_break_no_regions`, `content_enemy_break_hp_mismatch`, `content_enemy_break_hp_exceeds_structure`, `content_enemy_break_fraction_out_of_range`, `content_enemy_break_region_id_duplicate`, `content_enemy_break_region_orphan`

---

## Implementation Notes

*Derived from ADR-0003 + GDD Formulas EDB-1/EDB-3 + the Part-DB break-condition validator:*

Add to the Story-004 family: `_check_enemy_break_regions` (dispatches the sub-checks per enemy). Sub-checks: non-empty; per-region `derive_break_hp` equality (import the Story-003 function — do NOT paste the `+0.0001`); `break_hp < structure`; `region_fraction` in-bounds with `is_equal_approx`-style tolerance; `region_id` set-uniqueness; loot-connectivity (region's linkage key resolves to ≥1 `loot_pool` entry). Treat `break_event` as a NON-unique tag — its uniqueness is explicitly allowed (AC-ED-20). Build the 7-input divergent fixture set from the GDD AC-ED-08 table so the stored-equals-derived path exercises the same epsilon cases Story 003 unit-tests. Discriminating fixture for the shared-event positive: two regions, same `break_event`, different `region_id` → asserts zero errors (a naive "all region fields unique" impl fails this).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the `derive_break_hp` formula itself (this story *calls* it)
- Story 007: loot-pool referential integrity + rarity + boss-grade gating (this story checks region↔loot *connectivity*, Story 007 checks the loot entries' *validity*)
- Story 012 equivalent / Drop System: the runtime break-event *emission* set semantics (AC-ED-12, DEFERRED)

---

## QA Test Cases

- **AC-1** (stored == derived): epsilon parity with Story 003
  - Given: a region `structure=180, region_fraction=0.35, break_hp=63`; another with `break_hp=62`
  - When: validate
  - Then: 63 → no error; 62 → error naming id + region
  - Edge cases: run all 7 AC-ED-08 divergent inputs — each authored-correct value passes, each off-by-one fails
- **AC-2** (break_hp < structure): can't exceed pool
  - Given: `structure=100, break_hp=100`; `structure=100, break_hp=99`
  - When: validate
  - Then: 100 → error; 99 → no error
- **AC-3** (region_fraction bounds): boundary tolerance
  - Given: a fraction at the GDD min, at max, and just outside max
  - When: validate
  - Then: min & max → no error; outside → error
  - Edge cases: a `==`-on-raw-float impl mis-flags a legal boundary; use tolerance
- **AC-4** (region_id uniqueness vs shared break_event): the key discriminator
  - Given: two regions same `region_id`; two regions same `break_event` but distinct `region_id`
  - When: validate
  - Then: same `region_id` → error; shared `break_event` → **no error**
  - Edge cases: an "all fields unique" impl wrongly errors the shared-event case (AC-ED-20 regression guard)
- **AC-5** (≥1 region + orphan): structural
  - Given: `break_regions=[]`; a region whose loot linkage matches no `loot_pool` entry
  - When: validate
  - Then: empty → error; orphan region → error

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/enemy_break_region_validator_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema), Story 003 (`derive_break_hp`), Story 004 (`_validate_enemy_catalog` family)
- Unlocks: Story 007 (loot validity builds on region↔loot connectivity), Story 010 (authored break tables pass)
