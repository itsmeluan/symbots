# Story 013: Passive effect registry (Rule 13) & dispatch

> **Epic**: Turn-Based Combat
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 13, Rule 10 STAT_AURA path, EC-TBC-08)
**Requirement**: `TR-tbc-019`, `TR-tbc-035`, `TR-tbc-036`, `TR-tbc-037`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary), ADR-0002 (dispatch on `hit_resolved`), ADR-0005 (frozen_passive_aura)
**ADR Decision Summary**: TBC owns the registry mapping effect IDs (from Synergy `effects` + Assembly passive pool) to combat behaviors, keyed by trigger (`ON_HIT`, `ON_BATTLE_START`, `ON_TURN_START`, `PERSISTENT`, `ON_OVERHEAT`). Unknown IDs are logged as a content error and skipped, never a crash. Multiple passives on one event fire in ascending alphabetical effect-ID order; `stacking_policy` controls per-source refires. PERSISTENT is an application mode (sieved out of event listeners) whose STAT_AURA deltas enter `frozen_passive_aura` at BATTLE_INIT.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: ADR headers say 4.6; project pinned 4.7. Snapshot for riders is **pre-synergy** `final_stat["processing"]`. Passive procs must tolerate the widened 4-arg `hit_resolved(move, damage, target, sub_target)` (passives ignore `sub_target`). ON_OVERHEAT dispatch is deferred (no MVP content) — implement the trigger routing but no seed content required.

**Control Manifest Rules (Core layer)**:
- Required: `frozen_passive_aura` captured once at BATTLE_INIT (parallel to `frozen_synergy_delta`), summed per stat across UNIQUE-deduped PERSISTENT auras, fed through the SYN-F4 clamp (`effective_stat`).
- Forbidden: `inline_stat_composition`; `mid_battle_stat_recompute`.

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-14**: *(Verifies EC-TBC-08 / Synergy EC-SYN-05 obligation)* unknown effect ID: log + skip, no crash. Effect list `[&"volt_shock_on_hit", &"unknown_passive_xyz"]` → `volt_shock_on_hit` resolves; exactly one content error logged naming the unknown ID; no crash; remaining effects unaffected.
- [ ] **AC-TBC-29**: `&"volt_shock_on_hit"` fires on any DAMAGE move; applies Shock **duration 1** (not 2); snapshot = user's pre-synergy `final_stat["processing"]` at the hit. Negative: REPAIR moves do not trigger it.
- [ ] **AC-TBC-30**: `&"thermal_burn_on_weapon"` fires on WEAPON-slot DAMAGE moves only → Burn (2 turns); HEAD-slot DAMAGE move → NOT applied.
- [ ] **AC-TBC-40**: registry dispatch handles ON_TURN_START and ON_BATTLE_START, not only ON_HIT. Synthetic entries `{&"test_battle_start", ON_BATTLE_START, +counter}` and `{&"test_turn_start", ON_TURN_START, +counter}` → after a battle start and 2 turns, battle-start counter 1, turn-start counter 2, each at the correct phase.

---

## Implementation Notes

*Derived from ADR-0007 Rule 13 + trigger dispatch:*

- Registry entry: `{ effect_id: StringName, trigger: Enum, behavior }`. Seed MVP set: `volt_shock_on_hit` (ON_HIT any DAMAGE → Shock 1T), `thermal_burn_on_weapon` (ON_HIT WEAPON-slot → Burn 2T), `kinetic_stagger_on_hit` (ON_HIT any DAMAGE → Stagger 1T). Riders call `apply_status` (Story 007) with the user's pre-synergy `final_stat["processing"]` snapshot.
- Trigger routing: `ON_HIT` fires on `hit_resolved` (scope ANY_DAMAGE / WEAPON_ONLY narrows which moves qualify); `ON_BATTLE_START` fires once in `BATTLE_INIT` before turn 1; `ON_TURN_START` at the carrier's turn-start; `PERSISTENT` is NOT an event — sieve it out of event registration and capture STAT_AURA deltas into `frozen_passive_aura` at BATTLE_INIT (held whole battle, no re-fire, no teardown); `ON_OVERHEAT` routing exists but has no MVP content.
- Unknown effect ID (from Synergy `effects` or Assembly passive pool with no registry entry): log exactly one content error naming the ID via the injected LogSink, skip it, continue processing the rest of the pool — never crash, never silent-swallow.
- Firing order: when multiple passives fire on one event, resolve in ascending alphabetical effect-ID order; `stacking_policy` — `UNIQUE_PER_TRIGGER` dedups across sources (once per event), `UNIQUE` once at application, `STACKABLE` per source.
- `frozen_passive_aura` is empty in MVP (all 3 seed riders are STATUS_RIDER/ON_HIT) but the wiring must feed the SYN-F4 clamp so the first STAT_AURA Core passive reaches the damage pipeline (Story 008 reads it via `effective_stat`).

---

## Out of Scope

- Story 007: `apply_status` itself (riders call it).
- Story 008/009: the damage pipeline / `hit_resolved` emit that ON_HIT riders subscribe to (this story owns the dispatch, not the emit).
- ON_OVERHEAT seed content (no MVP content — routing only).

---

## QA Test Cases

- **AC-TBC-14**: unknown ID
  - Given: registry lacks `&"unknown_passive_xyz"`; effect list `[&"volt_shock_on_hit", &"unknown_passive_xyz"]`
  - When: triggers fire
  - Then: `volt_shock_on_hit` resolves; exactly one content error logged naming the unknown ID; no crash; remaining effects unaffected
  - Edge cases: unknown ID must not halt processing of the rest of the pool
- **AC-TBC-29**: volt_shock_on_hit
  - Given: a Symbot carrying `volt_shock_on_hit`, user processing snapshot
  - When: a DAMAGE move hits; then a REPAIR move
  - Then: Shock applied duration 1 (not 2), snapshot = pre-synergy processing; REPAIR does not trigger
- **AC-TBC-30**: thermal_burn_on_weapon
  - Given: carrier with `thermal_burn_on_weapon`
  - When: a WEAPON-slot DAMAGE move hits; then a HEAD-slot DAMAGE move
  - Then: WEAPON → Burn 2T; HEAD → not applied
- **AC-TBC-40**: trigger dispatch
  - Given: synthetic ON_BATTLE_START + ON_TURN_START counter entries on a Symbot
  - When: a battle starts and that Symbot takes 2 turns
  - Then: battle-start counter 1, turn-start counter 2, each fired at the correct phase
  - Edge cases: only-ON_HIT dispatch (counters read 0) is a FAIL

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tbc/passive_effect_registry_test.gd` — must exist and pass. Unknown-ID log-and-continue + ON_BATTLE_START/ON_TURN_START counters required. Stub logger captures the content-error message.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 (`apply_status` for riders), Story 002 (BATTLE_INIT for ON_BATTLE_START + aura capture), Story 009 (`hit_resolved` for ON_HIT)
- Unlocks: None (Synergy/Passive content authoring consumes the registry, but that is content, not a TBC story)
