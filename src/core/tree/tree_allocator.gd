## TreeAllocator — the rules for spending points on the shared tree (Core Design §4).
##
## Pure static functions over a [SkillTree], a [SymbotInstance] and a [SpeciesDef]. No
## state, no side effects except the explicit mutators, so the tree UI's "can I click
## this?" and the actual allocation cannot disagree.
##
## The one rule everything else hangs off: **a node may be allocated only when a neighbour
## is already allocated.** Reachability, not a role tag, is what gates a build — a healer
## *can* reach a DPS cluster, it just spends the walk a DPS gets for free (§4.1).
class_name TreeAllocator
extends RefCounted

const SkillNodeDefScript := preload("res://src/core/tree/skill_node_def.gd")
const InstallItemDefScript := preload("res://src/core/tree/install_item_def.gd")

## Why an allocation was refused. The UI shows the reason rather than a dead button —
## "you cannot reach this yet" teaches the tree; a greyed node with no explanation does not.
enum Refusal {
	OK = 0,
	NO_SUCH_NODE = 1,
	ALREADY_ALLOCATED = 2,
	NOT_REACHABLE = 3,
	NO_POINTS = 4,
	SOCKET_EMPTY = 5,
	SOCKET_WRONG_CATEGORY = 6,
	IS_ENTRY_NODE = 7,
}


## The set of nodes currently allocated, INCLUDING the species' entry node.
##
## The entry is not stored on the instance (it costs no point and storing it would charge
## the player for it), so every reachability question has to add it back here. Returns a
## Dictionary used as a set — membership is checked once per neighbour per node during the
## frontier walk, and an Array scan makes that quadratic.
static func allocated_set(inst: SymbotInstance, species: SpeciesDef) -> Dictionary:
	var out: Dictionary = {}
	if species != null and species.tree_entry_node != &"":
		out[species.tree_entry_node] = true
	for id in inst.allocated_nodes:
		out[id] = true
	return out


## Points earned but not yet spent. One point per level past the first; the entry node is
## free, so it never enters the arithmetic.
static func unspent_points(inst: SymbotInstance) -> int:
	return maxi(0, (inst.level - 1) - inst.allocated_nodes.size())


## Can this node be allocated right now? Returns a [enum Refusal] — [constant Refusal.OK]
## means yes.
##
## Example:
##     if TreeAllocator.can_allocate(tree, inst, species, node_id) == TreeAllocator.Refusal.OK:
##         TreeAllocator.allocate(tree, inst, species, node_id)
##
## [param items] resolves `item_instance_id -> InstallItemDef` for socket checks —
## `installed_items` stores ids, not defs, so the category can only be verified against the
## player's inventory. It defaults to empty and the check FAILS CLOSED: an unresolvable
## item refuses the socket rather than waving it through, because a gate that opens when it
## cannot verify is not a gate.
static func can_allocate(tree: SkillTree, inst: SymbotInstance, species: SpeciesDef,
		node_id: StringName, items: Dictionary = {}) -> Refusal:
	var node := tree.get_node_def(node_id)
	if node == null:
		return Refusal.NO_SUCH_NODE

	var allocated := allocated_set(inst, species)
	if allocated.has(node_id):
		return Refusal.ALREADY_ALLOCATED

	# Entry nodes belong to a species, not to a purchase. Reaching another species' door
	# by walking is not how you get in.
	if node.node_type == SkillNodeDefScript.NodeType.ENTRY:
		return Refusal.IS_ENTRY_NODE

	if not _touches_allocated(node, allocated):
		return Refusal.NOT_REACHABLE

	if unspent_points(inst) < node.point_cost():
		return Refusal.NO_POINTS

	if node.requires_item():
		return _check_socket(node, inst, items)

	return Refusal.OK


## A socket needs a point AND a fitted item of the right category (§4.4) — which is what
## makes hardware drops a second progression axis rather than more currency.
static func _check_socket(node: SkillNodeDef, inst: SymbotInstance,
		items: Dictionary) -> Refusal:
	var fitted_id = inst.installed_items.get(node.id, null)
	if fitted_id == null:
		return Refusal.SOCKET_EMPTY
	if node.socket_accepts == &"":
		return Refusal.OK
	var item: InstallItemDef = items.get(fitted_id, null)
	if item == null:
		# Fail closed — see can_allocate.
		return Refusal.SOCKET_WRONG_CATEGORY
	return Refusal.OK if item.fits(node.socket_accepts) else Refusal.SOCKET_WRONG_CATEGORY


static func _touches_allocated(node: SkillNodeDef, allocated: Dictionary) -> bool:
	for n in node.neighbours:
		if allocated.has(n):
			return true
	return false


## Allocate [param node_id]. Returns true when it happened; the caller should have asked
## [method can_allocate] first, but this re-checks because the UI's answer can be one tap
## stale after a level-up or an item being unfitted elsewhere.
static func allocate(tree: SkillTree, inst: SymbotInstance, species: SpeciesDef,
		node_id: StringName, items: Dictionary = {}) -> bool:
	if can_allocate(tree, inst, species, node_id, items) != Refusal.OK:
		return false
	inst.allocated_nodes.append(node_id)
	return true


## Every node the Symbot could allocate next, ignoring whether it can afford them. This is
## the frontier the tree UI highlights — showing what is *reachable* separately from what
## is *affordable* is what lets a player plan a route they cannot yet walk.
static func frontier(tree: SkillTree, inst: SymbotInstance,
		species: SpeciesDef) -> Array[StringName]:
	var allocated := allocated_set(inst, species)
	var seen: Dictionary = {}
	var out: Array[StringName] = []
	for id in allocated:
		for n in tree.neighbours_of(id):
			if allocated.has(n.id) or seen.has(n.id):
				continue
			if n.node_type == SkillNodeDefScript.NodeType.ENTRY:
				continue
			seen[n.id] = true
			out.append(n.id)
	return out


## Shortest walk from what is already allocated to [param target], as the node ids that
## would have to be bought, in order. Empty when unreachable or already held.
##
## Breadth-first because the tree is unweighted — every node costs one point — so the
## fewest nodes IS the cheapest route. The tree UI uses this for "show me the path".
static func path_to(tree: SkillTree, inst: SymbotInstance, species: SpeciesDef,
		target: StringName) -> Array[StringName]:
	var allocated := allocated_set(inst, species)
	if allocated.has(target) or not tree.has_node(target):
		return []

	var came_from: Dictionary = {}
	var queue: Array[StringName] = []
	var visited: Dictionary = {}
	for id in allocated:
		queue.append(id)
		visited[id] = true

	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for n in tree.neighbours_of(current):
			if visited.has(n.id) or n.node_type == SkillNodeDefScript.NodeType.ENTRY:
				continue
			visited[n.id] = true
			came_from[n.id] = current
			if n.id == target:
				return _rebuild_path(came_from, allocated, target)
			queue.append(n.id)
	return []


static func _rebuild_path(came_from: Dictionary, allocated: Dictionary,
		target: StringName) -> Array[StringName]:
	var path: Array[StringName] = []
	var cursor := target
	while not allocated.has(cursor):
		path.push_front(cursor)
		if not came_from.has(cursor):
			break
		cursor = came_from[cursor]
	return path


## Respec: refund every allocated node. Costs Scrap (§4.5) — free respec would make the
## tree a menu rather than a commitment, and commitment is what makes a build feel owned.
##
## Returns the Scrap cost, or -1 when the Symbot cannot afford it. Caller debits.
static func respec_cost(inst: SymbotInstance, cfg: BalanceConfig) -> int:
	return inst.allocated_nodes.size() * cfg.respec_scrap_per_node


## Clear every allocation. The entry node survives because it was never bought.
static func respec(inst: SymbotInstance) -> int:
	var refunded := inst.allocated_nodes.size()
	inst.allocated_nodes.clear()
	# Items stay fitted. Un-fitting them is its own action with its own Scrap cost (§4.4),
	# and silently ejecting a player's hardware during a respec would be a nasty surprise.
	return refunded


## Aggregate every stat bonus the allocated nodes contribute. Flat and percentage are kept
## apart because the stat pipeline applies them in that order, and folding them here would
## bake in an ordering the pipeline is supposed to own.
static func aggregate_stats(tree: SkillTree, inst: SymbotInstance,
		species: SpeciesDef) -> Dictionary:
	var flat: Dictionary = {}
	var percent: Dictionary = {}
	for id in allocated_set(inst, species):
		var node := tree.get_node_def(id)
		if node == null:
			continue
		for key in node.stat_bonus:
			flat[key] = int(flat.get(key, 0)) + int(node.stat_bonus[key])
		for key in node.stat_percent:
			percent[key] = int(percent.get(key, 0)) + int(node.stat_percent[key])
	return {"flat": flat, "percent": percent}


## Skills unlocked by allocated ACTIVE nodes, including ultimates.
static func granted_skills(tree: SkillTree, inst: SymbotInstance,
		species: SpeciesDef) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in allocated_set(inst, species):
		var node := tree.get_node_def(id)
		if node != null and node.node_type == SkillNodeDefScript.NodeType.ACTIVE \
				and node.skill_id != &"":
			out.append(node.skill_id)
	return out


## Passives granted by allocated PASSIVE and KEYSTONE nodes.
static func granted_passives(tree: SkillTree, inst: SymbotInstance,
		species: SpeciesDef) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in allocated_set(inst, species):
		var node := tree.get_node_def(id)
		if node == null or node.passive_id == &"":
			continue
		if node.node_type == SkillNodeDefScript.NodeType.PASSIVE \
				or node.node_type == SkillNodeDefScript.NodeType.KEYSTONE:
			out.append(node.passive_id)
	return out
