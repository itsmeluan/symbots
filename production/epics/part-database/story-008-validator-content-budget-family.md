# Story 008: ContentValidator — content-rule, budget & synergy family

> **Epic**: Part Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-15

## Context

**GDD**: `design/gdd/part-database.md`
**Requirement**: `TR-part-004`, `TR-part-005`, `TR-part-007`, `TR-part-014`, `TR-part-022`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Same DI `ContentValidator` from Story 007 — this story adds the content-composition families (range & power caps, economy/composition, and part-specific budget/concentration rules). All ERROR-severity; each blocks CI and fail-louds dev boot.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Pure validation over loaded catalogs. AC-19 (concentration) divides by `positive_total` — AC-10 must run first and guarantee `positive_total > 0` for every Prototype (a Prototype with no positive stats is an AC-10 failure and must not reach AC-19's divisor). Report via `LogSink`, never `push_error()`.

**Control Manifest Rules (this layer)**:
- Required: Route all diagnostics through the injected `LogSink` — source: ADR-0002
- Forbidden: `global_push_diagnostics` — source: ADR-0002
- Guardrail: linear pass over catalogs; debug/CI only, zero release cost

---

## Acceptance Criteria

*From GDD AC-04/10/11/12/19/23 + Stat Budget Reference:*

- [x] AC-04: `synergy_tags` mandatory — element tag on ALL parts (matching `element`); manufacturer tag on non-wild parts; wild parts carry NO manufacturer tag and only valid element strings (TR-part-005)
- [x] AC-10: every Prototype has ≥1 negative AND ≥1 positive `stat_bonuses` value (TR-part-004; also the AC-19 precondition)
- [x] AC-11: every Boss-grade part has ≥1 `drop_conditions` entry with `multiplier >= 500` (so `clamp(0.001×500,0,1) >= 0.5`); empty conditions or max multiplier < 500 → ERROR (TR-part-007)
- [x] AC-12: every part's positive stat spend (`sum(max(0, v))`) falls within the Stat Budget Reference bounds for its slot/rarity
- [x] AC-19: every Prototype has `top_two_sum / positive_total >= 0.70` (70%+ concentration in 1–2 stats); single-positive-stat prototype passes trivially (ratio 1.0) (TR-part-022)
- [x] AC-23: every Common part's primary stat ≤ its slot's Common primary CAP; every Rare part's primary stat ≥ its slot's Rare primary FLOOR (Arms/Weapon split by `damage_type`); empty comparison group passes vacuously + emits an authoring WARNING (TR-part-014)

---

## Implementation Notes

*Derived from GDD Stat Budget Reference + AC-04/10/11/12/19/23:*

Extend the Story 007 `ContentValidator` — same class, more families. Order matters for AC-10 → AC-19: run AC-10 first; if a Prototype fails AC-10 (no positive stat), record the ERROR and skip its AC-19 division (guard `if positive_total == 0: fail; continue`). 

AC-23 is the fiddliest: resolve `primary_stat` via the slot primary-stat mapping table; for Arms/Weapon, split the comparison into PHYSICAL and ENERGY subgroups by each part's `damage_type`. Use the caps/floors tables verbatim (Core 15/23, Chassis 19/29, Chipset 11/17, Energy Cell 12/19, Head 11/17, Arms 12/19, Legs 12/19, Weapon 14/22). An empty subgroup is a vacuous PASS + a WARNING (goes in `warnings`, not `errors`).

AC-12 reads the Stat Budget Reference table (Common/Rare/Boss/Prototype per slot) — source it from config, not hardcoded. Prototype drawback penalties are NOT counted in the positive budget (positive-only sum). The multi-stat cap note (no single stat > 55) is an additional check.

Ship a discriminating corrupted fixture per family (ADR-0003 Validation Criteria).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: Formula 3 math (this story only validates that boss-grade parts *carry* a ≥500 condition — AC-11)
- Story 007: schema/enum/nullability families
- Story 009: cross-DB referential integrity + level fields
- Story 010: authoring the content this validator checks + CI wiring
- Synergy System epic: what the tags *trigger* (thresholds, bonuses) — this story only validates tag *presence/consistency*

---

## QA Test Cases

*Extracted from GDD AC-04/10/11/12/19/23. Clean fixture passes; corrupted fixture fails its named test.*

- **AC-1** (GDD AC-04): synergy tag consistency
  - Given: a wild VOLT part carrying `"boltwell"`; a boltwell part missing `"boltwell"`; a part missing its element tag
  - When: validated
  - Then: each is an ERROR
  - Edge cases: a valid wild part with exactly `["volt"]` passes; a valid boltwell part with `["volt","boltwell"]` passes

- **AC-2** (GDD AC-10 + AC-19): Prototype ± presence and concentration
  - Given: a Prototype with only positive stats (no negative); a Prototype with budget spread evenly (top_two/total < 0.70); a valid concentrated Prototype
  - When: validated
  - Then: first two ERROR; third passes; AC-19 never divides by zero (AC-10 guards)
  - Edge cases: single-positive-stat Prototype → ratio 1.0, passes

- **AC-3** (GDD AC-11): Boss-grade break condition ≥500
  - Given: a Boss-grade with empty `drop_conditions`; one with max multiplier 1.5; one with a ×500 condition
  - When: validated
  - Then: first two ERROR, third passes
  - Edge cases: ×499 fails; ×500 passes (boundary)

- **AC-4** (GDD AC-12): stat budget bounds
  - Given: a Rare Weapon whose positive sum exceeds the Rare Weapon budget ceiling; a single stat > 55
  - When: validated
  - Then: each ERROR
  - Edge cases: a part exactly at the ceiling passes

- **AC-5** (GDD AC-23): Common cap / Rare floor per slot (+ damage_type subgroup)
  - Given: a Common Weapon with primary above its cap (14); a Rare Weapon with primary below its floor (22); a slot subgroup with no Common parts
  - When: validated
  - Then: first two ERROR; the empty subgroup is a vacuous PASS + a WARNING
  - Edge cases: PHYSICAL vs ENERGY Arms compared within their own subgroup, not across

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/content/part_validator_content_test.gd` — must exist and pass; discriminating corrupted fixture per family; asserts the AC-10→AC-19 ordering guard

**Status**: [x] Created and passing — `tests/unit/content/part_validator_content_test.gd` (22 tests, part of the 121/121 suite, 308 asserts, Godot 4.7 + GUT 9.7.1)

---

## Dependencies

- Depends on: Story 007 (extends the same `ContentValidator`)
- Unlocks: Story 010 (CI mount runs these families on real content)

---

## Completion Notes
**Completed**: 2026-07-15
**Criteria**: 6/6 passing (AC-04/10/11/12/19/23) — all COVERED by unit tests
**Deviations**:
- ADVISORY (config boundary): the AC-12/AC-23 budget/cap/floor bounds live in `BalanceConfig` (ADR-0005 "single BalanceConfig") and are read via DI, per the story's "source it from config, not hardcoded". The purely-structural maps (`ELEMENT_TAGS`, `PRIMARY_STAT`, `MANUFACTURER_TAGS`) and fixed design thresholds (`MAX_SINGLE_STAT=55`, `BOSS_BREAK_MIN_MULTIPLIER=500.0`, `CONCENTRATION_MIN=0.70`) stay as validator constants — they are not tuning knobs. This straddles the ADR-0003/ADR-0005 boundary; logged for confirmation.
- ADVISORY (stale label): story header reads "Engine: Godot 4.6" — project is pinned to 4.7 (label swap, not a compat change).
**Test Evidence**: Logic — `tests/unit/content/part_validator_content_test.gd` (22 tests; suite 121/121, 308 asserts). AC-19 ratio (24/35=0.686), AC-11 (499 vs 500), AC-12 single-cap (61-in-budget/56-over-cap) fixtures python3-Fraction-verified as discriminating.
**Code Review**: Complete — inline lean review, verdict APPROVED (ADR-0003/0002/0005 compliant; methods <40 lines, complexity <10; `_cfg != null` gating preserves Story 007's schema-only fixtures).
