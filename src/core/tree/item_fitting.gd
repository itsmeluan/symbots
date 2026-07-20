## ItemFitting — putting hardware into sockets and pulling it back out (Core Design §4.4).
##
## Pure static over the roster's [ItemInventory] and a [SymbotInstance]. Separate from
## [TreeAllocator] because allocating a node and fitting a component are different actions
## with different costs: a point versus a component, and Scrap to undo.
##
## The rule that matters: **pulling a component out also de-allocates its socket node and
## refunds the point.** Without that, a player fits a T1 chip, buys the node, pulls the chip
## back for a small Scrap fee and keeps a permanently opened socket — hardware would gate
## nothing after the first cheap chip.
class_name ItemFitting
extends RefCounted

const SkillNodeDefScript := preload("res://src/core/tree/skill_node_def.gd")

## Why a fit or unfit was refused, so the UI can say which.
enum Refusal {
	OK = 0,
	NO_SUCH_NODE = 1,
	NOT_A_SOCKET = 2,
	NOT_OWNED = 3,
	WRONG_CATEGORY = 4,
	ALREADY_FITTED = 5,
	NOTHING_FITTED = 6,
	CANNOT_AFFORD_REMOVAL = 7,
}


## Can [param item_id] go into [param node_id] on this Symbot?
static func can_fit(tree: SkillTree, inst: SymbotInstance, node_id: StringName,
		item_id: StringName, inventory: ItemInventory,
		catalog: InstallItemCatalog) -> Refusal:
	var node := tree.get_node_def(node_id)
	if node == null:
		return Refusal.NO_SUCH_NODE
	if node.node_type != SkillNodeDefScript.NodeType.SOCKET:
		return Refusal.NOT_A_SOCKET
	if inst.installed_items.has(node_id):
		return Refusal.ALREADY_FITTED
	if inventory == null or not inventory.has(item_id):
		return Refusal.NOT_OWNED
	var item := catalog.get_item(item_id) if catalog != null else null
	if item == null or not item.fits(node.socket_accepts):
		return Refusal.WRONG_CATEGORY
	return Refusal.OK


## Fit the component. Takes it out of the inventory — a component in a socket is no longer
## a spare, and showing it in both places would let the player "fit" the same chip twice.
static func fit(tree: SkillTree, inst: SymbotInstance, node_id: StringName,
		item_id: StringName, inventory: ItemInventory,
		catalog: InstallItemCatalog) -> bool:
	if can_fit(tree, inst, node_id, item_id, inventory, catalog) != Refusal.OK:
		return false
	if not inventory.take(item_id):
		return false
	inst.installed_items[node_id] = item_id
	return true


## Can the component in [param node_id] be pulled out?
static func can_unfit(inst: SymbotInstance, node_id: StringName, wallet: Wallet,
		catalog: InstallItemCatalog) -> Refusal:
	if not inst.installed_items.has(node_id):
		return Refusal.NOTHING_FITTED
	var item := catalog.get_item(inst.installed_items[node_id]) if catalog != null else null
	var cost := item.removal_scrap_cost if item != null else 0
	if wallet != null and not wallet.can_afford(Wallet.SCRAP, cost):
		return Refusal.CANNOT_AFFORD_REMOVAL
	return Refusal.OK


## Scrap the player will be charged to pull [param node_id]'s component.
static func removal_cost(inst: SymbotInstance, node_id: StringName,
		catalog: InstallItemCatalog) -> int:
	if not inst.installed_items.has(node_id) or catalog == null:
		return 0
	var item := catalog.get_item(inst.installed_items[node_id])
	return item.removal_scrap_cost if item != null else 0


## Pull the component, returning it to the inventory, and RE-LOCK the socket by dropping
## its allocation. Returns the item id, or empty on refusal.
##
## Charging happens before anything moves: a wallet debited for a removal that did not
## happen is the same class of bug as being charged for an upgrade that did not apply.
static func unfit(inst: SymbotInstance, node_id: StringName, inventory: ItemInventory,
		wallet: Wallet, catalog: InstallItemCatalog) -> StringName:
	if can_unfit(inst, node_id, wallet, catalog) != Refusal.OK:
		return &""
	var cost := removal_cost(inst, node_id, catalog)
	if wallet != null and cost > 0 and not wallet.spend(Wallet.SCRAP, cost):
		return &""

	var item_id: StringName = inst.installed_items[node_id]
	inst.installed_items.erase(node_id)
	if inventory != null:
		inventory.add(item_id)

	# Re-lock the socket. Leaving it allocated would mean one cheap chip permanently opens
	# a node — hardware would gate nothing after the first fit.
	inst.allocated_nodes.erase(node_id)
	return item_id


## Item ids the player owns that would fit [param node_id], sorted by tier descending so
## the strongest option is first — the player almost always wants their best chip, and
## making them scroll for it is friction with no decision in it.
static func fitting_options(tree: SkillTree, node_id: StringName,
		inventory: ItemInventory, catalog: InstallItemCatalog) -> Array[StringName]:
	var out: Array[StringName] = []
	var node := tree.get_node_def(node_id)
	if node == null or node.node_type != SkillNodeDefScript.NodeType.SOCKET:
		return out
	if inventory == null or catalog == null:
		return out

	var owned := inventory.owned_ids()
	var fitting: Array = []
	for item_id in owned:
		var item := catalog.get_item(item_id)
		if item != null and item.fits(node.socket_accepts):
			fitting.append({"id": item_id, "tier": int(item.tier)})
	fitting.sort_custom(func(a, b): return int(a["tier"]) > int(b["tier"]))
	for entry in fitting:
		out.append(entry["id"])
	return out
