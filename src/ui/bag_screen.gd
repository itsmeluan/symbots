## BagScreen — everything the player owns that is not a Symbot (Core Design §5, §6.2).
##
## Three things used to be invisible: Overclock Cores (spent in the Workshop), socket
## components (spent in the skill tree), and learned blueprints (spent in the Forge). Each was
## earned somewhere and consumed somewhere else, with no screen in between where the player
## could see what they were holding — so a drop felt like nothing and a plan was impossible.
##
## Read-only on purpose. Items are spent where they are used; the Bag is the ledger, not a
## second place to act, which keeps one action in one place.
class_name BagScreen
extends Screen

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const ROW_HEIGHT := 46

var _ctx: ServiceContext = null
var _list: VBoxContainer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.62)
	var content := build_chrome(_ctx, "BAG", &"bag", func(d): navigate.emit(d))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	if _ctx.inventory_items != null:
		_connect_owned(_ctx.inventory_items.inventory_changed, Callable(self, "_on_inventory_changed"))
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _on_inventory_changed() -> void:
	refresh()


## Full redraw. A handful of rows — an incremental update would be complexity with no payoff,
## and a rebuild cannot leave a stale count on screen.
func refresh() -> void:
	if _ctx == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var empty := true
	empty = _add_key_items() == 0 and empty
	empty = _add_components() == 0 and empty
	empty = _add_blueprints() == 0 and empty
	if empty:
		_list.add_child(_hint_label(
			"Nothing yet. Clear a dungeon for an Overclock Core, or a stage for components."))


func _add_key_items() -> int:
	if _ctx.key_items == null:
		return 0
	var rows := 0
	for id in KeyItems.ids():
		var count: int = _ctx.key_items.count(id)
		if count <= 0:
			continue
		if rows == 0:
			_list.add_child(_section("KEY ITEMS"))
		_list.add_child(_row(KeyItems.display_name(id), KeyItems.description(id),
			count, UIPalette.AMBER))
		rows += 1
	return rows


func _add_components() -> int:
	if _ctx.inventory_items == null or _ctx.item_catalog == null:
		return 0
	var rows := 0
	for id in _ctx.inventory_items.owned_ids():
		var item: InstallItemDef = _ctx.item_catalog.get_item(id)
		if item == null:
			continue
		if rows == 0:
			_list.add_child(_section("COMPONENTS"))
		_list.add_child(_row(item.display_name, item.description,
			_ctx.inventory_items.count(id), UIPalette.CYAN))
		rows += 1
	return rows


func _add_blueprints() -> int:
	if _ctx.blueprints == null or _ctx.species == null:
		return 0
	var rows := 0
	for id in _ctx.blueprints.known_ids():
		var species: SpeciesDef = _ctx.species.get_species(id)
		if species == null:
			continue
		if rows == 0:
			_list.add_child(_section("BLUEPRINTS"))
		_list.add_child(_row(species.display_name, "Craftable in the Forge.", 0, UIPalette.ALLOY))
		rows += 1
	return rows


func _section(title: String) -> Control:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UIPalette.MUTED)
	label.custom_minimum_size = Vector2(0, 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


## One owned thing: name, what it is for, and how many. [param count] of 0 hides the tally —
## a blueprint is known or not, never "×2".
func _row(item_name: String, description: String, count: int, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UIPalette.PANEL, 0.82)
	box.border_width_left = 2
	box.border_color = accent
	box.set_corner_radius_all(3)
	box.set_content_margin(SIDE_LEFT, 10)
	box.set_content_margin(SIDE_RIGHT, 10)
	box.set_content_margin(SIDE_TOP, 6)
	box.set_content_margin(SIDE_BOTTOM, 6)
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", UIPalette.TEXT)
	name_label.clip_text = true
	text.add_child(name_label)

	var desc := Label.new()
	desc.theme_type_variation = &"Light"
	desc.text = description
	desc.add_theme_font_size_override("font_size", 9)
	desc.add_theme_color_override("font_color", UIPalette.MUTED)
	desc.clip_text = true
	text.add_child(desc)

	if count > 0:
		var tally := Label.new()
		tally.text = "x%d" % count
		tally.add_theme_font_size_override("font_size", 14)
		tally.add_theme_color_override("font_color", accent)
		tally.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tally)
	return panel


func _hint_label(text: String) -> Control:
	var label := Label.new()
	label.theme_type_variation = &"Light"
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UIPalette.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 80)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
