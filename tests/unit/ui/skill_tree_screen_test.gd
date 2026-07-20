## SkillTreeScreen + SkillTreeView — spending points (Core Design §4, ADR-0008).
##
## The screen's job is to make the tree's SHAPE legible on a phone: what you hold, what you
## could take next, and — when you cannot take something — why not. Most of what is pinned
## here is that last part, because a dead grey button teaches nothing and gets reported as
## a bug.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const SkillTreeViewScript := preload("res://src/ui/tree/skill_tree_view.gd")
const SkillNodeDefScript := preload("res://src/core/tree/skill_node_def.gd")

var _game: V1Game
var _screen: SkillTreeScreen


func before_each() -> void:
	_game = V1GameScript.new()
	add_child_autofree(_game)
	_game.show_tree()
	_screen = _game._tree_screen


func after_each() -> void:
	_game = null
	_screen = null


func _symbot() -> SymbotInstance:
	return _screen._selected_symbot


func _give_points(n: int) -> void:
	_symbot().level = n + 1
	_screen.refresh()


func _first_frontier() -> StringName:
	var species: SpeciesDef = _game.ctx.species.get_species(_symbot().species_id)
	return TreeAllocator.frontier(_game.ctx.tree, _symbot(), species)[0]


# ---------------------------------------------------------------------------
# Opening
# ---------------------------------------------------------------------------

func test_the_screen_opens_on_a_fielded_symbot() -> void:
	assert_not_null(_symbot())


func test_the_view_is_centred_on_the_symbots_doorway() -> void:
	# Opening on the origin of a 156-node graph would show the player empty space.
	var species: SpeciesDef = _game.ctx.species.get_species(_symbot().species_id)
	var entry := _game.ctx.tree.get_node_def(species.tree_entry_node)
	var on_screen := entry.position + _screen._view._pan
	assert_almost_eq(on_screen, _screen._view.size * 0.5, Vector2(1, 1))


func test_the_doorway_shows_as_already_held() -> void:
	# It is granted at birth, so it must not read as something still to buy.
	var species: SpeciesDef = _game.ctx.species.get_species(_symbot().species_id)
	assert_true(_screen._view.allocated.has(species.tree_entry_node))


func test_the_frontier_is_highlighted_separately_from_what_is_locked() -> void:
	assert_gt(_screen._view.frontier.size(), 0,
		"a player with no visible next step has nowhere to aim")


func test_the_roster_strip_shows_each_symbots_own_points() -> void:
	# Points are per Symbot (§4.2), so a shared count would be a lie.
	assert_eq(_screen._roster_strip.get_child_count(), _game.ctx.roster.symbots.size())


# ---------------------------------------------------------------------------
# Allocating
# ---------------------------------------------------------------------------

func test_tapping_a_reachable_node_offers_it() -> void:
	_give_points(3)
	_screen._on_node_tapped(_first_frontier())
	assert_false(_screen._allocate_button.disabled)
	assert_true(_screen._allocate_button.text.contains("Allocate"))


func test_allocating_spends_a_point_and_holds_the_node() -> void:
	_give_points(3)
	var target := _first_frontier()
	_screen._on_node_tapped(target)

	_screen._on_allocate_pressed()

	assert_true(_symbot().allocated_nodes.has(target))
	assert_eq(TreeAllocator.unspent_points(_symbot()), 2)
	assert_true(_screen._view.allocated.has(target), "and the graph shows it")


func test_allocating_opens_the_next_step() -> void:
	_give_points(3)
	var frontier_before := _screen._view.frontier.size()
	_screen._on_node_tapped(_first_frontier())
	_screen._on_allocate_pressed()
	assert_gt(_screen._view.frontier.size(), frontier_before,
		"walking a step must reveal more, or the tree reads as a dead end")


# ---------------------------------------------------------------------------
# Refusals say WHY
# ---------------------------------------------------------------------------

func test_no_points_says_go_fight() -> void:
	# A fresh level-1 Symbot has none.
	_screen._on_node_tapped(_first_frontier())
	assert_true(_screen._allocate_button.disabled)
	assert_true(_screen._allocate_button.text.contains("No points"))


func test_an_unreachable_node_reports_how_far_away_it_is() -> void:
	# "Out of reach — 17 nodes away" turns a locked node into a plan.
	_give_points(3)
	_screen._on_node_tapped(&"key_glass_edge")
	assert_true(_screen._allocate_button.disabled)
	assert_true(_screen._allocate_button.text.contains("nodes away"),
		"got '%s'" % _screen._allocate_button.text)


func test_a_socket_says_what_to_install() -> void:
	var species: SpeciesDef = _game.ctx.species.get_species(_symbot().species_id)
	var socket_id := StringName("%s_socket" % species.tree_entry_node)
	_give_points(40)
	for step in TreeAllocator.path_to(_game.ctx.tree, _symbot(), species, socket_id):
		if step != socket_id:
			TreeAllocator.allocate(_game.ctx.tree, _symbot(), species, step)
	_screen.refresh()

	_screen._on_node_tapped(socket_id)

	assert_true(_screen._allocate_button.disabled)
	assert_true(_screen._allocate_button.text.contains("Install"),
		"got '%s'" % _screen._allocate_button.text)


func test_an_already_held_node_says_so() -> void:
	_give_points(3)
	var target := _first_frontier()
	_screen._on_node_tapped(target)
	_screen._on_allocate_pressed()
	_screen._on_node_tapped(target)
	assert_true(_screen._allocate_button.text.contains("Already"))


func test_the_detail_panel_describes_what_a_node_does() -> void:
	_give_points(3)
	_screen._on_node_tapped(_first_frontier())
	assert_ne(_screen._node_detail.text, "",
		"a node the player cannot evaluate is a node they allocate at random")


# ---------------------------------------------------------------------------
# Respec (§4.5)
# ---------------------------------------------------------------------------

func test_respec_is_hidden_until_there_is_something_to_undo() -> void:
	assert_false(_screen._respec_button.visible)


func test_respec_quotes_its_price_and_is_blocked_without_the_scrap() -> void:
	_give_points(3)
	_screen._on_node_tapped(_first_frontier())
	_screen._on_allocate_pressed()
	assert_true(_screen._respec_button.visible)
	assert_true(_screen._respec_button.disabled, "wallet is empty on a fresh save")
	assert_true(_screen._respec_button.text.contains("Scrap"))


func test_respec_charges_and_returns_every_point() -> void:
	_give_points(3)
	_screen._on_node_tapped(_first_frontier())
	_screen._on_allocate_pressed()
	var cost := TreeAllocator.respec_cost(_symbot(), _game.ctx.balance)
	_game.ctx.wallet.earn(Wallet.SCRAP, cost)
	_screen.refresh()

	_screen._on_respec_pressed()

	assert_eq(_game.ctx.wallet.scrap, 0, "charged")
	assert_eq(TreeAllocator.unspent_points(_symbot()), 3, "points back")
	assert_true(_symbot().allocated_nodes.is_empty())


func test_a_failed_respec_does_not_hand_out_a_free_one() -> void:
	# Refunding the points before taking the Scrap would make an unaffordable respec free.
	_give_points(3)
	_screen._on_node_tapped(_first_frontier())
	_screen._on_allocate_pressed()
	var held := _symbot().allocated_nodes.size()

	_screen._on_respec_pressed()  # wallet is empty

	assert_eq(_symbot().allocated_nodes.size(), held, "nothing was refunded")


# ---------------------------------------------------------------------------
# Switching Symbots
# ---------------------------------------------------------------------------

func test_switching_symbots_recentres_on_the_new_doorway() -> void:
	# Leaving the pan where it was would drop the player somewhere unrelated to the build
	# they just switched to.
	var second: SymbotInstance = _game.ctx.roster.symbots[1]
	_screen._on_symbot_selected(second)
	var species: SpeciesDef = _game.ctx.species.get_species(second.species_id)
	var entry := _game.ctx.tree.get_node_def(species.tree_entry_node)
	assert_almost_eq(entry.position + _screen._view._pan, _screen._view.size * 0.5,
		Vector2(1, 1))


func test_each_symbot_keeps_its_own_allocations() -> void:
	_give_points(3)
	var target := _first_frontier()
	_screen._on_node_tapped(target)
	_screen._on_allocate_pressed()

	_screen._on_symbot_selected(_game.ctx.roster.symbots[1])

	assert_false(_screen._view.allocated.has(target),
		"the second Symbot has its own path — points are per Symbot (§4.2)")


# ---------------------------------------------------------------------------
# The view's own behaviour
# ---------------------------------------------------------------------------

func test_a_tap_finds_the_nearest_node_within_slop() -> void:
	# The drawn dot is 7px; the tap target has to be far larger than that.
	var view := SkillTreeViewScript.new()
	add_child_autofree(view)
	view.tree = _game.ctx.tree
	view._pan = Vector2.ZERO
	var node: SkillNodeDef = _game.ctx.tree.nodes[0]
	assert_eq(view.node_at(node.position + Vector2(5, 5)), node.id)


func test_a_tap_far_from_everything_selects_nothing() -> void:
	var view := SkillTreeViewScript.new()
	add_child_autofree(view)
	view.tree = _game.ctx.tree
	assert_eq(view.node_at(Vector2(99999, 99999)), &"")


func test_navigation_returns_to_the_map() -> void:
	_screen._on_close_pressed()
	assert_not_null(_game._map)
	assert_null(_game._tree_screen)
