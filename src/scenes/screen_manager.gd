## ScreenManager — sole owner of all screen transitions (ADR-0004 §2, ADR-0008).
##
## THE only object that creates, frees, shows, or hides screens. All other systems
## request transitions by calling methods on their injected ScreenManager reference —
## they never perform transitions themselves (`unowned_scene_transition` forbidden).
##
## Screens never navigate themselves: no `add_child` from gameplay code, no
## `queue_free` from a screen on itself, no `get_parent()` climbing.
##
## OVERWORLD KEEP-ALIVE PATTERN (ADR-0004 §3):
##   On battle entry: hide + PROCESS_MODE_DISABLED + gui_release_focus().
##   On encounter_resolved: queue_free the Battle screen, show + restore Overworld.
##   The Overworld node is never destroyed across battle round-trips.
##
## TEARDOWN RULE (ADR-0002 teardown contract):
##   Battle screens MUST be torn down with queue_free(), NEVER free().
##   The battle_ended → encounter_resolved cascade is still unwinding when
##   ScreenManager receives encounter_resolved; queue_free() defers destruction
##   to the end of the idle step, after all synchronous subscribers have returned.
class_name ScreenManager
extends Node

## The ServiceContext bundle. Assembled by BootScreen at step 4b; passed to every
## screen's setup() call.
var _ctx: ServiceContext = null

## The currently active foreground screen. ScreenManager tracks this for teardown.
var _active_screen: Screen = null

## The Overworld screen instance when alive (kept between battles — never destroyed
## during the battle round-trip, ADR-0004 §3). Null until goto_overworld() first runs.
var _overworld: Screen = null

## True when a transition is in flight (TransitionLayer is covering input).
## Guards against double-tap / re-entrant transition calls.
var _transitioning: bool = false

## Cached TransitionLayer sibling (set in _ready via @onready path).
## get_node_or_null (not get_node): in production game.tscn the sibling exists; when
## ScreenManager is instantiated standalone (unit tests) it is legitimately absent —
## transition-layer usage is all Phase-4 TODO, so null here is expected, not an error.
@onready var _transition_layer: CanvasLayer = get_parent().get_node_or_null("TransitionLayer")


func _ready() -> void:
	# Subscribe to EventBus.encounter_resolved with a named Callable (ADR-0008).
	# ScreenManager is permanent — this connection is intentionally never disconnected.
	EventBus.encounter_resolved.connect(Callable(self, "_on_encounter_resolved"))


# ---------------------------------------------------------------------------
# Boot handoff — called by BootScreen to inject the ServiceContext
# ---------------------------------------------------------------------------

## Called by BootScreen at the end of its run_boot() sequence (boot step 7 shape).
## Stores the context so all future screen instantiations can receive it.
func set_context(ctx: ServiceContext) -> void:
	_ctx = ctx


# ---------------------------------------------------------------------------
# Transition API — all methods are the ONLY legal entry points for screen changes
# ---------------------------------------------------------------------------

## Navigate to the Main Menu screen. Frees any active non-Overworld screen.
## TODO (Phase 3 / BootScreen story): instantiate MainMenu, call setup(_ctx), add.
func goto_main_menu() -> void:
	pass  # TODO: instantiate MainMenu when authored


## Navigate to the Overworld. If the Overworld has been keep-alive'd (hidden during
## battle), restores it. If not yet instantiated, creates it.
## Only valid after SaveLoad restore + rederive are complete (ADR-0004 §5).
## On restore from battle keep-alive: show() + PROCESS_MODE_INHERIT (idempotent).
func goto_overworld() -> void:
	# Already alive (keep-alive'd during a battle) — restore rather than re-create.
	if _overworld != null:
		_overworld.process_mode = Node.PROCESS_MODE_INHERIT
		_overworld.show()
		return

	var scene: PackedScene = load("res://src/scenes/overworld_screen.tscn")
	if scene == null:
		Log.sink.warn(&"overworld_screen_not_found", {})
		return
	var overworld: Screen = scene.instantiate()
	add_child(overworld)          # _ready runs here — node refs valid for setup()
	overworld.setup(_ctx)         # inject the ServiceContext (ADR-0008 §1)
	_overworld = overworld


## Enter battle from Overworld. Hides + disables Overworld (keep-alive); creates
## BattleScreen; calls setup(_ctx); adds to tree.
##
## 4.6/4.7 dual-focus rule (ADR-0004 §2, ADR-0008 §3): call
## get_viewport().gui_release_focus() BEFORE adding the Battle screen so any
## keyboard/gamepad focus held by an Overworld Control does not remain "live" while
## the Overworld is hidden. `grab_focus()` drives keyboard-only focus in 4.6;
## mouse/touch focus is separate — absorbing pointer events alone is insufficient.
##
## [param encounter_payload] — Dictionary passed through to BattleScreen.setup_battle().
func enter_battle(encounter_payload: Dictionary) -> void:
	if _transitioning:
		return
	_transitioning = true

	# Dual-focus guard (4.6/4.7): release keyboard/gamepad focus before hiding.
	get_viewport().gui_release_focus()

	# TODO: show TransitionLayer fade when authored.

	# Overworld keep-alive: hide + disable processing/input (ADR-0004 §3).
	# NOTE: PROCESS_MODE_DISABLED suppresses _process, _physics_process,
	# _unhandled_input, timers, tweens, and AnimationPlayers in the subtree.
	# It does NOT suppress _input on plain Node subclasses — Overworld code must
	# use _unhandled_input only. Any exception must call set_process_input(false).
	if _overworld != null:
		_overworld.hide()
		_overworld.process_mode = Node.PROCESS_MODE_DISABLED

	var battle_scene: PackedScene = load("res://src/scenes/battle_screen.tscn")
	if battle_scene == null:
		Log.sink.warn(&"battle_screen_not_found", {})
		_transitioning = false
		return
	var battle: Screen = battle_scene.instantiate()
	add_child(battle)               # _ready builds the UI
	battle.setup(_ctx)              # inject ServiceContext + subscribe (ADR-0008 §1)
	# begin_encounter is BattleScreen-specific (not on the Screen base) — call by name.
	battle.call(&"begin_encounter", encounter_payload)
	_active_screen = battle
	_transitioning = false


## Called when EventBus.encounter_resolved fires. Tears down the active Battle screen
## (queue_free — NEVER free(); the cascade may still be unwinding, ADR-0002) and
## restores the Overworld from keep-alive.
func _on_encounter_resolved(result: int, encounter_type: int) -> void:
	# Tear down battle screen — queue_free so the cascade unwinds first (ADR-0002).
	if _active_screen != null:
		_active_screen.queue_free()
		_active_screen = null

	# Restore Overworld from keep-alive (ADR-0004 §3).
	if _overworld != null:
		_overworld.process_mode = Node.PROCESS_MODE_INHERIT
		_overworld.show()

	_transitioning = false


## Open the Workshop over the Overworld. Keeps the Overworld alive but hidden +
## PROCESS_MODE_DISABLED (same keep-alive discipline as battle entry, ADR-0004 §3), then
## instantiates + injects the WorkshopScreen as the active foreground screen.
func open_workshop() -> void:
	if _transitioning or _active_screen != null:
		return  # already have a foreground screen (workshop or battle) — ignore re-entry
	_transitioning = true
	get_viewport().gui_release_focus()

	if _overworld != null:
		_overworld.hide()
		_overworld.process_mode = Node.PROCESS_MODE_DISABLED

	var scene: PackedScene = load("res://src/scenes/workshop_screen.tscn")
	if scene == null:
		Log.sink.warn(&"workshop_screen_not_found", {})
		_restore_overworld()
		_transitioning = false
		return
	var workshop: Screen = scene.instantiate()
	add_child(workshop)          # _ready builds the UI
	workshop.setup(_ctx)         # inject ServiceContext + subscribe (ADR-0008 §1)
	_active_screen = workshop
	_transitioning = false


## Close the Workshop and restore the Overworld from keep-alive.
func close_workshop() -> void:
	if _active_screen != null:
		_active_screen.queue_free()
		_active_screen = null
	_restore_overworld()
	_transitioning = false


## Shared keep-alive restore: show + re-enable the Overworld (ADR-0004 §3).
func _restore_overworld() -> void:
	if _overworld != null:
		_overworld.process_mode = Node.PROCESS_MODE_INHERIT
		_overworld.show()
