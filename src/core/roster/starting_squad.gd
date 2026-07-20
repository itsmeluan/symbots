## StartingSquad — what a brand-new player is handed (Core Design §2.1, §3.1).
##
## Four Symbots, one of each role, so the very first battle can teach the role system by
## USING it rather than by explaining it. A new player who starts with four DPS learns
## that tanks and healers exist only by losing to them.
##
## All four are the COMMON species of their role. Handing out a rare on turn one would
## spend the rarity ladder's first rung before the player knows there is a ladder.
class_name StartingSquad
extends RefCounted

## The gift roster, in squad order: tank front, then damage, then sustain. The order is
## cosmetic — turn order is speed-based (§3.2) — but it reads as a squad rather than a
## list, which is what a first screen has to do.
const SPECIES: Array[StringName] = [
	&"boltshell",    ## TANK    — the taunt rule is visible from battle one
	&"rustcrawler",  ## DPS     — something that kills things
	&"solderfly",    ## HEALER  — something that keeps them alive
	&"coilsprite",   ## SUPPORT — the role whose value is least obvious, so it starts owned
]


## Grant the starting squad into [param roster] and field all four.
##
## Returns the number granted. Does nothing and returns 0 when the roster already has
## Symbots — this is a NEW-PLAYER gift, and re-granting on every boot would quietly hand
## an existing player duplicates every time they launched the game.
static func grant(roster: PlayerRoster, catalog: SpeciesCatalog,
		log: LogSink = null) -> int:
	if roster == null or not roster.symbots.is_empty():
		return 0

	var granted := 0
	for species_id in SPECIES:
		if catalog != null and catalog.get_species(species_id) == null:
			# A starting species that no longer ships would otherwise hand the player an
			# instance nothing can resolve, and the squad would field one unit fewer with
			# no explanation.
			if log != null:
				log.warn(&"starting_squad_species_missing", {"species": String(species_id)})
			continue
		var inst := SymbotInstance.new(
			StringName("starter_%s" % species_id), species_id)
		if roster.add(inst):
			roster.set_squad_slot(granted, inst.instance_id)
			granted += 1
	return granted


## True when this roster looks like a fresh save that has never been granted anything.
static func is_new_player(roster: PlayerRoster) -> bool:
	return roster != null and roster.symbots.is_empty()
