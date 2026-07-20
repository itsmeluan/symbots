## SkillCatalog — the explicit manifest of every SkillDef that ships in a build.
##
## Same discipline as [PartCatalog] (ADR-0003): an entry not listed here does not exist in
## the game, and the catalog IS the reviewable manifest. Directory scanning is forbidden in
## the content load path — DirAccess returns `.remap` stubs inside an exported PCK, so a
## `*.tres` scan silently returns nothing after export and the game ships with no skills.
##
## To add a skill: create its .tres under assets/data/skills/, then append it here. The
## diff stays entry-scoped and reviewable.
##
## Frozen shared instance — never mutate entries at runtime.
class_name SkillCatalog
extends Resource

@export var entries: Array[SkillDef] = []


## Build the id -> SkillDef table the [BattleEngine] takes.
##
## Returns a fresh Dictionary each call; the engine never mutates it, but handing out the
## same instance would let one caller's edit reach every battle.
##
## Example:
##     var engine := BattleEngine.new(mine, theirs, catalog.to_table(), cfg, rng, log)
func to_table() -> Dictionary:
	var out: Dictionary = {}
	for s in entries:
		if s != null and s.id != &"":
			out[s.id] = s
	return out


func get_skill(id: StringName) -> SkillDef:
	for s in entries:
		if s != null and s.id == id:
			return s
	return null
