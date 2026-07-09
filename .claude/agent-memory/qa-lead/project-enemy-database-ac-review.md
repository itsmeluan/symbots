---
name: project-enemy-database-ac-review
description: Enemy Database GDD AC review history — round 1 findings, blockers, and patterns to watch in future rounds
metadata:
  type: project
---

Enemy Database GDD AC review — Round 1 completed 2026-07-09.

**Why:** Shift-left QA; Enemy Database is a Foundation-layer system (sibling to Part DB) and its ACs gate all downstream test writing for Break, Drop, and Combat systems.

**Round 1 (2026-07-09):** Found 8 BLOCKING, 5 RECOMMENDED, 4 ADVISORY issues, and 3 missing test cases.

**BLOCKING issues:**
- AC-ED-09: Threshold (×1000) hardcodes `BASE_DROP_BOSS_GRADE = 0.001` as an implicit assumption. Should express the invariant as `base_rate × multiplier >= 1.0` and read the knob from config, not hardcode 1000.
- AC-ED-08(b): BREAK_HP_MIN activation case uses `20 × 0.15 = 3.0` (exact IEEE 754) — does not discriminate floor vs round vs ceil. Needs a note that (b) proves guard activation only; (a) and (c) carry the floor discrimination burden.
- AC-ED-05(a): No positive case for `structure = 1`; all-false implementation satisfies all negative cases. Same class as Part DB Round 5 AC-07 gap.
- AC-ED-06(b/c): No test for exactly 2 Boss-grade (passes boundary) or exactly 3 (fails boundary). An implementation that caps at 1 or allows 3 passes all stated cases.
- AC-ED-07(b): "condition key" references drop_conditions without citing the Part DB field schema — not independently executable by a tester who hasn't read Part DB. Cross-reference Part DB AC-11 explicitly.
- AC-ED-14: Boundary direction unspecified for band warning thresholds. `structure = 60` — warning or not? Needs explicit in-band/out-of-band boundary tests.
- AC-ED-16: Cites EDB-2 calibration table value (33) rather than DF-1 formula output. Deferred implementer cannot independently verify without DF-1. Fix: cite DF-1 formula directly.
- AC-ED-13: Mixed gate levels (ADVISORY + BLOCKING) in one AC. Sync dependency on Part DB flavor_text length makes the threshold unstable. Split into two ACs; threshold should read from config constant.

**RECOMMENDED issues:**
- AC-ED-04: "All disabled" vs "some disabled" boundary untested (pool of 2, exactly 1 disabled = pass with 1 warning).
- AC-ED-03: skills.size()=4 not confirmed as warning-free; skills.size()=5 not confirmed as warning trigger.
- AC-ED-09 (cross-system gap): ×500 vs ×1000 tension documented in prose but no concrete test case that constructs a Part DB–compliant ×500 entry and confirms Enemy DB rejects it.
- AC-ED-01: No wrong-type test for `spawn_enabled = 1` (int) or `"true"` (String) — most common JSON authoring error.
- AC-ED-07(b): break_event vocabulary ownership not stated; implied closed vocabulary has no test.

**ADVISORY issues:**
- AC-ED-10: GDScript null-to-StringName coercion behavior at call site not addressed.
- AC-ED-12: Deferred unblock trigger does not require the deduplication guarantee specifically.
- AC-ED-11: Progression warning fires unconditionally for spawn-disabled BOSS; false-positive behavior undocumented.
- AC-ED-04(f)/AC-ED-15(b): Scope overlap on empty-pool check — potential double-counting in validation reports.

**Missing test cases:**
- MTG-1: Empty `stats = {}` dict behavior (all 10 non-structure stats treated as 0 — no positive test).
- MTG-2: Reserved `enemy_class = "ELITE"` should fail — no test case.
- MTG-3: Stale hand-edited break_hp has no explicit fixture: `structure=100, fraction=0.35, stored break_hp=40` should fail (derived=35).

**Recurring patterns (same as Part DB):**
- All-false implementation gap: AC-ED-05(a) and AC-ED-06(b/c) repeat the Part DB Round 5 AC-07 problem — always include both a passing boundary case and a failing boundary case.
- Tuning knob hardcoding: AC-ED-09 threshold of 1000 is correct only at the current base rate. Any formula threshold derived from a tuning knob must read the knob, not hardcode the derived value.
- Calibration table ≠ formula output: AC-ED-16 cites EDB-2 design-intent values, not formula output. Always cite the authoritative formula, not the rounded design table.

**How to apply:** When reviewing future GDD ACs, check: (1) every negative case has a positive counterpart at the boundary; (2) every threshold derived from a tuning knob reads the knob; (3) ADVISORY and BLOCKING assertions are always separate ACs; (4) worked examples in deferred ACs cite the formula, not the calibration table.
