## SaveLoad — save/load provider registry + autosave + quiesce gate (ADR-0001; ADR-0004 §1 slot 10).
##
## Thin Node wrapper over [SaveLoadService], which is a pure RefCounted holding all the
## real logic: envelope format, atomic writes, two-phase restore, REFUSE semantics, the
## budget guard and the opaque-provider hold. This autoload exists only because autoloads
## must be Nodes and because signal subscriptions need an object that outlives every
## scene — the service itself stays testable without a scene tree.
##
## ADR-0004 inertness rule: zero _ready work. The service is constructed lazily on first
## use, providers register from BootScreen step 5, autosave connects at step 6.
##
## The two EventBus autosave sites use CONNECT_DEFERRED and are the ONLY sanctioned
## deferred connections in the project (ADR-0002 §4): the snapshot must observe world
## state AFTER the whole synchronous post-battle cascade has run. Connecting them
## non-deferred would persist a half-applied battle result.
##
## The callables target THIS autoload rather than a scene node — a scene node can be
## queue_free()'d out from under a subscription to a permanent producer, which is a
## use-after-free waiting to happen.
extends Node

const SaveLoadServiceScript := preload("res://src/persistence/save_load_service.gd")

## Slot used for the single-save MVP. The service supports more; the game exposes one.
const DEFAULT_SLOT := 0

var _service = null
var _log: LogSink = null
var _autosave_connected := false


## Give the autoload its log sink. Called by BootScreen before provider registration.
func setup(log: LogSink) -> void:
	_log = log


## Register [param provider] under [param key] for the snapshot/restore/rederive
## lifecycle. Called by BootScreen step 5, never in _ready.
func register_provider(key: StringName, provider: Object) -> void:
	_ensure_service()
	_service.register_provider(key, provider)


## Connect the deferred autosave trigger sites (ADR-0002 §4, ADR-0004 boot step 6).
## Idempotent: BootScreen runs once per process today, but a second call must not stack a
## duplicate subscription that would double every autosave.
func connect_autosave_triggers() -> void:
	if _autosave_connected:
		return
	EventBus.encounter_resolved.connect(_on_encounter_resolved, CONNECT_DEFERRED)
	EventBus.zone_entered.connect(_on_zone_entered, CONNECT_DEFERRED)
	_autosave_connected = true


## True when a battle is in progress (ADR-0002 §4 quiesce gate for manual save).
## Delegates to the TBC autoload at call time — never cached, because the answer changes
## within a frame and a stale copy would let a save land mid-battle.
func is_battle_active() -> bool:
	return TBC.is_battle_active()


## Write current state to [param slot]. Refuses mid-battle: a snapshot taken while a
## BattleContext is live captures a half-resolved fight no restore path expects.
func save(slot: int = DEFAULT_SLOT) -> Dictionary:
	if is_battle_active():
		return {ok = false, reason = "battle_active"}
	_ensure_service()
	return _service.save(slot)


## Load [param slot] into the registered providers. Returns `{ok=false, reason}` without
## touching any provider when the file is absent or the envelope is refused — the
## "leaves in-memory state exactly as before" guarantee belongs to the service.
func load_slot(slot: int = DEFAULT_SLOT) -> Dictionary:
	_ensure_service()
	return _service.load(slot)


func has_save(slot: int = DEFAULT_SLOT) -> bool:
	_ensure_service()
	return _service.has_save(slot)


## Emergency synchronous save — called from the Game root on
## NOTIFICATION_APPLICATION_PAUSED (iOS background/termination, ADR-0001 File Rule 8).
## Bypasses the deferred autosave path because there may be no next frame to defer to.
func save_emergency() -> void:
	_ensure_service()
	_service.save_emergency()


func _on_encounter_resolved(_result: int, _encounter_type: int) -> void:
	_autosave(&"encounter_resolved")


func _on_zone_entered(_zone_id: StringName) -> void:
	_autosave(&"zone_entered")


## Autosave never blocks play: a failed write is logged and the game continues. Losing a
## save is bad; freezing the player out of the game because a write failed is worse.
func _autosave(trigger: StringName) -> void:
	if is_battle_active():
		return
	var result := save(DEFAULT_SLOT)
	if _log == null:
		return
	if result.get("ok", false):
		_log.info(&"autosave_ok", {"trigger": String(trigger)})
	else:
		_log.warn(&"autosave_failed",
			{"trigger": String(trigger), "reason": str(result.get("reason", "unknown"))})


func _ensure_service() -> void:
	if _service == null:
		_service = SaveLoadServiceScript.new(_log)
