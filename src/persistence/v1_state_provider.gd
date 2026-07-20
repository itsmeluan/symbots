## V1StateProvider — persists the v1 roster, squad and currencies (ADR-0001 triad).
##
## Saves what the player would be furious to lose: which Symbots they own, how far each is
## levelled, where its points went, what hardware is fitted, who is in the squad, and both
## currency balances.
##
## WHAT IS NOT SAVED, AND WHY: a [SymbotInstance] stores a `species_id`, never the
## [SpeciesDef]. Base stats, part growth, passives and rarity are CONTENT, re-resolved from
## the catalog at restore. Writing the def into the save would freeze a copy of the balance
## table into every player's file, so a balance patch would silently not apply to anyone
## who had already played. The same reasoning covers tree nodes and install items — ids
## only, always.
##
## A species id that no longer resolves DROPS that Symbot with a warning rather than
## failing the load. A removed species should cost the player that Symbot, not their whole
## save. Allocated node ids that no longer exist are dropped the same way, and the points
## come back — a tree reshape must not leave a player paying for nodes that are gone.
extends RefCounted

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const WalletScript := preload("res://src/core/economy/wallet.gd")

## Stable provider key in the save envelope (ADR-0001).
const KEY := &"v1_state"

var _roster: PlayerRoster = null
var _wallet: Wallet = null
var _species: SpeciesCatalog = null
var _tree: SkillTree = null
var _log: LogSink = null


func _init(roster: PlayerRoster, wallet: Wallet, species: SpeciesCatalog,
		tree: SkillTree, log: LogSink = null) -> void:
	_roster = roster
	_wallet = wallet
	_species = species
	_tree = tree
	_log = log


## ADR-0001 triad — raw facts only. Nothing derived: aggregated stats are recomputed from
## the tree and the catalog on demand, so persisting them would create a second source of
## truth that can disagree with the pipeline.
func snapshot() -> Dictionary:
	var owned: Array = []
	if _roster != null:
		for s in _roster.symbots:
			owned.append(s.to_dict())
	return {
		"symbots": owned,
		"squad": _roster.squad.map(func(id): return String(id)) if _roster != null else [],
		"wallet": _wallet.to_dict() if _wallet != null else {},
	}


func restore(data: Dictionary) -> void:
	if _roster == null:
		return

	_roster.symbots.clear()
	for raw in data.get("symbots", []):
		var inst := _restore_symbot(raw)
		if inst != null:
			_roster.add(inst)

	_restore_squad(data.get("squad", []))

	if _wallet != null:
		var w := WalletScript.from_dict(data.get("wallet", {}))
		_wallet.scrap = w.scrap
		_wallet.alloy = w.alloy


func _restore_symbot(raw) -> SymbotInstance:
	if not (raw is Dictionary):
		return null
	var inst: SymbotInstance = SymbotInstanceScript.from_dict(raw)
	if inst == null:
		return null

	# A species that no longer ships costs the player that Symbot, not the save.
	if _species != null and _species.get_species(inst.species_id) == null:
		_warn(&"save_species_id_unresolved",
			{"species_id": String(inst.species_id), "instance": String(inst.instance_id)})
		return null

	_drop_missing_nodes(inst)
	return inst


## Drop allocated node ids the tree no longer has. The points return automatically because
## `unspent_points()` derives from the array's size — a tree reshape must never leave a
## player paying for nodes that are gone.
func _drop_missing_nodes(inst: SymbotInstance) -> void:
	if _tree == null:
		return
	var kept: Array[StringName] = []
	var dropped: Array[String] = []
	for id in inst.allocated_nodes:
		if _tree.has_node(id):
			kept.append(id)
		else:
			dropped.append(String(id))
	if dropped.is_empty():
		return
	inst.allocated_nodes = kept
	_warn(&"save_tree_nodes_dropped",
		{"instance": String(inst.instance_id), "nodes": dropped, "refunded": dropped.size()})

	# Fitted hardware in a socket that no longer exists is orphaned too. Left behind it
	# would be invisible to the player and unrecoverable — they could never open that
	# socket to pull it back out.
	for node_id in inst.installed_items.keys():
		if not _tree.has_node(StringName(str(node_id))):
			inst.installed_items.erase(node_id)


func _restore_squad(raw_squad) -> void:
	for i in _roster.squad.size():
		_roster.squad[i] = &""
	if not (raw_squad is Array):
		return
	for i in mini(raw_squad.size(), _roster.squad.size()):
		_roster.squad[i] = StringName(str(raw_squad[i]))

	# A save written before a species was removed can name a Symbot that no longer loaded.
	# Pruning here means the squad never fields a ghost — a failure that would otherwise
	# only show up as a battle starting one unit short.
	var dropped := _roster.prune_squad()
	if dropped > 0:
		_warn(&"save_squad_entries_pruned", {"dropped": dropped})


## Nothing to rederive: stats are computed on demand from the roster, the tree and the
## catalog, so the state is consistent the moment restore() returns. Declared because the
## triad is the contract, not because there is work to do.
func rederive() -> void:
	pass


func _warn(code: StringName, detail: Dictionary) -> void:
	if _log != null:
		_log.warn(code, detail)
