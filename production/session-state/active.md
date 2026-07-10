# Active Session State

## Current Task
Session 7: Synergy System GDD — /design-review complete (MAJOR REVISION NEEDED). Revisions applied 2026-07-10. Awaiting verdict on re-review vs. Approve.

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED (+ visual amendment 2026-07-10)
- Damage Formula GDD: APPROVED
- Symbot Assembly System GDD: APPROVED 2026-07-10 (Session 5)
- Synergy System GDD: DESIGNED 2026-07-10 (Session 6) — status: In Review

## Key Design Decisions (Synergy — preserved for next reviewer)
- Bonus types: stat bonuses (flat integers) + passive combat effects (named StringName IDs)
- Tiers: 2-piece (small bonus) and 4-piece (large bonus), CUMULATIVE (both apply when 4-piece hit)
- Combined synergies: require constituent tag thresholds met simultaneously (ironclad ≥ 2 AND VOLT ≥ 2); bonuses STACK with individual synergies, do not replace them
- Wild parts: contribute element tag only; no manufacturer tag
- evaluate() ALWAYS emits synergy_changed (even if result unchanged)
- preview() is strictly read-only (no signal, no cache write)
- Per-Symbot scope only (team-wide synergies deferred to Vertical Slice)
- Frozen during battle (no re-evaluation on part breaks)
- Scope conflict resolved: Synergy → MVP (game-concept.md updated 2026-07-10)
- 13 ACs total — 6 WEAK ACs from draft rewritten after qa-lead review; 4 new ACs added
- Section C amended: combined synergy stacking rule made explicit; always-emit invariant added

## Files Changed This Session
- design/gdd/synergy-system.md (CREATED — all 8 required sections + Visual/Audio, UI, Open Questions)
- design/gdd/systems-index.md (Synergy System status → Designed)
- design/gdd/game-concept.md (removed stale "NOT in MVP" note; updated scope tier table)
- design/registry/entities.yaml (added SYN-F1, SYN-F2, SYN-F3, SYN-F4 + SYNERGY_THRESHOLD_TIER1, SYNERGY_THRESHOLD_TIER2)
- production/session-state/active.md (this file)

## Revision Summary (applied 2026-07-10 in /design-review session)
- A1 FIXED: TIER1 raised 2→3, TIER2 raised 4→5. Section B already correct for 3-piece. Tier names "3-piece"/"5-piece" throughout.
- A2 FIXED: active_synergies typed as Array[StringName] in Rule 7 signal parameters.
- A3 FIXED: preview() slot-displacement specified (candidate replaces current occupant); out-of-range returns empty block + logs error.
- A4 FIXED: EC-SYN-03 reworded — wild parts double-dipping documented as intended design.
- evaluate_silent() added to Rule 7 + States table for TBC battle-start (prevents spurious Workshop UI signal at battle start).
- "Detailed Design" section renamed to "Detailed Rules".
- EC-SYN-02 updated: max simultaneous tiers = 10 (not 6).
- UI Req 1 scoped to build-relevant tiers (3–8 max on screen).
- OQ-6 added: verify SA-F2 return type before Workshop UI GDD authoring.
- All 13 ACs updated for new thresholds (3/5-piece); 5 weak ACs fixed; fixtures adjusted.
- entities.yaml: SYNERGY_THRESHOLD_TIER1=3, SYNERGY_THRESHOLD_TIER2=5.

## Next Steps
1. Decide: re-review synergy-system.md in a new session, or accept revisions as Approved
2. /design-system turn-based-combat — #6 in design order (depends on Damage Formula, Assembly, Enemy Database; Synergy must be at least Approved)

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Synergy System GDD
Task: Awaiting /design-review
<!-- /STATUS -->
