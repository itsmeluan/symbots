## TBC Story 004 — initiative order (TBC-F1, recomputed each ROUND_START).
##
## Covers AC-TBC-03 (descending effective_mobility), AC-TBC-04 (ties resolve player-first,
## NO RNG — deterministic), AC-TBC-05 (Shock consumed from the stored status lowers
## effective_mobility and can reorder). Exercises the pure static sort so no battle
## context is needed. Framework: GUT · Godot 4.7.
extends GutTest

var _cfg: BalanceConfig


func before_each() -> void:
	_cfg = BalanceConfig.new()


func _player(slot: int, mobility: int, synergy_mob: int = 0) -> Combatant:
	return Combatant.make_player(slot, slot, {&"mobility": mobility, &"structure": 100},
		{&"mobility": synergy_mob}, {}, PartDef.Element.KINETIC)


func _enemy(mobility: int) -> Combatant:
	return Combatant.make_enemy(&"foe", {&"mobility": mobility, &"structure": 100}, PartDef.Element.KINETIC)


# ---------------------------------------------------------------------------
# AC-TBC-03 — descending effective_mobility
# ---------------------------------------------------------------------------

func test_orders_by_descending_effective_mobility() -> void:
	var slow := _player(0, 20)
	var fast := _player(1, 60)
	var mid := _enemy(40)

	var order := BattleController.initiative_order([slow, mid, fast])

	assert_eq(order[0], fast, "highest mobility (60) acts first")
	assert_eq(order[1], mid, "next (40) acts second")
	assert_eq(order[2], slow, "lowest (20) acts last")


# ---------------------------------------------------------------------------
# AC-TBC-04 — ties resolve player-first, deterministically (no RNG)
# ---------------------------------------------------------------------------

func test_tie_resolves_player_before_enemy() -> void:
	var enemy := _enemy(50)
	var player := _player(0, 50)

	# Enemy passed first, but the player must still win the 50-vs-50 tie.
	var order := BattleController.initiative_order([enemy, player])

	assert_eq(order[0], player, "player wins the mobility tie (player-first rule)")
	assert_eq(order[1], enemy, "enemy follows")
	# Determinism: a re-sort of the same input yields the identical order.
	var again := BattleController.initiative_order([enemy, player])
	assert_eq(again[0], player, "stable across runs — no RNG")


# ---------------------------------------------------------------------------
# AC-TBC-05 — Shock lowers effective_mobility and can reorder
# ---------------------------------------------------------------------------

func test_shock_penalty_reorders_initiative() -> void:
	var shocked := _player(0, 60)
	var other := _player(1, 50)
	# processing 53 → shock_magnitude = 15 → effective 60 − 15 = 45 < 50.
	shocked.statuses.apply(StatusInstance.Type.SHOCK, 53, 2, _cfg)

	var order := BattleController.initiative_order([shocked, other])

	assert_eq(order[0], other, "the un-shocked 50 now outpaces the shocked 45")
	assert_eq(order[1], shocked, "Shock (−15) dropped the base-60 combatant below base-50")
	assert_eq(BattleController._mobility_of(shocked), 45, "effective_mobility consumes the stored Shock")
