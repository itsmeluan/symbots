## UnitBuilder — turns an owned [SymbotInstance] into a [BattleUnit] (Core Design §2, §3).
##
## The single composition point where all four progression axes meet: species base stats,
## part levels, allocated tree nodes, and fitted hardware. Having exactly ONE place that
## adds them up is what stops the Workshop preview and the actual battle disagreeing about
## how strong a Symbot is — the class of bug players report as "the game lied to me".
##
## Pure static with everything injected. No autoload, so the same builder serves the live
## battle, the Workshop's hypothetical preview, and the offline expedition simulator.
class_name UnitBuilder
extends RefCounted

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

## Order of application, and why it is not negotiable:
##   1. species base
##   2. + part growth x (part level - 1)
##   3. + tree flat
##   4. x tree percent
## Percentages last, over the whole flat total. Applying them earlier would make an
## identical build's stats depend on the ORDER the player happened to allocate nodes in.
static func build(inst: SymbotInstance, species: SpeciesDef, tree: SkillTree,
		skills: Dictionary, side: int, slot: int, items: Dictionary = {}) -> BattleUnit:
	if inst == null or species == null:
		return null

	var stats := _base_plus_parts(inst, species)
	if tree != null:
		var agg := TreeAllocator.aggregate_stats(tree, inst, species, items)
		for key in agg["flat"]:
			stats[key] = int(stats.get(key, 0)) + int(agg["flat"][key])
		for key in agg["percent"]:
			var base: int = int(stats.get(key, 0))
			stats[key] = base + (base * int(agg["percent"][key])) / 100
	for key in stats:
		stats[key] = maxi(0, int(stats[key]))

	var unit := BattleUnit.new()
	unit.unit_id = inst.instance_id
	unit.display_name = species.display_name
	unit.species_id = species.id
	unit.art_mark = clampi(inst.mark, 1, SymbotInstanceScript.MAX_MARK)
	unit.side = side
	unit.slot = slot
	unit.role = species.role
	unit.base_stats = stats
	unit.max_structure = maxi(1, int(stats.get(&"structure", 1)))
	unit.current_structure = unit.max_structure
	unit.skills = _resolve_skills(inst, species, tree, skills)
	unit.ultimate_skill = _resolve_ultimate(inst, species, skills)
	return unit


## Species base plus what the levelled parts contribute. Growth is per level ABOVE the
## first — a level-1 part contributes nothing beyond the species baseline, so the baseline
## is the honest floor rather than a number already inflated by five free part levels.
static func _base_plus_parts(inst: SymbotInstance, species: SpeciesDef) -> Dictionary:
	var stats: Dictionary = {}
	for key in species.base_stats:
		stats[key] = int(species.base_stats[key])
	for slot in SymbotInstanceScript.PART_COUNT:
		if not species.part_growth.has(slot):
			continue
		var levels_above_first: int = maxi(0, inst.get_part_level(slot) - 1)
		if levels_above_first == 0:
			continue
		var growth: Dictionary = species.part_growth[slot]
		for key in growth:
			stats[key] = int(stats.get(key, 0)) + int(growth[key]) * levels_above_first
	return stats


## Slot 0 is always the basic attack, so a turn is never wasted (§3.4). After it come the
## actives, capped at the three slots the design fixes.
##
## Skills the tree granted are appended after the species' own, and duplicates are
## dropped — two tree nodes can legitimately grant the same skill, and a doubled entry
## would render as two buttons that share one cooldown.
static func _resolve_skills(inst: SymbotInstance, species: SpeciesDef, tree: SkillTree,
		skills: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if skills.has(species.basic_attack_id):
		out.append(species.basic_attack_id)

	var seen: Dictionary = {species.basic_attack_id: true}
	var candidates: Array[StringName] = []
	candidates.append_array(species.starting_skills)
	if tree != null:
		candidates.append_array(TreeAllocator.granted_skills(tree, inst, species))

	for sid in candidates:
		if seen.has(sid) or not skills.has(sid):
			continue
		var skill: SkillDef = skills[sid]
		if skill.is_ultimate:
			continue  # the ult has its own slot (§3.4b)
		seen[sid] = true
		out.append(sid)
		if out.size() > ACTIVE_SLOTS:
			break
	return out


## Three active slots plus the basic attack (§3.4).
const ACTIVE_SLOTS := 3


## The slotted ult, if the player picked one and it resolves. Falls back to the species'
## starting ult so a Symbot is never fielded with an empty ult slot it has earned.
static func _resolve_ultimate(inst: SymbotInstance, species: SpeciesDef,
		skills: Dictionary) -> StringName:
	var chosen := species.starting_ultimate
	if chosen == &"" or not skills.has(chosen):
		return &""
	var skill: SkillDef = skills[chosen]
	return chosen if skill.is_ultimate else &""


## Build a whole side. Slot indices come from POSITION IN THE ARRAY, not from the roster's
## squad indices, so a squad with a gap in slot 2 still produces units in rows 0..n rather
## than leaving a hole the turn-order tie-break would read as a real slot.
static func build_side(instances: Array, catalog: SpeciesCatalog, tree: SkillTree,
		skills: Dictionary, side: int, items: Dictionary = {}) -> Array:
	var out: Array = []
	for inst in instances:
		var species := catalog.get_species(inst.species_id)
		if species == null:
			continue
		var unit := build(inst, species, tree, skills, side, out.size(), items)
		if unit != null:
			out.append(unit)
	return out


## Build an enemy from a species id at a given level. Enemies have no tree and no fitted
## hardware — their power comes from level and part levels alone, which keeps a stage's
## difficulty a single readable dial rather than a hidden build.
static func build_enemy(species: SpeciesDef, level: int, side: int, slot: int,
		skills: Dictionary, index: int = 0) -> BattleUnit:
	if species == null:
		return null
	var inst := SymbotInstanceScript.new(
		StringName("enemy_%s_%d" % [species.id, index]), species.id)
	inst.level = maxi(1, level)
	var part_level: int = clampi(level, 1, inst.part_level_cap())
	for i in SymbotInstanceScript.PART_COUNT:
		inst.part_levels[i] = part_level
	return build(inst, species, null, skills, side, slot)
