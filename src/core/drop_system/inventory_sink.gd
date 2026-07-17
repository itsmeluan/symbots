## InventorySink — the injected seam the Drop System hands new PartInstances to.
##
## The Drop System is pure core (ADR-0006) and must not know about Inventory
## persistence or id minting. On each successful roll it constructs a fresh
## [PartInstance] at upgrade tier 0 and pushes it through this seam; the concrete
## Inventory implementation (a later epic) mints the real `instance_id` and stores
## it. Keeping this an interface lets `src/core/drop_system/` stay pure and lets
## tests inject a spy that records the received instances.
##
## Usage:
##   var sink := MyInventory.new()          # extends InventorySink, implements receive
##   var ds := DropSystem.new(rng, balance, log, sink)
##   ds.resolve_drops(...)                  # each drop calls sink.receive_part_instance()
##
## This is an @abstract base: it declares the contract but cannot be instantiated.
## The production Inventory and test spies extend it. Test spies are `preload()`-ed
## or declared as inner classes — never `class_name`-declared (a `class_name` in
## `tests/` would enter the production global class registry; ADR-0002 §5).
@abstract
class_name InventorySink
extends RefCounted

## Receive a freshly-dropped part instance (always at upgrade tier 0). The sink
## owns persistence and id assignment; the Drop System never mutates the instance
## after handoff.
@abstract func receive_part_instance(instance: PartInstance) -> void
