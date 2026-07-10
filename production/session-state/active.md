# Active Session State

## Current Task
Session 6: Synergy System GDD designed — IN REVIEW. Awaiting /design-review.

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

## Next Steps
1. /design-review design/gdd/synergy-system.md — run formal review before proceeding to TBC
2. /design-system turn-based-combat — #6 in design order (depends on Damage Formula, Assembly, Enemy Database; Synergy must be at least Designed)

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Synergy System GDD
Task: Awaiting /design-review
<!-- /STATUS -->
