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

## Open Threads (not yet captured elsewhere)

- `design/ux/battle.md` still **Draft** → run `/ux-review battle`.
- Art bible **§8 Asset Standards** required before any scratch assets commissioned.
- **Faction-name sync** with narrative before faction concept art (§3.8 placeholders
  Smoothshell / Hardform / Wirework / Fluxform).
- **11 errata** tracked in `production/errata-backlog.md` + pending CD sign-off **OQ-CP-6**.
- 5 remaining Foundation epics (move / passive / consumable / enemy / damage-formula)
  are unstoried.
- Optional cleanup: refresh `docs/architecture/architecture.md` stale traceability block.
