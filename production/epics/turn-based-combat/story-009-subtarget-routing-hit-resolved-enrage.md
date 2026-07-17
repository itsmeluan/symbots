# Story 009: Sub-target routing, spillover & hit_resolved hook; enemy enrage (TBC-F7)

> **Epic**: Turn-Based Combat
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 10 sub-target routing + enemy pipeline, TBC-F7)
**Requirement**: `TR-tbc-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0005** (primary), ADR-0007, ADR-0002 (hook signal)
**ADR Decision Summary**: TBC routes `move_damage` by `sub_target` ∈ `{STRUCTURE} ∪ {unbroken region_id}`, applying the move's `break_bias` → `(structure_mult, break_mult)`. A STRUCTURE hit reduces structure by `PB-F1` with no spillover; a region hit emits `hit_resolved(move, move_damage, target, sub_target)` (Part-Break applies PB-F2/PB-F4) and TBC applies `PB-F3` spillover (`BREAK_SPILLOVER=0.20`). The enemy pipeline applies **TBC-F7 enrage** (`ENRAGE_PER_BREAK=0.12`) POST-Stagger. `hit_resolved` is the widened 4-arg hook carrying post-SYN-F4/MOVE-F1/Stagger damage plus the sub-target.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. `hit_resolved(move, damage, target, sub_target)` uses `.emit()`. The `BREAK_BIAS_MULTIPLIERS` / `ENRAGE_PER_BREAK` / `BREAK_SPILLOVER` constants are **owned by the Part-Break GDD** — verify against it before implementing; if Part-Break retunes them, re-derive the fixtures. All routing math uses `floor(x + 0.0001)` with a `max(1, …)` DAMAGE_FLOOR guard.

**Control Manifest Rules (Core layer)**:
- Required: `hit_resolved` is TBC's per-hit hook; TBC owns and applies PB-F1 (STRUCTURE) and PB-F3 (spillover), Part-Break owns PB-F2/PB-F4.
- Forbidden: `inline_stat_composition`; hardcoding `sub_target` (the AC-TBC-34 Fixture B trap).

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-34**: `hit_resolved(move, damage, target, sub_target)` emits exactly once per DAMAGE-move resolution, carrying post-SYN-F4/MOVE-F1/Stagger damage AND the sub-target.
  - Fixture A (STRUCTURE): pre-Stagger 77, attacker Staggered pct 21, STANDARD-tier move → fires once with `damage = max(1, floor(77×0.79+ε)) = 60` (round → 61 FAIL), the move, the target, `sub_target == STRUCTURE`. Non-DAMAGE moves and Burn ticks do NOT emit.
  - Fixture B (region): same pipeline sub-targeting `region_id = "left_arm"` → fires with `sub_target == "left_arm"` (NOT STRUCTURE) — proving the payload carries the chosen routing, not a hardcoded default. Both required.
- [ ] **TBC-F7 enrage (unit, stubbed `broken_region_count`)**: `enraged_damage = max(1, floor(enemy_hit_resolved × (1 + broken_region_count × 0.12) + 0.0001))`, applied POST-Stagger. Worked: `enemy_hit_resolved=43`, count 1 → 48 (round/ceil → 49 FAIL). Identity: count 0 → 43 (×1.00). Max-stack: `enemy_hit_resolved=41`, count 3 → `floor(41×1.36+ε)=55` (round/ceil → 56 FAIL).

---

## Implementation Notes

*Derived from ADR-0005 Rule 10 sub-target routing + TBC-F7:*

- Given `move_damage` (Story 008 output, post-Stagger) and a `sub_target`:
  - `sub_target == STRUCTURE`: `current_structure -= max(1, floor(move_damage × structure_mult + 0.0001))` (PB-F1); NO region effect, NO spillover.
  - `sub_target == region R`: emit `hit_resolved(move, move_damage, target, sub_target)` (Part-Break handles PB-F2/PB-F4 on `R.current_break_hp`); TBC applies spillover `current_structure -= max(1, floor(move_damage × break_mult × 0.20 + 0.0001))` (PB-F3). A hit on an already-BROKEN region redirects entirely to Structure at `structure_mult`, no spillover, no re-break (AC-TBC-INT-01e — deferred integration).
- `hit_resolved` fires **exactly once** per DAMAGE-move resolution, AFTER SYN-F4/MOVE-F1/Stagger — never on Repair/Status/SCAN moves, never on Burn ticks. `sub_target` must carry the *chosen* routing value, never a hardcoded `STRUCTURE` (Fixture B is the trap).
- **Enemy enrage (TBC-F7)**: in the enemy pipeline, after DF-1 → MOVE-F1 → Stagger yields `enemy_hit_resolved`, apply `max(1, floor(enemy_hit_resolved × (1 + broken_region_count × 0.12) + 0.0001))` then reduce the active Symbot's structure. Multiplier ∈ {1.00,1.12,1.24,1.36}; count 0 is the identity path. This story unit-tests TBC-F7 with a **stubbed** `broken_region_count` — the full Part-Break accrual chain (AC-TBC-INT-01a…f) is deferred until Part-Break is implemented.

---

## Out of Scope — DEFERRED integration

- **AC-TBC-INT-01a…01f** (Part-Break break-accrual chain: STRUCTURE/region PB-F1/F2/F3, spillover, enrage wiring from a real `broken_region_count`, Basic-Attack-BALANCED, already-broken redirect, DAMAGE_FLOOR spillover) — DEFERRED to the Part-Break epic. This story builds TBC's side (routing math, `hit_resolved` emit, TBC-F7 with a stubbed count) so those integration ACs can be closed when Part-Break lands.
- Story 008: the SYN-F4/DF-1/MOVE-F1/Stagger math that produces `move_damage`.

---

## QA Test Cases

- **AC-TBC-34 Fixture A**: STRUCTURE emit
  - Given: stub subscriber; pre-Stagger 77; attacker Staggered pct 21; STANDARD move; STRUCTURE sub-target
  - When: the move resolves
  - Then: `hit_resolved` fires once with `damage == 60`, the move, the target, `sub_target == STRUCTURE`
  - Edge cases: Repair/Status/SCAN and Burn ticks do NOT emit; `damage == 61` (round) is a FAIL
- **AC-TBC-34 Fixture B**: region emit
  - Given: same pipeline, `sub_target = "left_arm"` (unbroken)
  - When: it resolves
  - Then: `hit_resolved` fires with `sub_target == "left_arm"` (NOT STRUCTURE)
  - Edge cases: `sub_target == STRUCTURE` on a region-targeted hit is the exact hardcoding FAIL
- **TBC-F7 enrage**:
  - Given: `enemy_hit_resolved` post-Stagger; stubbed `broken_region_count` ∈ {0,1,3}
  - When: enrage applies
  - Then: count 1 (hit 43) → 48; count 0 → 43 (identity); count 3 (hit 41) → 55
  - Edge cases: 49 / 56 (round/ceil) are FAILs; enrage at count 0 changing the value is a FAIL

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/subtarget_routing_hit_resolved_test.gd` — must exist and pass. Fixture B (region sub_target != STRUCTURE) required to close the hardcoding trap. Enrage identity (count 0) required.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008 (`move_damage`), Story 001 (`hit_resolved` on the controller/context)
- Unlocks: Story 014 (break events collected from `hit_resolved`); Part-Break epic (AC-TBC-INT-01a…f close against this seam)
