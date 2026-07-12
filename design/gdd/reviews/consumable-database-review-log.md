# Consumable Database — Review Log

## Review — 2026-07-12 — Verdict: APPROVED (NEEDS REVISION → fixed same session)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior synthesis) + empirical python3 float scan
Blocking items: 5 | Recommended: 3 (converged: 2)

**Summary:** First full-panel review of the 8-entry / 6-concept Consumable Database (12th MVP GDD; all 11 prior Approved). Completeness 8/8, every EC cites a verifying AC, dependency graph clean (TBC/Drop/Encounter Zone Approved; downstream Not-Started systems correctly flagged provisional). Schema and all 5 formulas (CD-1…5) sound. Verdict NEEDS REVISION on 5 surgical blockers — all resolved and verified at file level the same session (CD committed APPROVE on fix-confirmation).

**Specialist disagreement resolved (IEEE-754):** systems-designer flagged AC-CD-09 (`0.15×0.1`) and AC-CD-10 (`0.35×2.5`) as BLOCKING, claiming the exact-equality assertions would fail on inexact float products. **Refuted** by a python3 IEEE-754 scan (`0.15*0.1==0.015` True; `0.35*2.5==0.875` True; `0.15*2.5==0.375` True) and independently corroborated by qa-lead at bit level. The GDD's IEEE-754 note is correct; ACs unchanged. Lesson: specialists err in both directions on float exactness — empirical scan is authoritative (see project float-epsilon-empirics).

**5 blockers fixed:**
1. Rule 3 / EC-CD-01 contradiction — rejection is now an explicit pre-action gate: turn NOT consumed, item NOT decremented (design decision: no turn on rejection).
2. AC-CD-14 was BLOCKING Unit but had no named owner for `steps_remaining` — named `EncounterModifierState` (sole mutator `on_overworld_step()`, no battle handler → structural freeze); States section aligned; live battle-freeze delegated to AC-CD-22 (DEFERRED).
3. AC-CD-12 (Beacon on flee) had no quantity assertion — added `beacon_qty==0` (flee-refund bug now caught).
4. No BLOCKING unit AC for Rule 3 "no Heat, no Energy" — added AC-CD-25 (stub-testable). 24→25 ACs (19 BLOCKING / 2 ADVISORY / 4 DEFERRED).
5. CD-2 Coolant Flush + Overheat timing unspecified — resolved **preventive-only** (design decision): an already-Overheated Symbot eats its Rule 4 skip; item action gets no carve-out ahead of the Overheat gate. Bound as a note on the TBC erratum.

**3 RECOMMENDED (carry into errata work):** (a) encounter-modifier "latest wins" lets a COMMON Lure silently consume an active RARE Jammer — game-designer + economy-designer converged; consider rejection-with-confirm, bind chosen behavior into the Encounter Zone erratum. (b) Beacon spend-on-flee needs explicit intended-tension framing in Player Fantasy — game-designer + economy-designer converged; bind into TBC/Drop errata. (c) "Beacon self-replenishes ~2:1" claim is contingent on the unset Drop System consumable drop frequencies (OQ-CD-2) — restate the ×3.0 break threshold in terms of Beacon's share of the RARE pool.

**Nice-to-have (deferred):** AC-CD-05 Case C explicit `qty==1` pre-condition + mutation confirm; AC-CD-19 promote to BLOCKING or add to smoke-check gate; AC-CD-03 add `current_energy=0` boundary + CD-4 Boss-grade Beacon (`0.001×2.0`) worked example; player-readable Jammer/Lure duration unit; Overview 6-vs-8 clarifying sentence.

Prior verdict resolved: First review
