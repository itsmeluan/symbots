---
name: project-elzs-ac-review
description: Enemy Level & Zone Scaling GDD AC review history — round 4 (fresh-session confirmation); 3 new BLOCKING gaps found despite CD's "APPROVE on fix-confirmation, no round 5" commitment
metadata:
  type: project
---

Enemy Level & Zone Scaling GDD adversarial AC review — Round 4 completed 2026-07-12.

**Why:** Round 4 is a fresh-session confirmation pass after three prior rounds. CD committed "APPROVE on fix-confirmation, no round 5." QA-lead mandate is adversarial: find what prior reviewers missed.

**Round 3 (prior) blockers — all confirmed correctly applied before round 4 audit:**
- AC-05: floor discriminator replaced with at-roof fixture (level-6 enemy in [3,6] zone passes).
- AC-05(E): all-out-of-band fixture added (report-all discriminator).
- AC-09: injection signature pinned to `level_band(level, mid_floor, high_floor)` + independent HIGH_FLOOR retune fixture.
- AC-11: both-directions wiring (0.1875 and 0.5625) confirmed present with diagnostic labels.
- AC-06: ADVISORY warning CI-visible requirement added.
- AC-02: BOSS L3→130 synthetic anti-hardcoding fixture confirmed.
- AC-13: pass fixture (all-valid IDs → passes) confirmed.
- AC-04: floor=1 and roof=10 boundary discriminators confirmed.
- Errata pre-gate: 3a canonical DS-1, 3b AC-DS-31 amendment, 3c interface doc + AC-11 Done condition, CI obligations confirmed.

**Round 4 new BLOCKING findings:**

**BLOCKING-1 (AC-ELZS-05): At-floor acceptance fixture missing for F > 1.**
Round 3 correctly removed the false floor discriminator (`level > F−1` ≡ `level >= F` for integers) and replaced it with the at-roof fixture (C). But it did not add an at-floor ACCEPTANCE fixture where `F > 1`. Fixture A uses zone [1,6] — the floor is 1, so a `level > F` implementation misclassifying at-floor works only when F = 1, where `level > 1` is false for level 1. A zone [3,6] with a level-3 enemy SHOULD pass, but no fixture asserts this. An implementation using `level > F` (strict greater-than) instead of `level >= F` rejects a level-3 enemy in zone [3,6] and passes all five stated AC-05 fixtures. This is the symmetric gap left by the round-3 fix. Requires adding: "(F) zone [3, 6], pool includes a level-3 enemy → passes (at-floor boundary discriminator: an implementation using strict `level > F` instead of `level >= F` rejects this enemy)."

**BLOCKING-2 (AC-ELZS-06): Overlap-boundary fixtures missing for Rule 4 bands.**
Rule 4 table has overlapping ranges: floor = 3 is valid for BOTH EARLY and MID; floor = 6 for MID and LATE; floor = 8 for LATE and ENDGAME. No AC-06 fixture covers a floor value in an overlap zone (e.g., `MID + floor = 3` should NOT warn; `LATE + floor = 6` should NOT warn). An implementation with wrong overlap logic — warning at `MID + floor = 3` — passes all stated AC-06 fixtures while mis-flagging valid authoring. The MVP zone (floor=1, EARLY) is the only pass fixture, but it is not in an overlap zone. Required: at least one no-warning fixture at an overlap value (e.g., `MID + floor = 3` → no warning emitted; `LATE + floor = 6` → no warning emitted).

**BLOCKING-3 (AC-ELZS-04): `floor = 0` rejection fixture missing.**
AC-04 specifies `enemy_level_floor >= 1` and adds the round-3 discriminator that `floor = 1` passes. But there is no fixture asserting `floor = 0` fails. An implementation that accepts `floor = 0` while rejecting missing fields passes all stated AC-04 fixtures. Compare: AC-01 correctly has both `level == 0` fails and `level == 10` passes. AC-04 has only the at-minimum acceptance, not the below-minimum rejection. Requires: `enemy_level_floor = 0` fails (BLOCKING).

**Round 4 RECOMMENDED findings:**

**RECOMMENDED-1 (AC-ELZS-10): Common invariance asserted "at every band" but tested only at HIGH.**
The fixture `Common (0.70) at HIGH with ×1.5 condition → clamp(0.70 × 1.0 × 1.5) = 1.0` clamps, so it's not a discriminating Common-multiplier test — a wrong EARLY Common mult (e.g., 0.5) would not be caught because the fixture is only at HIGH. Add: Common at EARLY, no beacon, no conditions → `clamp(0.70 × 1.0) = 0.70`; Common at MID, no conditions, no beacon → `clamp(0.70 × 1.0) = 0.70`. These discriminate an implementation that accidentally scales Common.

**RECOMMENDED-2 (AC-ELZS-09): `level_band(1, 3, 6) == EARLY` fixture missing.**
All four stated boundary fixtures use levels 2–6. Level 1 (the minimum valid level) is unverified. An implementation with an off-by-one or special-case at level 1 (returning null or UNKNOWN) passes all stated fixtures.

**RECOMMENDED-3 (AC-ELZS-11): Cross-document enforcement gap.**
The "Done condition" language is correct but the enforcement depends on the Drop System erratum story existing with AC-ELZS-11 explicitly in its Done criteria. No erratum story file exists to verify. If the erratum is applied without referencing the ELZS GDD, the integration test file may never be created. Risk mitigation: the Errata pre-gate block should explicitly list AC-ELZS-11 as a Done criterion for the erratum sprint story, not only as a note in the ELZS GDD body.

**RECOMMENDED-4 (AC-ELZS-02): L10 fixtures absent despite "required reference values" claim.**
CP-F4 table lists WILD L10 → 135 and BOSS L10 → 270 as "required reference values for any future ENDGAME content authoring." AC-02 fixtures stop at L6. A content validator hardcoding L1–L6 values passes AC-02 while silently miscalculating ENDGAME entries. Not a MVP blocker but inconsistent with the "required reference values" framing.

**NICE-TO-HAVE (unchanged from round 3):**
- EC-ELZS-08 → AC-CP-08 delegation: no cross-check confirming AC-CP-08 uses roof=6 specifically.
- AC-DS-31 amendment cited in errata pre-gate but no ELZS AC verifies it was applied.

**How to apply:**
(1) Any range AC using `>= F` (floor) or `<= R` (roof): fixture BOTH the at-floor acceptance (level == F passes) AND the at-floor rejection (level == F−1 fails where F > 1), AND the at-roof acceptance (level == R passes) AND the at-roof rejection (level == R+1 fails). Four fixtures total per range bound.
(2) Any ADVISORY validation with "at every band" coverage claim: provide a fixture at each band, not just the highest/lowest.
(3) Any guideline table with overlapping ranges: provide no-warning fixtures for values in the overlap, not only values in a single-band range.
(4) Integration tests as "Done conditions": verify the sprint story file exists and explicitly carries the AC as a Done criterion — cross-GDD references are not self-enforcing.
