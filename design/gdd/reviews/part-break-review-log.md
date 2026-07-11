# Part-Break System — Review Log

## Review — 2026-07-11 — Verdict: NEEDS REVISION (revised same session; pending fresh-session re-review)
Scope signal: L (cross-system errata surface: TBC routing/spillover/bias/enrage, Move DB break_bias, Drop System redefinition)
Specialists: game-designer, systems-designer, qa-lead, ux-designer, creative-director (senior synthesis)
Blocking items: 11 | Recommended: 5 (2 applied, 3 deferred as OQ/advisory)

Summary: Technically mature GDD (8/8 sections, all 13 EC↔AC cross-checks, python3-verified epsilon scan, BINDING Pillar-2 test AC-PB-28). Review surfaced no structural redesign — all fixes surgical. Key findings: (1) PB-F5 enrage calibration note was factually wrong — at the shipping value 0.15 a minimum-Structure glass cannon (60) is one-shot at full enrage, not "3–4 hits"; (2) seven AC-observability gaps where a plausible wrong implementation passes (AC-PB-05c, 09, 18, 21, 23, 24, 30); (3) Player Fantasy prose implied a per-build harvest penalty the system doesn't levy (BALANCED = 1.00/1.00 anchor); (4) no AC enforced the Combat-UI break-progress data contract; (5) UI-3 pre-SCAN information architecture undefined.

Adjudication (creative-director): REJECTED game-designer's proposed fix of moving BALANCED break_mult 1.00→0.80 (the anchor is load-bearing for the whole bias table). The defect is prose-vs-system: the harvest cost IS systemic (turns off the kill clock + enrage, guaranteed by AC-PB-28 for any bias) — fix the fantasy prose, keep the anchor. CD committed to APPROVE via fix-confirmation once the must-do items landed.

Revisions applied same session (2026-07-11):
- ENRAGE_PER_BREAK retuned 0.15 → 0.12 (user decision); cap +45% → +36%; epsilon re-scanned (now all-defensive); registry synced (PB-F5 entry + constant + last_updated). Honest calibration note replaces false claim; glass-cannon risk tied to OQ-PB-3.
- 7 qa-lead BLOCKING AC assertions hardened; new AC-PB-31 (Combat-UI data contract); AC count 30 → 31 (29 BLOCKING).
- Player Fantasy reframed (turns+enrage systemic cost; BALANCED = opportunity cost; anchor kept).
- UI-3 pre-SCAN = hidden-until-SCAN (user decision) + tutorial dependency caveat.
- Recommended applied: 2.0×-ratio absolute-floor companion rule; AC-PB-28 TBC-harness prerequisite.

Prior verdict resolved: First review. Re-review pending in a fresh session (fix-confirmation pass per CD commitment — not a full 5-agent sweep).

## Review — 2026-07-11 — Verdict: APPROVED (fix-confirmation re-review)
Scope signal: S (3 surgical prose/pointer fixes; no rule, formula, or architecture change)
Specialists: game-designer, systems-designer, qa-lead, ux-designer, creative-director (senior synthesis)
Blocking items: 3 (all fixed same session) | Recommended: 4 (punch-list, non-gating) | Deferred to Combat UI /ux-design: 7

Summary: Full 5-agent adversarial sweep (despite CD's "lighter pass" pre-commit — ran full to be safe). All 11 prior blockers verified fixed. systems-designer found zero blocking issues — all five formulas sound at every boundary, AC-PB-28's 2-vs-5-turn fixture independently reconfirmed. Re-sweep surfaced 13 new "blocking" claims; CD triaged to 3 genuine this-GDD fixes: (1) **phantom pity paragraph** — Player Fantasy ¶4 still described the dissolved DB3(b) break-failure pity mechanic (stale pre-dissolution artifact); rewrote as determinism + DAMAGE_FLOOR no-soft-lock guarantee; (2) **AC-PB-31 data contract** under-specified — named query signature + return struct, added breaking-hit element to break-event payload (VA-1's element-colored pop had no data source), added AC-PB-14 TBC-harness prerequisite; (3) **AC-PB-26** reclassified ADVISORY → Integration BLOCKING (break-key vocab mismatch = silent no-drop). CD's key adjudication: 6 of 7 ux "blockers" are Combat-UI *rendering* requirements, correctly deferred to Pre-Production /ux-design (Part-Break owns no UI); only VA-1's breaking-hit element (data Part-Break must expose) gated here.

Non-blocking punch-list (deferred): epsilon-scan note undercounts load-bearing cases (all multiples of 10, not 3 — formula correct); AC-PB-05 BALANCED spillover-floor coverage; AC-PB-19/24 precondition tightening; enrage_stacks == broken_region_count assertion.
Forward-dependency register (input to Combat UI /ux-design): UI-1 SE layout/spacing, UI-2 pip representation, UI-3 post-SCAN reflow + persistence-in-UI-Requirements, UI-4 effect representation + stack-0 state, UI-7 structure-vs-region hit feedback, VA-3 accessibility-doc citation, Mac keyboard/mouse sub-target nav.

Prior verdict resolved: Yes — NEEDS REVISION (2026-07-11) fully resolved; 11 original blockers verified fixed + 3 new surgical fixes applied. No re-review #3 (per CD pre-commitment).
