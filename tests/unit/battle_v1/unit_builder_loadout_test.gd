## UnitBuilder — the skill loadout (Core Design §3.4).
##
## The tree can teach MORE actives than the three battle slots hold, so the player picks
## which three field via `SymbotInstance.active_skills`. These pin the contract the reward
## for that choice depends on: the picked three are fielded, and an empty loadout still
## falls back to a sensible default rather than an empty bar.
extends GutTest

const UnitBuilderScript := preload("res://src/core/battle_v1/unit_builder.gd")
const SkillDefScript := preload("res://src/core/battle_v1/skill_def.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")


func _skill(id: StringName) -> SkillDef:
	var s := SkillDef.new()
	s.id = id
	s.target_mode = SkillDefScript.TargetMode.SINGLE_ENEMY
	return s


func _skills() -> Dictionary:
	var table: Dictionary = {}
	for id in [&"basic", &"a", &"b", &"c", &"d"]:
		table[id] = _skill(id)
	return table


func _species() -> SpeciesDef:
	var s := SpeciesDef.new()
	s.id = &"toy"
	s.basic_attack_id = &"basic"
	s.starting_skills.assign([&"a", &"b", &"c", &"d"])  # four learned, only three fit
	s.base_stats[&"structure"] = 100
	s.base_stats[&"physical_power"] = 10
	return s


func _inst() -> SymbotInstance:
	return SymbotInstance.new(&"i1", &"toy")


func _fielded(inst: SymbotInstance) -> Array:
	var unit := UnitBuilderScript.build(
		inst, _species(), null, _skills(), BattleUnit.Side.PLAYER, 0)
	return Array(unit.skills)


func test_learned_actives_lists_the_whole_pool_minus_basic_and_ults() -> void:
	var learned := UnitBuilderScript.learned_actives(_inst(), _species(), null, _skills())
	assert_eq(Array(learned), [&"a", &"b", &"c", &"d"],
		"the picker offers every learned active, even past the three that fit")


func test_with_no_loadout_the_first_three_learned_are_fielded() -> void:
	# A brand-new Symbot has never chosen — it must still fight with a sensible default.
	assert_eq(_fielded(_inst()), [&"basic", &"a", &"b", &"c"])


func test_the_chosen_loadout_is_fielded_over_the_default_order() -> void:
	var inst := _inst()
	inst.active_skills[0] = &"d"
	inst.active_skills[1] = &"b"
	inst.active_skills[2] = &"a"
	assert_eq(_fielded(inst), [&"basic", &"d", &"b", &"a"],
		"the player's picks are fielded, not the first three in learn order")


func test_an_empty_or_unlearned_slot_in_the_loadout_is_ignored() -> void:
	var inst := _inst()
	inst.active_skills[0] = &"d"
	inst.active_skills[1] = &""       # unfilled slot
	inst.active_skills[2] = &"ghost"  # a skill this Symbot never learned
	assert_eq(_fielded(inst), [&"basic", &"d"],
		"only the one valid pick is fielded — junk in active_skills never reaches the field")
