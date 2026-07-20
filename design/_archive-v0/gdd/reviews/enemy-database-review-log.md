# Review Log: Enemy Database

## Erratum — 2026-07-13 — ST-1 (`completion_bonus_xp` boss field) APPLIED — light re-review touch owed

Source: Symbot Core Progression 4th-pass `/design-review` (2026-07-13), OQ-CP-8 fix (per-boss completion bonus lever), tracked as **ST-1** in `production/errata-backlog.md`.

**Change (file-verified):** new schema field **`completion_bonus_xp: int`** added after `xp_value`. Flat one-time bonus added to `xp_value` by Core Progression at battle end (CP Rule 3a) before the deployed/benched split; **`0` for all WILD**, non-zero **only on BOSS** (MVP: Boss 1 = 310, Boss 2 = 180). Unlike `xp_value` it is **not** CP-F4-derived — per-boss authored, calibrated by ELZS against AC-ELZS-14. Content validation (BLOCKING): `≥ 0`, and `0` unless `enemy_class == BOSS`. Flows to Core Progression via the TBC `battle_ended` payload.

**Owed:** light `/design-review enemy-database.md` confirmation touch (mechanical schema-field addition — Status stays APPROVED); the `completion_bonus_xp` content-validation rule may warrant a small AC when the Enemy DB content-validation suite is next revised (currently specified in the field description).

## Review — 2026-07-09 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead; senior synthesis: creative-director
Blocking items: 6 | Recommended: 6
Summary: Structurally sound, disciplined Foundation schema with bounded correctable defects — chiefly the EDB-2 TTK calibration (broken in 4 places: WILD-early ceiling, BOSS floor/ceiling, no joint structure×defense bound), a false power-cap safety claim at player Armor=0, and AC-ED-09 hardcoding ×1000 instead of the product invariant. Roughly half of the economy/game-designer findings were correct diagnoses aimed at the Drop System and Part-Break GDDs; resolution was to name those owners in Open Questions 4–6 rather than overload this schema.
Prior verdict resolved: First review

### Post-review revision (same session, 2026-07-09)
All 6 blocking items resolved with user decisions:
1. AC-ED-14 rewritten as computed TTK check (user chose computed over static bands); bands corrected — WILD-early TTK 2–4 / structure 60–88 (user chose widen-TTK over tighten-structure); BOSS 364–594 at reference D=30. Float-scanned: zero divergences, no epsilon needed.
2. WILD_POWER_CAP lowered 40 → 39 (user chose cap-lowering over Armor-floor invariant or prose-only fix) — eliminates the one-shot at Armor=0/structure=60.
3. AC-ED-09 rewritten as product invariant `BASE_DROP_BOSS_GRADE × multiplier ≥ BOSS_GRADE_BREAK_GUARANTEE` (new knob, 1.0); pity-arc door left open for Drop System GDD.
4. Seven qa-lead AC fixes applied (AC-ED-05/06/07b/08b/13-split/14-boundaries/16-DF-1-citation).
5. Harvest-decision rule added: WILD `loot_pool.size() > break_regions.size()`, BLOCKING via AC-ED-15(c).
6. Open Questions 4–6 added naming downstream owners (Drop System: acquisition policy + pity + pool-dilution reconciliation; Encounter Zone/content-lint: roster coverage).
Also folded in (advisory): NULL_ELEMENT_MAX_WILD knob + AC-ED-15(d); in-spec output range 9–326; knob-warning prose corrections; A=0/D=0 DF-1 note; stale range sync.
Deferred (Recommended, not blocking): asymmetric break_hp warning on shared break events; EDB-3 multiplier-meaningfulness check; qa-lead's 3 extra test cases (empty stats dict, reserved ELITE class, stale break_hp).

**Next step**: full re-review in a fresh session (`/design-review design/gdd/enemy-database.md`) to verify blocker resolution before marking Approved.

## Review — 2026-07-09 (Session 2) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead; senior synthesis: creative-director
Blocking items: 5 | Recommended: 9
Summary: All six prior fixes confirmed held. New blockers found: AC-ED-14 degenerate blind spot (TTK=2 via Armor=0 passes silently — the same degenerate case WILD_POWER_CAP defends against, but the TTK band states "2" as a valid lower bound, so no warning fires); AC-ED-05 validator crash risk on missing `stats` keys (bracket access vs. safe `get()`); ×1000 boss-break multiplier requirement invisible from Part DB authoring context; AC-ED-15(c) missing 1-region minimum-case fixture; OQ5 framed as neutral deferral when pool-size ranges encode specific farming timelines (8–24 fights/Rare at diluted rates). Two design decisions resolved: BOSS_GRADE_BREAK_GUARANTEE lowered 1.0 → 0.5 (~50% per qualifying break, avg 2 attempts per exclusive; ×500 multiplier threshold now aligned with Part DB AC-11); OQ5 rewritten to state pool-size position and hard-block Drop System GDD on choosing a dilution model.
Prior verdict resolved: Yes — 6 of 6 prior blocking items confirmed resolved

### Post-review revision (same session, 2026-07-09)
All 5 blocking items resolved:
1. EDB-2 band table + AC-ED-14: added TTK lower-bound note (TTK=2 only via Armor=0, not a content target; WILD_POWER_CAP is the actual guard) and ADVISORY justification with Beta-upgrade note.
2. AC-ED-05(a): replaced `stats["structure"]` with `stats.get("structure", 0)` + explicit `stats: {}` fixture.
3. Rule 2 boss row + AC-ED-09: updated to 0.5 guarantee (×500 threshold, aligned with Part DB AC-11); cross-system boundary case rewritten (×500 now passes; ×499 fails both ACs).
4. AC-ED-15(c): added 1-region boundary fixture.
5. OQ5: rewritten with this schema's position on pool sizes and three-option hard-block for Drop System GDD.
Design decisions: BOSS_GRADE_BREAK_GUARANTEE 1.0 → 0.5; OQ4 updated with pity-floor requirement.

**Next step**: full re-review in a fresh session (`/design-review design/gdd/enemy-database.md`) after `/clear` — 9 recommended AC fixture/documentation improvements remain for the re-review to validate before Approved.

## Review — 2026-07-10 (Session 3) — Verdict: NEEDS REVISION (pending re-review)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead; senior synthesis: creative-director
Blocking items: 5 | Recommended: 8
Summary: All 11 prior fixes confirmed held. New blockers: AC-ED-14 pseudocode used GDScript bracket access (`stats["armor"]`/`stats["resistance"]`/`stats["structure"]`) which throws in strict mode — replaced with `.get(key, 0)`; Part DB Tuning Knobs stated ×1000 as "current value" for boss-break multiplier while Enemy DB requires ×500 minimum for 50% tension — cross-doc contradiction fixed in Part DB (Formula 3 table, Tuning Knobs row, AC-09(b) boundary note); AC-ED-07(a) had only a passing fixture, no counter-example — added structure=85 × 0.35 = 28 (fail) fixture; AC-ED-05(b) missing upper boundary fixtures — added armor=110 passes / armor=111 fails with `<= 110` clarification; Rule 6 / AC-ED-15(c) harvest-decision rule lacked floor-loot framing — un-gated parts now documented as floor loot. Recommended fixes also applied: epsilon count corrected 8→7 (python3 exhaustive scan); BOSS_GRADE_BREAK_GUARANTEE knob description de-dishonested (2-boss MVP roster cannot guarantee single-session exclusion); EDB-2 BOSS Armor > 80 authoring constraint documented with S_max formula; OQ4 mobile session note added (64–72% zero-Rare at 5 fights); EDB-3 syntactic-only note added; OQ7 added (minimum-meaningful break multiplier — owner: Drop System/Part DB); AC-ED-06(c) second positive fixture; EDB-3 at-fight-start clarification; AC-ED-04(f) BLOCKING ownership disambiguated.
Prior verdict resolved: Yes — all 5 prior blocking items confirmed resolved

### Post-review revision (same session, 2026-07-10)
All 5 blocking items resolved and all 8 recommended items addressed:
1. AC-ED-14: `stats["armor"]`/`stats["resistance"]`/`stats["structure"]` → `.get()` safe access; D=0 edge case note added.
2. Part DB ×1000→×500: Formula 3 table, Tuning Knobs row (current value 1000→500, safe range 500-9999→500-999), AC-09(b) boundary note.
3. AC-ED-07(a): Counter-example fixture added (stored=28 fails, stored=29 passes at structure=85×0.35).
4. AC-ED-05(b): Boundary fixtures added (110 passes, 111 fails; `<= 110` not `< 110`).
5. Rule 6 floor-loot framing: "un-gated part(s) are floor loot" clarification added with Pillar 2 floor minimum.
Recommended: epsilon count 8→7; BOSS_GRADE_BREAK_GUARANTEE honest framing; EDB-2 BOSS Armor > 80 constraint note + S_max formula; OQ4 mobile 64–72% note; EDB-3 syntactic-only advisory; OQ7 minimum-meaningful multiplier; AC-ED-06(c) second positive fixture; AC-ED-04(f) BLOCKING ownership.

**Next step**: `/clear` then `/design-review design/gdd/enemy-database.md` — fourth pass in fresh session to achieve APPROVED verdict.

## Review — 2026-07-10 (Session 4) — Verdict: APPROVED
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead; senior synthesis: creative-director
Blocking items: 2 | Recommended: 18
Summary: All 5 prior blocking items confirmed held. Two new true blockers: `region_fraction` field missing from Rule 5 break_regions schema (persistent gap across 3 prior reviews — EDB-1 requires it, AC-ED-07(a)/(d) and EC-ED-11 reference it; fixed by adding field to schema table, updating example record to `region_fraction: 0.48`, and clarifying EDB-1 prose to store both authored input and computed break_hp); floor loot rarity gap (un-gated pool parts had no rarity restriction, allowing Rare floor loot that silently undermines Pillar 2; fixed by adding content rule to Rule 6 requiring un-gated parts be Common rarity). Eighteen recommended AC improvements applied: EDB-2 TTK arithmetic corrected (Armor=90 TTK=13→12); OQ7 elevated from open question to dependency constraint; Combat UI added to Dependencies table; AC-ED-01 added ELITE class and wrong-type spawn_enabled fixtures; AC-ED-03 added size=4/5 boundary; AC-ED-04 added 1-disabled-of-2 boundary; AC-ED-06(d) added cross-enemy BOSS_GRADE fixture; AC-ED-07(b) added false-branch fixture; AC-ED-11 narrowed to integration scope only; AC-ED-12 added dedup-set semantics to unblock condition; AC-ED-14 added structure=89/90 classification boundary and dual-channel fixture; AC-ED-15(b) replaced [2,4] notation with explicit inequality language; four new ACs added (AC-ED-17 DB-side BOSS spawn warning, AC-ED-18 floor loot rarity, AC-ED-19 minimum break-gated parts, AC-ED-20 shared break_event positive case).
Prior verdict resolved: Yes — all 5 prior blocking items confirmed resolved

### Post-review revision (same session, 2026-07-10)
All 2 blocking items and all 18 recommended items addressed:
1. `region_fraction` added to Rule 5 break_regions schema as 5th field; example record updated; EDB-1 prose updated ("schema stores both region_fraction (authored input) and computed break_hp").
2. Floor loot rarity rule added to Rule 6 (un-gated pool parts must be Common rarity to preserve Pillar 2's floor loot purpose).
Recommended: EDB-2 TTK=12 correction; OQ7 dependency constraint elevation; Combat UI dependency added; AC-ED-01/03/04/06(d)/07(b)/11/12/14/15(b) all improved with additional fixtures and boundary clarity; AC-ED-17/18/19/20 added.
Status updated: Pending Review → Approved. systems-index.md updated: In Review → Approved.

**Next step**: `/design-system symbot-assembly` — #4 in design order (Core, MVP).
