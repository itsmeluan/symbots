## MoveDB autoload — thin host delegating to the MoveDB core class (ADR-0004 §1 slot 5).
##
## Registered as autoload "MoveDB"; consumers read via `MoveDB.get_move(id)`,
## `MoveDB.has_move(id)`. This script is the AUTOLOAD WRAPPER only — all logic lives
## in `src/core/content/move_db.gd`. No logic is moved here.
##
## ADR-0004 inertness rule: zero _ready work. The BootScreen sequencer calls
## `load_catalog(catalog, log)` explicitly — never _ready. No I/O, no catalog loads,
## no signal connections, no cross-autoload reads in _ready.
##
## load_catalog delegates directly to the core MoveDB instance (`_db`).
extends Node

## The core MoveDB instance that holds the indexed catalog. All lookups delegate to it.
var _db: MoveDB = MoveDB.new()

## Delegate: indexes [param catalog] into the id→def map.
## Called by BootScreen sequencer (ADR-0004 boot step 2), never in _ready.
## Returns true when every entry indexed cleanly, false on content_null_entry or
## content_duplicate_id (routes through injected [param log]).
func load_catalog(catalog: MoveCatalog, log: LogSink) -> bool:
	return _db.load_catalog(catalog, log)

## Delegate: true when [param id] is present in the index.
func has_move(id: StringName) -> bool:
	return _db.has_move(id)

## Delegate: returns the shared frozen [MoveDef] for [param id], or null for unknown id.
## Callers MUST null-check or guard with has_move().
func get_move(id: StringName) -> MoveDef:
	return _db.get_move(id)
