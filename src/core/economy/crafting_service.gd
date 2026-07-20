## CraftingService — build a new Symbot from a learned blueprint (Core Design §5.1).
##
## The Alloy sink, and the collection payoff: beat a species enough to learn its blueprint,
## then spend Alloy to add one to your roster. Pure static over the injected library, wallet
## and roster, so the crafting screen's "can I build this?" and the actual build cannot
## disagree.
##
## A crafted Symbot arrives as a fresh Mk I at level 1 — the same starting point as the
## gift squad. Crafting gives you the species, not a shortcut past the levelling that makes
## it strong; that levelling is the game.
class_name CraftingService
extends RefCounted

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

## Why a craft was refused, so the UI can say which — "you have not found this blueprint"
## and "you cannot afford it" send the player to completely different places (a boss to
## beat versus a boss to farm).
enum Refusal {
	OK = 0,
	NO_SUCH_SPECIES = 1,
	BLUEPRINT_LOCKED = 2,
	CANNOT_AFFORD = 3,
}


## Alloy to build [param species_id]. Authored per species (rarer costs more) so the price
## reads off the SpeciesDef, never a table that can drift from it.
static func alloy_cost(species_id: StringName, catalog: SpeciesCatalog) -> int:
	var species := catalog.get_species(species_id) if catalog != null else null
	return maxi(0, species.craft_alloy_cost) if species != null else 0


## Can this species be built right now?
static func can_craft(species_id: StringName, catalog: SpeciesCatalog,
		library: BlueprintLibrary, wallet: Wallet) -> Refusal:
	if catalog == null or catalog.get_species(species_id) == null:
		return Refusal.NO_SUCH_SPECIES
	if library == null or not library.has_blueprint(species_id):
		return Refusal.BLUEPRINT_LOCKED
	if wallet == null or not wallet.can_afford(Wallet.ALLOY, alloy_cost(species_id, catalog)):
		return Refusal.CANNOT_AFFORD
	return Refusal.OK


## Build one. Charges Alloy and adds a fresh Mk I to the roster. Returns the new instance,
## or null on refusal.
##
## Charges BEFORE adding, and rolls back if the roster rejects the add — a wallet debited
## for a Symbot that never joined is the crafting version of the bug players never forgive.
## The new id is unique per craft so a second copy does not collide with the first.
static func craft(species_id: StringName, catalog: SpeciesCatalog,
		library: BlueprintLibrary, wallet: Wallet, roster: PlayerRoster,
		unique_suffix: int) -> SymbotInstance:
	if can_craft(species_id, catalog, library, wallet) != Refusal.OK:
		return null
	var cost := alloy_cost(species_id, catalog)
	if not wallet.spend(Wallet.ALLOY, cost):
		return null

	var inst := SymbotInstanceScript.new(
		StringName("crafted_%s_%d" % [species_id, unique_suffix]), species_id)
	if not roster.add(inst):
		wallet.earn(Wallet.ALLOY, cost)  # put it back — the build did not happen
		return null
	return inst


## Every species the player COULD build if Alloy were no object — the recipes they own.
## The crafting screen lists these; locked species are shown separately as "defeat X".
static func craftable_now(catalog: SpeciesCatalog, library: BlueprintLibrary) -> Array:
	var out: Array = []
	if catalog == null or library == null:
		return out
	for id in library.known_ids():
		if catalog.get_species(id) != null:
			out.append(id)
	return out
