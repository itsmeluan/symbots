## THROWAWAY spike probe — Part-DB Story 001 (typed-dict `.tres` round-trip gate).
##
## Minimal `PartDef`-shaped Resource carrying ONLY the load-bearing field under
## test: a `Dictionary[StringName, int]`. This is NOT the shipped `PartDef`
## schema (Story 002 builds that). It exists solely so the gate test can author
## an instance to `.tres`, reload it headless, and assert type preservation.
##
## Deliberately NO `class_name`: the probe stays out of the global class registry
## so it never contaminates real content authoring. The `.tres` references it by
## script path instead.
extends Resource

## The single field the spike verifies. StringName keys, int values.
@export var stat_bonuses: Dictionary[StringName, int] = {}


## Typed accessor under test (AC-2): must compile with a typed `-> int` return
## and hand back a usable `int`, never a `Variant`. Not an override, so 4.7
## GH-115763 (inherited typed-return methods needing explicit `return`) does not
## apply here.
func get_bonus(k: StringName) -> int:
	return stat_bonuses.get(k, 0)
