## StatSummary — the numbers the Workshop stats drawer shows (Core Design §2.4, §5).
##
## Pins that the drawer never shows a stat the engine would not agree with: current stats are
## species base plus levelled-part growth, the cap value is what maxing the parts would give,
## and one part's contribution is exactly its growth × levels-above-one.
extends GutTest

const StatSummaryScript := preload("res://src/ui/workshop/stat_summary.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

var _species: SpeciesCatalog


func before_each() -> void:
	_species = load("res://assets/data/catalogs/species_catalog.tres")


func _fresh(species_id: StringName) -> SymbotInstance:
	var inst := SymbotInstanceScript.new()
	inst.species_id = species_id
	inst.mark = 1
	inst.level = 1
	inst.part_levels = PackedInt32Array([1, 1, 1, 1, 1])
	return inst


func test_a_level_one_symbot_reads_its_species_base() -> void:
	# Every part at level 1 contributes nothing beyond the baseline (growth is per level ABOVE
	# the first), so current must equal the honest species base.
	var sp: SpeciesDef = _species.get_species(&"boltshell")
	var inst := _fresh(&"boltshell")
	var cur := StatSummaryScript.current(inst, sp)
	assert_eq(int(cur["structure"]), int(sp.base_stats["structure"]),
		"a fresh Symbot's structure is its species base")


func test_the_cap_value_is_at_least_the_current_value() -> void:
	# The bar fills toward the cap, so the cap can never read below the current value.
	var sp: SpeciesDef = _species.get_species(&"boltshell")
	var inst := _fresh(&"boltshell")
	var cur := StatSummaryScript.current(inst, sp)
	var cap := StatSummaryScript.at_cap(inst, sp)
	for stat in cur:
		assert_true(int(cap.get(stat, 0)) >= int(cur[stat]),
			"%s cap %d >= current %d" % [stat, int(cap.get(stat, 0)), int(cur[stat])])


func test_levelling_a_part_raises_current_toward_cap() -> void:
	var sp: SpeciesDef = _species.get_species(&"boltshell")
	var inst := _fresh(&"boltshell")
	# Find a stat the chassis (slot 1) grows, and confirm raising that part moves it.
	if not sp.part_growth.has(1):
		pass_test("boltshell chassis has no growth to test")
		return
	var grown_stat: StringName = sp.part_growth[1].keys()[0]
	var before := int(StatSummaryScript.current(inst, sp).get(grown_stat, 0))

	inst.part_levels[1] = 5

	var after := int(StatSummaryScript.current(inst, sp).get(grown_stat, 0))
	assert_gt(after, before, "levelling the chassis raised %s" % grown_stat)
	assert_eq(after - before, int(sp.part_growth[1][grown_stat]) * 4,
		"the rise is exactly growth × levels above one")


func test_a_part_at_level_one_contributes_nothing() -> void:
	var sp: SpeciesDef = _species.get_species(&"boltshell")
	var inst := _fresh(&"boltshell")
	assert_true(StatSummaryScript.part_contribution(inst, sp, 1).is_empty(),
		"a level-1 part adds nothing on top of the baseline")
