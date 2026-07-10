# Active Session State

## Current Task
Session 13: Turn-Based Combat GDD — /design-review round 1 COMPLETE (full mode: game-designer, systems-designer, qa-lead, creative-director). **Verdict: NEEDS REVISION** — 7 genuine blockers (of 11 raised; CD triage), 6 recommended. **ALL blocking + recommended revisions APPLIED in-session 2026-07-10.** GDD status: awaiting re-review (user choosing next step: re-review in fresh session vs. accept-as-approved).

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED (+ visual amendment 2026-07-10)
- Damage Formula GDD: APPROVED
- Symbot Assembly System GDD: APPROVED 2026-07-10 (Session 5)
- Synergy System GDD: APPROVED 2026-07-10 (Session 12, re-review #6; GDD design phase CLOSED — no re-review #7 per CD)

## TBC Review Round 1 — Outcome of Record (2026-07-10)
- Specialists raised 11 BLOCKING; CD confirmed **7 genuine** (only 1 true contradiction — the Shock sign convention; rest were load-bearing spec silences). Zero mechanic redesigns.
- CD performed the skipped CD-GDD-ALIGN gate manually: **Player Fantasy passes on substance**; pillar-tracing (2, 4) clean.
- CD tension rulings: (1) SCAN = RECOMMENDED for TBC (runtime stub added; effect decision escalated to Move DB); (2) free forced switch = balance-watch OQ-TBC-7, not a rule change ("the degenerate play is usually the correct play"); (3) repair stall — mechanic fine, but the anti-stall proof needed the Energy-brake contract.
- Scope signal: XL (12 dependencies, cross-cutting orchestrator, errata on 4 Approved docs).

## Revisions Applied (blocker → fix, all in design/gdd/turn-based-combat.md)
1. `snapshotted_processing` → **ratified PRE-synergy** (`final_stat["processing"]`, never SYN-F4) — user decision; keeps 0–110 ranges exact, epsilon scans valid; AC-TBC-29 "effective processing" wording fixed
2. Shock sign contradiction → renamed to `shock_magnitude` everywhere (replace_all); TBC-F4 outputs/stores POSITIVE 0–33, TBC-F1 subtracts; both variable tables now agree
3. REPAIR Energy-brake → contract rule in Rule 9: `energy_cost > BASE_ENERGY_REGEN` (≥11); TBC-F6 anti-stall rewritten; new AC-TBC-38 (ADVISORY, DEFERRED content validation)
4. Part-Break harvest-dilemma anchor → BINDING Pillar-2 obligation in Dependencies downstream table (Part-Break MUST make part-targeting cost something; must carry its own AC); lean-mode note in Player Fantasy marked resolved
5. `hit_resolved` + `is_battle_active()` → new "Hook Contracts" AC section: AC-TBC-34 (emits once per DAMAGE move, post-Stagger damage 60 fixture — python3-verified vs. exact rational, round gives 61, discriminating), AC-TBC-35 (lockout predicate)
6. Status lifecycle → AC-TBC-36 (decrement-and-expire; status ABSENT at duration 0; no 3rd tick)
7. Voluntary switch → AC-TBC-37 (consumes the turn; contrast with forced AC-TBC-12)

Recommended also applied: AC-TBC-06 split (state vs. rendering — UI assertions moved to Combat UI's ledger); AC-TBC-17 hardened (turn-start bookkeeping before FLED + WILD action-set FAIL); AC-TBC-40 (ON_TURN_START/ON_BATTLE_START dispatch w/ synthetic registry entries); SCAN stub (Rule 9 + EC-TBC-16 + AC-TBC-39: turn-consuming no-op, costs paid); Stagger-doesn't-reduce-Burn note (TBC-F3); TBC-F6 heat/Rule-5 ref; BASE_ENERGY_REGEN hard-floor-8 note; energy_power 110+40 ceiling derivation; heat_max removed from Assembly snapshot row (constant 100, Part DB owns); AC-TBC-22 T=1.0-neutral note; AC-TBC-24 direct-apply_status clarification; OQ-TBC-7 added.
- AC count corrected: **40 numbered (37 BLOCKING unit, 3 ADVISORY) + 4 DEFERRED INT** (prior "29 BLOCKING" was an undercount). ECs now 16 (EC-TBC-16 = SCAN stub).
- No formula coefficients changed — existing epsilon scans remain valid; new AC-TBC-34 fixture value (77×0.79 → floor 60) python3-verified in-session.

## Next Steps
1. **Re-review**: /design-review design/gdd/turn-based-combat.md in a FRESH session (fix-confirmation focus on the 7 blocker regions per CD's mature-doc retuning directive) — OR user may accept-as-approved
2. After TBC approval: consider /design-system move-database BEFORE Encounter Zone (#7) — TBC's MOVE-CONTRACT-1 needs ratification (OQ-TBC-1), SCAN payload needs definition (OQ-TBC-3), Part DB AC-13 blocked on it
3. Pending errata on Approved docs (TBC Dependencies section): Enemy DB ED1-simplified + EDB-2 synergy-ceiling addendum; Synergy OQ-2 budget-closure; DF-1 registry range [1,225]; Part DB ammo_cost=0 content rule

## Standing Obligations (carried forward)
- Part-Break GDD: **BINDING Pillar-2 obligation** (part-targeting must cost something) + own AC — recorded in TBC Dependencies
- Move DB GDD: ratify MOVE-CONTRACT-1 incl. SCAN stub + REPAIR energy_cost ≥ 11
- Part Database content plan + Drop System GDD: Beat 2 vs. OQ-7 5–6 parts-per-tag minimum (HARD CONSTRAINT)
- Economy Designer: Synergy OQ-2's three calibration mandates before MVP content ships
- Workshop UI GDD: DCO-1…9 + combined-tier dual-track + ux-designer #6 findings
- Workshop System GDD: DCO-8 battle-time equip lockout (TBC side now testable via AC-TBC-35)
- Playtest: OQ-TBC-7 free-forced-switch balance watch

## CD PROCESS DIRECTIVES (binding, carried from Session 12)
- Retune adversarial review prompts for mature documents (~3+ cycles): "test could be stronger" is not BLOCKING when the spec is unambiguous. TBC is at cycle 1 — full adversarial was appropriate; re-review should be fix-confirmation focused.

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Turn-Based Combat GDD
Task: Review round 1 revisions applied — awaiting re-review decision
<!-- /STATUS -->
