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

signal closed

const MIN_BUTTON_HEIGHT := 44

var _ctx: ServiceContext = null
var _selected_symbot: SymbotInstance = null
var _selected_node: StringName = &""

var _view: SkillTreeView
var _points_label: Label
var _roster_strip: HBoxContainer
var _node_title: Label
var _node_detail: Label
var _allocate_button: Button
var _respec_button: Button


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
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var back := Button.new()
	back.text = "< Map"
	back.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	back.pressed.connect(Callable(self, "_on_close_pressed"))
	header.add_child(back)
	_points_label = Label.new()
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_points_label)

	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT + 8)
	roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(roster_scroll)
	_roster_strip = HBoxContainer.new()
	roster_scroll.add_child(_roster_strip)

	_view = SkillTreeViewScript.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.node_tapped.connect(Callable(self, "_on_node_tapped"))
	root.add_child(_view)

	_node_title = Label.new()
	_node_title.add_theme_font_size_override("font_size", 12)
	root.add_child(_node_title)

	_node_detail = Label.new()
	_node_detail.add_theme_font_size_override("font_size", 9)
	_node_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_node_detail.custom_minimum_size = Vector2(0, 30)
	root.add_child(_node_detail)

	_allocate_button = Button.new()
	_allocate_button.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	_allocate_button.pressed.connect(Callable(self, "_on_allocate_pressed"))
	root.add_child(_allocate_button)

	_respec_button = Button.new()
	_respec_button.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	_respec_button.pressed.connect(Callable(self, "_on_respec_pressed"))
	root.add_child(_respec_button)


func refresh() -> void:
	if _ctx == null:
		return
	_rebuild_roster_strip()
	_refresh_points()
	_refresh_view()
	_refresh_detail()
	_refresh_respec()


func _rebuild_roster_strip() -> void:
	for child in _roster_strip.get_children():
		_roster_strip.remove_child(child)
		child.queue_free()
	for symbot in _ctx.roster.symbots:
		var species: SpeciesDef = _ctx.species.get_species(symbot.species_id)
		if species == null:
			continue
		var button := Button.new()
		button.text = "%s\n%d pts" % [species.display_name,
			TreeAllocator.unspent_points(symbot)]
		button.custom_minimum_size = Vector2(76, MIN_BUTTON_HEIGHT)
		button.toggle_mode = true
		button.button_pressed = (_selected_symbot == symbot)
		button.pressed.connect(Callable(self, "_on_symbot_selected").bind(symbot))
		_roster_strip.add_child(button)


func _refresh_points() -> void:
	if _selected_symbot == null:
		_points_label.text = ""
		return
	_points_label.text = "%d points" % TreeAllocator.unspent_points(_selected_symbot)


func _refresh_view() -> void:
	if _selected_symbot == null:
		return
	var species := _species_of(_selected_symbot)
	var allocated := TreeAllocator.allocated_set(_selected_symbot, species)
	var frontier: Dictionary = {}
	for id in TreeAllocator.frontier(_ctx.tree, _selected_symbot, species):
		frontier[id] = true
	_view.set_state(allocated, frontier, _selected_node)


func _refresh_detail() -> void:
	if _selected_node == &"" or _selected_symbot == null:
		_node_title.text = "Tap a node"
		_node_detail.text = ""
		_allocate_button.disabled = true
		_allocate_button.text = "—"
		return

	var node := _ctx.tree.get_node_def(_selected_node)
	if node == null:
		return
	_node_title.text = node.display_name
	_node_detail.text = _describe(node)

	var refusal := TreeAllocator.can_allocate(_ctx.tree, _selected_symbot,
		_species_of(_selected_symbot), _selected_node, _ctx.items)
	_allocate_button.disabled = refusal != TreeAllocator.Refusal.OK
	_allocate_button.text = _refusal_text(refusal, node)


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
			return "Another species' doorway"
	return "—"


func _refresh_respec() -> void:
	if _selected_symbot == null or _selected_symbot.allocated_nodes.is_empty():
		_respec_button.visible = false
		return
	_respec_button.visible = true
	var cost := TreeAllocator.respec_cost(_selected_symbot, _ctx.balance)
	_respec_button.text = "Respec (%d Scrap)" % cost
	_respec_button.disabled = not _ctx.wallet.can_afford(Wallet.SCRAP, cost)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_symbot_selected(symbot: SymbotInstance) -> void:
	_selected_symbot = symbot
	_selected_node = &""
	# Recentre on the new Symbot's doorway — leaving the pan where it was would drop the
	# player somewhere unrelated to the build they just switched to.
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
