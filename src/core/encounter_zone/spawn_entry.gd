## SpawnEntry — one weighted WILD candidate in a terrain patch's sub-pool (Rule 2).
##
## A typed, `.tres`-backed value object read through the content catalog and never
## mutated at runtime (ADR-0003). Cross-DB reference is a StringName `enemy_id`;
## the referenced Enemy DB entry must be `enemy_class == WILD` and
## `spawn_enabled == true` — validated by Story 003 (sub-pool filtering), not here.
##
## `is_farmable_target` is a content-authoring signal LOCAL to Encounter Zone
## (Rule 2a): it marks a build-critical farming host so the 20%-of-patch-weight
## floor can be enforced mechanically (Story 008 linter, AC-EZ-54B). It is not
## enemy stat data and creates no Enemy DB errata obligation.
class_name SpawnEntry
extends Resource

## ID of the Enemy DB entry this entry can spawn (e.g. &"rust_hound"). &"" is the
## null-equivalent / invalid id sentinel — caught by Story 003 / Story 008.
@export var enemy_id: StringName = &""

## Relative selection weight for the EZ-2 cumulative-weight walk (Story 002).
## An entry's probability is `spawn_weight ÷ patch total_weight`. A non-positive
## weight is invalid — Story 003 excludes `spawn_weight <= 0`. Default 0 (sentinel).
@export var spawn_weight: int = 0

## Marks this entry as a build-critical farming host (Rule 2a). When `true`, the
## Story 008 linter enforces `spawn_weight >= 20%` of the patch's total weight.
## Default `false` — filler / pacing enemies face no weight floor.
@export var is_farmable_target: bool = false
