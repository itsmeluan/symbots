## SkillTreeScreen — spend points on the shared tree (Core Design §4, ADR-0008).
##
## The graph fills the screen; a detail panel along the bottom names the tapped node and
## either allocates it or says why it cannot. Saying WHY is the point: "you cannot reach
## this yet" teaches the tree's shape, while a dead button teaches nothing and reads as a
## bug.
##
## Owns no rules — every question goes to [TreeAllocator].
class_name SkillTreeScreen
extends Screen

const SkillTreeViewScript := preload("res://src/ui/tree/skill_tree_view.gd")
const SkillNodeDefScript := preload("res://src/core/tree/skill_node_def.gd")
const ItemFittingScript := preload("res://src/core/tree/item_fitting.gd")

signal closed

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

## The dossier's WORKSHOP action: open the workshop already pointed at this Symbot.
signal workshop_for(symbot: SymbotInstance)

const MIN_BUTTON_HEIGHT := 44

var _ctx: ServiceContext = null
var _selected_symbot: SymbotInstance = null
var _selected_node: StringName = &""

var _view: SkillTreeView
var _points_label: Label
var _roster_strip: SymbotCarousel
var _inspector: PanelContainer
var _node_title: Label
var _node_detail: Label
var _allocate_button: Button
var _respec_button: Button

## Fit / unfit controls, shown only when the selected node is a socket.
var _fit_row: HFlowContainer

var _roster_drawer: RosterDrawer
var _detail_modal: UnitInfoModal = null


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_build_layout()
	var squad := _ctx.roster.squad_symbots()
	_selected_symbot = squad[0] if not squad.is_empty() else null
	_view.bind(_ctx.tree, _entry_of(_selected_symbot))
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null
	_selected_symbot = null


func _build_layout() -> void:
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.62)
	var content := build_chrome(_ctx, "TREE", &"tree", func(d): navigate.emit(d))

	_view = SkillTreeViewScript.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.node_tapped.connect(Callable(self, "_on_node_tapped"))
	_view.hero_tapped.connect(Callable(self, "_on_hero_tapped"))
	content.add_child(_view)

	# The roster is the workshop's carousel: bare sprites, no chrome, swipe up for the
	# full drawer. An amber pip marks who still has points to spend.
	_roster_strip = SymbotCarousel.new()
	_roster_strip.custom_minimum_size = Vector2(0, 64)
	_roster_strip.focused_changed.connect(_on_carousel_focus)
	_roster_strip.dragged_up.connect(func() -> void: _roster_drawer.open_with(_ctx))
	var strip_margin := MarginContainer.new()
	strip_margin.add_theme_constant_override("margin_bottom", 6)
	strip_margin.add_child(_roster_strip)
	content.add_child(strip_margin)

	# The inspector FLOATS over the graph, anchored to the top — opening a node must
	# never reflow the tree behind it.
	var insets := _safe_insets()
	_inspector = PanelContainer.new()
	_inspector.add_theme_stylebox_override("panel", UIPalette.chunky(UIPalette.SURFACE))
	_inspector.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_inspector.offset_left = 10
	_inspector.offset_right = -10
	_inspector.offset_top = insets.x + 56
	_inspector.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_inspector)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_inspector.add_child(box)

	_node_title = Label.new()
	_node_title.add_theme_font_override("font", UIPalette.bold_font())
	_node_title.add_theme_font_size_override("font_size", 16)
	_node_title.clip_text = true
	box.add_child(_node_title)

	_node_detail = Label.new()
	_node_detail.add_theme_font_size_override("font_size", 11)
	_node_detail.add_theme_color_override("font_color", UIPalette.MUTED)
	_node_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_node_detail)

	_allocate_button = Button.new()
	_allocate_button.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	_allocate_button.add_theme_font_size_override("font_size", 13)
	_allocate_button.add_child(UIPalette.gloss())
	_allocate_button.pressed.connect(Callable(self, "_on_allocate_pressed"))
	box.add_child(_allocate_button)

	# Fit options WRAP instead of running off the screen edge.
	_fit_row = HFlowContainer.new()
	_fit_row.add_theme_constant_override("h_separation", 6)
	_fit_row.add_theme_constant_override("v_separation", 6)
	box.add_child(_fit_row)

	_respec_button = Button.new()
	_respec_button.custom_minimum_size = Vector2(0, 32)
	_respec_button.add_theme_font_size_override("font_size", 11)
	_respec_button.pressed.connect(Callable(self, "_on_respec_pressed"))
	box.add_child(_respec_button)

	_roster_drawer = RosterDrawer.new()
	_roster_drawer.card_pressed.connect(_on_roster_card_pressed)
	add_child(_roster_drawer)


func _on_carousel_focus(index: int) -> void:
	if index < 0 or index >= _ctx.roster.symbots.size():
		return
	if _ctx.roster.symbots[index] == _selected_symbot:
		return
	_on_symbot_selected(_ctx.roster.symbots[index])


## Point the tree at [param symbot] — the dossier TREE actions land here.
func focus_on(symbot: SymbotInstance) -> void:
	if symbot == null:
		return
	_on_symbot_selected(symbot)


## Tapping the hero sprite at the graph's centre opens the dossier for the Symbot the tree
## is currently pointed at — the same modal the roster cards open.
func _on_hero_tapped() -> void:
	if _selected_symbot != null:
		_on_roster_card_pressed(_selected_symbot)


func _on_roster_card_pressed(symbot: SymbotInstance) -> void:
	if _detail_modal != null:
		return
	_detail_modal = UnitInfoModal.new()
	_detail_modal.closed.connect(func() -> void: _detail_modal = null)
	add_child(_detail_modal)
	if not _detail_modal.open_instance(symbot, _ctx):
		_detail_modal.queue_free()
		_detail_modal = null
		return
	_detail_modal.add_nav_actions(
		func() -> void: workshop_for.emit(symbot),
		func() -> void:
			focus_on(symbot)
			_roster_drawer.close())


func refresh() -> void:
	if _ctx == null:
		return
	_rebuild_roster_strip()
	_refresh_points()
	_refresh_view()
	_refresh_detail()
	_refresh_fitting()
	_refresh_respec()


func _rebuild_roster_strip() -> void:
	var textures: Array = []
	var badges: Array = []
	for symbot in _ctx.roster.symbots:
		textures.append(UnitPanel.art_texture(symbot.species_id, symbot.mark))
		badges.append(TreeAllocator.unspent_points(symbot) > 0)
	_roster_strip.set_items(textures, true)
	_roster_strip.set_badges(badges)
	var index := _ctx.roster.symbots.find(_selected_symbot)
	if index >= 0 and _roster_strip.focused_index() != index:
		_roster_strip.focus(index)


func _refresh_points() -> void:
	# The name and unspent points ride ABOVE the hero at the graph's heart now — the
	# inspector stays purely about the tapped node.
	if _selected_symbot == null:
		_view.set_hero(null, "", 0)
		return
	var species := _species_of(_selected_symbot)
	_view.set_hero(
		UnitPanel.art_texture(_selected_symbot.species_id, _selected_symbot.mark),
		species.display_name.to_upper() if species != null else "",
		TreeAllocator.unspent_points(_selected_symbot))


func _refresh_view() -> void:
	if _selected_symbot == null:
		return
	var species := _species_of(_selected_symbot)
	var allocated := TreeAllocator.allocated_set(_selected_symbot, species)
	var frontier: Dictionary = {}
	for id in TreeAllocator.frontier(_ctx.tree, _selected_symbot, species):
		frontier[id] = true
	var fitted: Dictionary = {}
	for node_id in _selected_symbot.installed_items:
		fitted[node_id] = true
	_view.set_state(allocated, frontier, _selected_node, fitted)


func _refresh_detail() -> void:
	if _selected_node == &"" or _selected_symbot == null:
		_node_title.text = "SKILL TREE"
		_node_detail.text = "Tap a node to inspect it. Amber nodes are within reach."
		_allocate_button.visible = false
		return
	_allocate_button.visible = true

	var node := _ctx.tree.get_node_def(_selected_node)
	if node == null:
		return
	_node_title.text = node.display_name
	_node_detail.text = _describe(node)

	var refusal := TreeAllocator.can_allocate(_ctx.tree, _selected_symbot,
		_species_of(_selected_symbot), _selected_node, _ctx.items)
	_allocate_button.disabled = refusal != TreeAllocator.Refusal.OK
	_allocate_button.text = _refusal_text(refusal, node)
	# The one actionable button turns amber when it can actually be pressed.
	_allocate_button.theme_type_variation = \
		&"Primary" if refusal == TreeAllocator.Refusal.OK else &""


## What the node does, in the player's terms. Built from the authored data rather than a
## second description field, so a rebalanced node cannot end up describing its old values.
func _describe(node: SkillNodeDef) -> String:
	var parts: PackedStringArray = []
	if node.description != "":
		parts.append(node.description)
	for key in node.stat_bonus:
		parts.append("+%d %s" % [node.stat_bonus[key], String(key).replace("_", " ")])
	for key in node.stat_percent:
		var value: int = node.stat_percent[key]
		parts.append("%s%d%% %s" % ["+" if value >= 0 else "", value,
			String(key).replace("_", " ")])
	if node.skill_id != &"":
		parts.append("Unlocks %s" % node.skill_id)
	if node.socket_accepts != &"":
		parts.append("Needs a %s installed" % String(node.socket_accepts).replace("_", " "))
	return " · ".join(parts)


## The refusal, in words. "You cannot reach this yet" teaches the tree's shape; a dead grey
## button teaches nothing and reads as a bug the player reports.
func _refusal_text(refusal: int, node: SkillNodeDef) -> String:
	match refusal:
		TreeAllocator.Refusal.OK:
			return "Allocate (1 point)"
		TreeAllocator.Refusal.ALREADY_ALLOCATED:
			return "Already yours"
		TreeAllocator.Refusal.NOT_REACHABLE:
			var steps := TreeAllocator.path_to(_ctx.tree, _selected_symbot,
				_species_of(_selected_symbot), node.id).size()
			return "Out of reach — %d nodes away" % steps
		TreeAllocator.Refusal.NO_POINTS:
			return "No points — go fight"
		TreeAllocator.Refusal.SOCKET_EMPTY:
			return "Install a %s first" % String(node.socket_accepts).replace("_", " ")
		TreeAllocator.Refusal.SOCKET_WRONG_CATEGORY:
			return "Wrong component fitted"
		TreeAllocator.Refusal.IS_ENTRY_NODE:
			return "Another Symbot's doorway"
	return "—"


func _refresh_respec() -> void:
	if _selected_symbot == null or _selected_symbot.allocated_nodes.is_empty():
		_respec_button.visible = false
		return
	_respec_button.visible = true
	var cost := TreeAllocator.respec_cost(_selected_symbot, _ctx.balance)
	_respec_button.text = "Respec (%d Scrap)" % cost
	_respec_button.disabled = not _ctx.wallet.can_afford(Wallet.SCRAP, cost)


## Socket controls. Hidden entirely for a non-socket node rather than shown disabled — an
## always-present "Fit" button that is dead on 140 of 156 nodes trains the player to ignore
## the whole row.
func _refresh_fitting() -> void:
	for child in _fit_row.get_children():
		_fit_row.remove_child(child)
		child.queue_free()

	if _selected_symbot == null or _selected_node == &"":
		_fit_row.visible = false
		return
	var node := _ctx.tree.get_node_def(_selected_node)
	if node == null or node.node_type != SkillNodeDefScript.NodeType.SOCKET:
		_fit_row.visible = false
		return
	_fit_row.visible = true

	if _selected_symbot.installed_items.has(_selected_node):
		_build_unfit_button(node)
		return

	var options := ItemFittingScript.fitting_options(_ctx.tree, _selected_node,
		_ctx.inventory_items, _ctx.item_catalog)
	if options.is_empty():
		var none := Label.new()
		none.text = "No %s owned" % String(node.socket_accepts).replace("_", " ")
		_fit_row.add_child(none)
		return
	# Strongest first — the player almost always wants their best chip.
	for item_id in options:
		_fit_row.add_child(_build_fit_button(item_id))


func _build_fit_button(item_id: StringName) -> Button:
	var item: InstallItemDef = _ctx.item_catalog.get_item(item_id)
	var button := Button.new()
	button.text = "Fit %s (x%d)" % [item.display_name if item != null else String(item_id),
		_ctx.inventory_items.count(item_id)]
	button.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(Callable(self, "_on_fit_pressed").bind(item_id))
	return button


func _build_unfit_button(node: SkillNodeDef) -> void:
	var fitted: StringName = _selected_symbot.installed_items[_selected_node]
	var item: InstallItemDef = _ctx.item_catalog.get_item(fitted)
	var cost := ItemFittingScript.removal_cost(_selected_symbot, _selected_node,
		_ctx.item_catalog)

	var label := Label.new()
	label.text = "Fitted: %s" % (item.display_name if item != null else String(fitted))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fit_row.add_child(label)

	var button := Button.new()
	# The warning is on the button because pulling a chip ALSO re-locks the node, and a
	# player who loses a node they paid a point for without being told would be right to
	# call it a bug.
	button.text = "Remove (%d Scrap, re-locks)" % cost
	button.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	button.disabled = ItemFittingScript.can_unfit(_selected_symbot, _selected_node,
		_ctx.wallet, _ctx.item_catalog) != ItemFittingScript.Refusal.OK
	button.pressed.connect(Callable(self, "_on_unfit_pressed"))
	_fit_row.add_child(button)


func _on_fit_pressed(item_id: StringName) -> void:
	ItemFittingScript.fit(_ctx.tree, _selected_symbot, _selected_node, item_id,
		_ctx.inventory_items, _ctx.item_catalog)
	refresh()


func _on_unfit_pressed() -> void:
	ItemFittingScript.unfit(_selected_symbot, _selected_node, _ctx.inventory_items,
		_ctx.wallet, _ctx.item_catalog)
	refresh()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_symbot_selected(symbot: SymbotInstance) -> void:
	_selected_symbot = symbot
	_selected_node = &""
	# Recentre on the new Symbot's doorway — leaving the pan where it was would drop the
	# player somewhere unrelated to the build they just switched to.
	_view._has_user_panned = false
	_view.center_on(_entry_of(symbot))
	refresh()


func _on_node_tapped(node_id: StringName) -> void:
	_selected_node = node_id
	refresh()


func _on_allocate_pressed() -> void:
	if _selected_symbot == null:
		return
	# The allocator re-checks. A view's answer can be one tap stale after a level-up
	# elsewhere or an item being unfitted.
	TreeAllocator.allocate(_ctx.tree, _selected_symbot, _species_of(_selected_symbot),
		_selected_node, _ctx.items)
	refresh()


func _on_respec_pressed() -> void:
	if _selected_symbot == null:
		return
	var cost := TreeAllocator.respec_cost(_selected_symbot, _ctx.balance)
	# Charge FIRST. Refunding the points before taking the Scrap would let a failed spend
	# hand out a free respec.
	if not _ctx.wallet.spend(Wallet.SCRAP, cost):
		return
	TreeAllocator.respec(_selected_symbot)
	_selected_node = &""
	refresh()


func _on_close_pressed() -> void:
	closed.emit()


func _species_of(symbot: SymbotInstance) -> SpeciesDef:
	return _ctx.species.get_species(symbot.species_id) if symbot != null else null


func _entry_of(symbot: SymbotInstance) -> StringName:
	var species := _species_of(symbot)
	return species.tree_entry_node if species != null else &""
