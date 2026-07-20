## Skill tree + TreeAllocator (Core Design §4).
##
## Two halves. The allocator's rules are pinned with a tiny hand-built tree, so a failure
## names the rule rather than pointing at 156 nodes of authored content. The shipped tree
## is then checked for the invariants that make §4.1 true — chiefly that distance actually
## costs, since that is the tree's entire balance lever.
extends GutTest

const SkillNodeDefScript := preload("res://src/core/tree/skill_node_def.gd")
const InstallItemDefScript := preload("res://src/core/tree/install_item_def.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")

const TREE_PATH := "res://assets/data/tree/skill_tree.tres"
const SPECIES_CATALOG_PATH := "res://assets/data/catalogs/species_catalog.tres"

var _tree: SkillTree
var _species: SpeciesDef
var _inst: SymbotInstance


## A five-node line: entry -> a -> b, plus a socket off a, plus an orphan nothing reaches.
##   entry — a — b
##            \
##             socket        orphan
func _toy_tree() -> SkillTree:
	var t := SkillTree.new()
	t.nodes = [
		_node(&"entry", SkillNodeDefScript.NodeType.ENTRY, [&"a"]),
		_node(&"a", SkillNodeDefScript.NodeType.STAT, [&"entry", &"b", &"socket"],
			{&"physical_power": 10}),
		_node(&"b", SkillNodeDefScript.NodeType.PASSIVE, [&"a"]),
		_node(&"socket", SkillNodeDefScript.NodeType.SOCKET, [&"a"]),
		_node(&"orphan", SkillNodeDefScript.NodeType.STAT, []),
	]
	t.nodes[3].socket_accepts = &"ram_chip"
	t.nodes[2].passive_id = &"pass_toy"
	return t


func _node(id: StringName, type: int, neighbours: Array,
		bonus: Dictionary = {}) -> SkillNodeDef:
	var n := SkillNodeDef.new()
	n.id = id
	n.display_name = String(id)
	n.node_type = type
	var typed: Array[StringName] = []
	for x in neighbours:
		typed.append(x)
	n.neighbours = typed
	# stat_bonus is Dictionary[StringName, int]; an untyped literal is refused at runtime,
	# so the values have to be copied into a typed one.
	var typed_bonus: Dictionary[StringName, int] = {}
	for key in bonus:
		typed_bonus[key] = int(bonus[key])
	n.stat_bonus = typed_bonus
	return n


func _toy_species() -> SpeciesDef:
	var s := SpeciesDef.new()
	s.id = &"toy"
	s.tree_entry_node = &"entry"
	return s


func before_each() -> void:
	_tree = _toy_tree()
	_species = _toy_species()
	_inst = SymbotInstance.new(&"i1", &"toy")
	_inst.level = 10


func _item(category: int) -> InstallItemDef:
	var i := InstallItemDef.new()
	i.id = &"chip"
	i.category = category
	i.tier = InstallItemDefScript.Tier.T1
	return i


# ---------------------------------------------------------------------------
# Points and the free entry
# ---------------------------------------------------------------------------

func test_the_entry_node_costs_no_point() -> void:
	# It is granted at birth. Charging for it would leave every Symbot one point short for
	# its whole life — and the shortfall would be invisible.
	assert_eq(TreeAllocator.unspent_points(_inst), 9, "level 10 = 9 points")
	assert_false(_inst.allocated_nodes.has(&"entry"),
		"the entry is never stored on the instance")
	assert_true(TreeAllocator.allocated_set(_inst, _species).has(&"entry"),
		"but reachability still counts it as held")


func test_each_allocation_spends_exactly_one_point() -> void:
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	assert_eq(TreeAllocator.unspent_points(_inst), 8)


func test_allocation_is_refused_with_no_points_left() -> void:
	_inst.level = 1
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"a"),
		TreeAllocator.Refusal.NO_POINTS)


# ---------------------------------------------------------------------------
# Reachability — the rule everything hangs off
# ---------------------------------------------------------------------------

func test_a_node_touching_an_allocated_one_can_be_taken() -> void:
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"a"),
		TreeAllocator.Refusal.OK)


func test_a_node_two_steps_out_cannot_be_skipped_to() -> void:
	# Reachability, not a role tag, is what gates a build (§4.1).
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"b"),
		TreeAllocator.Refusal.NOT_REACHABLE)
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"b"),
		TreeAllocator.Refusal.OK, "and becomes available once the step between is walked")


func test_a_disconnected_node_is_never_reachable() -> void:
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"orphan"),
		TreeAllocator.Refusal.NOT_REACHABLE)


func test_another_species_doorway_cannot_be_walked_into() -> void:
	var other := _node(&"entry_other", SkillNodeDefScript.NodeType.ENTRY, [&"a"])
	_tree.nodes.append(other)
	_tree._indexed = false
	_tree.nodes[1].neighbours.append(&"entry_other")
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"entry_other"),
		TreeAllocator.Refusal.IS_ENTRY_NODE,
		"an entry belongs to a species, not to a purchase")


func test_the_same_node_cannot_be_bought_twice() -> void:
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"a"),
		TreeAllocator.Refusal.ALREADY_ALLOCATED)


func test_an_unknown_node_is_refused_rather_than_crashing() -> void:
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"no_such_thing"),
		TreeAllocator.Refusal.NO_SUCH_NODE)


# ---------------------------------------------------------------------------
# Sockets (§4.4)
# ---------------------------------------------------------------------------

func test_a_socket_needs_an_item_as_well_as_a_point() -> void:
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"socket"),
		TreeAllocator.Refusal.SOCKET_EMPTY,
		"hardware is a second progression axis, not more currency")


func test_a_socket_rejects_the_wrong_category() -> void:
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	_inst.installed_items[&"socket"] = &"chip_1"
	var items := {&"chip_1": _item(InstallItemDefScript.Category.SERVO)}
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"socket", items),
		TreeAllocator.Refusal.SOCKET_WRONG_CATEGORY)


func test_a_socket_opens_with_the_right_category() -> void:
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	_inst.installed_items[&"socket"] = &"chip_1"
	var items := {&"chip_1": _item(InstallItemDefScript.Category.RAM_CHIP)}
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"socket", items),
		TreeAllocator.Refusal.OK)


func test_a_socket_fails_closed_when_the_item_cannot_be_resolved() -> void:
	# A gate that opens when it cannot verify is not a gate.
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	_inst.installed_items[&"socket"] = &"unknown_chip"
	assert_eq(TreeAllocator.can_allocate(_tree, _inst, _species, &"socket", {}),
		TreeAllocator.Refusal.SOCKET_WRONG_CATEGORY)


# ---------------------------------------------------------------------------
# Frontier and pathing
# ---------------------------------------------------------------------------

func test_the_frontier_is_what_the_ui_highlights_next() -> void:
	assert_eq(TreeAllocator.frontier(_tree, _inst, _species), [&"a"] as Array[StringName])


func test_the_frontier_never_offers_a_doorway() -> void:
	var other := _node(&"entry_other", SkillNodeDefScript.NodeType.ENTRY, [&"a"])
	_tree.nodes.append(other)
	_tree._indexed = false
	_tree.nodes[1].neighbours.append(&"entry_other")
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	assert_false(TreeAllocator.frontier(_tree, _inst, _species).has(&"entry_other"))


func test_a_path_lists_only_the_nodes_still_to_buy() -> void:
	var path := TreeAllocator.path_to(_tree, _inst, _species, &"b")
	assert_eq(path, [&"a", &"b"] as Array[StringName],
		"the entry is already held, so it is not part of the bill")


func test_a_path_to_something_unreachable_is_empty() -> void:
	assert_eq(TreeAllocator.path_to(_tree, _inst, _species, &"orphan").size(), 0)


# ---------------------------------------------------------------------------
# Respec (§4.5)
# ---------------------------------------------------------------------------

func test_respec_refunds_every_point_and_keeps_the_doorway() -> void:
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	TreeAllocator.allocate(_tree, _inst, _species, &"b")
	assert_eq(TreeAllocator.respec(_inst), 2)
	assert_eq(TreeAllocator.unspent_points(_inst), 9, "all points back")
	assert_true(TreeAllocator.allocated_set(_inst, _species).has(&"entry"),
		"the entry survives — it was never bought")


func test_respec_leaves_installed_hardware_alone() -> void:
	# Silently ejecting a player's components during a respec would be a nasty surprise;
	# pulling an item is its own action with its own cost (§4.4).
	_inst.installed_items[&"socket"] = &"chip_1"
	TreeAllocator.respec(_inst)
	assert_true(_inst.installed_items.has(&"socket"))


func test_respec_is_priced_per_allocated_node() -> void:
	var cfg := BalanceConfig.new()
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	TreeAllocator.allocate(_tree, _inst, _species, &"b")
	assert_eq(TreeAllocator.respec_cost(_inst, cfg), 2 * cfg.respec_scrap_per_node,
		"a free respec makes the tree a menu rather than a commitment")


# ---------------------------------------------------------------------------
# Aggregation
# ---------------------------------------------------------------------------

func test_allocated_stat_nodes_aggregate() -> void:
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	var agg := TreeAllocator.aggregate_stats(_tree, _inst, _species)
	assert_eq(int(agg["flat"].get(&"physical_power", 0)), 10)


func test_allocated_passive_nodes_are_reported() -> void:
	TreeAllocator.allocate(_tree, _inst, _species, &"a")
	TreeAllocator.allocate(_tree, _inst, _species, &"b")
	assert_true(TreeAllocator.granted_passives(_tree, _inst, _species).has(&"pass_toy"))


# ---------------------------------------------------------------------------
# The shipped tree
# ---------------------------------------------------------------------------

func test_the_shipped_tree_has_the_sixteen_doorways_the_design_fixes() -> void:
	var tree: SkillTree = load(TREE_PATH)
	assert_eq(tree.entry_nodes().size(), 16, "§4.1 fixes sixteen — four per role")


func test_the_shipped_tree_gives_every_role_four_doorways() -> void:
	var tree: SkillTree = load(TREE_PATH)
	var per_role: Dictionary = {}
	for n in tree.entry_nodes():
		per_role[n.entry_role] = int(per_role.get(n.entry_role, 0)) + 1
	for role in [1, 2, 3, 4]:
		assert_eq(int(per_role.get(role, 0)), 4, "role %d needs four doorways" % role)


func test_every_shipped_species_can_actually_get_into_the_tree() -> void:
	var tree: SkillTree = load(TREE_PATH)
	var catalog: SpeciesCatalog = load(SPECIES_CATALOG_PATH)
	for s in catalog.entries:
		assert_true(tree.has_node(s.tree_entry_node),
			"%s enters at %s, which does not exist" % [s.id, s.tree_entry_node])
		var inst := SymbotInstance.new(&"probe", s.id)
		inst.level = 2
		assert_gt(TreeAllocator.frontier(tree, inst, s).size(), 0,
			"%s has a doorway that leads nowhere" % s.id)


func test_shipped_adjacency_is_symmetric() -> void:
	# The allocator treats edges as undirected. An edge stored on one side only makes a
	# node reachable from one direction and not the other — a maze with invisible one-way
	# doors, which is impossible to debug from the tree screen.
	var tree: SkillTree = load(TREE_PATH)
	for n in tree.nodes:
		for other_id in n.neighbours:
			var other := tree.get_node_def(other_id)
			assert_not_null(other, "%s points at missing node %s" % [n.id, other_id])
			if other != null:
				assert_true(other.neighbours.has(n.id),
					"%s -> %s is one-way" % [n.id, other_id])


func test_reaching_another_roles_keystone_costs_far_more_than_your_own() -> void:
	# This IS the design (§4.1): a healer CAN reach a DPS keystone, it just spends the walk
	# a DPS gets for free. If these two numbers ever converge, the tree has stopped
	# balancing anything.
	var tree: SkillTree = load(TREE_PATH)
	var catalog: SpeciesCatalog = load(SPECIES_CATALOG_PATH)
	var healer := catalog.get_species(&"solderfly")
	var inst := SymbotInstance.new(&"probe", &"solderfly")
	inst.level = 60

	var own := TreeAllocator.path_to(tree, inst, healer, &"key_transfusion").size()
	var foreign := TreeAllocator.path_to(tree, inst, healer, &"key_glass_edge").size()

	assert_gt(own, 0, "a healer must be able to reach its own keystone")
	assert_gt(foreign, own,
		"and a foreign keystone must cost strictly more (own=%d foreign=%d)" % [own, foreign])


func test_every_shipped_keystone_carries_a_drawback() -> void:
	# A keystone with no cost is just a big stat node (§4.3).
	var tree: SkillTree = load(TREE_PATH)
	var found := 0
	for n in tree.nodes:
		if n.node_type == SkillNodeDefScript.NodeType.KEYSTONE:
			found += 1
			assert_ne(n.keystone_drawback_id, &"", "%s has no drawback" % n.id)
	assert_eq(found, 4, "one keystone per role")


func test_every_shipped_socket_declares_what_fits_it() -> void:
	var tree: SkillTree = load(TREE_PATH)
	for n in tree.nodes:
		if n.node_type == SkillNodeDefScript.NodeType.SOCKET:
			assert_ne(n.socket_accepts, &"",
				"%s accepts nothing, so it could never be opened" % n.id)


func test_the_endless_tier_is_a_sink_not_a_shortcut() -> void:
	# Spoking every endless node onto the ring would make the sink a parallel ring, and a
	# cross-quadrant walk would route straight through it — destroying the distance cost
	# the tree is balanced on. It attaches at exactly one point.
	var tree: SkillTree = load(TREE_PATH)
	var joins := 0
	for n in tree.nodes:
		if not n.is_endless_tier:
			continue
		for other_id in n.neighbours:
			var other := tree.get_node_def(other_id)
			if other != null and not other.is_endless_tier:
				joins += 1
	assert_eq(joins, 1, "the endless tier joins the designed tree exactly once")
