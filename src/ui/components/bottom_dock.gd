## BottomDock — persistent bottom navigation across the meta screens (v1 UI prototype).
##
## Replaces the crowded five-button top row with the prototype's dock: one tab per
## destination, the current one lit cyan. The prototype ships four tabs; this game has seven
## meta destinations, so the dock holds eight (about 45px each at the 360 base width).
##
## Emits [signal navigate] with a destination id; the screen forwards it and the game root
## routes it. The dock knows nothing about the screens, only their names.
class_name BottomDock
extends PanelContainer

signal navigate(dest: StringName)

const HEIGHT := 62

## dest id -> [label, glyph]. Order is left-to-right. Four PRIMARY destinations only —
## the secondary ones (Forge, Tree, Send, Bag) live on the Home hub now (research: a
## mobile bottom bar tops out at ~5). MAP is the emphasised "play" tab. Every tab is
## icon AND label — the pattern every finished mobile nav shares.
const TABS: Array = [
	[&"home", "HOME", &"house"],
	[&"squad", "SYMBOTS", &"bot"],
	[&"workshop", "WORKSHOP", &"wrench"],
	[&"map", "MAP", &"flag"],
]

## The tab drawn as the primary call to action — the way into the core loop.
const PRIMARY_TAB := &"map"

var _active: StringName = &"home"
var _row: HBoxContainer
var _box: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	# The bar sits one surface-ladder step above the screen, separated by the 1px
	# top-light edge — never a plain grey hairline.
	_box = StyleBoxFlat.new()
	_box.bg_color = UIPalette.SURFACE
	_box.border_color = Color(1, 1, 1, 0.08)
	_box.border_width_top = 1
	_box.set_content_margin(SIDE_TOP, 5)
	_box.set_content_margin(SIDE_BOTTOM, 5)
	_box.set_content_margin(SIDE_LEFT, 6)
	_box.set_content_margin(SIDE_RIGHT, 6)
	add_theme_stylebox_override("panel", _box)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 4)
	add_child(_row)
	_rebuild_tabs()


func _rebuild_tabs() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for tab in TABS:
		_row.add_child(_build_tab(tab[0], tab[1], tab[2]))


## Reserve room below the tabs for the phone's home indicator, so a tap on a tab never lands
## on the OS gesture area. The bar's fill still bleeds to the screen edge; only the tabs move
## up. [param px] is in viewport units (0 on a device with no home indicator, e.g. desktop).
func set_safe_bottom(px: float) -> void:
	_box.set_content_margin(SIDE_BOTTOM, 4.0 + px)
	custom_minimum_size = Vector2(0, HEIGHT + px)


## Light the tab for [param dest] and dim the rest. Call from a screen's setup so the dock
## shows where the player is. Tabs are rebuilt whole — four of them, and the icon tint,
## pill and label weight all change together.
func set_active(dest: StringName) -> void:
	_active = dest
	_rebuild_tabs()


## One tab: glyph over caption. The ACTIVE tab earns the accent pill (soft accent fill,
## accent top rule) with its icon lit in the accent; inactive tabs are quiet grey pairs.
## The PRIMARY tab (MAP) speaks amber even at rest — the standing call to action.
func _build_tab(dest: StringName, label: String, glyph_kind: StringName) -> Button:
	var active := dest == _active
	var primary := dest == PRIMARY_TAB
	var accent := UIPalette.AMBER if primary else UIPalette.CYAN

	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, HEIGHT - 10)
	button.pressed.connect(func(): navigate.emit(dest))
	var pill := StyleBoxFlat.new()
	if active:
		pill.bg_color = Color(accent, 0.14)
		pill.set_corner_radius_all(10)
		pill.border_width_top = 1
		pill.border_color = Color(accent, 0.5)
	else:
		pill.bg_color = Color(0, 0, 0, 0)
	pill.set_content_margin_all(2)
	button.add_theme_stylebox_override("normal", pill)
	button.add_theme_stylebox_override("hover", pill)
	button.add_theme_stylebox_override("pressed", pill)
	button.add_theme_stylebox_override("focus", UIPalette.empty())

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var icon_tone := accent if active else \
		(Color(accent, 0.75) if primary else Color(UIPalette.MUTED, 0.65))
	var icon_holder := CenterContainer.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(Glyph.make(glyph_kind, 17.0, icon_tone))
	column.add_child(icon_holder)

	var caption := Label.new()
	caption.text = label
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", UIPalette.caption_font())
	caption.add_theme_font_size_override("font_size", 8)
	caption.add_theme_color_override("font_color",
		UIPalette.TEXT if active else (Color(accent, 0.8) if primary else UIPalette.MUTED))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption)
	return button
