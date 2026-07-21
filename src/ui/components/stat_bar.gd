## StatBar — one stat's icon, name, value and a fill bar, with a grow animation.
##
## The bar fills toward the stat's value at this mark's cap, so it reads as "how close to
## maxed". When the value rises (a part was upgraded) the new slice of bar GROWS IN BLUE and
## then settles to amber — a small, legible reward for the spend. Drawn as a pure function of
## three animated fractions so the whole effect lives in [method _draw].
class_name StatBar
extends Control

## The player tapped this stat's info button; carries the stat id and the button's screen
## position so the screen can place the explanation tooltip.
signal info_pressed(stat_id: StringName, at_global: Vector2)

const GROW_TIME := 0.30
const SETTLE_TIME := 0.28
const BAR_H := 5.0
const BLUE := Color("4d9bff")

var _stat_id: StringName = &""
var _cap: float = 1.0
var _amber: float = 0.0      ## settled fill fraction
var _blue: float = 0.0       ## leading edge of the freshly-grown slice
var _mix: float = 1.0        ## 0 = the grown slice is blue, 1 = it has become amber
var _tw: Tween

var _icon: TextureRect
var _name: Label
var _info: Button
var _value: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	row.offset_bottom = 17
	row.offset_right = -12  # keep the value clear of the screen edge / scrollbar
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(15, 15)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.modulate = UIPalette.MUTED
	row.add_child(_icon)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 11)
	_name.add_theme_color_override("font_color", Color("d4dde3"))  # brighter than muted
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_name)

	# A discreet round "i" — taps ask the screen to explain what the stat influences.
	_info = Button.new()
	_info.text = "i"
	_info.custom_minimum_size = Vector2(15, 15)
	_info.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info.add_theme_font_size_override("font_size", 10)
	_style_info(_info)
	_info.pressed.connect(func(): info_pressed.emit(_stat_id, _info.global_position + _info.size * 0.5))
	row.add_child(_info)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_value = Label.new()
	_value.add_theme_font_size_override("font_size", 12)
	_value.add_theme_color_override("font_color", UIPalette.TEXT)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_value)


func _style_info(b: Button) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_corner_radius_all(8)
	box.border_color = UIPalette.MUTED
	box.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	b.add_theme_stylebox_override("pressed", box)
	b.add_theme_stylebox_override("focus", UIPalette.empty())
	b.add_theme_color_override("font_color", UIPalette.MUTED)


## Bind identity (icon + name + stat id) once.
func bind(icon: Texture2D, label: String, stat_id: StringName) -> void:
	_icon.texture = icon
	_name.text = label
	_stat_id = stat_id


## Set the value and its cap. [param animate] plays the blue→amber grow when the value rose.
func set_value(value: int, cap: int, animate: bool) -> void:
	_value.text = str(value)
	_cap = maxf(1.0, float(cap))
	var target := clampf(float(value) / _cap, 0.0, 1.0)
	if animate and is_inside_tree() and target > _amber + 0.002:
		_kill()
		var from := _amber
		_blue = from
		_mix = 0.0
		_tw = create_tween()
		_tw.tween_method(_set_blue, from, target, GROW_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tw.tween_method(_set_mix, 0.0, 1.0, SETTLE_TIME)
		_tw.tween_callback(func():
			_amber = target
			_blue = target
			queue_redraw())
	else:
		_amber = target
		_blue = target
		_mix = 1.0
		queue_redraw()


func _set_blue(v: float) -> void:
	_blue = v
	queue_redraw()


func _set_mix(v: float) -> void:
	_mix = v
	queue_redraw()


func _kill() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null


func _draw() -> void:
	var w := size.x
	var y := size.y - BAR_H
	# Track.
	draw_rect(Rect2(0, y, w, BAR_H), Color(UIPalette.INK, 0.85))
	draw_rect(Rect2(0, y, w, BAR_H), UIPalette.LINE_SOFT, false, 1.0)
	# Settled amber fill.
	if _amber > 0.0:
		draw_rect(Rect2(1, y + 1, (w - 2) * _amber, BAR_H - 2), UIPalette.AMBER)
	# The freshly-grown slice: blue at first, lerping to amber as it settles.
	if _blue > _amber:
		var x0 := 1 + (w - 2) * _amber
		var seg := (w - 2) * (_blue - _amber)
		draw_rect(Rect2(x0, y + 1, seg, BAR_H - 2), BLUE.lerp(UIPalette.AMBER, _mix))
