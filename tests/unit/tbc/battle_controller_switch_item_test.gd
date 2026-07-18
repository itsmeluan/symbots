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


# ---------------------------------------------------------------------------
# AC-TBC-10 (Scenario A) + AC-TBC-18 (Scenario B) — a Burn tick at TURN START
# downs the active before it acts, and DOWNING clears ALL of its statuses.
# ---------------------------------------------------------------------------

func test_burn_kill_at_turn_start_downs_active_and_clears_all_statuses() -> void:
	_start(BattleController.EncounterType.WILD)
	var hero: Combatant = _bc.context().active()
	hero.current_structure = 3  # a tick-5 Burn is lethal at turn start
	hero.statuses.apply(StatusInstance.Type.BURN, 72, 2, _cfg)   # proc 72 → tick 5
	hero.statuses.apply(StatusInstance.Type.SHOCK, 53, 2, _cfg)  # a second status, to prove ALL clear
	assert_eq(hero.statuses.count(), 2, "arrange: two statuses ride the active before its turn")

	var ts: Dictionary = _bc.begin_turn(hero)

	assert_true(ts["downed"], "the turn-start Burn tick downs the active before it can act (AC-TBC-10 A)")
	assert_eq(ts["burn_damage"], 5, "the Burn dealt its tick-5 magnitude")
	assert_false(hero.is_alive(), "structure driven to 0 by the turn-start Burn")
	assert_true(hero.is_downed, "the active is flagged downed")
	assert_eq(hero.statuses.count(), 0, "DOWNING clears EVERY status, not just the lethal Burn (AC-TBC-18 B)")


# ---------------------------------------------------------------------------
# AC-TBC-10 (Scenario A) — a Burn-downed active with a living bench parks a
# FORCED_SWITCH; the free replacement pick is accepted and the battle continues.
# ---------------------------------------------------------------------------

func test_burn_kill_of_active_with_living_bench_parks_forced_switch() -> void:
	_start(BattleController.EncounterType.WILD)
	var ctx := _bc.context()
	var hero: Combatant = ctx.active()
	hero.current_structure = 3
	hero.statuses.apply(StatusInstance.Type.BURN, 72, 2, _cfg)

	var ts: Dictionary = _bc.begin_turn(hero)
	assert_true(ts["downed"], "arrange: the active is Burn-downed at turn start")

	var stopped: bool = _bc._handle_turn_start_death(hero)
	assert_true(stopped, "the turn loop halts on the downed active")
	assert_eq(_bc.state(), BattleController.BattleState.FORCED_SWITCH, "parks a FORCED_SWITCH, not a defeat (living bench)")

	# The free replacement pick is accepted — no turn is charged for it.
	_bc.submit_action({"type": BattleController.ActionType.SWITCH, "target_index": 1})
	assert_eq(ctx.active_index, 1, "the free forced-switch installed the chosen bench Symbot")
	assert_true(_bc.is_battle_active(), "the battle continues after the free switch")


# ---------------------------------------------------------------------------
# AC-TBC-10 (Scenario B) — an ENEMY Burn-downed at turn start ends in VICTORY.
# ---------------------------------------------------------------------------

func test_enemy_burn_death_at_turn_start_ends_in_victory() -> void:
	watch_signals(_bc)
	_start(BattleController.EncounterType.WILD)
	var foe: Combatant = _bc.context().enemy
	foe.current_structure = 3
	foe.statuses.apply(StatusInstance.Type.BURN, 72, 2, _cfg)

	var ts: Dictionary = _bc.begin_turn(foe)
	assert_true(ts["downed"], "arrange: the enemy is Burn-downed at its turn start")

	var stopped: bool = _bc._handle_turn_start_death(foe)
	assert_true(stopped, "the loop halts")
	assert_signal_emitted(_bc, "battle_ended", "a Burn-killed enemy ends the battle")
	assert_eq(get_signal_parameters(_bc, "battle_ended")[0], BattleController.Outcome.VICTORY, "outcome VICTORY (AC-TBC-10 B)")


# ---------------------------------------------------------------------------
# AC-TBC-18 (Scenario A) — benched statuses are FROZEN: while the active takes a
# full turn cycle, a benched Symbot's Burn neither ticks (no damage) nor
# decrements (no expiry).
# ---------------------------------------------------------------------------

func test_benched_statuses_freeze_while_active_takes_its_turn() -> void:
	_start(BattleController.EncounterType.WILD)
	var ctx := _bc.context()
	var bench: Combatant = ctx.team[1]
	var bench_structure_before: int = bench.current_structure
	bench.statuses.apply(StatusInstance.Type.BURN, 72, 1, _cfg)  # duration 1 → a stray decrement would EXPIRE it
	assert_eq(bench.statuses.count(), 1, "arrange: the benched Symbot carries a 1-turn Burn")

	# A full active-turn cycle — the only combatant the loop ticks is the active.
	_bc.begin_turn(ctx.active())
	_bc.end_turn(ctx.active())

	assert_eq(bench.statuses.count(), 1, "the benched Burn did NOT decrement/expire — frozen (AC-TBC-18 A)")
	assert_eq(bench.statuses.burn_tick(), 5, "the benched Burn still reads its snapshot potency")
	assert_eq(bench.current_structure, bench_structure_before, "the benched Symbot took no Burn damage while frozen")


# ---------------------------------------------------------------------------
# REGRESSION (bug found 2026-07-18): compute_initiative rostered the whole
# living_team, so a benched Symbot got a phantom turn — _run_turns parked on it as
# a player action and the ENEMY never acted. Only [active, enemy] may be in turn_order.
# The pre-existing freeze test above drives begin_turn/end_turn directly and so never
# exercised the full turn loop; this one runs _run_turns with a 3-Symbot team.
# ---------------------------------------------------------------------------

func test_bench_symbot_gets_no_turn_and_enemy_acts_in_multi_symbot_battle() -> void:
	_start(BattleController.EncounterType.WILD)
	var ctx := _bc.context()
	assert_eq(ctx.team.size(), 3, "arrange: a full 3-Symbot team is fielded")

	# Composition: turn_order is exactly [active, enemy] — the two benched Symbots are excluded.
	assert_eq(ctx.turn_order.size(), 2, "turn_order excludes the bench — only the active Symbot + the enemy")
	for c in ctx.turn_order:
		if not c.is_enemy:
			assert_eq(c.symbot_id, ctx.active().symbot_id,
				"the only team member in turn_order is the ACTIVE Symbot, never a benched one")

	# Behaviour: after the player's turn, the ENEMY actually acts (it damages the active),
	# proving the loop did not park on a benched Symbot's phantom turn and skip the enemy.
	var active_hp_before: int = ctx.active().current_structure
	var move := MoveDef.new()
	move.behavior = MoveDef.Behavior.DAMAGE
	move.power_tier = MoveDef.PowerTier.STANDARD
	move.damage_type = PartDef.DamageType.PHYSICAL
	move.element = PartDef.Element.KINETIC
	move.energy_cost = 0
	_bc.submit_action({"type": BattleController.ActionType.MOVE, "move": move, "part_heat_generation": 0})

	assert_lt(ctx.active().current_structure, active_hp_before,
		"the enemy took its turn and damaged the active — the bench did not steal the enemy's slot")
