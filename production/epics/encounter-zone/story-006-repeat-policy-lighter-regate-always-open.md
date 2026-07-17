# Story 006: Repeat policy — LIGHTER_REGATE delta re-gate & ALWAYS_OPEN

> **Epic**: Encounter Zone System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/encounter-zone.md`
**Requirement**: `TR-ez-005`, `TR-ez-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Turn-Based Combat State Machine & Battle Orchestrator
**ADR Decision Summary**: Post-first-defeat re-access is governed by `repeat_policy`, evaluated at the same battle-lifecycle boundaries as first-access. `LIGHTER_REGATE` measures a **delta** against a per-boss `wins_at_last_defeat` snapshot, not the raw never-resetting counter.

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: Pure comparison logic. The delta re-gate is `win_count − wins_at_last_defeat >= regate_params.required_wins`. Reading the raw cumulative counter instead would satisfy any re-gate the instant the boss first died (collapsing `LIGHTER_REGATE` into `ALWAYS_OPEN`) — AC-EZ-22 is the central discriminator that forbids this. `wins_at_last_defeat` is a per-boss snapshot taken on each defeat (owned/stored by Exploration Progress; read here through the injected interface).

**Control Manifest Rules (this layer)**:
- Required: pure core in `src/core/encounter_zone/`; progress state (counter + `defeated_once` + `wins_at_last_defeat`) read via injected interface.
- Forbidden: `push_warning`/`push_error` from `src/`; reading global singletons from core.
- Guardrail: `DEFEATED` is a genuine resting state — the delta re-gate must re-lock the boss at the moment of defeat (delta 0), never pass through.

---

## Acceptance Criteria

*From GDD `design/gdd/encounter-zone.md`, scoped to this story:*

- [ ] **AC-EZ-21** (BLOCKING, Unit): Boss 2 `LIGHTER_REGATE` **delta** re-gate at 3. GIVEN Boss 2, `defeated_once = true`, `wins_at_last_defeat = 10`, `regate_params.required_wins = 3`. `zone_win_count = 13` → delta 3 → `UNLOCKED`; `zone_win_count = 12` → delta 2 → `LOCKED`. Discriminator vs raw-counter: a raw impl returns `UNLOCKED` at `zone_win_count = 12` (`12 >= 3`) — assert `LOCKED`.
- [ ] **AC-EZ-22** (BLOCKING, Unit): re-gate **re-locks the boss at the moment of defeat** — the central delta-counter discriminator. GIVEN Boss 1 just defeated at `zone_win_count = 6` → `wins_at_last_defeat = 6`, `defeated_once = true`, `regate_params.required_wins = 2`, `zone_win_count` still `6` → delta 0 → `LOCKED`. Discriminator: BOTH the raw-counter bug (`6 >= 2`) AND an ignore-`defeated_once` first-access impl (`6 >= 6`) return UNLOCKED — assert `LOCKED`. Proves `LIGHTER_REGATE` does not collapse into `ALWAYS_OPEN`.
- [ ] **AC-EZ-23** (BLOCKING, Unit): re-gate met after banking the delta. GIVEN Boss 1, `defeated_once = true`, `wins_at_last_defeat = 6`, `regate_params.required_wins = 2`. `zone_win_count = 8` → delta 2 → `UNLOCKED`; `zone_win_count = 7` → delta 1 → `LOCKED`. The 7→LOCKED / 8→UNLOCKED boundary is the `>=` discriminator on the delta.
- [ ] **AC-EZ-39** (BLOCKING, Unit): re-access path gated on `defeated_once` *(verifies EC-EZ-09)*. **A (negative):** Boss 1, `defeated_once = false`, win_count 3, first-access 6, re-gate 2 → `LOCKED` (first-access applies; 3 < 6). With `wins_at_last_defeat` unset (0), win_count 3 PASSES the delta re-gate (`3 − 0 = 3 ≥ 2`) but FAILS first-access — an impl ignoring `defeated_once` returns UNLOCKED. **B (positive):** `defeated_once = false`, win_count 6, first-access 6 → `UNLOCKED` (an impl that never unlocks pre-defeat fails this).
- [ ] **AC-EZ-52** (BLOCKING, Unit): `repeat_policy = ALWAYS_OPEN`. GIVEN a boss with first-access `gate_type = WIN_COUNT`, `required_wins = 6`, `repeat_policy = ALWAYS_OPEN`, `defeated_once = true`, `win_count = 0` → `UNLOCKED` (permanently accessible after first clear). GIVEN the same boss `defeated_once = false`, `win_count = 0` → first-access gate still applies (`LOCKED`) — ALWAYS_OPEN only takes effect post-first-defeat.

---

## Implementation Notes

*Derived from ADR-0007 Implementation Guidelines:*

- Route gate evaluation through `defeated_once`: **false** → apply first-access (Story 005) regardless of `repeat_policy` (EC-EZ-09 / AC-EZ-39); **true** → apply `repeat_policy`.
- `LIGHTER_REGATE`: `UNLOCKED if (win_count − wins_at_last_defeat) >= regate_params.required_wins else LOCKED`. Use the delta, never the raw counter. `wins_at_last_defeat` is read from the injected progress interface (snapshotted per-boss on each defeat by Exploration Progress; this story does not own the snapshot write).
- `ALWAYS_OPEN`: once `defeated_once == true`, always `UNLOCKED` with no re-gate evaluation. Before first defeat, the first-access gate still applies (AC-EZ-52 Scenario B).
- Do not let the delta go negative in practice — the counter is monotonic and `wins_at_last_defeat` is a snapshot of it, so `win_count >= wins_at_last_defeat` always holds; delta 0 at the defeat instant is the resting-state case (AC-EZ-22).
- `FULL_REGATE` is reserved (Story 007 stubs its fail-safe/behavior note); this story implements only `LIGHTER_REGATE` and `ALWAYS_OPEN`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: first-access WIN_COUNT thresholds + sequencing (this story delegates to that for `defeated_once = false`).
- Story 007: `regate_params` **validation** (strictly-lighter-and-≥1, AC-EZ-25) and the reserved `FULL_REGATE` behavior stub (AC-EZ-53, DEFERRED). This story assumes valid regate params.
- **Deferred integration:** AC-EZ-44 (`defeated_once` + `wins_at_last_defeat` persist across save/reload) — epic deferred-integration note.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-EZ-21**: Boss 2 delta re-gate.
  - Given: Boss 2 `defeated_once = true`, `wins_at_last_defeat = 10`, `regate = 3`; `zone_win_count` = 13 then 12.
  - When: gate evaluated.
  - Then: UNLOCKED then LOCKED.
  - Edge cases: raw-counter impl unlocks at 12 — assert LOCKED.
- **AC-EZ-22**: re-lock at defeat.
  - Given: Boss 1 defeated at `zone_win_count = 6`, `wins_at_last_defeat = 6`, `regate = 2`, counter still 6.
  - When: gate evaluated.
  - Then: LOCKED (delta 0).
  - Edge cases: assert against BOTH the raw-counter and ignore-`defeated_once` impls.
- **AC-EZ-23**: delta banked.
  - Given: Boss 1 `wins_at_last_defeat = 6`, `regate = 2`; `zone_win_count` = 8 then 7.
  - When: gate evaluated.
  - Then: UNLOCKED then LOCKED.
- **AC-EZ-39**: `defeated_once` gating.
  - Given A: Boss 1 `defeated_once = false`, win_count 3, first-access 6, re-gate 2, `wins_at_last_defeat = 0`.
  - Then A: LOCKED (first-access path, not re-gate).
  - Given B: `defeated_once = false`, win_count 6, first-access 6.
  - Then B: UNLOCKED.
- **AC-EZ-52**: ALWAYS_OPEN.
  - Given A: WIN_COUNT `required_wins = 6`, ALWAYS_OPEN, `defeated_once = true`, win_count 0.
  - Then A: UNLOCKED.
  - Given B: same, `defeated_once = false`, win_count 0.
  - Then B: LOCKED.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/encounter_zone/repeat_policy_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (first-access verdict, delegated to for `defeated_once = false`).
- Unlocks: None.
