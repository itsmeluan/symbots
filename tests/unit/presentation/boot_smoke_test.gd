## Boot smoke test — verifies EventBus and Log resolve as autoloads and that
## the EventBus declares EXACTLY the 3 closed-roster bus signals (ADR-0002 §1).
##
## These tests run headless without a scene tree. They exercise the autoload
## objects directly (GUT makes autoloads available as global names).
##
## ADR-0002 static contract: EventBus declares no "battle_ended"; TBC declares no
## "encounter_resolved". Validated here in the bus-roster contract test.
extends GutTest


# ---------------------------------------------------------------------------
# Boot smoke — autoload resolution
# ---------------------------------------------------------------------------

func test_event_bus_resolves_as_autoload() -> void:
	# EventBus must be available as a global name before any other autoload's
	# _ready() runs (EventBus-first constraint, ADR-0004 §1).
	assert_not_null(EventBus, "EventBus autoload must be reachable as a global name")
	assert_true(EventBus is Node, "EventBus must extend Node")


func test_log_resolves_as_autoload_with_sink() -> void:
	assert_not_null(Log, "Log autoload must be reachable as a global name")
	assert_not_null(Log.sink, "Log.sink must be non-null after autoload construction")
	assert_true(Log.sink is LogSink, "Log.sink must be a LogSink instance")


# ---------------------------------------------------------------------------
# Bus roster contract — exactly 3 signals, no forbidden cross-names
# ---------------------------------------------------------------------------

## Helper: collect SCRIPT-DECLARED signal names only. get_signal_list() would also
## return inherited Node built-ins (ready, renamed, tree_entered, …), masking the
## closed 3-signal roster; get_script_signal_list() returns only what the script declares.
func _signal_names(obj: Object) -> Array[StringName]:
	var names: Array[StringName] = []
	for sig: Dictionary in obj.get_script().get_script_signal_list():
		names.append(sig["name"])
	return names


func test_event_bus_declares_exactly_three_signals() -> void:
	var names: Array[StringName] = _signal_names(EventBus)
	assert_eq(names.size(), 3,
		"EventBus must declare EXACTLY 3 signals (closed roster, ADR-0002). Found: %s" % [names])


func test_event_bus_has_encounter_resolved() -> void:
	assert_true(EventBus.has_signal("encounter_resolved"),
		"EventBus must declare encounter_resolved (ADR-0002 §2)")


func test_event_bus_has_zone_states_changed() -> void:
	assert_true(EventBus.has_signal("zone_states_changed"),
		"EventBus must declare zone_states_changed (ADR-0002 §1)")


func test_event_bus_has_zone_entered() -> void:
	assert_true(EventBus.has_signal("zone_entered"),
		"EventBus must declare zone_entered (ADR-0002 §1)")


func test_event_bus_does_not_declare_battle_ended() -> void:
	# Static contract: battle_ended is owner-declared on TBC, NEVER on the bus.
	# Cross-wiring by name must be structurally impossible (ADR-0002 §2).
	assert_false(EventBus.has_signal("battle_ended"),
		"EventBus must NOT declare battle_ended (ADR-0002 §2 cross-wire prevention)")


func test_battle_controller_does_not_declare_encounter_resolved() -> void:
	# Mirror of the above: encounter_resolved lives on EventBus only.
	assert_false(TBC.has_signal("encounter_resolved"),
		"TBC autoload must NOT declare encounter_resolved (ADR-0002 §2)")


func test_battle_controller_declares_battle_ended() -> void:
	# TBC autoload (slot 11 wrapper) re-declares + forwards the 3 TBC signals.
	assert_true(TBC.has_signal("battle_ended"),
		"TBC autoload must declare (forwarded) battle_ended")


func test_battle_controller_declares_battle_start_refused() -> void:
	assert_true(TBC.has_signal("battle_start_refused"),
		"TBC autoload must declare (forwarded) battle_start_refused")


func test_battle_controller_declares_hit_resolved() -> void:
	assert_true(TBC.has_signal("hit_resolved"),
		"TBC autoload must declare (forwarded) hit_resolved")
