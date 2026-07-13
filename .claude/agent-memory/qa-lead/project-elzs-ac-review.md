---
name: project-elzs-ac-review
description: Enemy Level & Zone Scaling GDD AC review history — round 3 findings; 5 blockers, 7 recommended, 2 NICE-TO-HAVE; new patterns for integer-bound discriminators and integration-test gate ordering
metadata:
  type: project
---

Enemy Level & Zone Scaling GDD adversarial AC review — Round 3 completed 2026-07-12.

**Why:** Third-round review after round-2 applied 4 confirmed blockers (AC-11 both directions, AC-12 empty-pool standalone, AC-13 dangling ID fail-safe, AC-02 anti-hardcoding fixture). Round 3 checks that those fixes are correctly applied and audits the full AC set for deeper specification problems.

**Round 3 (2026-07-12):** All 4 round-2 blockers verified correctly applied. Found 5 new BLOCKING, 7 RECOMMENDED, 2 NICE-TO-HAVE issues.

**Round-2 blockers — all confirmed applied:**
- AC-11 EARLY 0.1875 + HIGH 0.5625 both present with correct diagnostic labels.
- AC-12 empty-pool standalone with distinct-code-path discriminator.
- AC-13 dangling-ID fail-safe with correct fixture and filter-before-loop discriminator.
- AC-02 BOSS L3→130 synthetic anti-hardcoding fixture.

**BLOCKING issues (round 3):**

- Finding 2 (AC-ELZS-05): The floor-boundary discriminator is non-discriminating for integer levels. The claim that `level > F − 1` (wrong) differs from `level >= F` (correct) is false for integers — both are equivalent. The actual off-by-one risk is on the **upper bound**: `level < R` vs `level <= R`. Fix: replace the floor discriminator with an upper-bound discriminator (level == R must pass; a strict-`<` impl rejects it).

- Finding 3 (AC-ELZS-09): Retune fixture does not specify the injection mechanism for `LEVEL_BAND_MID_FLOOR`/`LEVEL_BAND_HIGH_FLOOR`. "Injected/config constants" is not a function signature. Without knowing whether the function takes parameters, reads a config resource, or uses module constants, no test author can write the retune test. This is the seed-underspecification pattern from AC-EAI-06. Fix: specify the injection mechanism explicitly; recommended pattern is function parameters `level_band(level, mid_floor, high_floor)`.

- Finding 5 (AC-ELZS-11): Production `effective_drop_rate()` function interface is unspecified. The integration test cannot be written without knowing whether the function takes `enemy_level` or a pre-computed `level_rarity_mult`. Fix: specify the function interface; require a placeholder test file to exist before story Done is declared.

- Finding 13 (EC-ELZS-06 → AC-05 citation): After AC-ELZS-12 was carved out of AC-ELZS-05, the all-out-of-band scenario (non-empty pool where every entry fails the band check) has no explicit fixture. AC-ELZS-05's fixtures all show one bad entry in a pool with other valid entries — the all-bad-pool case is not tested. Fix: add an all-out-of-band fixture to AC-ELZS-05, or promote EC-ELZS-06 to a dedicated AC.

- Finding 16 (AC-ELZS-11 gate ordering): The integration test is framed as "post-Drop System erratum implementation" — a follow-on task — when it should be a condition on the erratum story's Definition of Done. Fix: change the qualifier to "the Drop System erratum story is NOT Done without this integration test passing."

**RECOMMENDED issues (round 3):**

- Finding 1 (AC-ELZS-06): "ADVISORY warning" and "CI pass/fail" are never reconciled. A validator that emits the warning but exits 0 silently satisfies CI while the advisory issue exists. Add: "validator exits 0 but must emit the warning to stdout/log so it is observable."

- Finding 4 (AC-ELZS-10): No adjacent-level fixture for MID/HIGH boundary (level 5 → MID, level 6 → HIGH in a single DS-F-LEVEL assertion). AC-ELZS-09 covers the band classification; AC-ELZS-10 provides indirect coverage via level-6 multi-factor product. Failure diagnosis is harder without an isolated boundary fixture.

- Finding 6 (AC-ELZS-02): "Runs over the entire roster on every content commit (CI-gated)" is a process requirement, not a testable assertion. Move to the CI configuration or errata pre-gate block; remove from the AC body.

- Finding 7 (AC-ELZS-04): Missing `floor == 1` and `roof == MAX_ENEMY_LEVEL` boundary discriminators. AC-ELZS-01 does this correctly (level 10 passes; `> 9` impl rejects). AC-ELZS-04 should apply the same pattern.

- Finding 8 (AC-ELZS-12 + AC-ELZS-13 + AC-ELZS-05 scope): No file path specified for content-validation ACs (unlike unit ACs which are assigned to `tests/unit/drop_system/`). Recommended path: `tests/unit/encounter_zone/test_encounter_zone_content_validator.gd`.

- Finding 9 (AC-ELZS-13): Missing pass fixture (all valid IDs → passes). Only a fail fixture is present. Always-fail validator passes the stated FAIL case. This is the same happy-path gap pattern as AC-EAI-17/18.

- Finding 14 (summary count): When Finding 13 is fixed (either new AC or fixture addition), the BLOCKING count becomes 11, not 10. Update the summary line.

- Finding 15 (content validation test type): Content Validation ACs do not specify whether each validator function has a GUT unit test or is a manual run. The path for automated CI evidence is unspecified for 8 of 13 ACs.

**NICE-TO-HAVE issues:**

- Finding 10 (AC-ELZS-08 delegation to AC-CP-08): Delegation is correct in principle, but nothing confirms AC-CP-08 fixtures the actual MVP zone roof=6. A cross-check note would close this.

- Finding 12 (AC-ELZS-03): Missing non-inverted unequal pass fixture (`[4, 5]` passes) alongside the equal-floor-roof case.

**New patterns introduced by this review:**

- Integer-bound discriminators: `level > F − 1` vs `level >= F` is a non-discriminator for integer levels. The real off-by-one risk is always on the boundary value itself (does `level == F` or `level == R` pass or reject?). Any integer-range AC must use the exact boundary value as the fixture input, not arithmetic equivalents.

- Integration-test gate ordering: An integration test framed as "post-[erratum] implementation" is a follow-on task, not a Done condition. Integration tests must be declared as a condition on the gating story's Done, not a separate follow-on.

- All-out-of-band scenario gap: When one AC is carved out of another (e.g. empty-pool from membership check), audit whether the parent AC still covers the compound failure case (all entries failing the check). Carve-outs can leave the compound case uncovered.

**How to apply:** (1) Any integer-range AC: use the exact boundary value as fixture input, not algebraic equivalents. (2) Any integration test for a cross-system amendment: it must be a Done condition on the amendment story, not a separate follow-on. (3) When carving a new AC out of an existing one, re-audit the parent AC's fixtures for compound-failure coverage. (4) All content-validator ACs should specify a GUT test file path; manual-only validators are not CI-gated.
