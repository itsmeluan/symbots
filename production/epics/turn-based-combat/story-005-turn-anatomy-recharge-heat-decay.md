# Story 005: Turn anatomy — heat decay, energy recharge (TBC-F2), phase ordering

> **Epic**: Turn-Based Combat
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 4, TBC-F2, Rule 8)
**Requirement**: `TR-tbc-007`, `TR-tbc-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary)
**ADR Decision Summary**: Each combatant's turn resolves in fixed phases. Turn-start (Rule 4.1) runs, in order: (a) Heat decay `heat = max(0, heat − cooling)` (players only); (b) Energy recharge `energy = min(max_energy_capacity, energy + 10 + recharge)` (players only); (c) status ticks (Burn applies now — Story 007). Enemies get neither decay nor recharge (Rule 8).

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. TBC-F2 is **pure integer arithmetic — no epsilon**. Phase *order* is the system under test — Burn must tick strictly after decay+recharge (Story 007 provides the Burn tick; this story owns the ordering seam and the two player-only formulas).

**Control Manifest Rules (Core layer)**:
- Required: in-battle changes are TBC-owned modifiers layered on `effective_stat()` — heat/energy are `BattleContext` runtime fields, never a pipeline recompute.
- Forbidden: `mid_battle_stat_recompute`.

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-07**: turn-start phase order Heat decay → Energy recharge → Burn tick, players only. Heat 30/cooling 10; energy 40/cap 95/recharge 22; Burn active (proc 72); structure 50 → heat = `max(0,30−10) = 20`; energy = `min(95,40+10+22) = 72`; burn = `max(2,floor(5.7601)) = 5` → structure 45. Enemy exclusion: no decay/recharge on enemy turns.
- [ ] **AC-TBC-08**: TBC-F2 recharge cap-fires and cap-silent pair. Case A: `min(95, 73+10+22) = 95` (cap fires; no-min gives 105). Case B: `min(95, 40+10+22) = 72` (cap silent). Both required together.

---

## Implementation Notes

*Derived from ADR-0007 Rule 4 / TBC-F2:*

- Turn-start sequence is a single ordered method: (a) `heat = maxi(0, heat − cooling)`; (b) `energy = mini(max_energy_capacity, energy + 10 + final_stat["recharge"])`; (c) invoke the status-tick hook (Burn — Story 007). Ordering is authoritative — do not reorder; the AC-TBC-07 fixture fails if Burn ticks before decay.
- Both (a) and (b) run for **player Symbots only**. On an enemy turn, skip decay and recharge entirely (enemy has no heat/energy fields — Story 002).
- TBC-F2: `10` is the universal base regen (`BASE_ENERGY_REGEN`), `recharge` from the frozen snapshot. Integer math, no epsilon.
- The Overheat-skip variant of turn-start (heat set to flat carry-in 20, no decay) is Story 006 — this story handles the normal (non-Overheated) path.

---

## Out of Scope

- Story 006: the Overheated-turn variant (flat carry-in 20, no decay) and heat *gain* on move use.
- Story 007: the Burn tick value/floor and status decrement-at-turn-end (this story only invokes the tick hook in the right position).
- Story 004: initiative that decides whose turn runs.

---

## QA Test Cases

- **AC-TBC-07**: phase order + player-only
  - Given: heat 30/cooling 10; energy 40/cap 95/recharge 22; Burn (proc 72); structure 50; not Overheated
  - When: the turn starts
  - Then: heat → 20, then energy → 72, then burn 5 → structure 45 (in that order)
  - Edge cases: enemy turn — no decay, no recharge; burn = 6 (round/ceil) is a FAIL; energy = 105 (no cap) is a FAIL; Burn ticking before decay is a FAIL
- **AC-TBC-08**: recharge cap pair
  - Given: Case A energy 73/cap 95/recharge 22; Case B energy 40/cap 95/recharge 22
  - When: recharge applies
  - Then: A → 95 (cap fires); B → 72 (cap silent)
  - Edge cases: both assertions in one test — a no-cap implementation passes B alone

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/turn_anatomy_recharge_test.gd` — must exist and pass. AC-TBC-08 cap-fires + cap-silent required together.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (runtime heat/energy fields), Story 004 (turn order)
- Unlocks: Story 006 (Overheat variant builds on turn-start), Story 007 (Burn tick slots into phase (c))
