# ADR-0002: Event Bus & Signal Architecture

## Status

Accepted (2026-07-13, via `/architecture-review` follow-up — review report `architecture-review-2026-07-13.md`)

## Date

2026-07-13

## Last Verified

2026-07-13

## Decision Makers

Luan (solo dev / project owner); Claude Code Game Studios agents (godot-specialist engine validation 2026-07-13; TD-ADR gate skipped — Lean review mode)

## Summary

Symbots' systems communicate through named signals, and the blueprint's single highest-risk seam is that two differently-shaped signals share the name `battle_ended` (QQ-02) while no decision exists on bus-vs-direct transport (QQ-03). This ADR adopts a **hybrid** architecture: persistent system singletons own their typed signals and consumers connect directly; a thin, stateless `EventBus` autoload carries only a closed roster of cross-layer broadcasts. The 2-field world relay is **renamed `encounter_resolved`** (the 8-field TBC `battle_ended` keeps its GDD-ratified name), the synchronous-emit teardown-ordering contract is locked project-wide, the autosave quiesce point deferred by ADR-0001 is defined (`CONNECT_DEFERRED` on the bus — the only sanctioned deferred connection), and the injected-LogSink diagnostics pattern becomes a project-wide rule.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (signals / event routing / autoloads) |
| **Knowledge Risk** | HIGH overall (post-LLM-cutoff version) — but LOW for this domain: the Signal subsystem has **no breaking changes in 4.4/4.5/4.6** (specialist-verified against `breaking-changes.md`) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/architecture.md` (§ Data Flow 2, § API Boundaries), godot-specialist validation report 2026-07-13 |
| **Post-Cutoff APIs Used** | `@abstract` classes/methods (GDScript 4.5+, carried into 4.6) for the `LogSink` base. Everything else (typed signals, `Signal.emit()`, `CONNECT_DEFERRED`, typed `Array[Dictionary]` payloads) is stable pre-cutoff API. |
| **Verification Required** | (1) Spot-check on 4.6 that a `CONNECT_DEFERRED` callable queued during a synchronous cascade fires at the next engine idle poll *after* the full cascade returns (the autosave quiesce guarantee). (2) Confirm GUT can assert on the connection-audit helper (arity introspection via `get_signal_list()` / `Callable.get_argument_count()`) in the project's GUT version during `/test-setup`. |

> **Note**: Overall knowledge risk is HIGH. Re-validate this ADR if the project upgrades engine versions.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Save/Load — **Accepted 2026-07-13**): this ADR defines the save-trigger quiesce points ADR-0001 explicitly deferred here. |
| **Enables** | ADR-0004 (Scene/boot — the autoload set and its order, including "EventBus first", land there), ADR-0007 (TBC FSM — its emission points implement this ADR's teardown contract) |
| **Blocks** | Overworld Navigation GDD (#16) — must ratify the `encounter_resolved` relay contract defined here; Production coding of any signal producer or subscriber |
| **Ordering Note** | Second of the four Foundation ADRs. The `encounter_resolved` rename is propagated to zone-world-map.md and encounter-zone.md in the same pass as this ADR (cross-review C-1 remainder). |

## Context

### Problem Statement

Ten-plus systems communicate via named signals, but three contracts are undecided: (1) **transport** — central event-bus autoload vs direct owner-declared signals (QQ-03); (2) **the `battle_ended` collision** — TBC emits an 8-field combat signal consumed by Core Progression and Drop, while Overworld Navigation (Not Started) relays a 2-field world signal consumed by Zone & World Map and Encounter Zone; one identifier, two shapes, and a subscriber wired to the wrong one binds a payload that doesn't exist (QQ-02 — flagged by the 2026-07-13 cross-review as C-1, the highest-risk seam); (3) **ordering semantics** — TBC discards battle runtime state after emitting, Core Progression's first-defeat guard is deliberately ordering-independent, and the autosave trigger needs a point where the whole post-battle cascade has settled. Until these are decided, no subscriber can be implemented against a stable contract.

### Current State

Greenfield — no code. The contracts-in-prose that constrain this decision: TBC Rule 12 (8-field payload + the 2026-07-13 synchronous-teardown erratum), CP Rule 3/3a (payload-self-sufficiency via `is_first_boss_defeat`), Drop Rule 1 (VICTORY-only trigger), ZWM/EZ's consumption of the 2-field relay, EP OQ-EP-2 + ADR-0001's deferred save-timing, and the injected-logger pattern ADR-0001 File Rule 7 already established for persistence.

### Constraints

- **Engine (Godot 4.6):** Signal subsystem unchanged post-cutoff; string-based `connect()` deprecated since 4.0 (project deprecated-apis registry); signal dispatch is synchronous in connection order, but connection order is an implementation accident — never a contract.
- **Design:** TBC Rule 12's name and 8-field shape are ratified across four Approved GDDs (TBC, Core Progression, Drop, ELZS) — renaming *it* would churn four documents; the 2-field relay's producer GDD doesn't exist yet, so renaming *that* costs two document touches (ZWM, EZ).
- **Testing:** 80% coverage on game logic (GUT); systems must be testable in isolation — no hidden global coupling, diagnostics assertable via injected spies.
- **Resource (solo dev):** signal topology must be readable from the code — "who talks to whom" must not require runtime tracing.

### Requirements

- The two battle-end contracts must be **impossible to cross-wire by name**.
- A producer must be able to discard internal state after notifying subscribers, without any subscriber observing a torn payload.
- Subscribers must be ordering-independent (CP's first-defeat guard, ZWM's win-count increment, and Drop's payout must not care who ran first).
- Autosave must fire at a point where the entire post-battle mutation cascade (win_count++, gate re-eval, `defeated_once` flip, XP award, drop payout) has completed.
- All system diagnostics must be assertable in GUT via an injected sink.
- Signal payloads must be fixed-shape and read-only from the subscriber's perspective.

## Decision

Adopt a **hybrid signal architecture**: system-owned typed signals by default, plus a thin broadcast-only `EventBus` autoload with a closed admission-gated roster. Resolve the `battle_ended` collision by **renaming the 2-field world relay to `encounter_resolved`**.

### 1. Transport — owner-declared signals by default, bus by admission only

Persistent system singletons (autoloads per ADR-0004: TBC orchestrator, Symbot Assembly, Core Progression, Zone & World Map, Inventory, World Loot, …) declare their own typed signals. Consumers connect directly — `producer.signal_name.connect(callable)` — in `_ready()`. Direct connection is the default because it keeps the topology greppable: the producer names the contract, the consumer names its dependency.

A **`EventBus` Foundation autoload** exists as a *stateless plain `Node` script containing only signal declarations* — no methods, no state, no logic. Emission is `EventBus.signal_name.emit(...)`.

**Bus admission criteria** — a signal is declared on the bus **only if** at least one of:

1. Its **producer is not a stable boot-time autoload** at consumer-connect time (transient object, or a Not-Started system whose contract must exist before it does — the Overworld Navigation relay).
2. It is a **world-state broadcast with an unbounded consumer set** (UI screens, audio, autosave, future telemetry) where forcing every consumer to depend on the producer buys nothing.

Everything else is owner-declared. Adding a bus signal outside these criteria is a **forbidden pattern** (`bus_by_default`, registered).

**MVP bus roster (closed — additions require touching this ADR or a registry entry):**

```gdscript
# event_bus.gd — Foundation autoload, FIRST in the autoload list (ADR-0004)
signal encounter_resolved(result: int, encounter_type: int)      # criterion 1+2 — see § 2
signal zone_states_changed(transitions: Array[Dictionary])       # criterion 2 — ZWM → Map UI, audio, autosave
signal zone_entered(zone_id: StringName)                         # criterion 2 — ZWM → EZ context, UI, audio, autosave
```

**Owner-declared signals (consumers connect directly to the autoload):**

| Producer | Signal | Direct consumers |
|---|---|---|
| TBC | `battle_ended(outcome, enemy_id, fired_break_events: Dictionary, xp_value: int, completion_bonus_xp: int, is_first_boss_defeat: bool, enemy_level: int, deployed_symbot_ids: Array)` — 8-field, per TBC Rule 12 | Core Progression, Drop System, Overworld Navigation (relay source), Combat UI |
| TBC | `hit_resolved(move, damage: int, target, sub_target)` | Part-Break, Combat UI |
| TBC | `battle_start_refused(invalid_symbot_ids: Array, offending_parts: Array)` | Overworld Navigation, Combat UI |
| Assembly | `part_equipped(slot_type: int, new_part_id: StringName)`, `stats_changed(final_stat: Dictionary)` | Workshop UI |
| Synergy | `synergy_changed(...)` | Workshop UI |
| Core Progression | `core_leveled_up(core_id: int, old_level: int, new_level: int)` | Workshop UI, Combat UI |
| World Loot | `node_collected(...)` | Overworld/UI |

Combat UI connects directly to TBC because it already holds a TBC dependency for submitting actions — bus indirection there would hide a coupling that is real and necessary, not remove it.

### 2. The `battle_ended` seam — rename the world relay to `encounter_resolved`

- **TBC keeps `battle_ended`** (8-field) — the name and shape ratified by TBC Rule 12 and consumed by CP Rule 3/3a and Drop Rule 1. Owner-declared on TBC, never on the bus.
- **The 2-field world relay becomes `EventBus.encounter_resolved(result: int, encounter_type: int)`** — `result ∈ {WIN, LOSS, FLEE}`, `encounter_type ∈ {WILD, BOSS}`. **Overworld Navigation** (#16) is its sole producer: it consumes TBC's `battle_ended` directly, maps the outcome vocabulary (`VICTORY/DEFEAT/FLED → WIN/LOSS/FLEE`), attaches the `encounter_type` it knew at trigger time, and emits on the bus. Consumers: Zone & World Map (win-count increment per EZ Rule 8a), Encounter Zone (gate re-eval per EZ Rule 8), World Map UI.
- Because the names now differ and the relay lives on a different object, **cross-wiring by name is structurally impossible**. A static contract test asserts `EventBus` declares no signal named `battle_ended` and TBC declares no `encounter_resolved`.
- `is_first_boss_defeat` provenance is unchanged (blueprint QQ-05): Overworld Navigation computes it from pre-battle `defeated_once` and hands it to `TBC.start_battle(...)`; TBC relays it inside `battle_ended`.

### 3. Emission & teardown-ordering contract (project-wide)

1. **Synchronous emit.** All gameplay signal emission uses default (synchronous) `Signal.emit()`. Emit blocks until every non-deferred subscriber has returned — engine-guaranteed, specialist-confirmed on 4.6.
2. **Teardown after emit.** A producer may discard or mutate the state a payload was derived from only **after** `emit()` returns (TBC Rule 12 erratum, generalized to every producer).
3. **No inter-subscriber ordering dependency.** Engine dispatch happens in connection order, but connection order is never a contract. No subscriber may depend on another subscriber of the same signal having run. Payloads are **self-sufficient** — everything a subscriber needs rides the payload (this is why `is_first_boss_defeat` is a payload field and not a read of `defeated_once`).
4. **Read-only payloads.** Subscribers never mutate payload collections. Producers pass **deep copies** of internal mutable collections — `dict.duplicate(true)` / `array.duplicate(true)` (note: `duplicate_deep()` is a `Resource` method and does not apply to `Dictionary`/`Array`). `duplicate(true)` deep-copies one container level with new inner `Dictionary`/`Array` instances; MVP payload fields are value types (`int`, `bool`, `StringName`) inside one container level, so this suffices — a payload field that nests containers deeper must document its copy depth.
5. **No re-entrancy.** A subscriber must not cause the signal it is currently handling to be re-emitted synchronously (Godot processes re-entrant emission immediately, inside the subscriber's stack frame — double-processing).
6. **`CONNECT_DEFERRED` is reserved for the autosave trigger** (§ 4). Every other connection is synchronous. Deferred callables targeting a freed `Node` are silently skipped by the engine — a silent failure this rule confines to one audited site.
7. **Typed connections only.** `signal.connect(callable)`; string-based `connect("sig", obj, "method")` is banned (deprecated-apis registry). Non-autoload consumers (UI screens) disconnect in `_exit_tree()`; one-off subscriptions use `CONNECT_ONE_SHOT`.

### 4. Save quiesce points (resolves ADR-0001 deferred timing + EP OQ-EP-2)

A **quiesce point** is: `TBC.is_battle_active() == false` AND no signal cascade in flight.

- **Autosave**: Save/Load connects to `EventBus.encounter_resolved` and `EventBus.zone_entered` with **`CONNECT_DEFERRED`** — the deferred callable is queued and executes at the next engine idle poll *after the entire synchronous cascade unwinds* (win_count++, gate re-eval, `defeated_once` flip, XP award, drop payout all complete). The snapshot therefore always sees consistent post-cascade world state, regardless of connection order. This is the **only** sanctioned `CONNECT_DEFERRED` use in the project.
- **Manual save**: permitted whenever `is_battle_active() == false` (Save/Load queries TBC; refuses during battle).
- **`is_battle_active` lives on the TBC autoload orchestrator, never on the Battle scene node.** The Battle scene is `queue_free()`d at teardown (ADR-0004) — a query routed through the scene node would race its deletion (`is_queued_for_deletion()` window). The autoload flips the flag as part of its own FSM, independent of scene lifetime.

### 5. Injected LogSink (project-wide diagnostics contract)

Generalizes ADR-0001 File Rule 7 to every system:

```gdscript
@abstract class_name LogSink                       # GDScript 4.5+ @abstract, valid in 4.6
@abstract func info(code: StringName, detail: Dictionary) -> void    # non-error breadcrumbs
@abstract func warn(code: StringName, detail: Dictionary) -> void
@abstract func error(code: StringName, detail: Dictionary) -> void
```

- Production implementation wraps `print` (info) / `push_warning` (warn) / `push_error` (error); GUT tests inject a spy. The `info` channel carries non-error breadcrumbs — the ADR-0004 boot-step order trace (`boot_step`) and the ADR-0006 root-seed / `rng_seed_issued` log lines depend on it; it is not a warning and must not route through `warn`.
- Direct `push_warning`/`push_error` calls in system code are **banned** (`global_push_diagnostics`, registered forbidden pattern). CI greps `src/` for them.
- Test spies/stubs are **`preload()`-ed, not `class_name`-declared** — a `class_name` in `tests/` enters the global class registry of production builds (name pollution, wasted memory).

### Architecture Diagram

```
                    DIRECT (owner-declared typed signals)
  Combat UI ─┬─ connect ──▶ TBC.battle_ended (8-field)  ◀── connect ─┬─ Core Progression
             ├─ connect ──▶ TBC.hit_resolved            ◀── connect ─┤  Drop System
             │                                          ◀── connect ─┘  Part-Break (hit_resolved)
             │              TBC discards runtime state ONLY after emit() returns
             │
             │              Overworld Navigation ── consumes battle_ended,
             │                  maps VICTORY/DEFEAT/FLED → WIN/LOSS/FLEE ──┐
             │                                                             ▼
                    EVENT BUS (stateless autoload, closed roster)
             ┌────────────────────────────────────────────────────────────────┐
             │ EventBus.encounter_resolved(result, encounter_type)             │
             │ EventBus.zone_states_changed(transitions)                       │
             │ EventBus.zone_entered(zone_id)                                  │
             └──┬────────────────┬──────────────┬───────────────┬─────────────┘
                ▼ sync           ▼ sync         ▼ sync          ▼ CONNECT_DEFERRED
           Zone & World Map  Encounter Zone  World Map UI    Save/Load autosave
           (win_count++)     (gate re-eval)  (display)       (fires AFTER the whole
                                                              sync cascade settles)
```

### Key Interfaces

```gdscript
# event_bus.gd — Foundation autoload (FIRST in autoload order — ADR-0004)
# Signal declarations ONLY. No methods, no state.
signal encounter_resolved(result: int, encounter_type: int)
signal zone_states_changed(transitions: Array[Dictionary])
signal zone_entered(zone_id: StringName)

# Producer-side pattern (Overworld Navigation, the relay):
func _on_battle_ended(outcome, _enemy_id, _breaks, _xp, _bonus, _first, _level, _deployed) -> void:
    EventBus.encounter_resolved.emit(_map_result(outcome), _pending_encounter_type)

# Autosave trigger (Save/Load) — the ONLY CONNECT_DEFERRED site in the project:
EventBus.encounter_resolved.connect(_on_autosave_trigger, CONNECT_DEFERRED)
EventBus.zone_entered.connect(_on_autosave_trigger_zone, CONNECT_DEFERRED)

# Test-time connection auditor (GUT helper, not runtime code):
# for each connection on TBC + EventBus, assert
#   connection.callable.get_argument_count() (minus bound args)
#   == the signal's declared argument count (via get_signal_list()).
# Miswiring does NOT crash at runtime in 4.6 (push_error + continue) — this
# auditor is the loud CI failure, plus the static name-contract test:
#   assert not EventBus.has_signal("battle_ended")
#   assert not tbc.has_signal("encounter_resolved")
```

## Alternatives Considered

### Alternative 1: Central EventBus for everything

- **Description**: Every cross-system signal (~12+) declared on one Foundation autoload; all producers emit via the bus, all consumers connect to it; direct system-to-system connections banned.
- **Pros**: One place to read every contract; producers and consumers fully decoupled; trivially uniform wiring.
- **Cons**: God-object growth (every new feature touches the same file); hides the real topology — `grep EventBus` matches everything, telling you nothing about who actually talks to whom; couplings that are real and necessary (Combat UI ↔ TBC) get laundered through indirection; encourages signal sprawl because adding to the bus is frictionless.
- **Rejection Reason**: For a solo dev, the topology *is* the documentation. A bus-for-everything erases it. The two genuine bus use-cases (transient/unauthored producer, unbounded broadcast) are covered by the hybrid at a fraction of the surface.

### Alternative 2: Pure direct signals (no bus)

- **Description**: No bus autoload; every subscriber holds a reference to its producer; the two `battle_ended` signals stay on different objects (TBC vs Overworld Navigation) and could even keep the same name.
- **Pros**: Maximally explicit; zero indirection; same-name-different-object is technically unambiguous.
- **Cons**: The Overworld Navigation relay has no stable home until #16 is authored — ZWM/EZ would have nothing to connect to, blocking their implementation; every Presentation screen needs producers injected at `_ready()` (wiring burden grows with each screen); same-name-different-object remains a reader footgun even if the engine disambiguates; unbounded-consumer broadcasts (`zone_states_changed` → map UI + audio + autosave) force every consumer into a ZWM dependency for a read-only notification.
- **Rejection Reason**: Blocks ZWM/EZ implementation on an unwritten system and leaves the name collision as a permanent code-review hazard.

### Alternative 3: String-topic pub/sub (dictionary-keyed publish/subscribe)

- **Description**: A bus with `publish(topic: String, payload: Dictionary)` / `subscribe(topic, callable)` — topics as strings, payloads as untyped dictionaries.
- **Pros**: Infinitely flexible; no declarations needed; new events cost zero schema work.
- **Cons**: Stringly-typed — typos fail silently at runtime; payload shapes unenforceable (the exact `battle_ended` dual-shape bug this ADR exists to kill, generalized to every event); no editor autocomplete/refactor support; contradicts the deprecated-apis registry's direction (string-based connect → typed connections).
- **Rejection Reason**: Reintroduces the project's highest-risk seam as a design principle. Typed, name-declared signals are the entire point.

## Consequences

### Positive

- The `battle_ended` cross-wiring bug class is **structurally eliminated** (distinct names, distinct objects, static contract test) — closes cross-review C-1 and blueprint QQ-02/QQ-03.
- ZWM and Encounter Zone can be implemented and tested against `EventBus.encounter_resolved` **before Overworld Navigation exists** — the contract outlives the producer's authoring schedule.
- Ordering-independence + payload self-sufficiency make every subscriber unit-testable in isolation and immune to connection-order refactors.
- The autosave quiesce point is deterministic and consistent by construction (deferred-after-cascade), not by fragile connection-order arrangement — and ADR-0001's open timing question is now closed.
- Injected LogSink makes every diagnostic GUT-assertable, uniformly with ADR-0001's persistence rules.
- Bus admission criteria keep the bus a closed, reviewable surface (3 signals at MVP) instead of a growth vector.

### Negative

- Two transport idioms coexist (direct + bus) — each new signal requires an admission-criteria judgment call (mitigated: the criteria are two boolean tests, and `bus_by_default` is a registered forbidden pattern reviewers check).
- Producers pay a `duplicate(true)` copy per emission of mutable collections (accepted: payloads are small dictionaries at turn cadence, not frame cadence).
- The relay hop (TBC → Overworld Nav → bus) adds one indirection to world-state updates (accepted: it is exactly where the vocabulary mapping and `encounter_type` attachment must live anyway).

### Neutral

- Combat UI connects Presentation-to-Core directly. Layering governs *calls and writes*; signal subscription is a read-only notification and Combat UI already depends on TBC to submit actions.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| EventBus registered after a system autoload that connects to it in `_ready()` → silent missing-node failure | Medium | High | **EventBus must be FIRST in the autoload list** — a project-settings constraint owned by ADR-0004; boot smoke test asserts `EventBus` exists before any system's `_ready()` runs |
| A miswired connection (wrong arity) only `push_error`s at emit time and execution continues — silent in playtests | Medium | High | Test-time connection auditor (arity introspection over all TBC + EventBus connections) + static name-contract test; both BLOCKING in CI |
| A subscriber mutates a payload collection, corrupting a sibling subscriber's view | Medium | Medium | Producers emit `duplicate(true)` copies (contract rule 4); GUT test mutates a received payload and asserts producer internals + other subscribers unaffected |
| Deferred autosave callable targets a freed Node → engine silently skips the save | Low | Medium | Save/Load is a permanent autoload (never freed); rule 6 confines `CONNECT_DEFERRED` to that one audited site |
| Signal re-entrancy (subscriber transitively re-triggers the signal being handled) double-processes | Low | High | Contract rule 5 bans it; TBC's FSM guard (`is_battle_active`) makes `battle_ended` terminal — a re-entrant `start_battle` inside a subscriber is refused |
| UI consumer forgets to disconnect on screen teardown → callable leak / stale handler | Medium | Low | Rule 7: `_exit_tree()` disconnect or `CONNECT_ONE_SHOT`; code-review checklist item |
| A future payload field nests containers deeper than one level → `duplicate(true)` no longer fully isolates | Low | Medium | Contract rule 4 requires documenting copy depth per payload; review gate on payload-shape changes |
| Bus roster grows past its admission criteria (god-object drift) | Medium | Medium | `bus_by_default` registered as a forbidden pattern; roster is enumerated here and in the registry — additions are diff-visible |

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/turn-based-combat.md` | TBC | Rule 12 — 8-field `battle_ended` payload; 2026-07-13 erratum: synchronous teardown ordering + signal-name disambiguation | `battle_ended` name/shape kept verbatim, owner-declared on TBC; teardown-after-emit generalized to contract rule 2; relay renamed so the disambiguation note is now structural |
| `design/gdd/symbot-core-progression.md` | Core Progression | Rule 3/3a — XP award on `battle_ended(VICTORY)`; first-defeat guard must be ordering-independent (payload-carried `is_first_boss_defeat`) | Direct connection to TBC; contract rule 3 (no inter-subscriber ordering, self-sufficient payloads) makes the guard's ordering-independence a project-wide invariant |
| `design/gdd/drop-system.md` | Drop System | Rule 1 — `battle_ended` VICTORY-only resolution trigger; deduplicated `fired_break_events` set | Direct connection to TBC; rule 4 guarantees Drop's copy of `fired_break_events` survives TBC's post-emit state discard |
| `design/gdd/zone-world-map.md` | Zone & World Map | `win_count += 1` on relayed 2-field battle end (WIN, WILD); `zone_states_changed(transitions)` with suppression-when-empty | Relay renamed `EventBus.encounter_resolved(result, encounter_type)`; `zone_states_changed` admitted to the bus (criterion 2); GDD synced this pass |
| `design/gdd/encounter-zone.md` | Encounter Zone | Rule 8 — gate re-evaluated on battle end + boss approach, never mid-battle | EZ connects to `EventBus.encounter_resolved`; synchronous cascade completes before the deferred autosave observes the re-evaluated gate; GDD synced this pass |
| `design/gdd/exploration-progress.md` | Exploration Progress | OQ-EP-2 / Rule 8 — save timing owned by Save/Load, at event-boundary quiesce points | § 4 defines the quiesce point and the deferred autosave trigger — closes ADR-0001's deferred timing question |
| `design/gdd/world-loot.md` | World Loot | `node_collected` notification; injected error sink | Owner-declared signal (direct); LogSink contract § 5 |
| `design/gdd/consumable-database.md` | Consumable DB | Beacon flag read by Drop at battle-end resolution (TBC-owned battle context) | Unaffected by the rename — Drop reads TBC's `battle_ended` (8-field) and TBC-owned context directly |
| `.claude/docs/technical-preferences.md` | Conventions | Signals snake_case past tense; GUT testability of logic systems | `encounter_resolved`, `zone_entered`, etc. conform; LogSink + ordering contract are the testability seams |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU | n/a | Signal dispatch is O(subscribers) at **turn/battle cadence**, never per-frame; `duplicate(true)` on small payload dicts is negligible | No measurable frame cost; no polling — state with a signal must never be polled per frame |
| Memory | n/a | EventBus is one stateless Node; payload copies are transient | Negligible |
| Load Time | n/a | One extra autoload | Negligible (folds into ADR-0004 boot budget) |
| Network | n/a | N/A | — |

## Migration Plan

Greenfield — no code exists; nothing migrates. The `encounter_resolved` rename is a **documentation-level migration** executed with this ADR: `zone-world-map.md` and `encounter-zone.md` are updated to name the relayed signal explicitly (closing cross-review C-1's remainder); `turn-based-combat.md` needs no edit (its Rule 12 name is kept). When Overworld Navigation (#16) is authored, its GDD must ratify the producer side of `encounter_resolved` — recorded in ADR Dependencies → Blocks.

**Rollback plan**: The admission criteria are the reversible part — if the hybrid split proves awkward, promoting a direct signal onto the bus (or demoting one) is a local change to one producer and its consumers; the ordering/teardown/LogSink contracts (the load-bearing rules) are transport-independent and survive either direction.

## Validation Criteria

- [ ] Static contract test: `EventBus` declares no signal named `battle_ended`; TBC declares no signal named `encounter_resolved`; the bus script contains exactly the 3-signal MVP roster.
- [ ] Connection auditor (GUT helper): every connection on TBC and EventBus has callable arity matching the signal's declared parameter count — a deliberately miswired fixture fails CI loudly.
- [ ] Ordering-independence: with CP and Drop connected in both orders (A,B / B,A), end state after `battle_ended(VICTORY, …)` is identical (XP totals, pity counters, inventory).
- [ ] Teardown: TBC discards runtime state only after emit returns — a subscriber reading the payload mid-dispatch sees complete data; `fired_break_events` received by Drop is a copy (mutating it does not affect TBC internals or a second subscriber).
- [ ] Deferred autosave: with subscribers connected in adversarial order, the autosave snapshot always observes post-cascade state (`win_count` incremented, `defeated_once` flipped, XP awarded) — asserted via a spy provider.
- [ ] Manual save during battle is refused (`is_battle_active() == true` → refuse); permitted immediately after `battle_ended` cascade completes.
- [ ] LogSink: CI grep finds zero `push_warning`/`push_error` calls in `src/`; a GUT spy captures a system-emitted warning with its `code` and `detail`.
- [ ] Boot order: a smoke test asserts EventBus exists before any system autoload's `_ready()` executes (EventBus first in the autoload list — ADR-0004).

## Related

- `docs/architecture/architecture.md` — § Data Flow 2 (the `battle_ended` seam), § API Boundaries (Event Bus), QQ-02/QQ-03/QQ-05, Required ADR-0002
- `docs/architecture/adr-0001-save-load.md` — save-trigger timing deferred to this ADR (§ 4 resolves it); injected-logger File Rule 7 generalized by § 5
- `design/gdd/gdd-cross-review-2026-07-13.md` — C-1 (the signal-name collision this ADR structurally closes)
- ADR-0004 (Scene/boot) — autoload order ("EventBus first") and boot smoke test (to be written)
- ADR-0007 (TBC FSM) — implements the emission points under this ADR's teardown contract (to be written)
- `docs/registry/architecture.yaml` — `combat_battle_end`, `world_encounter_relay`, `cross_system_eventing`, `subscriber_ordering_dependency`, `global_push_diagnostics`, `bus_by_default`
