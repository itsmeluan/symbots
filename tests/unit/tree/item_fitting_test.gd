## Fitting and pulling hardware (Core Design §4.4).
##
## The rule that carries the most weight: pulling a component RE-LOCKS its node. Without
## that, one cheap chip permanently opens a socket and hardware gates nothing after the
## first fit — which would quietly delete the whole second progression axis.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const ItemFittingScript := preload("res://src/core/tree/item_fitting.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")

var _game: V1Game
var _symbot: SymbotInstance
var _species: SpeciesDef
var _socket_id: StringName


func before_each() -> void:
	_game = V1GameScript.new()
	_game.save_backend = MemoryBackend.new()
	add_child_autofree(_game)

	_symbot = _game.ctx.roster.squad_symbots()[0]
	_symbot.level = 60
	_species = _game.ctx.species.get_species(_symbot.species_id)
	_socket_id = StringName("%s_socket" % _species.tree_entry_node)
	# Walk up to (not into) the socket, so the only thing gating it is the component.
	for step in TreeAllocator.path_to(_game.ctx.tree, _symbot, _species, _socket_id):
		if step != _socket_id:
			TreeAllocator.allocate(_game.ctx.tree, _symbot, _species, step)


func after_each() -> void:
	_game = null


func _accepted() -> StringName:
	return _game.ctx.tree.get_node_def(_socket_id).socket_accepts


func _own(tier: int, count: int = 1) -> StringName:
	var item_id := StringName("item_%s_t%d" % [_accepted(), tier])
	_game.ctx.inventory_items.add(item_id, count)
	return item_id


func _fit(item_id: StringName) -> bool:
	return ItemFittingScript.fit(_game.ctx.tree, _symbot, _socket_id, item_id,
		_game.ctx.inventory_items, _game.ctx.item_catalog)


# ---------------------------------------------------------------------------
# Fitting
# ---------------------------------------------------------------------------

func test_fitting_takes_the_component_out_of_the_inventory() -> void:
	# A component in a socket is no longer a spare; showing it in both places would let the
	# player fit the same chip twice.
	var item_id := _own(1, 2)
	assert_true(_fit(item_id))
	assert_eq(_game.ctx.inventory_items.count(item_id), 1)
	assert_eq(_symbot.installed_items[_socket_id], item_id)


func test_a_component_you_do_not_own_cannot_be_fitted() -> void:
	var item_id := StringName("item_%s_t4" % _accepted())
	assert_eq(ItemFittingScript.can_fit(_game.ctx.tree, _symbot, _socket_id, item_id,
		_game.ctx.inventory_items, _game.ctx.item_catalog),
		ItemFittingScript.Refusal.NOT_OWNED)


func test_the_wrong_category_is_refused() -> void:
	var wrong := &"item_servo_t1" if _accepted() != &"servo" else &"item_ram_chip_t1"
	_game.ctx.inventory_items.add(wrong)
	assert_eq(ItemFittingScript.can_fit(_game.ctx.tree, _symbot, _socket_id, wrong,
		_game.ctx.inventory_items, _game.ctx.item_catalog),
		ItemFittingScript.Refusal.WRONG_CATEGORY)


func test_a_second_component_cannot_be_stacked_into_a_filled_socket() -> void:
	_fit(_own(1))
	var second := _own(2)
	assert_eq(ItemFittingScript.can_fit(_game.ctx.tree, _symbot, _socket_id, second,
		_game.ctx.inventory_items, _game.ctx.item_catalog),
		ItemFittingScript.Refusal.ALREADY_FITTED)


func test_a_non_socket_node_refuses_hardware() -> void:
	var item_id := _own(1)
	assert_eq(ItemFittingScript.can_fit(_game.ctx.tree, _symbot,
		StringName("%s_s1" % _species.tree_entry_node), item_id,
		_game.ctx.inventory_items, _game.ctx.item_catalog),
		ItemFittingScript.Refusal.NOT_A_SOCKET)


func test_fitting_opens_the_socket_for_allocation() -> void:
	assert_eq(TreeAllocator.can_allocate(_game.ctx.tree, _symbot, _species, _socket_id,
		_game.ctx.items), TreeAllocator.Refusal.SOCKET_EMPTY)
	_fit(_own(1))
	assert_eq(TreeAllocator.can_allocate(_game.ctx.tree, _symbot, _species, _socket_id,
		_game.ctx.items), TreeAllocator.Refusal.OK)


# ---------------------------------------------------------------------------
# Pulling it back out
# ---------------------------------------------------------------------------

func test_removal_costs_scrap() -> void:
	var item_id := _own(1)
	_fit(item_id)
	var cost := ItemFittingScript.removal_cost(_symbot, _socket_id, _game.ctx.item_catalog)
	assert_gt(cost, 0, "free removal makes sockets a menu (§4.4)")

	_game.ctx.wallet.earn(Wallet.SCRAP, cost)
	assert_eq(ItemFittingScript.unfit(_symbot, _socket_id, _game.ctx.inventory_items,
		_game.ctx.wallet, _game.ctx.item_catalog), item_id)
	assert_eq(_game.ctx.wallet.scrap, 0)


func test_removal_without_the_scrap_changes_nothing() -> void:
	var item_id := _own(1)
	_fit(item_id)
	assert_eq(ItemFittingScript.unfit(_symbot, _socket_id, _game.ctx.inventory_items,
		_game.ctx.wallet, _game.ctx.item_catalog), &"")
	assert_true(_symbot.installed_items.has(_socket_id), "still fitted")
	assert_eq(_game.ctx.inventory_items.count(item_id), 0, "and not duplicated back")


func test_a_removed_component_returns_to_the_inventory() -> void:
	var item_id := _own(1)
	_fit(item_id)
	_game.ctx.wallet.earn(Wallet.SCRAP, 100000)
	ItemFittingScript.unfit(_symbot, _socket_id, _game.ctx.inventory_items,
		_game.ctx.wallet, _game.ctx.item_catalog)
	assert_eq(_game.ctx.inventory_items.count(item_id), 1)


func test_pulling_a_component_re_locks_its_node() -> void:
	# THE rule. Without it: fit a T1 chip, buy the node, pull the chip for a small fee, and
	# keep a permanently opened socket — hardware would gate nothing after the first fit.
	_fit(_own(1))
	TreeAllocator.allocate(_game.ctx.tree, _symbot, _species, _socket_id, _game.ctx.items)
	assert_true(_symbot.allocated_nodes.has(_socket_id))
	var points_before := TreeAllocator.unspent_points(_symbot)

	_game.ctx.wallet.earn(Wallet.SCRAP, 100000)
	ItemFittingScript.unfit(_symbot, _socket_id, _game.ctx.inventory_items,
		_game.ctx.wallet, _game.ctx.item_catalog)

	assert_false(_symbot.allocated_nodes.has(_socket_id), "the node re-locks")
	assert_eq(TreeAllocator.unspent_points(_symbot), points_before + 1,
		"and the point comes back, since the node was taken away")


func test_unfitting_an_empty_socket_is_refused() -> void:
	assert_eq(ItemFittingScript.can_unfit(_symbot, _socket_id, _game.ctx.wallet,
		_game.ctx.item_catalog), ItemFittingScript.Refusal.NOTHING_FITTED)


# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------

func test_fitting_options_list_only_what_fits_and_is_owned() -> void:
	_own(1)
	var wrong := &"item_servo_t1" if _accepted() != &"servo" else &"item_ram_chip_t1"
	_game.ctx.inventory_items.add(wrong)
	var options := ItemFittingScript.fitting_options(_game.ctx.tree, _socket_id,
		_game.ctx.inventory_items, _game.ctx.item_catalog)
	assert_eq(options.size(), 1)
	assert_false(options.has(wrong))


func test_the_strongest_option_comes_first() -> void:
	# The player almost always wants their best chip; making them scroll for it is friction
	# with no decision in it.
	_own(1)
	_own(4)
	_own(2)
	var options := ItemFittingScript.fitting_options(_game.ctx.tree, _socket_id,
		_game.ctx.inventory_items, _game.ctx.item_catalog)
	assert_eq(options[0], StringName("item_%s_t4" % _accepted()))


# ---------------------------------------------------------------------------
# Through the screen
# ---------------------------------------------------------------------------

func test_the_tree_screen_offers_fitting_only_on_a_socket() -> void:
	# An always-present "Fit" row that is dead on 140 of 156 nodes trains the player to
	# ignore the whole row.
	_game.show_tree()
	var screen := _game._tree_screen
	screen._on_symbot_selected(_symbot)

	screen._on_node_tapped(StringName("%s_s1" % _species.tree_entry_node))
	assert_false(screen._fit_row.visible, "not a socket")

	screen._on_node_tapped(_socket_id)
	assert_true(screen._fit_row.visible)


func test_the_screen_says_so_when_nothing_owned_fits() -> void:
	_game.show_tree()
	var screen := _game._tree_screen
	screen._on_symbot_selected(_symbot)
	screen._on_node_tapped(_socket_id)
	var text := ""
	for child in screen._fit_row.get_children():
		if child is Label:
			text += child.text
	assert_true(text.contains("No "), "got '%s'" % text)


func test_fitting_through_the_screen_works_end_to_end() -> void:
	var item_id := _own(1)
	_game.show_tree()
	var screen := _game._tree_screen
	screen._on_symbot_selected(_symbot)
	screen._on_node_tapped(_socket_id)

	screen._on_fit_pressed(item_id)

	assert_eq(_symbot.installed_items.get(_socket_id), item_id)
	assert_false(screen._allocate_button.disabled, "and the node is now allocatable")


func test_the_remove_button_warns_that_it_re_locks() -> void:
	# A player who loses a node they paid a point for without being told would be right to
	# call it a bug.
	_fit(_own(1))
	_game.show_tree()
	var screen := _game._tree_screen
	screen._on_symbot_selected(_symbot)
	screen._on_node_tapped(_socket_id)

	var text := ""
	for child in screen._fit_row.get_children():
		if child is Button:
			text += child.text
	assert_true(text.contains("re-locks"), "got '%s'" % text)
