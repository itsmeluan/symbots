# Presentation-Tier Foundation — Implementation Plan

> **Status**: APPROVED 2026-07-18 (user). Executable spec for the foundation build that
> unblocks `/team-ui battle` Phase 3. Authored by godot-specialist; ratified by user.
> **Owner routing**: `.gd` → godot-gdscript-specialist / gameplay-programmer; scenes/project/
> architecture → godot-specialist; battle screen → ui-programmer. All subagents `model: sonnet`.

## Context

`/team-ui battle` reached implementation and found the presentation tier greenfield:
`project.godot` has no autoloads, no `src/ui/`, no `Screen`/`ServiceContext`/`ScreenManager`/
`Game` root/`BootScreen`. Core battle + content logic exists. `BattleController` is a per-session
`RefCounted` emitting only `battle_ended`, `battle_start_refused`, `hit_resolved`.

## Ratified decisions

1. **BattleController form = Option A (autoload wrapper).** A thin `Node` autoload (slot 11)
   holds/creates the per-session `BattleController` RefCounted, proxies `start_battle`/
   `submit_action`/`is_battle_active`, and forwards its signals. Pure core untouched. Honors
   ADR-0007 §1 + ADR-0001/0002 global `is_battle_active()` quiesce. No ADR erratum needed.
2. **Scope = full ADR-0004 foundation** (BootScreen sequencer, catalog loading, Overworld
   keep-alive) — not the minimal vertical-slice cut.

---

## 1. Autoload / boot roster (ADR-0004 §1, amended 10→11 by ADR-0007)

Register in `project.godot` `[autoload]`. Set `run/main_scene` = `res://src/scenes/game.tscn`
(currently the prototype). `Game.tscn` is the main scene, NOT an autoload.

| Slot | Name | Script | Build now? |
|---|---|---|---|
| 1 | `EventBus` | `src/autoloads/event_bus.gd` | **Real** — declares only the 3 bus signals (`encounter_resolved`, `zone_states_changed`, `zone_entered`); zero logic |
| 2 | `Log` | `src/autoloads/log_autoload.gd` | **Real** — hosts the existing `LogSink`, exposes `Log.sink` |
| 3 | `PartDB` | `src/autoloads/part_db_autoload.gd` | Wrapper over `src/core/content/part_db.gd`; `load_catalog(catalog, log)` |
| 4 | `EnemyDB` | `src/autoloads/enemy_db_autoload.gd` | Wrapper |
| 5 | `MoveDB` | `src/autoloads/move_db_autoload.gd` | Wrapper |
| 6 | `PassiveDB` | `src/autoloads/passive_db_autoload.gd` | Wrapper |
| 7 | `ConsumableDB` | `src/autoloads/consumable_db_autoload.gd` | Wrapper |
| 8 | `WorldLootDB` | `src/autoloads/world_loot_db_autoload.gd` | Stub (`load_catalog` no-op; DB not authored) |
| 9 | `RngService` | `src/autoloads/rng_service_autoload.gd` | `init()`/`next_seed()`/`make_rng()` (ADR-0006) |
| 10 | `SaveLoad` | `src/autoloads/save_load_autoload.gd` | Provider registry + autosave + quiesce (ADR-0001) |
| 11 | `TBC` | `src/autoloads/battle_controller_autoload.gd` | **Option A wrapper** — creates/holds the `BattleController` RefCounted, proxies API, forwards signals. **Singleton is `TBC`, NOT `BattleController`** (that name is the core `class_name`; a same-named autoload throws "hides an autoload singleton"). Matches ADR-0002 §4's `TBC.is_battle_active()`. See ADR-0007 §1 erratum (2026-07-18). |

All autoloads: **zero `_ready` work** (ADR-0004 inertness rule — boot orchestration belongs to
BootScreen). DB wrappers move no logic; they are stable global names delegating to `src/core/content/`.

`Game.tscn` root scene = `ScreenManager (Node)` + `TransitionLayer (CanvasLayer)` only.

---

## 2. `Screen` base class (ADR-0008 §1) — `src/ui/screen.gd`

`class_name Screen extends Control`. Contract:
- `func setup(ctx: ServiceContext) -> void` — called ONCE by ScreenManager at instantiation,
  before shown. Subclass caches deps + subscribes signals here via `_connect_owned(sig, callable)`.
- `_notification(what)` → on `NOTIFICATION_EXIT_TREE` auto-disconnects every `_connect_owned`
  connection, then calls overridable `_on_exit_tree()` (subclasses `super._on_exit_tree()` first).
- **Named Callables only** (lambdas can't be individually disconnected).
- **Forbidden**: `_process` polling of game state (`view_state_polling`); a subscription without
  teardown (`undisconnected_view_subscription`). Enforced by review + a CI grep over `src/ui/`,
  not by the engine. Register both in `docs/architecture/control-manifest.md`.

## 3. `ServiceContext` (ADR-0004 "injected at instantiation") — `src/ui/service_context.gd`

`extends RefCounted`. Bundles: `screens: ScreenManager`, `build`, `synergy: SynergySystem`,
`progression` (Variant until CoreProgression exists), `log: LogSink`. **BattleController is reached
as the global autoload (Option A)** — NOT carried in ServiceContext. `BootScreen` assembles the
one ServiceContext at boot step 4b; `ScreenManager` holds it and passes it to every `setup(ctx)`.

## 4. `ScreenManager` (ADR-0004 §2) — `src/scenes/screen_manager.gd`

`extends Node`. Holds `_ctx: ServiceContext` + `_active_screen: Screen`. API:
- `enter_battle(encounter_payload)` — TransitionLayer.show() + `gui_release_focus()` (4.6/4.7
  dual-focus guard) → instantiate BattleScreen → `setup(_ctx)` → add + show.
- `_on_encounter_resolved(result, encounter_type)` — subscribed to `EventBus.encounter_resolved`
  in `_ready` (named Callable, never disconnected — manager is permanent). **`queue_free()` NOT
  `free()`** (battle_ended cascade still unwinding, ADR-0002).
- `goto_main_menu()` / `goto_overworld()` / `open_workshop()` / `close_workshop()` +
  Overworld keep-alive (hide/disable/restore) — full scope; Overworld scene stubbed until authored.
- Screens never navigate themselves — they request via ScreenManager.

---

## 5. `BattleController` view-signals (ADR-0002: owner-declared, NOT bus additions)

Add to `src/core/battle/battle_controller.gd` (or forwarded through the Option A wrapper). Bus
admission criteria are NOT met (sole consumer = battle screen; stable authoritative producer);
adding to EventBus would trip `bus_by_default`. Emission sites reference the real methods:

| Signal | Params | Emit at (battle_controller.gd) |
|---|---|---|
| `action_pending` | `actor_is_player: bool` | `_run_turns()` where `_state = ACTION_PENDING` (~L324) |
| `action_resolving` | — | `submit_action()` where `_state = RESOLVING` (~L339) |
| `round_started` | `round_number: int, turn_order: Array` | `_begin_round()` after `compute_initiative()` (~L287) |
| `turn_started` | `combatant_id: StringName, is_player: bool` | `_run_turns()` after `begin_turn(actor)` (~L303) |
| `turn_skipped` | `combatant_id: StringName` | `_run_turns()` when `ts["skipped_action"]` (overheat skip) |
| `structure_changed` | `combatant_id, new_value, max_value, is_player` | after every `current_structure` mutation: `begin_turn` Burn tick, `_settle_heat` overheat dmg, `_apply_item_effect`, + on target from `_on_resolver_hit` (~L599) |
| `energy_changed` | `combatant_id, new_value, max_value` | `_resolve_player_move` spend (~L373), `begin_turn` recharge (~L224) |
| `heat_changed` | `combatant_id, new_value, is_overheated` | `_settle_heat` (~L264), `begin_turn` overheat-reset |
| `status_applied` | `combatant_id, status_id, duration` | forward from `StatusSet`/`BattleResolver` (needs a StatusSet hook) |
| `status_expired` | `combatant_id, status_id` | `end_turn()` → `statuses.decrement_turn()` (~L248) removal (needs hook) |
| `status_ticked` | `combatant_id, status_id, damage` | `begin_turn` Burn tick path |
| `combatant_downed` | `combatant_id, is_player` | `_down(c)` (~L567) |
| `forced_switch_required` | — | where `_state = FORCED_SWITCH` (`_resolve_enemy_action` ~L410, `_handle_turn_start_death` ~L475) |
| `overheat_triggered` | `combatant_id, self_damage` | `_settle_heat` when `is_overheated` set true |
| `break_region_updated` | `enemy_id, region_id, new_hp, max_hp, is_broken` | **STUB decl only** — needs Part-Break routed through resolver |
| `enrage_changed` | `enemy_id, broken_count, enrage_pct` | **STUB decl only** — needs Part-Break integration |

Prefer value-type payloads over passing live `Combatant` refs (keeps the view decoupled from
mutable internals). **Test impact**: additive decls break nothing; each emit must NOT re-enter the
FSM (ADR-0002 rule 5). GUT: spy-Callable subscriber, fixed seeds/stats, assert fires-once + payload
+ post-emit FSM state. Verify test COUNT rises per new test (class_name→`--import` gotcha).

---

## 6. Build sequence (dependency order)

```
Phase 0-A  project.godot autoloads + main_scene            [godot-specialist]
Phase 0-B  stub/real autoload scripts (EventBus, Log real) [godot-specialist]
   ├── Phase 1-A  Game.tscn + ScreenManager                [godot-specialist]
   │      └── Phase 1-B  Screen base + ServiceContext       [godot-specialist/gameplay-programmer]
   │             └── Phase 4  BattleScreen UI               [ui-programmer]
   └── Phase 2-A  BattleController view-signals (∥ Phase 1) [gameplay-programmer]
          └── Phase 2-B  BattleController autoload wrapper   [godot-specialist]
Phase 3    BootScreen 7-step sequencer (after 1-A)          [godot-specialist/gameplay-programmer]
```

GUT obligations per story: 0-A boot smoke (EventBus exists before any `_ready`); 0-B static
roster contract (bus has exactly 3 signals, no cross-naming); 1-A encounter_resolved round-trip;
1-B leak test (subscribe in setup → free → zero dangling); 2-A per-signal fire+payload+FSM;
2-B autoload inertness + proxy; 3 boot integration (step order via LogSink breadcrumbs + BootError
on broken fixtures); 4 screen-tree audit (≥44 min-size), leak test, dual-input (touch + mouse).

## 7. Godot 4.7 re-validation flags (VERSION.md: ADRs reasoned vs 4.6)

- **GH-115763** — any `Control`/`Screen` typed-return override needs explicit `return`.
- **InputEventScreenTouch** — dual-input test MUST synthesize touch, not mouse; verify
  `gui_release_focus()` on 4.7 (verify against `docs/engine-reference/godot/`).
- **PROCESS_MODE_DISABLED** suppresses `_unhandled_input` but NOT `_input` — assert in Overworld
  inertness test.
- **FoldableContainer** recursive-disable propagation — verify before use in combat log; else
  per-node `mouse_filter`.
- **Virtual-px vs pt** — `custom_minimum_size` is virtual px; on-device calibration gates any
  ≥44pt touch-target audit (Phase 4).
- **DisplayServer.get_display_safe_area()** — verify 4.7 signature before Phase 4.

## 8. Full-scope note

Overworld keep-alive (hide/disable/restore) is in scope but needs an Overworld scene that does
not exist yet — those methods are stubbed until the Overworld screen is authored. BootScreen
steps 3–8 (catalog load + ContentValidator) run against real or fixture catalogs; a broken
fixture must render BootError with zero DB reads.
