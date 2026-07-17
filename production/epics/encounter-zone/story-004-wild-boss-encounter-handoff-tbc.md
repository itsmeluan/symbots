# Story 004: WILD/BOSS encounter handoff to TBC

> **Epic**: Encounter Zone System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/encounter-zone.md`
**Requirement**: `TR-ez-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Turn-Based Combat State Machine & Battle Orchestrator (primary); ADR-0002: Event Bus & Signal Architecture
**ADR Decision Summary**: Encounter Zone hands the resolved `enemy_id` + class context to TBC's existing battle-start entry; TBC instantiates the enemy and owns the battle. The handoff is a lateral call at a battle-lifecycle boundary, consistent with the FSM's emit seam.

**Engine**: Godot 4.7 | **Risk**: MEDIUM
**Engine Notes**: This is a seam test against a **stub TBC** — no live `BattleController`. The contract is a single call carrying `(enemy_id, is_boss, fleeable)`: WILD is fleeable (TBC Rule 7), BOSS is not. The BOSS scenario guards against a hardcoded `fleeable = true` that the WILD scenario alone cannot catch.

**Control Manifest Rules (this layer)**:
- Required: pure core resolver in `src/core/encounter_zone/`; the handoff is an injected callback/interface (not a hard reference to a TBC autoload from core).
- Forbidden: `src/core/` reaching into a live autoload; `push_warning`/`push_error` from `src/`.
- Guardrail: no mid-battle re-entry — the handoff fires once per resolved encounter.

---

## Acceptance Criteria

*From GDD `design/gdd/encounter-zone.md`, scoped to this story:*

- [ ] **AC-EZ-15** (BLOCKING, Integration): correct handoff — both classes. Stub TBC records `(enemy_id, is_boss, fleeable)`. **Scenario A (WILD):** GIVEN pool `{bolt_skitter w8, iron_crawler w2}`, a stub EZ-1 forced to `triggered = true` and EZ-2 seeded to pick `bolt_skitter`, THEN stub TBC receives exactly one call `("bolt_skitter", false, true)` (WILD is fleeable). **Scenario B (BOSS):** GIVEN an `OPEN` boss `boss_id = "zone_boss"`, player initiates the boss encounter, THEN stub TBC receives `("zone_boss", true, false)` (boss not fleeable). Scenario B guards against a `return true` fleeable flag Scenario A alone cannot catch.

---

## Implementation Notes

*Derived from ADR-0007 + ADR-0002 Implementation Guidelines:*

- Expose a handoff that, on a resolved WILD encounter, calls the injected TBC interface once with `(enemy_id, is_boss = false, fleeable = true)`; on a boss encounter the player initiates against an *accessible* (`UNLOCKED`) boss, call with `(boss_id, is_boss = true, fleeable = false)`.
- Derive `fleeable` from the encounter *class*, not a constant — WILD ⇒ fleeable, BOSS ⇒ not. This is the whole point of Scenario B.
- The WILD path composes Story 001 (EZ-1 trigger) + Story 002 (EZ-2 select) + Story 003 (filter). Use the forced-trigger stub for EZ-1 (a seed where EZ-1 never fires would make the test vacuously pass) and a seeded EZ-2 that deterministically picks `bolt_skitter`.
- The boss path only requires an `OPEN` (already-`UNLOCKED`) boss for this story; the WIN_COUNT/sequenced-gate accessibility logic is Stories 005–007. Do not re-implement gate evaluation here — assume the boss is offerable.
- A sentinel `StringName("")` result (Story 003) must produce **no** handoff call (that assertion is the deferred AC-EZ-42; here, simply never call TBC on a sentinel).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 005–007: boss-gate accessibility (WIN_COUNT thresholds, sequencing, repeat policy, param validation). This story uses an already-`OPEN`/`UNLOCKED` boss.
- **Deferred integration (not this story, not any MVP story):** AC-EZ-42 (sentinel → no transition, live), AC-EZ-41/45 (Overworld Navigation terrain-step driving), AC-EZ-46 (reachable boss map presence). These await Overworld Navigation / Zone & World Map and are captured in the epic's deferred-integration note.

---

## QA Test Cases

*Automated GUT specs — the developer implements against these.*

- **AC-EZ-15 A (WILD)**:
  - Given: pool `{bolt_skitter w8, iron_crawler w2}`; stub EZ-1 forced `triggered = true`; EZ-2 seeded to pick `bolt_skitter`; stub TBC recording calls.
  - When: one encounter resolves.
  - Then: exactly one TBC call `("bolt_skitter", false, true)`.
  - Edge cases: assert call count == 1 (no double-handoff).
- **AC-EZ-15 B (BOSS)**:
  - Given: an `OPEN` boss `boss_id = "zone_boss"` (accessible); stub TBC.
  - When: player initiates the boss encounter.
  - Then: exactly one TBC call `("zone_boss", true, false)`.
  - Edge cases: `fleeable == false` is the discriminator against a hardcoded-true flag — assert it explicitly.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/encounter_zone/tbc_handoff_test.gd` — must exist and pass (stub TBC; no live scene).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (EZ-2 selection) + Story 003 (validated pool).
- Unlocks: None (terminal WILD-path story for MVP; live wiring is deferred integration).
