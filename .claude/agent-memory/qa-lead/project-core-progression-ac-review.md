---
name: project-core-progression-ac-review
description: Core Progression GDD AC review — Round 4 (confirmation pass); 3 new blockers (Assembly AC-SA-XX not yet in Assembly GDD, AC-CP-21 int/int trap, EC-CP-05 combat block has no AC in any Approved GDD)
metadata:
  type: project
---

Core Progression GDD AC adversarial review — four rounds completed.

**Why:** Shift-left QA; Core Progression is a new Foundation/Core-layer pillar (added 2026-07-12). Its ACs gate all downstream Assembly, Workshop, and TBC equip-gate tests.

## Round 1 (2026-07-12) — All blockers resolved in current GDD version

Round 1 found 6 BLOCKING, 7 RECOMMENDED (including 2 coverage gaps), 2 NICE-TO-HAVE. All were resolved in the GDD before Round 2 review:

- B-1: GUT signal assertions now specified (both emit_count + emitted_with_parameters).
- B-2: AC-CP-06 part B added (co-core independence scenario for EC-CP-12).
- B-3: AC-CP-08 case A now uses benched=6/enemy=3 exact boundary.
- B-4: AC-CP-04 case (c) added for null/zero level_requirement.
- B-5: AC-CP-07 and AC-CP-12 narrowed to unit scope; AC-CP-07b properly DEFERRED.
- B-6: AC-CP-18 added for pipeline ordering.
- R-1…R-8 and coverage gaps: AC-CP-19 added, AC-CP-01 signal assertion added, AC-CP-14 and AC-CP-20 added, logging spy pattern specified throughout.

## Round 2 (2026-07-12) — 4 new BLOCKING issues (all resolved before Round 3)

**B-0 — Rule 2 / EC-CP-02 / AC-CP-03 signal semantics contradiction (HIGHEST PRIORITY)**
Rule 2 said "emit for each crossed threshold" (one-per-threshold). EC-CP-02 and AC-CP-03 said emit once spanning (old_level → new_level). Resolved: Rule 2 updated to match EC-CP-02/AC-CP-03 (emit-spanning).

**B-1 — AC-CP-18: Assembly erratum not committed; Integration test has no executable path.**
Resolved by adding DEFERRED note plus DoD obligation on the Assembly erratum story.

**B-2 — AC-CP-03: Multi-jump fixture is non-discriminating for `>=` vs `>` on final level boundary.**
Resolved: sub-case added (award exactly 537 XP, assert level == 5).

**B-3 — AC-CP-09: Record-creation trigger interface unspecified; unit test has nothing to call.**
Resolved: `register_core(core_instance_id: int) -> void` specified in Rule 1.

## Round 2 RECOMMENDED issues (7) — status in Round 3 GDD

- AC-CP-04 case (b): error message null assertion — still unresolved (open).
- AC-CP-05 validation report structure: still unspecified (open RECOMMENDED).
- AC-CP-06 part B: enemy level now explicit in GDD. Resolved.
- AC-CP-11 part A: signal count == 0 assertion added in current version. Resolved.
- AC-CP-17a/b: emit_count == 0 added. Resolved.
- AC-CP-16: "isolates" comments remain slightly misleading for BOSS fixture. Minor open.
- AC-CP-20: DEFERRED note re Part DB erratum — still not explicitly noted in AC-CP-20 text.

## Round 3 (2026-07-13) — 4 new BLOCKING issues

**R3-B — AC-CP-22: `cooling` reference ceiling undefined (BLOCKING) → RESOLVED in-doc**
AC-CP-22 check (B) for cooling demoted to ADVISORY-until-established. Fix applied correctly.

**R3-C — AC-CP-18 unblocking: DoD prose note has no enforcement mechanism (BLOCKING) → PARTIALLY RESOLVED**
Bidirectionality Notes now say Assembly erratum MUST add AC-SA-XX. But Assembly GDD still does not contain this AC — obligation stated in Core Progression only. Live gap carries forward to Round 4.

**R3-E — Logging spy injection interface unspecified (BLOCKING) → RESOLVED in-doc**
Rule 1 now specifies injected logger with `warn(msg)` / `error(msg)`, production/test split. All five spy-dependent ACs now unit-testable.

**R3-G — OQ-CP-6 CD ratification has no AC and no enforcement mechanism (BLOCKING) → RESOLVED**
CD ratification recorded in OQ-CP-6 with evidence ("Ratified by creative-director in 2026-07-13 full-panel re-review synthesis"). Post-hoc sign-off adequately evidenced.

## Round 3 ADVISORY findings

**R3-A — AC-CP-21 floor discriminant (prior): neither fixture discriminated floor vs round.**
Resolved in-doc: incumbent energy_power changed from 20→24, giving result 10 (floor ≠ round ≠ ceil). Fixed.

**R3-F — AC-CP-16 BOSS fixture "isolates" comment slightly misleading.**
Minor — still open, low priority.

## Round 4 (2026-07-13) — 3 BLOCKING, 2 RECOMMENDED, 3 ADVISORY

### BLOCKING

**R4-B1 — Assembly GDD still has no AC-SA-XX (AC-CP-18 enforcement gap)**
The Core Progression GDD's Bidirectionality Notes state "Assembly erratum MUST add AC-SA-XX." But the Assembly GDD (Approved, 2026-07-10) does not contain this AC. An Assembly programmer who doesn't read Core Progression's Bidirectionality section will close the erratum story without running AC-CP-18. The fix must land in the Assembly GDD, not just in this GDD's prose. This is the R3-C gap, still open.

**R4-B2 — AC-CP-21 int/int division trap**
The worked example computes `3025/85 × 1.5` and expects 53. In GDScript, `int / int` truncates: `3025 / 85 = 35` (not 35.588). If DF-1 uses integer intermediates at that division step, `35 × 1.5 = 52.5`, `floor(52.5) = 52`, not 53. The AC must specify that `A²` and `(A+R)` are computed as `float` (e.g., `float(55*55) / float(55+30)`) or reference DF-1's explicit type contract. Without this, the expected value may be wrong and the test will fail falsely — or worse, the test is written against the wrong expected value and silently passes when the DF-1 implementation truncates.

**R4-B3 — EC-CP-05 combat block has no AC in any Approved GDD**
AC-CP-05 tests the flagging side (build marked invalid, parts listed). The actual combat-entry block — refusing to start a battle with an invalid build — is owned by TBC/Overworld Navigation. The TBC GDD is Approved but contains no AC for this. The obligation lives only in Core Progression's Bidirectionality Notes (prose, not an AC). This is the R3-C pattern applied to TBC. A player who swaps a core and presses "Enter Combat" will not be stopped by any tested code path.

### RECOMMENDED

**R4-R1 — AC-CP-22 / AC-CP-20 Part DB erratum cross-reference absent**
Both ACs are BLOCKING in label but the Part DB erratum story (not yet written) will not see this gate unless the Part DB GDD carries a cross-reference. Same pattern as R3-C/R4-B1. The Part DB erratum must explicitly list passing AC-CP-20 and AC-CP-22 as DoD items.

**R4-R2 — AC-CP-09 duplicate-register warning has no content assertion**
AC-CP-09 asserts a warning fires on duplicate register_core, but does not assert message content (unlike AC-CP-10, which asserts "warning containing 'bogus_stat'"). A test passes even if the wrong warning fires. Add: "warning contains the duplicate core_instance_id."

### ADVISORY

**R4-A1 — Logging spy interface underspecified — capture method not defined**
Rule 1 specifies `warn()` and `error()` on the logger interface but doesn't say how the spy exposes captured messages to tests. Risk: each programmer implements a different spy (last-only vs. all; list vs. string). Add one concrete example: "spy exposes `get_warnings() -> Array[String]` and `get_errors() -> Array[String]`."

**R4-A2 — AC-CP-08(B) missing round-discriminator callout**
`floor(32.5) = 32`, `round(32.5) = 33` — discriminating, but not annotated (unlike AC-CP-06's explicit callout). Inconsistency.

**R4-A3 — ADVISORY-until-established cooling ceiling has no promotion trigger**
When the SA-F1 cooling ceiling erratum lands, no AC fires to remind the team to promote AC-CP-22 check (B) to BLOCKING. Process gap only.

## Key patterns emerging across all rounds

- **"Obligation in one GDD, story in another GDD" is never a gate.** If an AC or DoD requirement lives only in the document that cites the need (not in the document whose story will be written), it will be missed. Every cross-GDD obligation needs an AC or tracked task in the *target* document.
- **GDScript int/int truncates silently.** Float-division steps in worked examples must specify `float()` casts. Applies to all formulas where intermediate division involves two integer operands.
- **Content validation gates must be duplicated in the content document.** AC-CP-20 and AC-CP-22 are BLOCKING in Core Progression; Part DB erratum authors won't read Core Progression before authoring parts.
- **EC-CP-05 pattern:** flagging (this system) vs. enforcement (another system) — the enforcement side consistently lacks a tested AC when the other system is already Approved.

**How to apply:** Before accepting any GDD as Approved, check: (1) every cross-GDD DoD obligation has an AC or board task in the target GDD; (2) every float-division worked example specifies the cast; (3) every content-validation BLOCKING AC is also listed as a DoD gate on the story that creates the content it validates; (4) every "cannot enter combat / cannot proceed" enforcement obligation that crosses to another Approved GDD has an AC in that GDD.
