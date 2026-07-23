## Reward screen and the item inventory (Core Design §4.4, §6).
##
## Closes a hole worth naming: chests listed items in the run result and handed over
## nothing, because no inventory existed to hand them to. Every "the chest actually
## delivers" check below would have passed vacuously before.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const StageRunnerScript := preload("res://src/core/stages/stage_runner.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

var _game: V1Game


func _make_game(backend = null) -> V1Game:
	var game: V1Game = V1GameScript.new()
	game.save_backend = backend if backend != null else MemoryBackend.new()
	# Battles resolve synchronously under test — pacing is theatre, not logic.
	game.battle_turn_pace = 0.0
	add_child_autofree(game)
	return game


func before_each() -> void:
	_game = _make_game()


func after_each() -> void:
	_game = null


func _strengthen_squad() -> void:
	for s in _game.ctx.roster.squad_symbots():
		s.level = 40
		for i in SymbotInstanceScript.PART_COUNT:
			s.part_levels[i] = 20


# ---------------------------------------------------------------------------
# ItemInventory
# ---------------------------------------------------------------------------

func test_adding_and_taking_items() -> void:
	var inv := ItemInventory.new()
	inv.add(&"item_servo_t1", 3)
	assert_eq(inv.count(&"item_servo_t1"), 3)
	assert_true(inv.take(&"item_servo_t1", 2))
	assert_eq(inv.count(&"item_servo_t1"), 1)


func test_taking_more_than_you_own_changes_nothing() -> void:
	# A partial take would leave a socket half-paid.
	var inv := ItemInventory.new()
	inv.add(&"item_servo_t1", 1)
	assert_false(inv.take(&"item_servo_t1", 2))
	assert_eq(inv.count(&"item_servo_t1"), 1)


func test_an_emptied_entry_is_erased_rather_than_kept_at_zero() -> void:
	# So has() and count() > 0 can never disagree.
	var inv := ItemInventory.new()
	inv.add(&"item_servo_t1", 1)
	inv.take(&"item_servo_t1", 1)
	assert_false(inv.has(&"item_servo_t1"))
	assert_false(inv.counts.has(&"item_servo_t1"))


func test_owned_ids_come_back_in_a_stable_order() -> void:
	# A list screen must not reshuffle because of the order drops happened to arrive in.
	var inv := ItemInventory.new()
	inv.add(&"item_servo_t1")
	inv.add(&"item_processor_t1")
	assert_eq(inv.owned_ids(), inv.owned_ids())
	assert_eq(inv.owned_ids()[0], &"item_processor_t1", "sorted, not insertion-ordered")


func test_a_change_is_announced() -> void:
	var inv := ItemInventory.new()
	watch_signals(inv)
	inv.add(&"item_servo_t1")
	assert_signal_emitted(inv, "inventory_changed")


func test_items_that_no_longer_ship_are_dropped_on_load() -> void:
	# Unlike a cleared stage id, a phantom item would SHOW in the inventory, be selectable
	# for a socket, and then fail to resolve — worse than simply not being there.
	var catalog: InstallItemCatalog = load("res://assets/data/catalogs/install_item_catalog.tres")
	var restored := ItemInventory.from_dict(
		{"item_servo_t1": 2, "item_that_was_cut": 5}, catalog)
	assert_eq(restored.count(&"item_servo_t1"), 2)
	assert_false(restored.has(&"item_that_was_cut"))


# ---------------------------------------------------------------------------
# The chest actually delivers
# ---------------------------------------------------------------------------

func test_clearing_a_stage_puts_its_chest_items_in_the_inventory() -> void:
	# Before the inventory existed, chest_items was a promise the game did not keep.
	_strengthen_squad()
	var stage := _game.ctx.stages.get_stage(&"stage_02")
	assert_false(stage.chest_item_ids.is_empty(), "precondition: stage_02 has a chest")

	_game._on_stage_chosen(stage)
	_game._battle._on_auto_toggled(true)

	for item_id in stage.chest_item_ids:
		assert_gt(_game.ctx.inventory_items.count(item_id), 0,
			"%s was promised and not delivered" % item_id)


func test_losing_delivers_no_chest() -> void:
	var runner := StageRunnerScript.new(_game.ctx.stages.get_stage(&"stage_02"),
		_game.ctx.species, _game.ctx.skills, _game.ctx.tree, _game.ctx.balance,
		RandomNumberGenerator.new(), null, _game.ctx.items)
	var result := StageRunnerScript.Result.new()
	runner.settle(result, false)
	runner.award(result, _game.ctx.wallet, _game.ctx.progress, [], _game.ctx.inventory_items)
	assert_eq(_game.ctx.inventory_items.total_items(), 0)


func test_owned_items_survive_a_relaunch() -> void:
	var backend := MemoryBackend.new()
	var game := _make_game(backend)
	game.ctx.inventory_items.add(&"item_heat_sink_t2", 4)
	game.save_now()

	var reopened := _make_game(backend)
	assert_eq(reopened.ctx.inventory_items.count(&"item_heat_sink_t2"), 4)


# ---------------------------------------------------------------------------
# The reward screen
# ---------------------------------------------------------------------------

func test_winning_shows_a_victory_summary() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	_game._battle._on_auto_toggled(true)
	assert_not_null(_game._reward)
	assert_eq(_game._reward._title.text, "VICTORY")


func test_the_summary_names_what_was_earned() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	_game._battle._on_auto_toggled(true)

	var text := ""
	for line in _game._reward._lines.get_children():
		text += line.text + "\n"
	assert_true(text.contains("Scrap"), "the payout is the point of the screen")
	assert_true(text.contains("XP"))


func test_a_chest_is_listed_by_item_name_not_by_id() -> void:
	# "Copper Sink" is a reward; "item_heat_sink_t2" is a database row.
	var result := StageRunnerScript.Result.new()
	result.cleared = true
	result.chest_items = [&"item_heat_sink_t2"]
	_game.show_reward(result, _game.ctx.stages.get_stage(&"stage_07"))

	var text := ""
	for line in _game._reward._lines.get_children():
		text += line.text + "\n"
	assert_true(text.contains("Copper Sink"), "got: %s" % text)


func test_a_defeat_still_reports_what_was_kept() -> void:
	# §6: a loss costs the chest and the time, never the session. A defeat screen showing
	# nothing would read as "you lost everything", which is not what happened.
	var result := StageRunnerScript.Result.new()
	result.cleared = false
	result.battles_won = 1
	result.scrap_earned = 120
	result.xp_each = 60
	_game.show_reward(result, _game.ctx.stages.get_stage(&"stage_05"))

	assert_eq(_game._reward._title.text, "DEFEAT")
	var text := ""
	for line in _game._reward._lines.get_children():
		text += line.text + "\n"
	assert_true(text.contains("120"), "the Scrap that was kept is still shown")
	assert_true(text.contains("No chest"), "and what was missed is named")


func test_zero_levels_gained_is_not_shown_as_a_line() -> void:
	# "Levels +0" is noise that makes the line the player cares about harder to find.
	var result := StageRunnerScript.Result.new()
	result.cleared = true
	result.levels_gained = 0
	_game.show_reward(result, _game.ctx.stages.get_stage(&"stage_01"))

	for line in _game._reward._lines.get_children():
		assert_false(line.text.contains("Levels"), "got '%s'" % line.text)


func test_the_reward_screen_can_be_dismissed_back_to_the_map() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	_game._battle._on_auto_toggled(true)
	_game._reward._on_continue_pressed()
	assert_not_null(_game._map)
	assert_null(_game._reward)
