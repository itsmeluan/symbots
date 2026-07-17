# Story 010: Repair (TBC-F6) & SCAN no-op

> **Epic**: Turn-Based Combat
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/turn-based-combat.md` (TBC-F6, Rule 9 SCAN stub, EC-TBC-10/16)
**Requirement**: `TR-tbc-023`, `TR-tbc-028`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0005** (primary, TBC-F6 uses effective energy_power), ADR-0007 (turn/cost path)
**ADR Decision Summary**: A REPAIR move restores `repair_amount = max(5, floor(effective_energy_power × 0.17 + 5 + 0.0001))`, capped at `max_structure`; Energy cost and heat gain always apply (overheal discarded, not rejected). A SCAN move is a turn-consuming no-op: Energy paid, heat gained, action consumed, no damage/status, no crash.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. TBC-F6 scales on **effective** `energy_power` (SYN-F4 via `effective_stat`). `REPAIR_COEFF=0.17`, `REPAIR_BASE=5`, `REPAIR_MIN=5`. `floor(x+0.0001)`, never `round()` (ep 45 → 12 not 13). The anti-stall Energy-brake (`energy_cost > BASE_ENERGY_REGEN`) is a Move-DB content rule (AC-TBC-38, deferred) — not enforced here.

**Control Manifest Rules (Core layer)**:
- Required: effective energy_power via `effective_stat` (SYN-F4 single point); structure/energy/heat are `BattleContext` runtime fields.
- Forbidden: `inline_stat_composition`; `mid_battle_stat_recompute`.

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-27**: TBC-F6 Repair floor. ep 45 → `floor(12.6501)=12` (round/ceil → 13 FAIL); ep 150 → `floor(30.5001)=30` (round → 31 FAIL).
- [ ] **AC-TBC-16**: *(Verifies EC-TBC-10)* Repair caps at max_structure; costs still paid. structure 98/100, ep 45 (repair 12), move cost 15 energy / 8 heat, energy 60, heat 20 → energy 45, structure `min(100,110)=100` (overheal discarded), heat 28. At exactly full: legal, wasteful, costs apply.
- [ ] **AC-TBC-39**: *(Verifies EC-TBC-16)* SCAN resolves as a turn-consuming no-op. move `energy_cost=8`, owning part `heat_generation=6`, user energy 50 / heat 10 → energy 42, heat 16, no damage, no status, action consumed (enemy acts next), no crash.

---

## Implementation Notes

*Derived from ADR-0005 TBC-F6 + Rule 9 SCAN stub:*

- Repair: `repair_amount = max(5, floor(effective_stat(user, "energy_power") × 0.17 + 5 + 0.0001))`; then `current_structure = min(max_structure, current_structure + repair_amount)`. Pay the move's Energy cost and apply Formula-5 heat gain **before/regardless of** overheal being discarded — costs always apply, even at full structure (not rejected).
- SCAN: pay Energy, apply heat gain (Rule 5d), consume the action, apply no damage and no status, do not crash. The reveal payload (break-region hints) is Move DB's (AC-MDB-10) — out of scope; this is the runtime turn/cost stub only.
- Both are DAMAGE-free — they must NOT emit `hit_resolved` (Story 009's non-DAMAGE exclusion).

---

## Out of Scope

- AC-TBC-38 (REPAIR Energy-brake content validation) — Move DB content validator, DEFERRED.
- SCAN reveal-content payload — Move DB AC-MDB-10.
- Story 006: the heat-gain formula itself (invoked here; owned there).

---

## QA Test Cases

- **AC-TBC-27**: Repair floor
  - Given: effective energy_power 45; then 150
  - When: `repair_amount` computed
  - Then: 12 (NOT 13); 30 (NOT 31)
- **AC-TBC-16**: cap + costs
  - Given: structure 98/100, ep 45 (repair 12), cost 15 energy / 8 heat, energy 60, heat 20
  - When: Repair used
  - Then: energy 45; structure 100 (overheal discarded); heat 28
  - Edge cases: at exactly full structure — repair legal, costs still applied, not rejected
- **AC-TBC-39**: SCAN no-op
  - Given: SCAN move energy_cost 8, part heat_generation 6, energy 50, heat 10
  - When: used
  - Then: energy 42, heat 16, no damage, no status, action consumed, no crash
  - Edge cases: SCAN treated as unknown-behavior crash/rejection is a FAIL; free action (no cost) is a FAIL

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/repair_scan_test.gd` — must exist and pass. Repair floor discriminators + overheal-cap-with-costs + SCAN cost/no-op required.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (runtime state), Story 006 (heat gain), Story 008 (pipeline context)
- Unlocks: None (leaf behaviour)
