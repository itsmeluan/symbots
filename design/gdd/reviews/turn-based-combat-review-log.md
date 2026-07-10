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
