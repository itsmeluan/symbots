## UnitInfoModal — full-screen overlay with everything about one combatant (ADR-0008).
##
## Opened by tapping a unit on the battlefield when no skill is armed. Shows identity,
## live stats, the skill kit, and the species' evolution line. The evolution strip is the
## collection tease: the mark being inspected renders normally, other DISCOVERED marks
## render desaturated, and marks the player has never obtained nor met in battle render
## as pure black silhouettes (see [DiscoveryCodex]).
##
## Built in code like every v1 screen. A plain overlay Control rather than a Window —
## it lives inside the battle screen, dims it, and swallows input until dismissed.
class_name UnitInfoModal
extends Control

## Emitted when the player dismisses the modal (scrim tap or the close button).
signal closed

const ROLE_TAGS := UnitPanel.ROLE_TAGS
const RARITY_NAMES := {
	SpeciesDef.Rarity.COMMON: "COMMON",
	SpeciesDef.Rarity.RARE: "RARE",
	SpeciesDef.Rarity.EPIC: "EPIC",
	SpeciesDef.Rarity.PROTOTYPE: "PROTOTYPE",
}
const MARK_LABELS := ["MK I", "MK II", "MK III"]

## Stat rows shown in the grid, in display order: [stat_key, label].
const STAT_ROWS := [
	[&"physical_power", "PHYSICAL PWR"],
	[&"energy_power", "ENERGY PWR"],
	[&"armor", "ARMOR"],
	[&"resistance", "RESISTANCE"],
	[&"mobility", "MOBILITY"],
	[&"targeting", "TARGETING"],
	[&"processing", "PROCESSING"],
]

const EVOLUTION_SPRITE_HEIGHT := 72.0

## Desaturation for discovered-but-other marks in the evolution strip. A shader rather
## than modulate because modulate can only darken/tint — it cannot remove saturation.
const DESAT_SHADER_CODE := "
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(grey), 0.85) * 0.72, c.a);
}"

var unit: BattleUnit = null

var _ctx: ServiceContext = null
var _ult_cost: int = 100
var _column: VBoxContainer = null
var _skill_detail: SkillDetailModal = null


## Build and show for an OWNED instance: the unit is assembled by the REAL pipeline
## (parts, tree, items via UnitBuilder), so the stats shown are exactly what the next
## fight fields. Returns false when the species or build is unresolvable.
func open_instance(symbot: SymbotInstance, ctx: ServiceContext) -> bool:
	if ctx == null or ctx.species == null:
		return false
	var species: SpeciesDef = ctx.species.get_species(symbot.species_id)
	if species == null:
		return false
	var unit: BattleUnit = UnitBuilder.build(symbot, species, ctx.tree, ctx.skills,
		BattleUnit.Side.PLAYER, 0, ctx.items)
	if unit == null:
		return false
	var cost := 100
	var ult: SkillDef = ctx.skills.get(unit.ultimate_skill)
	if ult != null:
		cost = ult.charge_cost
	open(unit, ctx, cost)
	return true


## Build and show. [param ult_cost] is the charge cost of the unit's ult, injected by the
## battle screen which owns the skill table.
func open(p_unit: BattleUnit, ctx: ServiceContext, ult_cost: int) -> void:
	unit = p_unit
	_ctx = ctx
	_ult_cost = maxi(1, ult_cost)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# The scrim: dims the battle and swallows every tap that is not on the panel.
	var scrim := ColorRect.new()
	scrim.color = Color(UIPalette.INK, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIPalette.panel(UIPalette.LINE, UIPalette.PANEL))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(328, 0)
	add_child(panel)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 8)
	panel.add_child(_column)

	var species: SpeciesDef = null
	if _ctx != null and _ctx.species != null:
		species = _ctx.species.get_species(unit.species_id)

	_column.add_child(_header(species))
	_column.add_child(_evolution_strip(species))
	_column.add_child(_stats_grid())
	_column.add_child(_skill_list())


## Append a primary action to the modal's foot (e.g. the squad screen's ADD TO SQUAD).
## The modal stays a pure viewer — the CALLER owns what the action does; pressing it
## runs the callable and dismisses. Call after [method open].
## The pair of navigation actions every roster dossier carries: WORKSHOP | TREE, half
## width each on one row. Each runs its callable and dismisses.
func add_nav_actions(on_workshop: Callable, on_tree: Callable) -> void:
	if _column == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_column.add_child(row)
	for pair in [["WORKSHOP", on_workshop, &"wrench"], ["TREE", on_tree, &"branch"]]:
		var button := Button.new()
		button.text = pair[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_constant_override("h_separation", 5)
		button.add_theme_constant_override("icon_max_width", 14)
		var callable: Callable = pair[1]
		button.icon = null
		button.pressed.connect(func() -> void:
			callable.call()
			_dismiss())
		row.add_child(button)


func add_action(label: String, on_pressed: Callable, primary: bool = true) -> void:
	if _column == null:
		return
	var button := Button.new()
	if primary:
		button.theme_type_variation = &"Primary"
		button.add_child(UIPalette.gloss())
	button.text = label
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(func() -> void:
		on_pressed.call()
		_dismiss())
	_column.add_child(button)


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

func _header(species: SpeciesDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = unit.display_name
	name_label.add_theme_font_override("font", UIPalette.bold_font())
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var tags := Label.new()
	var bits: PackedStringArray = []
	bits.append("LV %d" % unit.level)
	bits.append(String(ROLE_TAGS.get(unit.role, "")))
	if species != null:
		bits.append(String(RARITY_NAMES.get(species.rarity, "")))
	bits.append(MARK_LABELS[clampi(unit.art_mark, 1, 3) - 1])
	tags.text = " · ".join(bits)
	tags.add_theme_font_size_override("font_size", 10)
	tags.add_theme_color_override("font_color", UIPalette.MUTED)
	tags.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tags)

	# Just the glyph — no button box. Muted, brightening on press.
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(24, 24)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", UIPalette.MUTED)
	close_button.add_theme_color_override("font_hover_color", UIPalette.TEXT)
	close_button.add_theme_color_override("font_pressed_color", UIPalette.TEXT)
	close_button.add_theme_stylebox_override("normal", UIPalette.empty())
	close_button.add_theme_stylebox_override("hover", UIPalette.empty())
	close_button.add_theme_stylebox_override("pressed", UIPalette.empty())
	close_button.add_theme_stylebox_override("focus", UIPalette.empty())
	close_button.pressed.connect(_dismiss)
	row.add_child(close_button)
	return row


## The evolution line: every mark side by side with arrows between, the inspected mark
## bright, other discovered marks desaturated, unknown marks as black silhouettes.
func _evolution_strip(species: SpeciesDef) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)

	var desat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DESAT_SHADER_CODE
	desat.shader = shader

	for mark in range(1, 4):
		if mark > 1:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 16)
			arrow.add_theme_color_override("font_color", UIPalette.MUTED)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(arrow)
		row.add_child(_evolution_slot(species, mark, desat))
	return row


func _evolution_slot(species: SpeciesDef, mark: int, desat: ShaderMaterial) -> Control:
	var discovered := _is_discovered(mark)
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 2)

	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(EVOLUTION_SPRITE_HEIGHT, EVOLUTION_SPRITE_HEIGHT)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path := "%s%s_mk%d.png" % [UnitPanel.ART_DIR, unit.species_id, mark]
	sprite.texture = load(path) if ResourceLoader.exists(path) else null

	if not discovered:
		# Pure black keeps the outline readable — the classic "who's that" silhouette.
		sprite.modulate = Color.BLACK
	elif mark != unit.art_mark:
		sprite.material = desat
	slot.add_child(sprite)

	var caption := Label.new()
	caption.text = MARK_LABELS[mark - 1] if discovered else "???"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_color_override("font_color",
		UIPalette.TEXT if mark == unit.art_mark and discovered else UIPalette.MUTED)
	slot.add_child(caption)

	if species == null:
		pass  # header already shows what we know; the strip still renders from art alone
	return slot


func _is_discovered(mark: int) -> bool:
	# The unit being inspected is on the field right now, so its own mark is by
	# definition seen — even if a stale save said otherwise.
	if mark == unit.art_mark:
		return true
	if _ctx == null or _ctx.codex == null:
		return true
	return _ctx.codex.is_discovered(unit.species_id, mark)


func _stats_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)

	_add_stat(grid, &"core", "STRUCTURE",
		"%d / %d" % [unit.current_structure, unit.max_structure])
	if unit.shield > 0:
		_add_stat(grid, &"shield", "SHIELD", str(unit.shield))
	for entry in STAT_ROWS:
		var key: StringName = entry[0]
		if not unit.base_stats.has(key):
			continue
		# stat() includes live status modifiers — the number the next hit will use.
		_add_stat(grid, Glyph.FOR_STAT.get(key, &"hex"), entry[1], str(unit.stat(key)))
	if unit.has_ultimate():
		_add_stat(grid, &"star", "ULT CHARGE",
			"%d / %d" % [mini(unit.ultimate_charge, _ult_cost), _ult_cost])
	return grid


func _add_stat(grid: GridContainer, icon: StringName, label: String, value: String) -> void:
	var key_cell := HBoxContainer.new()
	key_cell.add_theme_constant_override("separation", 6)
	key_cell.add_child(Glyph.make(icon, 11.0, UIPalette.MUTED))

	var key_label := Label.new()
	key_label.text = label
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", UIPalette.MUTED)
	key_cell.add_child(key_label)
	grid.add_child(key_cell)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_override("font", UIPalette.mono_font())
	value_label.add_theme_font_size_override("font_size", 10)
	grid.add_child(value_label)


func _skill_list() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)

	var skill_ids: Array[StringName] = []
	skill_ids.assign(unit.skills)
	if unit.has_ultimate():
		skill_ids.append(unit.ultimate_skill)

	for sid in skill_ids:
		var skill: SkillDef = _ctx.skills.get(sid) if _ctx != null else null
		if skill == null:
			continue
		column.add_child(_skill_row(skill))
	return column


## One skill row (mockup): the round icon chip on the left — tap it for the full detail
## modal — then the name in bold over its description in a thinner, muted line.
func _skill_row(skill: SkillDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	row.add_child(SkillInfo.round_button(skill, 44.0,
		func() -> void: _open_skill_detail(skill)))

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)

	var name_label := Label.new()
	name_label.text = skill.display_name
	name_label.add_theme_font_override("font", UIPalette.bold_font())
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color",
		UIPalette.AMBER if skill.is_ultimate else UIPalette.TEXT)
	text.add_child(name_label)

	var desc := Label.new()
	desc.text = skill.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", UIPalette.MUTED)
	text.add_child(desc)
	return row


func _open_skill_detail(skill: SkillDef) -> void:
	if _skill_detail != null:
		return
	_skill_detail = SkillDetailModal.new()
	_skill_detail.closed.connect(func() -> void: _skill_detail = null)
	add_child(_skill_detail)
	_skill_detail.open(skill, unit, _ult_cost)


# ---------------------------------------------------------------------------
# Dismissal
# ---------------------------------------------------------------------------

func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss()


func _dismiss() -> void:
	closed.emit()
	queue_free()
