## ChamferStyleBox — a StyleBox with two opposite corners cut, matching the nameplate tag.
##
## The v1 UI's signature shape is a rectangle with the top-left and bottom-right corners
## sheared off (see [SymbotNameplate]). StyleBoxFlat can only round corners, so the small
## controls that must share that shape — the part Upgrade button — use this instead. Drawn
## through RenderingServer because a StyleBox has no Control draw helpers.
class_name ChamferStyleBox
extends StyleBox

@export var bg_color: Color = Color.WHITE
@export var border_color: Color = Color(0, 0, 0, 0)
@export var border_width: float = 0.0
@export var chamfer: float = 6.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var o := rect.position
	var w := rect.size.x
	var h := rect.size.y
	var k := minf(chamfer, minf(w, h) * 0.5)
	var pts := PackedVector2Array([
		o + Vector2(k, 0), o + Vector2(w, 0), o + Vector2(w, h - k),
		o + Vector2(w - k, h), o + Vector2(0, h), o + Vector2(0, k)])

	if bg_color.a > 0.0:
		var fill := PackedColorArray()
		fill.resize(pts.size())
		fill.fill(bg_color)
		RenderingServer.canvas_item_add_polygon(to_canvas_item, pts, fill)

	if border_width > 0.0 and border_color.a > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		var line := PackedColorArray()
		line.resize(loop.size())
		line.fill(border_color)
		RenderingServer.canvas_item_add_polyline(to_canvas_item, loop, line, border_width, true)
