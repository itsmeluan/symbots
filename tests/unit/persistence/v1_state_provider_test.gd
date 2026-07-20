## V1 roster, wallet and save persistence (Core Design §2, §5.1; ADR-0001).
##
## The tests that matter here are the ones about SURVIVING CHANGE: a save written last
## patch must still load after a species is cut or the tree is reshaped, and it must cost
## the player only the thing that went away — never the whole file.
extends GutTest

const V1StateProviderScript := preload("res://src/persistence/v1_state_provider.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")
const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

var _roster: PlayerRoster
var _wallet: Wallet
var _species: SpeciesCatalog
var _tree: SkillTree
var _spy: SpyLogSink


func before_each() -> void:
	_roster = PlayerRoster.new()
	_wallet = Wallet.new()
	_spy = SpyLogSink.new()
	_species = load("res://assets/data/catalogs/species_catalog.tres")
	_tree = load("res://assets/data/tree/skill_tree.tres")


func _provider(species: SpeciesCatalog = null, tree: SkillTree = null):
	return V1StateProviderScript.new(_roster, _wallet,
		species if species != null else _species,
		tree if tree != null else _tree, _spy)


func _symbot(id: String, species_id: StringName = &"rustcrawler") -> SymbotInstance:
	var s := SymbotInstanceScript.new(StringName(id), species_id)
	s.level = 12
	return s


func _codes() -> Array:
	return _spy.warns.map(func(w): return w.get("code"))


# ---------------------------------------------------------------------------
# Roster
# ---------------------------------------------------------------------------

func test_a_symbot_cannot_be_added_twice() -> void:
	assert_true(_roster.add(_symbot("a")))
	assert_false(_roster.add(_symbot("a")), "the same instance id is one Symbot")
	assert_eq(_roster.symbots.size(), 1)


func test_fielding_a_symbot_already_in_the_squad_moves_it() -> void:
	# Fielding the same unit twice would double its turns and let one healer out-heal a
	# whole enemy team.
	_roster.add(_symbot("a"))
	_roster.set_squad_slot(0, &"a")
	_roster.set_squad_slot(2, &"a")
	assert_eq(_roster.squad[0], &"")
	assert_eq(_roster.squad[2], &"a")
	assert_eq(_roster.squad_size(), 1)


func test_an_unowned_symbot_cannot_be_fielded() -> void:
	assert_false(_roster.set_squad_slot(0, &"ghost"))
	assert_eq(_roster.squad[0], &"")


func test_releasing_a_symbot_clears_its_squad_slot() -> void:
	# A released Symbot still named by a slot is a squad that fields a ghost, and the only
	# symptom is a battle starting one unit short.
	_roster.add(_symbot("a"))
	_roster.set_squad_slot(1, &"a")
	_roster.release(&"a")
	assert_eq(_roster.squad[1], &"")
	assert_eq(_roster.squad_size(), 0)


func test_a_short_handed_squad_is_a_legal_state() -> void:
	_roster.add(_symbot("a"))
	_roster.set_squad_slot(0, &"a")
	assert_eq(_roster.squad_size(), 1, "early game and after a costly run, this is normal")
	assert_false(_roster.is_squad_empty())


# ---------------------------------------------------------------------------
# Wallet
# ---------------------------------------------------------------------------

func test_spending_more_than_you_have_changes_nothing() -> void:
	# A partial spend that empties the balance and leaves the purchase unmade is the worst
	# of both outcomes.
	_wallet.earn(Wallet.SCRAP, 100)
	assert_false(_wallet.spend(Wallet.SCRAP, 150))
	assert_eq(_wallet.scrap, 100)


func test_spending_what_you_have_exactly_works() -> void:
	_wallet.earn(Wallet.SCRAP, 100)
	assert_true(_wallet.spend(Wallet.SCRAP, 100))
	assert_eq(_wallet.scrap, 0)


func test_a_negative_reward_cannot_drain_the_player() -> void:
	# An off-by-one in a reward table should be a no-op, not a charge.
	_wallet.earn(Wallet.SCRAP, 100)
	_wallet.earn(Wallet.SCRAP, -50)
	assert_eq(_wallet.scrap, 100)


func test_the_two_currencies_are_separate_pools() -> void:
	# A conversion rate would collapse "who do I level" and "who do I build" into one
	# decision (§5.1).
	_wallet.earn(Wallet.SCRAP, 100)
	assert_eq(_wallet.alloy, 0)
	assert_false(_wallet.spend(Wallet.ALLOY, 1))


func test_a_balance_change_is_announced() -> void:
	watch_signals(_wallet)
	_wallet.earn(Wallet.SCRAP, 10)
	assert_signal_emitted(_wallet, "balance_changed")


# ---------------------------------------------------------------------------
# Round trip
# ---------------------------------------------------------------------------

func test_a_full_round_trip_preserves_everything_the_player_earned() -> void:
	var a := _symbot("a", &"rustcrawler")
	a.level = 25
	a.mark = 2
	a.allocated_nodes = [&"entry_dps_scrapper_s1", &"entry_dps_scrapper_s2"]
	a.part_levels = PackedInt32Array([5, 6, 7, 8, 9])
	_roster.add(a)
	_roster.add(_symbot("b", &"boltshell"))
	_roster.set_squad_slot(0, &"a")
	_roster.set_squad_slot(3, &"b")
	_wallet.earn(Wallet.SCRAP, 1234)
	_wallet.earn(Wallet.ALLOY, 56)

	var data := _provider().snapshot()

	# A fresh world, as if the game had been closed and reopened.
	_roster = PlayerRoster.new()
	_wallet = Wallet.new()
	_provider().restore(data)

	assert_eq(_roster.symbots.size(), 2)
	var restored := _roster.get_symbot(&"a")
	assert_eq(restored.level, 25)
	assert_eq(restored.mark, 2)
	assert_eq(restored.allocated_nodes.size(), 2)
	assert_eq(Array(restored.part_levels), [5, 6, 7, 8, 9])
	assert_eq(_roster.squad[0], &"a")
	assert_eq(_roster.squad[3], &"b")
	assert_eq(_wallet.scrap, 1234)
	assert_eq(_wallet.alloy, 56)


func test_restore_replaces_rather_than_appends() -> void:
	# Loading a save into a session that already has a roster must not double it.
	_roster.add(_symbot("a"))
	var data := _provider().snapshot()
	_provider().restore(data)
	assert_eq(_roster.symbots.size(), 1)


# ---------------------------------------------------------------------------
# Surviving content change — the point of saving ids, not defs
# ---------------------------------------------------------------------------

func test_a_species_that_no_longer_ships_costs_that_symbot_not_the_save() -> void:
	_roster.add(_symbot("a", &"rustcrawler"))
	_roster.add(_symbot("gone", &"species_that_was_cut"))
	_wallet.earn(Wallet.SCRAP, 500)
	var data := _provider().snapshot()

	_roster = PlayerRoster.new()
	_wallet = Wallet.new()
	_provider().restore(data)

	assert_eq(_roster.symbots.size(), 1, "the cut species is dropped")
	assert_not_null(_roster.get_symbot(&"a"), "and everything else survives")
	assert_eq(_wallet.scrap, 500, "including the currency")
	assert_true(_codes().has(&"save_species_id_unresolved"))


func test_a_squad_slot_naming_a_dropped_symbot_is_pruned() -> void:
	_roster.add(_symbot("gone", &"species_that_was_cut"))
	_roster.set_squad_slot(1, &"gone")
	var data := _provider().snapshot()

	_roster = PlayerRoster.new()
	_provider().restore(data)

	assert_eq(_roster.squad[1], &"", "the squad must never field a ghost")
	assert_true(_codes().has(&"save_squad_entries_pruned"))


func test_tree_nodes_that_no_longer_exist_are_dropped_and_refunded() -> void:
	# A tree reshape must not leave a player paying points for nodes that are gone.
	var a := _symbot("a")
	a.level = 12
	a.allocated_nodes = [&"entry_dps_scrapper_s1", &"node_deleted_last_patch"]
	_roster.add(a)
	var data := _provider().snapshot()

	_roster = PlayerRoster.new()
	_provider().restore(data)

	var restored := _roster.get_symbot(&"a")
	assert_eq(restored.allocated_nodes.size(), 1, "the missing node is dropped")
	assert_eq(TreeAllocator.unspent_points(restored), 10,
		"and the point comes back — 11 earned, 1 still spent")
	assert_true(_codes().has(&"save_tree_nodes_dropped"))


func test_hardware_fitted_to_a_deleted_socket_is_not_left_orphaned() -> void:
	# Left behind, it would be invisible AND unrecoverable: the player could never open
	# that socket again to pull it back out.
	var a := _symbot("a")
	a.installed_items[&"socket_deleted_last_patch"] = &"item_servo_t1"
	a.installed_items[&"entry_dps_scrapper_socket"] = &"item_ram_chip_t1"
	a.allocated_nodes = [&"node_deleted_last_patch"]
	_roster.add(a)
	var data := _provider().snapshot()

	_roster = PlayerRoster.new()
	_provider().restore(data)

	var restored := _roster.get_symbot(&"a")
	assert_false(restored.installed_items.has(&"socket_deleted_last_patch"))
	assert_true(restored.installed_items.has(&"entry_dps_scrapper_socket"),
		"hardware in a socket that still exists is untouched")


func test_a_corrupt_entry_is_skipped_rather_than_failing_the_load() -> void:
	_provider().restore({"symbots": ["not a dictionary", null], "squad": [], "wallet": {}})
	assert_eq(_roster.symbots.size(), 0, "garbage is skipped")


func test_an_empty_save_restores_a_clean_world() -> void:
	_provider().restore({})
	assert_eq(_roster.symbots.size(), 0)
	assert_eq(_wallet.scrap, 0)
	assert_true(_roster.is_squad_empty())


func test_json_float_numbers_come_back_as_integers() -> void:
	# JSON has no int type; leaving level as 25.0 poisons every comparison downstream
	# (ADR-0001 implementation guideline).
	_provider().restore({
		"symbots": [{"instance_id": "a", "species_id": "rustcrawler", "level": 25.0,
			"mark": 2.0, "xp": 100.0, "part_levels": [1.0, 1.0, 1.0, 1.0, 1.0]}],
		"squad": [], "wallet": {"scrap": 500.0, "alloy": 7.0},
	})
	var restored := _roster.get_symbot(&"a")
	assert_not_null(restored)
	assert_typeof(restored.level, TYPE_INT)
	assert_eq(restored.level, 25)
	assert_typeof(_wallet.scrap, TYPE_INT)
	assert_eq(_wallet.scrap, 500)
