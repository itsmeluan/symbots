# Active Session State

## Current Task
Session 8: Synergy System GDD — /design-review re-review complete (NEEDS REVISION). 6 blocking items found and resolved in-session 2026-07-10. Ready for final re-review (#2).

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED (+ visual amendment 2026-07-10)
- Damage Formula GDD: APPROVED
- Symbot Assembly System GDD: APPROVED 2026-07-10 (Session 5)
- Synergy System GDD: In Review (revised twice — awaiting re-review #2)

## Key Design Decisions (Synergy — current state after revision)
- Bonus types: stat bonuses (flat integers) + passive combat effects (named StringName IDs)
- Thresholds: TIER1=3 (small bonus), TIER2=5 (large bonus), CUMULATIVE (both apply at 5-piece)
- Combined synergies: require constituent tag thresholds (ironclad ≥ 3 AND VOLT ≥ 3); stack with individual synergies
- Wild parts: contribute element tag only; no manufacturer tag
- evaluate() ALWAYS emits synergy_changed (even if result unchanged)
- evaluate_silent(): same computation as evaluate() but does NOT emit signal (TBC battle-start only)
- preview() is strictly read-only (no signal, no cache write)
- Per-Symbot scope only in MVP (team-wide synergies are Vertical Slice)
- Frozen during battle (no re-evaluation on part breaks)
- Maximum 7 simultaneous tiers (verified — 3 manufacturers can't all hit 3-piece in 8 slots)
- 15 ACs total (AC-SYN-01 through AC-SYN-15)
- OQ-6: RESOLVED — SA-F2 is delta; Workshop UI composition formula documented

## Revision History (Session 8 — 2026-07-10 — 6 blockers resolved)
- B2 FIXED: Beat 5 (Mastery) rewritten to single-Symbot cross-synergy mastery; team synergy marked post-MVP
- S1 FIXED: EC-SYN-02 "up to 10 tiers" → "7 tiers (verified maximum)" with proof
- U4 FIXED: UI Req 1 rewritten with 3 indicator states; all states require pending bonus value from content data
- U5 FIXED: "Active + progressing" state defined as third indicator state in UI Req 1
- Q1 FIXED: AC-SYN-14 added (evaluate_silent() does not emit; computes and caches correctly)
- Q2 FIXED: AC-SYN-15 added (tier deactivation when count drops below threshold)
- OQ-6 CLOSED: SA-F2 confirmed as delta; Workshop UI composition formula: effective_delta[S] = SA-F2.delta[S] + (preview().stat_delta.get(S,0) − cached_bonus_block.stat_delta.get(S,0))
- OQ-7 ADDED: Catalog size constraint for Beat 2 (The Hunt), deferred to Part Database content authoring
- "30 theoretical tiers" corrected to "21" in UI Req 1

## Files Changed Session 8
- design/gdd/synergy-system.md (6 edits — Beat 5, EC-SYN-02, UI Req 1, AC-SYN-14, AC-SYN-15, OQ-6/OQ-7)
- design/gdd/reviews/synergy-system-review-log.md (appended revision-pass entry)

## Next Steps
1. /clear this session (context is near limit)
2. /design-review design/gdd/synergy-system.md in fresh session — expected to APPROVE given all blockers resolved
3. After approval: /design-system turn-based-combat — #6 in design order

## Open RECOMMENDED Items (not blocking — flag in re-review)
- Beat 4 tradeoff strength at 3-piece; tier evaluation order undefined; wild parts tradeoff rationale; stacking content-author cap
- Cross-synergy effect deduplication AC missing; float validation in content loading
- AC-SYN-04 tests internal tag_count (not public API); AC-SYN-06/10 misclassified; AC-SYN-12 missing size()
- Combat UI Req 5 underdelegated; display_name length/null fallback unspecified

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Synergy System GDD
Task: Awaiting /design-review (re-review #2 — 6 blockers resolved)
<!-- /STATUS -->
