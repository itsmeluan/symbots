# Sprint 1 — 2026-07-17 to 2026-07-31

## Sprint Goal
Close the Core layer: implement the Encounter Zone and Drop System epics
(the last two storied Core systems), reaching the Pre-Production → Production gate.

## Capacity
- Total days: 10 (2-week sprint, solo dev + AI)
- Buffer (20%): 2 days reserved for unplanned work / rework from code review
- Available: 8 days

## Tasks

### Must Have (Critical Path) — the encounter→battle→drop loop, end to end
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| EZ-1 | Zone data model & EZ-1 encounter trigger (anchor) | /dev-story | 0.5 | None | AC-EZ-01/02/03/57/59 |
| EZ-2 | EZ-2 weighted enemy selection | /dev-story | 0.5 | EZ-1 | AC-EZ-04–09 |
| EZ-3 | Sub-pool validation & empty-pool sentinel | /dev-story | 0.5 | EZ-1 | AC-EZ-26–30/32/33 |
| EZ-4 | WILD/BOSS handoff to TBC (Integration) | /dev-story | 0.5 | EZ-2, EZ-3 | AC-EZ-15 |
| EZ-5 | Boss gate WIN_COUNT first-access & sequencing | /dev-story | 0.5 | EZ-1 | AC-EZ-16–20/40a/56/58 |
| DS-1 | DropSystem host, VICTORY trigger & DS-1 roll core (anchor) | /dev-story | 0.5 | None | AC-DS-03/04/05/11/20/27 |
| DS-2 | Condition assembly — match, stacking, unknown key | /dev-story | 0.5 | DS-1 | AC-DS-22/23/07/25 |
| DS-3 | Pool iteration — dedup, independent rolls, empty pool | /dev-story | 0.5 | DS-1 | AC-DS-12/08/06 |
| DS-4 | Prototype gradient pity (DS-2) | /dev-story | 0.5 | DS-1 | AC-DS-13/14/29/15 |
| DS-5 | Boss-grade floor pity (DS-3) | /dev-story | 0.5 | DS-1 | AC-DS-16/17/09/30/24/01/26 |
| DS-6 | Determinism — ID-order, stream-sync, reproducibility | /dev-story | 0.5 | DS-4, DS-5 | AC-DS-21/10/18/02 |

### Should Have — policy, injection, validation, content linters
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| EZ-6 | Repeat policy — LIGHTER_REGATE delta re-gate & ALWAYS_OPEN | /dev-story | 0.5 | EZ-5 | AC-EZ-21/22/23/39/52 |
| EZ-7 | Gate params validation & reserved-gate fail-safe | /dev-story | 0.5 | EZ-5 | AC-EZ-24/25/31/34–38 |
| EZ-8 | Content-validation linters | /dev-story | 0.5 | EZ-1 | AC-EZ-10–14/47–51/54 |
| DS-7 | Beacon (×2.0) & DS-F-LEVEL rate injection | /dev-story | 0.5 | DS-1, DS-5 | AC-DS-31 |
| DS-8 | Scrap yield & rarity-ordering invariant | /dev-story | 0.5 | DS-1 | AC-DS-19 |

### Nice to Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| — | (none — DS-9 is Blocked, see Risks; not workable this sprint) | — | — | — | — |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|--------------|
| (none — Sprint 1) | — | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| DS-9 (pity persistence, AC-DS-28 release-blocker) is Blocked on the Not-Started Save/Load system (ADR-0001) | High | High | Excluded from Sprint 1 work. Save/Load must be storied+built before ship; schedule it as the next epic. Track AC-DS-28 as an open release gate. |
| 16 stories in one sprint may overrun for a solo dev | Medium | Medium | Must Have (11) is the loop; Should Have (5) defers cleanly if velocity lags. 2-day buffer absorbs code-review rework. |
| EZ real zone `.tres` + DS content deferred (needs ~8-WILD roster + Art Bible terrain enum, OQ-EZ-1) | Medium | Low | Engine + linters built against fixtures now (mirrors Synergy-tier deferral); content pass is a later, non-blocking task. |
| Cross-system errata (AC-ED-11/16, AC-ED-12, AC-ELZS-11) surface during implementation | Medium | Low | Stubs already noted in each story's Out-of-Scope; wire when the owning system lands. |

## Dependencies on External Factors
- **Save/Load system (ADR-0001, Not Started)** blocks DS-9 and gates ship (AC-DS-28).
- Deferred content (zone `.tres`, WILD roster) awaits the Art Bible terrain enum (OQ-EZ-1) and faction names (PENDING).

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed (the encounter→battle→drop loop runs end to end)
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests (GUT green)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged (lean per-story `/code-review` → `/story-done`)

> **Scope check:** This sprint implements only stories already decomposed from the
> Encounter Zone and Drop System epics — no stories added beyond epic scope. If stories
> are added mid-sprint, run `/scope-check [epic]` before implementing them.

> ⚠️ **Blocked release gate:** DS-9 (AC-DS-28, pity-counter persistence) is a
> release-blocker gated on the Not-Started Save/Load system. It is intentionally **not**
> in this sprint's task tiers. Save/Load must be storied and built before ship.
```
