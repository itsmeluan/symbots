## WorkshopScreenV1 — level parts with Scrap, and advance a generation (Core Design §2.3,
## §2.4, §5).
##
## Portrait, from the v1 prototype. A full-width dark header (screen name left, Scrap over
## Alloy right) with a phone safe-area gap above it; below it the focused Symbot's chamfered
## nameplate and a GEN ▲ button; the five parts as round-badged icons down the left, each
## with its level and a small Upgrade button; the Symbot itself standing centred and low on
## the bench; and a draggable carousel of the roster hugging the dock. Spinning the carousel
## moves focus everywhere.
##
## The screen carries no written labels for what a glyph can say — part names live in a tap
## tooltip, roles pair an icon with a short word. It reserves the phone's safe areas top and
## bottom, and its width is fixed at the base 360 while height flexes (project stretch
## keep_width), so it fills a tall phone without letterboxing.
##
## Owns no rules. Prices come from [UpgradeEconomy], caps from [SymbotInstance]; the screen
## asks and draws. A view that re-derived a price could quote one number and charge another.
class_name WorkshopScreenV1
extends Screen

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const UpgradeEconomyScript := preload("res://src/core/economy/upgrade_economy.gd")

## Emitted when the player wants to leave. The root decides where to (ADR-0004/0008).
signal closed

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const MIN_ROW_HEIGHT := 48  ## past the 44pt touch minimum
const PART_ROW_HEIGHT := 56
const PART_NAMES: Array[String] = ["Core", "Chassis", "Head", "Arms", "Legs"]
const PART_ICON_PATHS: Array[String] = [
	"res://assets/art/icons/slot_core.svg",
	"res://assets/art/icons/slot_chassis.svg",
	"res://assets/art/icons/slot_head.svg",
	"res://assets/art/icons/slot_arms.svg",
	"res://assets/art/icons/slot_legs.svg",
]
const ART_DIR := "res://assets/art/symbots/"

var _ctx: ServiceContext = null
var _screen_root: VBoxContainer
var _selected: SymbotInstance = null

var _scrap_label: Label
var _alloy_label: Label
var _nameplate: SymbotNameplate
var _gen_button: Button
var _hero: TextureRect
var _part_list: VBoxContainer
var _carousel: SymbotCarousel
var _dock: BottomDock

# The right drawer: a sliding panel with PARTS and STATS tabs, and a handle that opens/closes
# it so the player can hide it and see just the art.
var _mid: Control
var _drawer: Control
var _catcher: Control
var _parts_scroll: Control
var _stats_scroll: Control
var _stats_view: VBoxContainer

## What each stat influences — shown in the discreet tooltip behind each stat's "i" button.
const STAT_INFO := {
	&"structure": "Health — the damage it can take before it falls.",
	&"armor": "Reduces incoming physical damage.",
	&"resistance": "Reduces incoming energy damage.",
	&"physical_power": "Raises the damage of physical attacks.",
	&"energy_power": "Raises the damage of energy attacks.",
	&"mobility": "Turn order — who acts first.",
	&"targeting": "Critical hit chance.",
	&"processing": "Strength of effects and abilities.",
	&"cooling": "Heat control — keeps it from overheating.",
	&"energy_capacity": "Maximum charge for the ultimate.",
	&"recharge": "How fast energy recharges.",
}
var _stat_bars: Dictionary = {}
var _tab_parts: Button
var _tab_stats: Button
var _active_tab: StringName = &"parts"
var _drawer_open: bool = false
var _drawer_t: float = 0.0     ## 0 = closed (art only), 1 = open
var _drawer_tween: Tween
var _dragging: bool = false
var _drag_moved: float = 0.0
var _hint: SwipeHint

# Per-slot widgets, so an upgrade can refresh a row IN PLACE. Rebuilding the rows would free
# the very button the player is holding down, killing the auto-repeat mid-press.
var _part_level_labels: Array = []
var _part_buttons: Array = []

# Hold-to-repeat on the Upgrade pill: one level lands on press, then it keeps levelling while
# held — pausing first so a single tap is still a single level, and accelerating so a long
# hold gets somewhere.
const HOLD_DELAY := 0.35
const HOLD_INTERVAL := 0.09
const HOLD_FAST_AFTER := 8
const HOLD_FAST_INTERVAL := 0.045
var _repeat_timer: Timer
var _repeat_slot: int = -1
var _repeat_ticks: int = 0

const DRAWER_W := 186.0
## Padding inside the drawer panel, used on both sides so content reads centred.
const PANEL_PAD := 8.0
## Clearance between the nameplate/GEN row and the top of the drawer.
const DRAWER_TOP_GAP := 14.0
## How far past the area's bottom the drawer reaches, sitting it nearer the carousel.
const DRAWER_BOTTOM_DROP := 8.0

# Overlay: a tap tooltip (part names) and a modal card (the gen-up requirement).
var _overlay_layer: Control
var _scrim: ColorRect
var _tooltip: PanelContainer
var _tooltip_label: Label
var _tooltip_timer: Timer
var _modal_center: CenterContainer
var _modal_crest: Label
var _modal_title: Label
var _modal_body: Label
var _modal_progress: Label


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.5)
	_build_layout()
	if _ctx.wallet != null:
		_connect_owned(_ctx.wallet.balance_changed, Callable(self, "_on_balance_changed"))
	_populate_carousel()
	var squad := _ctx.roster.squad_symbots()
	_selected = squad[0] if not squad.is_empty() else (
		_ctx.roster.symbots[0] if not _ctx.roster.symbots.is_empty() else null)
	if _selected != null:
		_carousel.focus(_index_of(_selected))
	refresh()
	# The drawer has no button — teach the gesture once, faintly, on every entry.
	_hint.play("Drag left for more info")


## Any touch retires the nudge — it has done its job the moment the player engages.
func _input(event: InputEvent) -> void:
	if _hint == null:
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		_dismiss_hint()


func _dismiss_hint() -> void:
	if _hint != null:
		_hint.dismiss()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_stop_repeat()
	_ctx = null
	_selected = null


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := _safe_insets()

	_screen_root = VBoxContainer.new()
	_screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.add_theme_constant_override("separation", 0)
	add_child(_screen_root)

	_screen_root.add_child(_build_header(insets.x))
	_screen_root.add_child(_build_content())
	_dock = _attach_bottom_dock(_screen_root, &"workshop", func(d): navigate.emit(d))
	_dock.set_safe_bottom(insets.y)

	_hint = SwipeHint.new()
	add_child(_hint)

	_repeat_timer = Timer.new()
	_repeat_timer.one_shot = true
	_repeat_timer.timeout.connect(_on_repeat_tick)
	add_child(_repeat_timer)

	_build_overlay_layer()


## No background bar — the header sits straight on the backdrop. Only the phone's top safe
## area is folded into the top padding. Screen name left; Scrap over Alloy right.
func _build_header(safe_top: float) -> Control:
	var bar := MarginContainer.new()
	bar.add_theme_constant_override("margin_top", int(safe_top + 6))
	bar.add_theme_constant_override("margin_bottom", 2)
	bar.add_theme_constant_override("margin_left", 14)
	bar.add_theme_constant_override("margin_right", 14)

	var hb := HBoxContainer.new()
	bar.add_child(hb)
	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = "WORKSHOP"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Top-aligned so the title sits on the first currency line (Scrap), not centred against
	# the two-row block.
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(title)

	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 1)
	money.alignment = BoxContainer.ALIGNMENT_END
	money.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(money)
	# Scrap uses the same scrap.svg the Upgrade button carries, so the two read as one icon.
	# Alloy keeps its drawn hexagon glyph.
	_scrap_label = _make_currency_row(money, _svg_icon(SCRAP_ICON, UIPalette.SCRAP, 13.0), UIPalette.SCRAP)
	_alloy_label = _make_currency_row(money, IconGlyph.new(&"alloy", UIPalette.ALLOY, 13.0), UIPalette.ALLOY)
	return bar


func _make_currency_row(parent: VBoxContainer, icon: Control, colour: Color) -> Label:
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
func _svg_icon(path: String, colour: Color, px: float) -> TextureRect:
	var tex := TextureRect.new()
	tex.texture = load(path) if ResourceLoader.exists(path) else null
	tex.custom_minimum_size = Vector2(px, px)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.modulate = colour
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex


## The padded content between header and dock: a gap, the nameplate + GEN ▲ line, the
## parts/hero area, and the carousel.
func _build_content() -> Control:
	var mc := MarginContainer.new()
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 4)
	mc.add_theme_constant_override("margin_bottom", 2)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	mc.add_child(col)

	col.add_child(_build_subheader())
	col.add_child(_build_mid())

	_carousel = SymbotCarousel.new()
	_carousel.custom_minimum_size = Vector2(0, 102)
	_carousel.focused_changed.connect(_on_focus_changed)
	col.add_child(_carousel)
	return mc


func _build_subheader() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	_nameplate = SymbotNameplate.new()
	_nameplate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_nameplate)

	_gen_button = Button.new()
	_gen_button.text = "GEN ▲"
	_gen_button.custom_minimum_size = Vector2(76, 52)
	_gen_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gen_button.clip_text = true
	_gen_button.pressed.connect(Callable(self, "_on_gen_up_pressed"))
	row.add_child(_gen_button)
	return row


## The hero fills the centre at full size; the drawer overlays it from the right (bleeding to
## the screen edge). A small amber handle at the bottom-right toggles it; a tap on the art
## closes it.
func _build_mid() -> Control:
	_mid = Control.new()
	_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_hero = TextureRect.new()
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.anchor_left = 0.0
	_hero.anchor_right = 1.0
	_hero.anchor_top = 1.0
	_hero.anchor_bottom = 1.0
	_hero.offset_top = -122
	_hero.offset_bottom = 0
	_mid.add_child(_hero)

	# Dragging the art left pulls the drawer out, 1:1 with the finger; a tap closes it.
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_art_input)
	_mid.add_child(_catcher)

	_mid.add_child(_build_drawer())
	_mid.resized.connect(_apply_drawer)
	call_deferred("_apply_drawer")
	return _mid


## The drawer is opened by dragging the Symbot left — no button. The drawer and the sprite
## both follow the finger, so the gesture feels like pulling the panel out rather than
## triggering an animation.
func _on_art_input(event: InputEvent) -> void:
	_dismiss_hint()
	if event is InputEventScreenTouch or (event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_dragging = true
			_drag_moved = 0.0
			_kill_drawer_tween()
		elif _dragging:
			_dragging = false
			_release_drag()
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		# Dragging left (negative x) opens.
		_drawer_t = clampf(_drawer_t - event.relative.x / DRAWER_W, 0.0, 1.0)
		_drag_moved += absf(event.relative.x)
		_apply_drawer()


## A flick settles to whichever side it is closer to; a tap (no travel) just closes an open
## drawer.
func _release_drag() -> void:
	if _drag_moved < 8.0:
		if _drawer_open:
			_animate_drawer(false)
		return
	_animate_drawer(_drawer_t > 0.5)


## A 3D-look tab strip on top (the inactive tab darker and recessed), then a translucent panel
## with the PARTS/STATS content. The whole thing slides and bleeds to the screen edge.
func _build_drawer() -> Control:
	_drawer = Control.new()
	_drawer.anchor_left = 0.0
	_drawer.anchor_right = 0.0
	_drawer.anchor_top = 0.0
	_drawer.anchor_bottom = 1.0

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	_drawer.add_child(v)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	v.add_child(tabs)
	_tab_parts = _make_tab("PARTS", &"parts")
	_tab_stats = _make_tab("STATS", &"stats")
	tabs.add_child(_tab_parts)
	tabs.add_child(_tab_stats)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pbox := StyleBoxFlat.new()
	pbox.bg_color = Color(UIPalette.PANEL, 0.8)  # translucent, no cyan left margin
	pbox.set_content_margin(SIDE_LEFT, PANEL_PAD)
	pbox.set_content_margin(SIDE_TOP, 8)
	pbox.set_content_margin(SIDE_RIGHT, PANEL_PAD)
	pbox.set_content_margin(SIDE_BOTTOM, 6)
	panel.add_theme_stylebox_override("panel", pbox)
	v.add_child(panel)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)
	_parts_scroll = _build_parts_tab()
	_stats_scroll = _build_stats_tab()
	content.add_child(_parts_scroll)
	content.add_child(_stats_scroll)
	_set_active_tab(&"parts")
	return _drawer


## The parts fill the panel and spread — no scroll (§5.2 decision stays on one screen).
func _build_parts_tab() -> Control:
	_part_list = VBoxContainer.new()
	_part_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_part_list.add_theme_constant_override("separation", 2)
	return _part_list


func _build_stats_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A ScrollContainer RESERVES its scroll bar out of the content width, so a bar left inside
	# the panel padding would eat into the stat bars and sit against them. Stretching the
	# scroll into the right padding puts the bar out in the margin instead: it hugs the screen
	# edge, and the stat bars end the same distance from the right as they start from the left.
	scroll.offset_right = PANEL_PAD
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_thin_scrollbar(scroll)
	_stats_view = VBoxContainer.new()
	_stats_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_view.add_theme_constant_override("separation", 7)
	scroll.add_child(_stats_view)
	return scroll


## Halve the scroll bar and let it hug the (screen) edge, so it no longer covers the values.
func _thin_scrollbar(scroll: ScrollContainer) -> void:
	var vsb := scroll.get_v_scroll_bar()
	vsb.custom_minimum_size = Vector2(4, 0)
	var grab := StyleBoxFlat.new()
	grab.bg_color = UIPalette.LINE
	grab.set_corner_radius_all(2)
	vsb.add_theme_stylebox_override("grabber", grab)
	vsb.add_theme_stylebox_override("grabber_highlight", grab)
	vsb.add_theme_stylebox_override("grabber_pressed", grab)
	vsb.add_theme_stylebox_override("scroll", UIPalette.empty())


func _make_tab(label: String, id: StringName) -> Button:
	var b := Button.new()
	b.text = label
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func(): _set_active_tab(id))
	return b


## 3D tabs: the active tab takes the panel's colour and stands proud; the hidden one is darker
## and recessed. Sits above the panel, not inside it.
func _style_drawer_tab(button: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.set_content_margin(SIDE_LEFT, 6)
	box.set_content_margin(SIDE_RIGHT, 6)
	if active:
		box.bg_color = Color(UIPalette.PANEL, 0.8)     # matches the panel — reads as one surface
		box.set_content_margin(SIDE_TOP, 9)
		box.set_content_margin(SIDE_BOTTOM, 8)
	else:
		box.bg_color = Color(UIPalette.INK, 0.72)       # darker, sunk
		box.set_content_margin(SIDE_TOP, 6)
		box.set_content_margin(SIDE_BOTTOM, 5)
	button.button_pressed = active
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_theme_color_override("font_color", UIPalette.CYAN if active else UIPalette.DISABLED)


# --- drawer open/close + tab switching ---

func _set_active_tab(id: StringName) -> void:
	_active_tab = id
	_parts_scroll.visible = id == &"parts"
	_stats_scroll.visible = id == &"stats"
	_style_drawer_tab(_tab_parts, id == &"parts")
	_style_drawer_tab(_tab_stats, id == &"stats")


func _toggle_drawer() -> void:
	_animate_drawer(not _drawer_open)


## Settle the drawer to fully open or fully closed.
func _animate_drawer(open: bool) -> void:
	_drawer_open = open
	_kill_drawer_tween()
	var target := 1.0 if open else 0.0
	if not is_inside_tree():
		_set_drawer_t(target)
		return
	_drawer_tween = create_tween()
	_drawer_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_method(_set_drawer_t, _drawer_t, target, 0.20)


func _kill_drawer_tween() -> void:
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = null


func _set_drawer_t(v: float) -> void:
	_drawer_t = v
	_apply_drawer()


func _apply_drawer() -> void:
	if _mid == null or _drawer == null:
		return
	var mw := _mid.size.x
	var edge := mw + 12.0  # the screen's right edge in mid coordinates (content margin is 12)
	# Open: the drawer's right sits on the screen edge. Closed: it slides fully off past it.
	var right := lerpf(edge + DRAWER_W, edge, _drawer_t)
	_drawer.offset_left = right - DRAWER_W
	_drawer.offset_right = right
	_drawer.offset_top = DRAWER_TOP_GAP
	_drawer.offset_bottom = DRAWER_BOTTOM_DROP
	# The sprite slides left with the drawer, so it stays fully visible beside it.
	_hero.offset_right = -DRAWER_W * _drawer_t


func _build_overlay_layer() -> void:
	_overlay_layer = Control.new()
	_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.visible = false
	_overlay_layer.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_hide_overlay())
	add_child(_overlay_layer)

	_scrim = ColorRect.new()
	_scrim.color = Color(UIPalette.INK, 0.7)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_scrim)

	# Small tooltip for part names — no scrim, positioned by the tap.
	_tooltip = PanelContainer.new()
	_tooltip.add_theme_stylebox_override("panel", UIPalette.panel(UIPalette.CYAN, UIPalette.PANEL_2))
	_tooltip.visible = false
	_overlay_layer.add_child(_tooltip)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(168, 0)
	_tooltip.add_child(_tooltip_label)

	_overlay_layer.add_child(_build_modal_card())

	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.timeout.connect(_hide_overlay)
	add_child(_tooltip_timer)


## The gen-up modal: a centred tech card with an amber crest, a title, the requirement, a
## parts-maxed readout, and a dismiss button. Replaces the bare tooltip that read as a broken
## prototype.
func _build_modal_card() -> CenterContainer:
	_modal_center = CenterContainer.new()
	_modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_center.visible = false

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(288, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.PANEL
	box.border_color = UIPalette.AMBER
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(20)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	card.add_theme_stylebox_override("panel", box)
	_modal_center.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)

	_modal_crest = Label.new()
	_modal_crest.theme_type_variation = &"Heading"
	_modal_crest.text = "GEN ▲"
	_modal_crest.add_theme_font_size_override("font_size", 34)
	_modal_crest.add_theme_color_override("font_color", UIPalette.AMBER)
	_modal_crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_modal_crest)

	_modal_title = Label.new()
	_modal_title.theme_type_variation = &"Heading"
	_modal_title.add_theme_font_size_override("font_size", 15)
	_modal_title.add_theme_color_override("font_color", UIPalette.AMBER)
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_modal_title)

	var rule := ColorRect.new()
	rule.color = UIPalette.LINE_SOFT
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)

	_modal_body = Label.new()
	_modal_body.add_theme_font_size_override("font_size", 13)
	_modal_body.add_theme_color_override("font_color", UIPalette.TEXT)
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_modal_body)

	_modal_progress = Label.new()
	_modal_progress.add_theme_font_size_override("font_size", 13)
	_modal_progress.add_theme_color_override("font_color", UIPalette.CYAN)
	_modal_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_modal_progress)

	var got := Button.new()
	got.text = "GOT IT"
	got.custom_minimum_size = Vector2(0, 46)
	var got_box := UIPalette.button()
	got_box.border_color = UIPalette.CYAN
	got.add_theme_stylebox_override("normal", got_box)
	got.add_theme_color_override("font_color", UIPalette.CYAN)
	got.pressed.connect(_hide_overlay)
	v.add_child(got)
	return _modal_center


# ---------------------------------------------------------------------------
# Data → view
# ---------------------------------------------------------------------------

func refresh() -> void:
	if _ctx == null:
		return
	_refresh_wallet()
	_refresh_hero_and_name()
	_rebuild_parts()
	_rebuild_stats()
	_refresh_gen()


func _refresh_wallet() -> void:
	if _ctx.wallet == null:
		return
	_scrap_label.text = _fmt(_ctx.wallet.scrap)
	_alloy_label.text = _fmt(_ctx.wallet.alloy)


func _on_balance_changed(_currency: StringName, _amount: int) -> void:
	_refresh_wallet()
	_refresh_gen()


func _refresh_hero_and_name() -> void:
	var species: SpeciesDef = _species_of(_selected)
	var xp := 0
	if _selected != null and _ctx.balance != null:
		xp = XpProgression.percent_to_next(_selected, _ctx.balance)
	_nameplate.set_symbot(species, _selected, xp)
	_hero.texture = _sprite_for(_selected)


func _rebuild_parts() -> void:
	_stop_repeat()
	_clear(_part_list)
	_part_level_labels.clear()
	_part_buttons.clear()
	_part_level_labels.resize(SymbotInstanceScript.PART_COUNT)
	_part_buttons.resize(SymbotInstanceScript.PART_COUNT)
	if _selected == null:
		return
	for slot in SymbotInstanceScript.PART_COUNT:
		_part_list.add_child(_build_part_row(slot))
	_refresh_part_rows()


## Update every row's level and Upgrade pill WITHOUT rebuilding them. Spending Scrap changes
## what the other parts can afford, so all five refresh together.
func _refresh_part_rows() -> void:
	if _selected == null:
		return
	for slot in SymbotInstanceScript.PART_COUNT:
		var label: Label = _part_level_labels[slot]
		if label != null:
			label.text = "Lv. %d/%d" % [_selected.get_part_level(slot), _selected.part_level_cap()]
		var button: Button = _part_buttons[slot]
		if button == null:
			continue
		var refusal := UpgradeEconomyScript.can_upgrade(
			_selected, slot, _ctx.wallet, _ctx.balance)
		var actionable := refusal == UpgradeEconomyScript.Refusal.OK
		button.disabled = not actionable
		button.text = _upgrade_label(slot, refusal)
		button.icon = load(SCRAP_ICON) if actionable and ResourceLoader.exists(SCRAP_ICON) else null
		_style_upgrade_button(button, actionable)


## Rebuild the STATS tab's bars for the selected Symbot. Only stats the species actually uses
## (non-zero at cap) get a bar. Called on a Symbot change; upgrades reuse the bars so the
## grow animation can play.
func _rebuild_stats() -> void:
	_clear(_stats_view)
	_stat_bars.clear()
	if _selected == null:
		return
	var species := _species_of(_selected)
	var cap_stats := StatSummary.at_cap(_selected, species)
	for stat in StatSummary.ORDER:
		if int(cap_stats.get(stat, 0)) <= 0:
			continue
		var bar := StatBar.new()
		var icon_path := StatSummary.icon_path(stat)
		bar.bind(load(icon_path) if ResourceLoader.exists(icon_path) else null,
			StatSummary.LABELS.get(stat, String(stat)), stat)
		bar.info_pressed.connect(_on_stat_info)
		_stats_view.add_child(bar)
		_stat_bars[stat] = bar
	_refresh_stats_values(false)


## Push values into the existing bars. Every bar is scaled against the LARGEST stat on this
## Symbot, so the biggest number always has the longest bar and the rest read in proportion —
## scaling each stat against its own ceiling made a 5 look fuller than an 80.
## [param animate] plays the blue→amber grow on any stat that rose, used after an upgrade.
func _refresh_stats_values(animate: bool) -> void:
	if _selected == null:
		return
	var species := _species_of(_selected)
	var cur := StatSummary.current(_selected, species)
	var top := 1
	for stat in _stat_bars:
		top = maxi(top, int(cur.get(stat, 0)))
	for stat in _stat_bars:
		_stat_bars[stat].set_value(int(cur.get(stat, 0)), top, animate)


const PART_ICON_SIZE := 20.0
const UPGRADE_W := 50.0
const SCRAP_ICON := "res://assets/art/icons/scrap.svg"

## One part: a thin blue icon (no badge), the part NAME in blue over its level, the stats it
## grows, and the chamfered Upgrade pill. The five rows spread to fill the panel — no scroll.
func _build_part_row(slot: int) -> Control:
	var row := VBoxContainer.new()
	row.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 1)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(top)

	var icon := TextureRect.new()
	icon.texture = load(PART_ICON_PATHS[slot]) if ResourceLoader.exists(PART_ICON_PATHS[slot]) else null
	icon.custom_minimum_size = Vector2(PART_ICON_SIZE, PART_ICON_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.modulate = UIPalette.CYAN
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(icon)

	var namecol := VBoxContainer.new()
	namecol.add_theme_constant_override("separation", 1)
	namecol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	namecol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(namecol)

	# Line one: the part name with its level beside it.
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	namecol.add_child(title)

	# Same size and weight as the stat names in the STATS tab, so the two tabs read alike.
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", UIPalette.TEXT)
	name_label.text = PART_NAMES[slot].to_upper()
	# Clipping lets the name give way as the level number grows, instead of the row overflowing
	# and shoving the Upgrade pill past the panel's right margin.
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)

	var level := Label.new()
	level.theme_type_variation = &"Light"
	level.add_theme_font_size_override("font_size", 10)
	level.add_theme_color_override("font_color", UIPalette.MUTED)
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level.size_flags_horizontal = Control.SIZE_SHRINK_END
	title.add_child(level)
	_part_level_labels[slot] = level

	# Line two: what the part grows. Scrolls itself when the Upgrade button squeezes it.
	var stats := MarqueeLabel.new()
	stats.style(9, UIPalette.MUTED, &"Light")
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.set_text(_part_stats_text(slot))
	namecol.add_child(stats)

	var button := Button.new()
	button.custom_minimum_size = Vector2(UPGRADE_W, 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_constant_override("icon_max_width", 12)
	button.add_theme_constant_override("h_separation", 2)
	button.add_theme_color_override("icon_normal_color", UIPalette.INK)
	# Press/release rather than `pressed`, so holding can keep levelling. Wired unconditionally
	# — `disabled` is what gates it, and that flips as Scrap comes and goes.
	button.button_down.connect(_on_upgrade_hold_start.bind(slot))
	button.button_up.connect(_on_upgrade_hold_end)
	top.add_child(button)
	_part_buttons[slot] = button

	# A hairline between blocks — just enough to group each part, not enough to notice.
	if slot < SymbotInstanceScript.PART_COUNT - 1:
		var rule := ColorRect.new()
		rule.color = Color(UIPalette.LINE, 0.22)
		rule.custom_minimum_size = Vector2(0, 1)
		row.add_child(rule)
	return row


## The stats a part grows, per level: "+3 STRUCTURE  +1 ARMOR". Shown small under the level.
func _part_stats_text(slot: int) -> String:
	var species := _species_of(_selected)
	if species == null or not species.part_growth.has(slot):
		return ""
	var growth: Dictionary = species.part_growth[slot]
	var parts: Array = []
	for stat in StatSummary.ORDER:
		if growth.has(stat):
			parts.append("+%d %s" % [int(growth[stat]), StatSummary.LABELS.get(stat, String(stat))])
	return "  ".join(parts)


## The chamfered "tech tag" shape of the nameplate, at button scale: amber when actionable,
## grey when capped/unaffordable.
func _style_upgrade_button(button: Button, actionable: bool) -> void:
	var box := ChamferStyleBox.new()
	box.chamfer = 5.0
	box.set_content_margin(SIDE_LEFT, 5)
	box.set_content_margin(SIDE_RIGHT, 5)
	box.set_content_margin(SIDE_TOP, 3)
	box.set_content_margin(SIDE_BOTTOM, 3)
	if actionable:
		box.bg_color = UIPalette.AMBER
		button.add_theme_color_override("font_color", UIPalette.INK)
	else:
		box.bg_color = UIPalette.PANEL_2
		box.border_color = UIPalette.LINE_SOFT
		box.border_width = 1.0
		button.add_theme_color_override("font_color", UIPalette.DISABLED)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("disabled", box)
	button.add_theme_stylebox_override("focus", UIPalette.empty())


## The button carries the Scrap glyph as its icon; its text is just the price (or the state).
## "Capped" and "cannot afford" send the player to different places — one means go gen-up, the
## other means go fight.
func _upgrade_label(slot: int, refusal: int) -> String:
	match refusal:
		UpgradeEconomyScript.Refusal.AT_MARK_CAP:
			return "Capped"
		UpgradeEconomyScript.Refusal.NO_SUCH_PART:
			return "—"
	return "%d" % UpgradeEconomyScript.level_cost(_selected.get_part_level(slot), _ctx.balance)


## GEN ▲ stays present but greyed until every part is capped; tapping it early opens the modal
## explaining the requirement rather than doing nothing.
func _refresh_gen() -> void:
	if _can_gen_up():
		_gen_button.theme_type_variation = &"Primary"
		_gen_button.remove_theme_color_override("font_color")
		_gen_button.modulate = Color.WHITE
	else:
		_gen_button.theme_type_variation = &""
		_gen_button.add_theme_color_override("font_color", UIPalette.DISABLED)
		_gen_button.modulate = Color(1, 1, 1, 0.8)


func _can_gen_up() -> bool:
	return _selected != null and _selected.mark < SymbotInstanceScript.MAX_MARK \
		and _selected.can_retrofit()


func _gen_requirement_text() -> String:
	if _selected == null:
		return ""
	if _selected.mark >= SymbotInstanceScript.MAX_MARK:
		return "This Symbot has reached Mk III — its final generation. There is no further to go."
	return "Take all five parts to level %d, then this Symbot advances to Mk %s." % [
		_selected.part_level_cap(), _roman(_selected.mark + 1)]


func _parts_maxed() -> int:
	if _selected == null:
		return 0
	var cap := _selected.part_level_cap()
	var n := 0
	for i in SymbotInstanceScript.PART_COUNT:
		if _selected.get_part_level(i) >= cap:
			n += 1
	return n


# ---------------------------------------------------------------------------
# Carousel
# ---------------------------------------------------------------------------

func _populate_carousel() -> void:
	var textures: Array = []
	for symbot in _ctx.roster.symbots:
		textures.append(_sprite_for(symbot))
	_carousel.set_items(textures)


func _on_focus_changed(index: int) -> void:
	if index < 0 or index >= _ctx.roster.symbots.size():
		return
	_selected = _ctx.roster.symbots[index]
	refresh()


func _index_of(symbot: SymbotInstance) -> int:
	return _ctx.roster.symbots.find(symbot)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## The player tapped a stat's "i" — show a discreet tooltip explaining what it influences.
func _on_stat_info(stat_id: StringName, at_global: Vector2) -> void:
	_show_tooltip(String(STAT_INFO.get(stat_id, "")), at_global + Vector2(10, -8))


## Kept for external/programmatic selection (tests). Sets focus without animating the
## carousel, to avoid a feedback loop.
func _on_symbot_selected(symbot: SymbotInstance) -> void:
	_selected = symbot
	refresh()


## One level. The economy is the authority and re-checks: a price quoted a moment ago can be
## stale if the wallet moved, and a no-op beats a charge the player did not agree to.
func _on_upgrade_pressed(slot: int) -> void:
	if UpgradeEconomyScript.upgrade(_selected, slot, _ctx.wallet, _ctx.balance) > 0:
		_after_upgrade()


## Everything an upgrade touches, refreshed in place — rebuilding would free the held button
## and discard the stat bars' grow animation.
func _after_upgrade() -> void:
	_refresh_part_rows()
	_refresh_stats_values(true)
	_refresh_wallet()
	_refresh_gen()


## Press: level once immediately, then arm the repeat so a held finger keeps going.
func _on_upgrade_hold_start(slot: int) -> void:
	_dismiss_hint()
	_on_upgrade_pressed(slot)
	if _selected == null:
		return
	if UpgradeEconomyScript.can_upgrade(_selected, slot, _ctx.wallet, _ctx.balance) \
			!= UpgradeEconomyScript.Refusal.OK:
		return  # capped or out of Scrap — nothing to repeat
	_repeat_slot = slot
	_repeat_ticks = 0
	_repeat_timer.start(HOLD_DELAY)


func _on_upgrade_hold_end() -> void:
	_stop_repeat()


func _stop_repeat() -> void:
	_repeat_slot = -1
	if _repeat_timer != null:
		_repeat_timer.stop()


## Each repeat tick levels once more and stops the moment the economy refuses, so a held
## finger can never overspend or push a part past its cap.
func _on_repeat_tick() -> void:
	if _repeat_slot < 0 or _selected == null or _ctx == null:
		return
	if UpgradeEconomyScript.upgrade(_selected, _repeat_slot, _ctx.wallet, _ctx.balance) <= 0:
		_stop_repeat()
		return
	_after_upgrade()
	_repeat_ticks += 1
	_repeat_timer.start(
		HOLD_FAST_INTERVAL if _repeat_ticks >= HOLD_FAST_AFTER else HOLD_INTERVAL)


func _on_gen_up_pressed() -> void:
	if _can_gen_up():
		if _selected.retrofit():
			refresh()
	else:
		_show_gen_modal()


func _on_close_pressed() -> void:
	closed.emit()


# ---------------------------------------------------------------------------
# Overlay
# ---------------------------------------------------------------------------

func _show_tooltip(text: String, near: Vector2) -> void:
	_scrim.visible = false
	_modal_center.visible = false
	_tooltip.visible = true
	_tooltip_label.text = text
	_tooltip.reset_size()
	_overlay_layer.visible = true
	await get_tree().process_frame
	var pos := near
	pos.x = clampf(pos.x, 8, size.x - _tooltip.size.x - 8)
	pos.y = clampf(pos.y, 8, size.y - _tooltip.size.y - 8)
	_tooltip.position = pos
	_tooltip_timer.start(1.6)


func _show_gen_modal() -> void:
	_tooltip_timer.stop()
	_tooltip.visible = false
	_scrim.visible = true
	var final_gen := _selected != null and _selected.mark >= SymbotInstanceScript.MAX_MARK
	_modal_title.text = "FINAL GENERATION" if final_gen else "GENERATION LOCKED"
	_modal_body.text = _gen_requirement_text()
	_modal_progress.visible = not final_gen
	_modal_progress.text = "PARTS MAXED   %d / %d" % [_parts_maxed(), SymbotInstanceScript.PART_COUNT]
	_modal_center.visible = true
	_overlay_layer.visible = true


func _hide_overlay() -> void:
	_tooltip_timer.stop()
	_overlay_layer.visible = false


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _species_of(symbot: SymbotInstance) -> SpeciesDef:
	if symbot == null or _ctx == null:
		return null
	return _ctx.species.get_species(symbot.species_id)


func _sprite_for(symbot: SymbotInstance) -> Texture2D:
	if symbot == null:
		return null
	var path := "%s%s_mk%d.png" % [ART_DIR, symbot.species_id, clampi(symbot.mark, 1, 3)]
	return load(path) if ResourceLoader.exists(path) else null


func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(n)


## Group thousands with a dot, matching the prototype's currency readout (8.085).
func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
