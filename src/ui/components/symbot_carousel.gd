## SymbotCarousel — the draggable roster of sprites along the bottom (v1 Workshop).
##
## Replaces the old top strip of text tabs. The player drags left/right; the centred Symbot
## grows and the neighbours shrink, and releasing snaps to the nearest. The whole thing is a
## single continuous `scroll` value drawn each frame — item i sits at (i - scroll) from the
## centre and its size interpolates with how close it is — so the grow/shrink and the drag
## share one smooth source of truth rather than per-node tweens fighting each other.
class_name SymbotCarousel
extends Control

## The centred Symbot changed. Fires only when the integer focus crosses, not every pixel,
## so a listener can afford to rebuild the parts panel on it.
signal focused_changed(index: int)

## Distance between adjacent item centres, in px.
const SPACING := 76.0
## Snap animation length.
const SNAP_TIME := 0.22

var _textures: Array = []
## Continuous scroll position, in item units. round() of it is the focused index.
var _scroll: float = 0.0:
	set(value):
		_scroll = clampf(value, 0.0, maxf(0.0, float(_textures.size() - 1)))
		queue_redraw()
		var f := focused_index()
		if f != _last_focus:
			_last_focus = f
			focused_changed.emit(f)

var _last_focus: int = -1
var _pressed: bool = false
var _moved: float = 0.0
var _snap: Tween = null


func _init() -> void:
	custom_minimum_size = Vector2(0, 128)
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep the pixel art crisp
	mouse_filter = Control.MOUSE_FILTER_STOP


## Give the carousel one texture per Symbot, in roster order. Focus resets to the first.
func set_items(textures: Array) -> void:
	_textures = textures
	_last_focus = -1
	_scroll = 0.0
	_last_focus = 0
	queue_redraw()


func focused_index() -> int:
	return clampi(int(round(_scroll)), 0, maxi(0, _textures.size() - 1))


func item_count() -> int:
	return _textures.size()


## Animate the focus to a specific index (used by a tap on a side sprite, or externally).
func focus(index: int) -> void:
	_animate_to(clampi(index, 0, _textures.size() - 1))


func _draw() -> void:
	var n := _textures.size()
	if n == 0:
		return
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	# The focused sprite is the only fully opaque one, so it barely needs a size boost — a
	# small one keeps it clearly in front without dwarfing its neighbours.
	var focus_h := size.y * 0.76
	var side_h := size.y * 0.60

	# Farthest-first so the focused sprite draws on top of its neighbours.
	var order: Array = []
	for i in n:
		order.append(i)
	order.sort_custom(func(a, b): return absf(a - _scroll) > absf(b - _scroll))

	for i in order:
		var tex: Texture2D = _textures[i]
		if tex == null:
			continue
		var dx := (float(i) - _scroll) * SPACING
		var x := cx + dx
		if x < -SPACING or x > size.x + SPACING:
			continue
		var t := clampf(1.0 - absf(float(i) - _scroll), 0.0, 1.0)
		var h := lerpf(side_h, focus_h, t)
		var aspect := float(tex.get_width()) / maxf(1.0, float(tex.get_height()))
		var w := h * aspect
		var a := lerpf(0.5, 1.0, t)
		var rect := Rect2(x - w * 0.5, cy - h * 0.5, w, h)
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, a))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_pressed = true
			_moved = 0.0
			_kill_snap()
		else:
			_pressed = false
			_release(event.position.x)
		accept_event()
	elif _pressed and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_scroll -= event.relative.x / SPACING
		_moved += absf(event.relative.x)
		accept_event()


## A release is either a flick (snap to nearest) or a tap (focus the sprite under the finger).
func _release(x: float) -> void:
	if _moved < 8.0:
		var tapped := int(round(_scroll + (x - size.x * 0.5) / SPACING))
		_animate_to(clampi(tapped, 0, _textures.size() - 1))
	else:
		_animate_to(focused_index())


func _animate_to(target: int) -> void:
	_kill_snap()
	if not is_inside_tree() or _textures.is_empty():
		_scroll = float(target)  # no tree yet (boot/tests) → snap without a tween
		return
	_snap = create_tween()
	_snap.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_snap.tween_property(self, "_scroll", float(target), SNAP_TIME)


func _kill_snap() -> void:
	if _snap != null and _snap.is_valid():
		_snap.kill()
	_snap = null
