# Story 008: Damage pipeline — SYN-F4 → DF-1 → MOVE-F1 → Stagger reduction (TBC-F5)

> **Epic**: Turn-Based Combat
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 10, TBC-F5, DF-1 Range Re-Derivation)
**Requirement**: `TR-tbc-011`, `TR-tbc-012`, `TR-tbc-026`, `TR-tbc-033`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0005** (primary), ADR-0007, ADR-0006 (crit seed)
**ADR Decision Summary**: DAMAGE-move damage is computed pipeline-order: effective attack stat via **SYN-F4** (`max(0, final + synergy + aura)`) on the routing power stat, same clamp for the defender's defense stat; call `compute_damage(A, damage_type, element, D, target_core_element, crit_mult=1.0)`; scale the result by the move's **MOVE-F1** power tier (post-DF-1); then apply **TBC-F5** Stagger reduction if the attacker is Staggered. DF-1's registered output range is [1,225]; post-MOVE-F1 damage extends to [1,315].

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. SYN-F4 goes through the single `CombatantSnapshot.effective_stat` / `StatMath.effective_stat` point — never re-implement the clamp. `compute_damage` is the existing pure static from the Damage Formula epic; pass `crit_mult=1.0` by default (crit is rolled via an injected seed — `next_seed(&"crit")` — vended by TBC, never `@GlobalScope` RNG). TBC-F5 uses `floor(x + 0.0001)`, never `round()`. AC-SYN-06/AC-SYN-10 (the SYN-F4 formula contract) are implemented in `tests/unit/tbc/` per the Synergy consumer-ownership note.

**Control Manifest Rules (Core layer)**:
- Required: all effective-stat composition goes through `StatMath.effective_stat` / `CombatantSnapshot.effective_stat`; damage via the `compute_damage` pure static; randomness injected as `seed`/`RandomNumberGenerator`.
- Forbidden: `inline_stat_composition`; `global_rng_access`; `rng_service_in_formula_code` (only the orchestrator vends the crit seed; the formula core stays pure).

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-22**: SYN-F4 applies to both sides before DF-1. Symbot `physical_power=90` + frozen synergy `{physical_power:25}` → effective A=115; enemy `armor=55`, no synergy → D=55; PHYSICAL KINETIC move; enemy `core_element=KINETIC` → T=1.0 → `compute_damage(115, PHYSICAL, KINETIC, 55, KINETIC, 1.0)` called (argument-capture) → damage `floor(13225/170+ε)=77`; structure −77. Type sub-fixture: enemy `core_element=VOLT` → T=1.5 → damage `floor(77.7941×1.5+ε)=116`.
- [ ] **AC-TBC-26**: TBC-F5 two-step floor. Step 1: proc 86 → `stagger_pct=floor(21.5001)=21` (round-half-away → 22 FAIL). Step 2: damage 50, pct 21 → `floor(39.5001)=39` (round/ceil → 40 FAIL). Floor guard: damage 1, pct 27 → `max(1, floor(0.7301))=1`.
- [ ] **AC-TBC-28**: DF-1 extended range. Absolute ceiling A=150,D=0,T=1.5 → 225. Realistic ceiling A=150,D=55,T=1.5 → `floor(164.6342…)=164` (round/ceil → 165 FAIL). Minimum A=1,D=182,T=0.75 → `max(1,0)=1`.

---

## Implementation Notes

*Derived from ADR-0005 Rule 10 + TBC-F5 + DF-1 re-derivation:*

- Pipeline order (authoritative): (1) `A = effective_stat(attacker, routing_power_stat)`, `D = effective_stat(defender, defense_stat)` — both via SYN-F4 (attacker gets synergy+aura; enemy defender has neither); (2) `raw = compute_damage(A, move.damage_type, move.element, D, target_core_element, crit_mult)`; (3) `powered = MOVE-F1(raw, move.power_tier)` (post-DF-1 multiply; STANDARD tier = ×1.00); (4) if attacker Staggered: `final = max(1, floor(powered × (1 − stagger_pct/100.0) + 0.0001))`.
- SYN-F4 is `CombatantSnapshot.effective_stat` — call it, do not inline. Synergy applies only to the attacker's power (and only defender's own side if it had synergy — enemies never do); never apply the attacker's synergy to enemy defense (the AC-TBC-22 FAIL case).
- `crit_mult` defaults to 1.0; when a crit roll is needed, draw it from an injected seed vended by TBC (`RngService.next_seed(&"crit")` → `make_rng`), never `@GlobalScope`. Keep the roll out of the formula core.
- DF-1 input ceilings after SYN-F4: `A_max=150` (`110 + SYNERGY_POWER_BUDGET 40`), `D_max=182` (`132 + SYNERGY_DEFENSE_BUDGET 50`); output range [1,225]; MOVE-F1 extends to [1,315]. These constants (`SYNERGY_POWER_BUDGET=40`, `SYNERGY_DEFENSE_BUDGET=50`) are TBC-derived (AC-TBC-33 enforcement lives in the Synergy validator — out of scope here).

---

## Out of Scope

- Story 009: sub-target routing (STRUCTURE vs region), PB spillover, `hit_resolved` emission, enemy enrage — this story yields the pre-routing `move_damage` (post-Stagger).
- Story 007: `stagger_pct` step-1 computation at status application (consumed here as an input).
- AC-TBC-33 cumulative synergy-budget validation (Synergy content validator).

---

## QA Test Cases

- **AC-TBC-22**: SYN-F4 both sides
  - Given: Symbot phys_power 90 + synergy {physical_power:25}; enemy armor 55, no synergy; PHYSICAL KINETIC move; enemy core KINETIC
  - When: the move resolves
  - Then: `compute_damage(115, PHYSICAL, KINETIC, 55, KINETIC, 1.0)` captured; damage 77
  - Edge cases: `compute_damage(90,…)` (SYN-F4 skipped → 55) is a FAIL; synergy applied to enemy defense is a FAIL; type sub-fixture VOLT core → T=1.5 → 116
- **AC-TBC-26**: TBC-F5 two-step
  - Given: proc 86 (step 1); then final_damage 50 at pct 21 (step 2); then damage 1 at pct 27
  - When: stagger applied
  - Then: pct 21 (NOT 22); staggered 39 (NOT 40); floor guard → 1
- **AC-TBC-28**: DF-1 range
  - Given: (A=150,D=0,T=1.5), (A=150,D=55,T=1.5), (A=1,D=182,T=0.75)
  - When: `compute_damage` evaluated
  - Then: 225; 164 (NOT 165); 1 (DAMAGE_FLOOR)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/damage_pipeline_test.gd` — must exist and pass. Argument-capture stub for `compute_damage`; SYN-F4-skipped and synergy-on-enemy-defense FAIL cases asserted. Also implements the SYN-F4 contract (AC-SYN-06/AC-SYN-10) in `tests/unit/tbc/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (frozen snapshot + synergy delta), Story 007 (`stagger_pct`)
- Unlocks: Story 009 (routes the `move_damage` this story produces)
