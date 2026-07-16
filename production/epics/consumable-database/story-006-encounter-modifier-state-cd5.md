# Story 006: Encounter modifier state & MODIFY_ENCOUNTER_RATE (CD-5)

> **Epic**: Consumable Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: *(set by /dev-story when implementation begins)*

## Context

**GDD**: `design/gdd/consumable-database.md`
**Requirement**: `TR-cdb-005` (MODIFY_ENCOUNTER_RATE modifier frozen during battle — no step countdown — resumes after)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Content Resource Loading & Schema Mapping
**ADR Decision Summary**: The DB defines the CD-5 clamp math and the `EncounterModifierState` counter contract (sole mutator `on_overworld_step()`); the state is *owned* by the overworld/traversal context, modeled here as a testable `RefCounted`.

**Engine**: Godot 4.7 | **Risk**: LOW (CD-5 is float-multiply-into-`clamp()`; GDD IEEE-754 note: use base `0.15`/`0.35` — `0.15×0.1`, `0.15×2.5`, `0.35×2.5` are exact; avoid `0.35×0.1`/`0.07×2.5` for `==` asserts)
**Engine Notes**: `EncounterModifierState` holds `(rate_multiplier, steps_remaining)`. Its **sole mutator is `on_overworld_step()`** (decrement, expire at 0). It exposes **no battle-turn handler** — the "frozen in battle" property is *structural* (battle turns never call it), asserted by construction (AC-CD-14). Only one modifier active — a second use **replaces** (latest wins, EC-CD-06). Querying with no active modifier returns the inert default and never crashes.

**Control Manifest Rules (this layer)**:
- Required: `rate_multiplier`/`duration_steps` read from `effect_params`; state is a DI-testable `RefCounted` — source: ADR-0003
- Forbidden: adding a battle-turn handler to the counter (would break the structural freeze); stacking modifiers; global RNG — source: GDD Rule 6 / AC-CD-14
- Guardrail: single active modifier; countdown advances on overworld steps only

---

## Acceptance Criteria

*From GDD Formula CD-5 + Rule 6, EC-CD-06/08, verified by AC-CD-09/10/13/14:*

- [ ] **CD-5 Signal Jammer**: `(0.1, 20)`, `base=0.15` → `effective == 0.015`, `steps_remaining==20`; after 3 steps → `17` — AC-CD-09
- [ ] **CD-5 Scrap Lure**: `(2.5, 15)`, `base=0.15` → `0.375` (no clamp); `base=0.35` (DENSE) → `0.875` (exact, NOT clamped to 1.0) — AC-CD-10
- [ ] **Second modifier replaces** (EC-CD-06): active Jammer (`steps=5`) + use Lure (`base=0.35`) → `modifier_type==LURE`, `steps_remaining==15`, `effective==0.875`, Lure `qty==0`, old Jammer gone — AC-CD-13
- [ ] **Countdown advances on overworld steps only + no-crash** (EC-CD-08): `EncounterModifierState` sole mutator `on_overworld_step()`; no battle-turn handler; querying with no active modifier returns inert default, raises nothing — AC-CD-14

---

## Implementation Notes

*Derived from GDD Formula CD-5 + Rule 6 + States and Transitions:*

Two pieces: (1) a pure `modify_encounter_rate(base_rate, rate_multiplier)` clamp function; (2) `EncounterModifierState extends RefCounted` holding `modifier_type`, `rate_multiplier`, `steps_remaining`, with `on_overworld_step()` (decrement + expire), `effective_rate(base_rate)`, and an `apply(def)` that *replaces* any active modifier (latest wins). **The class must expose no battle-turn method** — that absence is the AC-CD-14 structural-freeze assertion. Read `rate_multiplier`/`duration_steps` from `effect_params`. The live overworld step wiring + real encounter roll is the Encounter Zone / Overworld Navigation erratum (AC-CD-22, DEFERRED). Save/reload persistence of an active modifier is Overworld Nav / Save-Load's call (OQ-CD-4), out of scope.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Story 004: generic context validation (a Jammer/Lure is `WORLD`-context — reuses that gate)
- Story 005: Beacon / BOOST_DROP
- **Encounter Zone + Overworld Navigation erratum** (AC-CD-22, DEFERRED): the live per-step countdown during real traversal, the EZ-1 encounter roll, save/reload persistence — this story delivers the state machine + math only

---

## QA Test Cases

- **AC-1** (AC-CD-09): CD-5 Jammer
  - Given: Jammer `(0.1, 20)`, `base=0.15`
  - When: apply, then 3× `on_overworld_step()`
  - Then: `effective == 0.015` (exact), `steps_remaining` 20 → 17
  - Edge cases: a `0.5` impl gives 0.075; a non-decrementing impl leaves 20
- **AC-2** (AC-CD-10): CD-5 Lure
  - Given: Lure `(2.5, 15)`
  - When: `effective_rate(0.15)` and `effective_rate(0.35)`
  - Then: `0.375` and `0.875` (both exact, DENSE case NOT clamped to 1.0)
  - Edge cases: a `3.0×` impl gives `0.35×3.0 = 1.05 → 1.0` (≠ 0.875)
- **AC-3** (AC-CD-13): second modifier replaces
  - Given: active Jammer (`steps_remaining=5`), use Scrap Lure (`base=0.35`)
  - When: apply
  - Then: `modifier_type==LURE`, `steps_remaining==15`, `effective==0.875`, Lure `qty==0`, old Jammer gone
  - Edge cases: a stacking impl gives `0.35×0.1×2.5 = 0.0875`; a retain-old impl leaves JAMMER/5
- **AC-4** (AC-CD-14): countdown + structural freeze + no-crash
  - Given: `EncounterModifierState`, Jammer `steps=20`
  - When: 3× `on_overworld_step()`; (a battle occurs — zero calls to the counter); 1× `on_overworld_step()`
  - Then: `steps_remaining` 20 → 17 → 16
  - Edge cases: 8× from 20 → 12; querying `steps_remaining`/`effective_rate` with no active modifier returns inert default, raises nothing; a per-step off-by-one gives 17 at step-2 or 13 in the 8-step case; the class exposes **no** battle-turn handler (structural-freeze assertion)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/consumable_database/encounter_modifier_state_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (schema), Story 004 (reuses `WORLD`-context validation)
- Unlocks: Encounter Zone + Overworld Navigation erratum (AC-CD-22)
