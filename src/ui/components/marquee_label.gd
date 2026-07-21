## MarqueeLabel — a one-line label that scrolls itself when it does not fit.
##
## The part rows list every stat a part grows, beside an Upgrade button that eats the width.
## Truncating with an ellipsis would hide exactly the numbers the row exists to show, so the
## text slides left instead: it pauses, walks left until its tail is visible, pauses, then
## snaps back to the start instantly and repeats. Text that already fits never moves.
class_name MarqueeLabel
extends Control

const PAUSE_START := 1.2
const PAUSE_END := 0.8
## Scroll speed in px/second — slow enough to read while it moves.
const SPEED := 20.0

var _label: Label
var _tw: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	resized.connect(_restart)


## Match the surrounding type. Call before [method set_text].
func style(font_size: int, colour: Color, variation: StringName = &"") -> void:
	if variation != &"":
		_label.theme_type_variation = variation
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", colour)
	custom_minimum_size = Vector2(0, font_size + 4)


func set_text(value: String) -> void:
	_label.text = value
	_restart()


## (Re)start the walk. A no-op when the text fits, so short rows stay perfectly still.
func _restart() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
	_label.position.x = 0
	_label.size = Vector2(_label.get_minimum_size().x, size.y)
	if not is_inside_tree() or size.x <= 0.0:
		return
	var overflow := _label.get_minimum_size().x - size.x
	if overflow <= 1.0:
		return
	_tw = create_tween().set_loops()
	_tw.tween_interval(PAUSE_START)
	_tw.tween_property(_label, "position:x", -overflow, overflow / SPEED)
	_tw.tween_interval(PAUSE_END)
	# Instant return — a scroll back would read as a second, meaningless pass.
	_tw.tween_callback(func(): _label.position.x = 0)
