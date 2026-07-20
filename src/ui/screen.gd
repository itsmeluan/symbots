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


## Append the shared bottom navigation to [param container] (the screen's root VBox),
## lit on [param active], and route its taps through [param on_nav] — a Callable the screen
## passes as `func(d): navigate.emit(d)`. The dock knows nothing about the screens; the
## screen forwards, the game root routes.
func _attach_bottom_dock(container: Node, active: StringName, on_nav: Callable) -> void:
	var dock := BottomDock.new()
	dock.navigate.connect(on_nav)
	container.add_child(dock)
	dock.set_active(active)


## Install a full-screen background image behind the screen's content, dimmed so the UI
## panels stay legible on top. A missing texture is a no-op — a screen without its art
## still works, just on the flat backdrop.
##
## Added as the FIRST child so it sits behind everything, and mouse-ignoring so taps fall
## through to the controls. Call from setup() BEFORE building the layout, or the content
## will end up behind the image.
func _set_background(path: String, dim: float = 0.55) -> void:
	if not ResourceLoader.exists(path):
		return
	var bg := TextureRect.new()
	bg.texture = load(path)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# A dark scrim so text and panels read against busy art.
	var scrim := ColorRect.new()
	scrim.color = Color(UIPalette.INK, dim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


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
