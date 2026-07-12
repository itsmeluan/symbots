# Enemy AI System — Review Log

## Review — 2026-07-12 — Verdict: APPROVED (NEEDS REVISION → fixed same session)
Scope signal: M
Specialists: game-designer, systems-designer, ai-programmer, qa-lead, creative-director (senior)
Blocking items: 5 | Recommended: 6
Summary: Full-panel review of the stateless scored-heuristic Enemy AI. Core architecture (pure `request_move(battle_state)` function, seeded determinism, fail-safe AGGRESSIVE fallback) judged sound. Verdict NEEDS REVISION on five surgical blockers, all applied same session with the creative-director's "commit-to-Approve on fix-confirmation" ruling (no full re-review). Two judgment calls resolved toward pillar protection: (1) TACTICAL `w_lethal` raised 1.0→5.0 under a new kill-securing invariant `w_lethal ≥ w_type + w_stat` — the old 1.0 let TACTICAL decline securable kills to set up status, a Pillar-2 harvest exploit (bait low Structure, farm Part-Break turns) that also contradicted the "goes for the kill" Player Fantasy; (2) the low-Structure `damage_factor` saturation was kept (H_cur normalization) and documented as outcome-neutral (EC-EAI-10) rather than switched to max_structure, after arithmetic showed the collapse only affects mutually-lethal moves (identical outcome).

Blockers fixed:
1. Data-driven profile storage contract added to Rule 2 (`ai_profiles` Resource/.tres registry, no hardcoded weights).
2. AC-EAI-15 — DF-1 evaluated exactly once per move (call-count spy). Double-flagged by ai-programmer + qa-lead.
3. AC-EAI-16 — unit-level no-Heat/Energy cost filtering (complements DEFERRED integration AC-EAI-13).
4. AC-EAI-17 — content-validation rejects duplicate `phase_threshold` (Rule 6 "at most one").
5. EC-EAI-10 — low-Structure saturation documented as outcome-neutral.

Recommended applied: AC-EAI-18 (TACTICAL must carry ≥1 status move) + Tuning warning 6; EC-EAI-04 wording (≤ 0 incl. negative-distinct); AC-EAI-06 forced-tie + pre-selected seeds; AC-EAI-12 concrete triple + read-back; DF-1 purity + snapshot-timing notes in Interactions; OQ-EAI-3 resolved.

ACs: 14 → 18 (16 BLOCKING / 1 ADVISORY / 1 DEFERRED). All example arithmetic python3-verified (Example A unchanged; Example B TACTICAL now takes the kill X=6.0>Y=4.905; Example C reworked into a non-lethal reapplication-discount pick-flip at H_cur=80).

Errata applied on approval:
- Turn-Based Combat — AC-TBC-INT-02 un-deferred (contract `request_move` now defined); Enemy AI downstream rows → Approved.
- Enemy Database — AC-ED-01(d) referential check un-blocked via `EnemyAI.has_profile(id)`; ED4 discharged.
- Registry — `AI_PROFILE_WEIGHTS` (TACTICAL w_lethal 1.0→5.0) + `EAI-1` notes re-derived, YAML validated.

Deferred to future work (Nice-to-Have, not blocking): profile-identity legibility through Combat UI (Combat UI GDD); Part-Break → max_structure / phase-threshold interaction (log for TBC/Part-Break); OQ-EAI-3 remaining feel watch (phase-shift menace, TACTICAL setup feel) at playtest.

Prior verdict resolved: First review.
