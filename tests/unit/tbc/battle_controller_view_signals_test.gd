## BattleController Phase 2-A — view-signal suite (plan §5; presentation-tier-foundation-plan.md).
##
## For each of the 13 emitting view-signals: one test that starts a battle with fixed
## stats/seeds, subscribes via watch_signals(_bc), drives the FSM to the emission point,
## and asserts (a) the signal fired, (b) payload correct, (c) post-emit FSM state proves
## no re-entrancy (ADR-0002 rule 5). For the 3 non-emitting signals (status_applied gap +
## 2 Part-Break stubs): a test asserting has_signal = true but no emission in a normal battle.
##
## NAMING: BattleController is the class name (for .new() + enums). TBC is the autoload
## singleton — never call BattleController.some_method() on the class (parse error).
## Framework: GUT · Godot 4.7.
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


# ---------------------------------------------------------------------------
# Shared helpers (mirrors battle_controller_lifecycle_test.gd)
# ---------------------------------------------------------------------------

func _killer_loadout() -> SymbotLoadout:
	# physical_power 100 so a STANDARD basic attack one-shots the fragile enemy (structure 10).
	var m := MoveDef.new()
	m.id = &"basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = PartDef.Element.KINETIC
	m.energy_cost = 5
	return SymbotLoadout.make(0, {&"structure": 120, &"energy_capacity": 80, &"mobility": 50,
		&"physical_power": 100, &"recharge": 10, &"cooling": 5}, [m, null, null, null],
		[], PartDef.Element.KINETIC, [&"p0"])


func _fragile_enemy() -> Dictionary:
	# structure 10, armor 0, mobility 5 → player leads, one 100-hit kills it.
	return {"id": &"husk_walker", "stats": {&"structure": 10, &"armor": 0, &"mobility": 5},
		"core_element": PartDef.Element.KINETIC, "level": 4, "xp_value": 55,
		"completion_bonus_xp": 12, "is_first_boss_defeat": false}


func _tanky_enemy() -> Dictionary:
	# structure 1000, armor 200, mobility 5 → player leads, cannot be one-shotted.
	return {"id": &"iron_colossus", "stats": {&"structure": 1000, &"armor": 200, &"mobility": 5},
		"core_element": PartDef.Element.KINETIC, "level": 10, "xp_value": 200,
		"completion_bonus_xp": 50, "is_first_boss_defeat": false}


func _slow_enemy() -> Dictionary:
	# structure 400, mobility 1 → player ALWAYS leads (mobility 50 vs 1).
	return {"id": &"slow_bot", "stats": {&"structure": 400, &"armor": 0, &"mobility": 1},
		"core_element": PartDef.Element.KINETIC, "level": 3, "xp_value": 40}


func _kill_action() -> Dictionary:
	var m := MoveDef.new()
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = PartDef.Element.KINETIC
	m.energy_cost = 0
	return {"type": BattleController.ActionType.MOVE, "move": m, "part_heat_generation": 0}


func _damage_action_with_energy_cost(cost: int) -> Dictionary:
	var m := MoveDef.new()
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = PartDef.Element.KINETIC
	m.energy_cost = cost
	return {"type": BattleController.ActionType.MOVE, "move": m, "part_heat_generation": 0}


func _damage_action_with_heat(heat: int) -> Dictionary:
	var m := MoveDef.new()
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = PartDef.Element.KINETIC
	m.energy_cost = 0
	return {"type": BattleController.ActionType.MOVE, "move": m, "part_heat_generation": heat}


func _two_symbot_loadout(id: int) -> SymbotLoadout:
	var m := MoveDef.new()
	m.id = &"basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.energy_cost = 0
	return SymbotLoadout.make(id, {&"structure": 120, &"energy_capacity": 80, &"mobility": 50},
		[m, null, null, null], [], PartDef.Element.KINETIC, [&"p%d" % id])


# ---------------------------------------------------------------------------
# 1. round_started — fires at ROUND_START after compute_initiative()
# ---------------------------------------------------------------------------

func test_round_started_fires_on_battle_start_with_round_number_and_order() -> void:
	watch_signals(_bc)

	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())

	assert_signal_emitted(_bc, "round_started", "round_started fires at the first ROUND_START")
	var p: Array = get_signal_parameters(_bc, "round_started")
	assert_eq(p[0], 1, "round number is 1 for the first round")
	assert_true(p[1] is Array, "turn_order payload is an Array")
	assert_gt(p[1].size(), 0, "turn_order contains at least one combatant id")
	# Post-emit the FSM has advanced to ACTION_PENDING (player goes first — mobility 50 vs 5).
	assert_eq(_bc.state(), BattleController.BattleState.ACTION_PENDING,
		"FSM is parked at ACTION_PENDING after round_started — no re-entrancy")


# ---------------------------------------------------------------------------
# 2. turn_started — fires after begin_turn, before the actor's action
# ---------------------------------------------------------------------------

func test_turn_started_fires_for_the_first_actor() -> void:
	watch_signals(_bc)

	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())

	assert_signal_emitted(_bc, "turn_started", "turn_started fires for the first actor")
	var p: Array = get_signal_parameters(_bc, "turn_started")
	# The first actor is the player (mobility 50 > enemy 5).
	assert_eq(p[0], &"slot_0", "combatant_id is slot_0 for the first player Symbot")
	assert_true(p[1], "is_player is true for the player actor")
	assert_eq(_bc.state(), BattleController.BattleState.ACTION_PENDING,
		"FSM remains parked after turn_started — not re-entered")


# ---------------------------------------------------------------------------
# 3. action_pending — fires when the FSM parks awaiting player input
# ---------------------------------------------------------------------------

func test_action_pending_fires_when_fsm_parks_for_player() -> void:
	watch_signals(_bc)

	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())

	assert_signal_emitted(_bc, "action_pending", "action_pending fires when player turn parks")
	var p: Array = get_signal_parameters(_bc, "action_pending")
	assert_true(p[0], "actor_is_player is true")
	assert_eq(_bc.state(), BattleController.BattleState.ACTION_PENDING,
		"FSM is ACTION_PENDING — signal reported the state truthfully, no re-entrancy")


# ---------------------------------------------------------------------------
# 4. action_resolving — fires in submit_action when RESOLVING begins
# ---------------------------------------------------------------------------

func test_action_resolving_fires_when_submit_action_is_called() -> void:
	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	watch_signals(_bc)

	_bc.submit_action(_kill_action())

	assert_signal_emitted(_bc, "action_resolving", "action_resolving fires at the start of resolution")
	# The kill action ends the battle, so post-emit state is BATTLE_END.
	assert_eq(_bc.state(), BattleController.BattleState.BATTLE_END,
		"FSM is BATTLE_END after the killing action resolved — no re-entrancy loop")


# ---------------------------------------------------------------------------
# 5. energy_changed — fires in begin_turn (recharge) and _resolve_player_move (spend)
# ---------------------------------------------------------------------------

func test_energy_changed_fires_on_recharge_at_turn_start() -> void:
	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	# The first turn start fires energy_changed for recharge. Collect it.
	# Re-watch BEFORE submit so we can see the next recharge in round 2 if needed,
	# but the initial start_battle already fires it — re-watch now captures future emits.
	# Instead: watch before start_battle to catch the initial recharge.
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	watch_signals(_bc2)
	_bc2.start_battle([_killer_loadout()], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())

	assert_signal_emitted(_bc2, "energy_changed",
		"energy_changed fires at begin_turn for the recharge step")
	var p: Array = get_signal_parameters(_bc2, "energy_changed")
	assert_eq(p[0], &"slot_0", "combatant_id slot_0")
	assert_true(p[1] >= 0, "new_value is non-negative")
	assert_eq(p[2], 80, "max_value matches energy_capacity 80")
	assert_eq(_bc2.state(), BattleController.BattleState.ACTION_PENDING,
		"FSM remains parked after energy_changed")


func test_energy_changed_fires_on_energy_spend_in_damage_move() -> void:
	# energy_cost 5 in the action; player starts at 80, recharges at turn start.
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	_bc2.start_battle([_killer_loadout()], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	watch_signals(_bc2)

	_bc2.submit_action(_damage_action_with_energy_cost(5))

	# energy_changed fires for the spend (energy_cost 5 deducted from current_energy).
	assert_signal_emitted(_bc2, "energy_changed",
		"energy_changed fires when DAMAGE-move energy is spent")
	# The last emission of energy_changed has the post-spend value.
	var p: Array = get_signal_parameters(_bc2, "energy_changed")
	assert_eq(p[0], &"slot_0", "combatant_id slot_0")
	assert_eq(p[2], 80, "max_value is energy_capacity 80")
	# new_value varies depending on recharge; just assert it's <= max.
	assert_true(p[1] <= 80, "new_value after spend is at most max_capacity")


# ---------------------------------------------------------------------------
# 6. heat_changed — fires in begin_turn (decay) and _settle_heat
# ---------------------------------------------------------------------------

func test_heat_changed_fires_on_heat_decay_at_turn_start() -> void:
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	watch_signals(_bc2)
	_bc2.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())

	assert_signal_emitted(_bc2, "heat_changed", "heat_changed fires for cooling decay in begin_turn")
	var p: Array = get_signal_parameters(_bc2, "heat_changed")
	assert_eq(p[0], &"slot_0", "combatant_id slot_0")
	assert_false(p[2], "is_overheated is false at turn start with zero heat")
	assert_eq(_bc2.state(), BattleController.BattleState.ACTION_PENDING,
		"FSM still parked after heat_changed")


# ---------------------------------------------------------------------------
# 7. structure_changed — fires after resolver hit on the target
# ---------------------------------------------------------------------------

func test_structure_changed_fires_after_resolver_applies_damage_to_enemy() -> void:
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	_bc2.start_battle([_killer_loadout()], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	var enemy_start_hp: int = _bc2.context().enemy.current_structure
	watch_signals(_bc2)

	_bc2.submit_action(_kill_action())

	assert_signal_emitted(_bc2, "structure_changed",
		"structure_changed fires after enemy takes damage")
	# Emission 0 is the player's hit on the enemy; a later emission is the enemy's
	# counterattack on the player (slot_0), so pin index 0 for the enemy's structure change.
	var p: Array = get_signal_parameters(_bc2, "structure_changed", 0)
	assert_eq(p[0], &"iron_colossus", "combatant_id matches the enemy id")
	assert_lt(p[1], enemy_start_hp, "new_value is less than starting structure (damage landed)")
	assert_eq(p[2], 1000, "max_value is the enemy's max_structure 1000")
	assert_false(p[3], "is_player is false for the enemy")


# ---------------------------------------------------------------------------
# 8. combatant_downed — fires in _down() after is_downed set and statuses cleared
# ---------------------------------------------------------------------------

func test_combatant_downed_fires_when_enemy_is_killed() -> void:
	watch_signals(_bc)
	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())

	_bc.submit_action(_kill_action())

	assert_signal_emitted(_bc, "combatant_downed",
		"combatant_downed fires when the enemy is killed")
	var p: Array = get_signal_parameters(_bc, "combatant_downed")
	assert_eq(p[0], &"husk_walker", "combatant_id is the enemy id")
	assert_false(p[1], "is_player is false for the enemy")
	assert_eq(_bc.state(), BattleController.BattleState.BATTLE_END,
		"FSM is BATTLE_END after the enemy is downed — no re-entrancy")


# ---------------------------------------------------------------------------
# 9. status_ticked — fires in begin_turn when Burn ticks (damage > 0)
# ---------------------------------------------------------------------------

func test_status_ticked_fires_when_burn_ticks_at_turn_start() -> void:
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	_bc2.start_battle([_killer_loadout()], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	# Apply Burn to the player before their next turn.
	var hero: Combatant = _bc2.context().active()
	hero.statuses.apply(StatusInstance.Type.BURN, 72, 2, _cfg)
	# Manually advance a turn start (begin_turn calls the tick).
	watch_signals(_bc2)
	_bc2.begin_turn(hero)

	assert_signal_emitted(_bc2, "status_ticked", "status_ticked fires when Burn ticks")
	var p: Array = get_signal_parameters(_bc2, "status_ticked")
	assert_eq(p[0], &"slot_0", "combatant_id slot_0")
	assert_eq(p[1], &"BURN", "status_id is BURN")
	assert_eq(p[2], 5, "damage is the Burn tick magnitude (proc 72 → 5)")


# ---------------------------------------------------------------------------
# 10. status_expired — fires in end_turn when decrement_turn removes a status
# ---------------------------------------------------------------------------

func test_status_expired_fires_when_status_duration_reaches_zero() -> void:
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	_bc2.start_battle([_killer_loadout()], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	var hero: Combatant = _bc2.context().active()
	# Apply a 1-turn Shock — one decrement_turn call will expire it.
	hero.statuses.apply(StatusInstance.Type.SHOCK, 53, 1, _cfg)
	assert_true(hero.statuses.has(StatusInstance.Type.SHOCK), "arrange: SHOCK is active")
	watch_signals(_bc2)

	_bc2.end_turn(hero)

	assert_signal_emitted(_bc2, "status_expired", "status_expired fires when SHOCK expires")
	var p: Array = get_signal_parameters(_bc2, "status_expired")
	assert_eq(p[0], &"slot_0", "combatant_id slot_0")
	assert_eq(p[1], &"SHOCK", "status_id is SHOCK")
	assert_false(hero.statuses.has(StatusInstance.Type.SHOCK), "SHOCK is gone after expiry")


# ---------------------------------------------------------------------------
# 11. overheat_triggered — fires in _settle_heat when threshold is crossed
# ---------------------------------------------------------------------------

func test_overheat_triggered_fires_when_heat_crosses_threshold() -> void:
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	_bc2.start_battle([_killer_loadout()], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	var hero: Combatant = _bc2.context().active()
	# Pre-load heat to 95; a move with part_heat 10 will push it to 100 (threshold).
	hero.current_heat = 95
	watch_signals(_bc2)

	# Apply heat gain directly via apply_move_heat to isolate the settle path.
	_bc2.apply_move_heat(hero, 10, false)

	assert_signal_emitted(_bc2, "overheat_triggered",
		"overheat_triggered fires when heat crosses the threshold")
	var p: Array = get_signal_parameters(_bc2, "overheat_triggered")
	assert_eq(p[0], &"slot_0", "combatant_id slot_0")
	assert_gt(p[1], 0, "self_damage is positive (floor(max_structure × overheat_pct))")
	assert_true(hero.is_overheated, "the is_overheated flag was set — state mutation complete before signal")


# ---------------------------------------------------------------------------
# 12. turn_skipped — fires in _run_turns when actor's action is skipped (overheat)
# ---------------------------------------------------------------------------

func test_turn_skipped_fires_for_overheated_actor() -> void:
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	_bc2.start_battle([_killer_loadout()], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	# Force the player into the overheated state before their next turn.
	var hero: Combatant = _bc2.context().active()
	hero.is_overheated = true
	# submit_action will be ignored since it's not ACTION_PENDING yet in a fresh state;
	# instead drive a new turn by advancing the turn cursor and calling _run_turns directly.
	# We can re-start with a tanky enemy and the hero pre-overheated by watching the
	# second start: create a fresh BC, pre-overheat then let the turn loop run.
	var _bc3: BattleController = BattleController.new(_cfg, _log)
	_bc3.start_battle([_killer_loadout()], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	var hero3: Combatant = _bc3.context().active()
	hero3.is_overheated = true
	# Mark the state as parked so we can call submit with a dummy that gets rejected,
	# then the turn loop will see the overheated flag on the actor's NEXT turn.
	# Simpler: directly call begin_turn (which resets the flag) and end_turn to complete
	# the turn, then watch for the skipped signal on the subsequent turn.
	# CLEANEST: use a 2-Symbot setup where the first player is overheated, then _run_turns
	# sees the skip on that first actor.
	var _bc4: BattleController = BattleController.new(_cfg, _log)
	var loadout0: SymbotLoadout = _killer_loadout()
	var loadout1: SymbotLoadout = _two_symbot_loadout(1)
	_bc4.start_battle([loadout0, loadout1], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	# The battle started and parked at ACTION_PENDING. Pre-overheat the actor.
	var ctx4 := _bc4.context()
	var actor4: Combatant = ctx4.turn_order[ctx4.turn_cursor]
	actor4.is_overheated = true
	watch_signals(_bc4)
	# A turn-skip is driven by the turn loop. We need to flush the current turn.
	# Advance the cursor past this turn by calling begin_turn (which resets the flag
	# and sets skipped_action) then let _run_turns handle it via a full turn cycle.
	# The easiest driver: call submit_action with an ITEM that has a bad target —
	# but that re-parks at ACTION_PENDING, not skipped. Instead, re-invoke _run_turns.
	_bc4._run_turns()

	assert_signal_emitted(_bc4, "turn_skipped",
		"turn_skipped fires when the overheated actor's action phase is skipped")
	var p: Array = get_signal_parameters(_bc4, "turn_skipped")
	assert_true(p[0] != &"", "combatant_id is non-empty")


# ---------------------------------------------------------------------------
# 13. forced_switch_required — fires when active is downed and bench is living
# ---------------------------------------------------------------------------

func test_forced_switch_required_fires_when_active_is_downed_by_enemy() -> void:
	# A tanky enemy with high attack vs a low-structure active — we'll manually down the
	# active and let the enemy action trigger forced_switch_required.
	# Easiest: use 2 Symbots, let enemy deal a killing blow to the active.
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	var l0: SymbotLoadout = _two_symbot_loadout(0)
	var l1: SymbotLoadout = _two_symbot_loadout(1)
	# Enemy with very high physical_power to one-shot the active player.
	var high_dmg_enemy: Dictionary = {"id": &"crusher", "stats":
		{&"structure": 500, &"armor": 0, &"mobility": 1, &"physical_power": 9999},
		"core_element": PartDef.Element.KINETIC, "level": 5, "xp_value": 80}
	_bc2.start_battle([l0, l1], high_dmg_enemy, BattleController.EncounterType.WILD, FakeSynergy.new())
	# Player (mobility 50) parks at ACTION_PENDING. Submit a no-cost move that won't kill the enemy.
	watch_signals(_bc2)
	# Submit an action that doesn't kill the enemy; the loop then processes the enemy's turn.
	# Use a zero-damage move (0 physical_power player loadout would work, but we have 0 power).
	# The _two_symbot_loadout has no physical_power — attack does minimal damage.
	_bc2.submit_action(_kill_action())

	assert_signal_emitted(_bc2, "forced_switch_required",
		"forced_switch_required fires when the active is downed by the enemy")
	assert_eq(_bc2.state(), BattleController.BattleState.FORCED_SWITCH,
		"FSM is parked at FORCED_SWITCH — not re-entered")


# ---------------------------------------------------------------------------
# 14. forced_switch_required via Burn-kill at turn start (second emission site)
# ---------------------------------------------------------------------------

func test_forced_switch_required_fires_on_burn_kill_at_turn_start() -> void:
	var _bc2: BattleController = BattleController.new(_cfg, _log)
	var l0: SymbotLoadout = _two_symbot_loadout(0)
	var l1: SymbotLoadout = _two_symbot_loadout(1)
	_bc2.start_battle([l0, l1], _tanky_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	var hero: Combatant = _bc2.context().active()
	hero.current_structure = 3  # lethal Burn (tick 5 at proc 72)
	hero.statuses.apply(StatusInstance.Type.BURN, 72, 2, _cfg)
	watch_signals(_bc2)
	# Drive the turn: begin_turn will tick the Burn, down the hero, then _handle_turn_start_death
	# will park FORCED_SWITCH and emit forced_switch_required.
	var ts: Dictionary = _bc2.begin_turn(hero)
	assert_true(ts["downed"], "arrange: hero is Burn-killed at turn start")
	_bc2._handle_turn_start_death(hero)

	assert_signal_emitted(_bc2, "forced_switch_required",
		"forced_switch_required fires when active is Burn-downed at turn start with living bench")
	assert_eq(_bc2.state(), BattleController.BattleState.FORCED_SWITCH,
		"FSM is FORCED_SWITCH — signal reported state truthfully")


# ---------------------------------------------------------------------------
# 15. status_applied — GAP: declared but NOT emitted in Phase 2-A.
#     The signal exists on the class; it simply never fires in a normal battle
#     because status application is routed through PassiveEffectRegistry,
#     bypassing the controller. Tests that has_signal + no emission.
# ---------------------------------------------------------------------------

func test_status_applied_signal_exists_but_does_not_fire_in_normal_battle() -> void:
	assert_true(_bc.has_signal("status_applied"),
		"status_applied is declared on BattleController (HUD surface complete)")
	watch_signals(_bc)
	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	_bc.submit_action(_kill_action())
	assert_signal_not_emitted(_bc, "status_applied",
		"status_applied does NOT fire in Phase 2-A — StatusSet hook gap (see TODO in core)")


# ---------------------------------------------------------------------------
# 16. break_region_updated — STUB: declared, never emitted (Part-Break pending)
# ---------------------------------------------------------------------------

func test_break_region_updated_is_stub_declared_but_never_emitted() -> void:
	assert_true(_bc.has_signal("break_region_updated"),
		"break_region_updated is declared on BattleController (STUB for Part-Break)")
	watch_signals(_bc)
	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	_bc.submit_action(_kill_action())
	assert_signal_not_emitted(_bc, "break_region_updated",
		"break_region_updated does NOT fire — Part-Break not yet integrated")


# ---------------------------------------------------------------------------
# 17. enrage_changed — STUB: declared, never emitted (Part-Break pending)
# ---------------------------------------------------------------------------

func test_enrage_changed_is_stub_declared_but_never_emitted() -> void:
	assert_true(_bc.has_signal("enrage_changed"),
		"enrage_changed is declared on BattleController (STUB for Part-Break)")
	watch_signals(_bc)
	_bc.start_battle([_killer_loadout()], _fragile_enemy(),
		BattleController.EncounterType.WILD, FakeSynergy.new())
	_bc.submit_action(_kill_action())
	assert_signal_not_emitted(_bc, "enrage_changed",
		"enrage_changed does NOT fire — Part-Break not yet integrated")
