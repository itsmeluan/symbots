# Active Session State

## Current Task
Session 11: Synergy System GDD — /design-review re-review #5 complete (NEEDS REVISION → full-scope revision applied in-session). 4 blockers + recommended batch ALL resolved 2026-07-10. Ready for fresh-session re-review #6 (creative-director: APPROVE expected; guardrail — new STRUCTURAL blockers at #6 trigger scope/process intervention).

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED (+ visual amendment 2026-07-10)
- Damage Formula GDD: APPROVED
- Symbot Assembly System GDD: APPROVED 2026-07-10 (Session 5)
- Synergy System GDD: In Review (revised five times — awaiting re-review #6)

## Key Design Decisions (Synergy — current state after re-review #5 revision)
- Bonus types: stat bonuses (flat integers) + passive combat effects (named StringName IDs)
- Thresholds: TIER1=3, TIER2=5, CUMULATIVE; combined synergies = independent counts, no co-location
- Registration order: ascending alphabetical by tier ID (governs dedup + emission order); AC-SYN-12 now asserts strict ORDERED equality (order-independent check was a wrong test); AC-SYN-05b proves dedup determinism with a cross-prefix reverse-file-order fixture
- Requirements validity invariant: non-empty AND min_count ≥ 1; min_count > 8 = silent-safe dead tier (validation warning, not a skip)
- **NEW: SYN-F4 cross-system range contract** — effective_stat deliberately uncapped; DF-1's registered [1,165] output range is invalidated; TBC GDD must re-derive DF-1 ranges under synergy-amplified inputs (tracked in Dependencies table)
- **NEW: Rule 9 null candidate** — preview(null, slot, parts) = unequip preview, valid input, slot treated as empty; null-guard mandatory (EC-SYN-14, AC-SYN-24)
- **NEW: effects type guarantee** — synergy_bonus_block.effects always Array[StringName], never null (mirrors stat_delta int guarantee)
- **NEW: DCO-9** — Workshop UI GDD must define a testable AC for the Beat 3 first-crossing presentation
- DCO-2 constraint added: combined-tier indicator must never imply constituents deactivated (3 tiers simultaneously active)
- OQ-7 upgraded to HARD CONSTRAINT on Part DB content plan + Drop System GDD (Beat 2 delivery gate)
- OQ-2 now carries 3 calibration mandates: (i) manufacturer bonuses must compensate wild-part element-padding asymmetry; (ii) combined synergies must be reachable — dual-tag parts required in MVP pool; (iii) viability target vs pure-stat builds
- evaluate() always emits; evaluate_silent() for TBC battle-start (AC-SYN-14 now has combined-path Scenario B); no self-lock after silent (AC-SYN-25); effect IDs pass through unfiltered (AC-SYN-26); 7-tier max-stress fixture (AC-SYN-27)
- 28 ACs (AC-SYN-01…05, 05b, 06…27); 14 ECs (EC-SYN-01…14); every EC carries a Verified-by AC reference
- DCO-1…9 delegate UI/Workshop-System-scoped items downstream

## CD Adjudications of Record (re-review #5)
- All 3 game-designer design-gap blockers DISCHARGED as tracked obligations (per the GDD's own DCO/OQ deferral philosophy; raising fresh design bars on pass 5 = goalpost-moving) → routed to OQ-7 hard constraint + OQ-2 mandates
- SD's DF-1 range finding: defect real, but registry edit is downstream errata on the Damage Formula/TBC GDD; only the contract note blocks this doc
- qa-lead's AC-SYN-12 finding beats the main reviewer's structural pass: structural completeness (has pass/fail) ≠ assertion correctness — "this is exactly why the adversarial layer exists"
- min_count>8 demoted vs. the #4 min_count=0 blocker: dead tier never wrongly activates (silent-safe); false-activation was the blocking hazard

## Files Changed Session 11
- design/gdd/synergy-system.md (~20 edits: status; Player Fantasy beat-ordering note; Rule 9 null-candidate sentence; SYN-F2 min_count>8 note; SYN-F3 validator/dev-log + effects type guarantee; SYN-F4 DF-1 contract note; EC-SYN-02/05 verified-by updates; EC-SYN-14 new; Dependencies TBC row; UI Req 1 display_name validation; DCO-2 constraint + DCO-9 new; AC ownership range; AC-SYN-05b new; AC-SYN-12 strict ordering; AC-SYN-14 Scenario B; AC-SYN-17 FAIL line; AC-SYN-24/25/26/27 new; OQ-2 mandates; OQ-7 hard constraint)
- design/gdd/reviews/synergy-system-review-log.md (appended re-review #5 entry)

## Next Steps
1. /clear this session
2. /design-review design/gdd/synergy-system.md in fresh session — re-review #6 (CD: APPROVE expected; verify the 4 blocker fixes + spot-check recommended batch)
3. After approval: /design-system turn-based-combat — #6 in design order. TBC GDD must: define passive effect ID registry (OQ-3); re-derive DF-1 ranges under synergy-amplified stats (SYN-F4 contract); document Synergy dependency
4. **BEFORE authoring turn-based-combat GDD**: action the GDD-template amendment (see systemic flag below) — CD directive from re-review #4, still pending

## Standing Obligations Created Session 11
- TBC/Damage-Formula GDD: re-derive DF-1 registered output range under synergy-amplified inputs
- Part Database content plan + Drop System GDD: validate Beat 2 against OQ-7's 5–6 parts-per-tag minimum (HARD CONSTRAINT)
- Economy Designer: OQ-2's three calibration mandates mandatory before MVP content ships

## SYSTEMIC PROCESS FLAG — STILL ACTIONABLE (CD directive, re-review #4)
Amend the GDD standard (.claude/rules/design-docs.md + design/CLAUDE.md): every observable-outcome EC must reference a verifying AC (or state why none exists), and the /design-review completeness pass must run an EC↔AC cross-check. Apply BEFORE authoring the Turn-Based Combat GDD.

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Synergy System GDD
Task: Awaiting /design-review (re-review #6 — 4 blockers + recommended batch resolved; CD expects APPROVED)
<!-- /STATUS -->
