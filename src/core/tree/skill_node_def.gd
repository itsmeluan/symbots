## SkillNodeDef — one node of the shared skill tree (Core Design §4).
##
## There is ONE tree. Every species enters it at a different node and walks outward, so
## distance is the balancing tool: a healer *can* reach a DPS cluster, but the walk costs
## points a DPS spends on getting further. This is why nodes carry neighbours rather than
## a role tag — reachability, not permission, is what gates a build.
@tool
class_name SkillNodeDef
extends Resource

## Values are APPEND-ONLY — never reorder or renumber; allocations persist the int.
enum NodeType {
	INVALID  = 0,
	STAT     = 1,  ## flat/percentage stat — connective tissue and the endless-tier sink
	PASSIVE  = 2,  ## a named permanent effect
	ACTIVE   = 3,  ## grants a skill the Symbot can slot
	KEYSTONE = 4,  ## large effect WITH a drawback — build-defining
	SOCKET   = 5,  ## locked until an install item is fitted (§4.4)
	ENTRY    = 6,  ## one of the 16 species entry points; allocated free at birth
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var node_type: NodeType = NodeType.INVALID

## Adjacency. A node may be allocated only when at least one neighbour is already
## allocated — which is what makes the tree a walk rather than a shopping list.
@export var neighbours: Array[StringName] = []

## Layout position for the tree UI. Authored rather than computed so clusters read as
## deliberate regions instead of a force-directed blob.
@export var position: Vector2 = Vector2.ZERO

## STAT nodes: flat additions by stat key.
@export var stat_bonus: Dictionary[StringName, int] = {}
## STAT nodes: percentage additions by stat key, in whole percent.
@export var stat_percent: Dictionary[StringName, int] = {}

## PASSIVE / KEYSTONE: the effect this grants.
@export var passive_id: StringName = &""
## KEYSTONE: the cost that makes it a decision rather than an upgrade. A keystone with no
## drawback is just a big stat node.
@export var keystone_drawback_id: StringName = &""

## ACTIVE: the skill this unlocks for slotting.
@export var skill_id: StringName = &""

## SOCKET: which item category fits here. Empty on every other node type.
@export var socket_accepts: StringName = &""

## ENTRY: which role this doorway belongs to, for authoring checks and UI grouping.
@export var entry_role: int = 0

## Endless-tier nodes sit outside the designed region and exist to absorb late points.
## Flagged so the UI can render them plainly and the validator can skip design review.
@export var is_endless_tier: bool = false


## True when allocating this node needs an installed item as well as a point.
func requires_item() -> bool:
	return node_type == NodeType.SOCKET


## Entry nodes are granted at birth rather than bought, so they cost no point.
func point_cost() -> int:
	return 0 if node_type == NodeType.ENTRY else 1
