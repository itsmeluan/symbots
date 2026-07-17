## SynergyTierDef — the runtime definition of one synergy tier (Synergy System, Core).
##
## A plain dependency-injected `RefCounted` value object: the [SynergySystem] is
## constructed with an `Array[SynergyTierDef]` registry and reads it read-only.
##
## This is deliberately NOT a `.tres` content def yet — the authored data format
## (a dedicated `SynergyDatabase.tres`? part of the Part DB?) is OQ-1, still open,
## as are the MVP stat values (OQ-2) and the effect-ID roster (OQ-3, owned by the
## TBC GDD). The engine (this class + [SynergySystem]) is built and unit-tested
## against injected tiers now; content authoring is a later pass once those resolve.
##
## Fields:
##   [member id]           — the tier's stable id; ALSO the alphabetical sort key
##                           (via `String(id)`) that makes SYN-F3 dedup deterministic.
##   [member requirements] — AND-logic activation list; each element is a
##                           `[StringName tag, int min_count]` pair (SYN-F2).
##   [member stat_delta]   — additive stat contribution when active (StringName → int).
##   [member effects]      — effect ids contributed when active (deduplicated in SYN-F3).
class_name SynergyTierDef
extends RefCounted

## Stable tier id and the `String(id)` alphabetical sort key (SYN-F3 determinism).
var id: StringName = &""

## AND-logic activation requirements: `[[tag, min_count], ...]`. A tier activates
## only when EVERY pair satisfies `tag_count[tag] >= min_count` (SYN-F2). A tier with
## an empty list, or any `min_count < 1`, is skipped and logged (EC-SYN-12 / EC-SYN-13).
var requirements: Array = []

## Additive stat contribution folded into the bonus block when the tier is active
## (SYN-F3). Aggregation is blind — unknown stat keys are summed verbatim (EC-SYN-06).
var stat_delta: Dictionary = {}

## Effect ids contributed when active. Flattened in alphabetical tier order and
## keep-first deduplicated in SYN-F3.
var effects: Array[StringName] = []


func _init(
	p_id: StringName = &"",
	p_requirements: Array = [],
	p_stat_delta: Dictionary = {},
	p_effects: Array[StringName] = []
) -> void:
	id = p_id
	requirements = p_requirements
	stat_delta = p_stat_delta
	effects = p_effects
