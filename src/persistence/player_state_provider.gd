## PlayerStateProvider — persists what the player owns and what they are wearing.
##
## Implements the ADR-0001 provider triad (snapshot / restore / rederive) over the two
## stores that hold everything a player would be furious to lose: the equipped
## [SymbotBuild] manifest and the [PlayerInventory] of harvested parts.
##
## WHAT IS SAVED, AND WHY SO LITTLE: a [PartInstance] is only ever
## `{instance_id, part_id, tier}`. The [PartDef] behind it — stats, element, rarity,
## drop conditions — is CONTENT, reloaded from [PartDB] at restore. Writing the def into
## the save would freeze a copy of the balance table into every player's file, so a
## balance patch would silently not apply to anyone who had already played. Saving the
## id and re-resolving is what lets content change under an existing save.
##
## A part id that no longer resolves is DROPPED with a warning rather than failing the
## load: a removed part should cost the player that part, not their whole save.
##
## RESTORE ORDER MATTERS. equip_part() displaces the slot's current occupant into the
## inventory, so equipping the saved build first would leave the starter parts sitting in
## the inventory as phantom duplicates. So: equip the build, THEN clear the inventory,
## THEN refill it from the file. Clearing after equipping — not before — is the whole
## trick, and reversing those two lines silently doubles the player's parts.
extends RefCounted

const PartInstanceScript := preload("res://src/core/stats/part_instance.gd")

## Stable provider key in the save envelope (ADR-0001).
const KEY := &"player_state"

## Every equip slot, from the PartDef enum rather than a copy of the Workshop's
## presentation order — a save must cover all slots regardless of how the UI lists them.
const ALL_SLOTS: Array[int] = [
	PartDef.SlotType.CORE, PartDef.SlotType.CHASSIS, PartDef.SlotType.CHIPSET,
	PartDef.SlotType.ENERGY_CELL, PartDef.SlotType.HEAD, PartDef.SlotType.ARMS,
	PartDef.SlotType.LEGS, PartDef.SlotType.WEAPON,
]

var _build = null
var _inventory = null
var _log: LogSink = null


func _init(build, inventory, log: LogSink = null) -> void:
	_build = build
	_inventory = inventory
	_log = log


## ADR-0001 triad — raw facts only, no derived state. Stats are recomputed by the build
## itself on restore, so persisting them would only create a second source of truth that
## can disagree with the formula pipeline.
func snapshot() -> Dictionary:
	var equipped: Dictionary = {}
	if _build != null:
		for slot_type: int in ALL_SLOTS:
			var inst = _build.get_equipped(slot_type)
			if inst != null:
				equipped[str(slot_type)] = _instance_to_dict(inst)
	var owned: Array = []
	if _inventory != null:
		for inst in _inventory.all_parts():
			owned.append(_instance_to_dict(inst))
	return {"equipped": equipped, "inventory": owned}


func restore(data: Dictionary) -> void:
	if _build == null or _inventory == null:
		return
	var equipped: Dictionary = data.get("equipped", {})
	for slot_key in equipped:
		var inst = _dict_to_instance(equipped[slot_key])
		if inst != null:
			_build.equip_part(int(str(slot_key).to_int()), inst)
	# AFTER equipping — see the class docstring. Clearing first would let each equip
	# displace a starter into an inventory we then refill, doubling the player's parts.
	_clear_inventory()
	for raw in data.get("inventory", []):
		var inst = _dict_to_instance(raw)
		if inst != null:
			_inventory.receive_part_instance(inst)


## Nothing to rederive: equip_part() already recomputes the stat pipeline on every call,
## so by the time restore() returns the build is consistent. Declared because the triad
## is the contract, not because there is work to do.
func rederive() -> void:
	pass


func _instance_to_dict(inst) -> Dictionary:
	return {
		"instance_id": String(inst.instance_id),
		"part_id": String(inst.part.id),
		"tier": int(inst.tier),
	}


## Rebuild a PartInstance by re-resolving its PartDef from content. Returns null (with a
## warning) when the id no longer exists — see the class docstring on why that is a
## dropped part rather than a failed load.
func _dict_to_instance(raw) -> Variant:
	if not (raw is Dictionary):
		return null
	var part_id := StringName(str(raw.get("part_id", "")))
	var part_def = PartDB.get_part(part_id)
	if part_def == null:
		_warn(&"save_part_id_unresolved", {"part_id": String(part_id)})
		return null
	# JSON returns every number as float; tier is an integer field and leaving it as a
	# float would poison comparisons downstream (ADR-0001 impl guideline).
	return PartInstanceScript.new(
		StringName(str(raw.get("instance_id", ""))), part_def, int(raw.get("tier", 0)))


func _clear_inventory() -> void:
	for inst in _inventory.all_parts().duplicate():
		_inventory.remove(inst)


func _warn(code: StringName, detail: Dictionary) -> void:
	if _log != null:
		_log.warn(code, detail)
