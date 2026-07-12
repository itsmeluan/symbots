# Encounter Zone — Review Log

## Review — 2026-07-11 — Verdict: NEEDS REVISION (punch-list applied same session)
Scope signal: M (revision itself S)
Specialists: game-designer, systems-designer, economy-designer, level-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 4 | Recommended: 4 | Advisory: ~4
Prior verdict resolved: First review

**Key findings (panel raised 18+, CD resolved to 4 true blockers):**
- **B1 `wave_pools` undefined** (4 of 5 specialists) — WAVE `gate_params` referenced an undefined `wave_pools` field; blocked Boss 2 entirely and made AC-EZ-19/20/21 vacuous. CD verdict: **cut WAVE to Reserved** (off-pillar gauntlet fantasy + largest cost concentration) rather than spec it.
- **B2 WIN_COUNT semantic deferred** — OQ-EZ-5 punted "cumulative vs since-last-visit" to Exploration Progress, but Encounter Zone is the gating authority. Made normative.
- **B3 AC-EZ-25 mis-gated ADVISORY** — a MUST invariant (strictly-lighter regate) that breaks the harvest loop silently; must be BLOCKING.
- **B4 AC-EZ-40 fully deferred** — its no-crash provisional-fallback half is testable now and runs for the whole MVP dev period.

**Resolution (all applied same session):**
- WAVE → Reserved; Boss 2 → WIN_COUNT/10 on a **shared cumulative zone-win counter** (Boss 1 @ 6). Escalating-threshold arrival replaces the two-different-gates model.
- **Rule 8a** added (normative WIN_COUNT semantic: cumulative, all-time, zone-wide, never resets, wins-only). OQ-EZ-5 → RESOLVED.
- **Rule 2a** added (terrain identity-enemy + 20% weight-floor invariant) + AC-EZ-54 to enforce the targeting-lever promise.
- AC-EZ-25 → BLOCKING (+ regate=0 / regate≥first degenerate guards); AC-EZ-40 → 40a (BLOCKING now) / 40b (DEFERRED).
- AC discriminator fixes (03, 04, 15, 35, 39, 52) + new AC-EZ-53 (FULL_REGATE) / 55 (wins-only). 1.3×/1.6× ratio text fixed; EZ-2 pre-filter + defensive sentinel noted.
- Routed to OQs (not this read-only layer's to solve): OQ-EZ-6 (spatial tile/boss contracts → Zone & World Map), OQ-EZ-7 (enemy-terrain discovery UI → World Map UI), OQ-EZ-8 (inter-encounter HP recovery → Turn-Based Combat).

**AC count:** 52 → 56 (36 BLOCKING / 11 ADVISORY / 9 DEFERRED).

**Next:** fresh-session re-review (`/clear` → `/design-review design/gdd/encounter-zone.md`) to validate WAVE-cut consistency, shared-counter dual gate, Rule 2a/8a, and renumbered AC coverage before Approved.
