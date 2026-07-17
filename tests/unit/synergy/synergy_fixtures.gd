## Shared test doubles + factories for Synergy System tests (Stories 001–005).
##
## preload()-ed, NOT class_name-declared (ADR-0002 §5): a class_name in tests/ would
## pollute the production global class registry. Preloaded via its res:// path by each
## synergy suite.
extends RefCounted

const TierDef = preload("res://src/core/synergy/synergy_tier_def.gd")


## A minimal part stand-in: the Synergy System reads ONLY `synergy_tags`, so a duck-typed
## holder is a faithful (and null-capable) stand-in for a PartDef's tag surface. Using it
## lets AC-SYN-19 Scenario B set `synergy_tags = null`, which PartDef's typed
## `Array[StringName]` field cannot hold.
class TagPart:
	var synergy_tags


## Builds a [TagPart] carrying [param tags] (an Array of StringName, or null for the
## EC-SYN-07 null-field case). A plain array literal is copied into a typed
## `Array[StringName]` so it matches PartDef's real field type.
static func part(tags) -> TagPart:
	var p := TagPart.new()
	if tags == null:
		p.synergy_tags = null
	else:
		var typed: Array[StringName] = []
		for t in tags:
			typed.append(t)
		p.synergy_tags = typed
	return p


## Builds a [SynergyTierDef]. [param requirements] is `[[tag, min_count], ...]`;
## [param stat_delta] is `{StringName: int}`; [param effects] is an Array of StringName
## (copied into the typed field).
static func tier(id: StringName, requirements: Array, stat_delta: Dictionary = {}, effects: Array = []) -> TierDef:
	var typed_effects: Array[StringName] = []
	for e in effects:
		typed_effects.append(e)
	return TierDef.new(id, requirements, stat_delta, typed_effects)


## An 8-length array with [param parts] placed at the front and the rest null. Fewer than
## 8 entries pads with null; used to assemble slot fixtures compactly.
static func slots(parts: Array) -> Array:
	var out: Array = []
	for i in range(8):
		out.append(parts[i] if i < parts.size() else null)
	return out
