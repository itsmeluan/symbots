## StageProgress — which stages are cleared, and therefore which are open (Core Design §6).
##
## Availability is DERIVED from what is cleared, never stored. Storing an "unlocked" flag
## alongside a "cleared" flag creates two sources of truth that drift the moment a stage's
## requirements are edited — and the drift shows as a player permanently locked out of
## content, which is unrecoverable without a save edit.
class_name StageProgress
extends RefCounted

## Stage ids the player has completed, as a set.
var cleared: Dictionary = {}

## Highest endless tier reached. Progression never ends (§1), so this is unbounded rather
## than a stage id.
var endless_tier: int = 0


func is_cleared(stage_id: StringName) -> bool:
	return cleared.has(stage_id)


func mark_cleared(stage_id: StringName) -> void:
	cleared[stage_id] = true


## True when every prerequisite of [param stage] is cleared. A stage with no requirements
## is open from the start.
func is_available(stage: StageDef) -> bool:
	if stage == null:
		return false
	for req in stage.requires:
		if not is_cleared(req):
			return false
	return true


## Stages the player can enter right now, in catalog order.
func available_stages(catalog: StageCatalog) -> Array[StageDef]:
	var out: Array[StageDef] = []
	for s in catalog.entries:
		if s != null and is_available(s):
			out.append(s)
	return out


## Available stages the player has NOT yet cleared — what the map should draw the player's
## eye toward. A map that highlights everything highlights nothing.
func next_stages(catalog: StageCatalog) -> Array[StageDef]:
	var out: Array[StageDef] = []
	for s in available_stages(catalog):
		if not is_cleared(s.id):
			out.append(s)
	return out


func to_dict() -> Dictionary:
	return {
		"cleared": cleared.keys().map(func(k): return String(k)),
		"endless_tier": endless_tier,
	}


## Ids that no longer exist in the catalog are kept, not dropped: a stage removed in one
## patch and restored in the next should not silently re-lock content the player already
## beat. Unlike a Symbot or a tree node, a stale cleared-id costs nothing to carry.
static func from_dict(raw: Dictionary) -> StageProgress:
	var p := StageProgress.new()
	for id in raw.get("cleared", []):
		p.cleared[StringName(str(id))] = true
	p.endless_tier = maxi(0, int(raw.get("endless_tier", 0)))
	return p
