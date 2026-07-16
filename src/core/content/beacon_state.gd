## BeaconState — the Salvage Beacon per-battle flag contract (TR-cdb-004 / Rule 5).
##
## In production this state is OWNED by the battle context (TBC); it is modeled here as
## a DI-testable RefCounted so the Story-005 ACs are exercisable now, before the TBC
## erratum (AC-CD-21) wires the live drop roll. It exposes exactly the queryable fields
## the erratum promises: `beacon_used_this_battle` and `beacon_drop_multiplier_applied`.
##
## Rules encoded (GDD Rule 5):
##   - One Beacon per battle — a second use while the boost is active is REJECTED (not
##     wasted, not stacked): `beacon_qty` is unchanged and the flag stays true.
##   - Consumed on use (`beacon_qty` decremented once).
##   - Spent on flee/loss with NO effect, NEVER refunded — `on_battle_end(FLEE/LOSS)`
##     leaves `beacon_qty` untouched (the qty assertion is the sole catch for a
##     flee-refund economy bug).
##   - The multiplier applies ONLY on VICTORY (`beacon_drop_multiplier_applied` true
##     only after `on_battle_end(WIN)`).
##
## The CD-4 clamp math itself lives in [ConsumableEffects.boost_drop]; this class owns
## only the flag lifecycle.
class_name BeaconState
extends RefCounted

## How a battle concluded, for [method on_battle_end]. Result-contract enum.
enum BattleOutcome {
	WIN  = 1,
	FLEE = 2,
	LOSS = 3,
}

## True from the moment a Beacon is used until battle end (Rule 5 observable contract).
## Gates the second-Beacon rejection.
var beacon_used_this_battle: bool = false

## True only after `on_battle_end(WIN)` when a Beacon was used this battle — the
## boost applies on victory alone. Read by the Drop System at resolution.
var beacon_drop_multiplier_applied: bool = false

## The player's remaining Beacon quantity in this transaction. Decremented once on a
## successful use; NEVER incremented here (no refund path) — that absence is the
## structural guarantee AC-CD-12 asserts.
var beacon_qty: int = 0

## Attempt to use one Beacon this battle. Returns a use-result Dictionary shaped like
## [ConsumableUse]'s: `{outcome, reason, new_qty}`. Rejects (qty unchanged) when there
## is nothing to use or a Beacon is already active this battle; otherwise consumes one
## and raises the flag.
func use_beacon() -> Dictionary:
	if beacon_qty <= 0:
		return {"outcome": ConsumableUse.Outcome.USE_REJECTED, "reason": ConsumableUse.Reason.QUANTITY_ZERO, "new_qty": beacon_qty}
	if beacon_used_this_battle:
		return {"outcome": ConsumableUse.Outcome.USE_REJECTED, "reason": ConsumableUse.Reason.SECOND_BEACON, "new_qty": beacon_qty}
	beacon_qty -= 1
	beacon_used_this_battle = true
	return {"outcome": ConsumableUse.Outcome.USE_OK, "reason": ConsumableUse.Reason.NONE, "new_qty": beacon_qty}

## Resolve the Beacon flag at battle end. The multiplier is applied only on VICTORY and
## only if a Beacon was used; the per-battle flag is then cleared. `beacon_qty` is
## deliberately NOT touched — a Beacon spent on flee/loss is gone (Rule 5).
func on_battle_end(outcome: BattleOutcome) -> void:
	beacon_drop_multiplier_applied = beacon_used_this_battle and outcome == BattleOutcome.WIN
	beacon_used_this_battle = false
