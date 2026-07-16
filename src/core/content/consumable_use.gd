## ConsumableUse — the pure use-transaction contract for consumables (TR-cdb-002/003/007).
##
## Models the atomic use of one consumable: **validate → apply → decrement by 1**. A
## rejected use decrements NOTHING and (in battle) consumes NO turn — rejection is a
## PRE-ACTION gate (GDD Rule 3). Everything here is pure and dependency-injected: the
## target's resource state and the current context are passed in, so GUT exercises the
## exact production contract with no live TBC scene and no global RNG.
##
## Actually assigning the applied value to a live Symbot and consuming the turn is the
## TBC erratum (AC-CD-20, DEFERRED); this class delivers the validated decision + the
## computed delta the erratum will apply.
##
## Gate order (all must pass, in order):
##   (1) quantity > 0
##   (2) context matches `use_context` (BOTH is valid in either)
##   (3) valid target — a RESTORE_* item needs `structure > 0` (no reviving the downed)
##   (4) net effect > 0 — a use that would clamp to exactly the current value is
##       rejected; a PARTIAL effect (any change) is allowed and consumed
##
## **Resource neutrality (Rule 3 / AC-CD-25):** item-use never routes through the move
## damage/Heat/Energy pipeline. This class has no code path that generates Heat or
## consumes Energy, so a successful use reports `heat_generated == 0` and
## `energy_consumed == 0` by construction.
class_name ConsumableUse
extends RefCounted

## The outcome of a use attempt. Values are result-contract only (not authored .tres).
enum Outcome {
	USE_OK       = 1,
	USE_REJECTED = 2,
}

## Why a use was rejected (`NONE` on success). Result-contract only; append-only so
## Story 005 (SECOND_BEACON) and future gates extend it without renumbering.
enum Reason {
	NONE           = 0,
	QUANTITY_ZERO  = 1,
	WRONG_CONTEXT  = 2,
	INVALID_TARGET = 3,
	NO_NET_EFFECT  = 4,
	SECOND_BEACON  = 5,  # Story 005 — one Beacon per battle (EC-CD-05)
}

## The RESTORE_* effect types that act on a living team Symbot (TR-cdb-003). BOOST_DROP
## and MODIFY_ENCOUNTER_RATE target the battle / overworld and have their own paths
## (Stories 005/006), so they skip the living-target and net-effect resource gates.
const RESTORATIVE_TYPES: Array = [
	ConsumableDef.EffectType.RESTORE_STRUCTURE,
	ConsumableDef.EffectType.REDUCE_HEAT,
	ConsumableDef.EffectType.RESTORE_ENERGY,
]

## The living-target predicate (AC-CD-24), reused by the UI grey-out. A Symbot is a
## valid RESTORE_* target iff its Structure is above 0 — the boundary `structure == 1`
## is valid (a `structure >= threshold` impl wrongly fails it).
static func is_valid_target(structure: int) -> bool:
	return structure > 0


## Resolve a use attempt purely. [param target_state] carries the runtime resource
## values (`structure`, `max_structure`, `heat`, `energy`, `max_energy`) — read from
## the live target, never hardcoded. [param current_context] is the ACTUAL situation
## (BATTLE or WORLD — never BOTH, which is a def property). Returns a result Dictionary:
## `{outcome, reason, new_qty, applied_delta, heat_generated, energy_consumed}`.
static func resolve(def: ConsumableDef, target_state: Dictionary,
		current_context: ConsumableDef.UseContext, quantity: int) -> Dictionary:
	# (1) quantity gate — no underflow to −1 on qty 0.
	if quantity <= 0:
		return _reject(Reason.QUANTITY_ZERO, quantity)
	# (2) context gate.
	if not _context_allows(def.use_context, current_context):
		return _reject(Reason.WRONG_CONTEXT, quantity)
	# Gates (3)+(4) apply only to the RESTORE_* family; other effect types resolve
	# their own conditions in Stories 005/006 and pass the generic gates here.
	if RESTORATIVE_TYPES.has(def.effect_type):
		var structure := int(target_state.get("structure", 0))
		if not is_valid_target(structure):
			return _reject(Reason.INVALID_TARGET, quantity)
		var delta := _restorative_delta(def, target_state)
		if delta <= 0:  # would clamp to exactly current → no net effect
			return _reject(Reason.NO_NET_EFFECT, quantity)
		return _ok(quantity, delta)
	# Non-restorative use: generic gates passed; effect application is the caller's.
	return _ok(quantity, 0)


## True iff an item authored for [param item_ctx] may be used in [param current_ctx].
## `BOTH` is valid in either; otherwise the contexts must match exactly.
static func _context_allows(item_ctx: ConsumableDef.UseContext,
		current_ctx: ConsumableDef.UseContext) -> bool:
	if item_ctx == ConsumableDef.UseContext.BOTH:
		return true
	return item_ctx == current_ctx


## The magnitude of change a RESTORE_* use would produce against [param target_state]
## (always ≥ 0). 0 means the use is inert (already at cap / Heat already 0) and is
## rejected by the net-effect gate. Delegates to the Story-003 pure formulas so there
## is a single source of truth for the clamp math.
static func _restorative_delta(def: ConsumableDef, target_state: Dictionary) -> int:
	var amount := int(def.effect_params.get("amount", 0))
	match def.effect_type:
		ConsumableDef.EffectType.RESTORE_STRUCTURE:
			var cur := int(target_state.get("structure", 0))
			var new_val := ConsumableEffects.restore_structure(cur, int(target_state.get("max_structure", 0)), amount)
			return new_val - cur
		ConsumableDef.EffectType.REDUCE_HEAT:
			var cur := int(target_state.get("heat", 0))
			var new_val := ConsumableEffects.reduce_heat(cur, amount)
			return cur - new_val  # Heat removed is the positive delta
		ConsumableDef.EffectType.RESTORE_ENERGY:
			var cur := int(target_state.get("energy", 0))
			var new_val := ConsumableEffects.restore_energy(cur, int(target_state.get("max_energy", 0)), amount)
			return new_val - cur
	return 0


## A successful use: decrement by 1, carry the applied delta, resource-neutral.
static func _ok(quantity: int, applied_delta: int) -> Dictionary:
	return {
		"outcome": Outcome.USE_OK,
		"reason": Reason.NONE,
		"new_qty": quantity - 1,
		"applied_delta": applied_delta,
		"heat_generated": 0,
		"energy_consumed": 0,
	}


## A rejected use: nothing consumed, quantity unchanged, no resource touch.
static func _reject(reason: Reason, quantity: int) -> Dictionary:
	return {
		"outcome": Outcome.USE_REJECTED,
		"reason": reason,
		"new_qty": quantity,
		"applied_delta": 0,
		"heat_generated": 0,
		"energy_consumed": 0,
	}
