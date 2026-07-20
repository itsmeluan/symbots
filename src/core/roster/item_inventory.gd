## ItemInventory — install items the player owns but has not fitted (Core Design §4.4).
##
## Counts by item id rather than instances. An install item has no per-copy state — two T2
## Servos are interchangeable — so instances would be identity without meaning, and every
## screen would have to pick one arbitrarily.
##
## The consequence to be careful about: a FITTED item is not in here. Fitting moves it out,
## pulling it back puts it in. Anything that counts "how many do I have" must ask both this
## and the roster, or a player with one chip fitted sees zero and thinks it vanished.
class_name ItemInventory
extends RefCounted

## Emitted on any change, so screens render from a signal rather than polling.
signal inventory_changed

## item_id -> count. Zero-count entries are erased rather than kept, so `has()` and
## `count() > 0` cannot disagree.
var counts: Dictionary = {}


func count(item_id: StringName) -> int:
	return int(counts.get(item_id, 0))


func has(item_id: StringName) -> bool:
	return count(item_id) > 0


func add(item_id: StringName, amount: int = 1) -> void:
	if item_id == &"" or amount <= 0:
		return
	counts[item_id] = count(item_id) + amount
	inventory_changed.emit()


## Take one (or [param amount]) out. Returns false and changes NOTHING when the player does
## not have that many — a partial take would leave a socket half-paid.
func take(item_id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	var left := count(item_id) - amount
	if left <= 0:
		counts.erase(item_id)
	else:
		counts[item_id] = left
	inventory_changed.emit()
	return true


## Every owned id in stable alphabetical order, so a list screen does not reshuffle.
##
## Sorted by the STRING form deliberately. Godot compares StringNames by their internal
## pointer, not lexicographically, so a plain `sort()` gives an order that depends on
## interning and changes between runs — the list would silently reorder itself on some
## launches and not others, which is worse than no sorting at all because it looks random.
func owned_ids() -> Array:
	var ids: Array = counts.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	return ids


func total_items() -> int:
	var total := 0
	for id in counts:
		total += int(counts[id])
	return total


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id in counts:
		out[String(id)] = int(counts[id])
	return out


## Ids that no longer exist in the item catalog are dropped on load, unlike cleared stage
## ids: a phantom item would show in the inventory, be selectable for a socket, and fail to
## resolve — worse than simply not being there.
static func from_dict(raw: Dictionary, catalog: InstallItemCatalog = null) -> ItemInventory:
	var inv := ItemInventory.new()
	for key in raw:
		var id := StringName(str(key))
		if catalog != null and catalog.get_item(id) == null:
			continue
		var amount := int(raw[key])
		if amount > 0:
			inv.counts[id] = amount
	return inv
