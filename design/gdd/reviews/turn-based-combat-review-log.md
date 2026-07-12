# Review Log — Turn-Based Combat System

## Review — 2026-07-11 — Verdict: NEEDS REVISION (Part-Break erratum) → erratum applied same session
Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 8 | Recommended: 2
Summary: Focused erratum re-review triggered by Part-Break's approval (2026-07-11), which placed a "Substantial" obligation on TBC's core damage pipeline. TBC had not yet applied it. Specialists unanimously found the 5 named items undone, plus 4 load-bearing prerequisites that make them writable: (1) enrage (PB-F5) had no home — TBC documented no enemy-side resolution pipeline; (2) `enemy_hit_resolved` unanchored + Stagger×enrage floor-ordering unpinned; (3) no TBC formula slot for enrage; (4) `hit_resolved(move,damage,target)` signature could not express STRUCTURE-vs-region routing. CD confirmed these are prerequisites, not scope creep — "the erratum is not correct if enrage is bolted on without an enemy pipeline, a formula slot, and a sub_target-aware signature." No specialist disagreements (complementary: GD found the hole, SD found why unwritable, QA specified how to test it closed).
Prior verdict resolved: Supersedes the 2026-07-10 APPROVED (invalidated by the downstream Part-Break approval).

### Same-session resolution (2026-07-11) — all 8 blockers applied, user-approved
Two design decisions ratified by the user before editing:
- **Stagger×enrage ordering: POST-Stagger** — `enemy_hit_resolved` is post-DF-1/post-Stagger; enrage scales the final delivered hit.
- **Floor-collision @ move_damage=1: accepted as documented degenerate** — no Part-Break PB-F3 cascade (inversion exists only at move_damage=1, unreachable at realistic DF-1 outputs).

Fixes: (1) Rule 10 gains sub-target routing (STRUCTURE→PB-F1 by TBC, region→PB-F2 by Part-Break + PB-F3 20% spillover by TBC, `BREAK_BIAS_MULTIPLIERS`, already-broken redirect); (2) Rule 10 enemy side defines the enemy damage pipeline + enrage insertion point; (3) new **TBC-F7** enrage slot (owns PB-F5 application, discriminating examples + identity check); (4) `hit_resolved` widened to `(move,damage,target,sub_target)` — propagation flag on Passive DB ON_HIT subscribers; (5) Rule 9 Move Contract gains `break_bias` (Basic Attack=BALANCED) + runtime `sub_target`; (6) Dependencies Part-Break row → Approved, BINDING Pillar-2 obligation → DISCHARGED (interactions table + bidirectionality synced); (7) AC-TBC-INT-01 un-DEFERRED → 6 BLOCKING integration ACs (01a–01f) + AC-TBC-34 widened; (8) non-gating: Player Fantasy gains the enrage/spillover-kill beat. No formula coefficients changed (epsilon scans remain valid; enrage epsilon deferred to Part-Break §D scan).

**Re-review guidance:** fix-confirmation on the 8 blocker regions (CD recommendation) — not a fresh adversarial sweep. Run in a clean session after /clear.

**Open propagation item:** Passive DB ON_HIT subscribers (`volt_shock_on_hit`, `kinetic_stagger_on_hit`) must tolerate the widened four-arg `hit_resolved` — confirm/annotate in the Passive DB GDD.

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
