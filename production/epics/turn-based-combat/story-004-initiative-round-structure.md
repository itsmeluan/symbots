# Story 004: Initiative & round structure (TBC-F1 + TBC-F4 shock magnitude)

> **Epic**: Turn-Based Combat
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: 2026-07-17

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 3, TBC-F1, TBC-F4, EC-TBC-01)
**Requirement**: `TR-tbc-006`, `TR-tbc-038`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary), ADR-0005 (SYN-F4 mobility composition)
**ADR Decision Summary**: Initiative is recomputed at every `ROUND_START`, sorting living combatants **descending** by `effective_mobility`, player side winning ties. `effective_mobility = max(0, final_stat["mobility"] + synergy_delta.get("mobility",0) − shock_magnitude)`. TBC-F4 outputs a **positive** `shock_magnitude` (0–33) that TBC-F1 subtracts — never a pre-negated value.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. **Floor-not-round is load-bearing for the discriminators** — use `floor(x + 0.0001)`, never GDScript `round()` (round-half-away flips 15.9→16). The `+0.0001` epsilon is DEFENSIVE (scan-verified 2026-07-10); do NOT remove it, but it is not what makes the fixture pass — the `floor` is.

**Control Manifest Rules (Core layer)**:
- Required: SYN-F4 mobility composition goes through the single `StatMath.effective_stat` / `CombatantSnapshot.effective_stat` point; read the frozen snapshot only.
- Forbidden: `inline_stat_composition` (no re-implementing SYN-F4); `global_rng_access` (initiative tiebreak is deterministic — player-first, never RNG).

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-03**: initiative tie — including 0 vs. 0 — breaks in the player's favor. Symbot and enemy both at `effective_mobility = 0` (Symbot mobility 0, Shock proc-0 penalty 0; enemy mobility 0) → player acts first. Second fixture: both at 35 → player first. No RNG tiebreak.
- [ ] **AC-TBC-04**: initiative recomputes at every `ROUND_START`. Round 1: Symbot mobility 30, enemy 50 (enemy first); apply Shock (proc 53 → penalty 15) to enemy; Round 2: enemy effective 35, still first (35 > 30). Flip case: Symbot mobility 40, enemy 50, Shock 15 → Round 2 enemy 35 < 40 → order flips.
- [ ] **AC-TBC-05**: TBC-F1/F4 Shock penalty floor discrimination. `snapshotted_processing = 53` → `shock_magnitude = floor(53 × 0.3 + 0.0001) = 15` (round/ceil give 16); on mobility-64 target → `effective_mobility = 49` (round/ceil give 48). Edge: processing 0 → penalty 0, no crash.

---

## Implementation Notes

*Derived from ADR-0007 Rule 3 / TBC-F1 / TBC-F4:*

- `shock_magnitude = floor(snapshotted_processing * 0.3 + 0.0001)` (`SHOCK_COEFF = 0.3`), stored **positive** on the Shock status instance at application time (Story 007 owns application; this story consumes the stored magnitude). TBC-F1 subtracts it: `effective_mobility = max(0, mobility + synergy_delta.get("mobility",0) − shock_magnitude)`.
- Compose the mobility through `CombatantSnapshot.effective_stat` — do NOT re-implement the clamp. Enemy path: `stats.get("mobility",0)`, synergy_delta always 0.
- Sort living combatants descending by `effective_mobility`; on equal values the **player side is ordered first** (stable, deterministic — never RNG).
- **Recompute at every `ROUND_START`**, not once at battle start — the Round-2 fixtures prove recomputation ran (a Shock applied in Round 1 changes Round-2 order).

---

## Out of Scope

- Story 007: Shock status application, snapshot capture, and lifecycle (this story reads the already-stored `shock_magnitude`).
- Story 005: the turn-start phases that run once a combatant's turn begins.
- Enemy AI selection at the enemy's initiative slot (Enemy AI epic).

---

## QA Test Cases

- **AC-TBC-03**: player-first tiebreak
  - Given: Symbot and enemy both `effective_mobility = 0` (Symbot Shocked at proc-0); second fixture both at 35
  - When: initiative computed at `ROUND_START`
  - Then: player Symbot ordered first in both fixtures
  - Edge cases: 0 vs 0 with a Shocked zero-mobility Symbot still player-first; no RNG
- **AC-TBC-04**: recompute each round
  - Given: R1 Symbot mob 30, enemy 50; apply Shock (proc 53 → 15) to enemy
  - When: R2 initiative computed
  - Then: enemy effective 35, still first (35 > 30)
  - Edge cases: flip case — Symbot mob 40, enemy 50, Shock 15 → R2 enemy 35 < 40, order flips (proves recomputation, not inference)
- **AC-TBC-05**: TBC-F4 floor
  - Given: `snapshotted_processing = 53`, target base mobility 64
  - When: `shock_magnitude` and `effective_mobility` computed
  - Then: magnitude == 15 (NOT 16); effective == 49 (NOT 48)
  - Edge cases: processing 0 → magnitude 0, no crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/initiative_round_structure_test.gd` — must exist and pass. Discriminating floor fixtures (53→15, not 16) required.

**Status**: [x] Complete — `tests/unit/tbc/battle_controller_initiative_test.gd` (+ `battle_formulas_test.gd` for TBC-F1/F4)

---

## Completion Notes

**Completed**: 2026-07-17 · **Criteria**: 3/3 (AC-TBC-03, 04, 05) verified against source + discriminating tests.

- AC-TBC-03 (descending `effective_mobility`), AC-TBC-04 (ties resolve player-first, NO RNG — deterministic), AC-TBC-05 (Shock lowers `effective_mobility` and can reorder) each have a dedicated test; the TBC-F4 shock magnitude is separately pinned in `battle_formulas_test.gd`.
- Initiative recomputes every `ROUND_START` (verified through the pure static sort).

**Test Evidence**: `battle_controller_initiative_test.gd`, `battle_formulas_test.gd` — full GUT suite **762/762 green, 4268 asserts** (Godot 4.7 · GUT 9.7.1).
**Code Review**: inline as godot-gdscript-specialist (lean per-story gate) — no blocking issues.

---

## Dependencies

- Depends on: Story 002 (snapshot with mobility + synergy delta), Story 007 (Shock stores `shock_magnitude` — for the AC-TBC-04/05 Shock cases; the tie/recompute skeleton can be built first with stub Shock)
- Unlocks: Story 005 (turn anatomy runs per combatant in initiative order)
