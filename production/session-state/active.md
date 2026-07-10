# Active Session State

## Current Task
Session 16: **Passive Database GDD `/design-review`** (full mode: game-designer, systems-designer, qa-lead, creative-director). Verdict **NEEDS REVISION — 4 blocking gates, all resolved same session**. Awaiting **fix-confirmation re-review in a FRESH session** (user chose this path).
**Run next (after /clear):** `/design-review design/gdd/passive-database.md` — fix-confirmation focus on the 4 fixed regions (below), not a full re-review.

### Passive DB blockers resolved this session (all in design/gdd/passive-database.md)
1. **Schema hole** — STAT_AURA/RESOURCE_EFFECT/STRUCTURAL_EFFECT had no data fields → added **Rule 3a `behavior_params`** typed sub-schema; added field to Rule 1 + Rule 5 table.
2. **Axis decision (dissolved 2 blocks)** — ratified **`behavior_class` as sole resolution axis**; `passive_class` demoted to pure metadata; **Rule 4 stacking defaults re-keyed onto `behavior_class`**.
3. **`scope`/`ON_WEAPON_HIT` + TBC vocab mismatch** — removed `ON_WEAPON_HIT`; collapsed to `ON_HIT` + `scope: WEAPON_ONLY` (matches TBC Rule 13 exactly, grounded by reading TBC line 101); added `ON_TURN_START` for parity; `PERSISTENT` = application mode. Added Rule 2a (ON_OVERHEAT fires BEFORE Overheat consequence).
4. **AC-PDB-02 orphan fixture untestable** (guardrail for PassiveDB↔TBC divergence) — gave it `ON_BATTLE_START` trigger + observable + substring-ID assertion + FAIL. AC count corrected (was "9 BLOCKING" → 12 BLOCKING + 5 ADV-DEFERRED + 4 activates-on-first-content).
5. **OQ-PDB-1 reclassified** as named critical-path dependency (blocks Part DB Rare+ Core entries + Pillars 3–4) with content charter (flat-riders-by-design; inherits AC-PDB-D1–D4; ~12-combo Core ceiling).
Also added: Rule 3 trigger×behavior legality matrix; EC-PDB-08 + AC-PDB-15/16/17 (negative STRUCTURAL_EFFECT); tightened AC-04/05/06/08.

### Deliberately deferred to OQ-PDB-1 content pass (CD ruling — NOT schema defects)
Player Fantasy thinness (3 flat riders fire identically regardless of build depth — UNIQUE_PER_TRIGGER makes 6-part Volt stack == 1-part); actual Core identity passive roster. Both now owned/dated in the OQ-PDB-1 charter.
Full detail: design/gdd/reviews/passive-database-review-log.md

---

## Prior Task (Session 15 — CLOSED)
**Move Database GDD `/design-review`** — Verdict NEEDS REVISION, 4 blockers resolved same session. (Was awaiting fix-confirmation re-review; superseded — check move-database-review-log.md for status.)

### Blockers resolved this session (all in design/gdd/move-database.md)
1. Stale "errata unapplied" header (line 7) + OQ-MDB-3 → corrected to "applied 2026-07-10, verified vs TBC + registry"; OQ-MDB-3 marked RESOLVED. (TBC + registry were already correct; only this GDD lied.)
2. False "Heat-gated" SIGNATURE 3-turn-kill rationale → rewritten. **Script-verified in-session:** at heat_gen 30/35/40 the boss dies turn 3 before any Overheat skip; at 30 it never Overheats. Kill is gated by the **A=150 max-synergy requirement**, not Heat. TTK numbers (3/4/5) were correct, unchanged.
3. UTILITY defined by enumeration → now defined **by rule** (Rule 2): affects only user Heat/Energy, no damage/enemy-status/reveal.
4. AC-MDB-15 BLOCKING-DEFERRED (phantom CI gate) → **ADVISORY-DEFERRED**, escalates to BLOCKING when content pipeline ships. AC summary count updated.

### Recommended items NOT applied (deferred — user chose blockers-only)
B-1 move-panel distinctness rule · AC-MDB-03 full-trap-list + overcorrection guard · AC-MDB-05 assert df1_output=187 intermediate · AC-MDB-19/20 unit-vs-integration boundary + AC-MDB-20 split · R-1 SCAN-vs-boss equilibrium · R-3 MVP status-rider-passive scoping. All logged in design/gdd/reviews/move-database-review-log.md.

### Adjudicated disagreement (script-settled, CD concurred)
qa-lead's AC-MDB-05 BLOCKING ("fixture gives 261 either way") REFUTED: correct=261, A-boost=275, prefloor=262 — fixture IS discriminating. Downgraded to RECOMMENDED.

## Prior Task (Session 14 — CLOSED)
Move Database GDD **authored** (/design-system move-database, lean mode) → status Designed. Key decisions: power_tier ENUM; MOVE-F1 POST-DF-1 multiply [1,315] (epsilon LOAD-BEARING, 10 cases); SCAN reveals break_regions (ED6); UTILITY=Vent; TBC errata applied to TBC + registry same session.

## Prior Task (Session 13 — CLOSED)
Turn-Based Combat GDD: **APPROVED 2026-07-10** (fix-confirmation re-review, lean would-be — ran full fix-confirmation: systems-designer, qa-lead, game-designer, creative-director). All 7 round-1 blockers confirmed resolved; 0 new blockers. 3 non-gating follow-ups tracked in review log (AC-TBC-37 dual-path fixture; hit_resolved target→region-intent for Part-Break; ON_OVERHEAT dispatch watch). systems-index + review-log + GDD header updated.

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

## Move DB Sections Written (design/gdd/move-database.md)
- Overview ✓ (Part DB read-only sibling; ratifies MOVE-CONTRACT-1 + power_tier addition)
- Player Fantasy ✓ (borrowed/enabling — "the move panel is the build speaking")
- Detailed Design ✓ — Rules 1-9: schema (MOVE-CONTRACT-1 + power_tier), behavior classes, power-tier coherence table {LIGHT .80/STANDARD 1.00/HEAVY 1.20/SIGNATURE 1.40, Basic 0.70}, Basic Attack template, status moves, SCAN=reveal break_regions (ED6), REPAIR (energy_cost>10), UTILITY=Vent (dump Heat), upgrade_effects semantics (SKILL_UNLOCK/SKILL_ENHANCE)
- Formulas ✓ — MOVE-F1 `max(1,floor(df1_output×power_mult+0.0001))`, output [1,315]. **Epsilon LOAD-BEARING** (python3-verified in-session: 10 cases, e.g. 165×1.40=230.9999→231; SD wrongly called it defensive — memory updated). Pipeline DF-1→MOVE-F1→TBC-F5. Balance: SIGNATURE+max-synergy = 3-turn boss kill (vs TBC's 4), ruled acceptable (Heat-gated).
- Edge Cases ✓ — EC-MDB-01..10 (each cites an AC)
- Dependencies ✓ — resolves TBC OQ-1/3/4; errata table
- Tuning Knobs ✓ — power_mult tiers + vent_amount
- Visual/Audio + UI ✓ — brief delegation notes
- Acceptance Criteria ✓ — 22 ACs (18 BLOCKING unit + 1 BLOCKING-DEFERRED + 3 ADVISORY-DEFERRED content-val). qa-lead structural fixes accepted; its load-bearing-epsilon arithmetic ERROR rejected per python3 scan (2nd specialist to mis-analyze this epsilon).
- Open Questions ✓ — OQ-MDB-1..6
- **GDD COMPLETE** — status "Designed — pending /design-review" (lean mode; CD-GDD-ALIGN skipped per lean).

## Move DB Design Decisions (locked this session)
- power_tier ENUM (not free float), coherent w/ Part DB energy/heat tiers
- power_mult applied POST-DF-1 (mirrors TBC-F5 Stagger) → DF-1 [1,225] stays untouched
- SCAN reveals enemy break_regions + drop hints → delivers Enemy DB ED6
- UTILITY = exactly 1 move (Vent) in MVP

## Phase 5 DONE this session
- Registry: added MOVE-F1 (formula, [1,315], LOAD-BEARING epsilon), POWER_TIER_MULTIPLIERS (constant); TBC-F5 range [1,225]→[1,315] + move-db referenced_by; DF-1 referenced_by +move-db (range unchanged).
- **TBC errata APPLIED this session** (OQ-MDB-3 discharged, not deferred): TBC-F5 var table + output range→[1,315]; Rule 10 pipeline note (DF-1→MOVE-F1→TBC-F5); AC preamble range note; OQ-TBC-1/3/4 marked RESOLVED; AC-TBC-39 SCAN-reveal erratum; AC-TBC-34 post-power note; TBC status header errata line. TBC remains APPROVED (errata, not re-review).
- systems-index: Move DB Not Started→Designed; tracker started 6→7, MVP designed 6/22→7/22.
- Memory updated: project-float-epsilon-empirics += MOVE-F1 load-bearing.

## Next Steps
1. /design-review design/gdd/move-database.md in a FRESH session (never same-session as authoring)
2. /consistency-check to confirm the TBC-F5/[1,315] errata is coherent registry-wide
3. Next MVP system in design order: #1b Passive Database (unblocks OQ-MDB-1 rider passives + TBC Rule 13 registry) OR #7 Encounter Zone

<!-- CONSISTENCY-CHECK: 2026-07-10 | GDDs checked: 7 | Conflicts found: 1 (DF-1 range stale in damage-formula.md — resolved) | Log: docs/consistency-failures.md -->
<!-- CONSISTENCY-CHECK: 2026-07-10 | GDDs checked: passive-database.md (delta) vs 4 siblings | Conflicts found: 0 (PASS) | Action: added passives section to entities.yaml (3 ratified rider IDs) -->

## Passive Database — round 2 (this session)
- Fix-confirmation /design-review: 4 prior gates confirmed CLOSED; 5 NEW blockers found + fixed (all prose): STRUCTURAL_EFFECT neg-amount contradiction (BANNED both targets per user), AC count 14→21 total, OQ-PDB-1 ceiling ≈12→5, AC-PDB-02 Heat baseline=50, AC-PDB-09 delta-based observable. 5 Recommended left open (non-blocking). Verdict: APPROVED.
- systems-index: Passive DB Designed→Approved; reviewed 6→7, approved 6→7.
- review-log: round-2 APPROVED entry appended.
- /consistency-check: PASS (0 conflicts). Registered 3 status-rider IDs in new entities.yaml `passives:` section (drift-protection for Passive DB ↔ TBC Rule 13 durations).

## Next MVP system in design order
- #7 Encounter Zone System (Not Started) — next unblocked. OR /review-all-gdds (all 8 MVP Foundation+Core GDDs now approved — natural holistic gate before World/Feature layer).

## Session Extract — /review-all-gdds 2026-07-10
- Verdict: **CONCERNS** (no blocker on the 8 approved Foundation+Core GDDs; core is coherent).
- GDDs reviewed: 8 (part-db, damage-formula, enemy-db, symbot-assembly, synergy, TBC, move-db, passive-db). Parallel systems-designer (consistency) + game-designer (design-theory) subagents + main-session Phase 4 walkthrough.
- Formula pipeline SA-F1→SYN-F4→DF-1→MOVE-F1→TBC-F5: range-compatible PASS. No dominant strategy (SIGNATURE 3-turn kill = legit mastery ceiling). No AC contradictions.
- **2 integration seams — CLOSED this session (TBC errata applied, bidirectional):**
  - B-1: ON_OVERHEAT firing order → TBC Rule 13 "Trigger dispatch & firing order" note (fires before Overheat consequence; PERSISTENT sieved from event dispatch; alphabetical multi-passive order). Passive DB Rule 2a notes closure.
  - B-2: STAT_AURA path → TBC Rule 10 `frozen_passive_aura` block folds PERSISTENT part-passive deltas into effective_stat. Passive DB Rule 3a notes closure. AC-PDB-D2 remains the OQ-PDB-1 gate that exercises it.
  - (Both were forward-looking — no MVP content exercises them; all 3 riders are STATUS_RIDER/ON_HIT.)
- **HOLISM-01 (design decision, blocks Not-Started Drop System GDD):** duplicate-part sink undecided (scrap-currency / inventory-cap / no-store). Take position before Drop System authoring. Part DB DB5, Enemy DB OQ-4/5.
- Watches: Pillar-4 flat-passive gap (OQ-PDB-1 CRITICAL PATH must ship before content); Kinetic Stagger incoming-damage asymmetry (playtest watch); 4-demand attention budget (Combat UI 44pt constraint).
- **Errata APPLIED this session (8 fixes):** W-1 Part DB +Move DB downstream row (9→10); W-2 TBC dep labels Move/Passive DB→Approved (+Synergy's TBC label); W-3 Synergy +Passive DB downstream reciprocity; W-4 TBC STATUS_DURATION scope="move-applied only"; W-5 Enemy DB OQ-3 RESOLVED + Rule 3 dead-data note + EDB-2 max-synergy addendum; W-7 Part DB AC-13 unblocked (ACTIVE); W-8/W-9 registry DAMAGE_FLOOR + BASE_ENERGY_REGEN referenced_by += move-database.md. W-6 withdrawn (AC-MDB-10 exists).
- No GDD marked Needs Revision — all issues were errata (applied) or forward-looking obligations (tracked), not GDD-invalidating.
- Report: design/gdd/gdd-cross-review-2026-07-10.md
- Recommended next: apply B-1/B-2 TBC seam errata OR decide HOLISM-01 OR /design-system encounter-zone (#7) / part-break (#9, binding Pillar-2).

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Cross-GDD review → CONCERNS (8 errata + B-1/B-2 seams closed)
Task: Foundation+Core coherent & seams closed; open: HOLISM-01 sink decision; next system Encounter Zone (#7) / Part-Break (#9)
<!-- /STATUS -->
