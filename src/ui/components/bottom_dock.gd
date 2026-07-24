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

const HEIGHT := 56

## dest id -> short label. Order is left-to-right. Four PRIMARY destinations only —
## the secondary ones (Forge, Tree, Send, Bag) live on the Home hub now (research: a
## mobile bottom bar tops out at ~5). MAP is the emphasised "play" tab.
const TABS: Array = [
	[&"home", "HOME"],
	[&"squad", "SQUAD"],
	[&"workshop", "WORKSHOP"],
	[&"map", "MAP"],
]

## The tab drawn as the primary call to action — the way into the core loop.
const PRIMARY_TAB := &"map"

var _active: StringName = &"home"
var _row: HBoxContainer
var _box: StyleBoxFlat


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	# The dock has its own dark bar with a cyan top edge, distinct from the content panels.
	_box = StyleBoxFlat.new()
	_box.bg_color = UIPalette.INK
	_box.border_color = UIPalette.LINE
	_box.border_width_top = 1
	_box.set_content_margin(SIDE_TOP, 4)
	_box.set_content_margin(SIDE_BOTTOM, 4)
	_box.set_content_margin(SIDE_LEFT, 1)
	_box.set_content_margin(SIDE_RIGHT, 1)
	add_theme_stylebox_override("panel", _box)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 0)
	add_child(_row)
	for tab in TABS:
		_row.add_child(_build_tab(tab[0], tab[1]))


## Reserve room below the tabs for the phone's home indicator, so a tap on a tab never lands
## on the OS gesture area. The bar's fill still bleeds to the screen edge; only the tabs move
## up. [param px] is in viewport units (0 on a device with no home indicator, e.g. desktop).
func set_safe_bottom(px: float) -> void:
	_box.set_content_margin(SIDE_BOTTOM, 4.0 + px)
	custom_minimum_size = Vector2(0, HEIGHT + px)


## Light the tab for [param dest] and dim the rest. Call from a screen's setup so the dock
## shows where the player is.
func set_active(dest: StringName) -> void:
	_active = dest
	for i in _row.get_child_count():
		var button: Button = _row.get_child(i)
		_style_tab(button, TABS[i][0] == dest, TABS[i][0] == PRIMARY_TAB)


func _build_tab(dest: StringName, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, HEIGHT - 8)
	button.clip_text = true
	button.pressed.connect(func(): navigate.emit(dest))
	_style_tab(button, dest == _active, dest == PRIMARY_TAB)
	return button


## A tab draws no button chrome — just a label. The ACTIVE tab is the lit key (raised
## face, rounded top, cyan rule). The PRIMARY tab (MAP) always carries an amber accent so
## the way into the fight reads as the call to action even when it is not the open screen.
func _style_tab(button: Button, active: bool, primary: bool) -> void:
	var accent := UIPalette.AMBER if primary else UIPalette.CYAN
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("1c2632") if active else Color(0, 0, 0, 0)
	if active:
		flat.corner_radius_top_left = 7
		flat.corner_radius_top_right = 7
		flat.border_width_top = 2
		flat.border_color = accent
	flat.set_content_margin_all(1)
	button.add_theme_stylebox_override("normal", flat)
	button.add_theme_stylebox_override("hover", flat)
	button.add_theme_stylebox_override("pressed", flat)
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	var idle := accent if primary else UIPalette.MUTED
	button.add_theme_color_override("font_color", accent if active else idle)
	button.add_theme_color_override("font_hover_color", accent)
	# Four tabs share the row now, so they can breathe — a size up from the old eight-tab
	# squeeze; the primary tab is bold.
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_font_override("font",
		UIPalette.bold_font() if primary else UIPalette.display_font())
