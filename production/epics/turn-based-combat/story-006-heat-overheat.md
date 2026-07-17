# Story 006: Heat gain & Overheat (self-damage, skip, carry-in; victory-before-heat)

> **Epic**: Turn-Based Combat
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 4.2, Rule 5d, EC-TBC-03, EC-TBC-05)
**Requirement**: `TR-tbc-008`, `TR-tbc-022`, `TR-tbc-031`, `TR-tbc-032`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary)
**ADR Decision Summary**: Heat gain on move use is Part DB Formula 5: `heat = min(100, heat + heat_generation + (5 if part.element == THERMAL else 0))`. At heat 100 → Overheat: 10%-max-structure self-damage now, skip next action phase, carry-in heat 20. An OVERHEATED turn runs full bookkeeping (recharge, Burn tick, status decrement) EXCEPT heat decay (heat set flat to 20). **Victory is checked before heat gain** — a kill that would self-down via Overheat resolves as VICTORY, self-damage never applies.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. Rule 5 step order `(c) resolve → end-check → (d) heat gain` is the system under test for AC-TBC-11 — the end-check must sit *between* resolution and heat gain. Overheat self-damage is `floor(max_structure * 0.10)` (10%).

**Control Manifest Rules (Core layer)**:
- Required: heat is a `BattleContext` runtime field; in-battle changes are TBC-owned modifiers, never a pipeline recompute.
- Forbidden: `mid_battle_stat_recompute`; `battle_state_on_transient_node` (heat lives on the context, not a scene node).

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-09**: *(Verifies EC-TBC-03)* an Overheated turn (heat 100) skips the action phase but runs all bookkeeping. Burn active (proc 72, 2 turns), energy 50/cap 95/recharge 22, structure 40 → (1) heat decay does NOT run — heat set flat to carry-in **20**; (2) energy = 82; (3) burn ticks 5 → structure 35; (4) no action phase; (5) turn-end decrements Burn 2 → 1; (6) OVERHEATED clears, next turn acts normally.
- [ ] **AC-TBC-11**: *(Verifies EC-TBC-05)* victory checked before heat gain. Symbot heat 90, move `heat_generation = 20` (non-THERMAL), max_structure 50 (Overheat self-damage 5), current_structure 4 → move drops enemy to 0 → `battle_ended(VICTORY,…)` at that moment; heat gain (Rule 5d) never executes; no Overheat; Symbot NOT downed.

---

## Implementation Notes

*Derived from ADR-0007 Rule 4.2 / Rule 5d:*

- Heat gain (Rule 5d) after a move resolves: `heat = mini(100, heat + heat_generation + (5 if owning_part.element == THERMAL else 0))`. On reaching 100, mark `OVERHEATED`, apply `floor(max_structure * 0.10)` self-damage immediately, and set carry-in so the *next* turn's turn-start skips decay and sets heat to flat 20.
- **Rule 5 order (AC-TBC-11)**: (c) resolve the move → **end-condition check** (enemy structure 0 → VICTORY, emit now, stop) → (d) heat gain. The end-check strictly precedes heat gain — so a kill that would otherwise self-down via Overheat resolves VICTORY with no self-damage.
- **Overheated turn-start (AC-TBC-09)**: replace the Story 005 decay step with a flat `heat = 20` (carry-in), still run recharge and the Burn tick, skip the action phase, then run turn-end decrement. Clear `OVERHEATED` after this turn.
- 10% self-damage uses `max_structure`, floored; it can down the user only when it exceeds remaining structure (the EC-TBC-05 collision), which the victory-first check pre-empts.

---

## Out of Scope

- Story 005: the normal (non-Overheated) turn-start decay/recharge (this story is the Overheat variant + heat gain).
- Story 008: the damage that a move deals (this story consumes "enemy dropped to 0" as an input to the end-check).
- Story 007: the Burn tick value (invoked here in the Overheated bookkeeping, owned there).

---

## QA Test Cases

- **AC-TBC-09**: Overheated bookkeeping
  - Given: turn entered OVERHEATED (heat 100); Burn (proc 72, 2 left); energy 50/cap 95/recharge 22; structure 40
  - When: the turn resolves
  - Then: heat = 20 (flat carry-in, NOT `max(0,100−cooling)`); energy = 82; burn 5 → structure 35; no action; Burn decrements 2→1; OVERHEATED clears
  - Edge cases: next turn acts normally; a `max(0,100−cooling)` decay path is a FAIL
- **AC-TBC-11**: victory before heat
  - Given: heat 90, move `heat_generation=20` non-THERMAL, max_structure 50 (self-dmg 5), current_structure 4; move kills the enemy
  - When: the move resolves
  - Then: `battle_ended(VICTORY,…)` emits at kill; heat gain never runs; no Overheat; Symbot survives (structure 4)
  - Edge cases: heat-first ordering (→ self-down → DEFEAT) is the exact FAIL under test

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/heat_overheat_test.gd` — must exist and pass. Both the carry-in-20 discriminator and the victory-before-heat ordering required.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (turn-start scaffold), Story 002 (heat runtime field)
- Unlocks: Story 011 (down-ordering interacts with self-down), Story 014 (VICTORY emit)
