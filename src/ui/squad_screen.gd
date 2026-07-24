## SquadScreen — choose the four who fight (Core Design §2.1, §3.1).
##
## Four slots on top, the bench below. Tap a slot to select it, tap a Symbot to put them
## in. The screen shows each Symbot's ROLE prominently, because squad composition is the
## strategic layer that replaced build-from-parts in v1 — a player who cannot see at a
## glance that they have fielded three DPS and no healer will field it.
class_name SquadScreen
extends Screen

const SpeciesDefScript := preload("res://src/core/species/species_def.gd")
const UnitPanelScript := preload("res://src/ui/battle/unit_panel.gd")
const UnitInfoModalScript := preload("res://src/ui/battle/unit_info_modal.gd")
const UnitBuilderScript := preload("res://src/core/battle_v1/unit_builder.gd")

signal closed

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const MIN_ROW_HEIGHT := 52

## Bench card geometry: three across at the 360 base width, tall enough for name over
## sprite over caption.
const CARD_COLUMNS := 3
const CARD_HEIGHT := 128
const SLOT_HEIGHT := 86
const ROLE_NAMES: Dictionary = {
	SpeciesDefScript.Role.DPS: "DPS",
	SpeciesDefScript.Role.TANK: "TANK",
	SpeciesDefScript.Role.HEALER: "HEAL",
	SpeciesDefScript.Role.SUPPORT: "SUPP",
}

var _ctx: ServiceContext = null

## Which slot the next bench tap fills. -1 means none is armed.
var _armed_slot: int = -1

var _slot_row: HBoxContainer
var _bench: GridContainer
var _warning: Label

## The open detail modal, so a second tap re-uses rather than stacks.
var _detail_modal: UnitInfoModal = null


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_build_layout()
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.62)
	var content := build_chrome(_ctx, "SQUAD", &"squad", func(d): navigate.emit(d))

	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 6)
	_slot_row.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
	content.add_child(_slot_row)

	_warning = Label.new()
	_warning.add_theme_font_size_override("font_size", 9)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_warning)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_thin_scrollbar(scroll)

	# A gutter around the grid: top so the first row is not clipped against the viewport
	# edge, right so the thin scrollbar rides the screen edge OFF the cards rather than
	# over them.
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_right", 10)
	scroll.add_child(pad)

	_bench = GridContainer.new()
	_bench.columns = CARD_COLUMNS
	_bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bench.add_theme_constant_override("h_separation", 6)
	_bench.add_theme_constant_override("v_separation", 6)
	pad.add_child(_bench)


## A 4px scrollbar with a rounded grabber, riding the screen edge — matches the workshop
## stats drawer, so scrolling reads the same everywhere.
func _thin_scrollbar(scroll: ScrollContainer) -> void:
	var vsb := scroll.get_v_scroll_bar()
	vsb.custom_minimum_size = Vector2(4, 0)
	var grab := StyleBoxFlat.new()
	grab.bg_color = UIPalette.LINE
	grab.set_corner_radius_all(2)
	vsb.add_theme_stylebox_override("grabber", grab)
	vsb.add_theme_stylebox_override("grabber_highlight", grab)
	vsb.add_theme_stylebox_override("grabber_pressed", grab)
	vsb.add_theme_stylebox_override("scroll", UIPalette.empty())


func refresh() -> void:
	if _ctx == null:
		return
	_rebuild_slots()
	_rebuild_bench()
	_refresh_warning()


func _rebuild_slots() -> void:
	_clear(_slot_row)
	for slot in PlayerRoster.SQUAD_SIZE:
		_slot_row.add_child(_build_slot(slot))


## One squad slot: the fielded Symbot standing in a framed bay (sprite over name), or an
## "empty" bay inviting a pick. The armed slot glows cyan — same accent grammar as the
## battle's selected card.
func _build_slot(slot: int) -> Button:
	var symbot := _slot_instance(slot)
	var armed := _armed_slot == slot
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, SLOT_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_pressed = armed
	var glow := Color(UIPalette.CYAN, 0.55) if armed else Color.TRANSPARENT
	var face := Color("1b242f") if symbot != null else Color("141b23")
	var state := "selected" if armed else "normal"
	button.add_theme_stylebox_override("normal", UIPalette.chunky(face, state, glow))
	button.add_theme_stylebox_override("hover", UIPalette.chunky(face, state, glow))
	button.add_theme_stylebox_override("pressed", UIPalette.chunky(face, "selected", glow))
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.pressed.connect(Callable(self, "_on_slot_pressed").bind(slot))

	if symbot == null:
		button.text = "empty"
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_color", UIPalette.DISABLED)
		return button

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 4
	column.offset_right = -4
	column.offset_top = 4
	column.offset_bottom = -8
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	column.add_child(_sprite_view(symbot, 42.0))

	var name_label := Label.new()
	name_label.text = _display_name_of(symbot)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIPalette.display_font())
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	return button


func _slot_instance(slot: int) -> SymbotInstance:
	var id: StringName = _ctx.roster.squad[slot]
	return _ctx.roster.get_symbot(id) if id != &"" else null


func _sprite_view(symbot: SymbotInstance, height: float) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = UnitPanelScript.art_texture(symbot.species_id, symbot.mark)
	sprite.custom_minimum_size = Vector2(0, height)
	sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite


func _display_name_of(symbot: SymbotInstance) -> String:
	var species := _ctx.species.get_species(symbot.species_id)
	return species.display_name if species != null else String(symbot.species_id)


func _slot_text(slot: int) -> String:
	var id: StringName = _ctx.roster.squad[slot]
	if id == &"":
		return "empty"
	var symbot := _ctx.roster.get_symbot(id)
	var species: SpeciesDef = _ctx.species.get_species(symbot.species_id) \
		if symbot != null else null
	if species == null:
		return "?"
	return "%s\n%s" % [species.display_name, ROLE_NAMES.get(species.role, "")]


func _rebuild_bench() -> void:
	_clear(_bench)
	for symbot in _ctx.roster.symbots:
		_bench.add_child(_build_bench_row(symbot))


## One roster card: the name over the creature over its credentials, framed in the
## chunky card language. Fielded cards glow cyan; benched ones sit quiet. The whole
## summary also lives in tooltip_text — hover help on desktop, and the one string tests
## read without caring about the card's internal layout.
func _build_bench_row(symbot: SymbotInstance) -> Control:
	var species: SpeciesDef = _ctx.species.get_species(symbot.species_id)
	var fielded := _ctx.roster.squad.has(symbot.instance_id)
	var caption := "%s · MK %s · LV.%d" % [
		ROLE_NAMES.get(species.role, "—") if species != null else "—",
		_roman(symbot.mark), symbot.level]

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "%s\n%s%s" % [_display_name_of(symbot).to_upper(), caption,
		"   ·   FIELDED" if fielded else ""]
	# Fielded reads from a SOLID amber frame — no soft halo. A benched card is plain.
	var face := Color("1b242f") if fielded else Color("161e27")
	var rim := UIPalette.AMBER if fielded else Color.TRANSPARENT
	button.add_theme_stylebox_override("normal",
		UIPalette.chunky(face, "normal", Color.TRANSPARENT, rim))
	button.add_theme_stylebox_override("hover",
		UIPalette.chunky(face, "normal", Color.TRANSPARENT, rim))
	button.add_theme_stylebox_override("pressed", UIPalette.chunky(face, "pressed"))
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_child(UIPalette.gloss(0.06))
	# Enabled even when already fielded: tapping a fielded Symbot into another slot is how
	# the player reorders, and the roster moves rather than duplicates.
	button.pressed.connect(Callable(self, "_on_bench_pressed").bind(symbot))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Inset off the frame, and clear the thicker bottom lip so the FIELDED badge is never
	# clipped by the border.
	column.offset_left = 5
	column.offset_right = -5
	column.offset_top = 5
	column.offset_bottom = -8
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var name_label := Label.new()
	name_label.text = _display_name_of(symbot)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIPalette.bold_font())
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)

	column.add_child(_sprite_view(symbot, 56.0))

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 8)
	caption_label.add_theme_color_override("font_color", UIPalette.MUTED)
	caption_label.clip_text = true
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_label)

	var badge := Label.new()
	badge.text = "FIELDED" if fielded else " "
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", UIPalette.AMBER)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(badge)
	return button


func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(n)


## Warn about a composition that will not work, without blocking it. The design does not
## forbid four DPS — it just makes them lose — so this informs rather than forbids.
func _refresh_warning() -> void:
	var roles: Dictionary = {}
	for symbot in _ctx.roster.squad_symbots():
		var species: SpeciesDef = _ctx.species.get_species(symbot.species_id)
		if species != null:
			roles[species.role] = true

	if _ctx.roster.squad_size() < PlayerRoster.SQUAD_SIZE:
		_warning.text = "Squad is short-handed (%d of %d)" % [
			_ctx.roster.squad_size(), PlayerRoster.SQUAD_SIZE]
	elif not roles.has(SpeciesDefScript.Role.TANK):
		# Without a tank, nothing holds the enemy taunt line and the back row takes
		# everything (§3.3).
		_warning.text = "No tank — your back row will take every hit"
	elif not roles.has(SpeciesDefScript.Role.HEALER):
		_warning.text = "No healer — damage taken is permanent for the run"
	else:
		_warning.text = ""


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_slot_pressed(slot: int) -> void:
	# Tapping the armed slot again clears it — that is how a player empties a slot without
	# needing a separate "remove" control.
	if _armed_slot == slot:
		_ctx.roster.clear_squad_slot(slot)
		_armed_slot = -1
	else:
		_armed_slot = slot
	refresh()


## Same grammar as the battle: an ARMED slot makes the tap an assignment; an idle tap is
## an inspection. Fielding stays one tap away — the detail modal carries ADD TO SQUAD.
func _on_bench_pressed(symbot: SymbotInstance) -> void:
	if _armed_slot >= 0:
		_ctx.roster.set_squad_slot(_armed_slot, symbot.instance_id)
		_armed_slot = -1
		refresh()
		return
	_open_details(symbot)


## The full dossier — the battle's unit modal, fed a unit built by the REAL pipeline
## (parts, tree, items), so the stats here are exactly what the next fight will field.
func _open_details(symbot: SymbotInstance) -> void:
	if _detail_modal != null:
		return
	var species := _ctx.species.get_species(symbot.species_id)
	if species == null:
		return
	var unit := UnitBuilderScript.build(symbot, species, _ctx.tree, _ctx.skills,
		BattleUnit.Side.PLAYER, 0, _ctx.items)
	if unit == null:
		return
	var ult_cost := 100
	var ult: SkillDef = _ctx.skills.get(unit.ultimate_skill)
	if ult != null:
		ult_cost = ult.charge_cost

	_detail_modal = UnitInfoModalScript.new()
	_detail_modal.closed.connect(func() -> void: _detail_modal = null)
	add_child(_detail_modal)
	_detail_modal.open(unit, _ctx, ult_cost)

	if not _ctx.roster.squad.has(symbot.instance_id) and _first_empty_slot() >= 0:
		_detail_modal.add_action("ADD TO SQUAD", func() -> void:
			var slot := _first_empty_slot()
			if slot >= 0:
				_ctx.roster.set_squad_slot(slot, symbot.instance_id)
			refresh())


func _first_empty_slot() -> int:
	for i in PlayerRoster.SQUAD_SIZE:
		if _ctx.roster.squad[i] == &"":
			return i
	return -1


func _on_close_pressed() -> void:
	closed.emit()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
