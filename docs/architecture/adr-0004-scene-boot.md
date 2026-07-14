# ADR-0004: Scene Management & Boot / Initialization Order

## Status
Proposed

## Date
2026-07-13

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scene management |
| **Knowledge Risk** | LOW overall — the engine-reference library records no post-cutoff (4.4/4.5/4.6) changes to scene-tree lifecycle, autoload semantics, `process_mode`, or `queue_free()`. **Exception**: the 4.6 dual-focus input system (verified post-cutoff change — `input.md`, `ui.md`, `breaking-changes.md` 4.5→4.6) directly constrains the TransitionLayer input-blocking contract (Decision §2) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `modules/input.md`, `modules/ui.md` |
| **Post-Cutoff APIs Used** | None directly; the 4.6 dual-focus system (mouse/touch focus tracked separately from keyboard/gamepad focus) shapes the TransitionLayer rule — pointer absorption alone does not block keyboard activation of a focused Control beneath the layer |
| **Verification Required** | (1) `PROCESS_MODE_DISABLED` suppression of `_input` on plain `Node` subclasses (not Controls) — reference library silent for 4.4–4.6; the inertness test must assert `_input` delivery too, not just `_unhandled_input`; (2) whether a `hide()`n CanvasItem retaining keyboard focus (via a previously-focused Control child) still receives keyboard `gui_input` under the 4.6 dual-focus split — mitigated by `gui_release_focus()` on battle entry regardless; (3) `Signal.connect(callable, CONNECT_DEFERRED)` flag semantics unchanged in 4.6 (very likely; library silent); (4) `queue_free()` on the Battle screen and the deferred autosave landing in the same idle step — confirm the autosave (provider reads, no scene reads) is unaffected by teardown order |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (two-phase restore contract, REFUSE semantics, save quiesce); ADR-0002 (EventBus FIRST in autoload order; CONNECT_DEFERRED autosave sites; synchronous-emit teardown contract); ADR-0003 (catalog loading via `load_catalog(catalog, log_sink)`; dev-boot ContentValidator gate) |
| **Enables** | Coding start — this is the last of the four Foundation ADRs; every implementation epic boots through this sequence |
| **Blocks** | All implementation epics (nothing runs without boot); Overworld Navigation GDD #16 (must author against the ScreenManager battle-entry contract defined here) |
| **Ordering Note** | This ADR sequences what ADR-0001/0002/0003 defined; it introduces no new data contracts, only lifecycle and ordering. |

## Context

### Problem Statement
Three prior Foundation ADRs defined *what* exists — save providers, the EventBus, content catalogs — but not *when* anything initializes, *who* owns screen transitions, or *what happens when a boot step fails*. The blueprint mandates the logical order (DBs load → services → restore → rederive → gameplay) and the scene flow (Main Menu → Overworld → Battle → Workshop), and hands this ADR two explicit constraints: EventBus first in the autoload order (ADR-0002) and catalogs-then-validate before any consumer (ADR-0003). The highest-frequency transition in the game — Overworld → Battle → Overworld — must preserve player position and derived zone state without re-derivation.

### Constraints
- **Registry (locked stances)**: EventBus FIRST in autoload order (`cross_system_eventing`); catalogs load via DI'd `load_catalog` + dev-boot validation (`content_authoring`); restore is two-phase and REFUSE leaves memory unchanged (`save_provider`); Save/Load's bus connections are the only CONNECT_DEFERRED sites (`world_encounter_relay`); boot diagnostics via LogSink (`global_push_diagnostics`).
- **Teardown contract (ADR-0002)**: signals emit synchronously; the Battle screen may be dismantled only after the full `battle_ended` → `encounter_resolved` cascade unwinds. Freeing the emitter mid-cascade is a use-after-free class of bug.
- **Coding standard**: DI over singletons — autoloads may host, but logic must be injectable and unit-testable.
- **Platform**: iOS primary — screens must be cheap to keep resident; no reliance on desktop-only lifecycle.

### Requirements
- Deterministic, reviewable boot order with a visible failure state for every fatal step (TR init-order set, TR-ep-004: restore completes before any derived state is computed).
- Explicit transition ownership — systems request transitions; exactly one owner performs them.
- Overworld state (position, camera, derived zone states) survives battle round-trips (zone-world-map / encounter-zone: return to `EXPLORING`).
- New Game and Continue flow through the same restore→rederive path (one code path to test).

## Decision

**A persistent `Game` root scene owns a `ScreenManager` that performs all screen transitions; autoloads are thin hosts that do nothing in `_ready`; an explicit Boot screen drives the entire initialization sequence in code; the Overworld stays alive (hidden + disabled) during battle.**

### 1. Autoload roster and order

`project.godot` autoload list, in this exact order:

| # | Autoload | Role | `_ready` work |
|---|----------|------|---------------|
| 1 | `EventBus` | signal declarations ONLY (ADR-0002) | none (it has no logic at all) |
| 2 | `Log` | hosts the production LogSink instance | none (construct sink only) |
| 3–8 | `PartDB`, `EnemyDB`, `MoveDB`, `PassiveDB`, `ConsumableDB`, `WorldLootDB` | content lookup hosts (ADR-0003) | **none — catalogs are NOT loaded here** |
| 9 | `RngService` | injected-seed RNG factory (spec: ADR-0006) | none |
| 10 | `SaveLoad` | provider registry + save/load engine (ADR-0001) | none — providers register and bus connections happen in boot step 6 |

**Rule: autoloads do no work in `_ready`.** No I/O, no catalog loads, no signal connections, no cross-autoload reads. They are containers whose *initialization* is driven explicitly by the Boot screen (below). This makes the boot order reviewable code instead of editor-settings order, lets every failure reach a visible error screen, and keeps each host trivially constructible in GUT. EventBus stays first regardless — it must exist before anything *can* connect, and its zero-logic design makes it order-immune in both directions.

### 2. Scene graph — persistent root + ScreenManager

```text
Game.tscn (main scene — never replaced)
├── ScreenManager (Node)                    # THE transition owner
│   ├── BootScreen        (first screen; freed after handoff)
│   ├── MainMenu          (instantiated on demand)
│   ├── Overworld         (kept ALIVE during battle: hidden + PROCESS_MODE_DISABLED)
│   ├── Battle            (instantiated per encounter; queue_free'd on resolution)
│   └── Workshop          (instantiated on demand)
└── TransitionLayer (CanvasLayer)           # fades + input blocking during swaps
```

- **Only the ScreenManager creates, frees, shows, or hides screens.** Systems and UI *request* transitions through the ScreenManager reference injected into each screen at instantiation (DI — screens never `get_parent()`-climb or hard-reference the manager). Performing a scene swap from anywhere else is a forbidden pattern.
- The `TransitionLayer` blocks input during any swap, so a transition can never be re-entered mid-flight (double-tap on an encounter cannot start two battles). **4.6 dual-focus rule**: when the layer activates it must also call `get_viewport().gui_release_focus()` — in 4.6, keyboard/gamepad focus is tracked separately from pointer focus, and absorbing pointer events does NOT stop `ui_accept` from activating a still-focused Control beneath the layer.
- Godot's global `change_scene_to_*` APIs are unused — the root is permanent.

### 3. Battle round-trip — Overworld keep-alive

```text
ENTER:  Overworld Nav (#16) resolves the encounter → screen_manager.enter_battle(encounter_payload)
        → Overworld: hide() + process_mode = PROCESS_MODE_DISABLED
                     + get_viewport().gui_release_focus()            (drop any lingering keyboard focus)
          # DISABLED suppresses _process, _physics_process, _unhandled_input, node timers,
          # tweens, and AnimationPlayers for the subtree. It does NOT suppress _input on
          # plain Node subclasses — Overworld code uses _unhandled_input only (never _input);
          # any exception must additionally call set_process_input(false) on entry.
        → Battle instantiated, injected with the payload; TBC runs the fight

EXIT:   TBC emits battle_ended (8-field, synchronous)
        → Overworld Nav maps result → relays EventBus.encounter_resolved (nested synchronous emit)
        → ScreenManager (subscribed to EventBus.encounter_resolved):
            battle_screen.queue_free()      # NEVER free() — the cascade is still unwinding;
                                            # queue_free defers destruction to the end of the
                                            # idle step (post all current-frame callbacks).
                                            # NOT a guarantee for later subscribers: any
                                            # subscriber running after ScreenManager sees the
                                            # node alive but is_queued_for_deletion() == true
                                            # and must not dereference it
            Overworld: show() + process_mode restored → player exactly where they stood
        → Save/Load's CONNECT_DEFERRED autosave fires at the next idle poll — it reads
          provider state only (never scene nodes), so battle teardown order is irrelevant to it
```

Player position, camera, and the derived zone states survive because the node was never destroyed — no re-derivation (ZWM-F2), no position snapshot contract, nothing to restore. The dormant Overworld is one hidden 2D scene: trivial against the 512MB ceiling.

`ScreenManager` subscribing to `EventBus.encounter_resolved` is a legitimate bus consumption: the signal is already on the closed roster, and the manager is exactly the kind of cross-layer consumer the relay exists for (ADR-0002 admission unchanged — no new bus signals).

### 4. Boot sequence — explicit, sequential, fail-visible

`BootScreen` (the first screen ScreenManager shows) drives every step:

```gdscript
# boot_screen.gd — the ONLY place initialization order exists
func run_boot() -> void:
    var log := Log.sink                                    # 1. acquire the production LogSink
                                                           #    (Log.sink is declared `var sink: LogSink`
                                                           #     so inference stays typed, not Variant)
    for db in _content_dbs():                              # 2. load all 6 catalogs (ADR-0003)
        var catalog := load(db.catalog_path)               #    ResourceLoader — no DirAccess
        if catalog == null or not db.host.load_catalog(catalog, log):
            return _fail_boot(&"boot_catalog_failed", {"db": db.name})
    if OS.is_debug_build():                                # 3. content-validation gate (dev only)
        var report := ContentValidator.new().validate(_catalogs(), log)
        if not report.ok:
            return _fail_boot(&"boot_content_invalid", {"errors": report.errors.size()})
    RngService.init()                                      # 4. RNG factory ready (ADR-0006)
    for p in _save_providers():                            # 5. register providers (ADR-0001)
        SaveLoad.register_provider(p.key, p.provider)
    SaveLoad.connect_autosave_triggers()                   # 6. EventBus.encounter_resolved +
                                                           #    zone_entered, CONNECT_DEFERRED —
                                                           #    the project's ONLY deferred sites
    _screen_manager.goto_main_menu()                       # 7. handoff; BootScreen freed.
                                                           #    MUST stay the LAST statement —
                                                           #    goto_main_menu() queue_frees this
                                                           #    node; code after it would run on a
                                                           #    node marked for deletion
```

**Failure policy**: any fatal step routes to `_fail_boot(code, detail)` — LogSink.error + a `BootError` screen showing the code. There is no partial boot: a game that cannot load its content does not reach the menu. (Release builds skip step 3 but steps 2's structural failures — missing catalog, null entry, duplicate ID — still fail loud.)

### 5. New Game / Continue — one restore path

Save restore does **not** happen during boot. The Main Menu offers:

- **Continue** → `SaveLoad.load(slot)`: EP-PRED-1 version predicate → Phase 1 `restore()` per provider → Phase 2 `rederive()` (zone states via ZWM-F2, core levels via CP-F1) → `screen_manager.goto_overworld()`. A REFUSE (bad version, corrupt file) leaves all in-memory state unchanged (ADR-0001) — the menu shows the error and stays; the player is never dropped into a half-restored world.
- **New Game** → providers initialize their documented fresh-state defaults, then the **same Phase 2 `rederive()`** runs before entering the Overworld. New Game is "restore from nothing" — one derivation code path, tested once.

TR-ep-004 is satisfied structurally: derivation is a phase that only ever runs after restore (or fresh-init) completes, and gameplay screens are unreachable before it.

### Architecture Diagram

```text
 autoload phase (thin hosts, no work)          Boot screen (explicit sequence)
┌──────────────────────────────────┐   ┌──────────────────────────────────────────┐
│ 1 EventBus   2 Log   3-8 six DBs │──▶│ catalogs → validate(debug) → RngService  │
│ 9 RngService 10 SaveLoad         │   │ → providers → autosave connects → MENU   │
└──────────────────────────────────┘   └───────────────┬──────────────────────────┘
                                              fatal? → BootError screen (code + LogSink)
                                                       ▼
                    ┌─────────────── ScreenManager (sole transition owner) ───────────────┐
                    │ MainMenu ──Continue/NewGame: restore→rederive──▶ Overworld           │
                    │ Overworld ◀──── keep-alive (hidden+disabled) ────▶ Battle            │
                    │     ▲  enter_battle(payload) / queue_free on encounter_resolved  │   │
                    │ Workshop ◀──────────────────────────────────────▶ Overworld          │
                    └──────────────────────────────────────────────────────────────────────┘
```

### Key Interfaces

```gdscript
# ScreenManager — the ONLY object that performs transitions.
# Injected into every screen at instantiation (screens never locate it themselves).
func goto_main_menu() -> void
func goto_overworld() -> void                    # only valid after restore/fresh-init + rederive
func enter_battle(encounter_payload: Dictionary) -> void   # Overworld Nav's entry point
func open_workshop() -> void
func close_workshop() -> void
# Battle exit is NOT a method — ScreenManager subscribes to EventBus.encounter_resolved
# and tears down via queue_free() (never free(): the synchronous cascade must unwind first).

# Boot contract per content DB host (ADR-0003 shape, sequenced here):
# load_catalog(catalog, log_sink) called by BootScreen, in code, in order — never in _ready.

# SaveLoad boot hooks:
func register_provider(key: StringName, provider: Object) -> void
func connect_autosave_triggers() -> void         # the project's only CONNECT_DEFERRED sites
```

## Alternatives Considered

### Alternative 1: Engine-native full scene swaps (`change_scene_to_packed`)
- **Description**: Each screen is a root scene; transitions replace the whole tree; autoloads carry cross-screen state.
- **Pros**: Fully engine-idiomatic; zero screen-management code; screens are perfectly isolated.
- **Cons**: The Overworld is destroyed on every battle — the game's most frequent transition — forcing a position/camera snapshot contract and a ZWM-F2 zone-state re-derivation per fight; transition effects and input locking have no persistent home; state accumulates in autoloads, against the DI standard.
- **Rejection Reason**: Pays the highest cost on the hottest path to save code on the coldest. The keep-alive requirement alone rules it out.

### Alternative 2: Mobile push/pop screen stack
- **Description**: Screens push onto a navigation stack; back-gesture pops.
- **Pros**: Familiar iOS navigation semantics; Workshop-over-Overworld is a natural push.
- **Cons**: Four screens with a mostly fixed flow don't need a stack; stack invariants (what may sit under Battle? can Workshop stack on Battle? — no, combat-lock) become validation code for states the design forbids.
- **Rejection Reason**: The generality buys nothing the fixed flow needs and creates states that must be forbidden again. The ScreenManager's explicit methods ARE the legal-transition list.

### Alternative 3: Autoload `_ready` chain as the boot driver
- **Description**: Each autoload initializes itself in `_ready`; `project.godot` list order is the boot order.
- **Pros**: No Boot screen; engine does the sequencing.
- **Cons**: Ordering lives in editor settings, invisible in code review; a catalog failure during autoload init has no scene tree to show an error on (black-screen death); testing the sequence means replicating the autoload environment; cross-autoload reads during `_ready` are exactly the hidden-coupling pattern the coding standard bans.
- **Rejection Reason**: Boot is the one sequence that must be reviewable, testable, and fail-visible — the three things `_ready`-chain boot cannot provide.

## Consequences

### Positive
- Boot order is one readable function; every fatal step has a visible failure state and a LogSink code.
- Battle round-trips are free: no re-derivation, no snapshot contract, position preserved by construction.
- One restore→rederive path serves Continue and New Game — tested once, TR-ep-004 structural.
- Transition legality is the ScreenManager's method list — illegal transitions don't exist rather than being checked.
- Thin-host autoloads keep every piece of logic constructible in GUT without a scene tree.

### Negative
- One more scene (BootScreen) and a manager node that engine-native swaps wouldn't need.
- The dormant Overworld holds memory during battle (trivial now; revisit if overworld scenes grow dramatically post-MVP).
- ScreenManager is a single chokepoint — every new screen touches it (deliberate: that's the review surface).
- Screens receive an injected manager reference — one more wiring step at instantiation.
- `SceneTree.current_scene` always returns `Game.tscn` — Godot's remote debugger tree view and any tool reading that property see only the root. GUT tests that need the full graph must instantiate `ScreenManager` (or `Game.tscn`) directly in a test harness rather than relying on `get_tree().current_scene`; a future crash reporter must log the active screen from ScreenManager, not from the tree.

### Risks

| Risk | Mitigation |
|------|-----------|
| A hidden-but-alive Overworld still processes input or physics | Verification item #1: inertness test asserts no `_process`/`_physics_process`/`_unhandled_input` **and no `_input`** delivery while disabled; Overworld code standard: `_unhandled_input` only, never `_input` (exceptions must `set_process_input(false)` on battle entry) |
| Someone frees the Battle screen with `free()` during the `battle_ended` cascade | The ADR-0002 teardown contract + `queue_free()`-only rule here; code review flag + the miswire auditor can grep for `\.free()` on screens |
| A future `encounter_resolved` subscriber runs after ScreenManager and dereferences the Battle node | The node is still alive but `is_queued_for_deletion() == true`; ADR-0002's payload-self-sufficiency rule already forbids reaching into the emitter's scene — enforce it in review; subscribers consume the payload only |
| iOS suspends the app mid-battle, between `battle_ended` and the deferred autosave | The `Game` root implements `_notification()` for `NOTIFICATION_APPLICATION_PAUSED` and triggers a **synchronous** save of provider state, bypassing the CONNECT_DEFERRED path (exact iOS notification name is a pre-implementation verification item — medium drift risk) |
| Keyboard/gamepad focus survives under the TransitionLayer or a hidden Overworld (4.6 dual-focus) | `gui_release_focus()` on TransitionLayer activation and on battle entry (Decision §2/§3); verification item #2 |
| Boot steps silently reorder as the sequence grows | The boot integration test asserts the step order via LogSink breadcrumbs (each step logs a `boot_step` info entry) |
| A future screen bypasses ScreenManager (`add_child` from gameplay code) | Forbidden pattern registered (`unowned_scene_transition`); static grep test for `change_scene_to` anywhere in `src/` |
| Autosave and battle teardown interleave at the same idle step | Autosave reads provider state only, never scene nodes (ADR-0001 providers are plain-data snapshots); verification item #2 confirms |
| Overworld Nav (#16, Not Started) authors a different battle-entry shape | Its GDD must consume `enter_battle(encounter_payload)` as defined here — recorded in Blocks + the errata backlog forward-obligation |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| exploration-progress.md | TR-ep-004: restore before any derivation | Restore/fresh-init → rederive is a sequenced phase gate; gameplay unreachable before it |
| zone-world-map.md | Zone states derived on load, never trusted from disk; recompute on `encounter_resolved` | Phase 2 rederive runs ZWM-F2; Overworld keep-alive preserves derived state across battles |
| encounter-zone.md | Battle exit returns to `EXPLORING` with world state intact | Keep-alive round-trip: hide/disable → queue_free Battle → show/restore |
| turn-based-combat.md | Battle lifecycle; teardown only after `battle_ended` consumers finish | `queue_free()`-only teardown after the synchronous cascade (ADR-0002 contract applied) |
| save-load (ADR-0001 GDD set) | Save quiesce points; REFUSE leaves memory unchanged | Autosave connects in boot step 6 (deferred sites); Continue-REFUSE stays in menu |
| part/enemy/move/passive/consumable/world-loot DBs | Catalogs loaded before any consumer | Boot step 2 precedes everything; DBs are inert until then |
| enemy-ai / drop-system / encounter-zone (RNG consumers) | Injected-seed RNG available before gameplay | RngService initialized in boot step 4, before any screen that rolls |

## Performance Implications
- **CPU**: Boot is 6 catalog loads + one validation pass (debug) — well under a second of one-time work. Runtime: one dormant scene's zero processing (disabled).
- **Memory**: Dormant Overworld during battle — one 2D scene, negligible vs the 512MB ceiling.
- **Load Time**: Perceived startup = boot sequence + menu; content volume (~130 records) keeps this trivial. BootScreen doubles as the splash — the catalog `load()` calls are synchronous and main-thread, so any per-catalog hitch is player-visible. If a catalog exceeds ~50ms on the iOS test device, migrate boot step 2 to `ResourceLoader.load_threaded_request()` with a progress bar; the BootScreen already owns the sequence, so that is a contained refactor, not a redesign.
- **Network**: N/A.

## Migration Plan
None — greenfield. Implementation order: Game root + ScreenManager + BootScreen skeleton → autoload registration (thin hosts) → boot steps land as their ADRs' systems are implemented (catalogs first, save providers as they exist).

## Validation Criteria
- [ ] Boot integration test: full sequence runs headless, LogSink breadcrumbs assert step order (catalogs → validate → rng → providers → autosave → menu)
- [ ] Each fatal boot step, when fed a broken fixture, reaches BootError with the right code (no black-screen death)
- [ ] Overworld inertness test: while hidden+disabled, no `_process`/`_physics_process`/`_unhandled_input` **/`_input`** delivery, and no keyboard `gui_input` reaching a previously-focused hidden Control (verification items #1, #2)
- [ ] TransitionLayer focus test: with a Control focused, activate the layer — `ui_accept` must not trigger the underlying Control (4.6 dual-focus)
- [ ] Battle round-trip test: enter → resolve → return; player position and zone states identical, Battle node freed by end of frame
- [ ] `free()` never called on a screen anywhere in `src/` (static grep test); no `change_scene_to_*` anywhere in `src/`
- [ ] Continue with a REFUSE-class save: menu error shown, all in-memory state unchanged
- [ ] New Game and Continue both pass through the same rederive function (coverage assertion, not duplicate code paths)
- [ ] Autoload `_ready` bodies are empty of work (review checklist + grep for I/O calls in autoload scripts)

## Related Decisions
- ADR-0001 — Save/Load (providers, two-phase restore, REFUSE; autosave trigger sites sequenced here)
- ADR-0002 — Event bus (EventBus-first constraint discharged; teardown contract applied to Battle; ScreenManager as `encounter_resolved` consumer)
- ADR-0003 — Content resources (catalog loading + dev-boot validation gate sequenced as boot steps 2–3)
- ADR-0006 — RNG strategy (RngService init slot reserved at boot step 4)
- docs/architecture/architecture.md — §Data Flow 4 (initialization order made concrete)
