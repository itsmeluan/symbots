# Vertical Slice Report: Symbots — Harvest Loop

> **Date**: 2026-07-17
> **Slice Duration**: 1 day (Phases 4a–4d, single session)
> **Target Scope**: 3–5 minutes of polished, continuous gameplay
> **Source GDD**: design/gdd/game-concept.md

---

## Validation Question

Does a player, starting from a stock Symbot, break a specific enemy component,
harvest the part they targeted, re-equip it, and feel their build get stronger —
within ~3 minutes, unguided? And can we build one such loop at representative
quality on top of the existing pure core?

**Answer: YES on both axes.** (Evidence below.)

---

## Scope Built

A single interactive turn-based encounter (1 Symbot vs 1 Rustcrawler) driven by
touch, on top of the real `src/core` (BattleController, SymbotBuild, DropSystem,
StatPipeline) and real `.tres` content. Team-swap was cut. The overworld,
inventory, and multi-slot workshop were out of scope by design.

**Systems included (all real core, reused not reimplemented):**
- Turn-based combat resolution (`BattleController`) — submit action, synchronous round
- Part-Break targeting (ARM / HEAD / CORE) with per-region break HP
- Drop resolution (`DropSystem`) — authentic seeded RNG + gradient pity across rematches
- Stat pipeline + equip (`SymbotBuild.equip_part` / `preview_swap`)
- Reveal panel (PILHAGEM) and single-slot workshop (OFICINA) with live delta preview

**Art/audio quality level:** Placeholder (all-code Control UI, no art, no audio).
**Shortcuts taken deliberately:** basic_attack MoveDef synthesized (moves unauthored
in `src/`); Part-Break subscriber synthesized (unbuilt in `src/`); stock starter
loadout picked arbitrarily (first-common-per-slot).
**What was cut from scope:** overworld navigation, human player avatar, inventory
screen, team-swap, multi-slot workshop redesign, authored weapon skills.

---

## Build Velocity Log

| Day | Completed |
|-----|-----------|
| Day 1 (4a) | Headless harness — loop proven end-to-end on real core+content; balance retune of `rustcrawler.tres` (Finding 4). |
| Day 1 (4b) | Interactive battle screen (first interactive scene in the project) — all-code Control UI, signal-driven per ADR-0008, touch-first ≥56px; headless smoke-runner. |
| Day 1 (4c) | Drop-reveal panel (PILHAGEM) — authentic DropSystem RNG, pity survives rematches (RARE at fight 6); stale-target bug caught by smoke-runner + fixed. |
| Day 1 (4d) | Workshop (OFICINA) — equip + live `preview_swap` delta; signed-delta bug caught by equivalence assertion + fixed; **playtest-validated**. |
| Day 1 (4e) | Playtest debrief + 2 UX polish fixes (break-bar direction, target legibility) + REPORT. |

**Total elapsed:** 1 day for the full break→harvest→equip→feel-stronger loop.
**Velocity estimate:** ~0.25 day per UI screen at prototype quality *on top of an
already-built, tested pure core*. **Caveat:** this rate is not the production rate —
it excludes the core systems (already built over prior sessions), art, audio, the
overworld, and the real workshop redesign. Treat it as "UI-on-finished-core" velocity
only.

---

## Playtest Results

| Attribute | Value |
|-----------|-------|
| Total sessions | 2 (initial + post-polish re-feel) |
| Internal testers | 1 (Luan, solo dev) |
| External testers | 0 (solo dev — external testing recommended before full Production commit) |
| Avg session length | ~3 min (matches target) |
| Time to first meaningful action | "poucos segundos" (well under target) |

---

## Observations

**Where the tester succeeded without guidance:**
- Completed the full loop (enter → break arm → harvest → equip → fight stronger)
  unguided on the first session.
- First meaningful action within a few seconds of F6.
- Spontaneously described the intended overworld ("andar no mapa, encontrar um
  Symbot, terminar a batalha, navegar no inventário") and the human player avatar —
  matching `game-concept.md` ("You are a Symbot Mechanic") without having read it.
  Vision coherence signal: the design was guessable from a slice of it.

**Where the tester was confused (all UI, all out of slice scope — fixed or logged):**
- Target picker at the bottom (between own Symbot and ATTACK) read ambiguously —
  not obviously "aim at the enemy." **Fixed in 4e** (moved into enemy panel + ▶ marker).
- Break bar *grew* toward "broken" — counterintuitive; should deplete like the
  part's own HP. **Fixed in 4e** (now starts full, depletes).
- Wanted target selection directly on the enemy sprite / highlight on the enemy
  image. **Partially addressed** (▶ marker + brightened readout); full sprite-level
  targeting is a Production UI item.
- Workshop didn't feel like a workshop (envisions Symbot centered, tap slot → inventory
  opens, live skill/stat update). **Logged for Production** (deliberate redesign, not
  a slice fix).

**Emotional reactions observed (verbatim):**
- "hits ficaram mais fortes… me senti mais forte e não foi só sobre números. senti
  que meu esforço me recompensou."
- Post-polish: "bem melhor!" — target clarity, part-HP bar, and aim marker all
  confirmed working.
- Verdict rationale: "gostei da luta, de escolher o que quebrar para ter a chance de
  uma parte específica, equipá-la e ver meu symbot ficar mais forte." — the core
  fantasy, unprompted.

---

## Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| Time to first meaningful action | ~30 sec | few seconds ✓ |
| Session length | 3–5 min | ~3 min ✓ |
| Critical fun blockers found | 0 | 0 ✓ |
| Pipeline blockers found | 0 | 0 ✓ |
| Architecture surprises | 0 | 0 (core reused cleanly, zero changes to `src/core`) |

**Feel assessment:** The reward loop lands — breaking a specific part for a specific
drop, then feeling the equip (measured: +11 physical power, +3 structure from one
harvested arm). Two initial feel bugs (bar direction, target legibility) were the
only friction and were cheap to fix. No impact SFX / animation yet (out of scope).

---

## Recommendation: PROCEED

A solo tester, starting from a stock Symbot, completed the full
break→harvest→equip→feel-stronger loop unguided in ~3 minutes and independently
articulated the game's core fantasy ("escolher o que quebrar para ter a chance de
uma parte específica… ver meu symbot ficar mais forte"). The slice was built in a
single day by reusing the already-tested pure core with **zero** changes to
`src/core` and **zero** architecture surprises — strong evidence the ADR-0005/0007/0008
seams (stat pipeline, battle FSM, screen contracts) are correct for this game. The
remaining friction was entirely presentation-tier UI, out of slice scope, and either
fixed live or logged for Production.

---

## If Proceeding

**Production requirements (what must change from slice to production):**
- Author real MoveDefs / weapon skills (slice synthesized `basic_attack`; parts carry
  no `active_skill_id` — slice Finding 1).
- Promote the Part-Break subscriber to a real system (slice Finding 2).
- Author a real starter loadout (slice picks first-common-per-slot arbitrarily).
- Build the overworld + human player avatar (`Overworld Navigation` #16, "Not Started")
  — the tester expects it and it is already canonical in `game-concept.md`.
- Redesign the workshop as a real workshop (Symbot centered, tap-slot → inventory,
  live skill/stat update) — not the single-slot slice panel.
- Direct-on-sprite enemy part targeting once enemy art exists.
- Add **Symbot naming** at assembly (new design item surfaced by playtest — not yet
  in any GDD; belongs in the Workshop / identity design).

**Design decisions surfaced (for GDD backlog):**
- **Symbot naming** — player names the Symbot in the workshop (Pokémon-style bond).
  Not currently specified anywhere; recommend a short GDD note.
- **Drop-condition semantics (confirmed, document as intent):** `drop_conditions`
  are rate *multipliers*, not gates — a part can drop at its base rate even without
  its break firing; breaking a region only *boosts* the rate (MHW-authentic). The
  slice is faithful to this. This is a legitimate design choice, but it must be a
  *conscious* one: if the design intent is "this specific part ONLY from breaking
  this region," the current system cannot express a hard gate at the per-part level
  (base rate is per-rarity/global). Flag for a Drop System design confirmation before
  Production content authoring.

**Architecture adjustments needed:** none forced by the slice. The core seams held.

**Sprint velocity estimate based on slice data:** ~0.25 day per prototype-quality UI
screen *on a finished core*. Do NOT use this as the production rate — it excludes
core, art, audio, and the two large "Not Started" systems (Overworld, real Workshop).
Re-baseline velocity on the first real Production sprint.

**Performance targets:** Confirmed (60 fps / touch-first / 200 draw calls) — the
all-code Control UI is trivially within budget; no revision.

**Next steps:**
1. `/gate-check pre-production` — formally advance to Production.
2. `/create-epics layer:foundation` and `/create-epics layer:core`.
3. `/sprint-plan` — using this report's velocity data (with the caveat above).

---

## Lessons Learned

- **Assumption broken:** "single-part equip validates the build fantasy." It does
  NOT — the tester explicitly separated "senti mais forte" (validated) from "minha
  build ficou mais forte" (needs multi-slot synergy, effects, attack choice — out of
  scope). The slice validates the **reward loop**, not the **build-composition depth**.
  That depth is the #1 candidate for the next slice or the first Production stories.
- **Pipeline surprise (positive):** the pure core reused with zero changes and zero
  architecture surprises. The DI seams (injected RNG/LogSink, `preview_swap` reuse)
  paid off — the slice never had to reach into or modify `src/core`.
- **Two feel bugs the type-checker couldn't catch, the smoke-runner did:** stale
  target on rematch, and `preview_swap` returning a signed delta (not absolute stats).
  Both surfaced only via behavioral/equivalence assertions in the headless runner —
  reinforces the project's verification-driven discipline.
- **If run again:** invest a half-day in representative UI layout *up front*. The
  tester's Q4 note ("esperava algo mais polido agora") shows placeholder-but-well-
  positioned UI would have raised fantasy confidence earlier, before the polish pass.

---

> *Vertical slice code location: `prototypes/symbots-vertical-slice/`*
> *This code is reference material only. Production implementation is written from scratch.*
> *Never import or refactor this code into production.*
