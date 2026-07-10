---
name: workshop-ux-open-issues
description: 8 adversarial UX problems found in the Symbot Assembly GDD — must be resolved before Workshop UI GDD can be authored
metadata:
  type: project
---

Adversarial review conducted 2026-07-10 against `design/gdd/symbot-assembly.md`.

## Critical Issues (blockers)

**Issue 2 -- No undo for equip.**
Rule 3 equip is atomic and irreversible. On touch, misfires are normal. No confirmation, no undo, no cancel is specified. The player must manually re-equip to recover from a misfire. Breaks the fast-experimentation fantasy.

**Issue 3 -- Hover preview (SA-F2) is impossible on iOS touch.**
SA-F2 specifies "recompute on hover." iOS has no hover state. The Workshop UI GDD must replace this with a native touch pattern (e.g., tap-to-preview mode, long-press, dedicated preview panel) before implementation stories can be written.

## High Issues

**Issue 1 -- 11 simultaneous stat deltas on a mobile screen.**
No screen layout budget is defined in the GDD. Chassis swaps produce non-zero deltas across all 11 stats at once, creating a simultaneous multi-element change the player cannot process. Workshop UI GDD must specify a visual hierarchy for stat deltas.

**Issue 5 -- Synergy excluded from SA-F2 delta.**
The delta shown in Workshop is not the true gameplay delta when a swap crosses a synergy threshold. Players will make comparisons against incorrect information. Workshop UI GDD must surface synergy delta separately or the delta is misleading.

**Issue 7 -- 24-part team management with no navigation model.**
3 Symbots x 8 slots = 24 parts. No inter-Symbot navigation, Inventory filter model, or part-transfer flow is defined. This is MVP scope-critical complexity not flagged as a risk.

## Medium Issues

**Issue 4 -- Fixed move ordering with no stated rationale.**
Move 2=WEAPON, Move 3=HEAD, Move 4=ARMS is an invariant. No design justification given. Limits player tactical expressiveness relative to the stated build-ownership fantasy.

**Issue 6 -- CHIPSET and ENERGY_CELL are stat-only tax slots.**
No skill, no passive, no move pool contribution in MVP. These slots will feel like mandatory fillers, reducing Workshop depth without reducing Workshop complexity.

**Issue 8 -- No cross-Symbot comparison.**
SA-F2 is intra-build only. Team-level build decisions (role allocation across 3 Symbots) require working memory with no UI support.

**Why:** These issues were found during the first adversarial UX review pass before any Workshop UI design work has started. They are constraints that must feed into the Workshop UI GDD.

**How to apply:** Before authoring `design/ux/workshop.md`, explicitly resolve Issues 2 and 3 first -- they are platform-critical and will shape the entire interaction model. Issues 1, 5, 7 must be addressed in the Workshop UI spec before passing to implementation. Issues 4, 6, 8 can be addressed in a later design pass if needed for MVP scope.

See also: [[platform-constraints]]
