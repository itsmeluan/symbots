# Active Session State

## Current Task
Session 9: Synergy System GDD — /design-review re-review #3 complete (NEEDS REVISION). 13 blocking items found and resolved in-session 2026-07-10. Ready for fresh-session re-review #4 (expected APPROVED).

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED (+ visual amendment 2026-07-10)
- Damage Formula GDD: APPROVED
- Symbot Assembly System GDD: APPROVED 2026-07-10 (Session 5)
- Synergy System GDD: In Review (revised three times — awaiting re-review #4)

## Key Design Decisions (Synergy — current state after re-review #3 revision)
- Bonus types: stat bonuses (flat integers) + passive combat effects (named StringName IDs)
- Thresholds: TIER1=3 (small bonus), TIER2=5 (large bonus), CUMULATIVE (both apply at 5-piece)
- Combined synergies: INDEPENDENT counts (ironclad ≥ 3 AND VOLT ≥ 3), NO co-location required (author-confirmed 2026-07-10); stack with individual synergies
- Wild parts: contribute element tag only; trade MANUFACTURER-count throughput (not combined-synergy access — EC-SYN-03 corrected)
- Registration order: ascending ALPHABETICAL by tier ID (author decision; governs keep-first dedup + active_synergies emission; independent of content-file layout)
- evaluate() ALWAYS emits synergy_changed; consumers must diff on active_synergies SET (not bonus_block equality) — Rule 7 change-detection contract
- evaluate_silent(): same computation, no signal (TBC battle-start only)
- preview() strictly read-only (no signal, no cache write)
- Per-Symbot scope only in MVP (team-wide synergies are Vertical Slice)
- Frozen during battle (no re-evaluation on part breaks)
- Maximum 7 simultaneous tiers (verified)
- 18 ACs total (AC-SYN-01 through AC-SYN-18); 12 ECs (EC-SYN-01 through EC-SYN-12)
- New "Downstream Consumer Obligations" section (DCO-1…6) delegates UI-scoped items to Workshop UI/Combat UI GDDs

## Revision History (Session 9 — 2026-07-10 — 13 blockers resolved)
1. EC-SYN-03 rewritten (wild-parts rationale was mechanically false; independent-counts confirmed)
2. Registration order defined (alphabetical by tier ID) in Rule 3; Rule 7/SYN-F3 updated
3. Beat 1 +15 → +8 (harmonized to AC anchor)
4. EC-SYN-11 added (duplicate tags → count-each-occurrence; Part DB validation owns it)
5. EC-SYN-12 added (empty tier.requirements → skip+log; SYN-F2 non-empty invariant note)
6. Rule 7 change-detection contract (diff on active_synergies set)
7. Downstream Consumer Obligations section added (DCO-1…6)
8. AC-SYN-16 added (unique combined effect ID preserved)
9. AC-SYN-04 rewritten to observable outputs (was asserting internal tag_count)
10. AC-SYN-06/10 labeled consumer-owned (SYN-F4 contract, not SynergySystem.gd)
11. AC-SYN-12 explicit size()==2 assertion
12. AC-SYN-17 added (unknown stat key no-crash, EC-SYN-06)
13. AC-SYN-18 added (wrong-length array, EC-SYN-10)
+ SYN-F2 safe-access note (.get(tag,0))

## Files Changed Session 9
- design/gdd/synergy-system.md (16 edits across status, Beat 1, Rules 3/7, SYN-F2/F3, EC-SYN-03, EC-SYN-11/12, DCO section, AC preamble, AC-SYN-04/06/10/12, AC-SYN-16/17/18)
- design/gdd/reviews/synergy-system-review-log.md (appended re-review #3 entry)

## Next Steps
1. /clear this session (context past 50%)
2. /design-review design/gdd/synergy-system.md in fresh session — re-review #4, expected APPROVED (all 13 blockers resolved; only RECOMMENDED items remain)
3. After approval: /design-system turn-based-combat — #6 in design order

## Open RECOMMENDED Items (not blocking — flag in re-review #4)
- Beat 4 tradeoff tension collapses above 3-piece floor (game N4 — open across 3 reviews)
- No stat_delta budget cap for 7-tier stack; combined-threshold calibration rationale (game N10)
- "Stateless pure computation" wording contradicts cached/freezable block; Rule 8 freeze has no enforcement mechanism (game N11 / sys F8)
- Float infiltration via content loader — no enforcement owner (blocked on OQ-1); SYN-F2 min_count=0, null synergy_tags, null-in-effects edge cases (sys)
- OQ-6 marked RESOLVED but precondition has no owner (Workshop GDD doesn't exist) — consider re-opening (sys)
- 7-tier stack vs DF-1 output ceiling risk (sys); formula variable-table format non-compliance (sys)
- ACs for EC-SYN-07, AC-SYN-13 scenario B, preview() out-of-range; AC-SYN-14 note overstates coverage; coverage ~65-70% vs 80% (qa)
- ux precision: Combat UI Req 5 format, display_name char-limit/null fallback, lower-bound-of-3, "visually distinguishable" (mostly now folded into DCO section)

## SYSTEMIC PROCESS FLAG (qa-lead, endorsed by creative-director)
Edge Cases defining "no crash on bad input" have shipped WITHOUT corresponding ACs across ALL THREE Synergy reviews. This is a GDD-TEMPLATE gap, not a per-doc defect. Recommendation: amend the GDD standard so every observable-outcome EC must reference a verifying AC, and add an EC↔AC cross-check to the completeness pass. Will recur on every future GDD until the template changes.

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Synergy System GDD
Task: Awaiting /design-review (re-review #4 — 13 blockers resolved; expected APPROVED)
<!-- /STATUS -->
