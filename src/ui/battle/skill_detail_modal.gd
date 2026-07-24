## SkillDetailModal — everything about one skill, opened by tapping its icon in a unit
## dossier. The mockup shape: the round icon chip beside the name and description up top,
## then the numbers below (base power, damage now, effects, target, cost).
##
## A pure viewer stacked over its host. The caster is passed in so the damage line reads
## from real stats, not a guess.
class_name SkillDetailModal
extends Control

signal closed

var _skill: SkillDef = null
var _unit: BattleUnit = null
var _ult_cost: int = 100


func open(skill: SkillDef, unit: BattleUnit, ult_cost: int) -> void:
	_skill = skill
	_unit = unit
	_ult_cost = maxi(1, ult_cost)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40
	_build()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(UIPalette.INK, 0.82)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_dismiss())
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIPalette.chunky(UIPalette.OVERLAY))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(320, 0)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	column.add_child(_header())

	var rule := ColorRect.new()
	rule.color = Color(UIPalette.LINE, 0.4)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)

	for pair in SkillInfo.detail_rows(_unit, _skill, _ult_cost):
		column.add_child(_stat_row(pair[0], pair[1]))

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(_dismiss)
	column.add_child(close_button)


## The header from the mockup: round icon chip, then name (bold, amber for ults) over the
## description (thin, muted).
func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	row.add_child(SkillInfo.round_chip(_skill, 60.0))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 3)
	row.add_child(text)

	var name_label := Label.new()
	name_label.text = _skill.display_name
	name_label.add_theme_font_override("font", UIPalette.bold_font())
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color",
		UIPalette.AMBER if _skill.is_ultimate else UIPalette.TEXT)
	text.add_child(name_label)

	var desc := Label.new()
	desc.text = _skill.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UIPalette.MUTED)
	text.add_child(desc)
	return row


## One labelled figure: muted caption on the left, the value on the right.
func _stat_row(label: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var key := Label.new()
	key.text = label.to_upper()
	key.add_theme_font_override("font", UIPalette.caption_font())
	key.add_theme_font_size_override("font_size", 10)
	key.add_theme_color_override("font_color", UIPalette.MUTED)
	key.custom_minimum_size = Vector2(96, 0)
	row.add_child(key)

	var val := Label.new()
	val.text = value
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", UIPalette.TEXT)
	row.add_child(val)
	return row


func _dismiss() -> void:
	closed.emit()
	queue_free()
