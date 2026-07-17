# Epic: Turn-Based Combat System

> **Layer**: Core
> **GDD**: design/gdd/turn-based-combat.md
> **Architecture Module**: Turn-Based Combat (Core)
> **Status**: Complete (2026-07-17 — lean per-story gate)
> **Stories**: 14 stories — see `## Stories` below

## Overview

Turn-Based Combat is the battle orchestrator: the FSM that sequences rounds, resolves
moves and damage, applies statuses/heat/energy, and emits the battle-outcome seam. It
reads a **LOCKED snapshot** at BATTLE_INIT (Assembly `final_stat` + frozen synergy block
via `evaluate_silent`) and owns the only mutable battle state — per-combatant runtime
`current_structure/energy/heat` — which is discarded synchronously after the 8-field
`battle_ended` emit returns. The action seam is event-driven (player turn parks at
`ACTION_PENDING`; enemy turn runs a synchronous `EnemyAI.request_move`). The damage
pipeline is DF-1 → MOVE-F1 power-tier → Stagger reduction → break-bias routing, with
SYN-F4-clamped stats on both sides. This is the largest and highest-risk Core epic
(42 requirements; the dual-shape `battle_ended` seam is the architecture's single
highest-risk signal contract).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Turn-Based Combat State Machine & Battle Orchestrator | `BattleController` autoload (slot 11) hosting `is_battle_active` + enum-`match` FSM; per-battle `BattleContext` dropped synchronously after the `battle_ended` cascade; event-driven action seam | HIGH |
| ADR-0005: Stat Pipeline & Battle Snapshot | Reads the frozen `CombatantSnapshot`; in-battle changes are TBC-owned modifiers layered on `effective_stat()`, never recomputes the pipeline | MEDIUM |
| ADR-0006: RNG Service & Determinism | Randomness (status procs, crit) arrives as an injected `RandomNumberGenerator`; `src/core` stays pure — only the orchestrator vends RNG | MEDIUM |
| ADR-0002: Event Bus & Signal Architecture | 8-field `battle_ended` (COMBAT) distinct from the 2-field (WORLD) shape; synchronous emit + teardown contract; diagnostics via injected LogSink | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-tbc-001 | Three-Symbot team structure: exactly 1 active, 2 benched; only active acts/targeted | ADR-0007 ✅ |
| TR-tbc-002 | Assembly final_stat snapshot at battle start, immutable for battle duration | ADR-0005 ✅ |
| TR-tbc-003 | Synergy evaluate_silent() called once per Symbot, frozen cached_bonus_block contract | ADR-0005 ✅ |
| TR-tbc-004 | battle_ended 8-field payload (outcome, enemy_id, fired_break_events, xp_value, completion_bonus_xp, is_first_boss_defeat, enemy_level, deployed_symbot_ids) | ADR-0002 ✅ |
| TR-tbc-005 | Synchronous battle_ended emit; runtime state discarded only after all subscribers return | ADR-0002 ✅ |
| TR-tbc-006 | Initiative recomputed every round start; tiebreak player acts first | ADR-0007 ✅ |
| TR-tbc-007 | Turn phases ordered: heat decay, energy recharge, status ticks, action, turn-end decrement | ADR-0007 ✅ |
| TR-tbc-008 | Overheat skips action only; sets heat 20 carry-in; preserves turn bookkeeping except decay | ADR-0007 ✅ |
| TR-tbc-009 | Energy recharge: min(capacity, current+10+recharge_stat) per turn start | ADR-0007 ✅ |
| TR-tbc-010 | Basic Attack 0 energy always available; move 4 may be null; no soft-lock | ADR-0007 ✅ |
| TR-tbc-011 | Damage pipeline: DF-1 → MOVE-F1 power-tier → Stagger reduction → break-bias routing | ADR-0005 ✅ |
| TR-tbc-012 | SYN-F4 clamped stat on both sides before DF-1; passive aura frozen at BATTLE_INIT | ADR-0005 ✅ |
| TR-tbc-013 | hit_resolved(move, damage, target, sub_target) 4-arg hook post-Stagger carries sub_target | ADR-0002 ✅ |
| TR-tbc-014 | Benched Symbots: frozen heat/energy/statuses per Symbot; resume on return | ADR-0007 ✅ |
| TR-tbc-015 | Forced switch free on DOWNED; voluntary switch consumes turn | ADR-0007 ✅ |
| TR-tbc-016 | Flee WILD-only; consumes action; no drops/XP | ADR-0007 ✅ |
| TR-tbc-017 | Status decrement at turn-end; expire at 0; Burn ticks at turn-start | ADR-0007 ✅ |
| TR-tbc-018 | Reapplication newest-wins: refresh duration AND re-snapshot processing | ADR-0007 ✅ |
| TR-tbc-019 | Unknown passive effect ID logged error, skipped, no crash | ADR-0002 ✅ |
| TR-tbc-020 | Move pool: Basic Attack + WEAPON + HEAD + ARMS; slot 4 nullable | ADR-0007 ✅ |
| TR-tbc-021 | Three statuses: Shock(Volt,2T), Burn(Thermal,2T), Stagger(Kinetic,2T); no stacking | ADR-0007 ✅ |
| TR-tbc-022 | Heat: cap 100; Overheat 10% self-damage + skip turn + carry 20 | ADR-0007 ✅ |
| TR-tbc-023 | Repair: max(5, floor(energy_power*0.17+5+eps)); capped max_structure; costs always apply | ADR-0005 ✅ |
| TR-tbc-024 | Enemy: .get(stat,0) reads; no heat/energy; moves always available | ADR-0007 ✅ |
| TR-tbc-025 | is_build_valid() precondition pre-snapshot; invalid build refuses entry with battle_start_refused | ADR-0007 ✅ |
| TR-tbc-026 | Type multiplier T baked into DF-1 output before Stagger/break-bias | ADR-0005 ✅ |
| TR-tbc-027 | Burn bypasses DF-1: fixed potency damage; armor/resistance/type never reduce | ADR-0007 ✅ |
| TR-tbc-028 | SCAN no-op: costs paid, heat applied, action consumed, no damage/status | ADR-0007 ✅ |
| TR-tbc-029 | Item use: targets living Symbot; success consumes turn; rejection pre-gates, no cost | ADR-0007 ✅ |
| TR-tbc-030 | Item action: zero heat, zero energy cost; Overheat prevents use preventively | ADR-0007 ✅ |
| TR-tbc-031 | Victory checked before heat gain; kill+self-down = VICTORY, no self-damage | ADR-0007 ✅ |
| TR-tbc-032 | Overheat-skip turn: status ticks run; turn-end decrements; bookkeeping except decay | ADR-0007 ✅ |
| TR-tbc-033 | SYNERGY_POWER_BUDGET=40, SYNERGY_DEFENSE_BUDGET=50; DF-1 range [1,225] boss ceiling 164 | ADR-0005 ✅ |
| TR-tbc-034 | DOWNED clears all statuses; benched status frozen mid-battle | ADR-0007 ✅ |
| TR-tbc-035 | Passive ON_HIT at hit_resolved; ON_BATTLE_START once at BATTLE_INIT; PERSISTENT no re-fire | ADR-0007 ✅ |
| TR-tbc-036 | PERSISTENT aura captured at BATTLE_INIT into frozen_passive_aura; held whole battle | ADR-0005 ✅ |
| TR-tbc-037 | Registry dispatch: alphabetical effect ID order; stacking_policy controls per-source refires | ADR-0007 ✅ |
| TR-tbc-038 | Shock magnitude positive; TBC-F1 subtracts it (never pre-negate) | ADR-0007 ✅ |
| TR-tbc-039 | Enemy AI request_move(battle_state) returns one legal move at ACTION_PENDING | ADR-0007 ✅ |
| TR-tbc-040 | is_battle_active() true BATTLE_INIT → battle_ended emission, false otherwise | ADR-0007 ✅ |
| TR-tbc-041 | Battle end: all runtime state discarded; fresh snapshots/evaluate_silent next battle | ADR-0007 ✅ |
| TR-tbc-042 | Consumed turn → next combatant by initiative; free action does not advance turn order | ADR-0007 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | BattleController FSM host & teardown | Logic | Complete | ADR-0007 |
| 002 | Battle-start sequence & build validity | Logic | Complete | ADR-0007 |
| 003 | Move pool & action availability | Logic | Complete | ADR-0007 |
| 004 | Initiative & round structure (Shock floor) | Logic | Complete | ADR-0007 |
| 005 | Turn anatomy, recharge & heat decay | Logic | Complete | ADR-0007 |
| 006 | Heat gain & Overheat | Logic | Complete | ADR-0007 |
| 007 | Status system model & lifecycle | Logic | Complete | ADR-0007 |
| 008 | Damage pipeline: SYN-F4 → DF-1 → MOVE-F1 → Stagger | Logic | Complete | ADR-0005 |
| 009 | Sub-target routing, `hit_resolved` & enemy enrage | Logic | Complete | ADR-0005 |
| 010 | Repair (TBC-F6) & SCAN no-op | Logic | Complete | ADR-0005 |
| 011 | Switch, flee, bench-freeze & down-ordering | Logic | Complete | ADR-0007 |
| 012 | Use-item action | Logic | Complete | ADR-0007 |
| 013 | Passive effect registry & dispatch | Logic | Complete | ADR-0007 |
| 014 | Battle end — 8-field `battle_ended` & teardown | Integration | Complete | ADR-0002 |

13 Logic + 1 Integration. Implement in order — each story's `Depends on:` field names its prerequisites (Story 001 first).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/turn-based-combat.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The 8-field `battle_ended` payload and its synchronous-emit / discard-after-return teardown
  contract have integration tests; the COMBAT (8-field) and WORLD (2-field) shapes are proven
  non-confusable by a subscriber
- The turn-phase ordering, Overheat skip, newest-wins status reapplication, and DF-1→MOVE-F1→
  Stagger pipeline each have discriminating GUT fixtures
- `battle_start_refused` is emitted for an invalid build (is_build_valid precondition), verified by test

## Next Step

**Epic complete (2026-07-17).** All 14 stories implemented and closed through the lean per-story gate (`/code-review` + `/story-done`, inline as godot-gdscript-specialist). Full GUT suite **762/762 green, 4268 asserts** (Godot 4.7 · GUT 9.7.1).

Gate closed 5 test-coverage gaps the green suite could not surface on its own (the test-file headers carry AC IDs that drifted from the GDD, so coverage was mapped by scenario content):
- **AC-TBC-11** (Story 006) — victory resolves before the killing move's heat recoil: 1 discriminating test added.
- **AC-TBC-10 / AC-TBC-18** (Story 011) — Burn-kill-at-turn-start forced switch (both scenarios), bench-status freeze, and DOWN-clears-all-statuses at integration level: 4 discriminating tests added.

One ADVISORY carried to `docs/tech-debt-register.md`: `BattleController` ships as a DI `RefCounted`, not the ADR-0007 slot-11 autoload (no behavioral impact; revisit at Presentation-tier battle entry). Two in-story location/seed deviation notes recorded (Story 001/014 unit-vs-integration test path; Story 002 live enemy pools).
