# Active Session State

## Current Task
Enemy Database GDD — COMPLETE (Designed — Pending Review)
- File: design/gdd/enemy-database.md — all 12 sections written
- Key decisions: HYBRID stat model (hand-authored stats, 11 canonical Part DB stat
  names, anatomy-linked loot via break_event validation — single drop pipeline);
  reserved tier field (always 1 in MVP); A/D stats hard-capped [0,110] (DF-1
  verified range); EDB-1 break_hp DERIVED not authored (epsilon nudge LOAD-BEARING,
  8 real cases, e.g. 180×0.35); boss TTK 12–18 turns / Structure 350–600
  (specialist-adjusted from 10–20); WILD_POWER_CAP=40; AC-ED-09 gating multiplier
  ≥1000 (guaranteed drop, not ≥500 boost)
- Specialists consulted: systems-designer (formulas), qa-lead (ACs — found 2
  blockers + 7 coverage gaps, all incorporated); CD-GDD-ALIGN skipped (lean)
- Hard constraints declared on downstream GDDs: ED1 (Combat: enemy resource
  symmetry), ED2 (Part-Break: region targeting), ED3 (Drop: dedup event set),
  ED4 (Enemy AI: profile schema), ED5 (Encounter Zone: progression integrity)
- Registry updated: EDB-1 formula + BREAK_HP_MIN constant added; DF-1 referenced_by
  extended
- Next: /design-review design/gdd/enemy-database.md in a FRESH session (/clear first)
- File: design/gdd/enemy-database.md

## Previously This Session
MVP Foundation formula GDDs — BOTH APPROVED (Part Database Round 8, Damage Formula Round 2)

## Session Outcome (2026-07-09, post-/clear review session)

- **Part Database — APPROVED (Round 8)**, lean re-review. 1 blocker found and
  resolved: Formula 5 Thermal Element Bonus was in the tier table but absent from
  the formula expression — resolved as runtime Combat System modifier:
  `skill_heat_generation = heat_generation + element_heat_bonus` (0 or +5 for
  THERMAL). R2 applied simultaneously (Overheat-triggering worked example).
- **Damage Formula System — APPROVED (Round 2)**, lean. Round 1 blocker: AC-DF-03
  cross-check said wrong binding gives 22; actual math is 26 (`1600/60 → floor 26`).
  4 recommended applied: GDScript int-division trap note, EC-03 guard narrowed to
  `A == 0 and D == 0`, EPSILON documented as defensive convention, EC-07 rounding
  note corrected (GDScript round(82.5)=83 — input IS discriminating).
- Round 2 verification: all 20 numeric assertions + exhaustive EPSILON scan
  confirmed via python3 (zero epsilon-changing inputs, A,D ∈ [0,110], T ∈
  {0.75,1.0,1.5}, crit ∈ {1.0,2.0}).

## Files Modified This Session
- design/gdd/part-database.md — Formula 5 rewrite, Overheat example, status → Approved (Round 8)
- design/gdd/damage-formula.md — AC-DF-03 fix + 4 recommended, status → Approved (Round 2)
- design/gdd/reviews/part-database-review-log.md — Round 8 entry prepended
- design/gdd/reviews/damage-formula-review-log.md — created (Rounds 1–2)
- design/gdd/systems-index.md — both → Approved; tracker: 2 reviewed / 2 approved

## Hard Constraints Inherited by Downstream GDDs
- DB1 (Synergy): cross-tag manufacturer+element synergy thresholds required
- DB2 (Drop System): Prototype pity counter required
- DB3 (Part-Break): break probability + escalation mechanic required
- DB4 (Synergy): cross-element incentives keeping all 3 elements relevant
- DB5 (Drop System): scrap-sink; R7 recommends a quantitative floor (% of upgrade cost)
- DF1 (Move Database): per-move damage-type/element overrides live there, not Part DB
- DF2 (Combat UI): must read final_damage + type_mult from a single damage event
- DF3 (Enemy Database): must expose `core_element` field
- EC-16 (Drop System): Boss-grade pity floor; R8 recommends visible progress signal

## Open Recommended Items (Part Database Round 8 log — not blocking)
R4 (element distribution AC-24), R5 (unblock triggers AC-13/AC-15b), R6 (Core
identity → Assembly GDD), R7, R8, R9 (content density AC-25), flavor_text max
length, Boss-grade multi-stat spread AC, Open Questions stale "[To be designed]".

## Next Steps
1. /design-system enemy-database — #3 in design order (Foundation, MVP; DF3 applies)
2. Optionally first: /consistency-check or /review-all-gdds across the 2 approved GDDs
3. Then Symbot Assembly (#4), Synergy System (#5)

<!-- STATUS -->
Epic: MVP Foundation GDDs
Feature: Design pipeline
Task: Enemy Database GDD next
<!-- /STATUS -->
