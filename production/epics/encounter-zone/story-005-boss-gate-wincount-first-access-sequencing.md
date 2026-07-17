# Story 005: Boss gate WIN_COUNT first-access & sequencing

> **Epic**: Encounter Zone System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/encounter-zone.md`
**Requirement**: `TR-ez-004`, `TR-ez-005`, `TR-ez-006`, `TR-ez-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Turn-Based Combat State Machine & Battle Orchestrator (primary); ADR-0002: Event Bus & Signal Architecture
**ADR Decision Summary**: Gate re-evaluation is bounded to battle-lifecycle boundaries (`encounter_resolved` + boss-approach query) — never mid-battle. The gate reads persistent progress (win counter, `defeated_once`) through an injected interface and produces a `LOCKED`/`UNLOCKED` verdict.

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: Pure comparison logic against injected progress state — no live scene. The shared `zone_win_count` is read by every WIN_COUNT boss at its own `required_wins` threshold with a `>=` test (a `> N` impl stays LOCKED at exactly N — the AC-EZ-17/19 discriminator). Boss 2's `requires_defeated` sequencing AND-gates the win threshold with the prerequisite boss's `defeated_once` flag. A dangling `requires_defeated` reference is fail-safe LOCKED, never fail-open.

**Control Manifest Rules (this layer)**:
- Required: pure core in `src/core/encounter_zone/`; progress state read via injected interface; diagnostics via LogSink.
- Forbidden: `push_warning`/`push_error` from `src/`; reading global singletons from core; content-def mutation.
- Guardrail: fail-safe default is `LOCKED` — any missing/unresolvable input LOCKS, never falls through to accessible.

---

## Acceptance Criteria

*From GDD `design/gdd/encounter-zone.md`, scoped to this story:*

*Both bosses read one shared `zone_win_count` (Rule 8a) at their own `required_wins` threshold.*

- [ ] **AC-EZ-16** (BLOCKING, Unit): Boss 1 — 5 wins = `LOCKED`. GIVEN `zone_win_count = 5`, `defeated_once = false`, THEN `LOCKED`.
- [ ] **AC-EZ-17** (BLOCKING, Unit): Boss 1 — exactly 6 wins = `UNLOCKED` (`>=` discriminator). A `> 6` impl stays LOCKED; assert `UNLOCKED`.
- [ ] **AC-EZ-18** (BLOCKING, Unit): Boss 1 — 7 wins = `UNLOCKED` (no upper-bound "window" regression).
- [ ] **AC-EZ-19** (BLOCKING, Unit): Boss 2 — threshold at 10 (sequencing precondition satisfied). GIVEN Boss 1 `defeated_once = true`, `zone_win_count = 9` → Boss 2 `LOCKED`; same with `zone_win_count = 10` → Boss 2 `UNLOCKED` (`>= 10` discriminator — a `> 10` impl stays LOCKED at 10).
- [ ] **AC-EZ-20** (BLOCKING, Unit): shared-counter dual gate. GIVEN `zone_win_count = 6`, Boss 1 not yet defeated, THEN Boss 1 `UNLOCKED` **and** Boss 2 `LOCKED` (6 ≥ 6 but 6 < 10). GIVEN `zone_win_count = 10` **and** Boss 1 `defeated_once = true`, THEN **both** `UNLOCKED`. Discriminator: an impl using one flag for "any boss unlocked" opens Boss 2 at 6 — assert Boss 2 `LOCKED` at 6.
- [ ] **AC-EZ-56** (BLOCKING, Unit): Boss 2 sequencing precondition (`requires_defeated`). GIVEN Boss 2 `gate_params.requires_defeated = <Boss 1 boss_id>`, `zone_win_count = 10`, Boss 1 `defeated_once = false`, THEN Boss 2 `LOCKED` (threshold met, prerequisite unmet). GIVEN the same with Boss 1 `defeated_once = true`, THEN Boss 2 `UNLOCKED`. Discriminator: a threshold-only impl opens Boss 2 at 10 regardless of Boss 1.
- [ ] **AC-EZ-58** (BLOCKING, Unit): `requires_defeated` broken reference is fail-safe *(verifies EC-EZ-12)*. GIVEN Boss 2 `gate_params.requires_defeated = "no_such_boss"`, `zone_win_count = 10`, THEN Boss 2 `LOCKED` and unofferable, content error logged naming the boss + the unresolved value. Discriminator: a fail-**open** impl returns `UNLOCKED` at win_count ≥ 10.
- [ ] **AC-EZ-40a** (BLOCKING, Unit): Exploration Progress absent — no crash, safe defaults *(verifies EC-EZ-11)*. GIVEN a null/not-connected progress stub, WIN_COUNT gate → win counter reads 0, state `LOCKED`, provisional **warning** (not error) logged, no crash; OPEN gate → `UNLOCKED`.

---

## Implementation Notes

*Derived from ADR-0007 + ADR-0002 Implementation Guidelines:*

- Implement gate evaluation as a pure function of `(boss_encounter, progress_state) -> GateState`. WIN_COUNT: `state = UNLOCKED if zone_win_count >= required_wins else LOCKED` — use `>=`, never `>`.
- Sequencing: when `gate_params.requires_defeated` is present, resolve it against this zone's `boss_encounters`. Gate is `UNLOCKED` only when the win threshold is met **and** the resolved prerequisite boss's `defeated_once == true`. If the name resolves to no boss in the zone → **fail-safe LOCKED** + content error (AC-EZ-58); never treat "unresolvable" as "no prerequisite".
- The two bosses read *one* shared counter but compare it to their own thresholds independently. Do not collapse this into a single "any boss unlocked" flag (AC-EZ-20 discriminator).
- Progress absent (null stub): win counter reads 0, WIN_COUNT bosses are `LOCKED` with a provisional **warning** (not error), OPEN bosses are `UNLOCKED`; never crash (AC-EZ-40a). This fallback is live for the whole MVP dev period until Exploration Progress ships.
- Re-evaluation trigger is `encounter_resolved` (the ADR-0002 Overworld relay) + boss-approach query — never mid-battle. This story owns the *verdict*; the actual signal subscription wiring is deferred integration (AC-EZ-40b).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: `LIGHTER_REGATE` delta re-gate and `ALWAYS_OPEN` post-defeat behavior (AC-EZ-21/22/23/39/52). This story is *first-access only* (`defeated_once = false` for Boss 1's own gate; Boss 1's `defeated_once = true` appears here only as Boss 2's *prerequisite*).
- Story 007: gate-param *validation* (missing `required_wins`, OPEN spurious params, reserved gate types, WILD-in-boss-slot, regate-strictly-lighter). This story assumes well-formed WIN_COUNT params.
- **Deferred integration:** AC-EZ-40b (live Exploration Progress), AC-EZ-43/44 (save/reload persistence of counter + `defeated_once`) — epic deferred-integration note.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-EZ-16/17/18**: Boss 1 threshold.
  - Given: Boss 1 `required_wins = 6`; injected `zone_win_count` = 5 / 6 / 7; `defeated_once = false`.
  - When: gate evaluated.
  - Then: LOCKED / UNLOCKED / UNLOCKED.
  - Edge cases: the `= 6` case is the `>=`-vs-`>` discriminator.
- **AC-EZ-19**: Boss 2 threshold with sequencing satisfied.
  - Given: Boss 2 `required_wins = 10`, Boss 1 `defeated_once = true`; `zone_win_count` = 9 then 10.
  - When: gate evaluated.
  - Then: LOCKED then UNLOCKED.
- **AC-EZ-20**: dual gate off one counter.
  - Given: `zone_win_count = 6`, Boss 1 undefeated → then `zone_win_count = 10`, Boss 1 `defeated_once = true`.
  - When: both bosses evaluated.
  - Then: (Boss1 UNLOCKED, Boss2 LOCKED) then (both UNLOCKED).
  - Edge cases: Boss 2 must be LOCKED at 6 — the "any boss unlocked" discriminator.
- **AC-EZ-56**: sequencing precondition.
  - Given: Boss 2 `requires_defeated = <Boss1 id>`, `zone_win_count = 10`; Boss 1 `defeated_once` = false then true.
  - When: Boss 2 evaluated.
  - Then: LOCKED then UNLOCKED.
- **AC-EZ-58**: dangling prerequisite.
  - Given: Boss 2 `requires_defeated = "no_such_boss"`, `zone_win_count = 10`; spy LogSink.
  - When: Boss 2 evaluated.
  - Then: LOCKED; content error names the boss + unresolved value.
  - Edge cases: fail-**open** impl returns UNLOCKED — assert LOCKED.
- **AC-EZ-40a**: progress absent.
  - Given: null progress stub; spy LogSink.
  - When: a WIN_COUNT boss and an OPEN boss are evaluated.
  - Then: WIN_COUNT → LOCKED + provisional **warning**, counter reads 0, no crash; OPEN → UNLOCKED.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/encounter_zone/boss_gate_wincount_test.gd` — must exist and pass.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`BossEncounter` field shapes + resolver host + injected progress interface).
- Unlocks: Story 006 (repeat policy builds on the first-access verdict) + Story 007 (param validation guards this evaluation).
