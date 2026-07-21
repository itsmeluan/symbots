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

const CHAMFER := 10.0

var _name_label: Label
var _role_icon: IconGlyph
var _sub_label: Label


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


## Bind the card to a Symbot. [param species] gives name and role, [param inst] the marks.
func set_symbot(species: SpeciesDef, inst) -> void:
	if species == null or inst == null:
		_name_label.text = ""
		_sub_label.text = ""
		return
	_name_label.text = species.display_name.to_upper()
	_role_icon.glyph = ROLE_GLYPHS.get(species.role, &"role_supp")
	_sub_label.text = "MK %s · LV.%d" % [_roman(inst.mark), inst.level]
	queue_redraw()


func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(n)
