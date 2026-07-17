## Stub Enemy-DB reader for Encounter Zone sub-pool-validation specs (EZ-3).
##
## Mirrors the read seam EncounterResolver uses — `get_enemy(id) -> EnemyDef` (null
## for an unknown id), the same shape as the production `EnemyDB` autoload. Lets EZ-3
## tests arrange class/`spawn_enabled` per enemy_id without loading real catalog files
## (Control Manifest: no `DirAccess` content scanning, no def mutation of shared defs —
## these are throwaway defs the stub owns).
##
## preload()-ed, NOT class_name-declared — a class_name in tests/ would pollute the
## production global class registry (ADR-0002 §5).
extends RefCounted

var _by_id: Dictionary = {}


## Register an enemy and return self for chaining:
##   var db := StubEnemyReader.new().add(&"iron_crawler", EnemyDef.EnemyClass.WILD)
func add(id: StringName, enemy_class: int, spawn_enabled: bool = true) -> RefCounted:
	var def := EnemyDef.new()
	def.id = id
	def.enemy_class = enemy_class
	def.spawn_enabled = spawn_enabled
	_by_id[id] = def
	return self


## Shared-frozen-def read seam. Returns null for any unregistered id (the missing-id
## content-error path in `filter_valid`).
func get_enemy(id: StringName) -> EnemyDef:
	return _by_id.get(id)
