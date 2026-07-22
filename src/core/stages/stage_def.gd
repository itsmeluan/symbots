## StageDef — one node on the stage map (Core Design §6).
##
## A stage is a sequence of battles plus a chest. One battle is the common case; a dungeon
## is the same resource with more entries in [member battles], which is why there is no
## separate DungeonDef — the modes differ by length and by what carries between fights, not
## by structure.
@tool
class_name StageDef
extends Resource

## Values are APPEND-ONLY — progress persists the int.
enum Mode {
	INVALID = 0,
	STAGE   = 1,  ## a single battle
	DUNGEON = 2,  ## a sequence; structure and ult charge carry, everything else resets
	RAID    = 3,  ## reserved — a longer dungeon behind a boss gate
	ENDLESS = 4,  ## past the authored stages, difficulty scales without end
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var mode: Mode = Mode.STAGE

## Ordering and reward scale. Drives [method UpgradeEconomy.battle_reward], so it is a
## difficulty dial and an economy dial at once — deliberately, because a stage that pays
## more than it costs to beat would be the only stage anyone played.
@export var stage_level: int = 1

## Stages that must be CLEARED before this one opens. Empty means it is available from the
## start. A list rather than a single id so the map can converge as well as branch.
@export var requires: Array[StringName] = []

## Each entry is one battle: an array of enemy species ids, 1-4 of them (§3.1), with an
## optional parallel `marks` array giving each enemy's evolution (1-3).
## Shape: [ { "enemies": [StringName, ...], "marks": [int, ...] } ]
##
## `marks` is optional and may be shorter than `enemies`: any missing entry defaults to
## Mk I. This keeps early stages Mk I by simply omitting marks, and lets a later fight
## field a Mk II captain among Mk I grunts by listing only the marks that differ.
@export var battles: Array[Dictionary] = []

## Enemy level for this stage's units. Kept separate from `stage_level` so a bonus stage
## can pay well without being hard, or be brutal without paying more.
@export var enemy_level: int = 1

## Item ids the completion chest can award (§6). The chest is the ONLY source of
## blueprints and top-tier hardware — otherwise finishing has no purpose and the optimal
## play is to farm the first battle and quit.
@export var chest_item_ids: Array[StringName] = []

## Blueprint this stage's chest can drop, or empty. Blueprints are what make a boss worth
## repeating.
@export var chest_blueprint_id: StringName = &""

## This stage's battlefield art, or empty to use the shared default.
##
## A PATH rather than an exported [Texture2D]: a Texture2D reference would be resolved when
## the stage catalog loads, pulling all fifteen 1080x1920 backdrops into memory at boot
## (~8 MB each decompressed) against a 512 MB ceiling. As a path the art is loaded when the
## fight starts and released with the screen.
##
## The floor geometry a usable backdrop must satisfy is specified in
## `design/v1/battle-background-prompts.md` — art with a low horizon leaves the rear rank
## standing in open sky.
@export_file("*.png") var background_path: String = ""


func battle_count() -> int:
	return battles.size()


## Enemy species ids for battle [param index], or an empty array when out of range.
func enemies_at(index: int) -> Array:
	if index < 0 or index >= battles.size():
		return []
	return battles[index].get("enemies", [])


## Evolution mark (1-3) for each enemy in battle [param index], padded to match the enemy
## count. An enemy with no authored mark is Mk I — so an early stage that lists no marks
## fields base forms, exactly as §6.2 requires.
func marks_at(index: int) -> Array:
	var enemies := enemies_at(index)
	var authored: Array = battles[index].get("marks", []) if index >= 0 \
		and index < battles.size() else []
	var out: Array = []
	for i in enemies.size():
		out.append(clampi(int(authored[i]), 1, 3) if i < authored.size() else 1)
	return out


## The highest evolution mark any enemy in this whole stage reaches. The stage validator
## reads this to keep final forms out of the early campaign (§6.2).
func peak_mark() -> int:
	var peak := 1
	for i in battles.size():
		for m in marks_at(i):
			peak = maxi(peak, int(m))
	return peak


## True when structure carries between this stage's battles (§3.6). Dungeons and raids run
## as one continuous attrition arc; a plain stage is a single fight, so there is nothing to
## carry.
func carries_structure() -> bool:
	return mode == Mode.DUNGEON or mode == Mode.RAID
