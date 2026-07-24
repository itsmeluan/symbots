## HomeScreen — the hub the game opens on (Core Design §6; nav IA 2026-07-23).
##
## Answers "who are you and who is with you" first: the squad's lead Symbot standing in the
## room, the player's badge above it. It is also the HUB — the four secondary destinations
## (Forge, Tree, Send, Bag) are facility buttons here rather than footer tabs, keeping the
## dock to the four primary loops (Home/Squad/Workshop/Map). A big BATTLE button is the way
## into the fight.
class_name HomeScreen
extends Screen

## Bottom-dock AND facility-button navigation; the game root routes it.
signal navigate(dest: StringName)

const ART_DIR := "res://assets/art/symbots/"
const AVATAR_SIZE := 56.0

## The hub's facility buttons: [dest, label, glyph].
const FACILITIES: Array = [
	[&"foundry", "FORGE", &"anvil"],
	[&"tree", "TREE", &"branch"],
	[&"expeditions", "SEND", &"send"],
	[&"bag", "BAG", &"bag"],
]

var _ctx: ServiceContext = null
var _hero: TextureRect
var _name_label: Label
var _sub_label: Label


## The player's name until accounts exist. One obvious placeholder, easy to grep out.
const PLAYER_NAME := "OPERATOR"
const PLAYER_SUB := "Scrapyard licence 001"

var _hero_name: Label
var _hero_sub: Label


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.5)
	var content := build_chrome(_ctx, "HOME", &"home", func(d): navigate.emit(d))

	content.add_child(_build_profile())

	# The room: hero standing low, its nameplate floating just above it, and the facility
	# rails hugging the side edges — two doors per side.
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stage)

	_hero = TextureRect.new()
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_hero)

	stage.add_child(_build_hero_nameplate())
	stage.add_child(_build_side_rail([FACILITIES[0], FACILITIES[1]], true))
	stage.add_child(_build_side_rail([FACILITIES[2], FACILITIES[3]], false))

	content.add_child(_build_battle_cta())

	refresh()


## The lead Symbot's name and credentials, floating a small distance above its head.
func _build_hero_nameplate() -> Control:
	var plate := VBoxContainer.new()
	plate.add_theme_constant_override("separation", 0)
	plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Above the tallest hero band (MK III zoom) plus a small breath of air.
	plate.offset_bottom = -(HERO_BAND * MARK_ZOOM[MARK_ZOOM.size() - 1] + 10.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hero_name = Label.new()
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name.add_theme_font_override("font", UIPalette.bold_font())
	_hero_name.add_theme_font_size_override("font_size", 16)
	_hero_name.add_theme_color_override("font_color", UIPalette.AMBER)
	_hero_name.add_theme_color_override("font_outline_color", UIPalette.INK)
	_hero_name.add_theme_constant_override("outline_size", 5)
	plate.add_child(_hero_name)

	_hero_sub = Label.new()
	_hero_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_sub.add_theme_font_size_override("font_size", 10)
	_hero_sub.add_theme_color_override("font_color", UIPalette.CYAN)
	_hero_sub.add_theme_color_override("font_outline_color", UIPalette.INK)
	_hero_sub.add_theme_constant_override("outline_size", 4)
	plate.add_child(_hero_sub)
	return plate


## One vertical rail of two square facility doors, hugging a side edge at mid height.
func _build_side_rail(facilities: Array, left: bool) -> Control:
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 10)
	if left:
		rail.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		rail.grow_horizontal = Control.GROW_DIRECTION_END
	else:
		rail.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		rail.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rail.grow_vertical = Control.GROW_DIRECTION_BOTH
	for facility in facilities:
		rail.add_child(_build_facility(facility[0], facility[1], facility[2]))
	return rail


## The primary call to action: sized to its text, hovering just off the dock.
func _build_battle_cta() -> Control:
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_bottom", 10)

	var button := Button.new()
	button.text = "▶   BATTLE"
	button.theme_type_variation = &"Primary"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 19)
	# Room around the text without stretching bar-wide: the chunky margins plus our own.
	var padded := UIPalette.chunky(UIPalette.AMBER)
	padded.content_margin_left = 34
	padded.content_margin_right = 34
	button.add_theme_stylebox_override("normal", padded)
	var pressed := UIPalette.chunky(UIPalette.AMBER, "pressed")
	pressed.content_margin_left = 34
	pressed.content_margin_right = 34
	button.add_theme_stylebox_override("hover", padded)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_theme_color_override("font_color", UIPalette.INK)
	button.add_theme_color_override("font_pressed_color", UIPalette.INK)
	button.add_theme_color_override("font_hover_color", UIPalette.INK)
	button.add_child(UIPalette.gloss())
	_connect_owned(button.pressed, func() -> void: navigate.emit(&"map"))
	footer.add_child(button)
	return footer


## One square facility door: the glyph in a framed face, its name beneath — icon-first,
## because a door is recognised before it is read.
func _build_facility(dest: StringName, label: String, glyph_kind: StringName) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(58, 58)
	button.add_theme_stylebox_override("normal", UIPalette.chunky(Color("1b2530")))
	button.add_theme_stylebox_override("hover", UIPalette.chunky(Color("1b2530"), "selected"))
	button.add_theme_stylebox_override("pressed", UIPalette.chunky(Color("1b2530"), "pressed"))
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_child(UIPalette.gloss(0.07))
	_connect_owned(button.pressed, func() -> void: navigate.emit(dest))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 7
	column.offset_bottom = -9
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var icon_holder := CenterContainer.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(Glyph.make(glyph_kind, 20.0, UIPalette.CYAN))
	column.add_child(icon_holder)

	var name_label := Label.new()
	name_label.text = label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIPalette.display_font())
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_color", UIPalette.MUTED)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	return button


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


## The player's badge: a round placeholder until accounts land, with the lead Symbot's name
## beside it so the row says who is fielded without a second trip to Squad.
func _build_profile() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UIPalette.PANEL_2, 0.92)
	box.set_corner_radius_all(int(AVATAR_SIZE * 0.5))
	box.border_color = UIPalette.CYAN
	box.set_border_width_all(2)
	avatar.add_theme_stylebox_override("panel", box)
	row.add_child(avatar)

	var initial := Label.new()
	initial.theme_type_variation = &"Heading"
	initial.text = "P"  # placeholder until there is an account to draw from
	initial.add_theme_font_size_override("font_size", 22)
	initial.add_theme_color_override("font_color", UIPalette.CYAN)
	initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.add_child(initial)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)

	_name_label = Label.new()
	_name_label.theme_type_variation = &"Heading"
	_name_label.add_theme_font_size_override("font_size", 17)
	_name_label.add_theme_color_override("font_color", UIPalette.AMBER)
	_name_label.clip_text = true
	text.add_child(_name_label)

	_sub_label = Label.new()
	_sub_label.theme_type_variation = &"Light"
	_sub_label.add_theme_font_size_override("font_size", 11)
	_sub_label.add_theme_color_override("font_color", UIPalette.CYAN)
	text.add_child(_sub_label)
	return row


func refresh() -> void:
	if _ctx == null:
		return
	# The badge is the PLAYER's — the hero's own plate floats above the hero itself.
	_name_label.text = PLAYER_NAME
	_sub_label.text = PLAYER_SUB

	var squad := _ctx.roster.squad_symbots()
	var lead: SymbotInstance = squad[0] if not squad.is_empty() else null
	if lead == null:
		_hero_name.text = "NO SQUAD"
		_hero_sub.text = "Field a Symbot in SYMBOTS"
		_hero.texture = null
		return

	var species: SpeciesDef = _ctx.species.get_species(lead.species_id)
	_hero_name.text = (species.display_name if species != null
		else String(lead.species_id)).to_upper()
	_hero_sub.text = "MK %s · LV.%d · %d IN SQUAD" % [
		_roman(lead.mark), lead.level, squad.size()]
	var path := "%s%s_mk%d.png" % [ART_DIR, lead.species_id, clampi(lead.mark, 1, 3)]
	_hero.texture = load(path) if ResourceLoader.exists(path) else null
	# Same band as the Workshop, so the same Symbot is the same size on both screens.
	fit_hero(_hero, lead.mark)


func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(n)
