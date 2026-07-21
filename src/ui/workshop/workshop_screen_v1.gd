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
var _drawer_handle: Button
var _parts_scroll: Control
var _stats_scroll: Control
var _stats_view: VBoxContainer
var _stat_bars: Dictionary = {}
var _tab_parts: Button
var _tab_stats: Button
var _active_tab: StringName = &"parts"
var _drawer_open: bool = true
var _drawer_t: float = 1.0     ## 0 = closed (art only), 1 = open
var _drawer_tween: Tween

const DRAWER_W := 168.0
const HANDLE_W := 24.0

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


func _on_exit_tree() -> void:
	super._on_exit_tree()
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


## The hero fills the centre and stands low on the floor; a sliding right drawer holds the
## PARTS and STATS tabs and closes to a handle so only the art shows.
func _build_mid() -> Control:
	_mid = Control.new()
	_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mid.clip_contents = true  # clip the drawer as it slides off the right edge

	_hero = TextureRect.new()
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full width so it centres on screen; bottom-pinned so it stands low on the bench floor.
	# offset_right is animated by the drawer so the art re-centres in the free space.
	_hero.anchor_left = 0.0
	_hero.anchor_right = 1.0
	_hero.anchor_top = 1.0
	_hero.anchor_bottom = 1.0
	_hero.offset_top = -122
	_hero.offset_bottom = 0
	_mid.add_child(_hero)

	_mid.add_child(_build_drawer())
	_mid.resized.connect(_apply_drawer)
	call_deferred("_apply_drawer")
	return _mid


## The sliding drawer: a handle on the left edge, then a panel with the PARTS/STATS tabs.
func _build_drawer() -> Control:
	_drawer = Control.new()
	_drawer.anchor_top = 0.0
	_drawer.anchor_bottom = 1.0
	_drawer.anchor_left = 0.0
	_drawer.anchor_right = 0.0

	_drawer_handle = Button.new()
	_drawer_handle.text = "▶"
	_drawer_handle.anchor_top = 0.0
	_drawer_handle.anchor_bottom = 1.0
	_drawer_handle.offset_left = 0
	_drawer_handle.offset_right = HANDLE_W
	_drawer_handle.add_theme_font_size_override("font_size", 14)
	_style_handle(_drawer_handle)
	_drawer_handle.pressed.connect(_toggle_drawer)
	_drawer.add_child(_drawer_handle)

	var panel := PanelContainer.new()
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = HANDLE_W
	panel.offset_right = HANDLE_W + DRAWER_W
	var pbox := StyleBoxFlat.new()
	pbox.bg_color = Color(UIPalette.PANEL, 0.96)
	pbox.border_width_left = 2
	pbox.border_color = UIPalette.CYAN
	pbox.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", pbox)
	_drawer.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	_tab_parts = _make_tab("PARTS", &"parts")
	_tab_stats = _make_tab("STATS", &"stats")
	tabs.add_child(_tab_parts)
	tabs.add_child(_tab_stats)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(content)
	_parts_scroll = _build_parts_tab()
	_stats_scroll = _build_stats_tab()
	content.add_child(_parts_scroll)
	content.add_child(_stats_scroll)
	_set_active_tab(&"parts")
	return _drawer


func _build_parts_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_part_list = VBoxContainer.new()
	_part_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_part_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_part_list)
	return scroll


func _build_stats_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stats_view = VBoxContainer.new()
	_stats_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_view.add_theme_constant_override("separation", 5)
	scroll.add_child(_stats_view)
	return scroll


func _make_tab(label: String, id: StringName) -> Button:
	var b := Button.new()
	b.text = label
	b.toggle_mode = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(func(): _set_active_tab(id))
	return b


func _style_handle(button: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.CYAN_DARK
	box.set_corner_radius_all(3)
	box.border_color = UIPalette.CYAN
	box.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_theme_color_override("font_color", UIPalette.CYAN)


func _style_drawer_tab(button: Button, active: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.PANEL_2 if active else Color(0, 0, 0, 0)
	box.set_corner_radius_all(3)
	if active:
		box.border_width_bottom = 2
		box.border_color = UIPalette.CYAN
	box.set_content_margin_all(3)
	button.button_pressed = active
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_theme_color_override("font_color", UIPalette.CYAN if active else UIPalette.MUTED)


# --- drawer open/close + tab switching ---

func _set_active_tab(id: StringName) -> void:
	_active_tab = id
	_parts_scroll.visible = id == &"parts"
	_stats_scroll.visible = id == &"stats"
	_style_drawer_tab(_tab_parts, id == &"parts")
	_style_drawer_tab(_tab_stats, id == &"stats")


func _toggle_drawer() -> void:
	_drawer_open = not _drawer_open
	_drawer_handle.text = "▶" if _drawer_open else "◀"
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	var target := 1.0 if _drawer_open else 0.0
	if not is_inside_tree():
		_set_drawer_t(target)
		return
	_drawer_tween = create_tween()
	_drawer_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_method(_set_drawer_t, _drawer_t, target, 0.25)


func _set_drawer_t(v: float) -> void:
	_drawer_t = v
	_apply_drawer()


func _apply_drawer() -> void:
	if _mid == null or _drawer == null:
		return
	var mw := _mid.size.x
	var total := HANDLE_W + DRAWER_W
	var x := lerpf(mw - HANDLE_W, mw - total, _drawer_t)
	_drawer.offset_left = x
	_drawer.offset_right = x + total
	_hero.offset_right = -total * _drawer_t


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
	_tooltip_label.add_theme_font_size_override("font_size", 13)
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
	_nameplate.set_symbot(species, _selected)
	_hero.texture = _sprite_for(_selected)


func _rebuild_parts() -> void:
	_clear(_part_list)
	if _selected == null:
		return
	for slot in SymbotInstanceScript.PART_COUNT:
		_part_list.add_child(_build_part_row(slot))


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
			StatSummary.LABELS.get(stat, String(stat)))
		_stats_view.add_child(bar)
		_stat_bars[stat] = bar
	_refresh_stats_values(false)


## Push current/cap values into the existing bars. [param animate] plays the blue→amber grow
## on any stat that rose — used after an upgrade.
func _refresh_stats_values(animate: bool) -> void:
	if _selected == null:
		return
	var species := _species_of(_selected)
	var cur := StatSummary.current(_selected, species)
	var cap := StatSummary.at_cap(_selected, species)
	for stat in _stat_bars:
		_stat_bars[stat].set_value(int(cur.get(stat, 0)), int(cap.get(stat, 1)), animate)


const BADGE_SIZE := 36.0     ## 25% smaller than the first pass (48)
const UPGRADE_W := 50.0      ## the Lv label and the button share this width
const SCRAP_ICON := "res://assets/art/icons/scrap.svg"

## One part: a round-badged icon (tap = its name), its level, and a chamfered Upgrade button
## carrying the Scrap glyph and price. The badge glyph is the only thing that names the part,
## and only on tap. The Lv label and button share the button's width and sit so the button's
## bottom lines up with the bottom of the badge.
func _build_part_row(slot: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	row.add_theme_constant_override("separation", 6)

	row.add_child(_build_part_badge(slot))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	# Top line: level on the left, the Upgrade pill on the right.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	col.add_child(top)

	var level := Label.new()
	level.theme_type_variation = &"Light"
	level.add_theme_font_size_override("font_size", 10)
	level.add_theme_color_override("font_color", UIPalette.TEXT)
	level.text = "Lv. %d/%d" % [_selected.get_part_level(slot), _selected.part_level_cap()]
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(level)

	var refusal := UpgradeEconomyScript.can_upgrade(_selected, slot, _ctx.wallet, _ctx.balance)
	var button := Button.new()
	button.custom_minimum_size = Vector2(UPGRADE_W, 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_constant_override("icon_max_width", 12)
	button.add_theme_constant_override("h_separation", 2)
	button.disabled = refusal != UpgradeEconomyScript.Refusal.OK
	button.text = _upgrade_label(slot, refusal)
	_style_upgrade_button(button, refusal == UpgradeEconomyScript.Refusal.OK)
	if refusal == UpgradeEconomyScript.Refusal.OK:
		button.icon = load(SCRAP_ICON) if ResourceLoader.exists(SCRAP_ICON) else null
		button.add_theme_color_override("icon_normal_color", UIPalette.INK)
		button.pressed.connect(Callable(self, "_on_upgrade_pressed").bind(slot))
	top.add_child(button)

	# What the part boosts, per level — the stat values the drawer was missing.
	var stats_line := Label.new()
	stats_line.theme_type_variation = &"Light"
	stats_line.add_theme_font_size_override("font_size", 9)
	stats_line.add_theme_color_override("font_color", UIPalette.MUTED)
	stats_line.clip_text = true
	stats_line.text = _part_stats_text(slot)
	col.add_child(stats_line)
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


func _build_part_badge(slot: int) -> Control:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIPalette.INK, 0.65)
	sb.set_corner_radius_all(int(BADGE_SIZE * 0.5))
	sb.border_color = UIPalette.CYAN
	sb.set_border_width_all(2)
	badge.add_theme_stylebox_override("panel", sb)
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.gui_input.connect(func(e): _on_part_icon_input(e, slot, badge))

	var tex := TextureRect.new()
	tex.texture = load(PART_ICON_PATHS[slot]) if ResourceLoader.exists(PART_ICON_PATHS[slot]) else null
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.modulate = UIPalette.TEXT
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 6
	tex.offset_top = 6
	tex.offset_right = -6
	tex.offset_bottom = -6
	badge.add_child(tex)
	return badge


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

func _on_part_icon_input(event: InputEvent, slot: int, badge: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_tooltip(PART_NAMES[slot], badge.global_position + Vector2(badge.size.x + 6, 4))


## Kept for external/programmatic selection (tests). Sets focus without animating the
## carousel, to avoid a feedback loop.
func _on_symbot_selected(symbot: SymbotInstance) -> void:
	_selected = symbot
	refresh()


func _on_upgrade_pressed(slot: int) -> void:
	# The economy is the authority and re-checks. A price quoted a moment ago can be stale if
	# the wallet moved — better a no-op than a charge the player did not agree to.
	UpgradeEconomyScript.upgrade(_selected, slot, _ctx.wallet, _ctx.balance)
	# Targeted redraw rather than a full refresh(): rebuilding the stat bars would discard the
	# grow animation. The parts rebuild (levels/affordability changed), and the existing bars
	# animate the stats that rose.
	_rebuild_parts()
	_refresh_stats_values(true)
	_refresh_wallet()
	_refresh_gen()


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
