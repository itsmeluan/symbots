# Review Log: Enemy Database

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
