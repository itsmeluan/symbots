# Active Session State

## Current Task
Enemy Database GDD — REVIEWED (NEEDS REVISION) + all 6 blockers REVISED same session
- File: design/gdd/enemy-database.md — status "In Review" in systems-index
- Review log: design/gdd/reviews/enemy-database-review-log.md (first entry, 2026-07-09)
- Full /design-review: game-designer, systems-designer, economy-designer, qa-lead
  + creative-director synthesis. Verdict NEEDS REVISION (6 blocking / 6 recommended),
  scope L. CD: "structurally sound schema, bounded correctable defects."
- **Next: /design-review design/gdd/enemy-database.md re-review in a FRESH session
  (/clear first — user selected this)**. Re-review must verify the 6 blocker fixes
  below and read the review log.

## Blocker Fixes Applied (user decisions in parentheses)
1. AC-ED-14 → computed TTK check (chosen over static bands): dmg=floor(A_cal²/(A_cal+D)),
   ttk=ceil(structure/dmg), per defense channel; jointly bounds structure×defense.
   Bands: WILD-early TTK 2–4 / structure 60–88 (chosen over tighten-to-66);
   WILD-mid 3–5 / 90–160; BOSS 12–18 / 364–594 at reference D=30.
   Float-scanned: zero divergences — NO epsilon needed (division is correctly
   rounded; unlike EDB-1 which keeps its LOAD-BEARING +0.0001).
2. WILD_POWER_CAP 40 → 39 (chosen over Armor-floor invariant / prose-only):
   kills the one-shot at player Armor=0, structure=60 (58 < 60).
3. AC-ED-09 → product invariant: BASE_DROP_BOSS_GRADE × multiplier ≥
   BOSS_GRADE_BREAK_GUARANTEE (new knob, 1.0). ×500 cross-system boundary test in AC.
4. Seven qa-lead AC fixes (05 structure=1 positive; 06 count boundaries 1✓2✓3✗;
   07b Part DB {condition, multiplier} citation; 08b GUARD-ONLY label; 13 split
   a/b with FLAVOR_TEXT_MAX shared constant; 14 band-edge direction; 16 DF-1 citation).
5. Harvest-decision rule: WILD loot_pool.size() > break_regions.size() — BLOCKING
   AC-ED-15(c). Protects Pillar 2 from 1:1 region-part collapse.
6. Open Questions 4–6 added: OQ4 Drop System owns Boss-grade acquisition policy +
   bad-luck protection (must-address); OQ5 Drop System owns pool-dilution vs Part DB
   "3–5 attempts" reconciliation (blocking for Drop System sign-off); OQ6 roster-level
   coverage validation (Encounter Zone GDD or content-lint tool).
Also folded in: NULL_ELEMENT_MAX_WILD knob (1) + AC-ED-15(d); in-spec ranges 9–326;
knob-warning prose fixes; A=0/D=0 DF-1 note; Rustcrawler rebalance example 85→88.

## Deferred From This Review (Recommended, not blocking — revisit at re-review or later)
- Asymmetric break_hp warning when two regions share a break_event (farming trap)
- EDB-3 multiplier-meaningfulness check (×1.01 passes connectivity but is filler)
- qa-lead extra test cases: empty stats {}, reserved enemy_class ELITE fails,
  stale break_hp after structure rebalance
- game-designer venue-shifted items: boss-grade content depth (2–4 exclusives for
  5h) → MVP scope review; enemy stats not reverse-engineerable → already OQ1

## Previously This Session / Standing Context
- Part Database — Approved (Round 8); Damage Formula — Approved (Round 2)
- DF-1: max(DAMAGE_FLOOR, floor(A²/(A+D) × T × crit_mult + EPSILON))

## Hard Constraints Inherited by Downstream GDDs
- DB1 (Synergy): cross-tag manufacturer+element synergy thresholds required
- DB2 (Drop System): Prototype pity counter required
- DB3 (Part-Break): break probability + escalation mechanic required
- DB4 (Synergy): cross-element incentives keeping all 3 elements relevant
- DB5 (Drop System): scrap-sink; R7 recommends a quantitative floor (% of upgrade cost)
- DF1 (Move Database): per-move damage-type/element overrides live there, not Part DB
- DF2 (Combat UI): must read final_damage + type_mult from a single damage event
- DF3 (Enemy Database): core_element field — FULFILLED by Enemy DB Rule 4
- ED1 (Combat): enemy Heat/Energy resource symmetry decision
- ED2 (Part-Break): region targeting + damage accrual + break_event emission
- ED3 (Drop System): deduplicated event set collection
- ED4 (Enemy AI): ai_profile schema definition
- ED5 (Encounter Zone): spawn-disabled boss progression-integrity check
- EC-16 (Drop System): Boss-grade pity floor; R8 recommends visible progress signal
- NEW OQ4/OQ5 (Drop System): acquisition policy + pity; pool-dilution arithmetic
- NEW OQ6 (Encounter Zone or tooling): roster coverage lint (slots/elements/part_family)

## Open Recommended Items (Part Database Round 8 log — not blocking)
R4 (element distribution AC-24), R5 (unblock triggers AC-13/AC-15b), R6 (Core
identity → Assembly GDD), R7, R8, R9 (content density AC-25), flavor_text max
length (now: Enemy DB uses shared FLAVOR_TEXT_MAX=100 constant — Part DB should
adopt same constant), Boss-grade multi-stat spread AC, Open Questions stale
"[To be designed]".

## Next Steps
1. **/design-review design/gdd/enemy-database.md — re-review in fresh session (/clear first)**
2. If approved: /design-system symbot-assembly — #4 in design order (Core, MVP)
3. Then Synergy System (#5), Turn-Based Combat (#6)

<!-- STATUS -->
Epic: MVP Foundation GDDs
Feature: Design pipeline
Task: Enemy Database re-review (fresh session)
<!-- /STATUS -->
