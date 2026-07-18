## WorldLootDB autoload — stub host for the World Loot DB (ADR-0004 §1 slot 8).
##
## Registered as autoload "WorldLootDB". The WorldLootDB content (loot nodes, drop
## tables for overworld collection) is NOT authored in the MVP foundation wave — the
## full implementation is a future authoring story. This stub satisfies the 11-slot
## autoload roster contract so BootScreen can call load_catalog() without branching.
##
## ADR-0004 inertness rule: zero _ready work. No I/O, no catalog loads, no signal
## connections, no cross-autoload reads in _ready.
##
## TODO (WorldLoot authoring story): replace this stub with a real DB wrapper
## analogous to part_db_autoload.gd once LootNodeDef + LootCatalog are authored.
extends Node

## Stub: accepts any catalog argument and always returns true (empty DB is valid —
## BootScreen does not treat an unloaded WorldLootDB as a fatal error; the
## ContentValidator gate governs whether missing world-loot content is acceptable
## for a given build). log is accepted but never called.
func load_catalog(catalog: Resource, log: LogSink) -> bool:
	# TODO: delegate to a real WorldLootDB core class when authored.
	return true
