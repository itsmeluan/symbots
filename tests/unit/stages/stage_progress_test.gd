## Stage map, progression gating and the shipped arc (Core Design §6).
##
## The rule under test is that availability is DERIVED from what is cleared, never stored.
## The failure mode a stored flag produces — a player permanently locked out of content
## after a requirements edit — is unrecoverable without a save edit, so it gets pinned hard.
extends GutTest

const StageDefScript := preload("res://src/core/stages/stage_def.gd")

const STAGE_CATALOG_PATH := "res://assets/data/catalogs/stage_catalog.tres"
const SPECIES_CATALOG_PATH := "res://assets/data/catalogs/species_catalog.tres"
const ITEM_CATALOG_PATH := "res://assets/data/catalogs/install_item_catalog.tres"

var _progress: StageProgress
var _catalog: StageCatalog


func before_each() -> void:
	_progress = StageProgress.new()
	_catalog = load(STAGE_CATALOG_PATH)


func _stage(id: String, requires: Array = [], mode: int = StageDefScript.Mode.STAGE) -> StageDef:
	var s := StageDef.new()
	s.id = StringName(id)
	s.display_name = id
	s.mode = mode
	var typed: Array[StringName] = []
	for r in requires:
		typed.append(r)
	s.requires = typed
	return s


func _toy_catalog() -> StageCatalog:
	var c := StageCatalog.new()
	c.entries = [
		_stage("a"),
		_stage("b", ["a"]),
		_stage("c", ["a"]),
		_stage("d", ["b", "c"]),  # a converging requirement
	]
	return c


# ---------------------------------------------------------------------------
# Gating
# ---------------------------------------------------------------------------

func test_a_stage_with_no_requirements_is_open_from_the_start() -> void:
	assert_true(_progress.is_available(_stage("a")))


func test_a_stage_is_locked_until_its_requirement_is_cleared() -> void:
	var b := _stage("b", ["a"])
	assert_false(_progress.is_available(b))
	_progress.mark_cleared(&"a")
	assert_true(_progress.is_available(b))


func test_a_converging_stage_needs_every_branch() -> void:
	# The map converges as well as branches, so one satisfied prerequisite is not enough.
	var d := _stage("d", ["b", "c"])
	_progress.mark_cleared(&"b")
	assert_false(_progress.is_available(d), "one of two is not enough")
	_progress.mark_cleared(&"c")
	assert_true(_progress.is_available(d))


func test_availability_is_derived_not_stored() -> void:
	# Editing a stage's requirements must immediately change what is open. A stored
	# "unlocked" flag would leave the player locked out with no way back — unrecoverable
	# without a save edit.
	var b := _stage("b", ["a"])
	assert_false(_progress.is_available(b))
	b.requires = [] as Array[StringName]
	assert_true(_progress.is_available(b), "no migration step, no stale flag")


func test_available_stages_grow_as_the_player_clears() -> void:
	var c := _toy_catalog()
	assert_eq(_progress.available_stages(c).size(), 1, "only 'a' at the start")
	_progress.mark_cleared(&"a")
	assert_eq(_progress.available_stages(c).size(), 3, "a, b and c")


func test_next_stages_excludes_what_is_already_beaten() -> void:
	# A map that highlights everything highlights nothing.
	var c := _toy_catalog()
	_progress.mark_cleared(&"a")
	var next := _progress.next_stages(c).map(func(s): return s.id)
	assert_false(next.has(&"a"), "already cleared")
	assert_true(next.has(&"b"))


func test_a_null_stage_is_never_available() -> void:
	assert_false(_progress.is_available(null))


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func test_progress_round_trips() -> void:
	_progress.mark_cleared(&"a")
	_progress.mark_cleared(&"b")
	_progress.endless_tier = 7
	var restored := StageProgress.from_dict(_progress.to_dict())
	assert_true(restored.is_cleared(&"a"))
	assert_true(restored.is_cleared(&"b"))
	assert_eq(restored.endless_tier, 7)


func test_a_cleared_id_for_a_stage_that_no_longer_exists_is_kept() -> void:
	# Unlike a Symbot or a tree node, a stale cleared-id costs nothing to carry — and
	# dropping it would silently re-lock content the player already beat if a stage were
	# removed in one patch and restored in the next.
	var restored := StageProgress.from_dict({"cleared": ["stage_from_an_old_patch"]})
	assert_true(restored.is_cleared(&"stage_from_an_old_patch"))


func test_a_corrupt_endless_tier_floors_at_zero() -> void:
	assert_eq(StageProgress.from_dict({"endless_tier": -5}).endless_tier, 0)


# ---------------------------------------------------------------------------
# The shipped arc
# ---------------------------------------------------------------------------

func test_the_opening_arc_is_reachable_end_to_end() -> void:
	# The check that matters most: walking the requirement graph from an empty save must
	# reach every authored stage. An unreachable stage is content nobody ever sees, and
	# nothing else in the build would report it.
	var progress := StageProgress.new()
	var remaining := _catalog.entries.size()
	var guard := 0
	while remaining > 0 and guard < 100:
		var opened := progress.next_stages(_catalog)
		assert_gt(opened.size(), 0,
			"the graph dead-ends with %d stages still unreached" % remaining)
		for s in opened:
			progress.mark_cleared(s.id)
			remaining -= 1
		guard += 1
	assert_eq(remaining, 0, "every authored stage is reachable from an empty save")


func test_exactly_one_stage_is_open_on_a_fresh_save() -> void:
	# More than one would leave a new player choosing before they know anything.
	assert_eq(_progress.available_stages(_catalog).size(), 1)


func test_every_requirement_names_a_stage_that_exists() -> void:
	var ids := _catalog.ids()
	for s in _catalog.entries:
		for req in s.requires:
			assert_true(ids.has(req), "%s requires %s, which does not exist" % [s.id, req])


func test_every_stage_has_at_least_one_battle() -> void:
	for s in _catalog.entries:
		assert_gt(s.battle_count(), 0, "%s has nothing to fight" % s.id)


func test_no_battle_fields_more_than_four_enemies() -> void:
	# §3.1 fixes 1-4. A fifth enemy would have no row to stand in.
	for s in _catalog.entries:
		for i in s.battle_count():
			var count: int = s.enemies_at(i).size()
			assert_between(count, 1, 4, "%s battle %d fields %d" % [s.id, i, count])


func test_every_enemy_in_the_arc_is_a_species_that_ships() -> void:
	var species: SpeciesCatalog = load(SPECIES_CATALOG_PATH)
	for s in _catalog.entries:
		for i in s.battle_count():
			for e in s.enemies_at(i):
				assert_not_null(species.get_species(e),
					"%s battle %d fields %s, which is not in the species catalog"
						% [s.id, i, e])


func test_every_chest_item_in_the_arc_actually_exists() -> void:
	var items: InstallItemCatalog = load(ITEM_CATALOG_PATH)
	for s in _catalog.entries:
		for item_id in s.chest_item_ids:
			assert_not_null(items.get_item(item_id),
				"%s promises %s, which is not in the item catalog" % [s.id, item_id])


func test_stage_levels_climb_along_the_arc() -> void:
	# stage_level drives reward scale, so a later stage paying less than an earlier one
	# would make the earlier one the only rational grind.
	var last := 0
	for s in _catalog.entries:
		assert_gt(s.stage_level, last, "%s does not advance the level" % s.id)
		last = s.stage_level


func test_only_dungeons_carry_structure_between_fights() -> void:
	# §3.6: structure carries within a dungeon run and everything else resets. A single
	# battle has nothing to carry.
	for s in _catalog.entries:
		if s.mode == StageDefScript.Mode.STAGE:
			assert_false(s.carries_structure(), "%s is one fight" % s.id)
		elif s.mode == StageDefScript.Mode.DUNGEON:
			assert_true(s.carries_structure(), "%s is an attrition arc" % s.id)


func test_multi_battle_stages_are_authored_as_dungeons() -> void:
	# A stage with several fights that did NOT carry structure would silently be a much
	# easier dungeon — full repair between every fight.
	for s in _catalog.entries:
		if s.battle_count() > 1:
			assert_true(s.carries_structure(),
				"%s has %d battles but heals between them" % [s.id, s.battle_count()])
