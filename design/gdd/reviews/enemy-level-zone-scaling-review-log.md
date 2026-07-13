# Review Log — Enemy Level & Zone Scaling (#10c)

## Review — 2026-07-12 — Verdict: NEEDS REVISION
Scope signal: M
Specialists: systems-designer, game-designer, economy-designer, qa-lead, creative-director
Blocking items: 4 | Recommended: 3
Summary: GDD structure and formulas are sound (8/8 sections, 12 ECs all covered, discriminating ACs). The binding blocker was an economy cross-document integrity defect: DS-F-LEVEL reduces arc-average Rare throughput ~25%, invalidating the Approved Drop System's ~1,840-Scrap central economy model which was computed before DS-F-LEVEL existed. Supporting blockers: AC-ELZS-05(D) mis-cited EC-ELZS-06 for the empty-pool case (added EC-ELZS-12); no integration AC confirming DS-1 amendment is live in production code (added AC-ELZS-11); four Approved-doc errata had no closure gate (added errata pre-gate block). CD downgraded game-designer's three design-philosophy blockers to RECOMMENDED: zone-selection farming incentive is on-reference for MHW/PoE gradients and collapses to a legibility fix (drop-band signal routed to Combat UI GDD); HIGH-band Boss-2-exclusive is a single-zone MVP OQ (already in OQ-ELZS-1); DS-2/Prototype coupling is latent. All 7 fixes applied same session. Re-review required.
Prior verdict resolved: No — first review

## Review — 2026-07-12 — Verdict: NEEDS REVISION (revised same session; CD committed APPROVE on fix-confirmation)
Scope signal: M (fixes themselves S — surgical)
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 6 | Recommended: 4
Summary: Re-review found the prior session's economy fix was itself defective — the ~0.27 arc-average Rare figure had no derivation and was wrong-signed (economy-designer's reverse-engineering showed any plausible fight mix gives ~0.95 weighted mult, not 0.75); replaced with an explicit fight-distribution derivation (15/80/5 → ~0.34 Rares/victory, central ~1,800, mild-scarcity CONFIRMED). systems-designer caught a Tuning Knobs math error (1.667 Beacon-only threshold; correct = 2.0, verified against registry BEACON_MULTIPLIER=2.0). qa-lead landed 4 AC-integrity blockers: AC-11 EARLY-only integration fixture (+HIGH 0.5625), AC-05(D) empty-pool promoted to AC-ELZS-12, new EC/AC-ELZS-13 dangling enemy_id fail-safe, AC-02 anti-hardcoding BOSS L3→130 fixture. CD rejected game-designer's boss-XP-farming re-escalation on the facts (Encounter Zone Rule 9/8a delta re-gate caps refights) and ruled the UI min-bar demand disproportionate for a data-layer GDD (delegated with a normative minimum instead). All 6 blockers + 4 recommended applied same session. 12→13 ECs, 8→10 BLOCKING ACs. Fresh-session re-review required per CD's approve-on-fix-confirmation commitment.
Prior verdict resolved: Yes — all 7 prior fixes verified present; but the prior economy fix (0.27/1,660 annotation) was found underived and replaced.
