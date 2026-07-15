# Control Manifest

> **Engine**: Godot 4.6
> **Last Updated**: 2026-07-14
> **Manifest Version**: 2026-07-14
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed this
date when created. `/story-readiness` compares a story's embedded version to this
field to detect stories written against stale rules. It always matches
`Last Updated` — the same date serving two different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. Where the ADRs explain *why*,
this sheet tells you *what*. For the reasoning behind any rule, read the
referenced ADR. Every rule traces to an ADR, `docs/registry/architecture.yaml`, a
technical preference, or an engine reference doc — nothing here is invented.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns
- **Save providers implement the triad `snapshot() -> Dictionary` / `restore(data: Dictionary)` / `rederive()`; `snapshot()` returns plain data only** (Dictionary/Array/int/float/String/bool) into a single-file JSON envelope written atomically — source: ADR-0001
- **Honor the `save_emergency()` lifecycle path** for background/termination saves — source: ADR-0001
- **New cross-system signals default to owner-declared typed signals with direct connections**; a signal may join the closed 3-signal EventBus roster ONLY if it meets an ADR-0002 admission criterion (transient/unauthored producer, or unbounded-consumer world-state broadcast) — adding one requires an ADR-0002 amendment — source: ADR-0002
- **Signal payloads are self-sufficient and read-only** — carry everything consumers need; consumers that mutate copy first via `dict.duplicate(true)` / `array.duplicate(true)`. Emit is synchronous; state may be discarded only after `emit()` returns (teardown contract) — source: ADR-0002
- **Route all diagnostics through the injected `LogSink`** (`warn(code, detail)` / `error(...)` / `info(...)`), never global `push_warning()` / `push_error()` — source: ADR-0002
- **Content ships as typed `.tres` defs resolved through explicit catalog reference chains via `ResourceLoader`**; one catalog per DB — source: ADR-0003
- **Content defs and catalogs are frozen shared instances**; content-def `@export` enums declare explicit integer values starting at 1 (0 = reserved/invalid) and are APPEND-ONLY (never reorder/insert/renumber) — source: ADR-0003
- **Read content exclusively via the DB singletons' typed getters** (`content_db_lookup` contract) — source: ADR-0003
- **Persistent Game root + ScreenManager; the Overworld is kept alive across battles; boot runs through an explicit BootScreen sequencer; the autoload roster is fixed at 11 slots** — source: ADR-0004
- **All initialization is driven explicitly by the BootScreen sequencer, in code, in order**; autoloads are thin hosts — source: ADR-0004
- **Screens request transitions on their injected `ScreenManager` reference**; Battle teardown is `queue_free()` by ScreenManager only, never `free()` — source: ADR-0004 (`screen_transitions` contract)

### Forbidden Approaches
- **Never return a live Godot `Resource` (or a Dict/Array holding one) from a save `snapshot()`** — flatten to plain data first; a leaked Resource reopens the HIGH serialization risk (`live_resource_in_save_snapshot`) — source: ADR-0001
- **Never write a subscriber that depends on running before/after another subscriber of the same signal** — connection order is boot-order-dependent and silently breaks on reorder (`subscriber_ordering_dependency`) — source: ADR-0002
- **Never call `push_warning()` / `push_error()` from `src/`** — global diagnostics are invisible to GUT tests (`global_push_diagnostics`) — source: ADR-0002
- **Never add a signal to the EventBus for routing convenience** — admission is gated (`bus_by_default`) — source: ADR-0002
- **Never mutate a content def/catalog field at runtime, and never call `duplicate()` / `duplicate_deep()` on any def or catalog** — copy specific fields into your own runtime structs instead (`runtime_content_mutation`) — source: ADR-0003
- **Never list content directories with `DirAccess`** in the load path — `.remap` stubs make `*.tres` scans return nothing post-export (`content_directory_scanning`) — source: ADR-0003
- **Never reorder/insert/renumber existing content-def enum values** — `.tres` stores raw ints; renumbering silently re-labels authored content (`content_enum_reordering`) — source: ADR-0003
- **Never do I/O, catalog loads, signal connections, or cross-autoload reads in an autoload `_ready`** — thin hosts only (`autoload_ready_work`) — source: ADR-0004
- **Never perform a screen transition outside ScreenManager** — no `change_scene_to_packed/file()`, no `add_child/free/queue_free` of screen scenes, no `get_parent()` climbing to reach the manager (`unowned_scene_transition`) — source: ADR-0004

### Performance Guardrails
- **Save write**: ≤ 2 MiB serialized and ≤ 50 ms on iOS — source: ADR-0001

---

## Core Layer Rules

*Applies to: core gameplay loop, stat pipeline, RNG/determinism, turn-based battle FSM*

### Required Patterns
- **The pure formula core lives in `src/core/stats/`; its owners are DI RefCounted objects, not autoloads** — source: ADR-0005
- **All effective-stat composition (SYN-F4 = `maxi(0, final + synergy + aura)`) goes through the single point `StatMath.effective_stat` / `CombatantSnapshot.effective_stat`** — TBC damage, initiative, and every UI display call it — source: ADR-0005
- **`CombatantSnapshot` is frozen at BATTLE_INIT; battle code reads the frozen snapshot only** — in-battle changes are TBC-owned modifiers layered on top of `effective_stat()` — source: ADR-0005
- **A single `BalanceConfig` `.tres` is the sole tuning source** — source: ADR-0005
- **Damage is computed via the `compute_damage` pure static function** (`damage_computation` contract) — source: ADR-0005
- **Randomness arrives injected as `seed: int` or `RandomNumberGenerator`**; `RngService` (autoload slot 9) vends `next_seed() -> int` and `make_rng() -> RandomNumberGenerator` from one root — source: ADR-0006
- **`RngService.init()` is the ONLY sanctioned `randomize()` call in the project** — source: ADR-0006
- **`BattleController` (autoload slot 11) owns `is_battle_active: bool` + the `_state` FSM (enum + `match`)** — source: ADR-0007
- **Per-battle mutable state lives in a RefCounted `BattleContext` the controller drops synchronously AFTER the `battle_ended` emit() cascade returns** (RefCounted — no `queue_free`) — source: ADR-0007
- **The action seam is event-driven**: a player turn parks by setting `_state` and returning, resuming via `BattleController.submit_action(action)` (guarded no-op unless `_state == ACTION_PENDING`); an enemy turn runs a synchronous `EnemyAI.request_move(snapshot)` through the same `_resolve()` path — source: ADR-0007
- **`is_battle_active()` is the only cross-system read** of battle state (SaveLoad manual-save quiesce gate, ADR-0002 §4) — source: ADR-0007

### Forbidden Approaches
- **Never reimplement SYN-F4 outside the two legal sites** (`StatMath.effective_stat` / `CombatantSnapshot.effective_stat`) — copies drift on first patch (`inline_stat_composition`) — source: ADR-0005
- **Never call `StatPipeline.derive` or `SynergyEvaluator.evaluate/evaluate_silent` after BATTLE_INIT, and never hold a reference into the live `SymbotBuild` or evaluator cache from battle code** (`mid_battle_stat_recompute`) — source: ADR-0005
- **Never call `@GlobalScope` `randf()/randi()/randi_range()/randf_range()` or `randomize()` in gameplay/formula code** — all randomness is injected (`global_rng_access`) — source: ADR-0006
- **Never reference the `RngService` autoload from `src/core/` or gameplay resolvers** — randomness arrives strictly as a parameter; only orchestrators (BootScreen, TBC, the Drop resolver's owner) call `RngService` (`rng_service_in_formula_code`) — source: ADR-0006
- **Never put `is_battle_active` or `_state` on the Battle scene node or a transient screen** — they live on the persistent `BattleController` autoload; per-battle state lives in the RefCounted `BattleContext` (`battle_state_on_transient_node`) — source: ADR-0007
- **Never retain a reference to the `BattleContext` (or anything transitively holding it) past the `battle_ended` cascade; snapshots must not back-reference the context** — GDScript has no cycle collector (`battle_context_leak_past_teardown`) — source: ADR-0007
- **Never `await` across `ACTION_PENDING`** (no `var action = await …`, no polling loop) — a suspended coroutine held through teardown/save/re-entrancy is a use-after-free class (`coroutine_park_across_action`) — source: ADR-0007

### Performance Guardrails
- **Battle FSM transitions stay synchronous** — no `await` across `ACTION_PENDING`; every stop-point is testable — source: ADR-0007

---

## Feature Layer Rules

*Applies to: enemy AI, drop/loot rolling, secondary battle mechanics*

### Required Patterns
- **`EnemyAI.request_move` is a pure function**: it rebuilds its `RandomNumberGenerator` from the injected seed on EVERY call and caches no instance between calls — source: ADR-0006 (enemy-ai Rule 3) / registry `persistent_shared_rng_across_calls`
- **TBC vends `crit` + `ai` seeds only; the Drop resolver owns its own RNG vend** — source: ADR-0007 / registry `rng_vending` (the Drop-side vend is a forward constraint on the not-yet-authored Drop ADR, not yet ratified combat behavior)

### Forbidden Approaches
- **Never cache or reuse a `RandomNumberGenerator` across successive pure-function calls** — a reused instance carries stream state, so identical inputs yield different outputs by call history (`persistent_shared_rng_across_calls`) — source: ADR-0006 (enemy-ai Rule 3 / AC-EAI-06)

---

## Presentation Layer Rules

*Applies to: UI, screens, HUD, in-battle views, preview panels*

### Required Patterns
- **The `Screen` base extends `Control` with a one-shot `setup(ctx: ServiceContext)`**; ScreenManager `add_child()`s the screen (triggering `_ready`/`@onready`) BEFORE calling `setup(ctx)` — source: ADR-0008 (`screen_contract`)
- **Views are signal-driven**: subscribe in `setup`, disconnect on `NOTIFICATION_EXIT_TREE` via the `_connect_owned(sig, callable)` helper, binding named-method Callables (`Callable(self, "_on_x")`), NEVER lambdas that close over `self`/`ctx` — source: ADR-0008
- **Touch-first unified press-release path**: every action fires from the press-release both a mouse click and a touch tap raise; interactive Controls set `custom_minimum_size >= Vector2(44, 44)` (virtual px — calibrate against content scale); hover/tooltips are enhancement-only; keyboard focus optional (honors the 4.6 dual-focus split) — source: ADR-0008
- **Previews reuse the pure core** — `SynergyEvaluator.preview` + `StatPipeline` hypothetical derive + `compute_damage`; never reimplement a formula for display — source: ADR-0008
- **Styling goes through one shared project `Theme`** (`assets/ui/theme.tres`) with shared StyleBoxes — source: ADR-0008

### Forbidden Approaches
- **Never poll model state in `_process`/`_physics_process`** — subscribe to owner signals and render as a pure function of the last payload (`view_state_polling`) — source: ADR-0008
- **Never leave a subscription to a persistent owner connected when the screen frees** — disconnect on `NOTIFICATION_EXIT_TREE`; Godot 4.6 does NOT reliably auto-drop the connection (`undisconnected_view_subscription`) — source: ADR-0008
- **Never make an affordance discoverable/triggerable ONLY via hover or ONLY via keyboard/gamepad focus** — touch has no hover and 4.6 keyboard focus is separate (`hover_only_affordance`) — source: ADR-0008
- **Never carry per-widget unique material/shader instances on UI nodes**; also watch `clip_contents = true`, nested `CanvasLayer`, and per-frame `RichTextLabel`/BBCode updates — each breaks 2D batching (`ui_unique_material_batch_break`) — source: ADR-0008

### Performance Guardrails
- **Per screen**: ≤ 200 draw calls (the per-screen draw-call smoke check is the gate) — source: ADR-0008 (TR-perf-003)
- **No per-frame view work**: no `_process`/`_physics_process` state polling; views update only on signal — source: ADR-0008

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `SymbotController`, `PartDatabase` |
| Variables / Functions | snake_case | `move_speed`, `take_damage()` |
| Signals / Events | snake_case, past tense | `health_changed`, `part_equipped`, `battle_ended` |
| Files | snake_case matching class | `symbot_controller.gd` |
| Scenes / Prefabs | PascalCase matching root node | `SymbotController.tscn`, `BattleScreen.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_PARTS_PER_SLOT`, `BASE_DAMAGE_MULTIPLIER` |

### Performance Budgets
| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.6 ms |
| Draw calls | 200 (conservative for mobile 2D) |
| Memory ceiling | 512 MB (iOS safe ceiling for 2D RPG) |

### Approved Libraries / Addons
- **GUT** (Godot Unit Testing) — approved for automated testing (`addons/gut/`). The only approved addon so far.

### Forbidden APIs (Godot 4.6)
These are deprecated or must be replaced. Mirrors `docs/engine-reference/godot/deprecated-apis.md` (last verified 2026-02-12) row-for-row — if an agent suggests anything in the "Deprecated" column, replace it with "Use Instead".

**Nodes & Classes**
| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |

**Methods & Properties**
| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` | `instantiate()` | 4.0 |
| `PackedScene.instance()` | `PackedScene.instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| `Skeleton3D` signal `bone_pose_updated` | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |

> ⚠️ **`duplicate()` → `duplicate_deep()` applies to general nested resources ONLY.** It does **NOT** apply to content defs/catalogs (`PartDef`, `EnemyDef`, `MoveDef`, `PassiveDef`, `ConsumableDef`, `LootNodeDef`) — for those, **NEVER** call `duplicate()` OR `duplicate_deep()`; copy specific fields instead. See forbidden `runtime_content_mutation` (ADR-0003).

**Patterns**
| Deprecated Pattern | Use Instead | Why |
|--------------------|-------------|-----|
| String-based `connect()` | Typed signal connections | Type-safe, refactor-friendly |
| `$NodePath` in `_process()` | `@onready var` cached reference | Avoids per-frame path lookup |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | Compiler optimizations |
| `Texture2D` in shader parameters | `Texture` base type | Changed in 4.4 |
| Manual post-process viewport chains | `Compositor` + `CompositorEffect` | Structured post-processing (4.3+) |
| GodotPhysics3D for new projects | Jolt Physics 3D | Default since 4.6; better stability |

Source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints
- **Static typing enforced** on all GDScript (typed vars, `Array[Type]`, typed signals) — source: coding-standards / deprecated-apis patterns
- **Doc comments on all public APIs** — source: coding-standards
- **Gameplay values are data-driven** (external config / `.tres`), never hardcoded — source: coding-standards
- **Dependency injection over singletons** — all public methods must be unit-testable — source: coding-standards
- **80% minimum coverage** for game-logic systems (combat formulas, synergy, part-stat aggregation); balance formulas, gameplay systems, and build/part synergy require tests — source: technical-preferences (Testing)
- **Touch-first UI** — design every interaction for touch from day one (≥ 44×44 targets, no hover-only affordances); Mac keyboard/mouse is the dev/early-launch platform, iOS is the long-term primary target — source: technical-preferences (Input & Platform)
