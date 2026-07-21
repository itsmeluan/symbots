## KeyItems — the registry of items that are NOT skill-tree components.
##
## [InstallItemDef] deliberately covers only socket components, and the content CI enforces
## that every entry in that catalog fits some socket ("an item that fits no socket is a drop
## that reads as progress and is not"). A Chipset fits no socket — it is spent on the
## Symbot itself — so it lives here instead of polluting that invariant.
##
## Small and static on purpose: these are a handful of named, meaningful objects, not a
## generated table. Counts are held in an ordinary [ItemInventory]; this only supplies
## identity, and the guard that stops an unknown id surviving a reload.
class_name KeyItems
extends RefCounted

## Spent to take one Overclock level on a Rare-or-better Symbot (Core Design §2.2).
##
## Named Chipset, not Core: CORE is already a part slot on every Symbot, and a currency
## sharing that word reads as "collect duplicate Symbots for their cores", which is not the
## mechanic.
const CHIPSET := &"key_chipset"

const DEFS := {
	CHIPSET: {
		"name": "Chipset",
		"description": "Overclocking silicon, spent whole. Raises one Symbot's ceiling by a level.",
	},
}


static func has(id: StringName) -> bool:
	return DEFS.has(id)


static func display_name(id: StringName) -> String:
	return String(DEFS.get(id, {}).get("name", String(id)))


static func description(id: StringName) -> String:
	return String(DEFS.get(id, {}).get("description", ""))


## Every known key-item id, in declaration order.
static func ids() -> Array:
	return DEFS.keys()


## Drop ids this build no longer ships — the same discipline [ItemInventory] applies to
## socket components, for the same reason: a phantom item reads as progress and is not.
static func sanitise(inventory: ItemInventory) -> void:
	for id in inventory.counts.keys():
		if not has(id):
			inventory.counts.erase(id)
