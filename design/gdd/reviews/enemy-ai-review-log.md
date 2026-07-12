# Enemy AI System — Review Log

## Review — 2026-07-12 (2nd, fresh session) — Verdict: NEEDS REVISION → APPROVED (fixed & fix-confirmed same session)
Scope signal: S (surgical)
Specialists: game-designer, systems-designer, ai-programmer, qa-lead, creative-director (senior)
Blocking items: 5 | Recommended: many (1 folded, rest carry-forward)
Summary: Fresh-session re-review **reopened the 1st-pass approval** — the adversarial panel found two confirmed *spec-wrong* gaps in the flagship kill-securing fix itself, both verifiable against source docs that existed at the time of the 1st approval. **(B1)** `df1_preview` previewed DF-1 alone, skipping **MOVE-F1** (the power-tier multiply TBC applies) — so the kill-securing invariant silently failed for any non-STANDARD move: TACTICAL would decline a SIGNATURE/HEAVY kill that was under-previewed by up to 40%. Fixed: `df1_preview = floor(DF-1 × power_mult + ε)`, range [1,225]→[1,315]; new Example D + AC-EAI-19 pin a HEAVY-tier (×1.20, 53→63) lethal-flip at H_cur=60. Both flagged findings were **independently verified by the main reviewer** (MOVE-F1 against move-database.md; the invariant math via python3). **(B2)** The invariant `w_lethal ≥ w_type + w_stat` holds only at STATUS_BASE_VALUE=1.0; corrected to `w_lethal ≥ w_type + w_stat · STATUS_BASE_VALUE` and the SBV safe range narrowed [0.5,2.0]→[0.5,1.5] (SBV>1.5 re-opened the exact Pillar-2 harvest exploit). Main reviewer corrected the systems-designer's derived ceiling (1.25→**1.5** — type_factor is not scaled by SBV). Three further blockers were GDScript-specific: **(B3)** RNG contract bound to an injected int seed + fresh per-call RandomNumberGenerator (was ambiguous "injected RNG"; Godot RNG algo changed 4.4–4.6); AC-EAI-06 now mandates pre-computed hard-coded seeds. **(B4)** AC-EAI-04 split into 4 independent guard sub-cases (conflated A=0/H_cur=1; energy path + A+D=0 divide were untested). **(B5)** AC-EAI-09 float phase-division (int/int truncated to 0, boundary test fired vacuously); AC-EAI-12 mandatory write-intercepting mock (shallow duplicate() shared nested Array refs).

CD synthesis: flagship kill-securing *decision* was right; its *specification* was incomplete on three counts (preview composition, invariant coefficient, and enforcement). Verdict NEEDS REVISION with commit-to-Approve on fix-confirmation. game-designer's two BLOCKING items (Player-Fantasy-overstates-adaptivity; invariant-flattens-harvest-tension) downgraded to RECOMMENDED prose — the kill-seeking decision *relocates* rather than removes Pillar-2 tension (to Part-Break/heal/escape timing). Of ~24 claimed-serious items across the panel, 5 were real blockers, and two of those were load-bearing (confirmed against source).

ACs: 18 → 19 (17 BLOCKING [14 Unit + 3 Content-Validation] / 1 ADVISORY / 1 DEFERRED). +AC-EAI-19 (MOVE-F1 lethal-flip). Registry synced (EAI-1 df1_preview [1,315] + MOVE-F1 composition + int-seed RNG; STATUS_BASE_VALUE range 0.5-1.5; AI_PROFILE_WEIGHTS invariant; MOVE-F1↔enemy-ai cross-refs), YAML validated. All 5 worked examples python3-verified.

Recommended, deferred (not applied this pass — user chose blockers-only): standing content-validation AC enforcing the invariant for ALL profiles (carry-forward 6, CD strongly endorsed — auto-catches B1/B2-class regressions); harvest-tension trade-off paragraph; Player-Fantasy honesty pass; per-status status_factor (OQ-EAI-1); OPPORTUNIST/AGGRESSIVE mid-fight differentiation; phase-shift legibility interface contract for Combat UI (VA-2 binding for bosses).

Prior verdict resolved: Yes — superseded the 1st-pass 2026-07-12 "Approved" (which shipped a silently-failing invariant).

---

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
