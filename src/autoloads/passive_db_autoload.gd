## PassiveDB autoload — thin host delegating to the PassiveDB core class (ADR-0004 §1 slot 6).
##
## Registered as autoload "PassiveDB"; consumers read via `PassiveDB.get_passive(id)`,
## `PassiveDB.has_passive(id)`. This script is the AUTOLOAD WRAPPER only — all logic
## lives in `src/core/content/passive_db.gd`. No logic is moved here.
##
## ADR-0004 inertness rule: zero _ready work. The BootScreen sequencer calls
## `load_catalog(catalog, log)` explicitly — never _ready. No I/O, no catalog loads,
## no signal connections, no cross-autoload reads in _ready.
##
## load_catalog delegates directly to the core PassiveDB instance (`_db`).
extends Node

## The core PassiveDB instance that holds the indexed catalog. All lookups delegate to it.
var _db: PassiveDB = PassiveDB.new()

## Delegate: indexes [param catalog] into the id→def map.
## Called by BootScreen sequencer (ADR-0004 boot step 2), never in _ready.
## Returns true when every entry indexed cleanly, false on content_null_entry or
## content_duplicate_id (routes through injected [param log]).
func load_catalog(catalog: PassiveCatalog, log: LogSink) -> bool:
	return _db.load_catalog(catalog, log)

## Delegate: true when [param id] is present in the index.
func has_passive(id: StringName) -> bool:
	return _db.has_passive(id)

## Delegate: returns the shared frozen [PassiveDef] for [param id], or null for unknown id.
## Callers MUST null-check or guard with has_passive().
func get_passive(id: StringName) -> PassiveDef:
	return _db.get_passive(id)
