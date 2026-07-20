## Install items and the socket axis (Core Design §4.4).
##
## What matters here is that hardware is a real second axis rather than a re-skinned
## currency: every socket in the shipped tree must be fillable, tier must actually change
## what a socket gives, and pulling a component back out must stay affordable enough that
## the player is willing to experiment.
extends GutTest

const InstallItemDefScript := preload("res://src/core/tree/install_item_def.gd")
const SkillNodeDefScript := preload("res://src/core/tree/skill_node_def.gd")

const ITEM_CATALOG_PATH := "res://assets/data/catalogs/install_item_catalog.tres"
const TREE_PATH := "res://assets/data/tree/skill_tree.tres"
const SPECIES_CATALOG_PATH := "res://assets/data/catalogs/species_catalog.tres"

const EXPECTED_ITEM_COUNT := 20  ## 5 categories x 4 tiers

var _items: InstallItemCatalog
var _tree: SkillTree


func before_each() -> void:
	_items = load(ITEM_CATALOG_PATH)
	_tree = load(TREE_PATH)


# ---------------------------------------------------------------------------
# The shipped roster
# ---------------------------------------------------------------------------

func test_the_catalog_ships_every_category_at_every_tier() -> void:
	assert_eq(_items.entries.size(), EXPECTED_ITEM_COUNT)
	var seen: Dictionary = {}
	for i in _items.entries:
		seen["%d_%d" % [i.category, i.tier]] = true
	assert_eq(seen.size(), EXPECTED_ITEM_COUNT, "no category/tier pair is missing or doubled")


func test_no_shipped_item_has_an_invalid_category_or_tier() -> void:
	for i in _items.entries:
		assert_ne(i.category, InstallItemDefScript.Category.INVALID, "%s" % i.id)
		assert_ne(i.tier, InstallItemDefScript.Tier.INVALID, "%s" % i.id)


func test_every_item_id_is_unique() -> void:
	var seen: Dictionary = {}
	for i in _items.entries:
		assert_false(seen.has(i.id), "duplicate item id %s" % i.id)
		seen[i.id] = true


func test_every_socket_in_the_shipped_tree_can_actually_be_filled() -> void:
	# A socket with nothing that fits is a dead end the player hunts for forever.
	var sockets := 0
	for n in _tree.nodes:
		if n.node_type != SkillNodeDefScript.NodeType.SOCKET:
			continue
		sockets += 1
		assert_gt(_items.fitting(n.socket_accepts).size(), 0,
			"nothing in the catalog fits %s (accepts %s)" % [n.id, n.socket_accepts])
	assert_eq(sockets, 16, "the tree has sixteen sockets, one per doorway")


func test_every_item_category_has_somewhere_to_go() -> void:
	# The mirror of the check above: an item that fits no socket is a drop that reads as
	# progress and is not.
	var accepted: Dictionary = {}
	for n in _tree.nodes:
		if n.node_type == SkillNodeDefScript.NodeType.SOCKET:
			accepted[n.socket_accepts] = true
	for i in _items.entries:
		assert_true(accepted.has(i.category_key()),
			"%s is a %s, and no socket accepts that" % [i.id, i.category_key()])


# ---------------------------------------------------------------------------
# Tier
# ---------------------------------------------------------------------------

func test_a_higher_tier_is_strictly_stronger() -> void:
	# Same socket, better chip, stronger node — otherwise a socket opened early is a
	# one-time unlock rather than something worth revisiting.
	var last := 0
	for tier in [InstallItemDefScript.Tier.T1, InstallItemDefScript.Tier.T2,
			InstallItemDefScript.Tier.T3, InstallItemDefScript.Tier.T4]:
		var power: int = InstallItemDefScript.TIER_POWER[tier]
		assert_gt(power, last, "tier %d must beat the one below it" % tier)
		last = power


func test_removal_cost_rises_with_tier() -> void:
	# A high-tier component should be a heavier commitment than a starter chip.
	var by_tier: Dictionary = {}
	for i in _items.entries:
		by_tier[i.tier] = i.removal_scrap_cost
	assert_lt(int(by_tier[InstallItemDefScript.Tier.T1]),
		int(by_tier[InstallItemDefScript.Tier.T4]))


func test_removal_always_costs_something() -> void:
	# Free removal makes sockets a menu; §4.4 fixes a Scrap cost ("podem ser removidos,
	# mas custa scrap").
	for i in _items.entries:
		assert_gt(i.removal_scrap_cost, 0, "%s can be pulled for free" % i.id)


# ---------------------------------------------------------------------------
# Fitting
# ---------------------------------------------------------------------------

func test_an_item_fits_only_its_own_category() -> void:
	var chip := _items.get_item(&"item_ram_chip_t1")
	assert_not_null(chip)
	assert_true(chip.fits(&"ram_chip"))
	assert_false(chip.fits(&"servo"))


func test_the_lookup_table_resolves_every_shipped_item() -> void:
	var table := _items.to_table()
	assert_eq(table.size(), _items.entries.size())
	for i in _items.entries:
		assert_eq(table.get(i.id), i)


# ---------------------------------------------------------------------------
# The socket axis end to end
# ---------------------------------------------------------------------------

func _walk_to_socket(inst: SymbotInstance, species: SpeciesDef) -> StringName:
	var socket_id := StringName("%s_socket" % species.tree_entry_node)
	for step in TreeAllocator.path_to(_tree, inst, species, socket_id):
		if step == socket_id:
			break
		TreeAllocator.allocate(_tree, inst, species, step)
	return socket_id


func test_a_fitted_chip_opens_the_socket_and_a_wrong_one_does_not() -> void:
	var catalog: SpeciesCatalog = load(SPECIES_CATALOG_PATH)
	var species := catalog.get_species(&"rustcrawler")
	var inst := SymbotInstance.new(&"probe", &"rustcrawler")
	inst.level = 60
	var socket_id := _walk_to_socket(inst, species)
	var node := _tree.get_node_def(socket_id)
	var table := _items.to_table()

	# Wrong category first, so the pass afterwards is not a false positive.
	inst.installed_items[socket_id] = &"item_servo_t1"
	var wrong := TreeAllocator.can_allocate(_tree, inst, species, socket_id, table)

	inst.installed_items[socket_id] = _items.fitting(node.socket_accepts)[0].id
	var right := TreeAllocator.can_allocate(_tree, inst, species, socket_id, table)

	assert_eq(wrong, TreeAllocator.Refusal.SOCKET_WRONG_CATEGORY)
	assert_eq(right, TreeAllocator.Refusal.OK)


func test_a_better_chip_makes_the_same_socket_give_more() -> void:
	# This is the whole point of tiers. If these two aggregates were equal, tier would be
	# flavour text.
	var catalog: SpeciesCatalog = load(SPECIES_CATALOG_PATH)
	var species := catalog.get_species(&"rustcrawler")
	var inst := SymbotInstance.new(&"probe", &"rustcrawler")
	inst.level = 60
	var socket_id := _walk_to_socket(inst, species)
	var node := _tree.get_node_def(socket_id)
	var table := _items.to_table()
	var stat_key: StringName = node.stat_bonus.keys()[0]

	inst.installed_items[socket_id] = StringName("item_%s_t1" % node.socket_accepts)
	TreeAllocator.allocate(_tree, inst, species, socket_id, table)
	var low: int = TreeAllocator.aggregate_stats(_tree, inst, species, table)["flat"][stat_key]

	inst.installed_items[socket_id] = StringName("item_%s_t4" % node.socket_accepts)
	var high: int = TreeAllocator.aggregate_stats(_tree, inst, species, table)["flat"][stat_key]

	assert_gt(high, low, "a T4 chip must beat a T1 in the same socket (%d vs %d)" % [high, low])


func test_an_unresolvable_chip_still_pays_out_the_base_value() -> void:
	# The node was legitimately allocated. Refusing to pay out because the lookup came up
	# empty would silently weaken a build the player already spent points on — the reverse
	# of the fail-closed rule that governs whether it can be allocated at all.
	var catalog: SpeciesCatalog = load(SPECIES_CATALOG_PATH)
	var species := catalog.get_species(&"rustcrawler")
	var inst := SymbotInstance.new(&"probe", &"rustcrawler")
	inst.level = 60
	var socket_id := _walk_to_socket(inst, species)
	var node := _tree.get_node_def(socket_id)
	var stat_key: StringName = node.stat_bonus.keys()[0]

	inst.installed_items[socket_id] = _items.fitting(node.socket_accepts)[0].id
	TreeAllocator.allocate(_tree, inst, species, socket_id, _items.to_table())
	var agg := TreeAllocator.aggregate_stats(_tree, inst, species, {})

	assert_eq(int(agg["flat"][stat_key]), int(node.stat_bonus[stat_key]),
		"base value paid at 100%, not zeroed")
