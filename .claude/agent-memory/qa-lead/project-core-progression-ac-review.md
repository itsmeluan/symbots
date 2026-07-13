---
name: project-core-progression-ac-review
description: Core Progression GDD AC review — Round 2; all Round 1 blockers resolved; 4 new blockers (signal semantics contradiction, Assembly erratum dependency, multi-jump boundary, record-creation interface undefined)
metadata:
  type: project
---

Core Progression GDD AC adversarial review — two rounds completed.

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

## Round 2 (2026-07-12) — 4 new BLOCKING issues

**B-0 — Rule 2 / EC-CP-02 / AC-CP-03 signal semantics contradiction (HIGHEST PRIORITY)**
Rule 2 says "emit for each crossed threshold" (one-per-threshold). EC-CP-02 and AC-CP-03 say emit once spanning (old_level → new_level). These are directly contradictory. All signal-related tests are frozen until the design decision is made: emit-per-threshold OR emit-spanning. A programmer following Rule 2 implements one-per-threshold and is told by AC-CP-03 they are wrong.

**B-1 — AC-CP-18: Assembly erratum not committed; Integration test has no executable path.**
AC-CP-18 tests pipeline ordering (CP-F3 after SA-F1, before SYN-F4) but requires the Assembly erratum (not yet landed). Must either carry a DEFERRED note (like AC-CP-07b) or be narrowed to a unit-stubbed pipeline. Currently untestable.

**B-2 — AC-CP-03: Multi-jump fixture is non-discriminating for `>=` vs `>` on final level boundary.**
600 XP lands inside the level-5 band (537 ≤ 600 < 744) — the final level assignment is not tested at an exact boundary. An implementation using `>` on the level-5 threshold passes because 600 > 537 either way. Add a fixture landing exactly on a threshold (e.g., award 537 XP from level 1, assert level == 5) to discriminate.

**B-3 — AC-CP-09: Record-creation trigger interface unspecified; unit test has nothing to call.**
Rule 1 says "created when a core is first added to Inventory" but no method/signal interface is specified for this event. Is it `register_core(instance_id)`? A subscription to an Inventory signal? Without the interface, the unit test cannot be written. Inventory is not in the upstream dependencies table.

## Round 2 RECOMMENDED issues (7)

- AC-CP-04 case (b): should also assert error message is null (at-level equip emits no error).
- AC-CP-05: validation report structure unspecified — "lists the ARMS part" is not independently testable without knowing the data type (list of slot names? instance IDs?).
- AC-CP-06 part B: enemy level not stated; cap-guard condition requires reverse-engineering xp_value=170 via CP-F4. State enemy level explicitly.
- AC-CP-11 part A: missing `assert_signal_emit_count(..., 0)` for spurious signal guard.
- AC-CP-17a/b: no signal-count assertion (0) alongside the xp assert_eq.
- AC-CP-16: "isolates XP_BASE" comment is misleading — level=1 case tests XP_BASE + XP_PER_ENEMY_LEVEL composite; multi-case set is sufficient together but comment should be corrected.
- AC-CP-20: Part DB erratum not yet merged; needs DEFERRED note to avoid running against schema without `level_requirement` field.

## Advisory notes

- AC-CP-07b (when unblocked): must also verify serialized level-10 `cumulative_xp` is not incremented past cap on restore.
- EC-CP-12 / AC-CP-06: no test for both level-10 cap AND bench-lead cap both firing in same battle simultaneously.

## New patterns from Round 2

- **Rule-vs-EC signal contradictions are blockers:** A rule that specifies signal behavior (emit-per-threshold) that contradicts its own EC resolution (emit-spanning) is a design inconsistency, not an AC wording issue. Must be resolved at design level before writing tests.
- **Integration ACs on pending errata need DEFERRED notes:** Same pattern as Not-Started systems from Round 1 — an "Approved, erratum pending" system is as untestable as a Not-Started one.
- **Multi-jump tests must land on threshold boundary:** An off-threshold fixture (600 XP landing inside a band) does not discriminate `>=` vs `>` on the final level. Always use a fixture where cumulative_xp == threshold[L] for some L in the jump.

**How to apply:** (1) Check for intra-document rule/EC signal contradictions before writing any signal test. (2) Any Integration AC depending on an unapplied erratum must carry a DEFERRED note. (3) Boundary-discriminating fixtures must test at exact threshold values, not values that fall inside a band.
