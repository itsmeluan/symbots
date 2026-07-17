# Story 007: Status system — model, potency snapshot, Burn DoT, newest-wins, lifecycle

> **Epic**: Turn-Based Combat
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 11, TBC-F3, TBC-F4, TBC-F5 step 1; EC-TBC-07/09/13/14)
**Requirement**: `TR-tbc-017`, `TR-tbc-018`, `TR-tbc-021`, `TR-tbc-027`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary), ADR-0005 (snapshot contract)
**ADR Decision Summary**: Exactly three statuses (Shock/Volt/2T, Burn/Thermal/2T, Stagger/Kinetic/2T). No stacking (reapply refreshes duration to full); different statuses coexist. Every magnitude reads the applier's **pre-synergy** `final_stat["processing"]` at the moment of application and stores it on the status instance (never re-read live). Burn DoT bypasses DF-1. Reapplication is newest-wins entirely (refresh duration AND re-snapshot). Lifecycle: Burn ticks at turn-start, durations decrement at turn-end, expire at 0.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. Snapshot is **PRE-synergy** — `snapshotted_processing = final_stat["processing"]`, never SYN-F4. All three magnitude formulas use `floor(x + 0.0001)`, never `round()` (round-half-away flips the discriminators). Burn floor is `max(2, …)` — `BURN_MIN` always ticks even at proc 0.

**Control Manifest Rules (Core layer)**:
- Required: statuses are `BattleContext` runtime modifiers layered on `effective_stat()`; the snapshot is frozen at BATTLE_INIT (the status potency snapshot is analogous — captured at application, never re-read).
- Forbidden: `mid_battle_stat_recompute`; `inline_stat_composition`.

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-24**: all three statuses coexist with independent snapshots/durations; reapplication targets same-type only. Shock (proc 53), Burn (proc 72), Stagger (proc 86) on one target → penalty 15, tick 5, pct 21. Reapply Burn (proc 30) → only Burn changes; Shock/Stagger untouched.
- [ ] **AC-TBC-13**: *(Verifies EC-TBC-07)* reapplication refreshes duration AND re-snapshots — newest wins entirely. Burn snapshot proc 30 (tick 2), 1 left → reapply proc 72 → duration 2, tick 5. Discriminating lower-processing reapply proc 10 → tick 2, duration 2 (NOT 5 — no max()/higher-wins).
- [ ] **AC-TBC-15**: *(Verifies EC-TBC-09)* zero-potency statuses are legal no-ops; Burn still ticks BURN_MIN. Applier proc 0 → Shock penalty 0; Stagger pct 0 (`floor(50×1.0+ε)=50`, no reduction); Burn tick `max(2,0)=2`.
- [ ] **AC-TBC-25**: TBC-F3 Burn floor. proc 72 → `floor(5.7601)=5` (round/ceil → 6 FAIL); proc 0 → 2 (BURN_MIN); proc 110 → `floor(8.8001)=8` (round/ceil → 9 FAIL).
- [ ] **AC-TBC-23**: Burn bypasses DF-1 — Armor/Resistance/type never reduce it. Enemy armor 80/resistance 80/core KINETIC; Burn proc 72 → structure −5 exactly; `compute_damage` NOT called; no type multiplier.
- [ ] **AC-TBC-36**: decrement-and-expire lifecycle. Burn (duration 2, proc 72) → ticks exactly twice (turn-starts 1 and 2), decrements at each turn-end, ABSENT after turn 2's end; no third tick. Same for Shock/Stagger — modifiers stop at expiry.

---

## Implementation Notes

*Derived from ADR-0007 Rule 11 + snapshot contract:*

- Status instance: `{ type, snapshotted_processing, duration, computed_magnitude }`. Capture `snapshotted_processing = applier.final_stat["processing"]` (**pre-synergy**) at `apply_status()`; compute the magnitude once and store it.
  - Shock: `shock_magnitude = floor(proc × 0.3 + 0.0001)` (0–33), stored positive (Story 004 consumes it).
  - Burn: `burn_damage = max(2, floor(proc × 0.08 + 0.0001))` (`BURN_MIN=2`, `BURN_COEFF=0.08`) — ticks at turn-start, reduces `current_structure` directly, **bypasses DF-1** (no `compute_damage`, no armor/type), also not reduced by Stagger (DoT is not a move).
  - Stagger: `stagger_pct = floor(proc × 0.25 + 0.0001)` (0–27) — step 1 stored here; the step-2 damage reduction is Story 008.
- No stacking: `apply_status` on an already-active same-type status refreshes `duration` to full AND replaces `snapshotted_processing`+`computed_magnitude` (newest-wins — no `max()`, no averaging). Different types coexist as independent instances.
- Lifecycle: Burn tick fires in the turn-start phase (Story 005 hook); all durations decrement at turn-end; a status at duration 0 is removed (its modifier stops applying). Zero-potency statuses still apply/display/expire (Burn is the exception — always ticks BURN_MIN).

---

## Out of Scope

- Story 008: TBC-F5 step-2 Stagger damage reduction (this story computes `stagger_pct` at application only).
- Story 004: how `shock_magnitude` feeds initiative (consumed there).
- Story 011: DOWNED-clears-statuses and bench-freeze (AC-TBC-18) — those are switch/down mechanics; this story owns the per-turn tick/decrement/expire lifecycle.
- Story 013: passive riders that *apply* statuses (`volt_shock_on_hit` etc.) — this story owns `apply_status` itself.

---

## QA Test Cases

- **AC-TBC-24**: coexistence + same-type reapply
  - Given: Shock(53), Burn(72), Stagger(86) applied to one target via 3 `apply_status` calls
  - When: all present; then Burn reapplied at proc 30
  - Then: penalty 15 / tick 5 / pct 21 independently; only Burn's record changes on reapply
- **AC-TBC-13**: newest-wins
  - Given: Burn proc 30 (tick 2), 1 turn left
  - When: reapplied proc 72, then proc 10
  - Then: after 72 → duration 2, tick 5; after 10 → duration 2, tick 2 (NOT 5)
- **AC-TBC-15**: zero-potency
  - Given: applier proc 0
  - When: Shock/Stagger/Burn applied
  - Then: Shock penalty 0; Stagger pct 0 (no reduction); Burn tick 2
- **AC-TBC-25**: Burn floor discriminators
  - Given: proc 72 / 0 / 110
  - When: `burn_damage` computed
  - Then: 5 / 2 / 8 (NOT 6 / _ / 9)
- **AC-TBC-23**: Burn bypasses DF-1
  - Given: enemy armor 80/resistance 80/core KINETIC; Burn proc 72 (tick 5)
  - When: Burn ticks
  - Then: structure −5 exactly; `compute_damage` not called; no type multiplier
- **AC-TBC-36**: lifecycle
  - Given: Burn duration 2, proc 72
  - When: the afflicted combatant completes 2 of its own turns
  - Then: ticks exactly twice, decrements at each turn-end, absent after turn 2; no third tick; Shock/Stagger modifiers stop at expiry

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/status_system_test.gd` — must exist and pass. Newest-wins lower-processing reapply + Burn floor discriminators required.

**Status**: [x] Complete — `tests/unit/tbc/status_system_test.gd`

---

## Completion Notes

**Completed**: 2026-07-17 · **Criteria**: 6/6 (AC-TBC-24, 13, 15, 25, 23, 36) verified against source + discriminating tests.

- Coexistence + same-type reapply (24), newest-wins incl. the discriminating LOWER-processing reapply with no `max()` (13), zero-potency no-ops (15), TBC-F3 Burn floor discriminators (25), Burn bypasses DF-1 (23), and the tick-exactly-twice decrement/expire lifecycle (36) each have a dedicated test. 11 test functions cover the 6 ACs.

**Test Evidence**: `status_system_test.gd` — full GUT suite **762/762 green, 4268 asserts** (Godot 4.7 · GUT 9.7.1).
**Code Review**: inline as godot-gdscript-specialist (lean per-story gate) — no blocking issues.

---

## Dependencies

- Depends on: Story 002 (runtime state), Story 005 (turn-start tick hook / turn-end decrement hook)
- Unlocks: Story 004 (Shock magnitude), Story 008 (Stagger step-2), Story 013 (passive status riders)
