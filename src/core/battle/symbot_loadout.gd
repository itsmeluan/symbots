## SymbotLoadout — the immutable per-Symbot input the orchestrator receives at
## `start_battle` (ADR-0005 / ADR-0007; Story 002). A plain `RefCounted` value object
## carrying everything BATTLE_INIT needs to freeze a [Combatant], computed by the
## Overworld / party layer BEFORE combat so the controller never reaches into a live
## [SymbotBuild] mid-battle (`mid_battle_stat_recompute` forbidden).
##
## Validity (`is_build_valid`) is decided by Assembly / Core-Progression at equip time,
## not re-derived here: the controller's Rule 2 gate only READS the flag and refuses the
## whole battle if any fielded loadout is invalid (AC-TBC-42), surfacing
## [member offending_parts] in `battle_start_refused`.
class_name SymbotLoadout
extends RefCounted

## Team id of this Symbot (for `deployed_symbot_ids` and the DOWNED/switch bookkeeping).
var symbot_id: int = -1

## Assembly/Core-Progression validity verdict. False → the battle is refused before any
## snapshot is taken (Rule 2 step 0).
var is_build_valid: bool = true

## Part ids that make the build invalid (empty when valid). Echoed in the refusal signal.
var offending_parts: Array = []

## Frozen SA-F1 + CP-F3 `final_stat` (all 11 canonical keys). Seeds [Combatant.final_stat].
var final_stat: Dictionary = {}

## The equipped parts, in synergy-evaluation order — handed verbatim to
## `SynergySystem.evaluate_silent` (Rule 2 step 2). Opaque to the controller.
var parts: Array = []

## Ordered move pool `[basic_attack, WEAPON, HEAD, ARMS]` (length 4; null = empty slot).
var move_pool: Array = []

## PERSISTENT + event passive effect ids (Story 013), fed to [PassiveEffectRegistry].
var passive_pool: Array = []

## The Core part's [enum PartDef.Element] (null → neutral) for DF-1 type effectiveness.
var core_element = null


## Convenience constructor for a valid loadout (tests / the party layer).
static func make(symbot_id: int, final_stat: Dictionary, move_pool: Array,
		passive_pool: Array, core_element, parts: Array = []) -> SymbotLoadout:
	var l := SymbotLoadout.new()
	l.symbot_id = symbot_id
	l.is_build_valid = true
	l.final_stat = final_stat
	l.move_pool = move_pool
	l.passive_pool = passive_pool
	l.core_element = core_element
	l.parts = parts
	return l
