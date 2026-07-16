## EncounterModifierState — the Signal Jammer / Scrap Lure overworld counter (TR-cdb-005).
##
## Holds the `(rate_multiplier, steps_remaining)` pair active during overworld
## movement (GDD Rule 6 / States and Transitions). In production it is OWNED by the
## overworld/traversal context (Overworld Navigation drives the countdown); it is
## modeled here as a DI-testable RefCounted so the Story-006 ACs are exercisable before
## the Encounter Zone erratum (AC-CD-22) wires the live per-step roll.
##
## **Sole mutator is [method on_overworld_step]** (decrement, expire at 0). The class
## exposes NO battle-turn handler — so the "frozen during battle" property is
## STRUCTURAL (battle turns simply never call it), not an in-battle guard (AC-CD-14).
## Do not add a battle-turn method: that would break the structural freeze.
##
## Only ONE modifier is active at a time — [method apply] REPLACES any active one
## (latest wins, EC-CD-06); there is no stacking. Querying with no active modifier
## returns the inert default (base rate, no decrement) and never crashes.
##
## The CD-5 clamp math lives in [ConsumableEffects.modify_encounter_rate]; this class
## owns only the counter lifecycle.
class_name EncounterModifierState
extends RefCounted

## Which modifier (if any) is active. Derived from `rate_multiplier` on [method apply]:
## `> 1` is a Lure (attract), `< 1` a Jammer (repel). NONE (0) = inert default.
enum ModifierType {
	NONE   = 0,
	JAMMER = 1,
	LURE   = 2,
}

## The active modifier kind, or NONE when inert.
var modifier_type: ModifierType = ModifierType.NONE

## The active rate multiplier (1.0 when inert — a no-op factor).
var rate_multiplier: float = 1.0

## Overworld steps the modifier stays active; decremented by [method on_overworld_step],
## expires at 0.
var steps_remaining: int = 0

## True while a modifier is active (a real kind AND steps left).
func has_active() -> bool:
	return modifier_type != ModifierType.NONE and steps_remaining > 0

## Apply [param def]'s MODIFY_ENCOUNTER_RATE effect, REPLACING any active modifier
## (latest wins — no stacking). Reads `rate_multiplier` / `duration_steps` from
## `effect_params`; the kind is derived from the multiplier (`> 1` Lure, else Jammer).
func apply(def: ConsumableDef) -> void:
	var rm := float(def.effect_params.get("rate_multiplier", 1.0))
	var steps := int(def.effect_params.get("duration_steps", 0))
	rate_multiplier = rm
	steps_remaining = steps
	modifier_type = ModifierType.LURE if rm > 1.0 else ModifierType.JAMMER

## Advance the countdown by one overworld step (the SOLE mutator). Decrements
## `steps_remaining` and expires the modifier when it hits 0. A no-op when already
## inert (never underflows below 0).
func on_overworld_step() -> void:
	if steps_remaining <= 0:
		return
	steps_remaining -= 1
	if steps_remaining <= 0:
		_expire()

## The effective encounter rate against [param base_rate] under the active modifier
## (CD-5). Returns [param base_rate] unchanged when inert — querying with no active
## modifier is safe and raises nothing (AC-CD-14 no-crash).
func effective_rate(base_rate: float) -> float:
	if not has_active():
		return base_rate
	return ConsumableEffects.modify_encounter_rate(base_rate, rate_multiplier)

## Reset to the inert default.
func _expire() -> void:
	modifier_type = ModifierType.NONE
	rate_multiplier = 1.0
	steps_remaining = 0
