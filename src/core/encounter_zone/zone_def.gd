## ZoneDef — the static spawn-table authority for one explorable area (Rule 1).
##
## A typed, `.tres`-backed value object read read-only through the content catalog
## (ADR-0003); Encounter Zone owns NO combat state — it is read-only at runtime,
## bridging "where the player is standing" to "what battle starts". MVP authors
## exactly one ZoneDef (the schema generalizes to more without changes).
##
## `spawn_enabled` is the zone-level master switch (Rule 1 / EC-EZ-10): when `false`,
## every patch is inert — EZ-1 never rolls and EZ-2 is never called (AC-EZ-57).
class_name ZoneDef
extends Resource

## Unique zone identifier (e.g. &"scrapfield"). &"" = invalid sentinel.
@export var zone_id: StringName = &""

## Player-visible zone name.
@export var display_name: String = ""

## The zone's encounter terrains (Rule 2). Each patch binds a terrain type to a
## weighted WILD sub-pool. Defaults to [] (empty caught by Story 008).
@export var terrain_patches: Array[TerrainPatch] = []

## The zone's bosses and their gates (Rule 6). Field shapes declared in Story 001;
## gate logic in Stories 005–007. Defaults to [].
@export var boss_encounters: Array[BossEncounter] = []

## Zone-level master spawn switch (Rule 1, mirrors Enemy DB `spawn_enabled`). When
## `false`, the resolver short-circuits before EZ-1 — no roll, no EZ-2 (AC-EZ-57).
@export var spawn_enabled: bool = true

## Lowest enemy level allowed in this zone's spawn pool (ELZS erratum). `>= 1` and
## `<= enemy_level_roof`; validated BLOCKING by Story 008. MVP zone: 1.
@export var enemy_level_floor: int = 1

## Highest enemy level allowed in this zone's spawn pool (ELZS erratum). `>=
## enemy_level_floor` and `<= MAX_ENEMY_LEVEL (10)`; validated BLOCKING by Story 008.
## MVP zone: 6. Default 1 (minimal valid floor==roof).
@export var enemy_level_roof: int = 1
