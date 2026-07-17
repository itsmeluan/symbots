## TBC Story 011 / 012 — switch, flee, and consumable use.
##
## Covers AC-TBC-12 (voluntary switch consumes the turn; the incoming Symbot keeps its
## FROZEN runtime — not reset to full), AC-TBC-17 (a switch to a downed bench slot is
## rejected + logged and does NOT consume the turn), AC-TBC-10 (flee succeeds in a WILD
## encounter and is rejected in a BOSS encounter), AC-TBC-41 (an item restores a LIVING
## team member — active or benched, no switch-in — consuming the turn only on a
## net-positive apply; a full-pool use and a DOWNED target are rejected). Framework: GUT.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")
const FakeSynergy := preload("res://tests/unit/tbc/fake_synergy_system.gd")

var _cfg: BalanceConfig
var _log
var _bc: BattleController


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_bc = BattleController.new(_cfg, _log)


func _loadout(id: int) -> SymbotLoadout:
	var m := MoveDef.new()
	m.id = &"basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.energy_cost = 0
	return SymbotLoadout.make(id, {&"structure": 120, &"energy_capacity": 80, &"mobility": 50},
		[m, null, null, null], [], PartDef.Element.KINETIC, [&"p%d" % id])


func _enemy_spec() -> Dictionary:
	return {"id": &"husk", "stats": {&"structure": 400, &"armor": 40, &"mobility": 5},
		"core_element": PartDef.Element.KINETIC, "level": 3, "xp_value": 40}


func _start(encounter: int) -> void:
	_bc.start_battle([_loadout(0), _loadout(1), _loadout(2)], _enemy_spec(), encounter, FakeSynergy.new())


# ---------------------------------------------------------------------------
# AC-TBC-12 — voluntary switch consumes the turn, incoming keeps frozen runtime
# ---------------------------------------------------------------------------

func test_voluntary_switch_changes_active_and_preserves_frozen_runtime() -> void:
	_start(BattleController.EncounterType.WILD)
	var ctx := _bc.context()
	# Bench Symbot 1 arrived pre-damaged (benched runtime is frozen, not full).
	ctx.team[1].current_structure = 44

	var consumed := _bc.switch_active(1)

	assert_true(consumed, "a voluntary switch consumes the turn")
	assert_eq(ctx.active_index, 1, "the fielded Symbot changed")
	assert_eq(ctx.team[1].current_structure, 44, "incoming keeps its FROZEN structure (not reset to full)")


# ---------------------------------------------------------------------------
# AC-TBC-17 — switch to a downed bench slot is rejected + logged, no turn spent
# ---------------------------------------------------------------------------

func test_switch_to_downed_bench_is_rejected() -> void:
	_start(BattleController.EncounterType.WILD)
	var ctx := _bc.context()
	ctx.team[1].is_downed = true

	var consumed := _bc.switch_active(1)

	assert_false(consumed, "cannot switch to a downed Symbot — turn not consumed")
	assert_eq(ctx.active_index, 0, "active is unchanged")
	assert_false(_bc.can_switch_to(1), "can_switch_to reports the downed slot illegal")
	assert_gt(_log.warns.size(), 0, "the rejected switch is logged")


# ---------------------------------------------------------------------------
# AC-TBC-10 — flee: WILD succeeds and ends the battle; BOSS is rejected
# ---------------------------------------------------------------------------

func test_flee_succeeds_in_wild() -> void:
	watch_signals(_bc)
	_start(BattleController.EncounterType.WILD)

	var consumed := _bc.attempt_flee()

	assert_true(consumed, "flee succeeds in a WILD encounter")
	assert_signal_emitted(_bc, "battle_ended", "flee ends the battle")
	var params: Array = get_signal_parameters(_bc, "battle_ended")
	assert_eq(params[0], BattleController.Outcome.FLED, "outcome is FLED")
	assert_eq(params[2], {}, "FLED carries an empty break-event set")
	assert_false(_bc.is_battle_active(), "battle is over")


func test_flee_rejected_in_boss() -> void:
	_start(BattleController.EncounterType.BOSS)

	var consumed := _bc.attempt_flee()

	assert_false(consumed, "flee is rejected in a BOSS encounter")
	assert_true(_bc.is_battle_active(), "the battle continues")
	assert_gt(_log.warns.size(), 0, "the rejected flee is logged")


# ---------------------------------------------------------------------------
# AC-TBC-41 — use item: restore a living team member, consume turn only on net gain
# ---------------------------------------------------------------------------

func test_item_restores_benched_member_and_consumes_turn() -> void:
	_start(BattleController.EncounterType.WILD)
	var ctx := _bc.context()
	ctx.team[1].current_structure = 50  # bench Symbot is damaged

	var item := {"effect": BattleController.ItemEffect.RESTORE_STRUCTURE, "amount": 40, "id": &"repair_kit"}
	var consumed := _bc.use_item(item, 1)

	assert_true(consumed, "a net-positive restore consumes the turn")
	assert_eq(ctx.team[1].current_structure, 90, "structure 50 + 40 = 90 (no switch-in)")
	assert_eq(ctx.active_index, 0, "the target was NOT switched in")


func test_item_on_full_pool_is_rejected_without_consuming_turn() -> void:
	_start(BattleController.EncounterType.WILD)
	var ctx := _bc.context()
	# team[0] is at full structure (120) from the snapshot.
	var before: int = ctx.team[0].current_structure

	var item := {"effect": BattleController.ItemEffect.RESTORE_STRUCTURE, "amount": 40}
	var consumed := _bc.use_item(item, 0)

	assert_false(consumed, "a zero-net restore (already full) does NOT consume the turn")
	assert_eq(ctx.team[0].current_structure, before, "structure unchanged")


func test_item_on_downed_target_is_rejected() -> void:
	_start(BattleController.EncounterType.WILD)
	var ctx := _bc.context()
	ctx.team[1].is_downed = true
	ctx.team[1].current_structure = 0

	var item := {"effect": BattleController.ItemEffect.RESTORE_STRUCTURE, "amount": 40}
	var consumed := _bc.use_item(item, 1)

	assert_false(consumed, "a DOWNED Symbot is not a valid item target")
	assert_gt(_log.warns.size(), 0, "the rejected use is logged")
