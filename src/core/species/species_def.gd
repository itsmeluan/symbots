## SpeciesDef — one Symbot species: its identity, role, rarity and marks (Core Design §2).
##
## A species is authored content and never mutates at runtime. What the player owns is a
## [SymbotInstance], which points at a species and carries the mutable state (level, XP,
## part levels, allocated tree nodes). Keeping the two apart is what lets a balance patch
## reach every save: instances store a species id, not a copy of the species.
##
## `@tool` so the editor validates exported types while authoring .tres content.
@tool
class_name SpeciesDef
extends Resource

## Battlefield job. Drives the taunt rule (TANK), the AI's target preference, and which
## of the tree's 16 entry points this species may use.
## Values are APPEND-ONLY — never reorder or renumber; saves store the int.
enum Role {
	INVALID = 0,
	DPS     = 1,
	TANK    = 2,
	HEALER  = 3,
	SUPPORT = 4,
}

## Rarity does NOT cap level (Core Design §2.2) — every species reaches the same maximum.
## It sets base-stat scale, how many unique passives the species has, how strong they are,
## and how many OVERCLOCK levels the species can push past the shared cap.
enum Rarity {
	INVALID   = 0,
	COMMON    = 1,
	RARE      = 2,
	EPIC      = 3,
	PROTOTYPE = 4,
}

## Overclock levels available per rarity. A common Symbot is never obsolete — it reaches
## full standard power — but rarer ones have a ceiling above it that only long investment
## reaches.
const OVERCLOCK_BY_RARITY := {
	Rarity.COMMON: 0,
	Rarity.RARE: 5,
	Rarity.EPIC: 10,
	Rarity.PROTOTYPE: 15,
}

## Unique-passive count per rarity (Core Design §2.2).
const UNIQUE_PASSIVES_BY_RARITY := {
	Rarity.COMMON: 1,
	Rarity.RARE: 2,
	Rarity.EPIC: 3,
	Rarity.PROTOTYPE: 4,
}

## Stable id. Also the art lookup key: assets/art/symbots/<id>_mk1.png etc., following
## the project rule that the filename IS the content id.
@export var id: StringName = &""

@export var display_name: String = ""

## One-line flavour shown on the collection screen.
@export_multiline var description: String = ""

@export var role: Role = Role.INVALID
@export var rarity: Rarity = Rarity.INVALID

## Which of the tree's 16 entry-point nodes this species starts from (Core Design §4.1).
## Two species may share an entry; their paths diverge by what they can afford to reach.
@export var tree_entry_node: StringName = &""

## Base stats at level 1, Mk I, before part levels and tree nodes. Keys are the canonical
## stat names; see 02-stats-and-formulas.md.
@export var base_stats: Dictionary[StringName, int] = {}

## Per-part stat identity: which stats each of the six parts feeds, and how much per level.
## Shape: { part_slot (int) : { stat_key : per_level_gain } }. Authoring this per species
## is what makes the same slot mean different things on a tank and a healer.
@export var part_growth: Dictionary = {}

## Unique passives, unlocked at species-specific levels. Length should match
## UNIQUE_PASSIVES_BY_RARITY[rarity] — the content validator enforces it rather than
## trusting the author, because a missing passive is invisible until someone levels that
## far and wonders why nothing happened.
## Shape: [{ passive_id: StringName, unlock_level: int }]
@export var unique_passives: Array[Dictionary] = []

## Basic attack skill id — every Symbot has one, with no cooldown, so a turn is never
## wasted (Core Design §3.4).
@export var basic_attack_id: StringName = &"basic_attack"

## Skills granted by this species' ENTRY-POINT cluster — what it fields at level 1 before
## a single point is spent. This does not contradict "actives come from the tree" (§3.4):
## the entry node costs 0 points ([method SkillNodeDef.point_cost]), so what it grants is
## exactly the species' starting kit. Everything past it still has to be walked to.
@export var starting_skills: Array[StringName] = []

## The ult the entry cluster grants (§3.4b). One at a time; the tree offers more further
## out, and swapping is a build decision.
@export var starting_ultimate: StringName = &""

## Alloy cost to craft this species from its blueprint.
@export var craft_alloy_cost: int = 0


## Overclock levels this species can reach past the shared cap.
func max_overclock() -> int:
	return OVERCLOCK_BY_RARITY.get(rarity, 0)


## How many unique passives this species should author, from its rarity.
func expected_unique_passive_count() -> int:
	return UNIQUE_PASSIVES_BY_RARITY.get(rarity, 0)


## Art id for a given mark (1-3). The mark suffix is part of the id convention so a
## Retrofit is a texture swap and nothing more.
func art_id(mark: int) -> StringName:
	return StringName("%s_mk%d" % [String(id), clampi(mark, 1, 3)])
