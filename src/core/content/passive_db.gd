## PassiveDB — loads the PassiveCatalog into a read-only O(1) index and vends defs.
##
## Registered as an autoload (final name/order in ADR-0004); consumers read
## project-wide via `PassiveDB.get_passive(id)`. This is a THIN HOST (ADR-0004): it
## does NO I/O, catalog loads, signal connections, or cross-autoload reads in
## `_ready` (`autoload_ready_work` is forbidden). The BootScreen sequencer drives
## `load_catalog` explicitly — never `_ready`. Autoload wiring into project.godot is
## a boot-integration concern (ADR-0004 boot epic), NOT this story.
##
## Read-only contract (ADR-0003 §4): lookups return the SHARED frozen def instance.
## Never mutate a returned def, and never call `duplicate()` / `duplicate_deep()` on
## a def or catalog (`runtime_content_mutation` forbidden) — `duplicate()` shares
## nested references and is a mutation trap, not a safe copy. Systems needing mutable
## state copy specific fields into their own structures.
##
## No `DirAccess` anywhere in the load path (`content_directory_scanning` forbidden;
## ADR-0003) — content arrives only via the typed catalog reference.
extends Node

## Index of every loaded passive, keyed by its unique id. O(1) `Dictionary.get`
## lookups, no per-lookup allocation (guardrail).
var _by_id: Dictionary[StringName, PassiveDef] = {}

## Indexes every entry of [param catalog] into the id->def map.
##
## Dependency-injected (catalog + log_sink as parameters) so GUT exercises the exact
## production path with fixture catalogs — no autoload coupling.
##
## FATAL (returns false, halting the boot content gate) when:
##   - a catalog slot is null (stale/deleted authored entry) -> `content_null_entry`
##   - two entries share an id within this catalog -> `content_duplicate_id`
##
## All fatal reporting routes through the injected [param log_sink] — never
## `push_error()` from `src/` (`global_push_diagnostics` forbidden; ADR-0002).
## Returns true when every entry indexed cleanly.
func load_catalog(catalog: PassiveCatalog, log_sink: LogSink) -> bool:
	for def in catalog.entries:
		if def == null:  # stale/deleted catalog slot = fatal
			log_sink.error(&"content_null_entry", {"db": &"passive"})
			return false
		if _by_id.has(def.id):  # duplicate id within a catalog = fatal
			log_sink.error(&"content_duplicate_id", {"db": &"passive", "id": def.id})
			return false
		_by_id[def.id] = def
	return true

## True when [param id] is present in the index. Use as the guard for the null
## contract on [method get_passive].
func has_passive(id: StringName) -> bool:
	return _by_id.has(id)

## Returns the shared frozen [PassiveDef] for [param id], or null for any unknown id
## (including &"" and a null argument, both of which coerce to a missing key) —
## AC-PDB-01 / EC-PDB-01. The caller decides fallback (the Part DB / TBC log the
## content error and skip); this getter never throws.
##
## The `-> PassiveDef` annotation does NOT protect callers from null: GDScript object
## types are nullable, so this compiles and runs while silently delivering null.
## Callers MUST null-check, or guard with [method has_passive].
func get_passive(id: StringName) -> PassiveDef:
	return _by_id.get(id)
