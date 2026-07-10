# Review Log — Turn-Based Combat System

## Review — 2026-07-10 — Verdict: NEEDS REVISION
Scope signal: XL
Specialists: game-designer, systems-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 7 | Recommended: 6
Summary: Specialists raised 11 BLOCKING flags; the creative-director's triage confirmed 7 genuine — only one a true contradiction (the `shock_penalty` sign convention between TBC-F4 and TBC-F1); the rest were load-bearing specification silences (`snapshotted_processing` pre/post-synergy, the anti-stall proof's dependency on an unspecified Repair energy cost, the harvest dilemma unanchored as a Part-Break contract) and AC coverage holes (`hit_resolved` emission, status expiry lifecycle, voluntary-switch turn cost). Zero mechanic redesigns required. The CD manually performed the lean-mode-skipped CD-GDD-ALIGN gate: the Player Fantasy section passes on substance. CD stated the GDD is an APPROVE once the 7 fixes land.
Prior verdict resolved: First review

### Same-day resolution (2026-07-10, same session)
All 7 blocking + 6 recommended items were applied immediately after the verdict, with user approval:
- `snapshotted_processing` ratified **pre-synergy** (user decision; keeps 0–110 ranges exact and epsilon scans valid)
- Sign convention unified as positive `shock_magnitude` (F4 stores positive, F1 subtracts)
- REPAIR Energy-brake contract added to Rule 9 (`energy_cost > BASE_ENERGY_REGEN`, ≥ 11) + AC-TBC-38
- Part-Break BINDING Pillar-2 obligation recorded in Dependencies (part-targeting must impose a cost; own AC required)
- New ACs 34–40: hit_resolved emission (fixture python3-verified discriminating), is_battle_active(), status expiry, voluntary switch, ON_TURN_START/ON_BATTLE_START dispatch, SCAN stub, REPAIR validation
- SCAN runtime stub (Rule 9 + EC-TBC-16); AC-TBC-06 state/rendering split; AC-TBC-17 hardened; five one-line spec clarifications; OQ-TBC-7 forced-switch balance watch
- AC totals corrected: 40 numbered (37 BLOCKING unit, 3 ADVISORY) + 4 DEFERRED integration; ECs now 16
- No formula coefficients changed — epsilon scans remain valid

**Re-review guidance (CD directive):** fix-confirmation on the 7 blocker regions; do not re-run a full adversarial sweep as if this were an unreviewed document.

**CD tension rulings of record:** (1) SCAN — runtime stub is TBC's; the effect/payload decision is the Move DB GDD's (with Enemy DB ED6). (2) Free forced switch — legitimate design, tracked as OQ-TBC-7 balance watch, no rule change for MVP. (3) Repair stall — the mechanic and 3-HP margin are fine (SD-7 Claim A rejected); only the proof's contract gap was blocking (Claim B accepted, closed via Rule 9).

## Review — 2026-07-10 — Verdict: APPROVED
Scope signal: XL
Specialists: systems-designer, qa-lead, game-designer, creative-director (senior synthesis)
Blocking items: 0 | Recommended: 0 (2 minor observations tracked as non-gating follow-ups)
Summary: Fix-confirmation re-review per the CD directive (not a fresh adversarial sweep). All 7 prior blockers confirmed resolved by their domain specialists: (1) `snapshotted_processing` PRE-synergy — consistent across formula text/tables/examples/ACs, zero residue; (2) Shock sign convention unified positive; (3) REPAIR anti-stall energy contract in Rule 9 + AC-TBC-38; (4) ACs 34–40 added, AC-TBC-34 math verified discriminating; (5) AC-TBC-06 state/rendering split cleanly; (6) harvest-dilemma BINDING Pillar-2 obligation well-placed and loophole-closed on Part-Break; (7) `hit_resolved` hook precisely defined + AC-TBC-34. Epsilon scan claim consistent with formula language throughout. No new blockers; no specialist disagreements. CD held to the first-review commitment ("APPROVE once the 7 fixes land").
Prior verdict resolved: Yes — NEEDS REVISION (2026-07-10) fully addressed.

### Tracked non-gating follow-ups (do not block approval)
1. **AC-TBC-37** contrast fixture not self-contained — "voluntary and forced switch behave identically" FAIL only catchable by running AC-TBC-37 + AC-TBC-12 Scenario B together. Fold a dual-path scenario in at implementation time. [qa-lead]
2. **`hit_resolved` `target` param** is the combatant record, not a region ID — Part-Break GDD must decide how player region-targeting intent reaches accrual. First design question for the Part-Break GDD. [game-designer]
3. **ON_OVERHEAT dispatch** deferred (AC-TBC-40 covers ON_TURN_START/ON_BATTLE_START only) — standing watch so content authoring ON_OVERHEAT effects doesn't outrun trigger implementation. [qa-lead]
