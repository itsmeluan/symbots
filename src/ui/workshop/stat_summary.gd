## StatSummary — derives a Symbot's displayed stats from its species and part levels.
##
## Presentation-only mirror of [UnitBuilder]'s `_base_plus_parts`: species base plus each
## levelled part's growth (per level ABOVE the first). The Workshop stats drawer shows the
## CURRENT value and the value at this mark's cap, so a bar can read "how close to maxed" and
## grow as parts are upgraded. Pure and static — no state, so it is trivially testable.
class_name StatSummary
extends RefCounted

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

## Display order and identity of the eleven stats.
const ORDER: Array[StringName] = [
	&"structure", &"armor", &"resistance", &"physical_power", &"energy_power",
	&"mobility", &"targeting", &"processing", &"cooling", &"energy_capacity", &"recharge"]

const LABELS := {
	&"structure": "STRUCTURE", &"armor": "ARMOR", &"resistance": "RESIST",
	&"physical_power": "P.POWER", &"energy_power": "E.POWER", &"mobility": "MOBILITY",
	&"targeting": "TARGET", &"processing": "PROCESS", &"cooling": "COOLING",
	&"energy_capacity": "E.CAP", &"recharge": "RECHARGE"}

## Abbreviations for the part rows, where a levelled contribution can be four digits and
## the full label no longer fits beside it. The stats drawer keeps LABELS — it has the width.
const SHORT_LABELS := {
	&"structure": "STR", &"armor": "ARM", &"resistance": "RES",
	&"physical_power": "P.PWR", &"energy_power": "E.PWR", &"mobility": "MOB",
	&"targeting": "TGT", &"processing": "PRC", &"cooling": "COOL",
	&"energy_capacity": "E.CAP", &"recharge": "RCHG"}

const ICON_DIR := "res://assets/art/icons/stat_%s.png"


static func icon_path(stat: StringName) -> String:
	return ICON_DIR % stat


## Current stats: base plus each part's growth × (level - 1).
static func current(inst: SymbotInstance, species: SpeciesDef) -> Dictionary:
	return _accumulate(inst, species, false)


## Stats if every part were at this mark's cap — the ceiling a bar fills toward.
static func at_cap(inst: SymbotInstance, species: SpeciesDef) -> Dictionary:
	return _accumulate(inst, species, true)


## What one part currently contributes on top of the species baseline (growth × (level - 1)).
static func part_contribution(inst: SymbotInstance, species: SpeciesDef, slot: int) -> Dictionary:
	var out: Dictionary = {}
	if species == null or not species.part_growth.has(slot):
		return out
	var above: int = maxi(0, inst.get_part_level(slot) - 1)
	if above == 0:
		return out
	var growth: Dictionary = species.part_growth[slot]
	for key in growth:
		out[key] = int(growth[key]) * above
	return out


static func _accumulate(inst: SymbotInstance, species: SpeciesDef, at_max: bool) -> Dictionary:
	var stats: Dictionary = {}
	if species == null:
		return stats
	for key in species.base_stats:
		stats[key] = int(species.base_stats[key])
	var cap: int = inst.part_level_cap()
	for slot in SymbotInstanceScript.PART_COUNT:
		if not species.part_growth.has(slot):
			continue
		var level: int = cap if at_max else inst.get_part_level(slot)
		var above: int = maxi(0, level - 1)
		if above == 0:
			continue
		var growth: Dictionary = species.part_growth[slot]
		for key in growth:
			stats[key] = int(stats.get(key, 0)) + int(growth[key]) * above
	return stats
