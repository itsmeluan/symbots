---
name: project-synergy-ac-review
description: Synergy System GDD AC review history — round 5 findings; 5 blocking, 3 recommended; key issues are wrong AC (AC-SYN-12 order-independence), 7-tier fixture gap, null-candidate preview gap
metadata:
  type: project
---

Synergy System GDD has undergone five AC review rounds as of 2026-07-10.

**Why:** Shift-left QA; Synergy System is a Core-layer system that all downstream Workshop, TBC, and Workshop UI systems depend on.

**Round 1 (2026-07-10):** Embedded in design review. Found 2 QA-flagged items (RECOMMENDED): AC-SYN-04 white-box, AC-SYN-06/10 consumer formula. Both demoted to next re-review.

**Round 2 (2026-07-10):** Full re-review after MAJOR REVISION. Found 3 QA RECOMMENDED: AC-SYN-04 tests internal state; AC-SYN-06/AC-SYN-10 misclassified (SYN-F4 consumer); AC-SYN-12 missing size() assertion.

**Round 3 (2026-07-10) — current round:** Adversarial specialist review. Found 6 BLOCKING, 6 RECOMMENDED.

### BLOCKING items (6):

1. **AC-SYN-04 UPGRADED TO BLOCKING:** Asserts `tag_count["THERMAL"]` — an internal GDScript local variable, not a public observable. Rewrote to test `cached_bonus_block` + `active_synergies` only. No internal field exposure needed.

2. **AC-SYN-06 + AC-SYN-10 UPGRADED TO BLOCKING:** Both test SYN-F4 (`effective_stat = max(0, base + delta)`), which is a CONSUMER formula owned by TBC/Workshop UI — not computed by SynergySystem.gd. As written, neither TBC nor the Synergy programmer knows who owns the test. Resolution: move ACs to TBC/Workshop GDD OR add explicit "Owner: TBC programmer" label.

3. **AC-SYN-12 UPGRADED TO BLOCKING:** "Set equality" is not native in GDScript. Without explicit `size() == 2` assertion, an implementation returning a spurious third tier ID passes the two `has()` checks. Fix: add `active_synergies.size() == 2` as the discriminating assertion.

4. **NEW — No AC for EC-SYN-06 (unknown stat key):** EC-SYN-06 states unknown stat keys in stat_delta must not crash the system. GDScript `[]` on a Dictionary throws on missing key; `.get()` does not. This is a silent bug class. No AC catches it. Add AC-SYN-16.

5. **NEW — No AC for EC-SYN-10 (wrong-length array):** EC-SYN-10 specifies behavior for short (<8) and long (>8) input arrays. No AC tests either case. Add AC-SYN-17 with two scenarios.

6. **NEW — No AC for constituent + combined effect deduplication order:** SYN-F3 explicitly states combined synergy effects are suppressed when a constituent already granted the same ID (keep-first in registration order). AC-SYN-05 only tests same-synergy deduplication (VOLT 3-piece + 5-piece). No AC tests cross-synergy-type deduplication. Add AC-SYN-18.

### RECOMMENDED items (6):

- AC-SYN-07/EC-SYN-07: No AC for empty `synergy_tags = []` array path (different from null-slot path). Not blocking because GDScript for-loop over [] is safe, but distinct iteration path.
- AC-SYN-13 Scenario B: Combined synergy preview activation (tipping two constituent counts simultaneously) not tested — only single-tag preview tested.
- AC-SYN-14 note overstates: says it's a "comprehensive divergence detector" but only covers VOLT single-tag path; combined synergy path divergence not covered by this fixture.
- AC ordering dependency: If AC-SYN-01 fails, AC-SYN-02 through 15 cascade. Add prerequisite note; use GUT skip_all_if pattern.
- Coverage estimate: ~65–70% branch coverage with current 15 ACs — below the 80% coding-standards requirement.
- preview() out-of-range slot (Rule 9): No AC tests that `target_slot < 0` or `> 7` returns empty block without crash.

### Round 5 (2026-07-10) — adversarial re-review #5: 5 BLOCKING, 3 RECOMMENDED.

1. **BLOCKING — 7-tier maximum fixture missing (EC-SYN-02):** GDD claims the 7-tier simultaneous build is "content-authoring guidance, not a distinct code path" — this is wrong for test purposes. Needs dedicated AC.
2. **BLOCKING — AC-SYN-12 "order-independent" assertion CONTRADICTS Rule 3:** Rule 3 defines mandatory alphabetical-by-tier-ID emission order. AC-SYN-12 explicitly allows any order ("order-independent"). This is a WRONG assertion, not a missing test. Must change to ordered equality assertion.
3. **BLOCKING — No AC for keep-first alphabetical effect dedup order:** AC-SYN-05 proves dedup count is 1; no AC proves the FIRST (alphabetically-earlier-tier) occurrence is kept, not the last. Proposed AC-SYN-05b.
4. **BLOCKING — AC-SYN-14 named gap: evaluate_silent() on combined-synergy fixture never tested:** AC-SYN-14 note explicitly flags that combined-synergy path divergence is uncovered. Proposed AC-SYN-14b (ironclad=3, VOLT=3 combined fixture via evaluate_silent).
5. **BLOCKING — null candidate_part in preview() untested and undefined in Rule 9:** Null candidate = "unequip this slot" is the natural Workshop UI call. Not specified in Rule 9, not tested. Proposed AC-SYN-24 + Rule 9 amendment.
6. **RECOMMENDED — Rule 8 post-evaluate_silent evaluate() overwrite not tested:** evaluate() after evaluate_silent() should overwrite cache and emit. An impl that self-locks after silent call would silently break Workshop. Simple sequence test.
7. **RECOMMENDED — EC-SYN-05 effect pass-through not isolated:** No AC exercises a KNOWN-UNKNOWN effect ID to prove no filtering occurs. AC-SYN-17 covers stat-key pass-through; similar coverage for effect array needed.
8. **RECOMMENDED — AC-SYN-17 missing FAIL condition for drop-on-unknown-key bug:** "stat_delta does not contain 'speed'" should be explicit FAIL, not just an implicit assertion failure.

Finding 2 (AC-SYN-12 wrong assertion) is the highest-risk: it actively prevents catching order violations. Rule 7 consumer diff-on-active-synergies gap is NOT a Synergy System gap — it belongs in Workshop UI GDD (not yet written).

### Recurring pattern (consistent with Part DB and Enemy DB reviews):

- Error-contract paths (wrong input, unknown key, empty array) are specified in Edge Cases but never have ACs. This is now a third consecutive GDD with this pattern.
- White-box assertions keep appearing (tag_count here, calibration table values in Part DB). Always verify: does the named field exist as a public observable?
- Consumer formula ownership gap: SYN-F4 is the equivalent of the Part DB's "formula owned by consumer" problem seen in AC-15a (tests Drop System, not Part Database).

**How to apply:** For every Edge Case section in a GDD, check: does each EC have a corresponding AC? If the EC says "no crash," there must be an AC with a fixture that triggers that code path. For every formula in a GDD, confirm: is this formula computed by this system, or by a downstream consumer? Consumer formulas need a home in the consumer's GDD, not this one.

**New pattern from round 5:** Watch for WRONG assertions, not just missing ones. An AC that contradicts the spec (e.g., "order-independent" when order is mandated) is more dangerous than a missing AC — it gives false confidence AND actively masks a real bug class. When a spec defines a deterministic order, the AC must assert that exact order.
