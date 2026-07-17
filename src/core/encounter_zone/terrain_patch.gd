## TerrainPatch — the encounter unit: binds a terrain TYPE to a weighted enemy
## sub-pool (Rule 2). Terrain type is the player's coarse targeting lever —
## different terrain, different enemies.
##
## A typed, `.tres`-backed value object read read-only through the content catalog
## (ADR-0003). Enum members are APPEND-ONLY — `.tres` stores raw ints, so reordering
## or renumbering silently re-labels authored content. Enum default 0 = INVALID
## sentinel so an unset `.tres` slot is caught by the Story 008 content validator.
class_name TerrainPatch
extends Resource

## Coarse terrain identity (Rule 2). The concrete member set is content-authored per
## zone and pending the finalized Art Bible terrain enum (OQ-EZ-1) — declared here so
## the schema never changes when that lands. APPEND-ONLY; INVALID (0) = unset sentinel.
enum TerrainType {
	INVALID          = 0,  ## Reserved/unset sentinel — no authored patch should carry this.
	MECHANICAL_GRASS = 1,
	JUNKYARD         = 2,
	PYLON_FIELD      = 3,
	MACHINE_CAVERN   = 4,
}

## Density band label for `encounter_rate` (Rule 5). The band → rate mapping is a
## Tuning Knob validated by Story 008; density is a LABEL, the rate is the mechanism.
## APPEND-ONLY; INVALID (0) = unset sentinel.
enum DensityClass {
	INVALID  = 0,  ## Reserved/unset sentinel.
	SPARSE   = 1,  ## Low rate; open/transitional terrain.
	STANDARD = 2,  ## Default farming terrain.
	DENSE    = 3,  ## High rate; the cave/swarm-nest fast-farm biome.
}

## Terrain identity of this patch. Defaults to INVALID (0), caught by Story 008.
@export var terrain_type: TerrainType = TerrainType.INVALID

## Weighted WILD enemy candidates for this patch (Rule 4 selection input).
## Defaults to [] (empty pool caught by Story 003 / Story 008).
@export var enemy_subpool: Array[SpawnEntry] = []

## Per-step probability of triggering an encounter (EZ-1). Legal authored range
## [0.0, 1.0]; an out-of-range authored value is a content error logged + clamped
## by EncounterResolver (AC-EZ-02). Default 0.0 (no encounters).
@export var encounter_rate: float = 0.0

## Density band this patch belongs to (Rule 5). Defaults to INVALID (0).
@export var density_class: DensityClass = DensityClass.INVALID
