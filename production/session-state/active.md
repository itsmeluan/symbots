# Active Session State

## Current Task
Session 10: Synergy System GDD — /design-review re-review #4 complete (NEEDS REVISION → full-scope revision applied in-session). 6 blockers + 10 recommended items ALL resolved 2026-07-10. Ready for fresh-session re-review #5 (creative-director: high confidence APPROVED).

## Prior Completed
- Enemy Database GDD: APPROVED 2026-07-10 (Session 4)
- Part Database GDD: APPROVED (+ visual amendment 2026-07-10)
- Damage Formula GDD: APPROVED
- Symbot Assembly System GDD: APPROVED 2026-07-10 (Session 5)
- Synergy System GDD: In Review (revised four times — awaiting re-review #5)

## Key Design Decisions (Synergy — current state after re-review #4 revision)
- Bonus types: stat bonuses (flat integers) + passive combat effects (named StringName IDs)
- Thresholds: TIER1=3, TIER2=5, CUMULATIVE; combined synergies = independent counts, no co-location
- Registration order: ascending alphabetical by tier ID (governs dedup + emission order)
- **NEW: Requirements validity invariant** — requirements non-empty AND every min_count ≥ 1 (min_count=0 is vacuous-activation content error → skip + log; EC-SYN-13, AC-SYN-23)
- **NEW: null synergy_tags treated exactly as []** — null-guard mandatory (GDScript `for tag in null` errors); Part DB is invariant owner, Synergy guard is defensive only (EC-SYN-07 extended, AC-SYN-19)
- **NEW: Dual integer enforcement (user-approved)** — content validation rejects non-int stat_delta literals at load + SYN-F3 casts int() at aggregation ingest; independent of OQ-1 format choice
- **NEW: Rule 9 empty-return semantics** — consumers treat empty preview() return as "no change"; errors detected via log, never via return shape
- **NEW: DCO-7** — Workshop UI must hold stateful last_active_synergies set, diff before animating; debounce 100–200ms suggested (UI tuning). Rule 7 xref fixed to point here.
- **NEW: DCO-8** — Rule 8 freeze is a behavioral contract; Workshop System GDD must disable equip during battle (Synergy does not self-lock)
- **NEW: Cumulative budget constraint** — OQ-2 scope now includes 7-tier worst-case sum validation + future per-tier per-stat cap
- All 4 formulas now use Symbol/Type/Range variable tables (Range column on min_count = structural prevention)
- evaluate() always emits; evaluate_silent() for TBC battle-start; preview() strictly read-only
- 23 ACs (AC-SYN-01…23); 13 ECs (EC-SYN-01…13); every EC carries a "Verified by" AC reference (coverage ~90% direct, clears 80% standard)
- DCO-1…8 delegate UI/Workshop-System-scoped items downstream

## Revision History (Session 10 — 2026-07-10 — 6 blockers + 10 recommended resolved)
Blockers: (1) min_count≥1 invariant + EC-SYN-13 + AC-SYN-23; (2) null synergy_tags guard + AC-SYN-19-B; (3) dual int enforcement in Formulas + SYN-F3 int() cast; (4) AC-SYN-19 (EC-SYN-07 empty-tags, 3rd consecutive flag); (5) AC-SYN-13 Scenario B (preview deactivation — catches delta-approach bug); (6) AC-SYN-20 + Rule 9 empty-return sentence.
Recommended: DCO-7/DCO-8 added; dead Rule 7 xref fixed; formula variable tables; "stateless" wording corrected; worked-example fixture-divergence note; AC-SYN-14 note rewrite + shared-compute-core hint; AC-SYN-21 (dup tags), AC-SYN-22 (empty requirements); budget constraint in Tuning Knobs + OQ-2; Beat 2/3/4/5 dependency/intent annotations; Beat 3 binding in Visual/Audio; DCO-3/4 gesture-conflict warning; Verified-by refs on all ECs.

## CD Adjudications of Record (re-review #4)
- game-designer's APPROVED overruled (verdict must clear every domain)
- Upgrading prior-RECOMMENDED items on pass 4 = legitimate debt-calling, NOT goalpost-moving (guardrail: genuine correctness/standards defect deferred for scheduling)
- Prior blocked-on-OQ-1 deferral of float enforcement REVERSED — false dependency; enforcement point specifiable independent of format
- Systemic EC↔AC flag STRENGTHENS blocking case (known, endorsed, twice-deferred, cheap-to-fix)
- ux-designer's initial "7 open blockers" was stale agent memory predating the DCO section — reconciled to 1, demoted, fixed anyway

## Files Changed Session 10
- design/gdd/synergy-system.md (~30 edits: status, Beats 2–5, Rules 7/8/9, States wording, Formulas intro + all 4 variable tables + SYN-F2 invariant + SYN-F3 cast + worked-example note, EC-SYN-07 extension, EC-SYN-13 new, Verified-by refs on all ECs, Tuning Knobs budget constraint, Beat 3 binding, DCO intro + DCO-4 warning + DCO-7/8, AC preamble range, AC-SYN-13 Scenario B, AC-SYN-14 note, AC-SYN-19…23 new, OQ-2 scope)
- design/gdd/reviews/synergy-system-review-log.md (appended re-review #4 entry)

## Next Steps
1. /clear this session
2. /design-review design/gdd/synergy-system.md in fresh session — re-review #5 (CD: high confidence APPROVED; verify the 6 blocker fixes + spot-check the recommended batch)
3. After approval: /design-system turn-based-combat — #6 in design order
4. **BEFORE authoring turn-based-combat GDD**: action the GDD-template amendment (see systemic flag below) — CD directed this happen before the next GDD

## SYSTEMIC PROCESS FLAG — NOW ACTIONABLE (CD directive, re-review #4)
Amend the GDD standard (.claude/rules/design-docs.md + design/CLAUDE.md): every observable-outcome EC must reference a verifying AC (or state why none exists), and the /design-review completeness pass must run an EC↔AC cross-check. Three consecutive Synergy reviews vindicated this. Apply BEFORE authoring the Turn-Based Combat GDD.

<!-- STATUS -->
Epic: MVP Core GDDs
Feature: Synergy System GDD
Task: Awaiting /design-review (re-review #5 — 6 blockers + 10 recommended resolved; CD expects APPROVED)
<!-- /STATUS -->
