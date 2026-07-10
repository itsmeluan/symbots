---
name: project-synergy-ac-review
description: Synergy System GDD AC review history — round 3 findings; 6 blocking, 6 recommended; key issues are white-box AC, consumer formula ownership, missing error-contract ACs
metadata:
  type: project
---

Synergy System GDD has undergone three AC review rounds as of 2026-07-10.

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

### Recurring pattern (consistent with Part DB and Enemy DB reviews):

- Error-contract paths (wrong input, unknown key, empty array) are specified in Edge Cases but never have ACs. This is now a third consecutive GDD with this pattern.
- White-box assertions keep appearing (tag_count here, calibration table values in Part DB). Always verify: does the named field exist as a public observable?
- Consumer formula ownership gap: SYN-F4 is the equivalent of the Part DB's "formula owned by consumer" problem seen in AC-15a (tests Drop System, not Part Database).

**How to apply:** For every Edge Case section in a GDD, check: does each EC have a corresponding AC? If the EC says "no crash," there must be an AC with a fixture that triggers that code path. For every formula in a GDD, confirm: is this formula computed by this system, or by a downstream consumer? Consumer formulas need a home in the consumer's GDD, not this one.
