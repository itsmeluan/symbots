# Story 001: BattleController autoload host, FSM scaffold & teardown

> **Epic**: Turn-Based Combat
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: timeboxed 4h (Risk: HIGH — the FSM host every other story builds on)
> **Manifest Version**: 2026-07-14
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/turn-based-combat.md` (Rule 12, States and Transitions)
**Requirement**: `TR-tbc-040` (primary), `TR-tbc-005` (part), `TR-tbc-039` (seam)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: **ADR-0007** (primary), ADR-0002 (secondary)
**ADR Decision Summary**: `BattleController` is a thin autoload at **slot 11** holding only `is_battle_active: bool`, the `_state` FSM (enum + `match`), and a reference to a per-battle RefCounted `BattleContext`. It does NO `_ready` work. Per-battle mutable state lives in `BattleContext`, dropped **synchronously after** the `battle_ended` emit cascade returns (RefCounted, never `queue_free`). The action seam is event-driven: a player turn PARKS (sets `_state`, returns — never `await`), resuming via `submit_action(action)` (guarded no-op unless `_state == ACTION_PENDING`); an enemy turn synchronously calls `EnemyAI.request_move(snapshot)` through the same `_resolve()` path.

**Engine**: Godot 4.7 | **Risk**: HIGH
**Engine Notes**: ADR-0007's header references Godot 4.6; the project is pinned **Godot 4.7** (`docs/engine-reference/godot/VERSION.md`) — engine-compat re-validation is pending but does not change this story's FSM shape. Use the `.emit()` signal form (not `emit_signal`). This story amends **ADR-0004's autoload roster 10→11** (BattleController is the added slot). Verify teardown with a `WeakRef` to the dropped `BattleContext`.

**Control Manifest Rules (Core layer)**:
- Required: `BattleController` (autoload slot 11) owns `is_battle_active: bool` + the `_state` FSM (enum + `match`). Per-battle mutable state lives in a RefCounted `BattleContext` the controller drops synchronously AFTER the `battle_ended` emit() cascade returns. The action seam is event-driven (park + `submit_action` guarded no-op / synchronous `request_move`). `is_battle_active()` is the only cross-system read.
- Forbidden: `battle_state_on_transient_node` (never put `is_battle_active`/`_state` on the Battle scene node or a transient screen); `battle_context_leak_past_teardown` (never retain a `BattleContext` ref past the cascade; snapshots must not back-reference the context); `coroutine_park_across_action` (never `await` across `ACTION_PENDING`).
- Guardrail: Battle FSM transitions stay synchronous — every stop-point is testable.

---

## Acceptance Criteria

*From GDD `design/gdd/turn-based-combat.md`, scoped to this story:*

- [ ] **AC-TBC-35**: `is_battle_active()` returns `false` with no battle; becomes `true` at `BATTLE_INIT` and stays `true` through every state until `battle_ended` emits, after which it is `false` again. Never `true` before init or after end; never flips `false` mid-battle.
- [ ] **ADR-0007 verification — autoload inertness**: the `BattleController` autoload does no work in `_ready` (no snapshot, no state creation); `is_battle_active() == false` immediately after boot.
- [ ] **ADR-0007 verification — `submit_action` re-entrancy guard**: `submit_action(action)` called when `_state != ACTION_PENDING` is a guarded no-op (no state change, no crash); only advances resolution when `_state == ACTION_PENDING`.
- [ ] **ADR-0007 verification — teardown**: after a battle ends, the `BattleContext` reference is null AND a `WeakRef` taken before teardown reports the context actually freed (no lingering ref, no RefCounted cycle).
- [ ] The FSM enum `{ BATTLE_INIT, ROUND_START, TURN_ACTIVE, ACTION_PENDING, RESOLVING, TURN_END, FORCED_SWITCH, BATTLE_END }` is dispatched via `match` in a private `_advance()`; an unexpected state hits a `_: push_error(...)` default (no silent fall-through).

---

## Implementation Notes

*Derived from ADR-0007 Decision + Control Manifest:*

- Create `src/gameplay/battle/battle_controller.gd` (autoload, slot 11) and `src/gameplay/battle/battle_context.gd` (`extends RefCounted`). The controller holds `var is_battle_active := false`, `var _state: BattleState`, `var _ctx: BattleContext`.
- `_advance()` is `match _state: ...` with a `_: push_error("BattleController: unhandled state %s" % _state)` default. Keep every transition synchronous — no `await` anywhere in the FSM.
- Player park: set `_state = ACTION_PENDING` and **return** from the turn handler. Do NOT `var action = await …`. Resume path is `submit_action(action)` → guard `if _state != ACTION_PENDING: return` → feed `_resolve(action)`.
- Enemy branch (seam only in this story): call `EnemyAI.request_move(snapshot)` synchronously and pass the result through the same `_resolve(action)`. The real `EnemyAI` is a separate epic (AC-TBC-INT-02 deferred); stub the call site so it is testable.
- Teardown: after the `battle_ended` cascade returns, set `_ctx = null` and `is_battle_active = false` in that order — the emit is synchronous, so all subscribers have already read live state. Snapshots stored in `BattleContext` must NOT back-reference the context (no cycle).
- This story delivers the scaffold + `is_battle_active` + `submit_action` guard + teardown discipline. Battle-start population (Rule 2) is Story 002; per-outcome `battle_ended` payloads are Story 014.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the Rule 2 battle-start sequence (snapshot, `evaluate_silent`, enemy instantiation, build-validity refusal) that populates `BattleContext`.
- Story 014: the 8-field `battle_ended` payloads, dedup set, and dual-shape non-confusion.
- Enemy AI's actual move selection (`request_move` body) — AC-TBC-INT-02, deferred to the Enemy AI epic; only the synchronous call **site** is built here.

---

## QA Test Cases

*Automated unit test specs — developer implements against these.*

- **AC-TBC-35**: `is_battle_active()` lifecycle
  - Given: a freshly-booted `BattleController`, no battle started
  - When: `is_battle_active()` is queried; then a battle is driven `BATTLE_INIT`→…→`BATTLE_END`
  - Then: `false` before init; `true` at `BATTLE_INIT` and at every intermediate state; `false` after `battle_ended` emits
  - Edge cases: query during `ACTION_PENDING`, `RESOLVING`, `FORCED_SWITCH` all return `true`; never flips `false` mid-battle
- **Autoload inertness**:
  - Given: the autoload just instantiated (simulated `_ready`)
  - When: no `start_battle` called
  - Then: `is_battle_active() == false`, `_ctx == null`, no snapshot taken
- **`submit_action` guard**:
  - Given: `_state != ACTION_PENDING` (e.g. `ROUND_START`)
  - When: `submit_action(dummy)` is called
  - Then: no state change, no crash, resolution not triggered
  - Edge cases: called twice in a row while `ACTION_PENDING` — second call is a no-op after the first transitions state
- **Teardown / WeakRef freed**:
  - Given: a battle in progress with a live `BattleContext`; take `var wr := weakref(_ctx)`
  - When: the battle ends and the cascade returns
  - Then: `_ctx == null` AND `wr.get_ref() == null` (context actually freed — no cycle)
- **FSM default guard**:
  - Given: `_state` forced to an out-of-range value (test-only)
  - When: `_advance()` runs
  - Then: `push_error` path taken, no silent success

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/tbc/battlecontroller_fsm_host_test.gd` — must exist and pass. Include the `WeakRef` teardown assertion and the `submit_action` out-of-turn no-op.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational — first TBC story)
- Unlocks: Story 002 (battle start populates the context), and every later TBC story (all run on this FSM host)
