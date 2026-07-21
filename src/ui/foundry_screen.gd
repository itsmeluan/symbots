## FoundryScreen — craft new Symbots from learned blueprints (Core Design §5.1).
##
## Portrait list of the whole roster: species whose blueprint you own show a Craft button
## with its Alloy cost; ones you have not found yet are shown greyed with "defeat to learn".
##
## Showing the LOCKED species too, not just the ones you can build, is deliberate — it is
## the collection board. Seeing the silhouette of what you have not caught is the reason to
## keep fighting; a screen that only listed what you already own would teach nothing about
## what is left.
class_name FoundryScreen
extends Screen

const CraftingServiceScript := preload("res://src/core/economy/crafting_service.gd")

signal closed

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const MIN_ROW_HEIGHT := 52

var _ctx: ServiceContext = null
var _craft_counter: int = 0

var _list: VBoxContainer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	# A craft counter seeded from the roster size keeps crafted ids unique across a session
	# even if the player crafts, releases, and crafts again.
	_craft_counter = ctx.roster.symbots.size()
	_build_layout()
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.62)
	var content := build_chrome(_ctx, "FORGE", &"foundry", func(d): navigate.emit(d))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)


func refresh() -> void:
	if _ctx == null:
		return
	refresh_chrome_wallet()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	# Whole roster, so locked species are visible as targets. Known ones sort to the top so
	# the actionable rows are not buried under the ones you cannot build yet.
	var all := _ctx.species.entries.duplicate()
	all.sort_custom(func(a, b):
		var ka := _ctx.blueprints.has_blueprint(a.id)
		var kb := _ctx.blueprints.has_blueprint(b.id)
		if ka != kb:
			return ka
		return String(a.id) < String(b.id))
	for species in all:
		_list.add_child(_build_row(species))


func _build_row(species: SpeciesDef) -> Control:
	var known := _ctx.blueprints.has_blueprint(species.id)
	# Alloy-blue once the recipe is known, quiet while it is still out there to be found.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UIPalette.row(UIPalette.ALLOY if known else UIPalette.LINE, not known))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	panel.add_child(row)

	var owned := _count_owned(species.id)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Clip a long line rather than letting it widen the row past the screen edge, which
	# would push the Craft button off the right — the same overflow the skill bar hit.
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 12)
	if known:
		label.text = "%s\n%s" % [species.display_name.to_upper(),
			("OWNED x%d" % owned) if owned else "Not built yet"]
	else:
		# Not a name-and-blank: the row names how to unlock it, which is the whole point of
		# showing a locked species at all.
		label.text = "%s\nBlueprint not found" % species.display_name.to_upper()
		label.add_theme_color_override("font_color", UIPalette.DISABLED)
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(120, MIN_ROW_HEIGHT)
	button.clip_text = true
	var refusal := CraftingServiceScript.can_craft(species.id, _ctx.species,
		_ctx.blueprints, _ctx.wallet)
	button.text = _button_text(species, refusal)
	button.disabled = refusal != CraftingServiceScript.Refusal.OK
	if refusal == CraftingServiceScript.Refusal.OK:
		button.theme_type_variation = &"Primary"
		button.pressed.connect(Callable(self, "_on_craft_pressed").bind(species.id))
	button.add_theme_font_size_override("font_size", 11)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = Vector2(104, 34)
	row.add_child(button)
	return panel


## The button says WHY it cannot be pressed, because "locked" and "cannot afford" mean
## different next actions — find the boss versus grind Alloy.
func _button_text(species: SpeciesDef, refusal: int) -> String:
	match refusal:
		CraftingServiceScript.Refusal.BLUEPRINT_LOCKED:
			return "Locked"
		CraftingServiceScript.Refusal.CANNOT_AFFORD:
			return "%d Alloy" % species.craft_alloy_cost
	return "Craft (%d)" % species.craft_alloy_cost


func _count_owned(species_id: StringName) -> int:
	var n := 0
	for s in _ctx.roster.symbots:
		if s.species_id == species_id:
			n += 1
	return n


func _on_craft_pressed(species_id: StringName) -> void:
	_craft_counter += 1
	CraftingServiceScript.craft(species_id, _ctx.species, _ctx.blueprints,
		_ctx.wallet, _ctx.roster, _craft_counter)
	refresh()


func _on_close_pressed() -> void:
	closed.emit()
