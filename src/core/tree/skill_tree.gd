## SkillTree — the one shared tree every species walks (Core Design §4).
##
## Holds every [SkillNodeDef] and an id index built once on load. The index matters: a
## linear scan per lookup would be fine for one query and quadratic for the reachability
## walk the allocation UI runs on every tap.
##
## Frozen shared instance — never mutate at runtime.
class_name SkillTree
extends Resource

@export var nodes: Array[SkillNodeDef] = []

var _by_id: Dictionary = {}
var _indexed: bool = false


## Build the id index. Called lazily so a .tres loaded by the editor does not pay for it,
## and idempotent so callers never have to check.
func _ensure_index() -> void:
	if _indexed:
		return
	_by_id.clear()
	for n in nodes:
		if n != null and n.id != &"":
			_by_id[n.id] = n
	_indexed = true


func get_node_def(id: StringName) -> SkillNodeDef:
	_ensure_index()
	return _by_id.get(id, null)


func has_node(id: StringName) -> bool:
	_ensure_index()
	return _by_id.has(id)


func size() -> int:
	return nodes.size()


## Every ENTRY node, in authoring order. The design fixes sixteen — four per role (§4.1).
func entry_nodes() -> Array[SkillNodeDef]:
	var out: Array[SkillNodeDef] = []
	for n in nodes:
		if n != null and n.node_type == SkillNodeDef.NodeType.ENTRY:
			out.append(n)
	return out


## Neighbours of [param id] as defs, skipping ids that do not resolve. A dangling
## neighbour is a content bug the validator catches; here it is simply not walked, so a
## bad edge degrades reachability instead of crashing a player's tree screen.
func neighbours_of(id: StringName) -> Array[SkillNodeDef]:
	var out: Array[SkillNodeDef] = []
	var node := get_node_def(id)
	if node == null:
		return out
	for nid in node.neighbours:
		var n := get_node_def(nid)
		if n != null:
			out.append(n)
	return out
