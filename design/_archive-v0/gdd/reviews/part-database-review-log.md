# Review Log: Part Database

## Review — 2026-07-16 — Verdict: APPROVED (lean pass — full panel unavailable)
Scope signal: S (all follow-up is documentation-only; design + implementation are settled)
Specialists: none — game-designer, systems-designer, qa-lead all died on `API Error: Usage
credits required for 1M context` (persistent subagent failure this session). This was a lean
single-session review, not the full adversarial panel.
Blocking items: 0 | Recommended: 4 (hygiene) — applied this pass
Summary: First *full-document* re-read since the 2026-07-15 effect-capacity rework (the Round 9
pass on 2026-07-16 was scoped to blockers only). Completeness 8/8. Dependency graph clean — all
MVP downstream dependents have GDD files; the two without (Blueprint Crafting, Part Upgrade) are
explicitly Alpha. The effect-capacity model (Rule 8 / AC-01(a)–(d) / EC-01 / EC-02) holds under
full re-read with **zero regressions**, strongly corroborated by the live green implementation
(Part DB epic — 10 stories Complete; ContentValidator enforces every AC; suite 271/271 on Godot
4.7). No blocking design defect found. Applied 4 hygiene fixes: (1) EC↔AC citations added for
EC-03→AC-04, EC-04→AC-15a/15b, EC-06→AC-02, EC-08 (Assembly-owned, no Part DB AC), EC-09
(Assembly/Upgrade-owned), EC-14→AC-22 + ammo_cost note, EC-15 (schema-default, UI-owned) —
closing the project's EC↔AC cross-check rule gap; (2) stale `Open Questions` placeholder replaced
with "none remaining" + note that Visual/Audio + UI Requirements are Art-Bible / UX-spec-owned;
(3) Formula 4 Cooling (5–18) and Formula 6 Energy Capacity (80–120) "pending per-stat validation"
notes reframed as design-intent authoring guidelines (content now shipped within them, no per-stat
AC pins the exact range). The "unique trait" phrasing flagged in the Round 9 log was already
cleaned ("identity trait described in Rule 2" — accurate).
Prior verdict resolved: Yes — Round 9 (2026-07-16) APPROVED stands. Standing deferred *recommended*
items remain open and out of this hygiene pass's scope: D-1 (Rule 8 ceiling-clause rationale for
why Boss/Proto share ceiling 2), AC-01(c) naming `SKILL_CAPABLE_SLOTS`, and REC-1 / AC-06(b) /
Prototype-70% / earlier tuning items. NEW cross-GDD note: the attack-vs-utility skill-flavor split
(Rule 8, authoring-convention "until the Move DB carries a skill category") is now *actionable* —
Move DB epic is Complete; promoting it to an enforced Synergy/validator constraint can be scoped
(likely out of Part DB itself).

## Erratum — 2026-07-13 — C-3 + C-6 doc-hygiene (from /review-all-gdds) — light re-review touch owed

Two cross-GDD hygiene warnings from the 2026-07-13 holistic review, fixed here (Status stays APPROVED):
- **C-3:** the local energy-regen constant `BASE_REGEN` (safe range 5–15) renamed to **`BASE_ENERGY_REGEN`** and range aligned to **8–15**, unifying name/owner/range with TBC + registry. The 8-floor is load-bearing for TBC-F6's REPAIR anti-stall (a 5-floor would let a Light-cost Repair on a max-Recharge build become indefinitely sustainable). Owner = Turn-Based Combat; Part DB's Formula defines the regen step, TBC applies it. Renamed at the formula (energy_after_regen), variable table, tier table, and Tuning Knobs. Registry note updated.
- **C-6:** **Symbot Core Progression (#10b)** added to the Downstream Dependents table (10→11) — it reads the CP-defined `level_requirement`/`level_growth` fields hosted in the SympartData schema. Upstream stays "None" (the fields live in the root schema; there is no true circular dependency). AC-CP-20/AC-CP-22 are DoD gates on the Part DB erratum that authors those fields' values.

## Review — 2026-07-09 — Verdict: APPROVED (Round 8)
Scope signal: L (producer should verify before sprint planning)
Specialists: lean mode (no specialist agents)
Blocking items: 1 (resolved in session) | Recommended: 10 (logged, not applied)
Summary: Round 7 blockers all confirmed resolved. Round 8 found 1 new blocking issue: the Thermal Element Bonus (+5) appeared in Formula 5's tier table as a separate column but was absent from the formula expression, creating an ambiguity about whether it was pre-authored (schema value) or runtime (Combat System modifier). Resolved as runtime — formula expression updated to `skill_heat_generation = heat_generation + element_heat_bonus`; variable table expanded with `heat_generation` (0–40, schema) and `element_heat_bonus` (0 or +5, runtime, Thermal only); R2 simultaneously addressed with an Overheat-triggering worked example. 10 recommended items carried from Round 7 (R2–R9) plus new items (flavor_text max length, Boss-grade multi-stat spread AC, Open Questions stale text) were logged but not applied.
Prior verdict resolved: Yes — all Round 7 blockers confirmed fixed.

### Blocker Resolved (Round 8)
- B1: Formula 5 Thermal Element Bonus — expression updated to two-step; variable table expanded; element_heat_bonus defined as runtime Combat System modifier (+5 for THERMAL, 0 otherwise). Resolved R2 simultaneously: Overheat-triggering worked example added.

### Open Recommended Items (carried to Round 9 or downstream GDDs)
- R4: AC-24 candidate — element distribution per slot (≥1 Rare+ per element per slot) to defend DB4
- R5: AC-13/AC-15b — add explicit unblock triggers ("Unblocks when: X GDD defines Y interface")
- R6: Rule 2/Rule 8 — Core identity forward-reference to Assembly GDD
- R7: DB5 — scrap-sink quantitative floor (% of upgrade cost, not "player-perceived value")
- R8: EC-16 — player-visible pity progress signal requirement
- R9: AC-25 content density minimum (≥1 Common + ≥1 Rare per slot; Boss-grade spans ≥2 slots)
- NEW: flavor_text max length (suggest 80–120 chars; mobile UI risk)
- NEW: Boss-grade multi-stat spread AC (≥2 positive stats to preserve Prototype advantage)
- NEW: Open Questions section — update "[To be designed]" to reflect no remaining questions



## Review — 2026-07-09 — Verdict: MAJOR REVISION NEEDED → Revised (Round 7)
Scope signal: L (revision work was M — two systemic passes + three forced design decisions)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 10 (all resolved in session) | Forced design decisions: 3 (DN1–DN3) | Recommended: 9 (logged, not applied)
Summary: All Round 6 blockers confirmed resolved. Round 7 found 10 blockers dominated by two systemic defects: (1) AC-23 broken on two independent axes — `primary_stat` was undefined (structurally unimplementable) AND the threshold was mathematically unsatisfiable in all 8 slots at minimum Rare budgets even with 100% primary allocation; (2) float-epsilon inconsistency — canonical Formula 1/2 expressions omitted the `+0.0001` that the Pipeline note and AC-06(c) required. Critical empirical correction: main reviewer verified all disputed float claims via python3 — `20 × 1.15 = 23.0` EXACTLY (the AC-06(c) "22.999…" claim carried since Round 5 was FALSE; two Round 7 specialist claims about Formula 1 worked-example failures were also refuted); exhaustive scan proved F1/F2 epsilon is NOT load-bearing in MVP ranges (kept as defensive convention, documented honestly) while F2b's nudge IS load-bearing (26 real cases). AC-09(d) confirmed genuinely broken (0.25×1.5×1.3 = 0.48750000000000004 ≠ 0.4875 under strict equality) — converted to tolerance assertion. Remaining blockers: Balanced Frame ×1.05 moved from footnote into the Formula 1 modifier table; Prototype 15–20% claim substantiated with content rule + gradient worked example; Core passive/active contradiction (Rule 2 vs Rule 8); phantom "element-specific boost" field; AC-22 numbering gap filled with heat_generation validator.
Prior verdict resolved: Yes — all Round 6 blockers confirmed fixed.

### Blockers Resolved (Round 7)
- B1: Slot primary-stat mapping table added (Arms/Weapon split by damage_type subgroup; empty subgroup = vacuous pass + authoring warning)
- B2: Common primary CAPs + Rare primary FLOORs added per slot (floor = floor(cap × 1.50) + 1); floors override 60–70% band; AC-23 rewritten against them
- B3: Formula 2 canonical expression: `+ 0.0001` added; AC-06(c) rewritten as verified non-discriminating regression case
- B4: Formula 1 canonical expression: `+ 0.0001` added; worked example verified CORRECT as written (specialist claim of 40×0.80→31 refuted: it is exactly 32.0)
- B5: Balanced Frame ×1.05 Processing/Cooling added to Formula 1 modifier table; table declared sole authoritative source
- B6: AC-09(d) strict equality → `abs(result − 0.4875) < 1e-9`; (a)–(c) verified exact, left strict
- B7: Prototype gradient model codified; content rule ≥3 conditions with product ≥ ×3.0; worked example ladder 5%/7.5%/11.3%/16.9%
- B8: Core slot exception added to Rule 8 — active_skill_id null at all rarities, passive_id required at Rare+; AC-01 rewritten; SKILL_UNLOCK banned in Core upgrade_effects
- B9: "Element-specific boost" resolved as authoring convention, explicitly not a schema field (Rule 2 Core row)
- B10: AC-22 authored — heat_generation ∈ [0, 40] + heat_generation == 0 when active_skill_id null

### Forced Design Decisions (Round 7)
- DN1: AC-23 lever — explicit caps + floors chosen (over lowering threshold to ×1.30 or rebalancing budget table); preserves the ×1.50 "fresh Rare beats maxed Common" guarantee
- DN2: Prototype partial-fire — gradient chosen (over hard all-or-nothing gate); partial condition execution yields partial rate; no required_conditions schema field
- DN3: Core skill contradiction — passive-only slot exception chosen (over uniform Rule 8); Core is the only slot whose Rare-tier power is a passive identity trait

### Disputes Resolved (Round 7)
- AC-06(c) IEEE 754 dispute (open since Round 5) CLOSED empirically: 20×1.15 = 23.0 exactly; no discriminating epsilon input exists for Formula 2 in MVP ranges
- Round 7 adjudications by creative-director: AC-22 gap = blocking-as-documentation (tombstone/fill), recommended-as-validator; Core identity differentiation split — passive/active contradiction blocking, differentiation field deferred to Assembly GDD (R6)

### Open Recommended Items (carried to Round 8 — logged in session state)
- R2: Formula 5 lacks an Overheat-triggering worked example (Overheat branch untested by any example)
- R4: AC-24 candidate — element distribution per slot (≥1 Rare+ part per element per slot) to defend DB4
- R5: AC-13/AC-15b need structured BLOCKED/DEFERRED status blocks with unblock triggers
- R6: Core identity mechanical differentiation → forward-reference to Assembly GDD
- R7: DB5 scrap-sink constraint needs quantitative floor (% of upgrade cost), not "player-perceived value"
- R8: EC-16 must also require player-visible pity/break-attempt progress signal (Drop System GDD)
- R9: Content density minimum — ≥1 Common + ≥1 Rare per slot (16 parts); Boss-grade spanning ≥2 slots
- flavor_text max length undefined (mobile UI risk); AC-08 small-drawback (≤2) all-or-nothing behavior design flag
- Chassis over-leverage as universal modifier (open since Round 4); ~20 MVP parts thin (open since Round 3); Commons late-game hypothesis loop (open since Round 2); Head/Sensor info access; drop_enabled zone-gating

## Review — 2026-07-09 — Verdict: NEEDS REVISION → Revised (Round 6)
Scope signal: L (revision work was M — targeted precision fixes + design decisions on 2 forced items)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 3 (all resolved) | Forced design decisions: 2 (DN1, DN2) | Recommended: 14 (all applied)
Summary: All Round 5 advisory items addressed. Round 6 found 3 precision blockers, 2 forced design decisions, and 14 recommended hardening items. Critical finds: (1) B1 — Rule 7 / EC-03 / AC-04 internal contradiction: Rule 7 said element tag "always present", EC-03 permitted empty synergy_tags for wild parts, AC-04 allowed wild parts to skip element tag — resolved by Option A: all parts including wild must carry element tag; wild parts get element by thematic fit; (2) B2 — Formula 2b missing epsilon-nudge: `15 × (1-1/3)` evaluates to ~10.000...002 in IEEE 754, making `ceil()` return 11 without nudge — fixed by inlining `-0.0001`; (3) B3 — Tuning Knobs BASE_DROP_RARE annotation "3-5 attempts" false when pool_size > 1 — corrected with pool_size clarification. DN1 (Balanced Frame dominated strategy) resolved: +5% Processing, +5% Cooling bonus added to Rule 3 and Formula 1. DN2 (Common/Rare stat gap) resolved: Stat Budget Reference content rule and AC-23 added. All 14 recommended hardening items applied (AC-01 inverse rarity check, AC-04 wild-tag exclusion sub-assertions, AC-07 can_upgrade(3)=true, AC-09 ×999 required assertion, AC-12 reference fix, AC-14 null/empty guards, AC-15a drop_enabled assertion, AC-19 positive_total fail-fast guard, AC-23 new, DB3 Part-Break hard constraint, DB2/DB5 Drop System hard constraints, Cooling/Energy range notes, OVERHEAT_CARRY_IN derivation note, EC-10 acquisition experience intent). Status advanced to Revised Round 6 — Pending Re-review. IEEE 754 dispute on AC-06(c) (`20.0 × 1.15`) remains unresolved — verify with `print(20.0 * 1.15)` in GDScript before any change.
Prior verdict resolved: Yes — all Round 5 advisory items addressed.

### Blockers Resolved (Round 6)
- B1: Wild-element tag contradiction — Rule 7, EC-03, AC-04 all updated for consistency (Option A: all parts carry element tag; wild parts carry no manufacturer tag)
- B2: Formula 2b epsilon-nudge — `-0.0001` inlined into formula expression; self-contained without referencing prose
- B3: BASE_DROP_RARE tuning annotation — corrected with pool_size clarification ("~3–5 at base when pool_size=1; divide by pool_size for larger pools")

### Forced Design Decisions (Round 6)
- DN1: Balanced Frame — +5% Processing, +5% Cooling bonus added; unique among archetypes (no other archetype modifies these two stats in MVP)
- DN2: Common/Rare stat gap — Stat Budget Reference content rule added; AC-23 added enforcing `min(Rare_primary) > floor(max(Common_primary) × 1.50)` per slot

### Open Advisory Items (carried to Round 7)
- AC-06(c) IEEE 754 dispute unresolved — must verify `print(20.0 * 1.15)` in GDScript before any change to that AC
- ~20 MVP parts thin for 8 slots × 4 rarities (open since Round 3)
- Commons locked out of late-game hypothesis loop (open since Round 2)
- Head/Sensor sole info access — nothing enforces equipping it
- Prototype triple-punishment stack (rare + negative + undefined upgrade cost)
- drop_enabled binary can't support zone-gating (known constraint, open since Round 4)
- Chassis slot over-levered as universal stat modifier

## Review — 2026-07-09 — Verdict: NEEDS REVISION → Revised (Round 5)
Scope signal: L (revision work was S — targeted precision fixes only)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 8 (all resolved in session) | Recommended: 12 | Advisory: 7
Summary: All 8 Round 4 blockers confirmed resolved. Round 5 found 8 precision-level blockers — continuing the pattern of convergence (structural → precision → tightening). Critical finds: (1) Missing `chassis_archetype` schema field — Formula 1 requires chassis_modifier keyed by archetype but no Part Database field encoded it, confirmed by 3 specialists and main reviewer; (2) Formula 1's `.get(S, 1.0)` default for unlisted stats was prose-only, not in formula expression; (3) No AC exercised the epsilon-nudge boundary for floor() — an implementation omitting the nudge passed all prior ACs; (4) No Boss-grade acquisition floor committed — soft-lock risk with 2 MVP bosses; (5) Formula 3 variable table showed stale "999" — regression of Round 3 B1 surviving in a new location; (6) AC-10/AC-19 confirmed division-by-zero crash path for all-negative Prototype; (7) AC-07 had no explicit expected numeric output; (8) Enum validation ACs missing for 4 schema fields. All 8 resolved in same session. Status advanced to Revised Round 5 — Pending Re-review. Creative-director downgraded 2 specialist-blocker claims (Player Fantasy, Balanced Frame) and elevated 1 specialist-recommended item (Formula 3 "999") to blocking. Recurring root-cause pattern confirmed: un-propagated fixes survive one location after being corrected in another.
Prior verdict resolved: Yes — all 8 Round 4 blockers confirmed fixed.

### Blockers Resolved (Round 5)
- B1: `chassis_archetype` Enum field added to Rule 1 schema (null for non-CHASSIS parts); AC-20 added
- B2: Formula 1 updated to `chassis_modifier.get(S, 1.0)`; default value rule expressed in formula expression and note added referencing chassis_archetype field
- B3: AC-06(c) added — base=20, tier+1, expected=23 (IEEE 754 epsilon-nudge discriminating case for floor)
- B4: EC-16 added — Boss-grade acquisition floor committed as hard constraint on Drop System GDD
- B5: Formula 3 variable table multiplier range corrected: "0.5–999" → "0.5–1000"
- B6: AC-10 extended — requires ≥1 positive stat in addition to ≥1 negative; AC-19 precondition added (positive_total > 0 guaranteed by AC-10)
- B7: AC-07 rewritten — explicit expected value (base=10 → 15 at tiers +3 and +4), literal assertion required
- B8: AC-21 added — enum validation for manufacturer, element, damage_type, rarity (4 fields)
- Batched Recommended fix: Player Fantasy conditional note added (Synergy System dependency)

### Open Advisory Items (not blocking, track for future GDDs)

- No pity timer for Prototype drops
- Chassis slot over-levered as universal stat modifier
- Commons locked out of late-game hypothesis loop (open since Round 2)
- Head/Sensor sole info access — nothing enforces equipping it
- Balanced Frame is a dominated strategy (carry to Assembly System GDD — must not be lost)
- AC-20 recommended: heat_generation content validation ≤40 (AC-22 candidate)
- Cooling range (5–18) and Energy Capacity (80–120) in Formulas 4/6 ungrounded
- Rare acquisition enemy-pool dilution not acknowledged in Tuning Knobs
- Prototype triple-punishment stack (rare + negative + undefined upgrade cost)
- Common faucet without a sink (scrap sink Workshop-deferred, open since Round 4)
- Heat sustainability loop ("min turns between Signatures") not derived in Tuning Knobs
- Overheat carry-in of 20 lacks design-intent rationale in Tuning Knobs
- drop_enabled binary can't support zone-gating (known constraint, open since Round 4)
- AC hardening batch (AC-01 compound pass gaps, AC-09c float tolerance, AC-12 negative-stat masking, wild-manufacturer tag exclusion AC)
- ~20 MVP parts thin for 8 slots × 4 rarities
- Upgrade economy may create "always upgrade before hunting" dominant strategy

## Review — 2026-07-09 — Verdict: MAJOR REVISION NEEDED → Revised (Round 4)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 6 (2 downgraded to recommended by creative-director) | Recommended: 10 | Advisory: 8
Summary: All 10 Round 3 blockers confirmed resolved. Round 4 found 6 precision-level blockers — convergence from structural to tightening issues. Critical finds: (1) Player Fantasy named a "Forge tag + fire damage" moment the schema cannot produce — rewritten to deliverable MVP example; (2) Rule 8/EC-10 "Prototype exceeds Boss-grade at +5" claim is mathematically false at concentrated budgets — softened to "may exceed" with content authoring convention note; (3) AC-06(b) base=20 non-discriminating — fixed to base=13, expected [13,14,16,19,22,26]; (4) AC-07 untestable disjunction resolved to "returns capped +3 value"; (5) STAT_BONUS removed from upgrade_effects effect_type enum (unused in MVP); (6) AC-19 added for Prototype 70% concentration rule. Part-Break dependency note added for Formula 3 completeness. Status advanced to Revised Round 4 — Pending Re-review.
Prior verdict resolved: Yes — all 10 Round 3 blockers confirmed fixed.

### Blockers Resolved (Round 4)
- B1: Player Fantasy rewritten — "Ironclad tag + Volt element completing a 4-piece synergy" (achievable in MVP schema)
- B2: Rule 8 "must exceed" → "may exceed when Boss-grade is spread"; Stat Budget Reference and EC-10 updated with content authoring convention note
- B3: `upgrade_effects.effect_type` STAT_BONUS removed from MVP enum; documented as Full Vision reserved
- B4: Part-Break System added to Downstream Dependents table with stub interface contract for Formula 3 (economy-designer finding, creative-director downgraded from blocker)
- B5: AC-06(b) base=20 → base=13; expected sequence updated to [13, 14, 16, 19, 22, 26]
- B6: AC-07 "either returns +3 or errors" → "returns capped +3 value, no error; Workshop UI is responsible for prevention"
- B7: AC-19 added — Prototype concentration rule: top_two_sum / positive_total >= 0.70

### Advisory Items from Round 4 (Recommended, not yet addressed)
- No pity timer for Prototype drops (15% at perfect play — mobile session concern)
- Chassis slot over-levered as keystone stat modifier
- Commons locked out of late-game hypothesis loop (open since Round 2 REC-D1)
- Head/Sensor sole access to part-hunting info — nothing incentivizes equipping it
- No AC requires Prototype to have ≥1 positive stat (add to AC-19 or AC-10 on next pass)
- Formula 6 energy-at-zero precondition is UI-only — add explicit precondition note
- EC-10 should acknowledge Prototype tradeoff dissolves post-+3 (partially addressed; full acknowledgement deferred)
- Scrap sink economically undefined — Workshop GDD dependency note recommended
- EC-04: drop_enabled binary limitation not documented (zone-gating, seasonal events unsupported)
- AC-20 recommended: heat_generation upper bound ≤40 not validated
- Cooling range (5–18) and Energy Capacity range (80–120) in Formulas 4/6 ungrounded
- 20 MVP parts may be thin for "infinite build" fantasy at 2–3 per slot



## Review — 2026-07-09 — Verdict: MAJOR REVISION NEEDED → Revised
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 6 | Recommended: 7+ | AC corrections: 5
Summary: Four independent specialists converged on the same fault lines. Critical find: Boss-grade `base_drop_rate = 0.00` made boss parts permanently un-droppable (`0.00 × 999 = 0.00`). Additional blockers: Overheat damage 15% vs 10% discrepancy across sections; EC-03/AC-04 synergy tag contradiction; `base_drop_rate` missing from schema; Energy cost reduction in Rule 10 had no formula; Formula 2b `max(0, …)` clamp undocumented. All 6 blockers resolved in the same session — status advanced to Revised (Pending Re-review).
Prior verdict resolved: N/A — first review.

### Blockers Resolved
- BLOCK-1: Boss-grade base rate changed 0.00 → 0.001; Tuning Knobs updated with `BASE_DROP_BOSS_GRADE`
- BLOCK-2: Rule 5 Overheat damage corrected to 10% (matching Formula 5 and Tuning Knobs)
- BLOCK-3: EC-03 rewritten — empty synergy_tags valid for WILD rarity only; AC-04 updated to match
- BLOCK-4: Dependency table clarified — `base_drop_rate` is per-rarity config constant, not a schema field
- BLOCK-5: Rule 10 rewritten — Energy cost reduction removed as universal rule; skill effects deferred to Move Database GDD
- BLOCK-6: Formula 2b clamp note added — `max(0, …)` documented as mandatory floor preventing double-negation

## Review — 2026-07-09 — Verdict: MAJOR REVISION NEEDED → Revised (Round 2)
Scope signal: L
Specialists: systems-designer, qa-lead, game-designer, creative-director
Blocking items: 8 | Recommended: 6+ | AC corrections: 4
Summary: Prior 6 blockers all confirmed resolved. This pass found 8 new blockers: (1) Formula 1 missing `max(0,...)` clamp — Prototype drawbacks could produce negative final stats; (2) formula composition pipeline (F2/F2b/F1) never explicitly defined; (3) float precision unspecified — IEEE 754 could cause off-by-one errors across all three formulas; (4) non-discriminating AC test cases in AC-05/06/08/09 that pass against broken implementations; (5) Formula 3 worked example said 0.49 (correct: 0.4875); (6) BLOCK-4 fix not propagated to Rule 9, Interactions table, EC-12, AC-09; (7) `recharge_bonus` used in Formula 6 without a named stat in Rule 4; (8) Prototype endgame identity inverted (drawback removal at +3 with lower base stats makes Prototype strictly weaker than Boss-grade at endgame). All 8 resolved: Formula 1 updated, pipeline section added, float precision epsilon-nudge documented, ACs rewritten with discriminating inputs, Recharge added as 11th stat, base_drop_rate references reconciled, Prototype Option B (higher focus-stat ceiling, 70%+ concentration rule) applied.
Prior verdict resolved: Yes — all 6 blockers from Review 1 confirmed fixed.

### Blockers Resolved (Round 2)
- B1: Formula 1 wrapped with `max(0, floor(...))`
- B2: "Formula Pipeline" section added — explicit sign-routing rule for F2 vs F2b
- B3: Numeric precision note added (epsilon-nudge method) covering F1, F2, F2b
- B4: AC-05, AC-06, AC-08, AC-09 rewritten with discriminating test inputs
- B5: Formula 3 worked example corrected 0.49 → 0.4875
- B6: `base_drop_rate` field language removed from Rule 9, Interactions table, EC-12; AC-09 Boss-grade expected value corrected to 0.001
- B7: Recharge added as 11th MVP stat in Rule 4; Rule 5 and Formula 6 updated
- D2: Prototype Option B applied — Rule 8 and Stat Budget Reference updated with 70%+ focus-stat concentration rule and design-intent note

### Advisory Fixes Applied (Round 2)
- Rule 3: Light Frame "+20% Evasion (derived)" corrected to "+20% Mobility"
- Formula 5 variable table: overheat damage range corrected from "0–max_structure" to "0–floor(max_structure × 0.10)"
- Formula 5 overheat: carry-in clarified — Formula 4 does not run on the carry-in turn
- Stat Budget Reference: multi-stat cap note added (values > 55 require distribution)

### Open Items from Round 2 (Recommended, not yet addressed)
- D1: Commons deliver no hypothesis in early game — flagged as constraint for Synergy System GDD and content authoring guidance (not a schema problem)
- D3: Stat literacy / slot-stat predictability — flagged as constraint for Assembly System GDD and Workshop UX (not a schema problem)
- REC-D3: Drop condition vocabulary (`"arm_broken"` etc.) must be defined in Drop System GDD before content authoring begins — retrofit debt risk if parts are authored first
- Move Database + Passive Database still missing from Systems Index — AC-13 blocked until they are added

### Open Items (Recommended, not yet addressed)
- Move Database + Passive Database are referenced but not in the Systems Index — add before next review
- Common parts may not deliver "every drop is a hypothesis" after early game — design decision deferred
- `recharge_bonus` in Formula 6 is not one of the 10 named MVP stats — needs clarification
- Rare base rate 0.25 may be too fast; consider 0.15 after playtesting
- `ammo_cost = 0` for all MVP content — content validation rule recommended
- F2 + F2b composition for same Prototype part instance — add explicit note

## Review — 2026-07-09 — Verdict: MAJOR REVISION NEEDED → Revised (Round 3)
Scope signal: L
Specialists: systems-designer, qa-lead, game-designer, creative-director
Blocking items: 10 | Recommended: 7 | AC corrections: 4
Summary: All 8 Round 2 blockers confirmed resolved. This pass found 10 new blockers — all documentation-fidelity failures from two un-propagated changes (the Round 2 Pipeline insertion and the Recharge 11th-stat addition). Critical finds: (1) AC-09b expected output wrong — `0.001 × 999 = 0.999`, not `1.0`, causing correct implementations to fail the test; (2) Formula Pipeline scoped "Prototype parts only" — non-Prototype parts appeared to bypass Formula 2; (3) Formula 1 variable table contradicted the Pipeline with wrong symbol/range; (4) AC-05(b) non-discriminating after Pipeline added; (5) Recharge range conflict — Formula 6 said 0–15 but two contributing parts (EC + Core at 15 each) sum to 30; (6) AC-04 used "wild-rarity" which is not a valid rarity enum value; plus four more. Two design rulings resolved: recharge_bonus max = 0–30 (both contributors independent), Recharge slot exclusivity = structural rule (AC-18 added). All 10 blockers resolved in same session. Status advanced to Revised Round 3 — Pending Re-review.
Prior verdict resolved: Yes — all 8 blockers from Review 2 confirmed fixed.

### Blockers Resolved (Round 3)
- B1: AC-09b multiplier corrected 999 → 1000 (0.001×999=0.999≠1.0); also fixed in Formula 3 table and Tuning Knobs
- B2: Formula Pipeline section renamed "All Parts"; added explicit statement that F2 applies to all rarities
- B3: Formula 1 variable table updated — symbol `upgraded_value[S]`, range −55–110 per part, sum −440–880
- B4: EC-08 "10-stat list" → "11-stat list"; enumerated all 11 canonical stats
- B5: AC-05(b) replaced with discriminating tier +1 mixed-part Pipeline composition test
- B6: AC-04 "wild-rarity" replaced with "wild-manufacturer" / `manufacturer == 'wild'`
- B7: Rule 4 header "Ten stats" → "Eleven stats"
- B8: Formula 6 recharge_bonus range 0–15 → 0–30 (Ruling A: both EC and Core contribute independently)
- B9: AC-17 added — validates per-part Recharge value in [0, 15]
- B10: AC-18 added — validates Recharge slot exclusivity (ENERGY_CELL and CORE only, Ruling B: structural rule)

### Advisory Fixes Applied (Round 3)
- Rule 2: Core slot Stat Focus updated to include Recharge
- Rule 4 Recharge row: added "Schema rule (enforced)" note referencing AC-18
- Formula 1 modifier table note: added Recharge to exception list (uses ×1.0)
- Formula 2b worked example: "0.67" → "0.667" (avoids wrong intermediate math)
- Formula 5 output range: "clamped 0 to max_structure" → "clamped 0 to floor(max_structure × 0.10)"
- EC-10: added post-+3 Prototype design intent note for downstream GDD authors
- EC-08: enumerated all 11 canonical MVP stats inline

### Open Items (Recommended, not yet addressed)
- REC-1: Prototype budget guarantee math fails at minimum floor — Rule 8 "must exceed" claim is not universally true. Soften to "at equivalent or higher budget, focus stat exceeds Boss-grade at +5" OR raise Prototype minimum budgets. Deferred for balance tuning.
- AC-06(b): base=20 sanity check is non-discriminating (all exact integers). Consider replacing with base=13.
- No AC validates the Prototype 70% concentration rule (focus stat ≥ 70% of positive budget).
- Formula 4 Cooling range "5–18" and Formula 6 energy_capacity range "80–120" are ungrounded — add budget arithmetic or content authoring notes.

## Review — 2026-07-16 — Verdict: NEEDS REVISION → resolved same session (Accepted, marked Approved)
Scope signal: S
Specialists: game-designer, systems-designer, qa-lead, creative-director (full-mode adversarial panel)
Blocking items: 2 | Recommended: 4 (+1 nice-to-have) — deferred, user scoped this pass to blockers only
Summary: Targeted re-review of the 2026-07-15 Rule 2/Rule 8/AC-01 rework from a skill-quota to an effect-capacity model (which resolved the prior Rule 2↔Rule 8 contradiction; the rest of the doc was Approved at Round 8). Two blockers found and closed for real, not in prose: **B-A** — Rule 8's claim that "AC-01 validates" the SKILL_UNLOCK ban on support slots was false-coverage (`_check_nullability` reads only `active_skill_id`/`passive_id`, never `upgrade_effects`, so a support-slot part could smuggle an active skill in at an upgrade tier undetected). Fixed by adding **AC-01 sub-check (d)** (`content_upgrade_skill_unlock_forbidden`), a new validator dispatch `_check_upgrade_effects()`, and a negative/positive test pair (Core +4 SKILL_UNLOCK → error; Core +4 SKILL_ENHANCE → pass). **B-B** — EC-01/EC-02 said "Always valid", contradicting the Rare+ effect floor=1 (proven by `test_ac_01_rare_noncore_no_effect_errors`) and citing no AC; rewritten rarity-scoped with `Verified by AC-01(b)` (EC-02 also cites AC-01(c) for support-slot legality). CD verdict: approve-on-fix-confirmation. Suite 160/160 green (419 asserts, +2 tests/+3 asserts vs prior baseline), Godot 4.7.
Prior verdict resolved: Yes — the Rule 2↔Rule 8 contradiction (tech-debt, RESOLVED 2026-07-15) is now design-review-verified; recommended items REC-1 / AC-06(b) / Prototype-70% / Formula-4&6-ranges remain open (unchanged, out of this pass's scope).

### Recommended (deferred — NOT addressed this pass, user chose blockers-only)
- D-1: Rule 8 could state the ceiling-clause rationale explicitly (why Boss/Proto share ceiling 2).
- Skill-flavor (attack vs buff/debuff) is authoring-guideline only until the Move DB carries a skill category — then it becomes a Synergy/validator constraint.
- Stale "unique trait" phrasing near the Core identity consequence (partially cleaned in B-A edit).
- AC-01(c) could cite the `SKILL_CAPABLE_SLOTS` constant by name for traceability.

## Review — 2026-07-16 — Verdict: NEEDS REVISION
Scope signal: L (system) / S (revision pass — ~half-day of doc edits + 2 fast-follow stories)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, godot-specialist, creative-director (full-mode adversarial panel; all run headless on standard context — session Agent-tool 1M-context pin unusable)
Blocking items: 7 | Recommended: 5 (incl. 1 bundled validator-hardening fast-follow) | Nice-to-have: ~13 (batched, mostly downstream-GDD-owned)
Summary: Round ~10 full-panel re-review of the shipped doc (10-story epic green). Panel filed 42 findings (13 specialist-BLOCKING); CD deduplicated into 10 clusters and adjudicated severity splits explicitly (downgraded systems' Overheat-Thermal-derivation + max-Recharge-sustainability to RECOMMENDED; upgraded per-stat-cap and Prototype-drop-condition-AC to BLOCKING). Verdict NEEDS REVISION on 3 grounds: (1) two BLOCKING project directives violated — EC-05/07/13 lack "no AC because" clauses, EC-10/EC-11 lack citations (→AC-08/AC-07), and AC-09 never tests a product strictly >1.0 (clamp-free impl passes); (2) shipped content can betray a design promise — Prototype Chassis min budget 40×0.70=28 < Rare floor 29 (single off-by-one slot); (3) unenforced named contracts — Prototype ≥3-conditions/≥×3.0-product rule has no AC (unhinges Drop-System N_PROTO_PITY=25 calibration), `level_growth` typed `Dictionary[String,int]` vs `StringName` keys (CP-F3 lookups would silently return 0), per-stat ≤55 cap has zero enforcement (60 passes AC-12 → 120 at +5, breaking F2's 0–110 range), and Rule 9's ×0.7 example is illegal under Drop System Rule 5a (CD directed Option A: remove example, range floor →1.0). Disposition: implementation stands, header downgraded to Approved — Revision Pending until Priority-1 closes. Story-009 code comments promised entry-shape validators that never shipped (upgrade_effects/drop_conditions) — logged as required fast-follow.
Prior verdict resolved: Yes — prior entry (2026-07-16 Round 9) closed B-A/B-B and was Approved; this round's findings are all new (none are reopened Round-9 items). Deferred Round-9 opens REC-1/AC-06(b)/Formula-4&6-ranges were independently re-confirmed by the panel (REC-1 escalated into blocker #3; AC-06 non-discrimination re-flagged as godot #12; F4/F6 ranges re-flagged by economy #11 + systems #8).

## Review — 2026-07-16 — Verdict: NEEDS REVISION → resolved same session (CD fix-confirmed, marked Approved)
Scope signal: S (revision pass — ~19 surgical doc edits, no implementation change)
Specialists: godot-specialist, economy-designer, systems-designer, game-designer, qa-lead, creative-director (full-mode adversarial panel; Round 11 — fresh-panel confirmation of the 7 Round-10 fixes)
Blocking items: 3 | Recommended: 7 | Nice-to-have: ~13 (excluded by user scope choice)
Summary: The 7 Round-10 fixes all held, but the panel found 3 new blockers in the fix text itself. **B-1 [CD/game-designer]** — Round-10 AC-25 defined the focus stat as "highest positive bonus, whichever key it is", so a Chassis Prototype `{structure: 10, armor: 30, mobility: -8}` passed (30 > 29) while being a pure Structure downgrade — the exact failure EC-10 exists to prevent. **User design decision:** focus stat = slot primary stat (Arms/Weapon by damage_type per AC-23); off-primary Prototypes are not authorable in MVP (the alternative — off-primary focus + a primary minimum — is budget-infeasible under AC-19's 70% concentration: ≥45 focus + ≥19 primary = 64 > 55 max). AC-25 amended with two clauses + the must-FAIL fixture; EC-10 and Stat Budget Reference aligned. **B-2 [qa-lead]** — AC-08(b)'s base −1 fixture `[-1,-1,-1,0,0,0]` is also produced by a no-reduction implementation; replaced with base −3 (python-verified: correct `[-3,-2,-1,0,0,0]`; no-reduction `[-3,-3,-3,0,0,0]`; floor-variant `[-2,-1,0,1,1,1]`). **B-3 [godot-specialist]** — `stat_bonuses` schema said bare "Dictionary" with String-keyed examples while the pipeline reads StringName keys (4.7 typed dicts don't coerce — silent 0s); pinned `Dictionary[StringName, int]` with `&"key"` examples mirroring level_growth. Recommended fixes applied: AC-09(e) false "1.575 exact" claim corrected (product is 1.5749999999999997; strict == 1.0 stays safe), AC-06 ×2.00 non-discrimination exception documented, typed-export sentinel convention note (null → &""/0/{}), focus-floor authoring rule generalized beyond Chassis, EC-12 → "Verified by AC-11" citation, AC-26 Rule-9/Drop-5a invariant ownership cross-ref, "15–20%" band → "~16.9–20%" (true floor 16.875%) in 4 locations. qa-lead's REC-4 (F2b nudge not load-bearing / 15×(1−1/3)=10.0 exact) was refuted by python3 (10.000000000000002) and discarded per CD ruling. CD targeted fix-confirmation (committed in lieu of a full re-panel): all 3 blockers CONFIRMED against their acceptance tests, zero inconsistencies introduced — APPROVED.
Prior verdict resolved: Yes — all 7 Round-10 blockers verified fixed by the fresh panel; this round's 3 blockers were new findings in the fix text, not reopened items.
**Production debt (OPEN, escalated):** the Round-10 validator-hardening fast-follow story was never created; AC-25/26/27 have zero ContentValidator implementation and formula ACs 05–09/16 have no on-disk tests — the Round-10 entry's "271/271, ContentValidator enforces every AC" claim overstates the shipped state. Needs a producer-tracked story before content authoring scales.
