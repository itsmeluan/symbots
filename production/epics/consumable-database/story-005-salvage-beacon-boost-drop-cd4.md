# Story 005: Salvage Beacon per-battle flag & BOOST_DROP (CD-4)

> **Epic**: Consumable Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/consumable-database.md`
**Requirement**: `TR-cdb-004` (BOOST_DROP per-battle flag; one per battle, spent on flee/loss, applies only on victory)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: The DB defines the CD-4 multiply-into-clamp math and the per-battle flag *contract* (the queryable fields); the flag is *owned* by the battle context (TBC), not stored in this DB. The multiplier is read from `effect_params`, not hardcoded.

**Engine**: Godot 4.7 | **Risk**: LOW (CD-4 is float-multiply-into-`clamp()` feeding `randf() <` — GDD states no `floor()`, no float scan needed; `0.25×2.0` and `0.70×2.0` are exact)
**Engine Notes**: The observable contract (Rule 5): `beacon_used_this_battle: bool` (set true on use, cleared at battle end) and `beacon_drop_multiplier_applied: bool` (true only on VICTORY). CD-4 injects `beacon_multiplier` into the Drop System product; unit fixtures isolate it with `cond_mults=[]` (= 1.0). The full drop-condition product + real drop roll is the Drop System's (AC-CD-21, DEFERRED). Any RNG is injected.

**Control Manifest Rules (this layer)**:
- Required: `multiplier` read from `effect_params`; flag state modeled as an injected/stubbed battle context, DI-testable — source: ADR-0003
- Forbidden: hardcoding 2.0; stacking a second Beacon; applying the boost on a non-victory outcome; refunding the Beacon on flee — source: GDD Rule 5
- Guardrail: pure clamp math; flag is a boolean owned by the battle context

---

## Acceptance Criteria

*From GDD Formula CD-4 + Rule 5, EC-CD-05/07, verified by AC-CD-04/11/12:*

- [ ] **CD-4 injects + clamps**: `effective = clamp(base_rate × Π(cond_mults) × beacon_multiplier, 0.0, 1.0)` — `0.25 × 2.0 = 0.50`; `0.70 × 2.0 → clamp = 1.0` — AC-CD-04
- [ ] **Second Beacon rejected** (EC-CD-05): with `beacon_used_this_battle=true`, a second Beacon → `USE_REJECTED`, `qty` unchanged, flag still true; a fresh battle → `USE_OK`, flag true, `qty→0` — AC-CD-11
- [ ] **Spent on flee/loss, never refunded** (EC-CD-07): Beacon consumed on use (`qty 1→0`); `on_battle_end(FLEE)` → `beacon_drop_multiplier_applied==false`, flag cleared, `beacon_qty==0` (NOT refunded); `on_battle_end(WIN)` → `beacon_drop_multiplier_applied==true`, `beacon_qty==0` — AC-CD-12

---

## Implementation Notes

*Derived from GDD Formula CD-4 + Rule 5 + EC-CD-05/07:*

Two pieces: (1) a pure `boost_drop(base_rate, cond_mults, beacon_multiplier)` clamp function (mirrors CD-5's structure); (2) a small battle-context flag model (or stub interface) exposing `beacon_used_this_battle`, `beacon_drop_multiplier_applied`, `use_beacon(qty)`, and `on_battle_end(outcome)`. The flag lives in the battle context (TBC owns it in production); here it is modeled as an injected/stubbed object so AC-CD-11/12 are testable now. **`beacon_qty` assertions are the sole catch** for a flee-refund economy bug (AC-CD-12 discriminator) and a stacking bug (AC-CD-11) — do not omit them. Read `beacon_multiplier` from `effect_params.multiplier`. The end-to-end drop roll with real drop-condition products belongs to the Drop System erratum (AC-CD-21).

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 004: the generic use-transaction gate (context/target/qty) — the Beacon reuses it; this story adds the *second-Beacon* and *outcome* rejection paths
- Story 006: encounter modifiers
- **Drop System erratum** (AC-CD-21, DEFERRED): the real seeded drop roll, the drop-condition product `Π(cond_mults)`, and the live channel — this story isolates the Beacon factor with `cond_mults=[]`

---

## QA Test Cases

- **AC-1** (AC-CD-04): CD-4 injects + clamps
  - Given: Beacon `multiplier=2.0`, `cond_mults=[]`
  - When: `boost_drop(base_rate=0.25, [], 2.0)`
  - Then: `== 0.5` (exact)
  - Edge cases: `boost_drop(0.70, [], 2.0) == 1.0` (clamped from 1.40); an impl omitting `clamp` returns 1.4; an impl treating empty product as 0.0 returns 0.0 for the first case
- **AC-2** (AC-CD-11): second Beacon rejected
  - Given: `beacon_used_this_battle=true`, second Beacon `qty=1`
  - When: use
  - Then: `USE_REJECTED`, `qty==1`, flag still true
  - Edge cases: fresh battle `beacon_used_this_battle=false` → `USE_OK`, flag true, `qty==0`; a stacking impl consumes the second (qty→0)
- **AC-3** (AC-CD-12): spent on flee/loss, never refunded
  - Given: Beacon consumed on use this battle (`beacon_qty` 1→0), `beacon_used_this_battle=true`
  - When: `on_battle_end(FLEE)`
  - Then: `beacon_drop_multiplier_applied==false`, flag cleared, `beacon_qty==0`
  - Edge cases: `on_battle_end(WIN)` → `beacon_drop_multiplier_applied==true`, `beacon_qty==0`; a flee-refund impl wrongly restores `beacon_qty` to 1 (the qty assertion is the sole catch)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/consumable_database/beacon_boost_drop_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema), Story 004 (reuses the use-transaction gate)
- Unlocks: Drop System erratum (AC-CD-21)
