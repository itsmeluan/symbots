## InstallItemCatalog — the explicit manifest of every InstallItemDef that ships.
##
## Same discipline as [PartCatalog], [SkillCatalog] and [SpeciesCatalog] (ADR-0003): an
## entry not listed here does not exist, and directory scanning is forbidden in the content
## load path because DirAccess returns `.remap` stubs inside an exported PCK.
##
## Frozen shared instance — never mutate entries at runtime.
class_name InstallItemCatalog
extends Resource

@export var entries: Array[InstallItemDef] = []


func get_item(id: StringName) -> InstallItemDef:
	for i in entries:
		if i != null and i.id == id:
			return i
	return null


## Every item that fits a socket declaring [param accepts]. The socket UI lists these as
## the player's options for a given node.
func fitting(accepts: StringName) -> Array[InstallItemDef]:
	var out: Array[InstallItemDef] = []
	for i in entries:
		if i != null and i.fits(accepts):
			out.append(i)
	return out


## Build the `item_id -> InstallItemDef` table [TreeAllocator] takes.
##
## In play the player owns item INSTANCES, and `installed_items` maps a socket to an
## instance id. Until an instance layer exists, an instance id is its def id, so this table
## resolves both. When instances arrive, only the table builder changes — every caller
## already speaks "give me a lookup".
func to_table() -> Dictionary:
	var out: Dictionary = {}
	for i in entries:
		if i != null and i.id != &"":
			out[i.id] = i
	return out
