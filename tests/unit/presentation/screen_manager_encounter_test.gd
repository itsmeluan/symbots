## ScreenManager test — verifies that emitting EventBus.encounter_resolved invokes
## ScreenManager._on_encounter_resolved (round-trip wiring test, ADR-0004 §3).
##
## ScreenManager subscribes to EventBus.encounter_resolved in its _ready(). This test
## instantiates a ScreenManager in an add_child harness, emits the signal, and asserts
## the handler ran (via a spy subclass).
extends GutTest

## Spy subclass that records whether _on_encounter_resolved was invoked.
## preload()-ed — NOT class_name-declared (ADR-0002 §5: class_name in tests/ pollutes
## the production global class registry).
class _SpyScreenManager extends ScreenManager:
	var encounter_resolved_calls: int = 0
	var last_result: int = -1
	var last_encounter_type: int = -1

	func _on_encounter_resolved(result: int, encounter_type: int) -> void:
		encounter_resolved_calls += 1
		last_result = result
		last_encounter_type = encounter_type
		# Do NOT call super — we don't want the real teardown logic in this unit test.


var _spy: _SpyScreenManager = null


func before_each() -> void:
	_spy = _SpyScreenManager.new()
	# add_child triggers _ready, which connects the signal.
	add_child_autofree(_spy)


func after_each() -> void:
	# Signal cleanup: if _spy is still alive and still connected, disconnect.
	# add_child_autofree will queue_free() but we want an explicit guard here.
	if is_instance_valid(_spy):
		if EventBus.encounter_resolved.is_connected(
				Callable(_spy, "_on_encounter_resolved")):
			EventBus.encounter_resolved.disconnect(
				Callable(_spy, "_on_encounter_resolved"))


func test_encounter_resolved_emit_invokes_screen_manager_handler() -> void:
	assert_eq(_spy.encounter_resolved_calls, 0,
		"No calls before signal is emitted")

	EventBus.encounter_resolved.emit(1, 1)  # WIN=1, WILD=1

	assert_eq(_spy.encounter_resolved_calls, 1,
		"_on_encounter_resolved must be called exactly once after emit")


func test_encounter_resolved_passes_result_and_type() -> void:
	EventBus.encounter_resolved.emit(2, 2)  # LOSS=2, BOSS=2

	assert_eq(_spy.last_result, 2, "result payload must be forwarded correctly")
	assert_eq(_spy.last_encounter_type, 2, "encounter_type payload must be forwarded correctly")


func test_screen_manager_still_connected_after_multiple_emits() -> void:
	# Verifies no CONNECT_ONE_SHOT was used accidentally (connection must be permanent).
	EventBus.encounter_resolved.emit(1, 1)
	EventBus.encounter_resolved.emit(1, 2)

	assert_eq(_spy.encounter_resolved_calls, 2,
		"ScreenManager connection must be permanent (not one-shot)")
