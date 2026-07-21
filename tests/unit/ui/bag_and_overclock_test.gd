## Chipsets: where they come from, what they gate, and the Bag that shows them.
##
## The Core is the one sink Scrap cannot reach, so the checks that matter are the ones about
## not lying to the player: a Chipset is never charged for an Overclock that did not happen, a
## Core earned survives a relaunch, and an id this build no longer ships does not linger.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const StageRunnerScript := preload("res://src/core/stages/stage_runner.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")

var _game: V1Game


func _make_game(backend = null) -> V1Game:
	var game: V1Game = V1GameScript.new()
	game.save_backend = backend if backend != null else MemoryBackend.new()
	add_child_autofree(game)
	return game


func before_each() -> void:
	_game = _make_game()


func _settle_clear(stage_id: StringName) -> StageRunnerScript.Result:
	var stage := _game.ctx.stages.get_stage(stage_id)
	var runner := StageRunnerScript.new(stage, _game.ctx.species, _game.ctx.skills,
		_game.ctx.tree, _game.ctx.balance, RandomNumberGenerator.new(), null, _game.ctx.items)
	var result := StageRunnerScript.Result.new()
	runner.settle(result, true)
	runner.award(result, _game.ctx.wallet, _game.ctx.progress, [], _game.ctx.inventory_items,
		_game.ctx.blueprints, _game.ctx.key_items)
	return result


# ---------------------------------------------------------------------------
# The faucet
# ---------------------------------------------------------------------------

func test_clearing_a_dungeon_pays_a_chipset() -> void:
	var result := _settle_clear(&"stage_05")  # a dungeon
	assert_eq(result.cores_earned, 1)
	assert_eq(_game.ctx.key_items.count(KeyItems.CHIPSET), 1)


func test_a_plain_stage_pays_no_chipset() -> void:
	# If every stage paid one, the rarity ceiling would be a formality rather than a reason
	# to go back to a boss.
	var result := _settle_clear(&"stage_01")
	assert_eq(result.cores_earned, 0)
	assert_eq(_game.ctx.key_items.count(KeyItems.CHIPSET), 0)


func test_a_dungeon_pays_again_on_a_replay() -> void:
	_settle_clear(&"stage_05")
	_settle_clear(&"stage_05")
	assert_eq(_game.ctx.key_items.count(KeyItems.CHIPSET), 2,
		"a boss stays worth returning to")


# ---------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------

func _rare_at_final_mark() -> SymbotInstance:
	var inst: SymbotInstance = SymbotInstanceScript.new()
	inst.instance_id = &"oc_test"
	inst.species_id = &"voltfang"  # Rare, so it has an overclock allowance
	inst.mark = SymbotInstanceScript.MAX_MARK
	var cap: int = SymbotInstanceScript.MARK_CAPS[SymbotInstanceScript.MAX_MARK - 1]
	inst.level = cap
	inst.part_levels = PackedInt32Array([cap, cap, cap, cap, cap])
	_game.ctx.roster.symbots.append(inst)
	return inst


func test_overclock_is_refused_without_a_chipset() -> void:
	var inst := _rare_at_final_mark()
	_game.show_workshop()
	_game._workshop._on_symbot_selected(inst)

	assert_true(inst.can_overclock(5), "the Symbot itself has earned it")
	assert_false(_game._workshop._can_gen_up(), "but there is no Core to spend")
	assert_true(_game._workshop._gen_requirement_text().contains("Chipset"),
		"and the notice says so")


func test_overclock_spends_exactly_one_chipset() -> void:
	var inst := _rare_at_final_mark()
	_game.ctx.key_items.add(KeyItems.CHIPSET, 2)
	_game.show_workshop()
	_game._workshop._on_symbot_selected(inst)
	assert_true(_game._workshop._can_gen_up())

	_game._workshop._on_gen_up_pressed()

	assert_eq(inst.overclock, 1, "the ceiling moved")
	assert_eq(_game.ctx.key_items.count(KeyItems.CHIPSET), 1, "one Chipset, not two")


func test_a_refused_overclock_keeps_the_chipset() -> void:
	# The wallet-discipline rule, applied to Chipsets: never charged for something that did not
	# happen.
	var inst := _rare_at_final_mark()
	inst.level = 1  # no longer eligible
	_game.ctx.key_items.add(KeyItems.CHIPSET)
	_game.show_workshop()
	_game._workshop._on_symbot_selected(inst)

	_game._workshop._on_gen_up_pressed()

	assert_eq(inst.overclock, 0)
	assert_eq(_game.ctx.key_items.count(KeyItems.CHIPSET), 1, "the Chipset is untouched")


# ---------------------------------------------------------------------------
# Persistence and the Bag
# ---------------------------------------------------------------------------

func test_chipsets_survive_a_relaunch() -> void:
	var backend := MemoryBackend.new()
	var game := _make_game(backend)
	game.ctx.key_items.add(KeyItems.CHIPSET, 3)
	game.save_now()

	var reopened := _make_game(backend)

	assert_eq(reopened.ctx.key_items.count(KeyItems.CHIPSET), 3)


func test_a_key_item_this_build_no_longer_ships_is_dropped() -> void:
	var inv := ItemInventory.new()
	inv.add(&"key_something_cut", 4)
	inv.add(KeyItems.CHIPSET)

	KeyItems.sanitise(inv)

	assert_false(inv.has(&"key_something_cut"), "a phantom item reads as progress and is not")
	assert_true(inv.has(KeyItems.CHIPSET))


func test_the_bag_lists_what_is_owned() -> void:
	_game.ctx.key_items.add(KeyItems.CHIPSET, 2)
	_game.show_bag()
	assert_not_null(_game._bag)
	assert_gt(_game._bag._list.get_child_count(), 0, "the Chipset has a row")


func test_an_empty_bag_says_where_to_look_rather_than_showing_nothing() -> void:
	_game.show_bag()
	assert_gt(_game._bag._list.get_child_count(), 0,
		"an empty panel would read as broken")


func test_the_reward_screen_announces_a_chipset() -> void:
	# Earned in a dungeon, spent in the Workshop — the summary is the only place the player
	# is told it happened.
	var result := _settle_clear(&"stage_05")
	_game.show_reward(result, _game.ctx.stages.get_stage(&"stage_05"))
	var text := ""
	for line in _game._reward._lines.get_children():
		if line is Label:
			text += line.text
	assert_true(text.contains("CHIPSET"), "a Chipset earned and never mentioned is a Chipset lost")
