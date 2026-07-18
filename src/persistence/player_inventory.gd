## PlayerInventory — the session's owned-part store (concrete InventorySink).
##
## Two producers feed it:
##   1. DropSystem.resolve_drops(...) with this injected as its InventorySink —
##      harvested parts land here after a VICTORY.
##   2. SymbotBuild.equip_part(...) displaces the previously-equipped occupant here.
##
## One consumer reads it: the WorkshopScreen lists all_parts() as equip candidates.
##
## NOTE: InventorySink is @abstract with a class_name; concrete sinks must NOT declare
## their own class_name (inventory_sink.gd §17). This script is preloaded where needed.
extends InventorySink

## Owned part instances not currently installed in a slot. Order = acquisition order.
var _parts: Array[PartInstance] = []


## InventorySink contract — called by DropSystem and SymbotBuild when a part enters
## the player's possession (harvest or displacement).
func receive_part_instance(instance: PartInstance) -> void:
	if instance == null:
		return
	_parts.append(instance)


## All owned, uninstalled parts. Returns the live array — callers must not mutate it
## directly; use remove() to take a part out (e.g. when the Workshop equips it).
func all_parts() -> Array[PartInstance]:
	return _parts


## Owned parts whose slot_type matches [param slot_type] — the Workshop's candidate
## list for a given slot.
func parts_for_slot(slot_type: int) -> Array[PartInstance]:
	var out: Array[PartInstance] = []
	for pi in _parts:
		if pi.part.slot_type == slot_type:
			out.append(pi)
	return out


## Displacement entry point used by [method SymbotBuild.equip_part] when a slot's
## previous occupant is returned to the store. Aliases [method receive_part_instance]
## (the InventorySink contract method) — SymbotBuild's inventory duck-type expects the
## `add`/`remove` pair, so this keeps the equip path working against the concrete store.
func add(instance: PartInstance) -> void:
	receive_part_instance(instance)


## Remove [param instance] from the store (it is being installed into a slot).
func remove(instance: PartInstance) -> void:
	_parts.erase(instance)


## Count of owned parts — for HUD / debug.
func count() -> int:
	return _parts.size()
