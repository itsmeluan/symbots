## SpeciesCatalog — the explicit manifest of every SpeciesDef that ships in a build.
##
## Same discipline as [PartCatalog] and [SkillCatalog] (ADR-0003): an entry not listed here
## does not exist in the game. Directory scanning is forbidden in the content load path —
## DirAccess returns `.remap` stubs inside an exported PCK, so a `*.tres` scan silently
## returns nothing after export.
##
## Frozen shared instance — never mutate entries at runtime.
class_name SpeciesCatalog
extends Resource

@export var entries: Array[SpeciesDef] = []


func get_species(id: StringName) -> SpeciesDef:
	for s in entries:
		if s != null and s.id == id:
			return s
	return null


## Every species with the given role. Used by the collection screen's filters and by the
## stage generator when it needs "a tank, any tank".
func by_role(role: int) -> Array[SpeciesDef]:
	var out: Array[SpeciesDef] = []
	for s in entries:
		if s != null and s.role == role:
			out.append(s)
	return out
