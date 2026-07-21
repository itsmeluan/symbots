## SwipeHint — the one-off "drag left" nudge shown when the Workshop opens.
##
## The drawer has no button any more: it is pulled open by dragging the Symbot left. A
## gesture with no affordance is a gesture nobody finds, so the screen shows this once on
## entry — a translucent finger sliding left under a short instruction. It is deliberately
## faint and short-lived: long enough to read, gone before it becomes clutter, and dismissed
## the moment the player touches anything.
class_name SwipeHint
extends Control

## How long the hint holds before fading on its own.
const HOLD := 2.4
const FADE_IN := 0.25
const FADE_OUT := 0.35
## Horizontal travel of the finger, in px.
const TRAVEL := 74.0
const DOT_R := 11.0

var _label: Label
var _travel: float = 0.0   ## 0 → 1 across TRAVEL
var _loop: Tween
var _fade: Tween
var _done: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", UIPalette.TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	add_child(_label)


## Show the hint with [param text]. Safe to call on every screen entry.
func play(text: String) -> void:
	_label.text = text
	_done = false
	visible = true
	_kill()
	# The label sits just under the finger track.
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.offset_left = 0
	_label.offset_right = 0
	_label.anchor_top = 0.5
	_label.offset_top = 26

	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.5, FADE_IN)
	_fade.tween_interval(HOLD)
	_fade.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	# Stop the looping finger when the hint fades, or it would run for the screen's lifetime.
	_fade.tween_callback(func():
		_done = true
		visible = false
		if _loop != null and _loop.is_valid():
			_loop.kill()
		_loop = null)

	_loop = create_tween().set_loops()
	_loop.tween_method(_set_travel, 0.0, 1.0, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(0.25)
	_loop.tween_callback(func(): _set_travel(0.0))


## Fade out now — the player has touched something, so the nudge has done its job.
func dismiss() -> void:
	if _done:
		return
	_done = true
	_kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.15)
	_fade.tween_callback(func(): visible = false)


func _set_travel(v: float) -> void:
	_travel = v
	queue_redraw()


func _kill() -> void:
	if _loop != null and _loop.is_valid():
		_loop.kill()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_loop = null
	_fade = null


func _draw() -> void:
	# A finger dot travelling right → left, with a fading trail behind it.
	var cy := size.y * 0.5
	var start_x := size.x * 0.5 + TRAVEL * 0.5
	var x := start_x - TRAVEL * _travel

	var trail := Color(UIPalette.TEXT, 0.18)
	draw_line(Vector2(start_x, cy), Vector2(x, cy), trail, 2.0, true)
	draw_circle(Vector2(x, cy), DOT_R, Color(UIPalette.TEXT, 0.20))
	draw_arc(Vector2(x, cy), DOT_R, 0.0, TAU, 24, Color(UIPalette.TEXT, 0.55), 1.5, true)
	# A small chevron ahead of the dot, pointing the way.
	var tip := x - DOT_R - 7.0
	draw_polyline(PackedVector2Array([
		Vector2(tip + 6, cy - 5), Vector2(tip, cy), Vector2(tip + 6, cy + 5)]),
		Color(UIPalette.TEXT, 0.45), 1.5, true)
