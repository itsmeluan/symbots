---
name: project-core-progression-ac-review
description: Core Progression GDD AC review — Round 1; 6 blockers (signal emit spec, EC-CP-12 co-core independence, cap boundary, null level_req, Integration dependency, ordering AC missing); 7 recommended; 2 NICE-TO-HAVE
metadata:
  type: project
---

Core Progression GDD AC adversarial review — Round 1 completed 2026-07-12.

**Why:** Shift-left QA; Core Progression is a new Foundation/Core-layer pillar (added 2026-07-12). Its ACs gate all downstream Assembly, Workshop, and TBC equip-gate tests.

**Round 1 (2026-07-12):** Found 6 BLOCKING, 7 RECOMMENDED (including 2 coverage gaps), 2 NICE-TO-HAVE. 2 clean passes (AC-CP-02, AC-CP-13).

## BLOCKING issues

**B-1 — AC-CP-03: GUT signal mechanism missing; emit-once vs. emit-per-threshold unverified.**
The AC says "core_leveled_up fires with old_level=1, new_level=5" but does not specify `assert_signal_emit_count(..., 1)` or `assert_signal_emitted_with_parameters`. An impl firing one signal per threshold crossed (4 signals for a 1→5 jump) would emit a last signal (4,5) that passes content check but the count check catches it. Must add both GUT assertions.

**B-2 — AC-CP-06: EC-CP-12 is marked "Verified by AC-CP-06" but AC-CP-06 lacks the co-core independence scenario.**
EC-CP-12 says a level-10 deployed core "still counts as deployed — its presence does not change XP awarded to other team members." AC-CP-06 only checks the level-10 core itself. An impl zeroing all-core XP when any core hits level 10 passes AC-CP-06. Requires second scenario: deployed level-10 core + benched level-5 core, same battle, verify level-5 earns floor(170 × 0.5) = 85.

**B-3 — AC-CP-08: Missing exact cap boundary (benched=6, enemy=3); `>=` vs `>` cannot be distinguished.**
Bench-lead cap fires at `benched_core.level >= enemy.level + 3`. Stated cases (benched=9 and benched=5 vs enemy=3) skip the discriminating boundary at benched=6. A `>` impl gives XP to benched=6 core — the stated cases would not catch it. Add benched=6/enemy=3 → 0 explicitly. Also: specify enemy xp_value=65 in the earning scenario.

**B-4 — AC-CP-04: Rule 4's null/zero level_requirement path has no scenario.**
Rule 4 explicitly states: "If level_requirement == 0 / null: proceed normally." No AC exercises this path. An impl that crashes or incorrectly blocks on null/0 level_requirement passes all three scenarios (6, 3). Add: GIVEN level_requirement=0 or null, THEN can_equip=true.

**B-5 — AC-CP-07 and AC-CP-12: Integration stories dependent on "Not Started" system (Exploration Progress).**
Both ACs are classified Integration and test load behavior, but Exploration Progress is explicitly "Not Started" in the Dependencies table. Neither AC specifies whether to use a unit stub or wait for the real system. Tester and programmer both have no path to execution. Must either: (a) narrow to unit scope (test the deserialization method directly, no Exploration Progress required), or (b) explicitly defer with unblock trigger: "unblocks when Exploration Progress serialization is implemented." As written, untestable.

**B-6 — MISSING AC for CP-F3 pipeline ordering (Rule 6 / no existing AC covers this).**
Rule 6 mandates: CP-F3 applied AFTER SA-F1 (bypasses chassis modifier) and BEFORE SYN-F4 (synergy adds on top). No AC in the set verifies insertion point. An impl placing CP-F3 before SA-F1 (so chassis multiplier amplifies level growth) would pass all 17 ACs because AC-CP-15 only checks the delta value in isolation. New AC-CP-18 required: controlled pipeline fixture with known SA-F1 multiplier, verify intermediate value (SA-F1_output + CP-contribution) feeds SYN-F4, not the other way around. Story type: Integration. Gate: BLOCKING.

## RECOMMENDED issues

**R-1 — AC-CP-03 (and missing AC): No AC verifies core_leveled_up NOT fired when XP gained without crossing threshold.**
Add sub-case: level-2 core at cumulative_xp=100, awarded 50 XP → total=150, still below threshold[3]=220. Assert `assert_signal_emit_count(system, "core_leveled_up", 0)`.

**R-2 — AC-CP-01: No signal assertion; this fixture crosses level 2→3 and should verify core_leveled_up fires.**
State explicitly or note dependency on AC-CP-03.

**R-3 — AC-CP-05: "Cannot enter combat while invalid" (EC-CP-05) not tested here; ownership gap.**
Clarify whether TBC or Workshop System GDD owns this test, and add a cross-reference.

**R-4 — AC-CP-10: "Warning logged" assertion mechanism not specified for GUT.**
Standard GUT pattern: mock or spy on logging call. "Skipped with warning" is not a GUT-native assertion — must specify the mechanism (e.g., check push_warning() output or inject a logging spy).

**R-5 — AC-CP-11: "xp_value absent" is ambiguous in GDScript — two distinct cases (.get() vs key missing vs null value).**
Specify which "absent" means: key missing from payload Dictionary vs. key present with null value. These are different code paths requiring different guards.

**R-6 — AC-CP-15: Level-1 zero-contribution should assert no change to final_stat, not just delta=0.**
Verify in pipeline context that final_stat is unchanged after CP-F3 runs at level 1, not just that the formula term equals 0.

**R-7 — AC-CP-16: Level-1 WILD (xp_value=45) absent; covers XP_BASE in isolation.**
Add: level=1, WILD → (35 + 10) × 1 = 45. The two stated cases (65, 170) do not isolate XP_BASE error as well as level=1.

**R-8 — AC-CP-17: Should explicitly assert cumulative_xp is unchanged, not just "no XP earned."**
Use `assert_eq(core.cumulative_xp, initial_xp)` for every core. Prevents an impl that calls award with 0 and still writes state.

**Coverage gap — Rule 5 rarity floor invariant:** No content-validation AC. Each part must have level_requirement >= RARITY_LEVEL_FLOOR[rarity]. Config/Data story type, ADVISORY gate. An author could set level_requirement=1 on a Prototype and nothing catches it.

## NICE-TO-HAVE

- AC-CP-14: Full 3-Symbot roster (2 benched) not tested — off-by-one on roster iteration would be missed.
- AC-CP-09: "When queried" trigger is ambiguous; GDD says record created on inventory add, not on query.

## New patterns from this review

- **Signal content + count are both required in GUT:** `assert_signal_emitted_with_parameters` alone is insufficient. Always pair with `assert_signal_emit_count`. Applies to any AC involving signal emission.
- **Negative-only cap tests:** Bench-lead cap and equip-gate both need exact-boundary cases at the discriminating threshold (`>=` vs `>`). This is now the fourth consecutive system review to find this gap.
- **"Verified by AC-XX" in EC section is a binding claim:** If an EC cites a specific AC as verification, the review must confirm the AC actually covers ALL observable behaviors described in the EC, not just the headline case (EC-CP-12 / AC-CP-06 miss).
- **Integration stories on Not-Started dependencies:** Must carry a machine-readable deferred status or have scope narrowed to unit-testable stub. Two ACs (CP-07, CP-12) in this state.
- **Pipeline ordering requires a dedicated ordering AC:** Formula value tests (AC-CP-15) cannot substitute for insertion-point tests. Any system where formula application ORDER matters must have an ordering AC that uses a fixture where wrong order produces a detectably different output.

**How to apply:** (1) Every signal AC must specify both emit_count and emitted_with_parameters in GUT. (2) Every cap/gate boundary must test the exact discriminating threshold (>=6 vs >6). (3) Any EC that cites "Verified by AC-XX" must be cross-checked in review. (4) Integration ACs on Not-Started systems must be deferred or narrowed. (5) Multi-step pipelines with mandatory ordering must have a dedicated ordering AC.
