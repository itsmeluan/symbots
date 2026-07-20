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

const MIN_ROW_HEIGHT := 52

var _ctx: ServiceContext = null
var _craft_counter: int = 0

var _alloy_label: Label
var _list: VBoxContainer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	# A craft counter seeded from the roster size keeps crafted ids unique across a session
	# even if the player crafts, releases, and crafts again.
	_craft_counter = ctx.roster.symbots.size()
	_build_layout()
	if _ctx.wallet != null:
		_connect_owned(_ctx.wallet.balance_changed, Callable(self, "_on_balance_changed"))
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var back := Button.new()
	back.text = "< Map"
	back.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	back.pressed.connect(Callable(self, "_on_close_pressed"))
	header.add_child(back)
	var title := Label.new()
	title.text = "Foundry"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	header.add_child(title)
	_alloy_label = Label.new()
	_alloy_label.custom_minimum_size = Vector2(90, 0)
	_alloy_label.clip_text = true
	_alloy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_alloy_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)


func refresh() -> void:
	if _ctx == null:
		return
	_refresh_alloy()
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


func _refresh_alloy() -> void:
	if _ctx.wallet != null:
		_alloy_label.text = "Alloy %d" % _ctx.wallet.alloy


func _on_balance_changed(_currency: StringName, _amount: int) -> void:
	_refresh_alloy()


func _build_row(species: SpeciesDef) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)

	var known := _ctx.blueprints.has_blueprint(species.id)
	var owned := _count_owned(species.id)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Clip a long line rather than letting it widen the row past the screen edge, which
	# would push the Craft button off the right — the same overflow the skill bar hit.
	label.clip_text = true
	if known:
		label.text = "%s%s" % [species.display_name, ("  (owned x%d)" % owned) if owned else ""]
	else:
		# Not a name-and-blank: the row names how to unlock it, which is the whole point of
		# showing a locked species at all.
		label.text = "%s — blueprint not found" % species.display_name
		label.modulate = Color(0.55, 0.55, 0.6)
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(120, MIN_ROW_HEIGHT)
	button.clip_text = true
	var refusal := CraftingServiceScript.can_craft(species.id, _ctx.species,
		_ctx.blueprints, _ctx.wallet)
	button.text = _button_text(species, refusal)
	button.disabled = refusal != CraftingServiceScript.Refusal.OK
	if refusal == CraftingServiceScript.Refusal.OK:
		button.pressed.connect(Callable(self, "_on_craft_pressed").bind(species.id))
	row.add_child(button)
	return row


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
