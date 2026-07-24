## BagScreen — everything the player owns that is not a Symbot (Core Design §5, §6.2).
##
## Three things used to be invisible: Chipsets (spent in the Workshop), socket
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

const ROW_HEIGHT := 56

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
	UIPalette.thin_scrollbar(scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_right", 8)
	scroll.add_child(pad)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	pad.add_child(_list)

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
			"Nothing yet. Clear a dungeon for a Chipset, or a stage for components."))


func _add_key_items() -> int:
	if _ctx.key_items == null:
		return 0
	var grid: GridContainer = null
	var rows := 0
	for id in KeyItems.ids():
		var count: int = _ctx.key_items.count(id)
		if count <= 0:
			continue
		if grid == null:
			_list.add_child(_section("KEY ITEMS"))
			grid = _grid()
			_list.add_child(grid)
		grid.add_child(_card(KeyItems.display_name(id), KeyItems.description(id),
			count, UIPalette.AMBER, &"core", null))
		rows += 1
	return rows


func _add_components() -> int:
	if _ctx.inventory_items == null or _ctx.item_catalog == null:
		return 0
	var grid: GridContainer = null
	var rows := 0
	for id in _ctx.inventory_items.owned_ids():
		var item: InstallItemDef = _ctx.item_catalog.get_item(id)
		if item == null:
			continue
		if grid == null:
			_list.add_child(_section("COMPONENTS"))
			grid = _grid()
			_list.add_child(grid)
		grid.add_child(_card(item.display_name, item.description,
			_ctx.inventory_items.count(id), UIPalette.CYAN, _component_glyph(id), null))
		rows += 1
	return rows


func _add_blueprints() -> int:
	if _ctx.blueprints == null or _ctx.species == null:
		return 0
	var grid: GridContainer = null
	var rows := 0
	for id in _ctx.blueprints.known_ids():
		var species: SpeciesDef = _ctx.species.get_species(id)
		if species == null:
			continue
		if grid == null:
			_list.add_child(_section("BLUEPRINTS"))
			grid = _grid()
			_list.add_child(grid)
		grid.add_child(_card(species.display_name, "Craftable in the Forge.", 0,
			UIPalette.ALLOY, &"hex", UnitPanel.art_texture(id, 1)))
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


## Two small cards per row — items are inventory, not heroes, so their cards are half
## the size of a Symbot's.
func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	return grid


## Which glyph a component wears, from its id — a capacitor, a heat sink, a processor, a
## RAM stick and a servo each read as their own object across the whole inventory.
func _component_glyph(id: StringName) -> StringName:
	var key := String(id)
	if key.contains("capacitor"):
		return &"bolt"
	if key.contains("heat_sink"):
		return &"fins"
	if key.contains("processor"):
		return &"chip"
	if key.contains("ram"):
		return &"ram"
	if key.contains("servo"):
		return &"gear"
	return &"hex"


## One owned thing as a SMALL card: icon chip on the left, name + count beside it. The
## description lives in the tooltip — a small card earns its size by not repeating prose.
## [param sprite] (blueprints) replaces the glyph with the creature's own face.
func _card(item_name: String, description: String, count: int, accent: Color,
		icon: StringName, sprite: Texture2D) -> Control:
	var panel := Button.new()
	panel.custom_minimum_size = Vector2(0, 48)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = "%s\n%s" % [item_name, description]
	panel.add_theme_stylebox_override("normal", UIPalette.chunky(Color("18212b")))
	panel.add_theme_stylebox_override("hover", UIPalette.chunky(Color("18212b")))
	panel.add_theme_stylebox_override("pressed", UIPalette.chunky(Color("18212b"), "pressed"))
	panel.add_theme_stylebox_override("focus", UIPalette.empty())
	panel.pressed.connect(_open_item_details.bind(item_name, description, count, accent,
		icon, sprite))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 7
	row.offset_right = -7
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	# The uniform icon chip: accent lives on the CHIP fill, the glyph stays clean.
	var well := PanelContainer.new()
	var well_box := StyleBoxFlat.new()
	well_box.bg_color = Color(accent, 0.16)
	well_box.set_corner_radius_all(6)
	well_box.set_border_width_all(1)
	well_box.border_color = Color(accent, 0.35)
	well_box.set_content_margin_all(4)
	well.add_theme_stylebox_override("panel", well_box)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.custom_minimum_size = Vector2(28, 28)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sprite != null:
		var face := TextureRect.new()
		face.texture = sprite
		face.custom_minimum_size = Vector2(20, 20)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(face)
	else:
		well.add_child(Glyph.make(icon, 18.0, accent))
	row.add_child(well)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_font_override("font", UIPalette.display_font())
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", UIPalette.TEXT)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	if count > 0:
		var tally := Label.new()
		tally.text = "×%d" % count
		tally.add_theme_font_override("font", UIPalette.bold_font())
		tally.add_theme_font_size_override("font_size", 12)
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


## The item dossier: what this thing IS and where it is spent — the bag stays read-only,
## but no longer mute. Same overlay grammar as the Symbot dossiers.
func _open_item_details(item_name: String, description: String, count: int,
		accent: Color, icon: StringName, sprite: Texture2D) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(UIPalette.INK, 0.78)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free())
	overlay.add_child(scrim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIPalette.chunky(UIPalette.OVERLAY))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(300, 0)
	overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)

	var well := PanelContainer.new()
	var well_box := StyleBoxFlat.new()
	well_box.bg_color = Color(accent, 0.16)
	well_box.set_corner_radius_all(8)
	well_box.set_border_width_all(1)
	well_box.border_color = Color(accent, 0.4)
	well_box.set_content_margin_all(8)
	well.add_theme_stylebox_override("panel", well_box)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if sprite != null:
		var face := TextureRect.new()
		face.texture = sprite
		face.custom_minimum_size = Vector2(30, 30)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		well.add_child(face)
	else:
		well.add_child(Glyph.make(icon, 24.0, accent))
	head.add_child(well)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation", 1)
	head.add_child(title_box)
	var title := Label.new()
	title.text = item_name
	title.add_theme_font_override("font", UIPalette.bold_font())
	title.add_theme_font_size_override("font_size", 16)
	title.clip_text = true
	title_box.add_child(title)
	if count > 0:
		var owned := Label.new()
		owned.text = "Owned ×%d" % count
		owned.add_theme_font_size_override("font_size", 11)
		owned.add_theme_color_override("font_color", accent)
		title_box.add_child(owned)

	var body := Label.new()
	body.text = description
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", UIPalette.MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.pressed.connect(overlay.queue_free)
	column.add_child(close_button)
