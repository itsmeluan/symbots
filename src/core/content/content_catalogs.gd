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

## The Move Database manifest (Move-DB Story 001). Null in a Part-only validation
## (e.g. every Part-DB test fixture) — the Move schema/authoring family runs ONLY
## when this is provided, so prior-story fixtures that mount no move catalog stay
## green. Same gating discipline as [member balance] / [member references_mounted].
var moves: MoveCatalog

## The Passive Database manifest (Passive-DB Story 001). Null in a validation that
## mounts no passive catalog (e.g. Part-only / Move-only fixtures) — the Passive
## schema/authoring family runs ONLY when this is provided, so prior-story fixtures
## stay green. Same gating discipline as [member moves].
var passives: PassiveCatalog

## The Consumable Database manifest (Consumable-DB Story 001). Null in a validation
## that mounts no consumable catalog (e.g. Part/Move/Passive-only fixtures) — the
## Consumable schema/authoring family runs ONLY when this is provided, so prior-story
## fixtures stay green. Same gating discipline as [member moves] / [member passives].
var consumables: ConsumableCatalog

## The Enemy Database manifest (Enemy-DB Story 004). Null in a validation that mounts
## no enemy catalog — the Enemy schema family runs ONLY when this is provided, so all
## prior-story fixtures (Part/Move/Passive/Consumable-only) stay green without any
## modification. Same gating discipline as [member consumables].
## APPEND-ONLY: this field is the last slot in the aggregate — never reorder.
var enemies: EnemyCatalog

## The single balance tuning Resource (ADR-0005). The content-composition families
## (Story 008: stat budgets, primary caps/floors) validate against its tables, so
## they only run when it is provided; the schema families (Story 007) do not need
## it and run regardless. Null in a schema-only validation (e.g. Story 007 tests).
var balance: BalanceConfig

## The set of valid Move DB skill IDs, as a `{StringName: true}` membership set
## (ADR-0003: cross-DB references are `StringName` IDs, never Resource links). Read
## via `.has(id)` for AC-13 / EC-MDB-01 resolution. Populated only when [member
## references_mounted] is true. A lightweight id-set (not the full `MoveCatalog`)
## is used deliberately — O(1) `.has()` resolution with no `Resource`-link coupling.
## Build it from a loaded catalog with [method move_ids_from] so the real boot and
## test fixtures populate it identically (Move-DB Story 006).
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


## Build the [member move_ids] membership set from a loaded [MoveCatalog]
## (Move-DB Story 006). One canonical builder so the real boot and every test
## fixture populate the resolution seam identically: each entry's `id` maps to
## `true`. A null catalog or a null entry contributes nothing (the schema family
## reports those separately). O(n) build, O(1) `.has()` resolution.
static func move_ids_from(catalog: MoveCatalog) -> Dictionary:
	var ids := {}
	if catalog == null:
		return ids
	for move in catalog.entries:
		if move != null:
			ids[move.id] = true
	return ids


## Build the [member passive_ids] membership set from a loaded [PassiveCatalog]
## (Passive-DB Story 006). The Part→Passive analogue of [method move_ids_from]:
## one canonical builder shared by the real boot and every test fixture so the
## `part.passive_id` resolution seam populates identically. Each entry's `id` maps
## to `true`; a null catalog or a null entry contributes nothing (the schema family
## reports those separately). O(n) build, O(1) `.has()` resolution.
static func passive_ids_from(catalog: PassiveCatalog) -> Dictionary:
	var ids := {}
	if catalog == null:
		return ids
	for passive in catalog.entries:
		if passive != null:
			ids[passive.id] = true
	return ids
