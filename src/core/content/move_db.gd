## MoveDB — loads the MoveCatalog into a read-only O(1) index and vends defs.
##
## Registered as an autoload (final name/order in ADR-0004); consumers read
## project-wide via `MoveDB.get_move(id)`. This is a THIN HOST (ADR-0004): it does
## NO I/O, catalog loads, signal connections, or cross-autoload reads in `_ready`
## (`autoload_ready_work` is forbidden). The BootScreen sequencer drives
## `load_catalog` explicitly — never `_ready`. Autoload wiring into project.godot
## is a boot-integration concern (ADR-0004 boot epic), NOT this story.
##
## Read-only contract (ADR-0003 §4): lookups return the SHARED frozen def
## instance. Never mutate a returned def, and never call `duplicate()` /
## `duplicate_deep()` on a def or catalog (`runtime_content_mutation` forbidden) —
## `duplicate()` shares nested references and is a mutation trap, not a safe copy.
## Systems needing mutable state copy specific fields into their own structures.
##
## No `DirAccess` anywhere in the load path (`content_directory_scanning`
## forbidden; ADR-0003) — content arrives only via the typed catalog reference.
extends Node

## Index of every loaded move, keyed by its unique id. O(1) `Dictionary.get`
## lookups, no per-lookup allocation (guardrail).
var _by_id: Dictionary[StringName, MoveDef] = {}

## Indexes every entry of [param catalog] into the id→def map.
##
## Dependency-injected (catalog + log_sink as parameters) so GUT exercises the
## exact production path with fixture catalogs — no autoload coupling.
##
## FATAL (returns false, halting the boot content gate) when:
##   - a catalog slot is null (stale/deleted authored entry) → `content_null_entry`
##   - two entries share an id within this catalog → `content_duplicate_id` (AC-02)
##
## All fatal reporting routes through the injected [param log_sink] — never
## `push_error()` from `src/` (`global_push_diagnostics` forbidden; ADR-0002).
## Returns true when every entry indexed cleanly.
func load_catalog(catalog: MoveCatalog, log_sink: LogSink) -> bool:
	for def in catalog.entries:
		if def == null:  # stale/deleted catalog slot = fatal
			log_sink.error(&"content_null_entry", {"db": &"move"})
			return false
		if _by_id.has(def.id):  # duplicate id within a catalog = fatal
			log_sink.error(&"content_duplicate_id", {"db": &"move", "id": def.id})
			return false
		_by_id[def.id] = def
	return true

## True when [param id] is present in the index. Use as the guard for the null
## contract on [method get_move].
func has_move(id: StringName) -> bool:
	return _by_id.has(id)

## Returns the shared frozen [MoveDef] for [param id], or null for any unknown
## id (including &"" and a null argument, both of which coerce to a missing key).
##
## The `-> MoveDef` annotation does NOT protect callers from null: GDScript object
## types are nullable, so this compiles and runs while silently delivering null.
## Callers MUST null-check, or guard with [method has_move].
func get_move(id: StringName) -> MoveDef:
	return _by_id.get(id)
