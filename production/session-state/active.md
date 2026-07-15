# Active Session State

<!-- STATUS -->
Epic: Pre-Production
Feature: Sprint Zero
Task: Break Foundation epics into stories
<!-- /STATUS -->

> **This file is a lean checkpoint, not a changelog.** Keep it small — current
> task, open threads, next decision. Full project history lives in `git log` and
> in the artifact files (ADRs in `docs/architecture/`, epics in `production/epics/`,
> GDDs in `design/gdd/`). Prior-session narrative archived in
> `production/session-state/archive-active-2026-07-15.md`.

## Current Task — Pre-Production Sprint Zero (updated 2026-07-15)

- **Stage**: Pre-Production. All 8 ADRs (0001–0008) Accepted. MVP scope frozen
  (`production/mvp-scope-freeze.md`). 6 Foundation epics defined in
  `production/epics/index.md`.
- **Part Database stories COMPLETE (2026-07-15)** — `/create-stories part-database`
  wrote **10 stories** (`part-database/story-001…010`), all Ready, all 25 TRs
  covered. Build order: 001 engine-spike gate (typed-dict `.tres` round-trip —
  MUST pass before content authoring) → 002 schema → 003 loader / 004 F2+F2b /
  006 F3 / 007 validator-scaffold → 005 F1 / 008+009 validator families →
  010 author content + CI. Scoping calls: 004/005 governed primarily by ADR-0005;
  AC-15a/15b + THERMAL +5 runtime heat are OUT (Drop/Assembly/Combat epics).
- **Next decision** (user chose "Stop here" 2026-07-15): resume with EITHER
  `/story-readiness production/epics/part-database/story-001-tres-typed-dict-roundtrip-spike.md`
  → `/dev-story` (recommended — the spike de-risks all 5 content DBs), OR
  `/create-stories move-database` (5 Foundation epics still unstoried), OR
  `/sprint-plan new` (Part-DB-only sprint for now).

## Session Extract — Story 001 spike ✅ PASSED (2026-07-15)

- **SPIKE RE-RUN & PASSED.** Ran directly in-session (not via subagent — the
  prior attempt's subagent died on `API Error: Usage credits`). Godot
  `4.7.stable.official.5b4e0cb0f` at `/Applications/Godot.app/Contents/MacOS/Godot`.
  Headless GUT (v9.6.1) via the CI command → **7/7 tests, 27 asserts, 0 fail.**
  - Result: `Dictionary[StringName, int]` `.tres` round-trip **holds on 4.7** —
    StringName keys do NOT degrade to String; int values stay int; typed
    `get_bonus() -> int` returns usable int; missing-key → 0; empty dict OK.
  - Verified on BOTH the committed editor-format fixture (load path) and a fresh
    `ResourceSaver.save` → reload round-trip.
  - **ADR-0003 verification gate item (2) CLOSED (PASS)** — no ADR amendment;
    typed schema stands. **Story 002 + all content authoring UNBLOCKED.**
  - Artifacts: `tests/unit/part_database/tres_typed_dict_roundtrip_test.gd`,
    `stat_bonuses_probe.{gd,tres}` (throwaway probe), finding note
    `production/epics/part-database/story-001-FINDING.md`. Story + EPIC marked Done.
- **Engine already re-pinned 4.6 → 4.7** (prior session): authoritative pins
  (`project.godot`, `VERSION.md`, `technical-preferences.md`, `CLAUDE.md`) updated.
- **STILL DEFERRED to `/architecture-review`**: 8 ADRs + architecture docs still
  say "4.6" — need engine-compat *re-validation*, not a label swap. Not swept.
- **Next**: Story 002 (PartDef schema + enums + PartCatalog) is now the gate-open
  next build step — `/dev-story story-002`. Or story the 5 remaining Foundation
  epics. Or `/sprint-plan`.

## Open Threads (not yet captured elsewhere)

- `design/ux/battle.md` still **Draft** → run `/ux-review battle`.
- Art bible **§8 Asset Standards** required before any scratch assets commissioned.
- **Faction-name sync** with narrative before faction concept art (§3.8 placeholders
  Smoothshell / Hardform / Wirework / Fluxform).
- **11 errata** tracked in `production/errata-backlog.md` + pending CD sign-off **OQ-CP-6**.
- 5 remaining Foundation epics (move / passive / consumable / enemy / damage-formula)
  are unstoried.
- Optional cleanup: refresh `docs/architecture/architecture.md` stale traceability block.
