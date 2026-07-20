## PlayerRoster — every Symbot the player owns, and the four they field (Core Design §2, §3.1).
##
## Plain RefCounted with no autoload and no signals of its own: the roster is state, and
## the screens that show it subscribe to the owner that holds it. Keeping it injectable is
## what lets the offline-expedition simulator run against a roster the player is not
## currently looking at.
##
## Squad slots hold INSTANCE IDS, not instances. A slot pointing at an object would keep a
## released Symbot alive and let the squad silently field something the player scrapped.
class_name PlayerRoster
extends RefCounted

const SQUAD_SIZE := 4

## Owned Symbots, in acquisition order.
var symbots: Array[SymbotInstance] = []

## The four fielded slots. `&""` means empty — a squad may be short-handed, which is a
## real state early on and after a costly run.
var squad: Array[StringName] = [&"", &"", &"", &""]


func get_symbot(instance_id: StringName) -> SymbotInstance:
	for s in symbots:
		if s.instance_id == instance_id:
			return s
	return null


func owns(instance_id: StringName) -> bool:
	return get_symbot(instance_id) != null


func add(symbot: SymbotInstance) -> bool:
	if symbot == null or symbot.instance_id == &"" or owns(symbot.instance_id):
		return false
	symbots.append(symbot)
	return true


## Remove a Symbot from the roster, clearing any squad slot it occupied.
##
## Clearing the slot here rather than leaving it to the caller is deliberate: a released
## Symbot still named by a squad slot is a squad that fields a ghost, and the failure only
## shows up as a battle starting one unit short.
func release(instance_id: StringName) -> bool:
	var symbot := get_symbot(instance_id)
	if symbot == null:
		return false
	symbots.erase(symbot)
	for i in squad.size():
		if squad[i] == instance_id:
			squad[i] = &""
	return true


## Put a Symbot in a squad slot. Returns false when the slot is out of range or the
## Symbot is not owned.
##
## A Symbot already in another slot is MOVED rather than duplicated — fielding the same
## unit twice would double its turns and let one healer out-heal a whole enemy team.
func set_squad_slot(slot: int, instance_id: StringName) -> bool:
	if slot < 0 or slot >= SQUAD_SIZE:
		return false
	if instance_id != &"" and not owns(instance_id):
		return false
	if instance_id != &"":
		for i in squad.size():
			if squad[i] == instance_id:
				squad[i] = &""
	squad[slot] = instance_id
	return true


func clear_squad_slot(slot: int) -> bool:
	return set_squad_slot(slot, &"")


## The fielded Symbots, in slot order, skipping empty slots. This is what the battle
## builder consumes.
func squad_symbots() -> Array[SymbotInstance]:
	var out: Array[SymbotInstance] = []
	for id in squad:
		if id == &"":
			continue
		var s := get_symbot(id)
		if s != null:
			out.append(s)
	return out


func squad_size() -> int:
	return squad_symbots().size()


func is_squad_empty() -> bool:
	return squad_size() == 0


## Drop squad references to Symbots that are no longer owned. Called after a restore,
## where a save written before a content change can name something that has since gone.
func prune_squad() -> int:
	var dropped := 0
	for i in squad.size():
		if squad[i] != &"" and not owns(squad[i]):
			squad[i] = &""
			dropped += 1
	return dropped
