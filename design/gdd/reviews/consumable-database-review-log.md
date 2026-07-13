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

## Erratum — 2026-07-13 — ST-4 (Core Progression CP-F3 range) APPLIED — light re-review touch owed

Source: Symbot Core Progression 4th-pass `/design-review` (2026-07-13); systems-designer finding **F4** (BLOCKING), tracked as **ST-4** in `production/errata-backlog.md`.

**Problem:** CP-F3 CORE level-growth is additive on top of the SA-F1 part-derived combat-resource maxima. A level-10 Spark Core reaches `max_energy ≈ 147` / `max_structure ≈ 612`, but CD-1/CD-3 still declared the pre-CP-F3 ranges (`max_structure ∈ [60,594]`, `max_energy ∈ [80,120]`) and AC-CD-03's ceiling fixture used `max_energy=100`. **A hardcoded-120-ceiling implementation passed every BLOCKING CD test yet would clamp a leveled core's Power Cell at the wrong value in production** — a silent endgame runtime failure with no test coverage. (The CD-1/CD-3 `min()` clamps self-correct *if* the impl reads the runtime max; nothing tested that it does.)

**Changes applied (file-verified):**
1. CD-1 `max_structure` variable-table range `[60, 594]` → **`[60, 612]`** (annotated: part-derived floor 594 + up to +18 CP-F3 at L10).
2. CD-3 `max_energy` variable-table range `[80, 120]` → **`[80, 147]`** (annotated: part-derived ceiling 120 + up to +27 CP-F3 at L10).
3. Formulas-preamble CP-F3 note rewritten: the declared ranges are now the *runtime* maxima; points at AC-CD-03 case C as the guard; structure-side (+18/+3%) mirrored.
4. **AC-CD-03 case C added** (BLOCKING, Unit): `max_energy=147`, `current=130` → `min(147, 155) == 147`. Discriminator: a hardcoded-120 impl returns 120 ≠ 147 — the sole catch for the F4 bug. AC count unchanged (25 — a case on the existing AC, not a new AC).

**Owed:** a light `/design-review consumable-database.md` confirmation touch (mechanical erratum, no design change — Status stays APPROVED). Registry: no constant changed (max_structure/max_energy ceilings are SA-F1-derived runtime values, not registered constants); the `WORLD_SCRAP_CEILING`-style internal-only pattern does not apply here.

**Nice-to-have (deferred):** AC-CD-05 Case C explicit `qty==1` pre-condition + mutation confirm; AC-CD-19 promote to BLOCKING or add to smoke-check gate; AC-CD-03 add `current_energy=0` boundary + CD-4 Boss-grade Beacon (`0.001×2.0`) worked example; player-readable Jammer/Lure duration unit; Overview 6-vs-8 clarifying sentence.

Prior verdict resolved: First review
