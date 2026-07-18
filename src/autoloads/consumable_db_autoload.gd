## ConsumableDB autoload — thin host delegating to the ConsumableDB core class (ADR-0004 §1 slot 7).
##
## Registered as autoload "ConsumableDB"; consumers read via
## `ConsumableDB.get_consumable(id)`, `ConsumableDB.has_consumable(id)`. This script is
## the AUTOLOAD WRAPPER only — all logic lives in `src/core/content/consumable_db.gd`.
## No logic is moved here.
##
## ADR-0004 inertness rule: zero _ready work. The BootScreen sequencer calls
## `load_catalog(catalog, log)` explicitly — never _ready. No I/O, no catalog loads,
## no signal connections, no cross-autoload reads in _ready.
##
## load_catalog delegates directly to the core ConsumableDB instance (`_db`).
extends Node

## The core ConsumableDB instance that holds the indexed catalog. All lookups delegate to it.
## Referenced via preload (not the `ConsumableDB` class_name) — the autoload singleton is also
## named ConsumableDB and shadows the class_name, so `ConsumableDB.new()` here resolves to Nil.
const ConsumableDBCore := preload("res://src/core/content/consumable_db.gd")
var _db := ConsumableDBCore.new()

## Delegate: indexes [param catalog] into the id→def map.
## Called by BootScreen sequencer (ADR-0004 boot step 2), never in _ready.
## Returns true when every entry indexed cleanly, false on content_null_entry or
## content_duplicate_id (routes through injected [param log]).
func load_catalog(catalog: ConsumableCatalog, log: LogSink) -> bool:
	return _db.load_catalog(catalog, log)

## Delegate: true when [param id] is present in the index.
func has_consumable(id: StringName) -> bool:
	return _db.has_consumable(id)

## Delegate: returns the shared frozen [ConsumableDef] for [param id], or null for
## unknown id. Callers MUST null-check or guard with has_consumable().
func get_consumable(id: StringName) -> ConsumableDef:
	return _db.get_consumable(id)
