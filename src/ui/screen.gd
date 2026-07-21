## Screen — base class for all game screens (ADR-0008 §1).
##
## Extends Control. Every game screen (BootScreen, MainMenu, Overworld, Battle,
## Workshop) extends Screen and implements setup(ctx).
##
## CONTRACT:
##   1. The game root calls add_child(screen) THEN setup(ctx) — _ready/@onready
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


## Override in subclasses. Called ONCE by the game root after add_child(), before
## the screen is shown. Cache deps and subscribe signals here using _connect_owned().
## Do NOT connect signals in _ready() — use setup() so teardown is guaranteed.
func setup(ctx: ServiceContext) -> void:
	pass


## Append the shared bottom navigation to [param container] (the screen's root VBox),
## lit on [param active], and route its taps through [param on_nav] — a Callable the screen
## passes as `func(d): navigate.emit(d)`. The dock knows nothing about the screens; the
## screen forwards, the game root routes.
func _attach_bottom_dock(container: Node, active: StringName, on_nav: Callable) -> BottomDock:
	var dock := BottomDock.new()
	dock.navigate.connect(on_nav)
	container.add_child(dock)
	dock.set_active(active)
	return dock


## Shared chrome, built by [method build_chrome] — every meta screen wears the same one.
const CHROME_SCRAP_ICON := "res://assets/art/icons/scrap.svg"
var _chrome_scrap: Label
var _chrome_alloy: Label
var _chrome_dock: BottomDock
var _chrome_ctx: ServiceContext = null


## Build the shared screen frame and return the CONTENT box for the screen to fill.
##
## Every meta screen wears the same chrome: the screen's name at top left, Scrap over Alloy at
## top right, the phone's safe areas folded into the top padding and the dock's bottom, and
## one padding value down both sides. Screens used to each grow their own header, which is how
## they drifted apart; building it here makes them consistent by construction.
##
## [param title] is the screen's name, [param active] the dock tab to light.
func build_chrome(ctx: ServiceContext, title: String, active: StringName,
		on_nav: Callable) -> VBoxContainer:
	_chrome_ctx = ctx
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := _safe_insets()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_chrome_header(title, insets.x))

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", CONTENT_PAD)
	pad.add_theme_constant_override("margin_right", CONTENT_PAD)
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_bottom", 2)
	root.add_child(pad)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	pad.add_child(content)

	_chrome_dock = _attach_bottom_dock(root, active, on_nav)
	_chrome_dock.set_safe_bottom(insets.y)

	if ctx != null and ctx.wallet != null:
		_connect_owned(ctx.wallet.balance_changed, Callable(self, "_on_chrome_balance_changed"))
	refresh_chrome_wallet()
	return content


## Horizontal padding between the screen edge and its content.
const CONTENT_PAD := 12

## How tall a Symbot portrait is drawn at Mk I, and the multiplier per mark.
##
## Shared so every screen that shows a Symbot draws it at the same scale — Home and the
## Workshop each owning their own number is how the same creature ended up two sizes.
const HERO_BAND := 122.0
const MARK_ZOOM: Array[float] = [1.0, 1.32, 1.68]


## Bottom-pin a portrait TextureRect and size its band from [param mark], so a later mark
## looms larger (see MARK_ZOOM).
func fit_hero(hero: TextureRect, mark: int) -> void:
	hero.anchor_left = 0.0
	hero.anchor_right = 1.0
	hero.anchor_top = 1.0
	hero.anchor_bottom = 1.0
	hero.offset_bottom = 0
	hero.offset_top = -HERO_BAND * MARK_ZOOM[clampi(mark, 1, MARK_ZOOM.size()) - 1]


func _build_chrome_header(title: String, safe_top: float) -> Control:
	var bar := MarginContainer.new()
	bar.add_theme_constant_override("margin_top", int(safe_top + 6))
	bar.add_theme_constant_override("margin_bottom", 2)
	bar.add_theme_constant_override("margin_left", 14)
	bar.add_theme_constant_override("margin_right", 14)

	var row := HBoxContainer.new()
	bar.add_child(row)

	var name_label := Label.new()
	name_label.theme_type_variation = &"Heading"
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Top-aligned so the title sits on the first currency line, not centred against both.
	name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(name_label)

	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 1)
	money.alignment = BoxContainer.ALIGNMENT_END
	money.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(money)
	_chrome_scrap = _chrome_currency_row(
		money, _chrome_svg_icon(CHROME_SCRAP_ICON, UIPalette.SCRAP, 13.0), UIPalette.SCRAP)
	_chrome_alloy = _chrome_currency_row(
		money, IconGlyph.new(&"alloy", UIPalette.ALLOY, 13.0), UIPalette.ALLOY)
	return bar


func _chrome_currency_row(parent: VBoxContainer, icon: Control, colour: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(row)
	row.add_child(icon)
	var label := Label.new()
	label.theme_type_variation = &"Light"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", colour)
	row.add_child(label)
	return label


## An SVG icon as a colour-tinted TextureRect, sized square.
func _chrome_svg_icon(path: String, colour: Color, px: float) -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = load(path) if ResourceLoader.exists(path) else null
	tex.custom_minimum_size = Vector2(px, px)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.modulate = colour
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex


func _on_chrome_balance_changed(_currency: StringName, _amount: int) -> void:
	refresh_chrome_wallet()


## Redraw the header's currency readouts. Safe to call before the chrome exists.
func refresh_chrome_wallet() -> void:
	if _chrome_scrap == null or _chrome_ctx == null or _chrome_ctx.wallet == null:
		return
	_chrome_scrap.text = fmt_thousands(_chrome_ctx.wallet.scrap)
	_chrome_alloy.text = fmt_thousands(_chrome_ctx.wallet.alloy)


## Group thousands with a dot, matching the prototype's currency readout (8.085).
static func fmt_thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out


## Safe-area insets (top, bottom) in viewport units — the space a phone reserves for the
## notch/status bar and the home indicator. Zero on hardware without them (desktop), where a
## small floor keeps the layout from hugging the very edge. Screens pad their header top and
## their dock bottom by these so nothing lands under an OS gesture area.
func _safe_insets() -> Vector2:
	var win := Vector2(DisplayServer.window_get_size())
	var vp := get_viewport_rect().size
	if win.x <= 0.0 or vp.x <= 0.0:
		return Vector2(6, 6)
	var scale := vp.x / win.x  # physical px → viewport units
	var safe := DisplayServer.get_display_safe_area()
	var top := maxf(6.0, float(safe.position.y) * scale)
	var bottom := maxf(6.0, (win.y - float(safe.position.y + safe.size.y)) * scale)
	return Vector2(top, bottom)


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
