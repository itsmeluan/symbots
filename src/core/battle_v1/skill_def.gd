## SkillDef — one active skill (Core Design §3.4).
##
## Cooldown-based, no energy pool: a skill is available when its cooldown is 0 and
## unavailable otherwise. One resource is one thing for the player to learn, and
## cooldowns alone already produce rotation decisions.
@tool
class_name SkillDef
extends Resource

## Who a skill can be aimed at. This is the single most load-bearing field: it decides
## whether the taunt rule applies at all (§3.3 — multi-target effects are not *choosing*
## a target, so there is nothing for taunt to redirect).
## Values are APPEND-ONLY.
enum TargetMode {
	INVALID          = 0,
	SELF             = 1,
	SINGLE_ALLY      = 2,
	ALL_ALLIES       = 3,
	LOWEST_HP_ALLY   = 4,  ## healer convenience — resolves without a manual pick
	SINGLE_ENEMY     = 5,
	ALL_ENEMIES      = 6,
	RANDOM_ENEMY     = 7,
}

## What the skill does when it lands. A skill may carry several.
enum EffectKind {
	INVALID     = 0,
	DAMAGE      = 1,
	HEAL        = 2,
	SHIELD      = 3,
	APPLY_STATUS = 4,
	CLEANSE     = 5,
	REVIVE      = 6,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var target_mode: TargetMode = TargetMode.SINGLE_ENEMY

## Turns before the skill can be used again. 0 = usable every turn (the basic attack).
@export var cooldown: int = 0

## Turns before it can be used for the FIRST time. Lets a heavy skill be a mid-fight
## payoff rather than an opening move.
@export var initial_cooldown: int = 0

## Damage/heal scale against the caster's power stat, in whole percent. 100 = one times
## the stat. Whole percent rather than float so authored content has no rounding drift.
@export var power_percent: int = 100

## Which caster stat drives the magnitude — `physical_power`, `energy_power` for damage,
## `processing` for healing and support (see 02-stats-and-formulas.md).
@export var scaling_stat: StringName = &"physical_power"

## Effects applied in order, each `{kind: EffectKind, ...params}`.
@export var effects: Array[Dictionary] = []

## Bypasses the taunt rule, letting this skill reach past a living tank (§3.3 Pierce).
## The exception that makes tanks a puzzle rather than a wall.
@export var ignores_taunt: bool = false

## Skills a TANK uses to hold aggro read better if flagged, so UI can mark them.
@export var is_taunt_skill: bool = false


## True when this skill picks exactly one unit and therefore participates in the taunt
## rule. Multi-target and self-target skills do not.
func is_single_target() -> bool:
	return target_mode in [
		TargetMode.SINGLE_ENEMY, TargetMode.SINGLE_ALLY, TargetMode.LOWEST_HP_ALLY]


## True when the skill is aimed at the opposing side.
func targets_enemies() -> bool:
	return target_mode in [
		TargetMode.SINGLE_ENEMY, TargetMode.ALL_ENEMIES, TargetMode.RANDOM_ENEMY]
