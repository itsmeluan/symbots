## EnemyDB autoload — thin host delegating to the EnemyDB core class (ADR-0004 §1 slot 4).
##
## Registered as autoload "EnemyDB"; consumers read via `EnemyDB.get_enemy(id)`,
## `EnemyDB.has_enemy(id)`. This script is the AUTOLOAD WRAPPER only — all logic lives
## in `src/core/content/enemy_db.gd`. No logic is moved here.
##
## ADR-0004 inertness rule: zero _ready work. The BootScreen sequencer calls
## `load_catalog(catalog, log)` explicitly — never _ready. No I/O, no catalog loads,
## no signal connections, no cross-autoload reads in _ready.
##
## load_catalog delegates directly to the core EnemyDB instance (`_db`).
extends Node

## The core EnemyDB instance that holds the indexed catalog. All lookups delegate to it.
## Referenced via preload (not the `EnemyDB` class_name) — the autoload singleton is also
## named EnemyDB and shadows the class_name, so `EnemyDB.new()` here resolves to Nil.
const EnemyDBCore := preload("res://src/core/content/enemy_db.gd")
var _db := EnemyDBCore.new()

## Delegate: indexes [param catalog] into the id→def map.
## Called by BootScreen sequencer (ADR-0004 boot step 2), never in _ready.
## Returns true when every entry indexed cleanly, false on content_null_entry or
## content_duplicate_id (routes through injected [param log]).
func load_catalog(catalog: EnemyCatalog, log: LogSink) -> bool:
	return _db.load_catalog(catalog, log)

## Delegate: true when [param id] is present in the index.
func has_enemy(id: StringName) -> bool:
	return _db.has_enemy(id)

## Delegate: returns the shared frozen [EnemyDef] for [param id], or null for unknown id.
## Callers MUST null-check or guard with has_enemy().
func get_enemy(id: StringName) -> EnemyDef:
	return _db.get_enemy(id)

## Delegate: all loaded EnemyDef instances. Array is a snapshot; defs are not copied.
func all_enemies() -> Array[EnemyDef]:
	return _db.all_enemies()
