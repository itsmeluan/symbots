## PartInstance — one equipped/owned copy of a part at a specific upgrade tier.
##
## A [PartDef] is the frozen shared *type* (ADR-0003); a PartInstance is a mutable
## per-copy record layered on top: the same `boltwell_arc_blaster` type can exist
## as many instances, each at its own upgrade `tier`, distinguished by `instance_id`.
## Assembly's 8-slot manifest holds PartInstances, and equip/displace move instances
## between the manifest and the Inventory without ever mutating the underlying def.
##
## This is the Assembly-layer record the stat pipeline consumes. The Inventory epic
## (not yet built) will own instance persistence and id minting; until then this is
## the shared shape both the equip path and its tests construct. `part` is a
## read-only reference to a frozen def — never mutate `part` or call `duplicate()`
## on it (`runtime_content_mutation` forbidden; ADR-0003).
class_name PartInstance
extends RefCounted

## Unique id for THIS copy (distinct from `part.id`, the shared type id). Inventory
## mints these; Assembly only reads them for displacement bookkeeping.
var instance_id: StringName = &""

## The frozen shared [PartDef] this is a copy of. Read-only.
var part: PartDef = null

## Upgrade tier of this copy (0–5). Drives Formula 2 / 2b scaling in the pipeline.
var tier: int = 0


func _init(p_instance_id: StringName = &"", p_part: PartDef = null, p_tier: int = 0) -> void:
	instance_id = p_instance_id
	part = p_part
	tier = p_tier
