## SymbotNameplate — the focused Symbot's identity card (the second reference image).
##
## A tech panel with two corners chamfered, holding the name in the display face, and under
## it — in cyan — the generation and level, led by a small role ICON rather than the word
## "DPS". The role is a glyph on purpose: the screen carries no written labels, so identity
## reads at a glance without text the player has to parse.
class_name SymbotNameplate
extends Control

const SpeciesDefScript := preload("res://src/core/species/species_def.gd")

## Role enum → the [IconGlyph] name that stands for it.
const ROLE_GLYPHS := {
	SpeciesDefScript.Role.DPS: &"role_dps",
	SpeciesDefScript.Role.TANK: &"role_tank",
	SpeciesDefScript.Role.HEALER: &"role_heal",
	SpeciesDefScript.Role.SUPPORT: &"role_supp",
}

## Role enum → the short word shown beside its icon.
const ROLE_NAMES := {
	SpeciesDefScript.Role.DPS: "DPS",
	SpeciesDefScript.Role.TANK: "TANK",
	SpeciesDefScript.Role.HEALER: "HEAL",
	SpeciesDefScript.Role.SUPPORT: "SUPPORT",
}

const CHAMFER := 10.0
## A hairline XP bar — it reads as a progress rule, not a gauge.
const XP_BAR_H := 2.0
## Breathing room inserted ABOVE the XP bar. A label carries descent padding that a bare bar
## does not, so equal container separation still leaves the identity line hugging the bar.
## Measured from a render: the gap above the line was 16px and below it 3px, so this closes
## the 13px difference and leaves the line equidistant.
const XP_TOP_PAD := 6.25

var _name_label: Label
var _role_icon: IconGlyph
var _sub_label: Label
var _xp_bar: ProgressBar


func _init() -> void:
	custom_minimum_size = Vector2(0, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	_name_label = Label.new()
	_name_label.theme_type_variation = &"Heading"
	_name_label.add_theme_font_size_override("font_size", 19)
	_name_label.add_theme_color_override("font_color", UIPalette.AMBER)
	_name_label.clip_text = true
	col.add_child(_name_label)

	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 5)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)
	_role_icon = IconGlyph.new(&"role_dps", UIPalette.CYAN, 15.0)
	sub.add_child(_role_icon)
	_sub_label = Label.new()
	_sub_label.add_theme_font_size_override("font_size", 11)
	_sub_label.add_theme_color_override("font_color", UIPalette.CYAN)
	sub.add_child(_sub_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, XP_TOP_PAD)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)

	# Experience toward the next level — a hairline bar under the identity line.
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, XP_BAR_H)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.show_percentage = false
	_xp_bar.max_value = 100
	_xp_bar.value = 0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(UIPalette.INK, 0.9)
	track.set_corner_radius_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIPalette.CYAN
	fill.set_corner_radius_all(1)
	_xp_bar.add_theme_stylebox_override("background", track)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_xp_bar)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var k := CHAMFER
	# Top-left and bottom-right corners cut — the sheared "tech tag" outline.
	var shape: PackedVector2Array = [
		Vector2(k, 0), Vector2(w, 0), Vector2(w, h - k),
		Vector2(w - k, h), Vector2(0, h), Vector2(0, k)]
	draw_colored_polygon(shape, Color(UIPalette.INK, 0.9))
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, UIPalette.LINE, 1.5, true)


## Bind the card to a Symbot. [param species] gives name and role, [param inst] the marks,
## and [param xp_percent] (0-100) fills the experience bar toward the next level.
func set_symbot(species: SpeciesDef, inst, xp_percent: int = 0) -> void:
	_xp_bar.value = clampi(xp_percent, 0, 100)
	if species == null or inst == null:
		_name_label.text = ""
		_sub_label.text = ""
		return
	_name_label.text = species.display_name.to_upper()
	_role_icon.glyph = ROLE_GLYPHS.get(species.role, &"role_supp")
	# Order: icon, role name, generation, level.
	_sub_label.text = "%s · MK %s · LV.%d" % [
		ROLE_NAMES.get(species.role, "—"), _roman(inst.mark), inst.level]
	queue_redraw()


func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(n)
