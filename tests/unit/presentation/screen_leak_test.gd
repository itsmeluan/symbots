## Screen leak test — verifies that a Screen subclass connecting a signal in setup()
## via _connect_owned() leaves ZERO dangling connections on the emitter after the
## screen is freed (ADR-0008 risk mitigation).
##
## Godot 4 does NOT reliably auto-drop connections when the subscriber is freed.
## The Screen base class auto-disconnects all _connect_owned() connections on
## NOTIFICATION_EXIT_TREE. This test exercises that teardown path.
##
## All spy/stub types are inner classes (not class_name-declared) per ADR-0002 §5.
extends GutTest


## A minimal persistent signal emitter that stands in for a long-lived owner such
## as CoreProgression or SynergyEvaluator.
class _FakeOwner extends Node:
	signal value_changed(new_value: int)


## A Screen subclass that subscribes to value_changed in setup().
class _TestScreen extends Screen:
	var received_values: Array[int] = []

	func setup(ctx: ServiceContext) -> void:
		_connect_owned(
			(_get_owner_ref() as _FakeOwner).value_changed,
			Callable(self, "_on_value_changed")
		)

	func _on_value_changed(new_value: int) -> void:
		received_values.append(new_value)

	## Inject the owner reference. Called by the test harness before setup().
	var _owner_ref: _FakeOwner = null
	func _get_owner_ref() -> _FakeOwner:
		return _owner_ref


var _owner: _FakeOwner = null


func before_each() -> void:
	_owner = _FakeOwner.new()
	add_child_autofree(_owner)


func test_signal_fires_before_screen_freed() -> void:
	var screen := _TestScreen.new()
	screen._owner_ref = _owner
	add_child(screen)
	screen.setup(null)

	_owner.value_changed.emit(42)

	assert_eq(screen.received_values.size(), 1,
		"Signal must reach the screen while it is alive")
	assert_eq(screen.received_values[0], 42,
		"Signal payload must be forwarded correctly")

	screen.queue_free()


func test_zero_dangling_connections_after_screen_freed() -> void:
	var screen := _TestScreen.new()
	screen._owner_ref = _owner
	add_child(screen)
	screen.setup(null)

	# Verify connected before free.
	assert_true(
		_owner.value_changed.is_connected(Callable(screen, "_on_value_changed")),
		"Connection must exist before free"
	)

	# Free the screen. NOTIFICATION_EXIT_TREE triggers _disconnect_all_owned().
	# remove_child + queue_free is the standard pattern that fires EXIT_TREE.
	remove_child(screen)
	screen.queue_free()

	# After removal from tree, the connection must be gone.
	assert_false(
		_owner.value_changed.is_connected(Callable(screen, "_on_value_changed")),
		"Screen._connect_owned() teardown must disconnect on EXIT_TREE — zero dangling connections"
	)


func test_signal_does_not_fire_into_freed_screen() -> void:
	var screen := _TestScreen.new()
	screen._owner_ref = _owner
	add_child(screen)
	screen.setup(null)

	remove_child(screen)
	screen.queue_free()

	# Emitting after teardown must not fire into the freed screen.
	# If the connection were still live, Godot would push_error (invalid instance).
	# We assert the connection count on the emitter is zero.
	var connection_count: int = _owner.value_changed.get_connections().size()
	assert_eq(connection_count, 0,
		"No connections must remain on the emitter after screen is freed")


func test_duplicate_connect_is_guarded() -> void:
	# _connect_owned must not connect twice if the signal+callable pair is already registered.
	var screen := _TestScreen.new()
	screen._owner_ref = _owner
	add_child(screen)

	# Manually call _connect_owned twice with the same callable.
	var cb := Callable(screen, "_on_value_changed")
	screen._connect_owned(_owner.value_changed, cb)
	screen._connect_owned(_owner.value_changed, cb)  # second call should be a no-op

	_owner.value_changed.emit(7)

	# If the guard works, the signal fires exactly once (not twice).
	assert_eq(screen.received_values.size(), 1,
		"_connect_owned must guard against duplicate connections (no double-fire)")

	remove_child(screen)
	screen.queue_free()
