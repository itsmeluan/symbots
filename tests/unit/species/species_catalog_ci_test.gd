## Species + skill catalog CI gate (Core Design §2, §3.4b).
##
## Two jobs. First, run the validator over the SHIPPED catalogs and demand zero errors —
## this is the gate that stops a broken species reaching a build. Second, pin the
## validator's own rules with hand-built bad content, because a validator that silently
## stops checking is worse than no validator: the suite stays green and the guarantee is
## gone.
extends GutTest

const SpeciesDefScript := preload("res://src/core/species/species_def.gd")
const SkillDefScript := preload("res://src/core/battle_v1/skill_def.gd")
const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

const SPECIES_CATALOG_PATH := "res://assets/data/catalogs/species_catalog.tres"
const SKILL_CATALOG_PATH := "res://assets/data/catalogs/skill_catalog.tres"

## The slice roster, pinned by name. A species silently dropped from the catalog would
## otherwise pass every other check in this file.
const EXPECTED_SPECIES: Array[StringName] = [
	&"rustcrawler", &"voltfang", &"boltshell", &"ironmaul",
	&"solderfly", &"nanoweave", &"coilsprite", &"hexcircuit",
	&"quillrack", &"rapierbill", &"foldscale", &"slaghorn",
	&"candlestag", &"mosshollow", &"cogwatch", &"splicewyrm",
]

const EXPECTED_SKILL_COUNT := 34

var _spy: SpyLogSink
var _species: SpeciesCatalog
var _skills: SkillCatalog


func before_each() -> void:
	_spy = SpyLogSink.new()
	_species = load(SPECIES_CATALOG_PATH)
	_skills = load(SKILL_CATALOG_PATH)


# ---------------------------------------------------------------------------
# The shipped content
# ---------------------------------------------------------------------------

func test_the_shipped_catalogs_validate_with_no_errors() -> void:
	var errors := SpeciesValidator.validate(_species, _skills, _spy)
	assert_eq(errors, 0, "shipped species content must be clean")
	assert_eq(_spy.errors.size(), 0, "and nothing reached the error channel")


func test_the_shipped_catalogs_raise_no_warnings() -> void:
	SpeciesValidator.validate(_species, _skills, _spy)
	assert_eq(_spy.warns.size(), 0, "a warning today is an error once content grows")


func test_the_roster_is_exactly_the_sixteen_authored_species() -> void:
	var ids: Array = _species.entries.map(func(s): return s.id)
	for expected in EXPECTED_SPECIES:
		assert_true(ids.has(expected), "%s is missing from the catalog" % expected)
	assert_eq(_species.entries.size(), EXPECTED_SPECIES.size())


func test_every_role_has_four_species() -> void:
	# Four per role at full roster (§2.1): the choice of which to field is the strategy.
	for role in SpeciesValidator.REQUIRED_ROLES:
		assert_eq(_species.by_role(role).size(), 4,
			"role %d should have exactly 4 species at full roster" % role)


func test_every_species_enters_the_tree_at_its_own_point() -> void:
	var entries: Array = _species.entries.map(func(s): return s.tree_entry_node)
	var unique: Dictionary = {}
	for e in entries:
		unique[e] = true
	assert_eq(unique.size(), _species.entries.size(),
		"all sixteen species enter at distinct points, so all sixteen tree doors are used")


func test_the_skill_catalog_ships_the_expected_count() -> void:
	assert_eq(_skills.entries.size(), EXPECTED_SKILL_COUNT)


func test_every_skill_id_is_unique() -> void:
	var seen: Dictionary = {}
	for s in _skills.entries:
		assert_false(seen.has(s.id), "duplicate skill id %s" % s.id)
		seen[s.id] = true


func test_the_skill_table_resolves_every_id() -> void:
	# The engine is handed this table; an id that does not resolve is a skill that does
	# nothing when used.
	var table := _skills.to_table()
	assert_eq(table.size(), _skills.entries.size())
	for s in _skills.entries:
		assert_eq(table.get(s.id), s)


func test_every_ultimate_is_charge_gated_and_costs_something() -> void:
	for s in _skills.entries:
		if s.is_ultimate:
			assert_true(s.uses_charge(), "%s is an ult so it must use charge" % s.id)
			assert_gt(s.charge_cost, 0,
				"%s costs 0 charge, so it would be usable on turn one" % s.id)


func test_basic_attacks_have_no_cooldown() -> void:
	# Design §3.4: a turn is never wasted, which requires the basic attack always be up.
	for id in [&"basic_strike", &"basic_pulse"]:
		var s := _skills.get_skill(id)
		assert_not_null(s, "%s must exist" % id)
		assert_eq(s.cooldown, 0, "%s must always be available" % id)


func test_authored_effect_dicts_use_string_keys() -> void:
	# Godot hashes "kind" and &"kind" as DIFFERENT keys. If authored content used
	# StringName keys, the engine's String lookup would read the default off every effect
	# and every skill in the game would silently do nothing.
	for s in _skills.entries:
		for effect in s.effects:
			assert_true(effect.has("kind"),
				"%s has an effect with no String \"kind\" key" % s.id)


# ---------------------------------------------------------------------------
# The validator's own rules
# ---------------------------------------------------------------------------

func _minimal_species() -> SpeciesDef:
	var s := SpeciesDef.new()
	s.id = &"probe"
	s.role = SpeciesDefScript.Role.DPS
	s.rarity = SpeciesDefScript.Rarity.COMMON
	s.tree_entry_node = &"entry_probe"
	s.base_stats = {&"structure": 100, &"physical_power": 40, &"energy_power": 10}
	s.part_growth = {0: {&"recharge": 1}, 1: {&"structure": 5}, 2: {&"targeting": 2},
		3: {&"physical_power": 3}, 4: {&"mobility": 2}}
	s.unique_passives = [{"passive_id": &"pass_probe", "unlock_level": 5}]
	s.basic_attack_id = &"basic_strike"
	s.starting_skills = []
	s.starting_ultimate = &"ult_scrap_storm"
	return s


## Wrap one species in a catalog with the other three roles stubbed in, so the
## role-coverage rule does not drown the rule actually under test.
func _catalog_with(s: SpeciesDef) -> SpeciesCatalog:
	var c := SpeciesCatalog.new()
	c.entries = [s]
	for role in [SpeciesDefScript.Role.TANK, SpeciesDefScript.Role.HEALER,
			SpeciesDefScript.Role.SUPPORT]:
		var filler := _minimal_species()
		filler.id = StringName("filler_%d" % role)
		filler.role = role
		filler.tree_entry_node = StringName("entry_filler_%d" % role)
		c.entries.append(filler)
	return c


func _codes() -> Array:
	return _spy.errors.map(func(e): return e.get("code"))


func test_validator_rejects_a_species_whose_stats_fight_its_own_skills() -> void:
	var s := _minimal_species()
	s.basic_attack_id = &"basic_pulse"          # energy attack…
	s.base_stats[&"physical_power"] = 90        # …on a physical stat spread
	s.base_stats[&"energy_power"] = 10
	assert_gt(SpeciesValidator.validate(_catalog_with(s), _skills, _spy), 0)
	assert_true(_codes().has(&"species_scaling_stat_mismatch"),
		"this is the bug the generated content actually shipped with once")


func test_validator_rejects_a_passive_count_that_contradicts_rarity() -> void:
	var s := _minimal_species()
	s.rarity = SpeciesDefScript.Rarity.EPIC     # promises 3 passives, has 1
	SpeciesValidator.validate(_catalog_with(s), _skills, _spy)
	assert_true(_codes().has(&"species_passive_count_mismatch"))


func test_validator_rejects_an_unreachable_passive() -> void:
	var s := _minimal_species()
	s.unique_passives = [{"passive_id": &"pass_probe", "unlock_level": 0}]
	SpeciesValidator.validate(_catalog_with(s), _skills, _spy)
	assert_true(_codes().has(&"species_passive_never_unlocks"))


func test_validator_rejects_a_skill_reference_that_does_not_exist() -> void:
	var s := _minimal_species()
	s.starting_skills = [&"skill_that_was_never_authored"]
	SpeciesValidator.validate(_catalog_with(s), _skills, _spy)
	assert_true(_codes().has(&"species_missing_skill"))


func test_validator_rejects_an_ultimate_that_is_not_flagged_as_one() -> void:
	# It would be gated by cooldown instead of charge, so it could open the fight.
	var s := _minimal_species()
	s.starting_ultimate = &"basic_strike"
	SpeciesValidator.validate(_catalog_with(s), _skills, _spy)
	assert_true(_codes().has(&"species_ultimate_not_flagged"))


func test_validator_rejects_a_part_slot_that_grows_nothing() -> void:
	# Scrap spent for no effect is the worst kind of upgrade.
	var s := _minimal_species()
	s.part_growth.erase(3)
	SpeciesValidator.validate(_catalog_with(s), _skills, _spy)
	assert_true(_codes().has(&"species_part_slot_no_growth"))


func test_validator_rejects_a_roster_missing_a_role() -> void:
	var c := SpeciesCatalog.new()
	c.entries = [_minimal_species()]  # DPS only
	SpeciesValidator.validate(c, _skills, _spy)
	assert_true(_codes().has(&"species_role_unrepresented"))


func test_validator_rejects_duplicate_ids() -> void:
	var c := _catalog_with(_minimal_species())
	c.entries.append(_minimal_species())
	SpeciesValidator.validate(c, _skills, _spy)
	assert_true(_codes().has(&"species_duplicate_id"))
