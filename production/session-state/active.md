# Active Session State

## Current Task
Enemy Database GDD — Re-reviewed (Session 2). Verdict: NEEDS REVISION, 5 new blockers resolved same session.

## Session 2 Blocker Fixes (2026-07-09)
1. **EDB-2 + AC-ED-14**: Added TTK lower-bound note — TTK=2 for WILD-early only via Armor=0
   (degenerate floor the WILD_POWER_CAP guards). Added ADVISORY justification + Beta upgrade note
   to AC-ED-14. Cross-references EDB-2 and AC-ED-05c now linked.
2. **AC-ED-05(a)**: Replaced `stats["structure"]` with `stats.get("structure", 0)` safe-access
   pattern. Added `stats: {}` explicit fixture. Prevents validator crash on missing keys.
3. **Rule 2 + AC-ED-09**: BOSS_GRADE_BREAK_GUARANTEE lowered 1.0 → **0.5** (design decision).
   Design target: ~50% per qualifying break, avg 2 attempts per exclusive. Required multiplier
   now ×500 — aligned with Part DB AC-11. Updated AC-ED-09 boundary: ×500 passes, ×499 fails.
4. **AC-ED-15(c)**: Added 1-region boundary fixture: 1 region + 1 pool → fails; 1 region +
   2 pool → passes.
5. **OQ5**: Rewritten. Pool-size ranges locked as authored (WILD 2–4, BOSS 4–6). Farming
   timelines stated: WILD min 8.33%/~12 fights, BOSS max 4.17%/~24 fights at pool-diluted rates.
   Drop System GDD hard-blocked on 3 explicit model choices.
   **OQ4**: Updated with design decision and Drop System pity-floor requirement.

## Design Decisions Made This Session
- `BOSS_GRADE_BREAK_GUARANTEE` = 0.5 (was 1.0)
- Pool-size position: current ranges locked; Drop System must choose dilution model

## Session 1 Blocker Fixes (still valid — confirmed by Session 2 review)
1. AC-ED-14 computed TTK check (dmg=floor(A²/(A+D)), TTK=ceil(structure/dmg) per channel)
2. WILD_POWER_CAP 40→39
3. AC-ED-09 product invariant
4. Seven QA AC fixes (AC-05/06/07b/08b/13/14/16)
5. Harvest-decision rule AC-ED-15(c) BLOCKING
6. Open Questions 4–6 (OQ4/OQ5/OQ6)

## Hard Constraints Inherited by Downstream GDDs
- ED1 (Combat): enemy Heat/Energy resource symmetry decision
- ED2 (Part-Break): region targeting + damage accrual + break_event emission
- ED3 (Drop System): deduplicated event set collection
- ED4 (Enemy AI): ai_profile schema definition
- ED5 (Encounter Zone): spawn-disabled boss progression-integrity check
- OQ4 (Drop System): Boss-grade pity floor MUST be defined (BOSS_GRADE_BREAK_GUARANTEE=0.5,
  avg 2 attempts — worst-case tail must be bounded); Rare bad-luck protection position required
- OQ5 (Drop System): pool-dilution model choice HARD-BLOCKS Drop System design; three options
  given in OQ5; Part DB "3–5 attempts" framing must be reconciled
- OQ6 (Encounter Zone or content-lint): roster coverage lint (reverse coverage, slots/elements,
  part_family arcs)

## Open Recommended Items (not blocking, carry forward to next re-review)
9 QA AC fixture/documentation improvements:
- AC-ED-07(a): stale break_hp fixture (stored=30/derived=29)
- AC-ED-07(e): empty `break_regions: []` fixture
- AC-ED-07(d): float tolerance mechanism (parsed vs. computed path)
- AC-ED-03: output annotation requirement while skills BLOCKED
- AC-ED-04(f)/AC-ED-15(b): empty-pool suppresses size-range warning
- AC-ED-06(d): clarify "(a) runs against every WILD pool"
- AC-ED-05(b): upper boundary stat=110 fixture
- AC-ED-09: explicit multiplier fixture values + unblocking annotation
- EDB-1 implementation notes: epsilon over-correction proof

Also from Session 1 (still deferred):
- Asymmetric break_hp warning on shared break_events
- EDB-3 multiplier-meaningfulness check

## Next Steps
1. **/clear** — context at ~65-70% after 5-agent review
2. **/design-review design/gdd/enemy-database.md** — third pass (fresh session)
3. If approved: /design-system symbot-assembly — #4 in design order (Core, MVP)
4. Then Synergy System (#5), Turn-Based Combat (#6)

<!-- STATUS -->
Epic: MVP Foundation GDDs
Feature: Design pipeline
Task: Enemy Database re-review (fresh session — /clear first)
<!-- /STATUS -->
