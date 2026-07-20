# Move Database — Review Log

Revision history for `design/gdd/move-database.md`. Newest entries at the bottom.

## Review — 2026-07-10 — Verdict: NEEDS REVISION (4 blockers resolved same session)
Scope signal: S (single schema doc, one owned formula MOVE-F1, no new ADRs)
Mode: full `/design-review` — 5 agents
Specialists: systems-designer, game-designer, qa-lead, creative-director (senior synthesis)
Focus (user-requested): MOVE-F1 load-bearing epsilon citation · SIGNATURE 4→3 turn TTK rationale · TBC-F5 [1,315] errata coherence
Blocking items: 4 (all resolved this session) | Recommended: 6 | Nice-to-have: 4

### Blocking items and resolutions
1. **Stale errata header + OQ-MDB-3** [systems-designer] — GDD header (line 7) and OQ-MDB-3 claimed the TBC-F5/[1,315] errata were "unapplied (run /propagate-design-change)", but TBC header, TBC-F5 variable table, and registry (MOVE-F1, TBC-F5, DF-1) all showed them applied 2026-07-10. **Fixed:** header rewritten to "errata applied, verified against TBC + registry"; OQ-MDB-3 marked RESOLVED.
2. **False "Heat-gated" TTK rationale** [systems-designer, main-session script-verified] — the SIGNATURE 3-turn boss kill (261/hit vs structure 594) is real, but the "forcing Overheat at turn 2–3" justification is false: at heat_generation 30/35/40 the boss dies on turn 3 before any Overheat skip fires; at 30 the build never Overheats (peaks Heat 90). **Fixed:** rationale corrected — the kill is gated by the A=150 max-synergy requirement; Heat gates *repeated/sustained* SIGNATURE use, not this kill. TTK numbers (3/4/5 SIG/STANDARD/BASIC) were correct and unchanged.
3. **UTILITY defined by enumeration, not rule** [game-designer B-2] — behavior class defined only as "exactly Vent (MVP)". **Fixed:** Rule 2 now defines UTILITY by rule (affects only user's Heat/Energy; no damage, no enemy status, no reveal).
4. **AC-MDB-15 orphaned BLOCKING-DEFERRED** [qa-lead] — a BLOCKING gate with no tooling to run it = permanent CI false-red. **Fixed:** relabeled ADVISORY-DEFERRED, escalates to BLOCKING when the content-validation pipeline ships. AC summary count updated.

### Adjudicated disagreement
- **AC-MDB-05 distinguishability** — qa-lead flagged BLOCKING ("fixture gives 261 either way, can't catch mis-composed pipeline"). Main-session script verification refuted this: correct=261, power-as-A-boost=275, power-inside-DF-1-prefloor=262 — the fixture IS discriminating. Downgraded to RECOMMENDED (residual: assert the inspectable df1_output=187 intermediate). Creative-director concurred.

### Confirmed sound (focus areas)
- MOVE-F1 load-bearing epsilon citation internally consistent (10 cases / 1,125 inputs / 0 overcorrections) across GDD body, registry, and AC preamble. Not re-analyzed analytically per review scope — empirical scan is authoritative.
- [1,315] pipeline numerically coherent across TBC-F5 variable table, TBC ACs, registry TBC-F5/MOVE-F1/DF-1. Only the Move DB's own header was stale (blocker 1).

### Recommended (NOT applied — deferred to a follow-up pass)
- B-1: move-panel distinctness content-authoring rule (protects "the panel is the build speaking")
- AC-MDB-03 hardening (drive from full 10-input trap list + overcorrection guard, e.g. df1=229 STANDARD → 229 not 230)
- AC-MDB-05: assert inspectable df1_output=187 intermediate; add wider-divergence case
- AC-MDB-19/20: define unit-vs-integration test boundary; split AC-MDB-20 persist-clause (Move DB) from clear-at-battle-end (TBC)
- R-1: resolve "never SCAN the boss" equilibrium (full-turn cost highest where harvest info matters most)
- R-3: explicitly scope whether MVP ships status-rider passives, else Rule 5 silently removes status-applier builds until Passive DB exists

### Senior verdict [creative-director]
NEEDS REVISION — Scope S (fix-confirmation). A structurally sound Foundation schema one cleanup pass from approval, not a design needing rethink. Three true implementation gates (stale errata header = active landmine; false Heat-gate rationale = poisoned tuning basis; UTILITY-by-enumeration = incomplete schema) plus AC-MDB-15 CI-hygiene. All batchable in one sub-hour pass; a targeted fix-confirmation re-review then suffices — no full 5-agent re-review needed. Continues the Symbots pattern: specialists surface many BLOCKING tags, triage collapses to a few structural gates plus spec-hardening.

Prior verdict resolved: First review
Next: fix-confirmation re-review in a fresh session (`/clear` → `/design-review design/gdd/move-database.md`)

## Review — 2026-07-10 — Verdict: APPROVED
Scope signal: S
Mode: lean fix-confirmation — no specialist agents (per creative-director: targeted 4-fix check only)
Specialists: none
Blocking items: 0 | Recommended: 0
Summary: All 4 GDD fixes from the 2026-07-10 full review verified clean. One registry regression found and corrected: MOVE-F1 `notes` retained stale "(Heat-gated, ruled acceptable)" from before Fix 2 was applied to the GDD; updated to reflect the verified mechanism (A=150 max-synergy gated; Heat gates repeated/sustained use, not this kill). No design changes — factual note correction only. 6 deferred recommended items unchanged; none became blocking.
Prior verdict resolved: Yes
