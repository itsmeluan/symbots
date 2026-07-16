# Story 011: Validator hardening — Round 10/11 review-debt closure (AC-25/26/27 + fixture sync)

> **Epic**: Part Database
> **Status**: Complete (2026-07-16) — `/code-review` APPROVED WITH SUGGESTIONS (all applied); suite 294/294 green
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: TBD (fill at sprint planning)
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-16

## Context

**GDD**: `design/gdd/part-database.md` (Approved — Round 11, 2026-07-16)
**Requirement**: `TR-part-014`, `TR-part-017`, `TR-part-021`, `TR-part-024` (extended by GDD Round 10/11 ACs — AC-25/26/27 postdate the TR registry snapshot; re-sync the registry as part of this story)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Same DI `ContentValidator` from Stories 007–009 — this story closes the gap between the shipped validator and the GDD's Round 10/11 acceptance criteria. All new checks ERROR-severity; each blocks CI and fail-louds dev boot.

**Engine**: Godot 4.7 | **Risk**: LOW (pure validation + test-fixture sync; no runtime formula changes)
**Engine Notes**: Reuse the existing primary-stat resolution from `_check_primary_stat_bounds` (Arms/Weapon resolve per-part by `damage_type`) for AC-25 — do not duplicate the mapping. Report via `LogSink`, never `push_error()`.

**Why this story exists (review-debt provenance):** The Round-10 review log promised a validator-hardening fast-follow that was never created as a story. The Round-11 re-review (2026-07-16) escalated this: AC-25 and AC-26 have **zero** validator implementation, AC-27's negative bound is missing, and the AC-08(b) GUT fixture no longer matches the amended GDD. The Round-10 log's "ContentValidator enforces every AC" claim overstates the shipped state until this story closes.

**Control Manifest Rules (this layer)**:
- Required: Route all diagnostics through the injected `LogSink` — source: ADR-0002
- Forbidden: `global_push_diagnostics` — source: ADR-0002
- Guardrail: linear pass over catalogs; debug/CI only, zero release cost

---

## Acceptance Criteria

*From GDD AC-25 (Round 11 amended) / AC-26 / AC-27 / AC-08(b):*

- [x] **AC-25 (amended Round 11 — focus = slot primary)**: new `_check_prototype_focus_floor(part)` — for every `PROTOTYPE` entry, resolve `primary_stat` via the slot primary-stat mapping (Arms/Weapon by `damage_type`, exactly as AC-23), then assert (a) `stat_bonuses[primary_stat]` is the part's highest positive bonus (ties permitted — no other stat strictly exceeds it) and (b) `stat_bonuses[primary_stat] > rare_primary_floor[slot]` (strict `>`). Discriminating fixtures: Chassis Prototype `{&"structure": 10, &"armor": 30, &"mobility": -8}` must FAIL (a); Chassis `structure = 29` must FAIL (b); `structure = 30` passes. Error codes: `content_prototype_focus_not_primary`, `content_prototype_focus_below_rare_floor`.
- [x] **AC-26**: new `_check_prototype_drop_conditions(part)` — for every `PROTOTYPE` entry: (a) `drop_conditions.size() >= 3`; (b) `product(multiplier)` over ALL authored conditions `>= 3.0`. Boundary fixtures: 3 × ×1.5 → 3.375 passes; ×1.4/×1.4/×1.5 → 2.94 FAILS (b); 2 × ×2.0 → 4.0 FAILS (a) — both sub-checks independently required. Product uses float accumulation; compare with `>= 3.0 - 1e-9` tolerance per the GDD float-equality warning. Error codes: `content_prototype_too_few_drop_conditions`, `content_prototype_drop_product_low`.
- [x] **AC-27 (negative bound)**: extend `_check_stat_budget` — the positive cap (`v > MAX_SINGLE_STAT`) already ships; add the symmetric negative floor `v < -MAX_SINGLE_STAT` (guards Formula 2b's −55 input floor). The existing loop only inspects `v > 0` — restructure so negatives are checked too. Discriminating fixture: `{&"structure": 40, &"armor": -60}` must FAIL with `content_stat_exceeds_single_cap` (or a dedicated negative-code variant) while passing the total-budget check.
- [x] **AC-08(b) fixture sync**: `tests/unit/part_database/upgrade_formula_test.gd` — replace the base −1 F2b case (expected `[-1, -1, -1, 0, 0, 0]` — non-discriminating: a no-reduction implementation produces the same sequence) with base −3, expected `[-3, -2, -1, 0, 0, 0]`. Python-verified divergents: no-reduction `[-3, -3, -3, 0, 0, 0]`; floor-instead-of-ceil `[-2, -1, 0, 1, 1, 1]`.
- [x] **Entry-shape validators (Story-009 promised, never shipped)**: `upgrade_effects` and `drop_conditions` entries validated for shape — required keys present, correct types (`tier` int 1–5, `multiplier` float > 1.0 per Rule 9 / Drop Rule 5a, `condition` StringName non-empty). Malformed entry → clean `content_*` error, never an engine panic.
- [x] Each new check family ships a discriminating corrupted `.tres` fixture (ADR-0003 Validation Criteria) and GUT tests asserting the exact error code fires — and does NOT fire on compliant content.
- [x] Full suite green; CI gate passes on authored MVP content (if `boltwell_surge_core.tres` / `scrapjaw_scrap_core.tres` or other authored Prototypes violate amended AC-25, fix the CONTENT to focus the slot primary — the rule is normative, user-decided Round 11).

---

## Implementation Notes

*Derived from GDD AC-25/26/27 (Round 10/11) + content_validator.gd current state:*

Wire the three new part checks into the existing per-part dispatch alongside `_check_prototype_balance` / `_check_prototype_concentration`. AC-25 runs only on Prototypes and reuses AC-23's primary-stat resolution — an unresolved primary (bad damage_type) is already flagged by the enum family; skip rather than double-report. Note AC-25's tie rule: a secondary stat EQUAL to the primary passes (a); only a strictly greater one fails.

For AC-26, compute the product over all authored conditions — runtime condition matching is Formula 3's concern, not the validator's. The `> 1.0` multiplier invariant is owned by Rule 9 / Drop System Rule 5a; the entry-shape check enforces it per entry, AC-26 assumes it for the product.

Sync `docs/architecture/tr-registry.yaml`: TR-part-017 text still reads "15–20%" (GDD now "~16.9–20%") and no TR row covers AC-25/AC-27 — add or amend per registry conventions.

## Out of Scope

*Handled elsewhere — do not implement here:*

- Formula implementations (F1/F2/F2b/F3) — shipped and green in Stories 004–006; this story touches only validators, tests, fixtures, and content.
- `stat_bonuses` `Dictionary[StringName, int]` typing — already correct in `part_def.gd:122` (verified 2026-07-16).
- Downstream-GDD errata (Drop System pity note, Synergy focus-stat amplification) — design-side, not validator scope.

## Completion Notes
**Completed**: 2026-07-16
**Criteria**: 7/7 passing (none deferred) — all auto-verified via headless GUT, 294/294 green
**Deviations**: None blocking. Accepted residuals (documented, not tech debt): AC-25(a) co-fires with AC-10 when the primary value ≤ 0 (noisy, never wrong — noted in the validator doc comment); malformed-multiplier entries double-report entry-shape + product-low (independence by design); int multipliers accepted intentionally (`.tres` may serialize small numbers as int).
**Test Evidence**: Logic — `tests/unit/content/part_validator_content_test.gd` (23 Story-011 tests incl. post-review empty-drop_conditions add) + `tests/unit/part_database/upgrade_formula_test.gd::test_upgrade_f2b_base_minus_3_reduces_to_zero`
**Code Review**: Complete — `/code-review` same session, APPROVED WITH SUGGESTIONS; all 4 suggestions applied (empty-drop_conditions test, payload-key `value` rename, dead-assignment cleanup, AC-10 co-fire doc note) and suite re-verified. Two specialist findings were refuted by fact-check: the "blocking" non-Dictionary crash path is unrepresentable (`drop_conditions`/`upgrade_effects` are typed `Array[Dictionary]`, part_def.gd:146/166), and the AC-08(b) floor-variant divergent `[-2,-1,0,1,1,1]` was re-confirmed numerically (the −0.0001 epsilon makes floor ≠ ceil even for integer-exact bases).
