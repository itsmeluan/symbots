---
name: project-core-progression-ac-review
description: Core Progression GDD AC review — Round 3 (re-review); 4 new blockers (cooling ceiling undefined, AC-CP-18 traceability gap, logging spy injection unspecified, OQ-CP-6 no enforcement AC)
metadata:
  type: project
---

Core Progression GDD AC adversarial review — three rounds completed.

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
Rule 2 says "emit for each crossed threshold" (one-per-threshold). EC-CP-02 and AC-CP-03 say emit once spanning (old_level → new_level). These are directly contradictory. Resolved: Rule 2 updated to match EC-CP-02/AC-CP-03 (emit-spanning).

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

**R3-B — AC-CP-22: `cooling` reference ceiling undefined (BLOCKING)**
AC-CP-22 checks `level_growth[stat] × 9 ≤ 0.25 × REFERENCE_SA_F1_OUTPUT[stat]` but the CP-F3 table lists cooling as `~40` (approximate). No approved GDD declares an exact SA-F1 cooling ceiling — the Bidirectionality Notes explicitly call this out as "owed." The cooling ceiling check in AC-CP-22 is un-implementable until the SA-F1 cooling range is formally declared. A test author must either hardcode 40 (fragile after retune) or import from SA-F1 (not yet defined). Fix: AC-CP-22 must explicitly note it is BLOCKED for cooling until the SA-F1 cooling ceiling erratum lands.

**R3-C — AC-CP-18 unblocking: DoD prose note has no enforcement mechanism (BLOCKING)**
The DoD note says "unblocking AC-CP-18 is a required DoD item on the Assembly erratum story." But the Assembly erratum story does not yet exist, and when authored it will draw from the Assembly GDD, which does not reference AC-CP-18. There is no mechanism that fires if the Assembly story closes without running AC-CP-18. Fix: the Assembly GDD must contain a cross-referencing AC (AC-SA-XX) that explicitly makes AC-CP-18 a gate on the Assembly erratum story, or a tracked task must exist on a board where it would block sprint review.

**R3-E — Logging spy injection interface unspecified; five ACs depend on it (BLOCKING)**
ACs-CP-09, 10, 11, 12, 23 all require a logging spy, but the GDD never specifies the injection seam. If a programmer uses `push_warning()` (GDScript native, not injectable), all five tests are untestable as unit tests. This is the same structural gap as Round 2's B-3 (register_core) applied to the logging interface. Fix: Rule 1 must specify that the system accepts an injected ILogger (or equivalent) with at minimum `warn(msg)` and `error(msg)` methods. Tests inject a spy; production injects an engine wrapper.

**R3-G — OQ-CP-6 (CD sign-off on anti-pillar revision) has no AC and no enforcement mechanism (BLOCKING)**
The Level Backbone revises the game-concept.md anti-pillar, which requires creative-director ratification before the Level Backbone locks (OQ-CP-6). This is tracked only in Open Questions with "Owner: creative-director." There is no AC, no blocking gate, and no mechanism preventing the GDD from being marked Approved without the sign-off. Fix: add AC-CP-24 (BLOCKING): the GDD cannot move to Approved unless game-concept.md shows explicit CD sign-off on the anti-pillar #3 revision.

## Round 3 ADVISORY findings

**R3-A — AC-CP-21 floor discriminant: neither fixture discriminates floor vs round in DF-1.**
The challenger (53.38 → 53) and incumbent (8.0 → 8) both produce the same result under floor and round. AC-CP-21 correctly tests an ordering invariant (53 > 8), not the rounding function — this is acceptable if DF-1's own AC tests floor vs round. Flag for DF-1 reviewer to confirm.

**R3-F — AC-CP-16 BOSS fixture "isolates" comment is slightly misleading.**
The BOSS fixture only isolates BOSS_XP_MULTIPLIER given the prior two fixtures already constraining XP_BASE and XP_PER_ENEMY_LEVEL. Comment is technically imprecise but not incorrect in practice. Minor.

## Patterns from Round 3

- **Approximate reference values (`~N`) in BLOCKING ACs are blockers.** A tilde in a test reference means the test either hardcodes a guess or can't run. Any BLOCKING AC that references an approximate value must resolve it to an exact constant.
- **DoD prose notes in one GDD are not gates on another GDD's story.** A cross-GDD DoD obligation needs a tracked enforcement mechanism (an AC in the target GDD, or a board task) — not just prose.
- **Logging injection is a shared-API decision, not a test implementation detail.** When five ACs depend on a logging spy, the injection interface must be part of the system's API specification, not left to the implementer's inference.
- **Required stakeholder sign-offs must be ACs, not open questions.** An OQ with "Owner: [role]" is a comment. An AC with BLOCKING gate is a gate.

**How to apply:** (1) Before writing any BLOCKING content-validation AC that references a stat ceiling, verify the ceiling is an exact constant in a published, approved document. (2) For any DEFERRED AC whose unblocking is a DoD item on another story, verify the target story's GDD contains a cross-reference. (3) Check whether logging is injectable before writing logging-spy ACs. (4) Stakeholder sign-offs required before Approval must be expressed as BLOCKING ACs, not OQs.
