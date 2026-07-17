## Shared test doubles + factories for Symbot Assembly tests (Stories 001–007).
##
## preload()-ed, NOT class_name-declared (ADR-0002 §5): a class_name in tests/ would
## pollute the production global class registry. Both the unit and integration suites
## preload this via its res:// path.
extends RefCounted

const PartInstanceScript = preload("res://src/core/stats/part_instance.gd")


## Records the instances added to / removed from Inventory during an equip so the
## displace/install bookkeeping (AC-SA-04) is assertable.
class StubInventory:
	var added: Array = []
	var removed: Array = []

	func add(instance) -> void:
		added.append(instance)

	func remove(instance) -> void:
		removed.append(instance)


## Stub CoreProgression: `allow` drives the can_equip gate; `level` feeds CP-F3.
class StubCoreProgression:
	var level: int = 1
	var allow: bool = true

	func can_equip(_part) -> bool:
		return allow

	func get_level() -> int:
		return level


## Stub for MoveDB / PassiveDB: knows only the ids seeded at construction. Serves both
## `has_move` and `has_passive` (the two DBs share the same lookup contract).
class StubDB:
	var known: Dictionary = {}

	func _init(ids: Array = []) -> void:
		for id in ids:
			known[id] = true

	func has_move(id) -> bool:
		return known.has(id)

	func has_passive(id) -> bool:
		return known.has(id)


## Builds a frozen-shape [PartDef] from a plain dict. Typed sub-dictionaries
## (`stat_bonuses`, `level_growth`) are copied key-by-key to guarantee the
## StringName/int typing the schema requires. Callers MUST use &"" StringName keys.
static func make_part(fields: Dictionary) -> PartDef:
	var p := PartDef.new()
	p.id = fields.get("id", &"test_part")
	p.display_name = fields.get("display_name", "Test Part")
	p.slot_type = fields.get("slot_type", PartDef.SlotType.WEAPON)
	p.rarity = fields.get("rarity", PartDef.Rarity.COMMON)
	p.chassis_archetype = fields.get("chassis_archetype", 0)
	p.active_skill_id = fields.get("active_skill_id", &"")
	p.passive_id = fields.get("passive_id", &"")
	p.level_requirement = fields.get("level_requirement", 0)
	p.max_upgrade_tier = fields.get("max_upgrade_tier", 3)
	var sb: Dictionary[StringName, int] = {}
	for k in fields.get("stat_bonuses", {}):
		sb[k] = fields["stat_bonuses"][k]
	p.stat_bonuses = sb
	var lg: Dictionary[StringName, int] = {}
	for k in fields.get("level_growth", {}):
		lg[k] = fields["level_growth"][k]
	p.level_growth = lg
	return p


## Wraps a [PartDef] in a [PartInstance] at [param tier].
static func make_instance(part: PartDef, tier: int = 0, instance_id: StringName = &"inst") -> Object:
	return PartInstanceScript.new(instance_id, part, tier)
