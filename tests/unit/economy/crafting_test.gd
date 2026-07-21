## Blueprints, crafting, and the Alloy loop (Core Design §5.1, §6.2).
##
## Closes the collection loop: beat a boss → learn its blueprint → spend Alloy → own the
## species. The checks that matter are the ones about NOT cheating the player: a craft that
## charged Alloy without adding the Symbot, a blueprint re-announced on every replay, a
## boss whose chest promised a blueprint and delivered nothing.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const CraftingServiceScript := preload("res://src/core/economy/crafting_service.gd")
const StageRunnerScript := preload("res://src/core/stages/stage_runner.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")

var _species: SpeciesCatalog


func before_each() -> void:
	_species = load("res://assets/data/catalogs/species_catalog.tres")


func _game() -> V1Game:
	var g: V1Game = V1GameScript.new()
	g.save_backend = MemoryBackend.new()
	add_child_autofree(g)
	return g


# ---------------------------------------------------------------------------
# BlueprintLibrary
# ---------------------------------------------------------------------------

func test_unlocking_a_blueprint_reports_new_only_the_first_time() -> void:
	# A boss replayed for Scrap must not re-announce a blueprint the player already owns.
	var lib := BlueprintLibrary.new()
	assert_true(lib.unlock(&"ironmaul"), "first time is new")
	assert_false(lib.unlock(&"ironmaul"), "second time is not")
	assert_true(lib.has_blueprint(&"ironmaul"))


func test_known_ids_come_back_sorted() -> void:
	# StringName sorts by pointer, not text; a list screen must not reshuffle between runs.
	var lib := BlueprintLibrary.new()
	lib.unlock(&"voltfang")
	lib.unlock(&"boltshell")
	assert_eq(lib.known_ids()[0], &"boltshell")


func test_a_blueprint_change_is_announced() -> void:
	var lib := BlueprintLibrary.new()
	watch_signals(lib)
	lib.unlock(&"ironmaul")
	assert_signal_emitted(lib, "blueprint_unlocked")


func test_a_phantom_blueprint_is_dropped_on_load() -> void:
	# A recipe for a species that no longer ships would show a craftable the game cannot
	# resolve.
	var lib := BlueprintLibrary.from_dict(
		{"unlocked": ["ironmaul", "a_species_that_was_cut"]}, _species)
	assert_true(lib.has_blueprint(&"ironmaul"))
	assert_false(lib.has_blueprint(&"a_species_that_was_cut"))


# ---------------------------------------------------------------------------
# CraftingService
# ---------------------------------------------------------------------------

func test_a_locked_blueprint_cannot_be_crafted() -> void:
	# "Locked" and "cannot afford" are different next actions — find the boss vs grind Alloy.
	var lib := BlueprintLibrary.new()
	var wallet := Wallet.new()
	wallet.earn(Wallet.ALLOY, 99999)
	assert_eq(CraftingServiceScript.can_craft(&"ironmaul", _species, lib, wallet),
		CraftingServiceScript.Refusal.BLUEPRINT_LOCKED)


func test_an_unaffordable_craft_is_refused() -> void:
	var lib := BlueprintLibrary.new()
	lib.unlock(&"ironmaul")
	var wallet := Wallet.new()  # empty
	assert_eq(CraftingServiceScript.can_craft(&"ironmaul", _species, lib, wallet),
		CraftingServiceScript.Refusal.CANNOT_AFFORD)


func test_crafting_charges_alloy_and_adds_a_fresh_mk1() -> void:
	var lib := BlueprintLibrary.new()
	lib.unlock(&"ironmaul")
	var wallet := Wallet.new()
	var cost := CraftingServiceScript.alloy_cost(&"ironmaul", _species)
	wallet.earn(Wallet.ALLOY, cost + 50)
	var roster := PlayerRoster.new()

	var inst := CraftingServiceScript.craft(&"ironmaul", _species, lib, wallet, roster, 1)

	assert_not_null(inst)
	assert_eq(wallet.alloy, 50, "charged exactly the cost")
	assert_eq(roster.symbots.size(), 1)
	assert_eq(inst.species_id, &"ironmaul")
	assert_eq(inst.mark, 1, "a crafted Symbot starts at Mk I…")
	assert_eq(inst.level, 1, "…and level 1 — crafting gives the species, not a shortcut")


func test_crafting_is_repeatable_for_multiple_copies() -> void:
	# §4.2: a player may own several of the same species, built differently. Each copy gets
	# a unique id so the second does not collide with the first.
	var lib := BlueprintLibrary.new()
	lib.unlock(&"rustcrawler")
	var wallet := Wallet.new()
	wallet.earn(Wallet.ALLOY, 10000)
	var roster := PlayerRoster.new()

	var a := CraftingServiceScript.craft(&"rustcrawler", _species, lib, wallet, roster, 1)
	var b := CraftingServiceScript.craft(&"rustcrawler", _species, lib, wallet, roster, 2)

	assert_eq(roster.symbots.size(), 2)
	assert_ne(a.instance_id, b.instance_id, "two copies, two ids")


func test_a_refused_craft_does_not_touch_the_wallet() -> void:
	var lib := BlueprintLibrary.new()  # locked
	var wallet := Wallet.new()
	wallet.earn(Wallet.ALLOY, 500)
	var roster := PlayerRoster.new()
	assert_null(CraftingServiceScript.craft(&"ironmaul", _species, lib, wallet, roster, 1))
	assert_eq(wallet.alloy, 500, "not charged for a build that never happened")
	assert_eq(roster.symbots.size(), 0)


# ---------------------------------------------------------------------------
# The chest actually delivers Alloy and the blueprint
# ---------------------------------------------------------------------------

func _settle_clear(g: V1Game, stage_id: StringName) -> StageRunnerScript.Result:
	# Settle a cleared run directly rather than fighting: the reward arithmetic is what is
	# under test, and a real fight would be nondeterministic and slow.
	var stage := g.ctx.stages.get_stage(stage_id)
	var runner := StageRunnerScript.new(stage, g.ctx.species, g.ctx.skills, g.ctx.tree,
		g.ctx.balance, RandomNumberGenerator.new(), null, g.ctx.items)
	var result := StageRunnerScript.Result.new()
	runner.settle(result, true)
	runner.award(result, g.ctx.wallet, g.ctx.progress, [], g.ctx.inventory_items, g.ctx.blueprints)
	return result


func test_a_boss_chest_grants_alloy_and_teaches_its_blueprint() -> void:
	var g := _game()
	var stage := g.ctx.stages.get_stage(&"stage_05")  # a dungeon with a blueprint
	assert_ne(stage.chest_blueprint_id, &"", "precondition: stage_05 has a blueprint")

	_settle_clear(g, &"stage_05")

	assert_gt(g.ctx.wallet.alloy, 0, "a boss chest pays Alloy")
	assert_true(g.ctx.blueprints.has_blueprint(stage.chest_blueprint_id),
		"and teaches the blueprint")


func test_a_plain_stage_pays_no_alloy() -> void:
	# Alloy is the rare currency — only bosses (dungeons) give it, or it stops being rare.
	var g := _game()
	_settle_clear(g, &"stage_01")
	assert_eq(g.ctx.wallet.alloy, 0)


func test_the_blueprint_is_announced_only_on_the_first_clear() -> void:
	var g := _game()
	var stage := g.ctx.stages.get_stage(&"stage_05")
	var runner := StageRunnerScript.new(stage, g.ctx.species, g.ctx.skills, g.ctx.tree,
		g.ctx.balance, RandomNumberGenerator.new(), null, g.ctx.items)

	var first := StageRunnerScript.Result.new()
	runner.settle(first, true)
	runner.award(first, g.ctx.wallet, g.ctx.progress, [], g.ctx.inventory_items, g.ctx.blueprints)
	assert_true(first.blueprint_was_new, "first clear teaches it")

	var second := StageRunnerScript.Result.new()
	runner.settle(second, true)
	runner.award(second, g.ctx.wallet, g.ctx.progress, [], g.ctx.inventory_items, g.ctx.blueprints)
	assert_false(second.blueprint_was_new, "a replay does not re-teach it")


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func test_blueprints_and_alloy_survive_a_relaunch() -> void:
	var backend := MemoryBackend.new()
	var g: V1Game = V1GameScript.new()
	g.save_backend = backend
	add_child_autofree(g)
	g.ctx.blueprints.unlock(&"ironmaul")
	g.ctx.wallet.earn(Wallet.ALLOY, 250)
	g.save_now()

	var reopened: V1Game = V1GameScript.new()
	reopened.save_backend = backend
	add_child_autofree(reopened)

	assert_true(reopened.ctx.blueprints.has_blueprint(&"ironmaul"))
	assert_eq(reopened.ctx.wallet.alloy, 250)


# ---------------------------------------------------------------------------
# The Foundry screen
# ---------------------------------------------------------------------------

func test_the_foundry_lists_the_whole_roster_including_locked() -> void:
	# It is the collection board — seeing what you have not caught is the point.
	var g := _game()
	g.show_foundry()
	assert_eq(g._foundry._list.get_child_count(), g.ctx.species.entries.size())


func test_a_locked_species_shows_how_to_unlock_it_not_a_dead_button() -> void:
	var g := _game()
	g.show_foundry()
	# Rows are panelled now, so gather every Label in the subtree rather than the top level.
	var text := _all_label_text(g._foundry._list)
	assert_true(text.contains("Blueprint not found"),
		"a locked species names its state rather than sitting blank")


func _all_label_text(node: Node) -> String:
	var text := ""
	for child in node.get_children():
		if child is Label:
			text += child.text
		text += _all_label_text(child)
	return text


func test_crafting_through_the_foundry_adds_the_symbot() -> void:
	var g := _game()
	g.ctx.blueprints.unlock(&"rapierbill")
	g.ctx.wallet.earn(Wallet.ALLOY, 10000)
	var before := g.ctx.roster.symbots.size()
	g.show_foundry()

	g._foundry._on_craft_pressed(&"rapierbill")

	assert_eq(g.ctx.roster.symbots.size(), before + 1)
	assert_true(g.ctx.roster.symbots.any(func(s): return s.species_id == &"rapierbill"))


func test_the_foundry_is_reachable_from_the_map_and_returns() -> void:
	var g := _game()
	g._map._on_foundry_pressed()
	assert_not_null(g._foundry)
	g._foundry._on_close_pressed()
	assert_not_null(g._map)
	assert_null(g._foundry)


func test_every_boss_blueprint_is_a_real_craftable_species() -> void:
	# The bug this pins: a chest_blueprint_id authored as "blueprint_boltshell" while the
	# Foundry keys crafting on the species id "boltshell" means the boss teaches a recipe
	# nothing can build. Every stage blueprint must resolve to a species, so learning it
	# actually unlocks a craft.
	var stages: StageCatalog = load("res://assets/data/catalogs/stage_catalog.tres")
	for stage in stages.entries:
		if stage.chest_blueprint_id != &"":
			assert_not_null(_species.get_species(stage.chest_blueprint_id),
				"%s drops blueprint %s, which is not a craftable species"
					% [stage.id, stage.chest_blueprint_id])
