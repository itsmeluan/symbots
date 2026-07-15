# ADR-0007: Turn-Based Combat State Machine & Battle Orchestrator

## Status
Accepted

## Date
2026-07-14

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (runtime FSM / GDScript orchestration — turn-based; no physics, rendering, or navigation surface) |
| **Knowledge Risk** | LOW–MEDIUM — pure GDScript control flow. The only post-cutoff-adjacent surfaces (autoload construction order, typed `Signal.connect`, `StringName`, `RefCounted`) are all pre-4.4 stable and already exercised by ADR-0002/0004/0005/0006. The 4.6 dual-focus concern lives in ScreenManager (ADR-0004), not here. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`; ADR-0002, ADR-0004, ADR-0005, ADR-0006; `design/gdd/turn-based-combat.md` |
| **Post-Cutoff APIs Used** | None. Autoload registration, typed signals, `RefCounted`, `match` dispatch are all pre-4.4. |
| **Verification Required** | (1) `BattleController` autoload registered as slot 11 does **no** `_ready` work (grep + inertness GUT test — order-immune by construction). (2) `submit_action` re-entrancy guard: a call while `_state != ACTION_PENDING` is a no-op (GUT). (3) `BattleContext` ref is null after the `battle_ended` cascade returns (teardown GUT test). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (**Accepted** — `combat_battle_end` producer contract, synchronous-emit teardown, `is_battle_active` quiesce gate); ADR-0004 (**Accepted** — autoload roster, ScreenManager transition ownership, Overworld keep-alive); ADR-0005 (**Accepted** — `CombatantSnapshot`, `compute_damage`, `is_build_valid`, `apply_battle_result`, SYN-F4 composition point); ADR-0006 (**Accepted** — `next_seed`/`make_rng` vends, orchestrator injection discipline) |
| **Enables** | ADR-0008 (Touch UI — Combat UI binds to `submit_action`, `is_battle_active`, and TBC's turn/damage/status/overheat/break signals) |
| **Blocks** | Combat implementation epic; Drop System integration (needs the `battle_ended` break-set contract); Enemy AI integration (needs the `request_move` call site + injected seed); Combat UI |
| **Ordering Note** | Third Core-tier ADR; the last before Presentation. **Amends** the accepted `boot_initialization` stance (fixed roster 10 → 11) and **adds a carve-out** to `stat_formula_home` — this is the "ADR-0004 roster amendment" branch ADR-0005 §Risks explicitly permitted for the host seam. Resolves the deferred cross-review **C-3** seam. |

## Context

### Problem Statement

Four accepted ADRs name "TBC" as a signal producer and contract consumer, but **none places the orchestrator**. ADR-0002 §4 requires `is_battle_active` to live on a *persistent* host — never on the Battle scene node, which is `queue_free()`d at teardown and would race the query (`is_queued_for_deletion()` window). ADR-0005 §Risks deferred the placement to this ADR verbatim: *"ADR-0007 must place the TBC orchestrator (persistent node under Game root, or an ADR-0004 roster amendment) and wire `CoreProgression.apply_battle_result` at construction."* This is the last open Foundation/Core seam (cross-review **C-3**).

Beyond placement, the runtime battle FSM itself is unspecified: the turn-based-combat GDD defines the states, turn anatomy, and battle-start/end sequences, but not *what object runs them*, *how the FSM pauses for player input*, or *where the two RNG vends (crit roll, AI seed) are called from*. This ADR resolves all of it.

### Constraints (binding accepted stances)

- `combat_battle_end` — TBC is the **producer** of the 8-field `battle_ended`; synchronous emit; battle state discarded only after `emit()` returns; payload self-sufficient (`subscriber_ordering_dependency` forbidden).
- `combatant_snapshot` — battle reads the frozen `CombatantSnapshot`; `effective_stat()` is THE SYN-F4 point (`inline_stat_composition` forbidden).
- `mid_battle_stat_recompute` (forbidden) — after BATTLE_INIT, no `derive`/`evaluate*`; in-battle modifiers layer *on top of* `effective_stat()`; no live `SymbotBuild`/evaluator reference in battle.
- `damage_computation` — `compute_damage` is deterministic; `crit_mult` is passed **in**, never rolled inside DF-1.
- `rng_vending` + `rng_service_in_formula_code` (forbidden) — only orchestrators call `RngService`; TBC is a **named** sanctioned orchestrator (`next_seed(&"crit")`, `next_seed(&"ai")`).
- `core_progression_gate` — `is_build_valid` is the battle-start precondition; `apply_battle_result` consumes the payload fields, host-agnostic.
- `screen_transitions` + `unowned_scene_transition` (forbidden) — TBC **never** transitions screens; ScreenManager tears the Battle screen down via `queue_free()` on `EventBus.encounter_resolved` (ADR-0004 §3).
- `autoload_ready_work` (forbidden) — an autoload host must do nothing in `_ready`.

### Requirements (from `turn-based-combat.md`)

- Run the FSM: BATTLE_INIT → ROUND_START → TURN_ACTIVE → ACTION_PENDING → RESOLVING → TURN_END → BATTLE_END, with the FORCED_SWITCH detour (Rule 4 / States table).
- Battle-start (Rule 2): `is_build_valid` precondition → `battle_start_refused` on failure (no runtime state, no `battle_ended`); ×3 snapshot + `evaluate_silent`; enemy instantiation; runtime-state init; round-1 initiative.
- Own the runtime state the data layer refuses to hold: `current_structure`/`current_energy`/`current_heat` per combatant, region break pools, statuses, the Beacon flag (Rule 1/8).
- Route damage (Rule 10): SYN-F4 via `effective_stat()` → `compute_damage(..., crit_mult)` → MOVE-F1 → Stagger → sub-target routing / enemy enrage; crit rolled by TBC.
- Enemy AI hook at enemy ACTION_PENDING (Rule "States"): `request_move(battle_state)` + injected seed.
- Emit the 8-field `battle_ended` synchronously (Rule 12); discard state after the cascade.

## Decision

Five parts.

### 1. Host — `BattleController` autoload (slot 11)

A new thin autoload `BattleController` (`class_name` not required; registered as an autoload singleton) is added as **slot 11**, amending ADR-0004's fixed roster of 10. It holds only: `is_battle_active: bool`, `_state: BattleState`, and a reference to the current `BattleContext` (null outside battle). It does **no** work in `_ready` (`autoload_ready_work` honored) — the FSM is driven exclusively by `start_battle()`.

Chosen over a persistent node under `Game.tscn` because ADR-0002 §4's accepted contract already writes `TBC.is_battle_active()` as a global call, and **SaveLoad is itself an autoload** (slot 10): a peer-autoload query needs no injected reference, whereas a scene node would force late-bound registration into SaveLoad (inverting autoload construction order and reintroducing `_ready` wiring). The orchestrator is genuinely a global singleton — exactly one battle exists at a time, and `is_battle_active` must answer *even when no battle is running* (SaveLoad manual-save gate).

`stat_formula_home` banned *formula-owner* service autoloads (stat/synergy/progression) because those are cheaply DI'd pure-math objects with many test seams. The combat orchestrator is categorically different: its defining property **is** being the always-queryable battle authority. The amendment adds a carve-out, not a reversal.

### 2. Runtime state — `BattleContext` (RefCounted)

Per-battle state lives in a RefCounted `BattleContext`, created at BATTLE_INIT and referenced by the controller for the battle's duration. It holds: the 3 player `CombatantSnapshot`s + the enemy snapshot; per-combatant `current_structure`/`current_energy`/`current_heat`; region break pools (initialized from `EnemyDef` via Part-Break); active statuses (with `snapshotted_processing`); the `beacon_used_this_battle` flag; the accumulating `deployed_symbot_ids` set and `fired_break_events` set. The controller **drops the reference synchronously after the `battle_ended` cascade returns** — no `queue_free`, no deferred cleanup (it is RefCounted, not a Node). This keeps the autoload itself a lean controller (mirrors ADR-0005's frozen-snapshot + RefCounted-owner discipline) and gives the teardown contract a single, testable moment.

### 3. FSM — enum + `match` dispatch

```
enum BattleState { BATTLE_INIT, ROUND_START, TURN_ACTIVE, ACTION_PENDING,
                   RESOLVING, TURN_END, FORCED_SWITCH, BATTLE_END }
```

Transitions are explicit `_state` assignments; a private `_advance()` dispatches via `match _state`. Idiomatic for 8 fixed states, no per-transition allocation, every transition verifiable in isolation. State-object classes were rejected as over-engineered — there is no dynamic/extensible state set.

### 4. Action seam — event-driven park + synchronous AI

At ACTION_PENDING the FSM **parks** (no `await`, no loop). For a player turn it simply waits; Combat UI resumes it by calling `BattleController.submit_action(action)`. For an enemy turn, TBC synchronously calls `EnemyAI.request_move(snapshot)` and feeds the returned move through the **same** internal `_resolve(action)` path — matching the GDD's "treats the response like player input." `submit_action` is guarded: a call while `_state != ACTION_PENDING` is a no-op. No coroutine is held across the park, so teardown, the save quiesce point, and re-entrancy (`is_battle_active` makes `battle_ended` terminal — a re-entrant `start_battle` inside a subscriber is refused, ADR-0002 rule 5) all reason simply.

### 5. RNG wiring — TBC owns crit + AI seed only

- **Crit**: TBC is the sole crit-roller. Before a DAMAGE resolution it draws `next_seed(&"crit")`, computes `crit_mult`, and passes it **into** `compute_damage(..., crit_mult)`. DF-1 stays deterministic (`damage_computation`).
- **Enemy AI seed**: TBC draws `next_seed(&"ai")` and injects it into `request_move` — Enemy AI builds a fresh RNG per call (`persistent_shared_rng_across_calls` forbidden; TBC never caches an AI RNG).
- **Drop**: TBC does **not** vend for Drop. It emits `battle_ended` with the break set; the Drop resolver (its own orchestrator) calls `make_rng(&"drop")` itself and drives the ID-ascending roll loop. TBC's RNG surface is exactly `{crit, ai}`. *(Forward constraint recorded for the Drop System ADR/GDD.)*

### Architecture Diagram

```
 Autoload roster (fixed order of 11):
  1 EventBus  2 Log  3-8 six DBs  9 RngService  10 SaveLoad  11 BattleController ◀ NEW

 ScreenManager.enter_battle(payload)                SaveLoad.snapshot()
        │                                                │ queries (autoload→autoload)
        ▼                                                ▼
 ┌─────────────────────── BattleController (autoload) ───────────────────────┐
 │  is_battle_active : bool          _state : BattleState                     │
 │  start_battle(payload) -> bool    submit_action(action)                    │
 │  signal battle_ended(8 fields)    signal battle_start_refused(...)         │
 │                                                                            │
 │  start_battle:  is_build_valid ×3 ──false──▶ battle_start_refused (return) │
 │                 │ true                                                     │
 │                 ▼   creates ──▶ BattleContext (RefCounted, per-battle)     │
 │  FSM:  BATTLE_INIT ▶ ROUND_START ▶ TURN_ACTIVE ▶ ACTION_PENDING ─┐         │
 │          │                ▲                        │  player: park│        │
 │          │                └──── TURN_END ◀─ RESOLVING ◀───────────┘        │
 │          │                        │        enemy: request_move(seed)       │
 │          │                  FORCED_SWITCH                                  │
 │          ▼                                                                 │
 │        BATTLE_END ──▶ emit battle_ended (sync) ──▶ drop BattleContext ref  │
 └────────────────────────────────────────────────────────────────────────────┘
     │ calls (per resolution)                         ▲ subscribers (sync)
     ▼                                                │
  effective_stat() · compute_damage(crit_mult)   CoreProgression.apply_battle_result
  next_seed(&"crit") · next_seed(&"ai")           Drop resolver (make_rng(&"drop"))
  EnemyAI.request_move(seed)                       Overworld Nav (→ encounter_resolved)
```

### Key Interfaces

```
# BattleController (autoload slot 11)
func start_battle(encounter_payload: Dictionary) -> bool   # false + battle_start_refused on invalid build
func is_battle_active() -> bool                            # SaveLoad quiesce gate; true only INIT..BATTLE_END
func submit_action(action: BattleAction) -> void          # no-op unless _state == ACTION_PENDING
signal battle_ended(outcome: int, enemy_id: StringName, fired_break_events: Dictionary,
                    xp_value: int, completion_bonus_xp: int, is_first_boss_defeat: bool,
                    enemy_level: int, deployed_symbot_ids: Array)   # combat_battle_end verbatim
signal battle_start_refused(invalid_symbot_ids: Array, offending_parts: Array)   # Rule 2.0

# BattleContext (RefCounted, per-battle, discarded post-cascade) — not a public API surface;
# constructed and owned solely by BattleController.
```

**Implementer notes (Godot 4.6 idioms, from engine-specialist validation):**
- Emit with `battle_ended.emit(...)` / `battle_start_refused.emit(...)` — the signal-object `.emit()` form, never the legacy `emit_signal("name", ...)`.
- Type the signal collections in the actual `.gd` declaration per coding standards: `deployed_symbot_ids: Array[int]`; `invalid_symbot_ids: Array[int]`. `fired_break_events` is a Dictionary-as-set (`StringName → bool`; GDScript has no `Set` type — the GDD's "Set" is realized as a `Dictionary`).
- The `match _state` dispatch carries a `_: push_error(...)` default branch to catch invalid transitions during development (Godot `match` silently passes unhandled cases).

## Alternatives Considered

### Alternative 1: Persistent node under `Game.tscn` root (host)
- **Description**: TBC orchestrator as a scene node sibling to ScreenManager, constructed at boot + ScreenManager-injected.
- **Pros**: honors "fixed roster of 10" literally; matches ADR-0005's DI-owner pattern.
- **Cons**: ADR-0002 §4's accepted text says "autoload" and writes `TBC.is_battle_active()`; SaveLoad (autoload) would need a late-bound node reference (inverts construction order, reintroduces `_ready` wiring + a null window before binding); requires re-interpreting an accepted ADR.
- **Rejection Reason**: The SaveLoad→host query is the decisive constraint — autoload→autoload needs zero wiring; node→autoload fights lifecycle order.

### Alternative 2: `await`-based action seam
- **Description**: FSM does `var action = await player_action_submitted`.
- **Pros**: linear, readable per-turn code.
- **Cons**: a coroutine suspended across the park interacts badly with teardown, the save quiesce point, and re-entrancy guards; a mid-`await` save/`queue_free` is a sharp edge.
- **Rejection Reason**: the event-driven park achieves the same with no suspended state to reason about.

### Alternative 3: State-object FSM (one RefCounted class per state)
- **Description**: `enter/exit/handle` classes per state.
- **Cons**: 8 files + per-transition allocation; value is a dynamic/extensible state set, which MVP TBC does not have.
- **Rejection Reason**: over-engineered; enum + `match` is idiomatic and equally testable.

### Alternative 4: TBC vends `make_rng(&"drop")` and passes the instance in the payload
- **Rejection Reason**: puts live mutable stream state in the `battle_ended` payload (violates `subscriber_ordering_dependency`) and couples TBC to Drop's load-bearing stream position. Drop owns its own vend.

## Consequences

### Positive
- The C-3 host seam is closed; `is_battle_active` has a stable, always-queryable home matching ADR-0002's accepted call form.
- The autoload stays a thin controller; all mutable battle state is isolated in a RefCounted context with a single, testable teardown moment.
- The event-driven seam gives Combat UI (ADR-0008) a trivial integration surface (`submit_action` + signals) and no coroutine coupling.
- RNG surface is minimal and orchestrator-bounded; every seeded path is GUT-testable with an injected seed.

### Negative
- The accepted roster grows 10 → 11 and two registry stances (`boot_initialization`, `stat_formula_home`) must be amended — a reviewed, explicit change, but it does touch previously-frozen text.
- `BattleController` is a stateful autoload, a slightly heavier host than the roster's other thin singletons (mitigated: state lives in `BattleContext`, not the autoload).

### Risks
- **Risk**: a subscriber to `battle_ended` triggers a re-entrant `start_battle`. *Mitigation*: `is_battle_active` remains `true` until the cascade completes, making `battle_ended` terminal; `start_battle` refuses while active (ADR-0002 rule 5). *(Engine-confirmed: Godot 4.6 does not block or defer re-entrant emissions; the boolean guard is the idiomatic mechanism — no `CONNECT_DEFERRED` needed.)*
- **Risk**: `submit_action` arrives out of turn (double-tap, stale UI). *Mitigation*: state-guarded no-op + GUT test.
- **Risk**: `BattleContext` outlives teardown via a stray reference (Combat UI holding it). *Mitigation*: UI reads via signals/getters, never retains the context; teardown GUT test asserts the controller's ref is null post-cascade.
- **Risk**: **RefCounted reference cycle** — GDScript has no cycle collector, so if a `CombatantSnapshot` (or any object held in `BattleContext`) back-references `BattleContext`, dropping the controller's ref will NOT free the context and it leaks for the process lifetime. *Mitigation*: `BattleContext` references snapshots one-directionally; snapshots (ADR-0005, frozen at BATTLE_INIT) must never hold a `BattleContext` reference. Teardown GUT test asserts the context is actually freed (e.g. via a `WeakRef` going null), not merely dereferenced.
- **Risk**: the `battle_ended → apply_battle_result` subscriber re-connects on every battle (duplicate connections). *Mitigation*: the connection lives on the **subscriber** side (the meta-progression owner of `CoreProgression`), wired **once** in that subscriber's `_ready` (guarded by `is_connected()` if there is any doubt) — never inside `start_battle()`. `BattleController` itself subscribes to nothing, so its `_ready` stays inert.
- **Risk**: autoload slot-11 construction order. *Mitigation*: the host does no `_ready` work, so order is immaterial (inertness test) — slot 11 is a display convention, not a dependency. *(Engine-confirmed: no 4.4–4.6 change to autoload/singleton `_ready` ordering.)*

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| turn-based-combat.md | Rule 2 battle-start sequence incl. Rule 2.0 `is_build_valid` precondition | `start_battle()` runs the precondition → `battle_start_refused` (no state, no `battle_ended`); then snapshot ×3 + `evaluate_silent` + enemy build + runtime init + initiative |
| turn-based-combat.md | States & Transitions table (8 states + FORCED_SWITCH) | `BattleState` enum + `match` dispatch in `BattleController` |
| turn-based-combat.md | Rule 4 turn anatomy; Rule 10 damage resolution | FSM turn phases; `effective_stat()` → `compute_damage(..., crit_mult)` → MOVE-F1 → Stagger → sub-target/enrage, all reading `BattleContext` |
| turn-based-combat.md | Enemy AI hook at enemy ACTION_PENDING | synchronous `EnemyAI.request_move(snapshot)` fed through `_resolve`; `next_seed(&"ai")` injected |
| turn-based-combat.md | Rule 12 battle-end 8-field `battle_ended`, synchronous, state discarded after subscribers return | `battle_ended` signal (verbatim `combat_battle_end`); `BattleContext` ref dropped after `emit()` returns |
| damage-formula.md | TR-df-003 `crit_mult` passable, not hardcoded | TBC rolls `next_seed(&"crit")` → passes `crit_mult` into deterministic DF-1 |
| symbot-core-progression.md | `is_build_valid` gate + `apply_battle_result` on battle end | `start_battle` precondition; the meta-progression owner subscribes to `battle_ended` (wired once in the subscriber's `_ready`) and calls `apply_battle_result` — `BattleController` only emits, it subscribes to nothing |

## Performance Implications
- **CPU**: turn-based; the FSM advances only on discrete actions, not per-frame. `compute_damage` and `effective_stat` are O(1) integer math. Negligible against the 16.6 ms budget.
- **Memory**: one `BattleContext` (a handful of snapshots + small dictionaries) alive per battle, freed at teardown. No pooling needed.
- **Load Time**: none — the autoload does no boot work.
- **Network**: N/A.

## Migration Plan
Greenfield — no existing combat code. Implementation stories build `BattleController` + `BattleContext` against this ADR. The roster amendment is a project-settings autoload entry + the two registry-stance edits below.

## Validation Criteria
- `is_battle_active` is `false` before `start_battle` and after the `battle_ended` cascade; `true` only across INIT..BATTLE_END (GUT).
- An invalid build causes `start_battle` to return `false` + emit `battle_start_refused` with **no** `battle_ended` and no runtime state (GUT).
- `submit_action` out of ACTION_PENDING is a no-op (GUT).
- Crit path: with an injected fixed seed, `crit_mult` is deterministic and DF-1 output matches the GDD worked examples (GUT).
- Teardown: `BattleController`'s `BattleContext` reference is null immediately after `emit()` returns, **and the context is actually freed** — a `WeakRef` taken before teardown reads null afterward, proving no reference cycle keeps it alive (GUT).
- Autoload inertness: `BattleController._ready` performs no I/O, no signal connections, no cross-autoload reads (grep + GUT).

## Related Decisions
- ADR-0002 (event bus — `combat_battle_end`, teardown, `is_battle_active` quiesce)
- ADR-0004 (scene/boot — roster **amended here 10 → 11**, ScreenManager teardown)
- ADR-0005 (stat pipeline — `CombatantSnapshot`, DF-1, `is_build_valid`, `apply_battle_result`; C-3 seam deferred here)
- ADR-0006 (RNG — crit + AI vends)
- ADR-0008 (UI — consumes `submit_action` + battle signals; enabled by this ADR)
