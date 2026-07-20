## UnitBuilder + StageRunner — the loop end to end (Core Design §2, §3, §6).
##
## This is the integration seam: owned Symbots become combatants, stages become battles,
## wins become Scrap. Most of what is pinned here is about the FOUR progression axes
## actually reaching the battlefield — if levelling a part or allocating a node did not
## change a unit's numbers, every other system in the game would still pass its own tests
## while the game itself was inert.
extends GutTest

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const StageDefScript := preload("res://src/core/stages/stage_def.gd")
const StageRunnerScript := preload("res://src/core/stages/stage_runner.gd")
const BattleEngineScript := preload("res://src/core/battle_v1/battle_engine.gd")
const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

var _species: SpeciesCatalog
var _skills: Dictionary
var _tree: SkillTree
var _items: Dictionary
var _stages: StageCatalog
var _cfg: BalanceConfig
var _rng: RandomNumberGenerator
var _spy: SpyLogSink


func before_each() -> void:
	_species = load("res://assets/data/catalogs/species_catalog.tres")
	_skills = (load("res://assets/data/catalogs/skill_catalog.tres") as SkillCatalog).to_table()
	_tree = load("res://assets/data/tree/skill_tree.tres")
	_items = (load("res://assets/data/catalogs/install_item_catalog.tres")
		as InstallItemCatalog).to_table()
	_stages = load("res://assets/data/catalogs/stage_catalog.tres")
	_cfg = BalanceConfig.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 99
	_spy = SpyLogSink.new()


func _symbot(id: String, species_id: StringName, level := 1) -> SymbotInstance:
	var s := SymbotInstanceScript.new(StringName(id), species_id)
	s.level = level
	return s


func _build(inst: SymbotInstance, slot := 0) -> BattleUnit:
	return UnitBuilder.build(inst, _species.get_species(inst.species_id), _tree,
		_skills, BattleUnit.Side.PLAYER, slot, _items)


func _runner(stage_id: StringName) -> StageRunner:
	return StageRunnerScript.new(_stages.get_stage(stage_id), _species, _skills, _tree,
		_cfg, _rng, _spy, _items)


# ---------------------------------------------------------------------------
# The four progression axes reach the battlefield
# ---------------------------------------------------------------------------

func test_a_fresh_symbot_matches_its_species_baseline() -> void:
	# Growth is per level ABOVE the first, so a level-1 part contributes nothing and the
	# species baseline is the honest floor rather than a number already inflated.
	var unit := _build(_symbot("a", &"rustcrawler"))
	var species := _species.get_species(&"rustcrawler")
	assert_eq(unit.stat(&"physical_power"), int(species.base_stats[&"physical_power"]))
	assert_eq(unit.max_structure, int(species.base_stats[&"structure"]))


func test_levelling_a_part_raises_the_stats_that_part_feeds() -> void:
	var base := _build(_symbot("a", &"rustcrawler"))
	var levelled_inst := _symbot("a", &"rustcrawler")
	levelled_inst.part_levels[3] = 10  # ARMS
	var levelled := _build(levelled_inst)
	assert_gt(levelled.stat(&"physical_power"), base.stat(&"physical_power"),
		"ARMS feeds physical power on a DPS")


func test_the_same_slot_feeds_different_stats_on_different_roles() -> void:
	# §2.4: part identity is authored per species, which is what stops all eight Symbots
	# being the same chassis with a different sprite.
	var dps := _symbot("a", &"rustcrawler")
	dps.part_levels[1] = 10  # CHASSIS
	var healer := _symbot("b", &"solderfly")
	healer.part_levels[2] = 10  # HEAD
	assert_gt(_build(dps).max_structure,
		_build(_symbot("a2", &"rustcrawler")).max_structure)
	assert_gt(_build(healer).stat(&"processing"),
		_build(_symbot("b2", &"solderfly")).stat(&"processing"))


func test_allocating_a_tree_node_reaches_the_unit() -> void:
	var inst := _symbot("a", &"rustcrawler", 10)
	var before := _build(inst).stat(&"physical_power")
	inst.allocated_nodes = [&"entry_dps_scrapper_s1"]
	assert_gt(_build(inst).stat(&"physical_power"), before,
		"a node the player paid for must change a number they can see")


func test_percentages_apply_over_the_flat_total_not_before() -> void:
	# Otherwise an identical build's stats would depend on the ORDER the player happened
	# to allocate nodes in — the same points producing different Symbots.
	var a := _symbot("a", &"rustcrawler", 30)
	var b := _symbot("b", &"rustcrawler", 30)
	a.allocated_nodes = [&"entry_dps_scrapper_s1", &"entry_dps_scrapper_s2"]
	b.allocated_nodes = [&"entry_dps_scrapper_s2", &"entry_dps_scrapper_s1"]
	assert_eq(_build(a).stat(&"physical_power"), _build(b).stat(&"physical_power"))
	assert_eq(_build(a).max_structure, _build(b).max_structure)


func test_a_fitted_chip_reaches_the_unit_and_a_better_one_reaches_further() -> void:
	var species := _species.get_species(&"rustcrawler")
	var socket_id := StringName("%s_socket" % species.tree_entry_node)
	var node := _tree.get_node_def(socket_id)
	var stat_key: StringName = node.stat_bonus.keys()[0]

	var inst := _symbot("a", &"rustcrawler", 60)
	for step in TreeAllocator.path_to(_tree, inst, species, socket_id):
		if step != socket_id:
			inst.allocated_nodes.append(step)
	inst.allocated_nodes.append(socket_id)

	inst.installed_items[socket_id] = StringName("item_%s_t1" % node.socket_accepts)
	var low := _build(inst).stat(stat_key)
	inst.installed_items[socket_id] = StringName("item_%s_t4" % node.socket_accepts)
	var high := _build(inst).stat(stat_key)

	assert_gt(high, low, "hardware tier must be visible in the fight (%d vs %d)" % [high, low])


# ---------------------------------------------------------------------------
# Skills and slots
# ---------------------------------------------------------------------------

func test_slot_zero_is_always_the_basic_attack() -> void:
	# §3.4: a turn is never wasted.
	var unit := _build(_symbot("a", &"rustcrawler"))
	assert_eq(unit.skills[0], _species.get_species(&"rustcrawler").basic_attack_id)


func test_the_species_starting_kit_is_fielded() -> void:
	var unit := _build(_symbot("a", &"rustcrawler"))
	assert_true(unit.skills.has(&"skill_rend"))
	assert_eq(unit.ultimate_skill, &"ult_scrap_storm")


func test_the_ultimate_never_occupies_an_active_slot() -> void:
	# §3.4b gives it a dedicated slot; letting it compete would mean most players never
	# field one.
	var unit := _build(_symbot("a", &"rustcrawler"))
	assert_false(unit.skills.has(unit.ultimate_skill))


func test_a_duplicated_skill_grant_is_not_fielded_twice() -> void:
	# Two tree nodes can legitimately grant the same skill; a doubled entry would render
	# as two buttons sharing one cooldown.
	var inst := _symbot("a", &"rustcrawler", 40)
	# The scrapper cluster's ACTIVE grants skill_rend, which the species already has.
	for step in TreeAllocator.path_to(_tree, inst, _species.get_species(&"rustcrawler"),
			&"entry_dps_scrapper_active"):
		inst.allocated_nodes.append(step)
	var unit := _build(inst)
	var count := 0
	for s in unit.skills:
		if s == &"skill_rend":
			count += 1
	assert_eq(count, 1)


func test_a_side_is_numbered_by_position_not_by_squad_slot() -> void:
	# A squad with a gap must not leave a hole the turn-order tie-break reads as a real
	# slot.
	var units := UnitBuilder.build_side(
		[_symbot("a", &"rustcrawler"), _symbot("b", &"boltshell")],
		_species, _tree, _skills, BattleUnit.Side.PLAYER, _items)
	assert_eq(units[0].slot, 0)
	assert_eq(units[1].slot, 1)


func test_a_symbot_of_an_unknown_species_is_skipped_not_crashed() -> void:
	var units := UnitBuilder.build_side(
		[_symbot("ghost", &"species_that_was_cut"), _symbot("a", &"rustcrawler")],
		_species, _tree, _skills, BattleUnit.Side.PLAYER, _items)
	assert_eq(units.size(), 1)


# ---------------------------------------------------------------------------
# Running a stage
# ---------------------------------------------------------------------------

func _strong_squad() -> Array:
	var squad: Array = []
	for pair in [["p0", &"ironmaul"], ["p1", &"rustcrawler"], ["p2", &"voltfang"],
			["p3", &"solderfly"]]:
		var s := _symbot(pair[0], pair[1], 40)
		for i in SymbotInstanceScript.PART_COUNT:
			s.part_levels[i] = 20
		squad.append(s)
	return squad


func test_a_strong_squad_clears_the_first_stage_and_gets_paid() -> void:
	var runner := _runner(&"stage_01")
	var result := runner.run_auto(_strong_squad())
	assert_true(result.cleared)
	assert_eq(result.battles_won, 1)
	assert_gt(result.scrap_earned, 0)


func test_clearing_pays_the_battle_reward_plus_the_chest() -> void:
	var stage := _stages.get_stage(&"stage_01")
	var runner := _runner(&"stage_01")
	var result := runner.run_auto(_strong_squad())
	assert_eq(result.scrap_earned,
		UpgradeEconomy.battle_reward(stage.stage_level, _cfg)
		+ UpgradeEconomy.chest_reward(stage.stage_level, _cfg))


func test_an_empty_squad_earns_nothing_rather_than_crashing() -> void:
	var result := _runner(&"stage_01").run_auto([])
	assert_false(result.cleared)
	assert_eq(result.scrap_earned, 0)


func test_losing_costs_the_chest_but_not_what_already_dropped() -> void:
	# §6: defeat costs the chest and the time, never the session.
	var weak := [_symbot("p0", &"solderfly", 1)]
	var runner := _runner(&"stage_10")  # a dungeon well past a level-1 healer
	var result := runner.run_auto(weak)
	assert_false(result.cleared)
	assert_true(result.chest_items.is_empty(), "no chest")
	assert_eq(result.chest_blueprint, &"")


func test_a_dungeon_runs_every_battle_in_sequence() -> void:
	var stage := _stages.get_stage(&"stage_05")
	var result := _runner(&"stage_05").run_auto(_strong_squad())
	assert_true(result.cleared, "the slice's strong squad should clear stage 05")
	assert_eq(result.battles_won, stage.battle_count())
	assert_eq(result.battles.size(), stage.battle_count())


func test_a_dungeon_carries_damage_between_rooms() -> void:
	# This IS the difference between a dungeon and a run of separate stages (§3.6).
	var squad := _strong_squad()
	var result := _runner(&"stage_05").run_auto(squad)
	assert_gt(result.battles_won, 1, "precondition: more than one room was fought")
	var second: BattleEngine = result.battles[1]
	var started_hurt := false
	for u in second.player_units:
		if u.current_structure < u.max_structure:
			started_hurt = true
	assert_true(started_hurt, "somebody should still be carrying damage into room two")


func test_awarding_moves_the_money_and_marks_the_stage() -> void:
	# settle() and award() are split so a reward screen can be shown before the numbers
	# actually move.
	var wallet := Wallet.new()
	var progress := StageProgress.new()
	var runner := _runner(&"stage_01")
	var result := runner.run_auto(_strong_squad())

	assert_eq(wallet.scrap, 0, "settling alone must not pay")
	runner.award(result, wallet, progress)
	assert_eq(wallet.scrap, result.scrap_earned)
	assert_true(progress.is_cleared(&"stage_01"))


func test_a_loss_does_not_mark_the_stage_cleared() -> void:
	var wallet := Wallet.new()
	var progress := StageProgress.new()
	var runner := _runner(&"stage_10")
	var result := runner.run_auto([_symbot("p0", &"solderfly", 1)])
	runner.award(result, wallet, progress)
	assert_false(progress.is_cleared(&"stage_10"))


func test_every_shipped_stage_can_be_built_into_battles() -> void:
	# A stage that cannot produce a fight is a dead end nothing else would report.
	for stage in _stages.entries:
		var runner := StageRunnerScript.new(stage, _species, _skills, _tree, _cfg, _rng, _spy)
		var units := UnitBuilder.build_side(_strong_squad(), _species, _tree, _skills,
			BattleUnit.Side.PLAYER, _items)
		for i in stage.battle_count():
			assert_not_null(runner.build_battle(units, i),
				"%s battle %d produced no engine" % [stage.id, i])
