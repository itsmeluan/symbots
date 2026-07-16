---
name: project-part-database-ac-review
description: Status of Part Database GDD AC reviews — what rounds have been done, blocking issues found, and what to watch for in future reviews
metadata:
  type: project
---

Part Database GDD has undergone three AC review rounds as of 2026-07-09.

**Why:** Shift-left QA practice; GDD is a Foundation-layer system and its ACs gate all downstream test writing.

**Round 1 (2026-07-09):** Found 6 blockers, 5 involved AC corrections. All resolved in the same session.
- AC-04: wild-rarity synergy tag exception added
- AC-11: Boss-grade multiplier threshold raised to >= 500
- AC-13: BLOCKED (Move Database + Passive Database not yet designed)
- AC-15: Split into 15a (testable) and 15b (deferred, requires Assembly + Inventory)
- AC-16: Per-stat independence test added

**Round 2 (2026-07-09):** Found 5 new BLOCKING issues and 7 advisory issues.
- AC-05: Two blocking gaps — no fractional floor test, and sum=0 test doesn't exercise max(0,…) clamp
- AC-06: All test values are clean integers — floor vs ceil vs truncate indistinguishable; needs base=7 test
- AC-08: base -1 test only covers tier +3; tiers +4 and +5 (double-negation bug) untested
- AC-09 (GDD): Worked example says 0.49, correct value is 0.4875 — inconsistency will cause tester error; AC value is correct but GDD body needs fix
- Advisory: AC-01 missing inverse rarity check, AC-07 ambiguous error contract, AC-11 tied to current tuning knob value, AC-12 no minimum drawback magnitude, AC-14 empty string case, AC-15a tests Drop System not Part Database

**Round 3 (2026-07-09):** Found 4 new BLOCKING issues and 4 advisory issues. Round 2 fixes verified except AC-09b.
- BLOCKING: AC-09b expected output is wrong — 0.001 × 999 = 0.999, not 1.0. Fix: change multiplier to 1000, or expected output to 0.999. Also fix Tuning Knobs prose that claims "×999 clamps to 1.0."
- BLOCKING: Rule 4 body says "Ten stats" but defines 11 (Recharge was added as 11th MVP stat).
- BLOCKING: No AC enforces Recharge per-part range 0–15 (Rule 4 explicitly names this ceiling; AC-12 only checks total budget, not individual stat ranges).
- BLOCKING: Formula 6 variable table says recharge_bonus range is 0–15, but it is a sum across all equipped parts — Energy Cell and Core can each contribute up to 15, so actual range is 0–30. Developers implementing bounds checks will cap at wrong value.
- ADVISORY: AC-05b chassis archetype not specified — tester must infer which archetype to use for fixture.
- ADVISORY: AC-06b "sanity check" with base=20 has zero discriminating power (all products are exact integers; same result from floor, ceil, or round).
- ADVISORY: No AC for Prototype 70%+ concentration rule — AC-10 checks drawback exists, AC-12 checks total budget, neither checks concentration.
- ADVISORY: Formula 2b epsilon-nudge (ceil(value - 0.0001)) may be insufficient for certain float inputs; integer-scaled arithmetic is safer and should be recommended explicitly.

**Round 5 (2026-07-09):** Found 5 BLOCKING, 6 RECOMMENDED, 5 ADVISORY, 3 coverage gaps. [Round 4 state not available; reviewing current AC text directly.]
- BLOCKING: AC-05(b) arithmetic error — tier+1 with base=-15 yields F2b output of -20 not -10; expected result 2 is unreachable at the stated tier.
- BLOCKING: AC-06(c) IEEE 754 claim is wrong — 20×1.15 computes to 23.000…, not 22.999…; epsilon-nudge test has zero discriminating power as written.
- BLOCKING: AC-07 only asserts can_upgrade(4)=false; does not assert can_upgrade(3)=true; all-false implementation passes.
- BLOCKING: AC-08 note misdirects testers — claims double-negation bug manifests at tiers +4/+5 but discriminating assertion is at tier 0 (value should be negative, not 0).
- BLOCKING: AC-12 references "Stat Budget Reference ranges" without specifying document location; AC is not independently executable.
- RECOMMENDED: AC-01 still missing inverse rarity check (Common with accidental active_skill_id passes).
- RECOMMENDED: AC-04 does not validate element tag string value when wild parts include an element tag.
- RECOMMENDED: AC-09(b) missing below-clamp assertion (×999 → 0.999); all-ones implementation passes.
- RECOMMENDED: AC-14 still missing empty-string and null-input cases (flagged Round 2, not fixed by Round 5).
- RECOMMENDED: AC-15a tests Drop System behavior, not Part Database storage correctness.
- RECOMMENDED: AC-19 ordering dependency on AC-10 is implicit; isolation run causes division-by-zero.
- GAPS: F2b zero-at-tier-3 in F1 sum; wild-part element tag delivery to Synergy System; archetype-to-slot-type compatibility.

**Round 7 (2026-07-09):** Found 3 BLOCKING, 2 RECOMMENDED, 2 ADVISORY issues.
- BLOCKING: AC-23 `primary_stat` is undefined — no lookup table exists in any document; Arms/Weapon slots have per-part damage_type variability making the AC structurally unexecutable without a SLOT_PRIMARY_STAT schema addition.
- BLOCKING: Formula 2 canonical expression `floor(base × multiplier)` is missing the `+0.0001` epsilon — engineers implementing from the formula (not the Pipeline example) will produce the wrong answer for near-integer products (20 × 1.15 → floor(22.999...) = 22, not 23). AC-06(c) requires 23. Silent latent bug with a false-positive test.
- BLOCKING: AC-09(d) uses strict equality on a float product involving non-representable constant 1.3; evaluation order is unspecified; epsilon tolerance `abs(result - 0.4875) < 1e-9` must be added.
- RECOMMENDED: AC-22 numbering gap — slot is empty with no tombstone; add heat_generation content validation or explicit "not added" note.
- RECOMMENDED: AC-13 (BLOCKED) and AC-15b (DEFERRED) have no structured unblock-trigger or owner; add machine-readable status block to each.
- ADVISORY: AC-05(b) arithmetic verified correct by independent calculation; no action needed.
- ADVISORY: AC-08 base=-1 sequence correct; design flag — small drawbacks (abs ≤ 2) never partially reduce under Formula 2b, only vanish at tier+3; flag to game designer as unintentional all-or-nothing behavior.

**Round 8 (2026-07-16):** Effect-capacity rework review. Found 2 BLOCKING, 3 RECOMMENDED.
- BLOCKING: Rule 8 line 202 says "Core parts must not define upgrade_effects entries of type SKILL_UNLOCK ... AC-01 validates this." AC-01's pass-when text and `_check_nullability` validator cover only `active_skill_id` field — `upgrade_effects` array is never inspected. False-coverage defect: a Core with a SKILL_UNLOCK entry at upgrade tier 4 passes all current checks undetected.
- BLOCKING: EC-01 and EC-02 claim "Always valid" but this is false for Rare/Boss/Proto parts under Rule 8's floor-of-1. A Rare part with both fields null violates AC-01(b). Neither EC cites AC-01, violating the EC↔AC cross-check rule. A tester reading these ECs would write no negative tests for the Rare+ empty-effect case.
- RECOMMENDED: AC-01(a) has no discriminating fixture in its pass-when text. Test file covers Common+1-skill but not Common+2-effects (skill AND passive on a Common). A flat-ceiling-2 implementation escapes the Common+2-effects case.
- RECOMMENDED: `content_effect_capacity_exceeded` for Boss/Prototype is unreachable with the current two-field schema (ceiling=2, max achievable count=2). AC-01 should note this is a forward-guard for schema expansion, not a currently-exercisable check.
- RECOMMENDED: `content_effect_missing` has no fixture in AC-01 or test for Rare ENERGY_CELL (structurally identical to Rare CORE but absent from both AC text and test file).

**Recurring pattern:** Fix introductions create new issues — Round 2 AC-09b fix (changing 0.49 to 0.4875) was correct for the worked example but the AC-09b test assertion also needed the multiplier adjusted to actually produce 1.0 (use ×1000, not ×999). Always re-verify math in any AC that references a formula constant. Round 5 BLOCKING-2 is the same class of error: AC author stated an IEEE 754 behavior that is factually wrong for the chosen inputs. Round 7 BLOCKING-2 is the same root cause again: epsilon missing from the canonical formula expression because the author verified from the Pipeline section, not the formula statement.

**Systemic root cause identified (Round 7):** Every round adding worked-example ACs introduces at least one float precision issue. Authors verify by hand/calculator (which displays rounded values), not by IEEE 754 computation. Mitigation: require Python `float.hex()` or equivalent verification for any AC asserting a specific float output before accepting the AC as written.

**New systemic root cause (Round 8):** Rule prose that says "AC-NN validates this" is not self-enforcing — the AC's pass-when and validator code must be read together to confirm the claim. In Round 8, Rule 8 line 202 cited AC-01 for `upgrade_effects` coverage but the AC's scope never extended there. The `upgrade_effects` field is an array of Dictionaries; it requires a separate validator family, not a nullability check. Watch for any rule that delegates enforcement to an existing AC without adding a new sub-check for the new constraint.

**How to apply:** Each round has introduced new issues. Do not assume a rewritten AC is correct without re-verifying its math independently. Key watch: formula constants in ACs must be verified against the formula itself, not just against each other. "Nice" numbers and stated design intent are not a substitute for arithmetic. For IEEE 754 claims specifically: always compute the float product manually before asserting it is a problematic case. For Formula 2 specifically: the canonical expression is the authoritative source — if it disagrees with a worked example, fix the canonical expression, not just the example. For any AC cited by a rule: trace from the rule text to the AC pass-when text to the validator code and confirm the chain is complete.
