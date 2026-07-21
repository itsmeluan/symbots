## HomeScreen — where the game opens (Core Design §6).
##
## The player used to land straight on the stage list, which asks "where do you want to fight"
## before showing them what they have. Home answers "who are you and who is with you" first:
## the squad's lead Symbot standing centre, and the player's own badge above it.
##
## Deliberately thin for now. The profile is a placeholder until accounts exist, and the
## Symbot is a portrait rather than a control — everything actionable already has a screen,
## and duplicating it here would give the same action two homes.
class_name HomeScreen
extends Screen

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const ART_DIR := "res://assets/art/symbots/"
const AVATAR_SIZE := 56.0

var _ctx: ServiceContext = null
var _hero: TextureRect
var _name_label: Label
var _sub_label: Label


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.5)
	var content := build_chrome(_ctx, "HOME", &"home", func(d): navigate.emit(d))

	content.add_child(_build_profile())

	# The lead Symbot, standing low so it reads as present in the room rather than pasted on.
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(stage)

	_hero = TextureRect.new()
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_hero)

	refresh()


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
	var squad := _ctx.roster.squad_symbots()
	var lead: SymbotInstance = squad[0] if not squad.is_empty() else null
	if lead == null:
		_name_label.text = "NO SQUAD"
		_sub_label.text = "Field a Symbot in SQUAD"
		_hero.texture = null
		return

	var species: SpeciesDef = _ctx.species.get_species(lead.species_id)
	_name_label.text = (species.display_name if species != null
		else String(lead.species_id)).to_upper()
	_sub_label.text = "MK %s · LV.%d · %d IN SQUAD" % [
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
