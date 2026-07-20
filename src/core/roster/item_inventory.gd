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


## Every owned id, sorted, so a list screen renders in a stable order rather than in
## whatever order the drops happened to arrive.
func owned_ids() -> Array:
	var ids: Array = counts.keys()
	ids.sort()
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
