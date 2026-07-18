## Screen — base class for all game screens (ADR-0008 §1).
##
## Extends Control. Every game screen (BootScreen, MainMenu, Overworld, Battle,
## Workshop) extends Screen and implements setup(ctx).
##
## CONTRACT:
##   1. ScreenManager calls add_child(screen) THEN setup(ctx) — _ready/@onready
##      run during add_child, so node references are valid by the time setup() fires.
##   2. setup() is called ONCE, before the screen is shown. Override it to cache
##      dependencies and subscribe signals via _connect_owned().
##   3. On NOTIFICATION_EXIT_TREE, all connections registered with _connect_owned()
##      are auto-disconnected, then _on_exit_tree() is called for subclass cleanup.
##
## FORBIDDEN PATTERNS (control-manifest.md, ADR-0008):
##   view_state_polling — do NOT poll model state in _process / _physics_process.
##     Subscribe to owner signals and render as a pure function of the last payload.
##   undisconnected_view_subscription — every connect() in setup() MUST go through
##     _connect_owned() so EXIT_TREE teardown disconnects it. Godot 4 does NOT
##     reliably auto-drop connections when the subscriber is freed; a dangling
##     connection to a persistent owner (CoreProgression, SynergyEvaluator) fires
##     into a freed node — a use-after-free class of bug (ADR-0008 risk noted).
##
## NAMED CALLABLE DISCIPLINE (ADR-0008):
##   Always pass Callable(self, "_on_something") — never a lambda that closes over
##   self or ctx. Lambda captures can silently extend the ServiceContext lifetime
##   past the screen and prevent reference-counted teardown.
class_name Screen
extends Control


## Connections registered via _connect_owned(). Disconnected atomically on EXIT_TREE.
## Each entry: {signal: Signal, callable: Callable}
var _owned_connections: Array[Dictionary] = []


## Override in subclasses. Called ONCE by ScreenManager after add_child(), before
## the screen is shown. Cache deps and subscribe signals here using _connect_owned().
## Do NOT connect signals in _ready() — use setup() so teardown is guaranteed.
func setup(ctx: ServiceContext) -> void:
	pass


## Godot notification handler. Handles EXIT_TREE to auto-disconnect all owned
## connections and call the subclass hook. Subclasses that override _notification
## MUST call super._notification(what) first.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_disconnect_all_owned()
		_on_exit_tree()


## Subclass hook called after owned connections are disconnected. Override for
## additional cleanup (e.g. cancelling tweens, releasing references). Call
## super._on_exit_tree() at the top of any override.
func _on_exit_tree() -> void:
	pass


## Register a signal connection that will be automatically disconnected on EXIT_TREE.
## [param sig] — the Signal to connect (e.g. some_node.some_signal).
## [param callable] — a named Callable: Callable(self, "_on_something").
##   NEVER pass a lambda — lambdas cannot be individually disconnected and may
##   silently extend the lifetime of captured variables past screen teardown.
## Connecting the same signal+callable pair twice is guarded: a duplicate is logged
## and skipped rather than connected twice (double-fire hazard).
func _connect_owned(sig: Signal, callable: Callable) -> void:
	# Guard: skip if already connected (prevents double-fire on re-entry).
	if sig.is_connected(callable):
		Log.sink.warn(&"screen_duplicate_connect",
			{"screen": get_script().resource_path, "callable": callable.get_method()})
		return
	sig.connect(callable)
	_owned_connections.append({"signal": sig, "callable": callable})


## Disconnect all registered connections. Called automatically on EXIT_TREE.
## Safe to call multiple times — is_connected() guards each disconnect.
func _disconnect_all_owned() -> void:
	for entry: Dictionary in _owned_connections:
		var sig: Signal = entry["signal"]
		var callable: Callable = entry["callable"]
		if sig.is_connected(callable):
			sig.disconnect(callable)
	_owned_connections.clear()
