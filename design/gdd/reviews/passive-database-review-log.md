# Passive Database — Review Log

## Review — 2026-07-10 — Verdict: NEEDS REVISION (revisions applied same session; awaiting fix-confirmation re-review)
Scope signal: M (revision itself S–M — surgical schema + AC edits, no new deps, no ADR)
Specialists: game-designer, systems-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 4 gates (7 findings) | Recommended: 7 | Advisory/Nice-to-have: several
Prior verdict resolved: First review

### Summary (creative-director synthesis)
The GDD is "two documents wearing one cover": a sound schema-ratification spec for three fully-authored MVP status riders (that TBC/Part DB already depend on), and a deliberately-deferred content doctrine (OQ-PDB-1). The schema-only Foundation GDD is coherent to approve at #1b — but three findings made 3 of 4 behavior classes literally unimplementable, one AC defect disabled the PassiveDB↔TBC divergence guardrail, and OQ-PDB-1's critical-path priority was invisible. Verdict NEEDS REVISION (not MAJOR); fix scope surgical.

### Blocking gates (all resolved in-session)
1. **Schema hole** — STAT_AURA/RESOURCE_EFFECT/STRUCTURAL_EFFECT had no data fields (no stat/resource/amount). Fix: added Rule 3a `behavior_params` typed sub-schema; added field to Rule 1 + Rule 5 table.
2. **Axis ambiguity (root cause of #1 and #4)** — doc never decided whether `behavior_class` or `passive_class` is authoritative. Fix: ratified `behavior_class` as sole resolution axis; `passive_class` demoted to pure metadata.
3. **`scope`/`ON_WEAPON_HIT` contradiction + TBC vocab mismatch** — Rule 2 said scope null for non-ON_HIT yet `thermal_burn_on_weapon` carried `ON_WEAPON_HIT` + `WEAPON_ONLY`; TBC Rule 13 uses "ON_HIT (WEAPON-slot)". Fix: removed `ON_WEAPON_HIT`; collapsed to `ON_HIT` + `scope: WEAPON_ONLY`; added `ON_TURN_START` for TBC parity; `PERSISTENT` reclassified as application mode. **Grounded in TBC Rule 13 canonical enum.**
4. **`passive_class`/stacking contradiction** — Rule 4 keyed stacking on a field declared "metadata only." Fix: re-keyed stacking defaults onto `behavior_class`.
5. **AC-PDB-02 orphan fixture untestable** — no `trigger_category`, so "when trigger fires" had nothing to fire; error format unspecified. Fix: `ON_BATTLE_START` fixture + observable + substring ID assertion + FAIL conditions. (This is the PassiveDB↔TBC divergence guardrail — highest-priority QA fix.)
6. **AC count wrong** ("9 BLOCKING" → actually 11+). Fix: corrected to 12 BLOCKING + 5 ADVISORY-DEFERRED + 4 activates-on-first-content; EC↔AC cross-check rebuilt.
7. **OQ-PDB-1 priority invisible** — deferred Core-passive content is critical-path (Part DB Rare+ Cores require it; Pillars 3–4 funded by it). Fix: reclassified as named critical-path dependency with content charter.

### Folded-in recommended items
AC-PDB-06 positive case; AC-PDB-08 named ordering observable (proc log); attacker/target roles + duration FAILs in AC-04/05; Rule 3 trigger×behavior legality matrix; Rule 2a ON_OVERHEAT ordering contract; EC-PDB-08 + AC-PDB-15/16/17 (negative STRUCTURAL_EFFECT); deferred AC-PDB-D1–D4 as OQ-PDB-1 entry criteria.

### Deliberately deferred to OQ-PDB-1 content pass (per CD ruling — not schema defects)
- Player Fantasy thinness: 3 flat riders fire identically regardless of build depth (UNIQUE_PER_TRIGGER makes a 6-part Volt stack == 1-part). Recorded as OQ-PDB-1 charter: investment-scaling / threshold passives are that pass's brief, not the ratified riders'.
- Actual Core identity passive roster (all of Rule 6's content).

### Re-review target
Fix-confirmation re-review only the 4 gates + folded edits above — not a full redesign. Run `/design-review design/gdd/passive-database.md` in a fresh session.
