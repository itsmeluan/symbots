## BottomDock — persistent bottom navigation across the meta screens (v1 UI prototype).
##
## Replaces the crowded five-button top row with the prototype's dock: one tab per
## destination, the current one lit cyan. The prototype ships four tabs; this game has six
## meta destinations, so the dock holds six — still comfortable at 360px (60px each).
##
## Emits [signal navigate] with a destination id; the screen forwards it and the game root
## routes it. The dock knows nothing about the screens, only their names.
class_name BottomDock
extends PanelContainer

signal navigate(dest: StringName)

const HEIGHT := 56

## dest id -> short label. Order is left-to-right. Kept short because six tabs share one
## row; the label is a reminder, not a sentence.
const TABS: Array = [
	[&"map", "MAP"],
	[&"squad", "SQUAD"],
	[&"workshop", "SHOP"],
	[&"tree", "TREE"],
	[&"foundry", "FORGE"],
	[&"expeditions", "SEND"],
]

var _active: StringName = &"map"
var _row: HBoxContainer


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	# The dock has its own dark bar with a cyan top edge, distinct from the content panels.
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.INK
	box.border_color = UIPalette.LINE
	box.border_width_top = 1
	box.set_content_margin_all(4)
	add_theme_stylebox_override("panel", box)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 3)
	add_child(_row)
	for tab in TABS:
		_row.add_child(_build_tab(tab[0], tab[1]))


## Light the tab for [param dest] and dim the rest. Call from a screen's setup so the dock
## shows where the player is.
func set_active(dest: StringName) -> void:
	_active = dest
	for i in _row.get_child_count():
		var button: Button = _row.get_child(i)
		_style_tab(button, TABS[i][0] == dest)


func _build_tab(dest: StringName, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, HEIGHT - 8)
	button.clip_text = true
	button.pressed.connect(func(): navigate.emit(dest))
	_style_tab(button, dest == _active)
	return button


## A tab draws no button chrome — just a label that goes cyan with a top rule when active,
## muted otherwise. This keeps the dock reading as a bar rather than six raised buttons.
func _style_tab(button: Button, active: bool) -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = UIPalette.PANEL_2 if active else Color(0, 0, 0, 0)
	if active:
		flat.border_width_top = 2
		flat.border_color = UIPalette.CYAN
	flat.set_content_margin_all(2)
	button.add_theme_stylebox_override("normal", flat)
	button.add_theme_stylebox_override("hover", flat)
	button.add_theme_stylebox_override("pressed", flat)
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_theme_color_override("font_color",
		UIPalette.CYAN if active else UIPalette.MUTED)
	button.add_theme_color_override("font_hover_color", UIPalette.CYAN)
	button.add_theme_font_size_override("font_size", 12)
