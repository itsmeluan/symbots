## IconGlyph — a themeable vector icon drawn in code (no texture files).
##
## The v1 UI wants small, crisp symbols — currencies, roles, part slots — that read at any
## size and recolour with the theme. A pixel-art PNG per icon would be a file to author, a
## fixed resolution, and a fixed colour. Drawing them in [method _draw] instead keeps them
## sharp when the whole game fractional-scales to fill a phone screen, and lets one glyph be
## tinted amber for Scrap or cyan for Alloy without a second asset.
##
## Skill icons are the exception: those get real pixel art later (Pixel Lab). Until then a
## skill shows an effect-kind glyph from here so the drawer is never blank.
class_name IconGlyph
extends Control

## Which symbol to draw. See the match in [method _draw] for the roster.
@export var glyph: StringName = &"":
	set(value):
		glyph = value
		queue_redraw()

## Line/fill colour. Defaults to primary text; screens set it per use (amber, cyan, …).
var color: Color = UIPalette.TEXT:
	set(value):
		color = value
		queue_redraw()

## Stroke width in px at the icon's drawn scale.
var line_width: float = 2.0


func _init(p_glyph: StringName = &"", p_color: Color = UIPalette.TEXT, p_size: float = 24.0) -> void:
	glyph = p_glyph
	color = p_color
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var u: float = minf(size.x, size.y)
	if u <= 0.0:
		return
	var c := size * 0.5           # centre
	var r := u * 0.5 * 0.78       # working radius (leaves a margin)
	var w := line_width
	var fill := Color(color, 0.16)

	match glyph:
		&"scrap":
			# A gear: a ring, a hub, and eight teeth.
			for i in 8:
				var a := TAU * float(i) / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_line(c + d * r, c + d * (r + u * 0.10), color, w, true)
			draw_arc(c, r, 0.0, TAU, 32, color, w, true)
			draw_circle(c, r * 0.34, color)
		&"alloy":
			# A cut ingot/crystal: a hexagon with a faint fill and a facet line.
			var hex := _polygon(c, r, 6, -PI / 2.0)
			draw_colored_polygon(hex, fill)
			draw_polyline(_closed(hex), color, w, true)
			draw_line(c + Vector2(-r * 0.5, 0), c + Vector2(r * 0.5, 0), color, w * 0.7, true)
		&"role_dps":
			# A blade pointing up-right with a crossguard — attack.
			draw_line(c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.6, -r * 0.7), color, w, true)
			draw_line(c + Vector2(r * 0.15, -r * 0.15), c + Vector2(r * 0.6, r * 0.05), color, w, true)
			draw_line(c + Vector2(r * 0.15, -r * 0.15), c + Vector2(-r * 0.05, -r * 0.6), color, w, true)
		&"role_tank":
			# A shield.
			var sh: PackedVector2Array = [
				c + Vector2(0, -r), c + Vector2(r * 0.85, -r * 0.55),
				c + Vector2(r * 0.85, r * 0.2), c + Vector2(0, r),
				c + Vector2(-r * 0.85, r * 0.2), c + Vector2(-r * 0.85, -r * 0.55)]
			draw_colored_polygon(sh, fill)
			draw_polyline(_closed(sh), color, w, true)
		&"role_heal":
			# A plus.
			var t := r * 0.34
			var plus: PackedVector2Array = [
				c + Vector2(-t, -r), c + Vector2(t, -r), c + Vector2(t, -t),
				c + Vector2(r, -t), c + Vector2(r, t), c + Vector2(t, t),
				c + Vector2(t, r), c + Vector2(-t, r), c + Vector2(-t, t),
				c + Vector2(-r, t), c + Vector2(-r, -t), c + Vector2(-t, -t)]
			draw_colored_polygon(plus, fill)
			draw_polyline(_closed(plus), color, w, true)
		&"role_supp":
			# A node broadcasting — support/utility.
			draw_circle(c, r * 0.26, color)
			draw_arc(c, r * 0.58, -PI * 0.35, PI * 0.35, 12, color, w, true)
			draw_arc(c, r * 0.92, -PI * 0.30, PI * 0.30, 12, color, w, true)
		&"part_core":
			draw_arc(c, r, 0.0, TAU, 32, color, w, true)
			draw_circle(c, r * 0.42, color)
		&"part_chassis":
			# A torso: broad shoulders tapering down.
			var ch: PackedVector2Array = [
				c + Vector2(-r * 0.9, -r * 0.5), c + Vector2(r * 0.9, -r * 0.5),
				c + Vector2(r * 0.6, r), c + Vector2(-r * 0.6, r)]
			draw_polyline(_closed(ch), color, w, true)
			draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r), color, w * 0.6, true)
		&"part_head":
			# A helmet: rounded box with a visor line.
			_draw_round_rect(Rect2(c - Vector2(r * 0.75, r * 0.8), Vector2(r * 1.5, r * 1.5)), r * 0.3, w)
			draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(r * 0.55, 0), color, w, true)
		&"part_arms":
			# Two arms.
			for sx in [-1.0, 1.0]:
				draw_line(c + Vector2(sx * r * 0.55, -r * 0.8), c + Vector2(sx * r * 0.55, r * 0.8), color, w * 1.4, true)
		&"part_legs":
			# A stance.
			draw_line(c + Vector2(0, -r * 0.8), c + Vector2(-r * 0.7, r * 0.9), color, w * 1.4, true)
			draw_line(c + Vector2(0, -r * 0.8), c + Vector2(r * 0.7, r * 0.9), color, w * 1.4, true)
		# --- skill effect-kind placeholders (swapped for real art later) ---
		&"skill_damage":
			draw_polyline([c + Vector2(-r * 0.5, -r), c + Vector2(r * 0.1, -r * 0.1),
				c + Vector2(-r * 0.2, 0), c + Vector2(r * 0.5, r)], color, w, true)
		&"skill_heal":
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), color, w * 1.6, true)
			draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), color, w * 1.6, true)
		&"skill_buff":
			draw_line(c + Vector2(0, r), c + Vector2(0, -r), color, w, true)
			draw_line(c + Vector2(0, -r), c + Vector2(-r * 0.5, -r * 0.4), color, w, true)
			draw_line(c + Vector2(0, -r), c + Vector2(r * 0.5, -r * 0.4), color, w, true)
		&"skill_debuff":
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), color, w, true)
			draw_line(c + Vector2(0, r), c + Vector2(-r * 0.5, r * 0.4), color, w, true)
			draw_line(c + Vector2(0, r), c + Vector2(r * 0.5, r * 0.4), color, w, true)
		&"skill_shield":
			var sk: PackedVector2Array = [c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.4),
				c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.4)]
			draw_polyline(_closed(sk), color, w, true)
		_:
			# Unknown glyph: a neutral diamond, so a missing name is visible, not blank.
			draw_polyline(_closed(_polygon(c, r * 0.8, 4, 0.0)), Color(color, 0.5), w, true)


## Regular polygon points, [param n] sides, starting angle [param a0].
func _polygon(centre: Vector2, radius: float, n: int, a0: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := a0 + TAU * float(i) / float(n)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
	return pts


## A polyline needs the first point repeated to close the outline.
func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if pts.size() > 0:
		out.append(pts[0])
	return out


func _draw_round_rect(rect: Rect2, _radius: float, w: float) -> void:
	# A plain rect outline is enough at icon scale; the radius arg keeps call sites readable.
	draw_rect(rect, color, false, w)
