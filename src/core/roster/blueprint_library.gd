## BlueprintLibrary — which species the player has learned to build (Core Design §5.1, §6.2).
##
## A blueprint is a permanent RECIPE unlock, not a consumable. Once you have beaten the boss
## that drops a species' blueprint, you can craft that species — repeatedly, paying Alloy
## each time. This follows from locked design: a player may own several of the same species
## built differently (§4.2), so crafting has to be repeatable, which means the blueprint is
## the recipe and the Alloy is the per-build cost.
##
## Stored as a set of species ids. The library never holds a SpeciesDef — a blueprint for a
## species that no longer ships is simply dropped on load, the same way a cut species is.
class_name BlueprintLibrary
extends RefCounted

## Emitted when a new blueprint is learned, so the map/reward screen can react.
signal blueprint_unlocked(species_id: StringName)

## species_id -> true. A set; membership is the whole state.
var unlocked: Dictionary = {}


func has_blueprint(species_id: StringName) -> bool:
	return unlocked.has(species_id)


## Learn a blueprint. Returns true only when it was NEW — a boss replayed for Scrap should
## not re-announce a blueprint the player already owns.
func unlock(species_id: StringName) -> bool:
	if species_id == &"" or unlocked.has(species_id):
		return false
	unlocked[species_id] = true
	blueprint_unlocked.emit(species_id)
	return true


## Every learned species id, sorted for a stable list order (StringName sorts by pointer,
## not text, so sort by String — the same gotcha the item inventory hit).
func known_ids() -> Array:
	var ids: Array = unlocked.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	return ids


func count() -> int:
	return unlocked.size()


func to_dict() -> Dictionary:
	return {"unlocked": known_ids().map(func(id): return String(id))}


## Ids for species that no longer ship are dropped on load — a phantom recipe would show a
## craftable species the game cannot resolve.
static func from_dict(raw: Dictionary, catalog: SpeciesCatalog = null) -> BlueprintLibrary:
	var lib := BlueprintLibrary.new()
	for id in raw.get("unlocked", []):
		var sid := StringName(str(id))
		if catalog != null and catalog.get_species(sid) == null:
			continue
		lib.unlocked[sid] = true
	return lib
