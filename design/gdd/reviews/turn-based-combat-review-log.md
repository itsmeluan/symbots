# Review Log — Turn-Based Combat System

## Erratum — 2026-07-13 — ST-1 (`completion_bonus_xp` payload field) APPLIED — light re-review touch owed

Source: Symbot Core Progression 4th-pass `/design-review` (2026-07-13), OQ-CP-8 fix (per-boss completion bonus), tracked as **ST-1** in `production/errata-backlog.md`.

**Refight-guard addendum (2026-07-13, same-day post-Approval /review-all-gdds):** Rule 12 payload gained a further field **`is_first_boss_defeat: bool`** (now **eight-field**) — sourced by the boss-approach/Overworld-Nav layer from ZWM-owned `defeated_once` (pre-battle) and relayed by TBC so Core Progression can suppress the boss completion bonus on `LIGHTER_REGATE` refights (CP Rule 3a first-defeat guard; AC-CP-25). Ordering-independent (pre-battle value). AC-TBC-31 unchanged (never enumerated the XP fields). Owed: same light TBC confirmation touch already noted below covers both payload extensions.

**Change (file-verified):** Rule 12 `battle_ended` payload extended to carry **`completion_bonus_xp: int`** (all three outcomes — VICTORY/DEFEAT/FLED — for payload uniformity; the signal is now "seven-field", further extended to eight-field by the refight-guard addendum above). It rides alongside `xp_value`/`enemy_level`; Core Progression consumes it and folds it into `full_xp` per CP Rule 3a. `0` for WILD; per-boss for BOSS (Enemy DB field). AC-TBC-31 (payload/dedup AC) unchanged — it never enumerated the XP fields (consistent with how the 2026-07-12 Level Backbone payload extension was handled). **Owed:** light `/design-review turn-based-combat.md` confirmation touch (mechanical payload extension — Status stays APPROVED); this and the ST-3 touch below can be combined into one TBC re-review.

## Erratum — 2026-07-13 — ST-3 (Core Progression invalid-build combat refusal) APPLIED — light re-review touch owed

Source: Symbot Core Progression 4th-pass `/design-review` (2026-07-13); qa-lead finding **R4-B3** (BLOCKING), tracked as **ST-3** in `production/errata-backlog.md`.

**Problem:** Core Progression EC-CP-05 — after a CORE swap to a lower-level core, now-over-level parts are flagged (not auto-unequipped) and the build "cannot enter combat while invalid." Core Progression exposes `is_build_valid(build) → bool` and explicitly delegates the *combat-entry refusal* to whichever system starts battles. TBC (Approved) contained **no AC** for it — the obligation lived only as prose in Core Progression. **A player who swaps a core and presses "Enter Combat" was stopped by no tested code path.**

**Changes applied (file-verified):**
1. **Rule 2 step 0** (battle-start build-validity precondition): before any snapshot, TBC MUST call `CoreProgression.is_build_valid(build)` for every fielded Symbot; if any is invalid, the battle does not start — TBC emits `battle_start_refused(invalid_symbot_ids, offending_parts)`, instantiates no runtime state, fires no `battle_ended`. Overworld Navigation (Not Started) noted as an additional earlier gate; TBC's check is the authoritative last line of defense.
2. **AC-TBC-42** (BLOCKING, Unit): invalid build (Boss-grade ARMS `level_requirement=6` on a level-4 CORE) refused at battle start, no runtime state created, `battle_start_refused` names the offender, no `battle_ended`; **positive control** for an all-valid roster proceeding normally.
3. **Core Progression** added to TBC's Upstream dependency table as a **Hard** read (`is_build_valid`), annotated as a mutual reference with the Rule 12 `battle_ended` emit (not a design-order cycle — stateless query). Core Progression EC-CP-05 + Bidirectionality note updated to name AC-TBC-42 (owner-pointer discharged).

**Owed:** a light `/design-review turn-based-combat.md` confirmation touch (mechanical erratum adding one precondition + one Unit AC; no design change — Status stays APPROVED). No registry change.

## Review — 2026-07-11 — Verdict: NEEDS REVISION → APPROVED (fix-confirmation of the Part-Break erratum; 2 blockers fixed same session)
Scope signal: S
Specialists: game-designer, systems-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 2 | Recommended: 2 (of ~10 raised; CD downgraded the rest under the mature-doc directive)
Summary: Fix-confirmation re-review of the 8 Part-Break erratum regions applied the previous session. Erratum **design confirmed correct across all 8 regions** (sub-target routing, enemy pipeline, TBC-F7, 4-arg `hit_resolved` — no residual 3-arg refs, all boundary math verified). Two AC-*integrity* defects found — guards that failed to guard, not design flaws:
- **BLOCKING 1 — AC-TBC-INT-01c ordering fixture non-discriminating.** systems-designer AND qa-lead independently proved the fixture (enemy_raw=55, pct=21, count=1) yields 48 under BOTH orderings — floor(55×0.79)=43→floor(43×1.12)=48 vs floor(55×1.12)=61→floor(61×0.79)=48 — so an enrage-before-Stagger bug passed the only test of the ratified POST-Stagger ordering. Fixed: raw 55→50 (correct −43 vs wrong −44; verified divergent). Numeric fix (systems-designer) chosen over qa-lead's pipeline-spy — qa-lead's "structurally impossible" claim was falsified by systems-designer's working counterexample.
- **BLOCKING 2 — AC-TBC-34 region case parenthetical.** The `sub_target == region_id` path had no required GIVEN/THEN/FAIL — a hardcoded-STRUCTURE `hit_resolved` passed. Fixed: promoted to required Fixture B (`sub_target == "left_arm"` ≠ STRUCTURE) + FAIL condition.
- **Recommended (applied):** multiplier source-of-truth note on INT-01 umbrella (BREAK_BIAS/ENRAGE/SPILLOVER owned by Part-Break — retune → re-derive); inline EC↔AC citations for the already-broken redirect (→INT-01e) and floor-collision note (→INT-01f); TBC-F7 post-Stagger *rationale* + calibration-ownership pointer.
Specialist disagreements adjudicated by CD: (1) INT-01c IS broken — game-designer called it "well-constructed/PASS" but did not run the wrong-order path; systems-designer + qa-lead + main reviewer confirmed the 48=48 collision. (2) Fix method = numeric (55→50), not a spy. Downgraded: enrage-calibration argument (real gap, but `ENRAGE_PER_BREAK` is Part-Break-owned → tracked on Part-Break §D, not a TBC gate); BREAK_BIAS cross-reference (maintenance hazard, not a current defect).
No design/formula/coefficient changed; epsilon scans remain valid. Marked APPROVED — the two fixtures now demonstrably diverge, confirmable by inspection without a fresh sweep.
Prior verdict resolved: Yes — the NEEDS REVISION (Part-Break erratum) below is fully addressed and confirmed.

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
