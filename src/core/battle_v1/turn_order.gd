## TurnOrder — who acts, in what order (Core Design §3.2).
##
## Recomputed at the start of each round and stable within it. Recomputing per round
## rather than per action is what lets a Slow debuff matter next round without
## reshuffling the queue under a player who has already read it.
##
## Pure static — the engine calls it, the UI calls it to preview the round, and neither
## can get a different answer.
class_name TurnOrder
extends RefCounted


## Build the acting order for one round: every living unit, fastest first.
##
## Ties break toward the PLAYER, then by slot. Two reasons, and the second is the one
## that matters: a player who loses a coin-flip they cannot see reads it as the game
## cheating, and a deterministic tie-break is what lets the same seed replay identically.
##
## Example:
##     for unit in TurnOrder.for_round(player_units, enemy_units):
##         if unit.is_stunned(): continue
##         resolve_turn(unit)
static func for_round(player_units: Array, enemy_units: Array) -> Array:
	var all: Array = []
	for u in player_units:
		if u.is_alive():
			all.append(u)
	for u in enemy_units:
		if u.is_alive():
			all.append(u)
	all.sort_custom(_compare)
	return all


## Faster first; on equal speed the player unit acts first; on both equal, lower slot.
static func _compare(a: BattleUnit, b: BattleUnit) -> bool:
	var sa := a.speed()
	var sb := b.speed()
	if sa != sb:
		return sa > sb
	if a.side != b.side:
		return a.side == BattleUnit.Side.PLAYER
	return a.slot < b.slot


## Preview the next round's order without mutating anything — the UI shows this as the
## initiative ribbon so a player can plan around a Slow before spending it.
static func preview(player_units: Array, enemy_units: Array) -> Array:
	return for_round(player_units, enemy_units)
