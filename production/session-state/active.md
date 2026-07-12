# Active Session State

## Current Task
Session 17: **Part-Break System GDD `/design-system part-break`** (lean mode). Skeleton created at `design/gdd/part-break.md`. Starting Section A (Overview).
**File**: design/gdd/part-break.md
**STATUS: Part-Break GDD COMPLETE** (design/gdd/part-break.md — all 8 required + Visual/Audio + UI + Open Questions). Status: Designed, pending fresh-session /design-review.
**Phase 5 done**: self-check (0 placeholders); registry updated (PB-F1..F5 + BREAK_SPILLOVER/ENRAGE_PER_BREAK/BREAK_BIAS_MULTIPLIERS + referenced_by on EDB-1/BREAK_HP_MIN/DAMAGE_FLOOR/MOVE-F1/TBC-F5; YAML valid); systems index updated (10/22 MVP designed). CD-GDD-ALIGN skipped (lean).
**3 ERRATA OBLIGATIONS on Approved docs (must be applied before those docs are re-approved):**
  1. TBC (substantial) — Rule 10 damage routing by sub-target + PB-F3 spillover + BREAK_BIAS_MULTIPLIERS + PB-F5 enrage on enemy outgoing; region sub-targeting layer.
  2. Move DB (small) — add break_bias field (enum, default BALANCED) + BREAK_BIAS_MULTIPLIERS table + reserved target_profile; add part-break to referenced systems.
  3. Drop System (small) — redefine provisional Rule 5/7: break is deterministic (no P(break fires), no break-failure pity); DS-3 drop pity unaffected.
**DB3 resolution**: (a) deterministic pool depletion (PB-F4); (b) break-failure soft-lock DISSOLVED (DAMAGE_FLOOR guarantees progress).

## Next
- **/design-review design/gdd/part-break.md in a FRESH session** (never same-session as authoring).
- Then /consistency-check (new PB constants/formulas + the 3 pending errata).
- Apply the 3 errata to TBC / Move DB / Drop System (they'll need re-review touches).
- Next MVP system in design order: #7 Encounter Zone or #10 Enemy AI.
**Multi-target skills**: RESERVED extension (Rule 11) — target_profile schema hook + split rule reserved; no MVP content. User confirmed.
**Section D locked**: BREAK_BIAS_MULTIPLIERS = STRUCTURE_HEAVY(1.25,0.55)/BALANCED(1.00,1.00)/BREAK_HEAVY(0.70,1.40); BREAK_SPILLOVER=0.20; ENRAGE_PER_BREAK=0.15. Epsilon scan (python3, M∈[1,315]): PB-F1@0.70 LOAD-BEARING, PB-F2@1.40 LOAD-BEARING, PB-F3 defensive, PB-F5@1.15 LOAD-BEARING; 0 overcorrections, 0 unfixed. Formulas PB-F1..F5 + DAMAGE_FLOOR=1 guards.
**Key locked decisions**: Two-pool model (Structure + region break pools from EDB-1); free target selection (Structure OR region, no turn cost); break_bias enum STRUCTURE_HEAVY/BALANCED/BREAK_HEAVY; BREAK_SPILLOVER=0.20; deterministic break (one RNG gate = the drop); unlimited multi-break gated by fraction cost + ENRAGE_PER_BREAK escalator; all_boss_parts_broken capstone.
**Erratum obligations created (Approved docs)**: Move DB (+break_bias field + BREAK_BIAS_MULTIPLIERS), TBC (Rule 10 target routing + spillover + bias + enrage), Drop System (break deterministic → drops P(break fires) + break-failure pity from provisional Rule 5/7).
**New constants to register (Phase 5)**: BREAK_SPILLOVER, BREAK_BIAS_MULTIPLIERS, ENRAGE_PER_BREAK.

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
- **HOLISM-01 — RESOLVED 2026-07-10 (CD decision):** Parts are **instances** (multiple copies useful — same part on multiple Symbots). Duplicates **stored** in inventory, **player-chooses** to scrap → **Scrap** (generic currency); never auto-scrapped. Satisfies Part DB DB5. **MVP Scrap sink = material-gated part upgrading** (tier 0→5 costs Scrap). **Designs** = rarer blueprint drops → **fabricate** part instances on demand w/ currency+materials (deterministic acquisition atop RNG); Designs = Blueprint Crafting System #25, **Alpha-tier**. Unblocks Drop System GDD; informs Inventory (instance storage/stacking — mobile save/UX risk), Workshop/Part Upgrade, Blueprint Crafting. Enemy DB OQ-4/5 (rates/pity) still Drop System's.
- Watches: Pillar-4 flat-passive gap (OQ-PDB-1 CRITICAL PATH must ship before content); Kinetic Stagger incoming-damage asymmetry (playtest watch); 4-demand attention budget (Combat UI 44pt constraint).
- **Errata APPLIED this session (8 fixes):** W-1 Part DB +Move DB downstream row (9→10); W-2 TBC dep labels Move/Passive DB→Approved (+Synergy's TBC label); W-3 Synergy +Passive DB downstream reciprocity; W-4 TBC STATUS_DURATION scope="move-applied only"; W-5 Enemy DB OQ-3 RESOLVED + Rule 3 dead-data note + EDB-2 max-synergy addendum; W-7 Part DB AC-13 unblocked (ACTIVE); W-8/W-9 registry DAMAGE_FLOOR + BASE_ENERGY_REGEN referenced_by += move-database.md. W-6 withdrawn (AC-MDB-10 exists).
- No GDD marked Needs Revision — all issues were errata (applied) or forward-looking obligations (tracked), not GDD-invalidating.
- Report: design/gdd/gdd-cross-review-2026-07-10.md
- Recommended next: apply B-1/B-2 TBC seam errata OR decide HOLISM-01 OR /design-system encounter-zone (#7) / part-break (#9, binding Pillar-2).

## Drop System GDD — COMPLETE (this session, Designed/pending review)
- All 8 sections written. Independent per-part rolls (Enemy DB OQ-5 → option b). Hidden pity (surprise-rescue). Mild-scarcity Scrap.
- Formulas: DS-1 (roll, strict <), DS-2 (Prototype pity N_PROTO_PITY=25), DS-3 (Boss-grade pity M_BOSS_PITY=8). 24 ACs (21 BLOCKING unit) via qa-lead; EC↔AC 9/9.
- Discharges Part DB DB2 (N=25), EC-16 (M=8), DB5 (scrap: yields Common5/Rare20/BG60/Proto35, sink=upgrading 10/20/40/80/130). Resolves Enemy DB OQ-4 & OQ-5.
- Scrap yields owned here; upgrade-cost curve proposed here but owned by Part Upgrade/Workshop. Pool Common cap (≤2 WILD/≤3 BOSS) = Enemy DB authoring rule.
- Applied: registry +N_PROTO_PITY/+M_BOSS_PITY; Enemy DB OQ-4/OQ-5 → RESOLVED errata; systems-index #8 → Designed (started 8→9, MVP designed 8→9/22).
- Provisional/open: OQ-DS-1 Part-Break contract (break vocab + P(break)); OQ-DS-2 outcome-fact provenance (TBC↔Drop interface — real gap); OQ-DS-3 Designs (Alpha); OQ-DS-4 inventory cap/scrap UX. Deferred ACs AD-1..5.
- CD-GDD-ALIGN skipped (lean). Player Fantasy drafted without creative-director (lean) — manual pillar check before production.

## Drop System GDD — MAJOR REVISION addressed (2026-07-11, this session)
Re-review 2026-07-10 verdict = MAJOR REVISION NEEDED (9 blockers). All 9 worked in a fresh session. Two design decisions resolved by user: **dedupe-to-unique** duplicate-pool-ID contract; **mild-scarcity** economy target.
- **B1 dup contract** → dedupe to unique (Rule 2 rewritten, EC-DS-08, AC-DS-08). Aligns with Approved Enemy DB EC-ED-08; no Enemy DB change needed.
- **B2 economy** → rederived from scratch: A1 ~200 victories, A2 per-victory yield, A3 absorption (C75/R50/BG25/P25%). Faucet ~1,915 (band 1,700–2,300); sink 2 Rare+1 Proto+1 Common maxed = ~1,000/Symbot ×3 = ~3,000; funds ≈2 loadouts → mild scarcity. OQ-DS-5 reframed to assumptions.
- **B3 MULTIPLIER_FLOOR=1.5** defined (Rule 5a; new registry const) → discharges Enemy DB ED3-OQ7 + Recommended #7 (both marked RESOLVED in Enemy DB).
- **B4 pity calibration** → new "Pity Calibration Authoring Rules" table: Proto floor ×3.0 (→1.72% at floor; Part DB rule exists, surfaced missing-AC obligation); Boss ×500 load-bearing (Part DB AC-11) → 0.39%. Corrected old "~0.9%"/"~0.4%".
- **B5 upgrade curve** → +4→+5 fixed to 160 (pure doubling; Common+3=70, Rare+ +5=310); "wall" framing corrected (was inverted 130<160).
- **B6 AC-DS-25** → false arithmetic removed; single discriminator draw 0.30 (rate 0.35).
- **B7 AC fixes** → AC-DS-23 ghost 0.225→0.10 additive, draws 0.11/0.15; AC-DS-09/17 dedup (17 repurposed to nominal 0→1 increment); AC-DS-13 pre-roll pity ordering explicit; AC-DS-19 invariant → 3 boolean assertions.
- **B8 AD-2** → promoted to numbered gated **AC-DS-28** (pity persistence, release-blocker).
- **B9 stale ÷pool_size** → erratum applied to Part DB line 696 + Enemy DB loot-pool prose (line 104).
- Registry: +MULTIPLIER_FLOOR; N_PROTO_PITY note corrected; last_updated 2026-07-11.
- AC count now: 27 BLOCKING unit + 1 gated (AC-DS-28) + 4 deferred (AD-1,3,4,5).

## Session 18 — Part-Break /design-review (full, 5 agents) → NEEDS REVISION → 11 blockers fixed same session
Full review spawned game-designer + systems-designer + qa-lead + ux-designer + creative-director (synthesis). Verdict NEEDS REVISION (surgical, no redesign). CD committed to APPROVE-via-fix-confirmation once must-do items landed. User chose "revise now" + "re-review in fresh session."
- **PB-F5 enrage retuned 0.15 → 0.12** (user decision): cap +45%→+36%; epsilon re-scanned (python3) → now ALL-DEFENSIVE (old load-bearing 1.15 gone); output_range 456→428. Honest calibration note replaces false "3-4 hits" claim — glass cannon (SA-F1 floor 60) is one-shot at 1 stack (55×1.12=61>60); tied to OQ-PB-3. Registry synced (PB-F5 entry + ENRAGE_PER_BREAK const + last_updated).
- **7 qa-lead AC hardenings**: AC-PB-05(c)+new(d) kill-path, 09(N=1), 18(spillover==0), 21(precondition), 23(spillover==14/struct==0), 24(reinit non-null), 30(dynamic mid-battle exclusion).
- **New AC-PB-31** (Combat-UI break-progress data contract, Integration BLOCKING). AC count 30→31 (29 BLOCKING).
- **Player Fantasy reframed** (CD-adjudicated): harvest cost = turns+enrage (systemic, AC-PB-28-guaranteed for any bias); BALANCED = opportunity cost. **1.00 anchor KEPT** (rejected GD's 0.80 proposal).
- **UI-3 pre-SCAN = hidden-until-SCAN** (user decision) + tutorial-dependency caveat.
- **Recommended applied**: 2.0×-ratio absolute-floor companion; AC-PB-28 TBC-harness prerequisite declared.
- Review log created: design/gdd/reviews/part-break-review-log.md. systems-index: #9 → "In Review — NEEDS REVISION addressed".

## Session 19 — Part-Break fix-confirmation re-review (full, 5 agents) → APPROVED
Ran full 5-agent adversarial sweep (game-designer + systems-designer + qa-lead + ux-designer + creative-director synthesis) despite CD's "lighter pass" pre-commit. All 11 prior blockers verified fixed. systems-designer: ZERO blocking (formulas sound at every boundary; AC-PB-28 2-vs-5-turn fixture reconfirmed). Re-sweep raised 13 new "blocking" claims; CD triaged to 3 genuine this-GDD fixes — all applied this session:
- **Fix 1 — phantom pity paragraph** (Player Fantasy ¶4): described the DISSOLVED DB3(b) break-failure pity as if live. Rewrote as "no-soft-lock guarantee" = determinism + DAMAGE_FLOOR (EC-PB-08); kept "bad luck adds turns, never walls the goal."
- **Fix 2 — AC-PB-31 data contract**: named two queries (`query_break_progress(move) → Array[RegionProgress]{region_id,ratio,projected_break_damage}`, broken regions omitted, no-move → projected=0) + added **breaking-hit element** to the `<region>_broken` payload (VA-1's element-colored pop had no data source). Sub-asserts (a)–(d). Also added AC-PB-14 TBC-harness fixture prerequisite (symmetric w/ AC-PB-28).
- **Fix 3 — AC-PB-26** reclassified ADVISORY → Integration BLOCKING (break-key vocab mismatch = silent no-drop). Header count → 30 BLOCKING / 1 ADVISORY.
- CD adjudication: 6 of 7 ux "blockers" are Combat-UI *rendering* reqs → deferred to Pre-Production /ux-design (Part-Break owns no UI). Only VA-1 element (data) gated.
- Tracking done: part-break.md Status → Approved; systems-index #9 → Approved + Progress Tracker 8→9 reviewed/approved; review log appended (APPROVED fix-confirmation entry). **No re-review #3.**

## Session 20 — TBC fix-confirmation re-review (full, 5 agents) → NEEDS REVISION → 2 blockers fixed same session → APPROVED
`/design-review turn-based-combat.md` ran (game-designer, systems-designer, qa-lead, creative-director synthesis). Erratum **design confirmed correct across all 8 regions** — the only findings were 2 AC-*integrity* defects (guards that failed to guard). User chose revise-now + accept-as-Approved.
- **BLOCKING 1 — AC-TBC-INT-01c ordering fixture non-discriminating** (systems-designer + qa-lead independently; main reviewer verified): raw=55/pct=21/count=1 → 48 under BOTH orderings (floor compresses 43→48 and 61→48). The only test of the ratified POST-Stagger ordering didn't test it. **Fixed: raw 55→50** → correct −43 vs wrong −44 (divergent). Chose numeric fix over qa-lead's pipeline-spy (qa-lead's "structurally impossible" claim falsified by SD's counterexample).
- **BLOCKING 2 — AC-TBC-34 region case parenthetical**: `sub_target==region_id` had no required FAIL; hardcoded-STRUCTURE passed. **Fixed: promoted to required Fixture B** (`sub_target=="left_arm"` ≠ STRUCTURE).
- **Recommended applied**: INT-01 umbrella multiplier source-of-truth note (BREAK_BIAS/ENRAGE/SPILLOVER = Part-Break-owned, retune→re-derive); inline EC↔AC citations (already-broken redirect→INT-01e, floor-collision→INT-01f); TBC-F7 post-Stagger *rationale* + calibration-ownership pointer.
- **Disagreement of record**: game-designer called INT-01c "well-constructed/PASS" — WRONG (didn't run wrong-order path). SD+QA+CD confirmed the collision. Logged.
- **Downgraded (CD, mature-doc directive)**: enrage-calibration argument (real, but `ENRAGE_PER_BREAK` Part-Break-owned → tracked on **Part-Break §D**, not a TBC gate); BREAK_BIAS cross-ref (hazard not defect).
- Tracking: GDD header → APPROVED; systems-index #6 → Approved + Last-Updated line; review-log appended (NEEDS REVISION→APPROVED entry). No design/formula/coefficient changed; epsilon scans valid.

## Propagation / errata APPLIED (Session 20, 2026-07-11 — all four docs)
- **✅ Passive DB** — ON_HIT trigger row (Rule 2) now shows 4-arg `hit_resolved(move,damage,target,sub_target)` + explicit note that the three seed riders IGNORE `sub_target` (Part-Break's routing concern, not the rider's).
- **✅ Part-Break** — its own Interactions table (line 75) + upstream Dependencies table (line 263) updated 3-arg → 4-arg (game-designer Finding 6.1 closed); TBC-erratum "Requires" → "applied".
- **✅ Move DB** — Rule 1 schema gained `break_bias` enum (default BALANCED, DAMAGE+ENEMY only) + reserved/nullable `target_profile` (Part-Break Rule 11 hook); BREAK_BIAS_MULTIPLIERS referenced (Part-Break-owned, not re-tuned); Basic Attack template = BALANCED; Part-Break downstream row → Approved + erratum-applied; bidirectionality synced.
- **✅ Drop System** — Rule 5 (vocab) + Rule 7 (Boss-grade floor) + Interactions (line 85) + downstream dep (210) + bidirectionality (226) + AD-5 (412) + OQ-DS-1 (434, → RESOLVED): break is **deterministic**, no `P(break fires)`, no break-failure pity (Part-Break DB3 dissolved); DS-3 drop-RNG pity unaffected. Provisional caveats discharged.

## Next
- **Part-Break §D** — track the "does +12%/break carry decision weight?" enrage-calibration question (CD routed it here at TBC re-review; TBC-F7 now points to it). NOT a blocker — a balance-watch owned by the enrage knob's home doc.
- **/consistency-check** — verify MULTIPLIER_FLOOR + all the accumulated errata (BREAK_BIAS_MULTIPLIERS, break_bias field, deterministic-break contract) are registry-coherent across the 4 just-edited docs + registry.
- Next NEW MVP system in design order: **#7 Encounter Zone** (Not Started) or **#10 Enemy AI** (Not Started, unblocks TBC AC-TBC-INT-02).
- Other pending ERRATA from Part-Break: **Move DB** (add break_bias enum default BALANCED + BREAK_BIAS_MULTIPLIERS table + reserved/nullable target_profile + list Part-Break as referencer) — "Small"; **Drop System** (redefine provisional Rule 5/7: break deterministic, no P(break fires), no break-failure pity; DS-3 drop-RNG pity unaffected) — "Small".
- Still pending from Session 17: /consistency-check (MULTIPLIER_FLOOR + errata). NOTE: systems-index shows Drop already "Approved (2026-07-11, re-review punch-list applied)".
- Next MVP system in design order: #7 Encounter Zone (Not Started) or #10 Enemy AI.

## Encounter Zone (#7) — design-review DONE, punch-list APPLIED (2026-07-11)
- **Verdict**: NEEDS REVISION (first review, full panel: game/systems/economy/level designers + qa-lead + CD synthesis). 4 blockers + 4 recommended — ALL applied same session.
- **BIG CHANGE — WAVE gate CUT to Reserved** (CD verdict: off-pillar gauntlet + `wave_pools` undefined). Both MVP bosses now `WIN_COUNT` on a **shared cumulative zone-win counter**: Boss 1 @ 6, Boss 2 @ 10 (regate 2 / 3). WAVE keeps enum value alongside REACH/DUNGEON_RUSH.
- **Rule 8a** added — WIN_COUNT semantic NORMATIVE (cumulative, all-time, zone-wide, never resets, wins-only; fled/lost don't count). OQ-EZ-5 → RESOLVED. Exploration Progress now *implements* this, doesn't ratify.
- **Rule 2a** added — terrain identity-enemy + 20% weight-floor invariant (AC-EZ-54) enforcing the targeting-lever promise.
- AC-EZ-25 ADVISORY→BLOCKING (+regate=0/≥first guards); AC-EZ-40 split 40a(BLOCKING now)/40b(DEFERRED); AC discriminator fixes (03/04/15/35/39/52) + new 53(FULL_REGATE)/55(wins-only). 1.3×/1.6× text fixed; EZ-2 pre-filter+sentinel noted. **52→56 ACs** (36 BLOCKING/11 ADV/9 DEFERRED).
- Routed OUT (not this read-only layer's job): OQ-EZ-6 (spatial tile/boss contract→Zone&Map), OQ-EZ-7 (enemy-terrain discovery→World Map UI), OQ-EZ-8 (inter-encounter HP recovery→TBC).
- **Tracking done**: GDD header→Reviewed/revised; systems-index #7 row + Last-Updated updated; review-log CREATED (design/gdd/reviews/encounter-zone-review-log.md). grep sweep = consistent.
- **User chose: RE-REVIEW in a new session.** → done 2026-07-12 (see below).

## Encounter Zone (#7) — 2nd-round RE-REVIEW DONE, punch-list APPLIED (2026-07-12)
- **Verdict**: NEEDS REVISION (2nd round, fresh-session full panel: game/systems/economy/level + qa-lead + CD). All 4 prior blockers confirmed correctly fixed. **3 new blockers + 2 recommended — ALL applied same session** (user chose all 3 recommended fix options via AskUserQuestion).
- **B1 — LIGHTER_REGATE was silently broken** (economy + systems, independent): never-resetting shared counter is already ≥6 at defeat, so re-gate (2/3) was permanently met → collapsed into ALWAYS_OPEN. **FIX: delta re-gate** `win_count − wins_at_last_defeat >= regate_params.required_wins`; per-boss `wins_at_last_defeat` snapshot taken on each defeat (Rule 9/8a + Exploration Progress storage). AC-EZ-21/22/23 rewritten; **AC-EZ-22 = central discriminator** (boss re-locks at moment of defeat). DEFEATED now a real resting state.
- **B2 — Rule 2a/AC-EZ-54B unenforceable** (4 of 5 specialists): no schema field for "farmable" host. **FIX: `is_farmable_target: bool` added to SpawnEntry** (authoring signal, no Enemy DB errata). AC-EZ-54 gains A2 (identity-enemy 10% weight floor, closes token-exclusive loophole).
- **B3 — Boss-1 bypass / simultaneous dual-unlock** (game + level): **FIX: `gate_params.requires_defeated`** — Boss 2 needs win_count≥10 AND Boss 1 defeated_once (Rule 8). New AC-EZ-56; Rule 7/8a/11 + AC-EZ-19/20/49 updated.
- **Recommended**: EC-EZ-07 citation → AC-EZ-35 added (systems+qa); new **AC-EZ-57** zone-level spawn_enabled + EC-EZ-10 re-cite; gate-eval timing → battle_ended/approach (Rule 8); DENSE tuning flagged provisional on OQ-EZ-8; Tuning Knob warning 4 (required_wins × density); AC-EZ-49 tilde hardened (Boss2−Boss1≥3); UI Req 3 sequencing + wins-only feedback.
- **56 → 58 ACs** (38 BLOCKING / 11 ADV / 9 DEFERRED). grep sweep = consistent.
- **Tracking done**: GDD header→2nd-round revised (Last Updated 2026-07-12); systems-index #7 row + header updated; review-log 2026-07-12 entry appended.
- **User chose: CONFIRMATION RE-REVIEW in a new session.** → `/clear` then `/design-review design/gdd/encounter-zone.md` (validate delta-counter semantics, sequencing precondition, is_farmable_target, AC-EZ-21/22/23/56/57) BEFORE marking Approved.

## Encounter Zone (#7) — CONFIRMATION RE-REVIEW DONE → APPROVED (2026-07-12)
- **Verdict**: APPROVED (3rd round, fresh-session full panel: game/systems/economy/level + qa-lead + CD). **All five specialists ZERO blocking.** Round 2 fixes (delta re-gate, is_farmable_target, requires_defeated sequencing) confirmed correct at discriminator level; LIGHTER_REGATE→ALWAYS_OPEN collapse genuinely closed; delta provably non-negative (Rule 8a monotonicity). CD verdict **APPROVED WITH ONE MINOR REVISION** — applied same session (user chose "apply punch-list now"):
  - **EC-EZ-12 + AC-EZ-58** (required, game+systems converged): `requires_defeated` naming a non-existent boss_id → fail-safe LOCKED, never fail-open.
  - **Tuning Knob warning 5** (economy+level converged): re-gate × density coupling.
  - **Rule 2a `is_farmable_target` authoring criterion** (level): "primary/sole source of a build-critical part."
- 58 → 59 ACs (39 BLOCKING / 11 ADV / 9 DEFERRED). No Round 4 (CD directive: no full panel for a fail-safe EC).
- **Tracking done**: GDD header → APPROVED; systems-index #7 → Approved + tracker (reviewed/approved → 11/11, **all 11 authored MVP GDDs now Approved**); review-log 2026-07-12 APPROVED entry appended.

## SCOPE ADDITION — Consumable items → MVP (2026-07-12, user decision)
- **Decision**: add a small consumable-item layer to MVP. MVP drop taxonomy = **parts + scrap + consumables** (designs/blueprints stay Alpha per HOLISM-01). Drop source = **global level/rarity-scaled table** (NO Enemy DB errata). Revive/Overclock held as stretch (out of MVP). Item-use consumes the turn, no Heat/Energy cost.
- **New system #1c — Consumable Database** (Foundation, standalone, no Part DB dependency; design-order slot 10a, BEFORE Inventory #11). Added to systems-index (main table, categories, dependency map, design-order, tracker 30→31 / MVP denom 22→23) + game-concept.md MVP list item 9 + 2026-07-12 scope-revision note.
- **Initial roster (6, world-themed salvage-tech)**: Repair Kit (Structure heal, tiered Weld Patch/Repair Kit/Field Forge) · Coolant Flush (Heat dump) · Power Cell (Energy restore) · Salvage Beacon (drop-odds boost → Drop System conditions) · Signal Jammer (repel) · Scrap Lure (lure).
- **PENDING ERRATA (author these IN the Consumable DB GDD, then light re-review touch on each Approved doc):**
  1. **TBC** — add `use item` to battle action set (Rule 3: move/switch/flee → +use-item; consumes turn, no Heat/Energy) + AC.
  2. **Drop System** — consumables as level/rarity-scaled drop output class + Salvage Beacon → drop-condition multiplier feedback.
  3. **Encounter Zone** — un-defer OQ-EZ-4: add `encounter_rate` modifier hook to EZ-1 (Signal Jammer / Scrap Lure) + ACs.
  4. Enemy DB — NONE (global-table drop source chosen).
- **NEXT ACTION**: author the Consumable Database GDD via `/design-system` (schema authority first; errata reference its IDs). Enemy AI (#10) remains independent and can be sequenced whenever.

## Consumable Database (#1c) — /design-system IN PROGRESS (2026-07-12)
- **Sections written to file**: A Overview ✓, B Player Fantasy ✓, C Detailed Design ✓, D Formulas ✓ (CD-1..CD-5, all epsilon-exempt), E Edge Cases ✓ (EC-CD-01..12), F Dependencies+errata ✓, G Tuning Knobs ✓ (magnitudes + price table + stack caps), Visual/Audio ✓, UI Requirements ✓. Remaining: **H Acceptance Criteria (qa-lead spawned, hardening AC-CD-01..23)**, Open Questions.
- **Section D specialist values (locked)**: heal 25/50/120, Coolant −50 Heat, Power Cell +25 Energy, **Beacon ×2.0** (economy safe range 1.5–2.5; ≥3.0 degenerate), Jammer 0.1×/20 steps, Lure 2.5×/15 steps. Registry correction: BASE_ENERGY_REGEN=10 (not 8). Prices (economy, buy/sell): WeldPatch/Coolant/Power 12/2, ScrapLure 15/3, RepairKit 36/8, Jammer 45/10, Beacon 48/10, FieldForge 75/15. Stack caps C20/R10/P5.
- **New registry constants (Phase 5)**: WELD_PATCH_AMOUNT 25, REPAIR_KIT_AMOUNT 50, FIELD_FORGE_AMOUNT 120, COOLANT_FLUSH_AMOUNT 50, POWER_CELL_AMOUNT 25, BEACON_MULTIPLIER 2.0, JAMMER_RATE_MULTIPLIER 0.1, JAMMER_DURATION_STEPS 20, LURE_RATE_MULTIPLIER 2.5, LURE_DURATION_STEPS 15 + 8 consumable entries.
- **Locked design decisions**: schema `ConsumableEntry` {consumable_id, display_name, rarity, effect_type(5), effect_params(typed), use_context(BATTLE/WORLD/BOTH), target(LIVING_TEAM_MEMBER/CURRENT_BATTLE/OVERWORLD), max_stack, buy_price, sell_price}. Battle item-use = 4th TBC action, consumes turn, no Heat/Energy. **Targeting = any LIVING team Symbot** (no revive — downed not targetable). **Salvage Beacon = flat fight-wide drop-rate boost** (per-battle flag, one per battle). Encounter modifiers = step-duration, replace-latest. **buy_price > sell_price strict invariant** (Scrap; reserved post-MVP shops, inert in MVP). Roster = 8 entries/6 concepts (Repair 3-tier family + Coolant/Power/Beacon/Jammer/Lure).
- **Key Item System #23a REGISTERED** (Meta, Vertical Slice) — story/plot key items, NOT consumables, NOT a rarity. Systems-index updated (row/categories/dep-map/design-order; totals 31→32, VS denom 2→3).
- **Shops** = tracked as post-MVP (NPC System #23 owns vendor buy/sell); NOT a new system row (decision) — will be an Open Question in the GDD.
- **NEXT**: Section D Formulas (effect magnitudes per tier, Beacon multiplier, encounter-rate modifier math), lean mode (may spawn systems-designer for D/H as HIGH-risk). Then E/F/G/H + optional sections.

## Consumable Database (#1c) — /design-system COMPLETE → Designed (2026-07-12)
- **All 12 sections written** to design/gdd/consumable-database.md. Status → Designed, pending fresh-session /design-review. Lean mode; systems-designer + economy-designer + qa-lead consulted (Formulas/ACs); CD-GDD-ALIGN skipped (lean) — manual pillar check before production.
- **24 ACs** (18 BLOCKING [15 Unit + 3 Content-Val] / 2 ADVISORY / 4 DEFERRED). qa-lead caught 2 IEEE-754 float-equality fixture bugs (use density 0.15/0.35, not 0.35×0.1 or 0.07×2.5) + added AC-CD-24 (valid-target positive path). CD-1..CD-5 all epsilon-exempt (no python3 scan).
- **Registry updated + YAML-validated**: 8 consumable items, 5 formulas (CD-1..5), 10 constants. last_updated → 2026-07-12.
- **Tracking done**: GDD header → Designed; systems-index #1c → Designed + tracker (started 11→12, MVP designed 11→12/23) + Last-Updated note.
- **3 PENDING ERRATA (apply on approval, each needs re-review touch; update source GDD + registry together)**:
  1. TBC — `use item` 4th action (Rule 3), target=living team Symbot, consumes turn/no Heat/Energy, applies CD-1/2/3, sets beacon flag (`beacon_used_this_battle`/`beacon_drop_multiplier_applied` observables).
  2. Drop System — consumable level/rarity drop channel + Beacon injects BEACON_MULTIPLIER into effective_drop_rate (CD-4).
  3. Encounter Zone — EZ-1 encounter_rate modifier hook (CD-5) + OQ-EZ-4 → RESOLVED; Overworld Nav counts down duration.
- **NEXT**: `/clear` then `/design-review design/gdd/consumable-database.md` in a FRESH session. After approval: apply the 3 errata. Then #10 Enemy AI or #11 Inventory.

## Consumable Database (#1c) — /design-review DONE → APPROVED + 3 ERRATA APPLIED (2026-07-12)
- **Full-panel /design-review** (game/systems/economy designers + qa-lead + CD synthesis). Verdict NEEDS REVISION → **5 surgical blockers fixed same session** → **APPROVED**. systems-index #1c → Approved; reviewed/approved 11→12; review-log created.
- **IEEE-754 blocker REFUTED**: systems-designer claimed AC-CD-09/10 (`0.15×0.1`, `0.35×2.5`) would fail on inexact floats. **python3 scan proved them EXACT** (qa-lead concurred). ACs unchanged. (Reinforces float-epsilon-empirics: verify both directions.)
- **5 blockers fixed**: (1) Rule 3 rejection = pre-action gate, NO turn consumed; (2) AC-CD-14 → named `EncounterModifierState` owner, true unit test; (3) AC-CD-12 → `beacon_qty==0` flee-no-refund assertion; (4) new AC-CD-25 (no-Heat/no-Energy unit); (5) CD-2 Coolant Flush **preventive-only** re Overheat (no carve-out ahead of TBC Rule 4 skip). 24→25 ACs (19 BLOCKING).
- **Design decisions locked** (user): rejection consumes no turn; Coolant Flush preventive-only (can't rescue an already-Overheated Symbot). Combat model reconfirmed: 1 active Symbot, benched have no turns; using a consumable IS the active Symbot's action.
- **ALL 3 ERRATA APPLIED** (GDD + registry together): **TBC** Rule 7a use-item action + Upstream row + AC-TBC-41 + bidirectionality; **Drop System** Rule 12 consumable channel + Beacon injection (DS-1 addendum) + Interactions/Upstream rows + AC-DS-31 + OQ-DS-7; **Encounter Zone** EZ-1 modifier hook + Rule 3 note + Upstream row + AC-EZ-59 + OQ-EZ-4 RESOLVED (59→60 ACs). Registry `last_updated` refreshed; Consumable GDD errata-status → APPLIED.
- **3 RECOMMENDED still open** (not blocking): (a) encounter-modifier "latest wins" — a COMMON Lure silently consumes an active RARE Jammer (consider rejection-with-confirm); (b) Beacon flee-spend explicit intended-tension framing; (c) "Beacon 2:1 self-replenish" claim contingent on OQ-DS-7.
- **OQ-DS-7 OPEN (Part B)**: consumable drop-channel *frequencies* not yet set — an economy decision (per-rarity consumable drop rates + level/rarity scaling) feeding the sell-faucet + Beacon accrual. Scoped in Drop System; tackle via focused pass / economy-designer + Consumable OQ-CD-2.
- **NEXT**: `/consistency-check` (new CD constants + 3 errata) OR `/review-all-gdds` (12 GDDs) OR `/design-system enemy-ai` (#10, next in design order) OR set OQ-DS-7 (consumable drop frequencies).

## Session Extract — /consistency-check + /review-all-gdds (2026-07-12)
- **/consistency-check**: PASS — 0 conflicts across 12 GDDs / all 55 registry entries. (CONSISTENCY-CHECK marker appended below.)
- **/review-all-gdds**: **CONCERNS** (0 blocking). 12 GDDs, parallel Phase 2 (consistency) + Phase 3 (design-theory) + Phase 4 scenario walkthrough. Report: design/gdd/gdd-cross-review-2026-07-12.md.
  - **C-1 (APPLIED)**: consumable-database.md Overview "six items" → "eight items across six effect concepts" (matches Rules 1/10 + AC-CD-18).
  - **D-1 (watch → Combat UI GDD)**: combat active-tracking demands 4→5 with consumables (elective, mitigated by pre-action reject + grey-out). Recommend consumables as a collapsible/secondary combat affordance.
  - **D-2 (watch → OQ-DS-7 + playtest)**: consumable economy contingent — Beacon 2:1 drain unverified until OQ-DS-7 frequencies set; accumulation bounded only by max_stack (overflow policy deferred to Inventory EC-CD-12). **OQ-DS-7 = highest-value balance number to lock at playtest.**
  - Flagged for revision: consumable-database.md (C-1 only, already applied). No GDD needs re-review.
  - Prior 2026-07-10 review (8 GDDs) items all confirmed resolved; not re-flagged.
- **Recommended next**: /design-system enemy-ai (#10, next in design order) — architecture still gated on completing the MVP GDD set (10 of 22 undesigned).

<!-- STATUS -->
Epic: MVP Foundation GDDs
Feature: Enemy AI System (#10) — /design-system COMPLETE → Designed (pending fresh-session /design-review)
Task: Next — /clear then /design-review design/gdd/enemy-ai.md (fresh session). On approval apply 2 errata (TBC un-defer AC-TBC-INT-02; Enemy DB un-block AC-ED-01d via has_profile). Then #11 Inventory or set OQ-DS-7
<!-- /STATUS -->

## Enemy AI System (#10) — /design-system IN PROGRESS (2026-07-12, lean)
- **Decisions locked**: scored-heuristic AI (not priority-list/random). 3 profiles: AGGRESSIVE (damage-max) / TACTICAL (type+status exploiter) / OPPORTUNIST (lethal-spike closer). Stateless core + optional per-profile phase_threshold (Structure-% swap to phase_profile). 4 scoring factors: damage/type/status/lethal. request_move(battle_state) at enemy ACTION_PENDING, returns 1 legal move, deterministic w/ injected seed. Player has no break regions → no enemy sub-target. Type effectiveness = move element vs player Core-slot element (DF-1/Part DB Rule 6 triangle Volt>Thermal>Kinetic).
- **Sections written**: A Overview, B Player Fantasy, C Detailed Design (Rules 1-8 + States + Interactions). Discharges TBC AC-TBC-INT-02 + Enemy DB ED4.
- **COMPLETE → Designed** (2026-07-12, lean). All 8 required + VA/UI/OQ written (0 placeholders, ~5.8k words). systems-index #10 → Designed; docs started 12→13, MVP designed 12→13/23.
- **EAI-1 python3-verified**; caught+fixed a systems-designer Example C mis-score (SHOCK-active TACTICAL still picks Y=2.91 vs X=2.0, NOT X). Profile weights: AGG(3.0,0.2,0.0,1.0)/TAC(1.0,2.0,2.0,1.0)/OPP(2.0,0.5,0.0,4.0). STATUS_BASE_VALUE=1.0. No floor/ceil in EAI-1 (only the DF-1 preview floors). 9 ECs, 14 ACs (12 BLOCKING/1 ADV/1 DEFERRED), full EC↔AC coverage.
- **Registry updated + YAML-validated**: EAI-1 formula + STATUS_BASE_VALUE + AI_PROFILE_WEIGHTS added; DF-1 referenced_by += enemy-ai.md. 26 formulas / 29 constants.
- **2 ERRATA PENDING (apply on approval)**: (1) TBC un-defer AC-TBC-INT-02 (Enemy AI hook request_move now defined) + Downstream row → Designed; (2) Enemy DB un-block AC-ED-01d referential check via EnemyAI.has_profile(id) over {AGGRESSIVE/TACTICAL/OPPORTUNIST}.
- **NEXT**: `/clear` then `/design-review design/gdd/enemy-ai.md` FRESH session. On approval apply the 2 errata. Then #11 Inventory (owns EC-CD-12 overflow, D-2 watch) or set OQ-DS-7 (consumable drop frequencies). **Feel watch OQ-EAI-3**: profile weights are first-pass — confirm TACTICAL-declines-kill feels smart at playtest.

<!-- CONSISTENCY-CHECK: 2026-07-11 | GDDs checked: 9 | Conflicts found: 0 (1 stale registry note synced: N_PROTO_PITY calibration) | Drop-owned constants N_PROTO_PITY/M_BOSS_PITY/MULTIPLIER_FLOOR all consistent across Part DB + Enemy DB -->
<!-- CONSISTENCY-CHECK: 2026-07-11 (session 20 close) | GDDs checked: 10 | Conflicts found: 0 | Verified: BREAK_BIAS_MULTIPLIERS(1.25/0.55/0.70/1.40) + ENRAGE_PER_BREAK(0.12) + BREAK_SPILLOVER(0.20) + 4-arg hit_resolved across Passive DB/Part-Break/TBC/Move DB + Drop System OQ-DS-1 RESOLVED (deterministic break) | 38 registry entries all PASS -->
<!-- CONSISTENCY-CHECK: 2026-07-12 | GDDs checked: 12 | Conflicts found: 0 | Verified: all 55 registry entries (8 consumable items + 10 CD constants + CD-1..CD-5 formulas + all prior constants/formulas/passives) across 12 GDDs — PASS. Noteworthy: CD-5 worked example uses 0.35×0.1 (non-exact in IEEE-754) as prose only; AC fixtures correctly use 0.15 (exact). All 3 errata (TBC/Drop/EZ) consistent. -->
