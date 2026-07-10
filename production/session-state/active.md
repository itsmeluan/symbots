# Active Session State

## Current Task
Session 12: Synergy System GDD — /design-review re-review #6 COMPLETE. **Verdict: APPROVED** (CD, with 7 errata — all applied in-session). Status flipped to Approved in systems-index. GDD design phase for Synergy is CLOSED — CD ruled no re-review #7; any future verification is fix-confirmation only on the 7 errata regions.

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED (+ visual amendment 2026-07-10)
- Damage Formula GDD: APPROVED
- Symbot Assembly System GDD: APPROVED 2026-07-10 (Session 5)
- **Synergy System GDD: APPROVED 2026-07-10 (Session 12, re-review #6 — six review cycles total)**

## Re-review #6 Outcome (of record)
- Specialists claimed 18 blockers; CD adjudicated **0 structural**, 7 genuine errata (all localized text edits, none touching a Rule's semantics, formula, or interface), 11 demoted/discharged.
- The 7 errata applied:
  1. EC-SYN-02: pure 8-part concentration = **5** tiers, not 6 (combined 5-piece excluded in MVP) — the only factual error found
  2. Rule 3: GDScript StringName sort is NOT lexicographic — implementation note requires String conversion before sort; AC-SYN-05b gained no-combined-tier fixture guard + active_synergies.size()==2 assertion
  3. States section: cached_bonus_block initializes to empty block at construction (pre-evaluate reads valid, never null — TBC-before-Workshop crash class)
  4. Rule 7: active_synergies never-null guarantee (mirrors SYN-F3 effects) + AC-SYN-07 assertion/FAIL line
  5. AC-SYN-06/10 ownership: "or" → "AND" — both tests/unit/tbc/ AND tests/unit/workshop_ui/ implement SYN-F4 tests independently
  6. UI Req 1: combined-tier **dual-track progress** state added (never collapse two independent thresholds to one "X/Y"); build-relevance for combined tiers = ≥1 part per constituent tag
  7. UI Req 3: no-color-alone accessibility constraint (mandatory project standard, not deferrable)
- Demotions of record: ux batch (indicator density, zero-match discoverability, DCO-9 minimum bar, DCO-2 testability, greyed-out-vs-distinct) → Workshop UI GDD per DCO framework; game-designer Beat-4 calibration + 20-part content geometry → already in OQ-2/OQ-7 hard constraints (4th re-raise); qa AC-hardening batch → recommended test-suite strengthening (specs unambiguous). Workshop UI GDD authors SHOULD read the ux-designer #6 findings when that GDD is authored.

## CD PROCESS DIRECTIVES (re-review #6 — binding)
1. **No re-review #7** — this was the last full adversarial re-review of the Synergy GDD.
2. Future verification = fix-confirmation only (the 7 errata regions), no full specialist sweep.
3. **Retune the adversarial review prompt for mature documents** — stop raising "test could be stronger" as BLOCKING when the underlying spec is unambiguous. Apply when running /design-review on documents past ~3 review cycles.

## Next Steps
1. **/clear, then /design-review design/gdd/turn-based-combat.md in a FRESH session** — first review of the TBC GDD (full adversarial appropriate; CD's mature-doc retuning applies from ~cycle 3)
2. After TBC approval: next in design order is Encounter Zone System (#7, S effort) — but consider /design-system move-database first (1a, Foundation): TBC's MOVE-CONTRACT-1 needs ratification (OQ-TBC-1), SCAN behavior needs definition (OQ-TBC-3), and Part DB AC-13 is blocked on it
3. Pending errata on Approved docs (created by TBC, listed in its Dependencies section): Enemy DB ED1-simplified + EDB-2 synergy-ceiling addendum; Synergy OQ-2 budget-closure note; Part DB ammo_cost=0 content rule

## Standing Obligations (carried forward)
- TBC/Damage-Formula GDD: re-derive DF-1 registered output range under synergy-amplified inputs
- Part Database content plan + Drop System GDD: validate Beat 2 against OQ-7's 5–6 parts-per-tag minimum (HARD CONSTRAINT)
- Economy Designer: OQ-2's three calibration mandates mandatory before MVP content ships
- Workshop UI GDD: DCO-1…9 + combined-tier dual-track state (UI Req 1) + read ux-designer #6 findings
- Workshop System GDD: DCO-8 battle-time equip lockout

## SYSTEMIC PROCESS FLAG — RESOLVED (Session 12, 2026-07-10)
The re-review #4 CD directive is DONE: EC↔AC cross-check amendment applied to
.claude/rules/design-docs.md (+ discriminating-fixtures rule), design/CLAUDE.md,
and .claude/skills/design-review/SKILL.md Phase 2 checklist. The Turn-Based Combat
GDD gate is cleared.

## TBC GDD Session (started 2026-07-10, Session 12)
- File: design/gdd/turn-based-combat.md (skeleton created)
- Sections done: ALL 12 ✓ (A Overview, B Fantasy, C Detailed Design, D Formulas, E Edge Cases, F Dependencies, G Tuning Knobs, V/A Requirements, UI Requirements, H Acceptance Criteria [33 + 4 INT], Open Questions [OQ-TBC-1..6])
- Status: Designed — awaiting /design-review in a FRESH session (never same-session)
- Self-check: PASS (no placeholders; 697 lines)
- Section H note: qa-lead's AC-TBC-22 type-chart error caught and fixed at write time (Kinetic is super-effective vs VOLT, not THERMAL)
- Notable OQ: OQ-TBC-3 — SCAN move behavior undefined anywhere (ties to Enemy DB ED6 drop-hint mechanism); OQ-TBC-1 — Move DB must ratify MOVE-CONTRACT-1
- Section D ratified: snapshot potency; processing-only Burn (0.08, min 2); Shock 0.3 (0–33); Stagger 0.25 post-DF-1 multiply (0–27%); REPAIR_COEFF 0.17 (5–30, anti-stall margin 3); SYNERGY_POWER_BUDGET=40 / SYNERGY_DEFENSE_BUDGET=50 (closes Synergy OQ-2 cap); DF-1 re-derived [1,225] (registry errata queued); TTK ruling: no enemy errata, max-synergy boss-melt 4–7 turns is intended Pillar 4 endgame (EDB-2 addendum queued as Enemy DB errata obligation)
- Epsilon scans (python3, 2026-07-10): ALL TBC formulas + DF-1 extended range = defensive epsilon, ZERO load-bearing cases (95k+ inputs; specialist's load-bearing claims empirically refuted)
- Section E: 15 ECs, all with Verified-by AC-TBC-XX forward refs — Section H must cover AC-TBC-03,06,09..19
- Section C locked decisions: Mobility initiative (desc, player wins ties, recomputed per round); 1 active + 2 bench, switch consumes turn, forced replacement free; ED1 ratified SIMPLIFIED (no enemy Heat/Energy — Enemy DB Rule 3 errata obligation); statuses = Shock/Burn/Stagger (2 turns, no stack, processing-scaled); full reset per battle; no drops on defeat; flee guaranteed WILD-only; 1 enemy per battle (MVP); ammo deferred to Full Vision (content must author ammo_cost=0); MOVE-CONTRACT-1 provisional schema for Move DB; TBC owns passive effect registry with 3 seed effects (volt_shock_on_hit, thermal_burn_on_weapon, kinetic_stagger_on_hit)
- B provisional resolved in C: no drops on defeat (Rule 12) — Player Fantasy "keeps drops earned before defeat" line needs harmonizing when Section D is done (drops discarded on loss; inventory intact)
- Section D pending: TBC-F1 initiative, F2 recharge, F3 Burn, F4 Shock, F5 Stagger, F6 repair, DF-1 range re-derivation + SYNERGY_POWER_BUDGET proposal (closes Synergy OQ-2 cap), TTK impact check. MUST python3-scan every new floor/ceil formula (memory: specialists miss these)
- Open flag: "status effects" mentioned in index/concept but unscoped — decide scope in Section C
- Decision: Move Database handled via PROVISIONAL CONTRACT (TBC defines expected Move schema, flagged for Move DB GDD to ratify — mirrors Enemy DB approach)
- Review mode: lean (specialists only for Formulas + ACs)
- Must resolve: DF call contract + status-dmg routing; ED1 enemy resource symmetry; recharge/current_structure/ENERGY_CELL/CHIPSET/CORE (Assembly obligations); Synergy OQ-3 effect registry + evaluate_silent + SYN-F4 + DF-1 range re-derivation; Part DB Formulas 4/5 heat + energy costs + ammo

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Turn-Based Combat GDD
Task: Section A (Overview) — skeleton created, section cycle starting
<!-- /STATUS -->
