# Review Log — Symbot Core Progression (Leveling)

## Review — 2026-07-12 — Verdict: APPROVED (after revision)

Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, economy-designer, creative-director
Blocking items: 9 | Recommended: 13
Summary: The GDD's formula and AC layer was technically sound — CP-F1..F4 all correct; prior lean-mode qa-lead session had already addressed discriminating fixtures for most ACs. The blockers were structural: a direct Rule 2 vs EC-CP-02/AC-CP-03 contradiction on signal semantics (emit-per-threshold vs. emit-spanning), an unspecified core acquisition vector that left the bench XP system's balance premise unverifiable, a missing `register_core()` interface that made AC-CP-09 untestable, an undocumented `round()` derivation for the CP-F1 threshold table, and a non-discriminating even xp_value in AC-CP-06. The creative-director's verdict reframed the economy-designer's equip-gate concern: the binary gate is defensible pacing; the defect was the absence of bench-lead-cap legibility in the post-battle summary. All 9 blockers fixed same session. OQ-CP-7 (bench dead zone in single-zone MVP) added to Open Questions. Core acquisition established as Part drops + starter gift (drop_enabled=false).
Prior verdict resolved: N/A — first review

## Review — 2026-07-13 — Verdict: NEEDS REVISION → revisions applied (re-review pending in fresh session)

Scope signal: M
Specialists: systems-designer, game-designer, qa-lead, economy-designer, creative-director
Blocking items: 5 | Recommended: 6
Summary: Re-review triggered by /review-all-gdds (2026-07-13) flipping the 2026-07-12 APPROVED verdict for C-2 (CP-F3 range breach) + D-2 (anti-grind invariant not testable). Full-panel re-review confirmed C-2 (energy_power growth pushed DF-1 input A to 168 > declared/scanned 150; also energy_capacity +27 breached the anti-grind ceiling and Consumable DB cited ranges) and surfaced new findings: an equip-frustration gap (economy-designer — Boss-grade/Prototype drops arrive N grind-battles before the equip level, denting Pillar 2) and the anti-grind invariant failing at same-rarity/type parity (game-designer). CD ruling: take Fix 1 (prohibit power stats from level_growth — Fix 2 would make leveling raise raw damage, the very treadmill anti-pillar #3 forbids); route the equip-frustration gap to Enemy Level & Zone Scaling as a blocking Pillar-2 calibration AC (all numbers gate on unset OQ-CP-1); state the invariant honestly (bounded-edge, not build-dominant-at-parity).
Revisions applied this session (all 5 blockers + 6 recommended):
- Fix 1: new Rule 6a forbids power stats in level_growth; Spark Core retuned (energy_power removed) → 54 pts; A stays ≤ 150, no DF-1 change/re-scan. Sibling range re-annotations applied to symbot-assembly.md (SA-F1 table) + consumable-database.md (CD-1/CD-3) — CORE growth is additive on top of part-derived ceilings (max_energy → ~147, max_structure → ~612); clamps self-correct, docs were stale only.
- D-2: new AC-CP-21 (checkable L4-build-beats-L8-raw comparison, 53 vs 8 dmg) + fixed all-Rare reference baseline table + anti-grind-invariant-log.md maintenance requirement. Invariant rewritten as bounded-edge.
- AC-CP-20 promoted ADVISORY → BLOCKING. New AC-CP-22 (BLOCKING) content-validation: no power stats + per-stat 25%-of-reference ceiling. New AC-CP-23 (BENCH_XP_SHARE epsilon assertion).
- AC-CP-17a/b + emit_count==0 on DEFEAT/FLED; AC-CP-18 unblock made a DoD item on the Assembly erratum; EC-CP-05 is_build_valid() owner assigned to TBC/Overworld Nav; CP-F4 ownership notation resolved (CP owns formula, ELZS calibrates); OQ-CP-8 equip-frustration gap logged → ELZS.
Owed obligations (gated elsewhere, NOT fixed here): cooling has no SA-F1 ceiling (Part DB/SA-F1); is_build_valid pre-battle check (TBC/Overworld Nav); OQ-CP-8 equip-frustration calibration (ELZS); OQ-CP-6 CD sign-off on anti-pillar revision STILL OPEN — must resolve before Level Backbone locks.
Prior verdict resolved: Partial — C-2 + D-2 addressed in-doc; fresh full re-review pending (user chose new session). systems-index #10b remains Needs Revision until re-review confirms.
