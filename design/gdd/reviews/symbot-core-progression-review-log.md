# Review Log — Symbot Core Progression (Leveling)

## Review — 2026-07-12 — Verdict: APPROVED (after revision)

Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, economy-designer, creative-director
Blocking items: 9 | Recommended: 13
Summary: The GDD's formula and AC layer was technically sound — CP-F1..F4 all correct; prior lean-mode qa-lead session had already addressed discriminating fixtures for most ACs. The blockers were structural: a direct Rule 2 vs EC-CP-02/AC-CP-03 contradiction on signal semantics (emit-per-threshold vs. emit-spanning), an unspecified core acquisition vector that left the bench XP system's balance premise unverifiable, a missing `register_core()` interface that made AC-CP-09 untestable, an undocumented `round()` derivation for the CP-F1 threshold table, and a non-discriminating even xp_value in AC-CP-06. The creative-director's verdict reframed the economy-designer's equip-gate concern: the binary gate is defensible pacing; the defect was the absence of bench-lead-cap legibility in the post-battle summary. All 9 blockers fixed same session. OQ-CP-7 (bench dead zone in single-zone MVP) added to Open Questions. Core acquisition established as Part drops + starter gift (drop_enabled=false).
Prior verdict resolved: N/A — first review
