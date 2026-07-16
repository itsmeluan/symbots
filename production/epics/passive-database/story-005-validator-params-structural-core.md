# Story 005: Passive validator — behavior_params, STRUCTURAL non-negative & Core restriction

> **Epic**: Passive Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/passive-database.md`
**Requirement**: `TR-pdb-006` (behavior_params schema per class), `TR-pdb-007` (STRUCTURAL_EFFECT amount non-negative), `TR-pdb-008` (Core passive trigger whitelist)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: The `ContentValidator` enforces per-field authoring rules with typed, id-naming errors; content is rejected at authoring/CI time, never silently coerced. Pure catalog-in → error-list-out.

**Engine**: Godot 4.7 | **Risk**: LOW (dict-shape + numeric-sign checks; no post-cutoff API)
**Engine Notes**: `behavior_params` is an untyped `Dictionary`; validate its key set against the `behavior_class` (Rule 3a): `STAT_AURA → {stat: StringName, delta: int}`, `RESOURCE_EFFECT → {resource, amount}`, `STRUCTURAL_EFFECT → {target, amount}` (amounts non-negative for both `CURRENT_STRUCTURE` and `MAX_STRUCTURE` targets), `STATUS_RIDER → status payload keys`. Use String keys for untyped entry dicts consistent with the existing validator convention (`_check_boss_break_condition` in `content_validator.gd`); `StringName` only for stat keys / error codes.

**Control Manifest Rules (this layer)**:
- Required: A dev-boot + CI `ContentValidator` rejects malformed content with a typed, id-naming error — source: ADR-0003
- Forbidden: Never mutate/`duplicate()` a def inside the validator; never widen the STRUCTURAL non-negative rule without a GDD change (negative structural is a deliberate MVP non-goal, GDD Formulas note) — source: ADR-0003 / GDD
- Guardrail: validator is pure and deterministic

---

## Acceptance Criteria

*From GDD Rule 3a + Formulas + Rule 6 + AC-PDB-12/14/16:*

- [ ] A passive whose `behavior_params` does not match its `behavior_class` — missing a required key, wrong key set — is rejected, naming the id and the offending field — **AC-PDB-16** (params half)
- [ ] A `STRUCTURAL_EFFECT` with a **negative** `amount` for **either** target (`CURRENT_STRUCTURE` or `MAX_STRUCTURE`) is rejected, naming the id and field — **AC-PDB-16** (structural half) / **TR-pdb-007** *(verifies EC-PDB-08 authoring path)*
- [ ] A `CORE_TRAIT` passive (`passive_class = CORE_TRAIT`) authored with `trigger_category: ON_HIT` — or any trigger outside `{ON_BATTLE_START, ON_OVERHEAT, PERSISTENT}` — is flagged, naming the passive id — **AC-PDB-12** / **TR-pdb-008** *(verifies EC-PDB-07 authoring path)*
- [ ] Boss-grade / Prototype Core passives sharing an identical `trigger_category` + `behavior_class` combo are flagged as duplicates, naming both passive ids — **AC-PDB-14**

---

## Implementation Notes

*Derived from ADR-0003 + GDD Rule 3a / Formulas / Rule 6:*

Add a Passive authoring-rules family to `ContentValidator` (same gate as Story 004: `catalogs.passives != null`). Error codes (new): `content_passive_params_mismatch` (`{id, field}`), `content_passive_negative_structural` (`{id, target}`), `content_core_illegal_trigger` (`{id, trigger}`), `content_core_duplicate_combo` (`{id_a, id_b, trigger, behavior}`). The Core-trigger whitelist (`ON_BATTLE_START`/`ON_OVERHEAT`/`PERSISTENT`) is Rule 6; note the runtime "`passive_class` is metadata, fires anyway" behaviour is TBC's, NOT re-checked here (EC-PDB-07). The AC-PDB-14 uniqueness check only bites once OQ-PDB-1 authors Core content — it is inert (zero Core passives) until then, so it must not error on an all-rider MVP catalog. AC-PDB-12/14/16 are ADVISORY-DEFERRED in the GDD, but the *validator code + unit tests* land now so the seam is ready when content arrives — this mirrors how Part-DB shipped its validators ahead of full content.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 004: legality matrix + stacking + structural-schema field presence
- Story 006: cross-DB dangling `passive_id` references (AC-PDB-13)
- Story 007 / OQ-PDB-1: the actual Core passive *content* the uniqueness check will police
- TBC epic: runtime clamps and "fires anyway" dispatch (AC-PDB-10/11/17 and the runtime half of EC-PDB-07/08)

---

## QA Test Cases

- **AC-1** (AC-PDB-16 params): params/class mismatch
  - Given: a `STAT_AURA` passive whose `behavior_params` omits `delta`
  - When: the validator runs
  - Then: one `content_passive_params_mismatch` naming the id and the missing field
  - Edge cases: a `RESOURCE_EFFECT` with an extra/unknown key errors; a well-formed payload for each class passes
- **AC-2** (AC-PDB-16 structural / TR-pdb-007): negative structural rejected
  - Given: a `STRUCTURAL_EFFECT` with `amount = -20` on `CURRENT_STRUCTURE`
  - When: the validator runs
  - Then: one `content_passive_negative_structural` naming the id and target
  - Edge cases: negative on `MAX_STRUCTURE` also rejected; `amount = 0` and positive amounts pass
- **AC-3** (AC-PDB-12 / TR-pdb-008): Core illegal trigger
  - Given: a `CORE_TRAIT` passive with `trigger_category = ON_HIT`
  - When: the validator runs
  - Then: one `content_core_illegal_trigger` naming the id
  - Edge cases: `CORE_TRAIT` + `ON_BATTLE_START`/`ON_OVERHEAT`/`PERSISTENT` all pass; a non-Core (`STATUS_RIDER`) passive + `ON_HIT` is NOT flagged by this rule
- **AC-4** (AC-PDB-14): Core combo duplication
  - Given: two Boss/Prototype Core passives sharing `trigger_category` + `behavior_class`
  - When: the validator runs
  - Then: one `content_core_duplicate_combo` naming both ids
  - Edge cases: a catalog with **zero** Core passives (MVP-riders-only) produces no Core errors of any kind

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/content/passive_validator_authoring_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (validator runs over a loaded catalog)
- Unlocks: Story 007 (riders must pass this validator)
