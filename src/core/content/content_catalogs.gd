## ContentCatalogs — the aggregate of every loaded content catalog in a build.
##
## A plain dependency-injection bundle (RefCounted, not a Resource — it is
## assembled at boot from already-loaded catalog resources, never authored as a
## `.tres`). It mirrors ADR-0004's `ServiceContext` bundle pattern: one typed
## field per content database, handed whole to the [ContentValidator] and to any
## system that needs cross-DB lookups.
##
## Fields are APPEND-ONLY — as the Move / Passive / Consumable / Enemy databases
## come online, append their catalogs here; never reorder or remove. Story 007
## ships the Part DB slot only; Stories 008–009 add cross-DB families that read
## the other slots from this same aggregate.
class_name ContentCatalogs
extends RefCounted

## The Part Database manifest (Story 002). Null only in malformed test setups —
## the validator reports `content_missing_part_catalog` rather than crashing.
var parts: PartCatalog

## The single balance tuning Resource (ADR-0005). The content-composition families
## (Story 008: stat budgets, primary caps/floors) validate against its tables, so
## they only run when it is provided; the schema families (Story 007) do not need
## it and run regardless. Null in a schema-only validation (e.g. Story 007 tests).
var balance: BalanceConfig

## The set of valid Move DB skill IDs, as a `{StringName: true}` membership set
## (ADR-0003: cross-DB references are `StringName` IDs, never Resource links). Read
## via `.has(id)` for AC-13 resolution. Populated only when [member
## references_mounted] is true. A lightweight id-set (not a full `MoveCatalog`) is
## used deliberately — the Move DB epic owns the real catalog schema; this is only
## the resolution seam the real boot fills from the loaded Move DB.
var move_ids: Dictionary = {}

## The set of valid Passive DB IDs, as a `{StringName: true}` membership set. Same
## contract and rationale as [member move_ids] — see there.
var passive_ids: Dictionary = {}

## True once a Move + Passive resolution index has been mounted (the real boot, or
## a Story 009 test fixture). The Story 009 referential + level-field family runs
## ONLY when this is true; prior-story validations (007/008) leave it false and
## skip that family, so their fixtures — which set no level data and mount no
## reference index — stay green. Mirrors the `balance != null` gate for Story 008.
var references_mounted: bool = false
