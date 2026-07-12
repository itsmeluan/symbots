---
name: project-enemy-ai-ac-review
description: Enemy AI GDD AC review history — round 1 findings; 4 blockers, 11 recommended, 4 NICE-TO-HAVE; patterns for future AI system ACs
metadata:
  type: project
---

Enemy AI GDD AC adversarial review — Round 1 completed 2026-07-12.

**Why:** Shift-left QA; Enemy AI is a Foundation-layer decision system. Its ACs gate all downstream Enemy AI integration tests and TBC's ACTION_PENDING hook.

**Round 1 (2026-07-12):** Found 4 BLOCKING, 11 RECOMMENDED, 4 NICE-TO-HAVE issues, plus 2 coverage gaps.

**BLOCKING issues:**

- AC-EAI-04: Energy zero path (energy_power=0 with ENERGY move) untested. Only physical_power=0 is tested. Two independent guards (A=0 floor, H_cur floor) are conflated in one fixture — cannot tell which guard is missing on failure. Requires split into 3 sub-cases: (a) physical A=0 alone, (b) energy A=0 alone, (c) H_cur=1 alone.

- AC-EAI-06: Seed pre-selection is an unverified open fixture — the AC does not specify the exact GDScript RNG API (`randi_range`, `randi() % N`, etc.) or the concrete seed values. Until the implementing programmer specifies the RNG call and pre-computes seed values against it, no test author can write this test. Seeds left as TBD = failing AC. Rewrite must require the programmer to record verified seed values in the test file as constants.

- AC-EAI-09: GDScript int-division trap not addressed. `int(40)/int(100) = 0` in GDScript (not 0.40) — a test using integer current_structure/max_structure would make the strict-< boundary trivially true for all values below max. The fixture must explicitly state float types or explicit cast, and the FAIL condition must name the int-division ≤-bug path.

- AC-EAI-12: "Deep-copied or read-only battle_state" is unenforceable without a write-intercepting mock. GDScript's `.duplicate()` is shallow by default; nested Arrays/Resources are not copied. A mutation to `battle_state.player.active_statuses` (an Array) is invisible to a shallow snapshot. The AC must specify a write-intercepting mock (preferred) or `.duplicate(true)` deep copy with full nested field comparison.

**RECOMMENDED issues:**

- AC-EAI-01: Implicit dependency on AC-EAI-03 for arithmetic correctness not stated. Score values cited in the AC text invite wrong exact-float assertions.
- AC-EAI-02: Missing boundary case `H_cur = df1(X) = 53` (lethal_factor at exact equality). An impl using strict `>` instead of `≥` for lethal_factor passes all stated cases.
- AC-EAI-03: No final-score composition assertion. Correct individual factor values don't catch wrong weight application.
- AC-EAI-07: All-zero path only asserts "a move returns," not "the least-negative move returns." All-return-index-0 impl passes vacuously.
- AC-EAI-08: Does not specify single-fire vs. per-invocation logging. "Exactly one error" is ambiguous on repeated calls.
- AC-EAI-10: ADVISORY — discriminator claims to catch type_factor bug on SELF, but pick-only test cannot confirm factor values.
- AC-EAI-11: FAIL condition does not name the part (a) direction failure (discount applied when no status active → returns X instead of Yn).
- AC-EAI-14: Case-sensitivity not tested. `has_profile("tactical")` → false is missing. A case-insensitive impl would silently pass authored `"Tactical"` entries in Enemy DB.
- AC-EAI-15: No lethal-branch coverage in the spy fixture. The single-call rule should be verified with at least one lethal move in the set.
- AC-EAI-17: Happy-path sub-case missing (single threshold → accept). An all-rejecting linter passes the stated FAIL.
- AC-EAI-18: Happy-path sub-case missing (≥1 status move → no warning). An always-warn linter passes the stated FAIL.

**Coverage gaps:**

- Gap 1 (RECOMMENDED): Kill-securing invariant (`w_lethal ≥ w_type + w_stat`) never tested as an explicit assertion. TACTICAL is the historical risk; AGGRESSIVE/OPPORTUNIST invariant holds vacuously but no AC would catch a weight edit violating it. Suggested new content-validation AC: assert the invariant for every MVP profile's weight vector.
- Gap 2 (RECOMMENDED): `has_profile(id)` cannot distinguish registry-backed vs. hardcoded implementation. An impl that hard-codes the three names satisfies AC-EAI-14 but violates Rule 2 (data-driven profiles).

**Recurring patterns (same as Part DB / Enemy DB rounds):**

- Missing happy-path sub-cases: AC-EAI-17 and AC-EAI-18 repeat the Part DB / Enemy DB AC-07 all-false-impl gap — always include both a passing boundary case and a failing boundary case.
- GDScript int-division: AC-EAI-09 is a new pattern specific to ratio comparisons. Any future AC involving `int / int` threshold comparisons must specify float types explicitly.
- Shallow-copy mutation: AC-EAI-12 is a new pattern for GDScript. Any AC asserting "input unchanged after call" must use either a write-intercepting mock or `.duplicate(true)` with full nested-field comparison. Shallow duplicate fails silently on Array/nested-Resource mutations.
- Seed underspecification: AC-EAI-06 is a new pattern. Any AC that pre-selects RNG seeds must (a) specify the exact GDScript RNG API, (b) pre-compute and hard-code expected outputs, and (c) require the implementing programmer to record verified values before the test is merged.

**How to apply:** When reviewing future GDD ACs: (1) any content-validation AC must have both a reject case and an accept case; (2) any ratio-comparison threshold AC must specify field types (float vs int); (3) any "input unchanged" AC must specify deep vs. shallow copy strategy; (4) any RNG seed pre-selection AC must require the programmer to fill in verified seed values before merge; (5) the kill-securing invariant is now a standing check — assert it as a static weight-vector test in any system with profile-weighted scoring.
