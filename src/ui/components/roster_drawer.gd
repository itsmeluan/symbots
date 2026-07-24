## RosterDrawer — the swipe-up sheet of Symbot cards, shared by the Workshop and the
## Skill Tree so "pull up to pick who to work on" is one gesture everywhere.
##
## Emits [signal card_pressed]; the HOST decides what a pick means (dossier, select,
## navigate). The sheet follows the finger while dragging and dragging it all the way
## down closes it. The grab affordance is just the pill — no box around it.
class_name RosterDrawer
extends Control

signal card_pressed(symbot: SymbotInstance)

## Fraction of the host's height the open sheet covers.
const HEIGHT_FRAC := 0.68

var grid: GridContainer

var _ctx: ServiceContext = null
var _scrim: ColorRect
var _sheet: PanelContainer
var _t: float = 0.0
var _tween: Tween = null
var _drag_active: bool = false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_scrim = ColorRect.new()
	_scrim.color = Color(UIPalette.INK, 0.6)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close())
	add_child(_scrim)

	_sheet = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.SURFACE
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_detail = 20
	box.anti_aliasing_size = 1.0
	box.border_width_top = 1
	box.border_color = Color(1, 1, 1, 0.10)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	box.set_content_margin_all(10)
	_sheet.add_theme_stylebox_override("panel", box)
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.gui_input.connect(_on_sheet_input)
	add_child(_sheet)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_sheet.add_child(column)

	# Just the pill — the universal "this sheet drags" mark, with nothing framing it.
	var handle := Control.new()
	handle.custom_minimum_size = Vector2(0, 12)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := Panel.new()
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = UIPalette.LINE
	pill_box.set_corner_radius_all(3)
	pill.add_theme_stylebox_override("panel", pill_box)
	pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pill.offset_left = -22
	pill.offset_right = 22
	pill.offset_bottom = 5
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.add_child(pill)
	column.add_child(handle)

	var title := Label.new()
	title.text = "SYMBOTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIPalette.caption_font())
	title.add_theme_font_size_override("font_size", 13)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIPalette.thin_scrollbar(scroll)
	column.add_child(scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_right", 8)
	scroll.add_child(pad)

	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	pad.add_child(grid)


## Populate from the roster and slide up.
func open_with(ctx: ServiceContext) -> void:
	_ctx = ctx
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for symbot in ctx.roster.symbots:
		grid.add_child(SymbotCard.build(ctx, symbot,
			func() -> void: card_pressed.emit(symbot)))
	_animate(true)


func close() -> void:
	_animate(false)


func is_open() -> bool:
	return _t > 0.5


func _sheet_height() -> float:
	return size.y * HEIGHT_FRAC


func _apply_t() -> void:
	var h := _sheet_height()
	_sheet.offset_top = -h * _t
	_sheet.offset_bottom = h * (1.0 - _t)
	visible = _t > 0.001
	_scrim.modulate.a = _t


func _animate(open: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		_t = 1.0 if open else 0.0
		_apply_t()
		return
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		_t = v
		_apply_t(),
		_t, 1.0 if open else 0.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The sheet follows the finger; releasing settles to the nearer side. Dragging it all
## the way down is how it closes.
func _on_sheet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_active = true
			if _tween != null and _tween.is_valid():
				_tween.kill()
		elif _drag_active:
			_drag_active = false
			_animate(_t > 0.55)
	elif _drag_active and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_t = clampf(_t - event.relative.y / _sheet_height(), 0.0, 1.0)
		_apply_t()
