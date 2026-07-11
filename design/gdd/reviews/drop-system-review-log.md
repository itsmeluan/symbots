# Review Log: Drop System

## Review — 2026-07-11 (fresh-session re-review, round 4) — Verdict: APPROVED (punch-list applied)
Scope signal: L
Specialists: economy-designer, game-designer, systems-designer, qa-lead, creative-director (senior synthesis)
Blocking items (as raised): 15 across 4 specialists → adjudicated by CD to 0 hard implementation-blockers + a 7-item non-blocking punch-list (all applied this session).
Summary: Mandatory fresh-session re-review of the prior NEEDS-REVISION fixes. All 9 prior blockers verified closed. New findings were a level deeper — AC discriminability, pseudocode completeness, and prose/number precision, no formula-math errors. The CD went to the file and overturned several "BLOCKING" specialist findings: QA F1 (AC-DS-03 already carries the `effective_drop_rate == 1.0` value assertion), QA F5 (EC-DS-09 forecloses the storage-rejection branch in MVP — unbounded inventory), and the Boss-grade-vs-Pillar-2 tension (an already-accepted design position, Rule 4 + OQ-DS-6). One genuine coverage hole survived → AC-DS-30 (DS-3 natural-drop reset, the DS-2/AC-DS-15 analog). Orchestrator independently verified in Python: pity off-by-one (true worst-case guarantee attempts 26/39/76, not 25/38/75), calibration figures (compliant floor 0.16875→0.99%, not 0.15→1.72%), economy band floor (1,556 not 1,600), and game-thirds derivation (~1,565, third-3 was overstated ~48%).
Punch-list applied (7): (1) DS-2 c=0 pseudocode completed with base-roll + conditional reset; (2) new AC-DS-30 (29 BLOCKING total); (3) partial-play attempts-to-guarantee corrected to `⌈N×C/c⌉+1` (39/76); (4) pity-calibration label fixed to floor-compliant 0.16875→0.99%; (5) economy band floor → ~1,556, mild-scarcity qualified across band; (6) game-thirds recomputed ~300/650/615 = ~1,565, reframed as the back-loaded ≈-floor scenario; (7) Rule 6 anti-exploit wording scoped to the part's own conditions.
CD directive: this is the third clean structural pass — **no fifth full re-review**; restrict any further work to fix-verifying the changed lines. Non-blocking follow-ups deferred to backlog: targeting_active semantic definition, AC-DS-29 second scenario should use c≥2, Phase-2 rarity-dispatch pseudocode note, AC-DS-28 minimum Save/Load interface, Part-Break provisional-vocabulary silent-fail risk.
Surfaced cross-GDD obligation (carried): Part DB should add a content-validation AC for the ≥×3.0 Prototype drop-condition floor (the DS-2 analog of AC-11).
Prior verdict resolved: Yes — all prior NEEDS-REVISION blockers closed and verified; stepped up to APPROVED.

## Review — 2026-07-11 (re-review) — Verdict: NEEDS REVISION (revisions applied; pending re-review)
Scope signal: L
Specialists: game-designer, economy-designer, systems-designer, qa-lead, creative-director
Blocking items: 9 | Recommended: ~12
Summary: Fresh-context re-review of the MAJOR-REVISION fixes. All 9 prior blockers verified closed; systems-designer independently verified all 11 numerical claims (zero arithmetic errors). New findings were a level deeper — design-experience and AC-discrimination, not math. Nine new blockers: (1) DS-2 all-or-nothing pity credit dead-ends partial-execution players against a hidden counter [game-designer]; (2) OQ-DS-6 break-on-defeat was an uncontracted gap to Not-Started Part-Break [game-designer]; (3) economy modeled only arc-total, not back-loaded early timing [economy-designer]; (4) Boss-grade 25% absorption implausible at 2-boss scope [economy-designer]; (5) States table implied roll-then-pity, contradicting pre-roll pseudocode [systems-designer + game-designer, triple-convergent]; (6) AC-DS-25 fixture ×1.4 below MULTIPLIER_FLOOR [qa-lead]; (7) AC-DS-26 non-discriminating vs omitted-pity [systems-designer]; (8) AC pity-interaction gaps — multi-guarantee stream, joint pity, output order, undefined "identical pity state" [qa-lead]; (9) AC-DS-19 vs scrap-yield range inversion [economy-designer].
CD directive on the central tension: hidden pity STAYS hidden (rejected the reveal asks) — the defect is the credit model, fixed with partial-credit-per-condition, not the UI.
Revisions applied this session (user chose "revise now"): DS-2 rebuilt as partial-credit (`pity_credit += c`, threshold `N_PROTO_PITY × C`; optimal play unchanged at 25 attempts); OQ-DS-6 accepted victory-only as final (user decision, no Part-Break obligation); Boss-grade → 0% absorption (faucet ~1,840) + game-thirds temporal sketch; States-table pity fold; AC-DS-25 → ×1.5; AC-DS-26 positive companion; AC-DS-10/24/21/18 multi-part coverage; new AC-DS-29 (partial-credit discriminator); scrap-yield ranges made non-overlapping + invariant note. AC count 27 → 28 BLOCKING.
Prior verdict resolved: Yes — all 9 prior (MAJOR) blockers closed and verified; this verdict is a step down to NEEDS REVISION.
Next: fresh-session re-review of these fixes (never same-session as revision); then /consistency-check (N_PROTO_PITY × C threshold, Boss-grade 0% absorption, scrap-yield ranges vs registry/Part DB/Enemy DB).

## Review — 2026-07-10 (re-review) — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 9 | Recommended: 7
Summary: Fresh-context re-review of the revised GDD. The mechanical core (independent per-condition rolls, Scrap "no drop is garbage" floor, dual convergence guarantee) is sound and aligns with Pillar 2 — failure is concentrated in the periphery. Nine blockers, converging independently across specialists:
(1) EC-DS-08 (duplicate pool IDs → independent trials) directly contradicts Approved Enemy DB EC-ED-08 (dedupe to unique IDs) — AC-DS-08 untestable until resolved; a DESIGN DECISION, not a wording fix.
(2) Economy arithmetic broken + internally self-contradictory: "avg 175 Scrap/part" only holds at exact 50/50 rarity mix (realistic mix → ~3,800–4,400 sink = 3.6× faucet); same paragraph states sink as both "~1,260–1,960" and "~1,050", and "~1,140 expected vs ~1,050 sink" implies surplus while claiming "mild scarcity". Needs from-scratch rederivation with stated absorption-rate assumption.
(3) MULTIPLIER_FLOOR obligation (Enemy DB ED3-OQ7 names Drop System as owner) absent entirely.
(4) Pity calibration claims wrong across legal range: N=25 "~0.9%" is ~1.72% at legal Prototype floor; DS-3 "~0.4%" assumes all Boss-grade use ×500 (unenforced; ×200 → ~16.8%). Need authoring rules.
(5) "+4/+5 wall (110+130)" numeric error (line 215) — tier +4 costs 80; wall framing inverted (130 < 160 doubling).
(6) AC-DS-25 FAIL clause has false arithmetic ("0.34 < 0.25") + doesn't enforce THIRD discriminator.
(7) AC test-spec defects: AC-DS-23 ghost value 0.225; AC-DS-09/17 redundant, orphan increment/reset paths; nominal 0→1 increment untested; AC-DS-13 misses post-roll pity-check bug; AC-DS-19 invariant is prose.
(8) AD-2 (pity persistence, self-labeled "release blocker") must be promoted to a numbered gated AC.
(9) Part DB line 696 stale "÷ pool_size" errata still not discharged (flagged prior review).
PROCESS FINDING (creative-director): three previously-flagged blockers (Part DB errata, economy assumption, AC discrimination) resurfaced un-discharged despite being marked "addressed" — a blocker is closed only when a specific line changed AND the change is verifiable against the file. Recommend revising in a fresh session (economy rederivation + 2 design decisions + cross-GDD errata).
Prior verdict resolved: No — prior NEEDS REVISION blockers partially un-discharged; re-review escalated to MAJOR REVISION.

## Review — 2026-07-10 — Verdict: NEEDS REVISION (revisions applied; pending re-review)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 4 | Recommended: 9
Summary: The resolution engine and pity systems are mechanically sound with a discriminating AC set. Four blockers addressed this session: (1) the deliberate-hunter Player Fantasy had no downstream legibility obligation — fixed by adding a full condition+multiplier display mandate and Boss-grade break label to UI Requirements; (2) the Scrap economy's "mild scarcity" claim rested on an unspecified Symbot count — fixed with an explicit 3-Symbot baseline assumption and OQ-DS-5; (3) Boss-grade 0.001 was described as "functionally zero" but is a legitimate persistence floor — now stated explicitly in Rule 4; (4) AC-DS-12 fixture was non-discriminating against pool-normalization bugs, and AD-1 conflated testable and deferred halves — fixed with draw 0.10 discriminator and new AC-DS-25 (BLOCKING). 27 BLOCKING ACs total after revision (up from ~24). Pending fresh-context re-review.
Prior verdict resolved: First review
