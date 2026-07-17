# Story 007: Gate params validation & reserved-gate fail-safe

> **Epic**: Encounter Zone System
> **Status**: Done
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/encounter-zone.md`
**Requirement**: `TR-ez-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Turn-Based Combat State Machine & Battle Orchestrator (primary); ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: Gate parameters are validated before evaluation; any missing required key, wrong-class boss slot, reserved gate type, or non-strictly-lighter regate is a content fault that defaults the boss to `LOCKED` (fail-safe, never fail-open) with a LogSink diagnostic.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: Pure validation logic over injected `BossEncounter` data. Every fault path defaults `LOCKED` — the single invariant across all these ACs. `OPEN` is the one gate type needing no params (spurious params → warning + ignore, not error). Reserved gate types (WAVE/REACH/DUNGEON_RUSH) have live enum values but are not activatable in MVP → error + LOCKED.

**Control Manifest Rules (this layer)**:
- Required: pure core in `src/core/encounter_zone/`; diagnostics via LogSink `warn(code, detail)` with severity; content defs read-only.
- Forbidden: `push_warning`/`push_error` from `src/`; content-enum reordering; content-def mutation.
- Guardrail: fail-safe `LOCKED` on every fault; never fall through to accessible.

---

## Acceptance Criteria

*From GDD `design/gdd/encounter-zone.md`, scoped to this story:*

- [x] **AC-EZ-34** (BLOCKING, Unit): WIN_COUNT missing `required_wins` *(verifies EC-EZ-07)*. `gate_params = {}` → error naming boss + missing key, boss `LOCKED`, never offerable. A `required_wins=0` default would wrongly open it — this catches that.
- [x] **AC-EZ-35** (BLOCKING, Unit): OPEN with spurious params. GIVEN `gate_type = OPEN`, `gate_params = { required_wins: 3 }`, THEN evaluates `UNLOCKED` (params ignored, NOT interpreted as a WIN_COUNT gate) with a content **warning** (not error). Discriminator: an impl reading `required_wins` off any gate would LOCK this below 3 — assert `UNLOCKED`.
- [x] **AC-EZ-36** (BLOCKING, Unit): OPEN with empty `gate_params` is valid — no error, no warning, evaluates `UNLOCKED` immediately.
- [x] **AC-EZ-37** (BLOCKING, Unit): `REACH` in MVP → content error naming boss + gate_type, `LOCKED` *(verifies EC-EZ-08)*.
- [x] **AC-EZ-38** (BLOCKING, Unit): `DUNGEON_RUSH` in MVP → content error, `LOCKED`.
- [x] **AC-EZ-24** (BLOCKING, Unit): reserved `WAVE` gate is fail-safe *(verifies EC-EZ-08 — WAVE variant)*. GIVEN a boss authored `gate_type = WAVE`, THEN content error naming boss + gate_type, boss `LOCKED` and unofferable (no crash, no fall-through to OPEN).
- [x] **AC-EZ-31** (BLOCKING, Unit): WILD in boss slot → boss `LOCKED`. `boss_id = "iron_crawler"` (WILD) → error logged, boss entry excluded, `LOCKED` (fail-safe, not OPEN).
- [x] **AC-EZ-25** (BLOCKING, Content Val): re-access strictly lighter **and ≥ 1**. **A:** `regate_params.required_wins >= gate_params.required_wins` (e.g. Boss 1 regate 6 vs first-access 6) → content error naming boss + both values (degenerates to `FULL_REGATE`). **B:** `regate_params.required_wins == 0` → content error (degenerates to `ALWAYS_OPEN`). **C:** valid defaults (Boss 1 `1 ≤ 2 < 6`, Boss 2 `1 ≤ 3 < 10`) → no error.

---

## Implementation Notes

*Derived from ADR-0007 + ADR-0003 Implementation Guidelines:*

- Add a `validate_gate(boss_encounter) -> (ok, GateState_on_fault)` pass that runs before evaluation. Every fault returns `LOCKED` + a LogSink diagnostic; none fall through to accessible.
- WIN_COUNT with no `required_wins` key → error naming boss + missing key, `LOCKED` (AC-EZ-34). Do NOT default the missing key to 0 (that would open the boss).
- OPEN: empty params → valid, `UNLOCKED`, silent (AC-EZ-36); spurious params → `UNLOCKED` + **warning** (AC-EZ-35). Never interpret OPEN's params as a WIN_COUNT threshold.
- Reserved gate types (`WAVE`, `REACH`, `DUNGEON_RUSH`) → error naming boss + gate_type, `LOCKED` (AC-EZ-24/37/38). The enum values exist but are not fulfillable in MVP.
- WILD-class `enemy_id` in a `boss_encounters` slot → error, boss excluded, `LOCKED` (AC-EZ-31). This is the boss-slot half of the class check (the terrain-slot half is Story 003 / AC-EZ-30).
- `regate_params` validation (AC-EZ-25): error if `regate >= gate_params.required_wins` (not strictly lighter) or `regate == 0`; valid when `1 <= regate < first-access`. Surface both values in the diagnostic. This is a content-validation check but co-located here with the other gate-param faults.
- Reserved `FULL_REGATE` behavior (AC-EZ-53, DEFERRED) — leave a stub note; no MVP content authors it. When authored, `FULL_REGATE` re-applies the full first-access gate each cycle.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: valid WIN_COUNT threshold evaluation + sequencing (this story guards the *inputs* to that).
- Story 006: valid `LIGHTER_REGATE`/`ALWAYS_OPEN` evaluation (this story validates the regate *params*, AC-EZ-25).
- Story 003: BOSS-in-terrain-pool exclusion (AC-EZ-30) — the mirror-image class check.
- **Deferred:** AC-EZ-53 (`FULL_REGATE` reserved behavior) — stub only; activate when FULL_REGATE content ships (epic deferred note).

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-EZ-34**: WIN_COUNT missing key.
  - Given: WIN_COUNT boss, `gate_params = {}`; spy LogSink.
  - Then: error names boss + missing key; `LOCKED`. Assert not opened by a 0-default.
- **AC-EZ-35 / 36**: OPEN params.
  - Given: OPEN boss with `{ required_wins: 3 }` (A) and `{}` (B).
  - Then: A → `UNLOCKED` + warning; B → `UNLOCKED`, no diagnostic.
  - Edge cases: A must not LOCK below 3.
- **AC-EZ-37 / 38 / 24**: reserved gate types.
  - Given: bosses authored `REACH` / `DUNGEON_RUSH` / `WAVE`.
  - Then: each → content error naming boss + gate_type; `LOCKED`; no crash, no OPEN fall-through.
- **AC-EZ-31**: WILD in boss slot.
  - Given: `boss_id = "iron_crawler"` (WILD in stub DB); spy LogSink.
  - Then: error logged; boss excluded; `LOCKED` (not OPEN).
- **AC-EZ-25**: regate validity (content linter).
  - Given A: regate 6, first-access 6.
  - Then A: error naming boss + both values.
  - Given B: regate 0.
  - Then B: error.
  - Given C: Boss 1 `1 ≤ 2 < 6`, Boss 2 `1 ≤ 3 < 10`.
  - Then C: no error.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/encounter_zone/gate_params_validation_test.gd` — must exist and pass.

**Status**: [x] Complete — `tests/unit/encounter_zone/gate_params_validation_test.gd`, 10 tests, all green (GUT 9.7.1, Godot 4.7.stable). Covers AC-EZ-34 (missing required_wins → fail-safe LOCKED, not a 0-default open), AC-EZ-35/36 (OPEN spurious→UNLOCKED+warning / empty→UNLOCKED silent), AC-EZ-37/38/24 (reserved REACH/DUNGEON_RUSH/WAVE → error+LOCKED), AC-EZ-31 (WILD-class enemy in boss slot → error+LOCKED via injected Enemy-DB), AC-EZ-25 (regate strictly-lighter-and-≥1 linter: A too-heavy / B zero / C valid).

---

## Completion Notes (2026-07-17)

- Added `EncounterResolver.validate_gate(boss) -> bool` as a guard clause at the top of `evaluate_boss_gate`: a `false` return short-circuits to fail-safe `LOCKED` *before* any threshold logic runs. This makes the `required_wins`-default-to-0 in `_evaluate_win_count_gate` unreachable for the missing-key case (AC-EZ-34) — the guard catches it first, so a WIN_COUNT gate with `gate_params = {}` can never be wrongly opened by a 0-default.
- **Severity is spec-load-bearing.** OPEN + spurious params → `ez_open_spurious_params` **warning** + still `UNLOCKED` (AC-EZ-35); OPEN + empty params → `UNLOCKED`, silent (AC-EZ-36); missing required key, reserved gate type, and WILD-in-boss-slot → **error** + `LOCKED`. Collapsing these to one severity would either false-alarm on harmless junk or hide real faults.
- Reserved gate types (`WAVE`/`REACH`/`DUNGEON_RUSH`) and `INVALID` fall to the `match` default arm → `ez_gate_type_reserved` error + `LOCKED` (AC-EZ-24/37/38); the enum values are live but not fulfillable in MVP.
- WILD-in-boss-slot (AC-EZ-31) checked first, via the injected Enemy-DB reader (`_enemy_db.get_enemy(boss_id).enemy_class == WILD` → `ez_boss_slot_wild_class` error + `LOCKED`). The check is skipped when no Enemy-DB is injected — this is why the EZ-5/EZ-6 gate tests (constructed without an Enemy-DB) are unaffected. This is the boss-slot mirror of Story 003's terrain-slot class check (AC-EZ-30).
- `validate_regate_params(boss) -> bool` is a **separate** content linter (AC-EZ-25), tested directly and NOT wired into `evaluate_boss_gate` — a repeat-param typo flags at author time (`ez_regate_not_lighter` error naming both values) without locking a boss on first access. Valid iff `1 <= regate_required < gate_required`; `regate < 1` (→ ALWAYS_OPEN) or `regate >= first-access` (→ FULL_REGATE) are content faults.
- `FULL_REGATE` reserved behavior (AC-EZ-53) stays **DEFERRED** — stub note only; no MVP content authors it.
- No new global `class_name` (methods on the existing resolver + a new `_test.gd`). The regressions held: EZ-5's `test_ez5_absent_progress_leaves_open_gate_unlocked` (OPEN + empty params → silent) and every EZ-6 WIN_COUNT case pass `validate_gate` unchanged. Full suite rose by exactly **+10 to 848 tests / 4553 asserts**, all green (EZ dir 37→47).

---

## Dependencies

- Depends on: Story 005 (evaluation this validation guards) + Story 001 (`BossEncounter` shapes + injected Enemy-DB reader for the class check).
- Unlocks: None.
