## StageCatalog — the explicit manifest of every StageDef that ships (ADR-0003).
##
## Same discipline as every other catalog: an entry not listed here does not exist, and
## directory scanning is forbidden in the content load path because DirAccess returns
## `.remap` stubs inside an exported PCK.
##
## Frozen shared instance — never mutate entries at runtime.
class_name StageCatalog
extends Resource

@export var entries: Array[StageDef] = []


func get_stage(id: StringName) -> StageDef:
	for s in entries:
		if s != null and s.id == id:
			return s
	return null


## Every stage id this catalog knows, for validating a requirement graph.
func ids() -> Dictionary:
	var out: Dictionary = {}
	for s in entries:
		if s != null:
			out[s.id] = true
	return out
