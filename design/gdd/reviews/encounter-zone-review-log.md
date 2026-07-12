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

---

## Review — 2026-07-12 — Verdict: NEEDS REVISION (2nd round, punch-list applied same session)
Scope signal: S–M (revision itself S — docs/rules-layer, one schema field added)
Specialists: game-designer, systems-designer, economy-designer, level-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 3 | Recommended: 2 | Nice-to-have: ~6
Prior verdict resolved: Yes — all 4 prior blockers (WAVE cut, Rule 8a, AC-EZ-25 BLOCKING, AC-EZ-40 split) confirmed correctly fixed and internally consistent.

**Key findings (fresh-session panel; the WAVE→shared-counter revision introduced a latent defect):**
- **B1 (economy + systems, independent) — `LIGHTER_REGATE` collapsed into `ALWAYS_OPEN`.** The never-resetting shared counter is already ≥6 the instant a boss is defeated, so the re-gate (2/3) is permanently satisfied — re-access friction was zero and the regate knobs were tuning theater. AC-EZ-22/23 tested the logic correctly against a broken spec.
- **B2 (4 of 5 specialists, independent) — Rule 2a / AC-EZ-54B unenforceable.** The 20% farmable weight-floor referenced a "farmable/needed-part host" tag with no field in the `SpawnEntry` schema — no linter ground truth, no author signal.
- **B3 (game + level, independent) — Boss-1 bypass / simultaneous dual-unlock undesigned.** A player could reach win_count≥10 without fighting Boss 1 and unlock both at once, contradicting the sequential "deeper you go" fantasy. GDD was silent.
- **R (systems + qa, independent) — EC-EZ-07 citation error** (cited AC-EZ-36 for spurious params; correct is AC-EZ-35) and **zone-level `spawn_enabled` had no verifying AC** (EC-EZ-10 mis-cited AC-EZ-27).

**Resolution (all applied same session — user chose all three recommended options via AskUserQuestion):**
- **Delta re-gate** (B1): re-access = `win_count − wins_at_last_defeat >= regate_params.required_wins`, per-boss snapshot on each defeat. Rewrote Rule 6/8a/9 + state table + Exploration Progress storage contract + Tuning Knobs. AC-EZ-21/22/23 rewritten; AC-EZ-22 is the central discriminator (boss re-locks at moment of defeat, proving no ALWAYS_OPEN collapse). `DEFEATED` is now a genuine resting state (fixes systems-designer's pass-through concern).
- **`is_farmable_target: bool` on SpawnEntry** (B2): AC-EZ-54B queries the field (no Enemy DB errata — it's an authoring signal local to this system). Added AC-EZ-54 A2 (identity-enemy 10% weight floor) closing the token-exclusive loophole (game-designer).
- **`gate_params.requires_defeated` sequencing** (B3): Boss 2 requires win_count≥10 AND Boss 1 defeated_once. New AC-EZ-56; updated Rule 7/8/8a/11 + AC-EZ-19/20/49.
- EC-EZ-07 re-cited (AC-EZ-35 added); new AC-EZ-57 (zone-level spawn_enabled) + EC-EZ-10 re-cite; gate-eval timing pinned to battle_ended/approach (Rule 8, fixes mid-battle-unlock ambiguity); DENSE tuning flagged provisional on OQ-EZ-8; Tuning Knob warning 4 (required_wins × density coupling); AC-EZ-49 tilde hardened to `Boss2−Boss1 >= 3`; UI Req 3 sequencing + wins-only feedback obligations.

**AC count:** 56 → 58 (38 BLOCKING / 11 ADVISORY / 9 DEFERRED). Grep sweep = consistent.

**Next:** fresh-session confirmation re-review (`/clear` → `/design-review design/gdd/encounter-zone.md`) to validate the delta-counter semantics, sequencing precondition, `is_farmable_target`, and AC-EZ-21/22/23/56/57 before marking Approved.
