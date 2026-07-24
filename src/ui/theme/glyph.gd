## Glyph — the project's code-drawn icon set (ADR-0008 presentation tier).
##
## Icons are DRAWN, not textures: crisp at any scale, tinted by the palette, and zero
## asset-pipeline weight — the same reasoning as the code-built v1 UI itself. The pixel-art
## belongs to the creatures; the chrome around them stays clean vector, which is what keeps
## a busy battlefield readable.
##
## One Control per icon. `Glyph.make(&"sword", 14, UIPalette.CORAL)` is the whole API;
## every icon is designed on a unit square and scaled by [member size], so callers only
## ever think in final pixels.
class_name Glyph
extends Control

## Which icon to draw. The roster below is the project vocabulary — add here, and every
## screen can use it. See [method _draw] for the shapes.
var kind: StringName = &"sword"
var colour: Color = Color.WHITE
var thickness: float = 1.6


static func make(p_kind: StringName, px: float, p_colour: Color) -> Glyph:
	var g := Glyph.new()
	g.kind = p_kind
	g.colour = p_colour
	g.custom_minimum_size = Vector2(px, px)
	g.size = Vector2(px, px)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## Icon for a skill, derived from what it IS: ult star first, then its first effect.
static func for_skill(skill: SkillDef) -> StringName:
	if skill.is_ultimate:
		return &"star"
	for effect in skill.effects:
		match int(effect.get("kind", SkillDef.EffectKind.INVALID)):
			SkillDef.EffectKind.DAMAGE:
				return &"bolt" if skill.scaling_stat == &"energy_power" else &"sword"
			SkillDef.EffectKind.HEAL:
				return &"wrench"
			SkillDef.EffectKind.SHIELD:
				return &"shield"
			SkillDef.EffectKind.APPLY_STATUS:
				return &"arrow_down" if bool(effect.get("is_debuff", true)) else &"arrow_up"
			SkillDef.EffectKind.CLEANSE:
				return &"sparkle"
			SkillDef.EffectKind.REVIVE:
				return &"core"
	return &"sword"


## Icon per canonical stat key (unit modal, future inspectors).
const FOR_STAT := {
	&"structure": &"core",
	&"physical_power": &"sword",
	&"energy_power": &"bolt",
	&"armor": &"shield",
	&"resistance": &"hex",
	&"mobility": &"chevrons",
	&"targeting": &"reticle",
	&"processing": &"chip",
}

## Icon per status kind (unit panel chips, unit modal).
const FOR_STATUS := {
	StatusEffect.Kind.BURN: &"flame",
	StatusEffect.Kind.CORRODE: &"droplet",
	StatusEffect.Kind.SHOCK: &"bolt",
	StatusEffect.Kind.STUN: &"spiral",
	StatusEffect.Kind.SLOW: &"clock",
	StatusEffect.Kind.TAUNT_BREAK: &"hex",
	StatusEffect.Kind.HASTE: &"chevrons",
	StatusEffect.Kind.REGEN: &"wrench",
	StatusEffect.Kind.DAMAGE_REDUCTION: &"shield",
	StatusEffect.Kind.ATTACK_UP: &"arrow_up",
	StatusEffect.Kind.ATTACK_DOWN: &"arrow_down",
	StatusEffect.Kind.CRIT_UP: &"reticle",
	StatusEffect.Kind.PIERCE: &"sword",
	StatusEffect.Kind.COOLDOWN_REDUCTION: &"clock",
}


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		return
	# Everything below is authored on a 0..1 square then scaled — `p()` maps a design
	# point to pixels.
	match kind:
		&"sword":
			# Blade from lower-left to upper-right with a crossguard.
			_line(Vector2(0.25, 0.75), Vector2(0.80, 0.20), s)
			_line(Vector2(0.32, 0.48), Vector2(0.52, 0.68), s)
			_line(Vector2(0.16, 0.84), Vector2(0.28, 0.72), s)
		&"bolt":
			var points := PackedVector2Array([
				p(Vector2(0.60, 0.08), s), p(Vector2(0.30, 0.52), s), p(Vector2(0.50, 0.52), s),
				p(Vector2(0.40, 0.92), s), p(Vector2(0.72, 0.44), s), p(Vector2(0.52, 0.44), s)])
			draw_colored_polygon(points, colour)
		&"wrench":
			draw_arc(p(Vector2(0.68, 0.32), s), s * 0.16, PI * 0.25, PI * 1.75, 10,
				colour, thickness)
			_line(Vector2(0.58, 0.42), Vector2(0.22, 0.78), s)
		&"shield":
			var top := 0.14
			var points := PackedVector2Array([
				p(Vector2(0.50, top), s), p(Vector2(0.82, 0.26), s), p(Vector2(0.78, 0.58), s),
				p(Vector2(0.50, 0.90), s), p(Vector2(0.22, 0.58), s), p(Vector2(0.18, 0.26), s)])
			draw_polyline(points + PackedVector2Array([points[0]]), colour, thickness)
		&"star":
			var pts: PackedVector2Array = []
			for i in 10:
				var r := 0.42 if i % 2 == 0 else 0.18
				var a := -PI * 0.5 + TAU * i / 10.0
				pts.append(p(Vector2(0.5 + cos(a) * r, 0.5 + sin(a) * r), s))
			draw_colored_polygon(pts, colour)
		&"hex":
			var pts: PackedVector2Array = []
			for i in 6:
				var a := -PI * 0.5 + TAU * i / 6.0
				pts.append(p(Vector2(0.5 + cos(a) * 0.38, 0.5 + sin(a) * 0.38), s))
			draw_polyline(pts + PackedVector2Array([pts[0]]), colour, thickness)
		&"chevrons":
			_line(Vector2(0.28, 0.30), Vector2(0.56, 0.50), s)
			_line(Vector2(0.56, 0.50), Vector2(0.28, 0.70), s)
			_line(Vector2(0.52, 0.30), Vector2(0.80, 0.50), s)
			_line(Vector2(0.80, 0.50), Vector2(0.52, 0.70), s)
		&"reticle":
			draw_arc(p(Vector2(0.5, 0.5), s), s * 0.28, 0.0, TAU, 16, colour, thickness)
			_line(Vector2(0.5, 0.08), Vector2(0.5, 0.28), s)
			_line(Vector2(0.5, 0.72), Vector2(0.5, 0.92), s)
			_line(Vector2(0.08, 0.5), Vector2(0.28, 0.5), s)
			_line(Vector2(0.72, 0.5), Vector2(0.92, 0.5), s)
		&"chip":
			draw_rect(Rect2(p(Vector2(0.28, 0.28), s), Vector2(s * 0.44, s * 0.44)),
				colour, false, thickness)
			for f in [0.38, 0.62]:
				_line(Vector2(f, 0.10), Vector2(f, 0.28), s)
				_line(Vector2(f, 0.72), Vector2(f, 0.90), s)
				_line(Vector2(0.10, f), Vector2(0.28, f), s)
				_line(Vector2(0.72, f), Vector2(0.90, f), s)
		&"core":
			draw_arc(p(Vector2(0.5, 0.5), s), s * 0.32, 0.0, TAU, 16, colour, thickness)
			draw_circle(p(Vector2(0.5, 0.5), s), s * 0.12, colour)
		&"flame":
			# A teardrop flame: two arcs meeting in a point at the top.
			var pts := PackedVector2Array([
				p(Vector2(0.50, 0.10), s), p(Vector2(0.70, 0.42), s), p(Vector2(0.66, 0.72), s),
				p(Vector2(0.50, 0.88), s), p(Vector2(0.34, 0.72), s), p(Vector2(0.30, 0.42), s)])
			draw_colored_polygon(pts, colour)
		&"droplet":
			var pts := PackedVector2Array([
				p(Vector2(0.50, 0.10), s), p(Vector2(0.68, 0.52), s), p(Vector2(0.60, 0.80), s),
				p(Vector2(0.40, 0.80), s), p(Vector2(0.32, 0.52), s)])
			draw_colored_polygon(pts, colour)
		&"spiral":
			for i in 3:
				draw_arc(p(Vector2(0.5, 0.5), s), s * (0.14 + 0.10 * i),
					TAU * 0.25 * i, TAU * 0.25 * i + PI * 1.3, 10, colour, thickness)
		&"arrow_up":
			_line(Vector2(0.5, 0.85), Vector2(0.5, 0.20), s)
			_line(Vector2(0.28, 0.42), Vector2(0.5, 0.18), s)
			_line(Vector2(0.72, 0.42), Vector2(0.5, 0.18), s)
		&"arrow_down":
			_line(Vector2(0.5, 0.15), Vector2(0.5, 0.80), s)
			_line(Vector2(0.28, 0.58), Vector2(0.5, 0.82), s)
			_line(Vector2(0.72, 0.58), Vector2(0.5, 0.82), s)
		&"clock":
			draw_arc(p(Vector2(0.5, 0.5), s), s * 0.34, 0.0, TAU, 16, colour, thickness)
			_line(Vector2(0.5, 0.5), Vector2(0.5, 0.28), s)
			_line(Vector2(0.5, 0.5), Vector2(0.66, 0.58), s)
		&"sparkle":
			_line(Vector2(0.5, 0.12), Vector2(0.5, 0.88), s)
			_line(Vector2(0.12, 0.5), Vector2(0.88, 0.5), s)
			_line(Vector2(0.28, 0.28), Vector2(0.72, 0.72), s)
			_line(Vector2(0.72, 0.28), Vector2(0.28, 0.72), s)
		&"bag":
			# A pouch: a rounded body under a drawstring neck.
			var body := PackedVector2Array([
				p(Vector2(0.24, 0.42), s), p(Vector2(0.76, 0.42), s),
				p(Vector2(0.82, 0.86), s), p(Vector2(0.18, 0.86), s)])
			draw_polyline(body + PackedVector2Array([body[0]]), colour, thickness)
			_line(Vector2(0.34, 0.42), Vector2(0.40, 0.20), s)
			_line(Vector2(0.66, 0.42), Vector2(0.60, 0.20), s)
			_line(Vector2(0.40, 0.20), Vector2(0.60, 0.20), s)
		&"branch":
			# A trunk that forks twice — the skill tree.
			_line(Vector2(0.5, 0.90), Vector2(0.5, 0.52), s)
			_line(Vector2(0.5, 0.52), Vector2(0.26, 0.28), s)
			_line(Vector2(0.5, 0.52), Vector2(0.74, 0.28), s)
			draw_circle(p(Vector2(0.26, 0.24), s), s * 0.09, colour)
			draw_circle(p(Vector2(0.74, 0.24), s), s * 0.09, colour)
			draw_circle(p(Vector2(0.5, 0.52), s), s * 0.07, colour)
		&"anvil":
			# A blocky anvil — the forge.
			var anvil := PackedVector2Array([
				p(Vector2(0.16, 0.40), s), p(Vector2(0.84, 0.40), s),
				p(Vector2(0.70, 0.52), s), p(Vector2(0.60, 0.52), s),
				p(Vector2(0.60, 0.66), s), p(Vector2(0.40, 0.66), s),
				p(Vector2(0.40, 0.52), s), p(Vector2(0.30, 0.52), s)])
			draw_colored_polygon(anvil, colour)
			draw_rect(Rect2(p(Vector2(0.34, 0.72), s), Vector2(s * 0.32, s * 0.10)), colour)
		&"send":
			# A paper plane pointing up-right — dispatch.
			var plane := PackedVector2Array([
				p(Vector2(0.14, 0.52), s), p(Vector2(0.86, 0.18), s),
				p(Vector2(0.52, 0.86), s), p(Vector2(0.44, 0.58), s)])
			draw_colored_polygon(plane, colour)
		_:
			draw_arc(p(Vector2(0.5, 0.5), s), s * 0.3, 0.0, TAU, 12, colour, thickness)


func p(design: Vector2, s: float) -> Vector2:
	return design * s


func _line(a: Vector2, b: Vector2, s: float) -> void:
	draw_line(p(a, s), p(b, s), colour, thickness)
