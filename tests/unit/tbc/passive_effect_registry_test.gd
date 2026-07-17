## TBC Story 013 — PassiveEffectRegistry trigger dispatch (Rule 13).
##
## Covers AC-TBC-29 (volt_shock_on_hit fires on any DAMAGE, NOT on REPAIR), AC-TBC-30
## (thermal_burn_on_weapon is WEAPON-slot-only — a HEAD-slot hit applies nothing),
## AC-TBC-14 (an unknown effect id logs exactly one content error and is skipped, the
## known sibling still firing), and AC-TBC-40 (ON_BATTLE_START / ON_TURN_START generic
## entries dispatch, PERSISTENT/absent triggers do not fire on those events).
## Framework: GUT · Godot 4.7.
extends GutTest

const SpyLogSink := preload("res://tests/unit/tbc/spy_log_sink.gd")

var _cfg: BalanceConfig
var _log
var _reg: PassiveEffectRegistry


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_log = SpyLogSink.new()
	_reg = PassiveEffectRegistry.new(_log)


func _carrier() -> Combatant:
	# processing 50 → shock_magnitude(50) = floor(15.0001) = 15 (discriminating).
	return Combatant.make_player(0, 7, {&"processing": 50, &"structure": 100}, {}, {}, null)


func _target() -> Combatant:
	return Combatant.make_enemy(&"dummy", {&"structure": 200}, PartDef.Element.KINETIC)


func _damage_move() -> MoveDef:
	var m := MoveDef.new()
	m.behavior = MoveDef.Behavior.DAMAGE
	return m


func _repair_move() -> MoveDef:
	var m := MoveDef.new()
	m.behavior = MoveDef.Behavior.REPAIR
	return m


# ---------------------------------------------------------------------------
# AC-TBC-29 — volt_shock_on_hit: Shock 1T on any DAMAGE, nothing on REPAIR
# ---------------------------------------------------------------------------

func test_volt_shock_rider_applies_shock_on_damage() -> void:
	var carrier := _carrier()
	var target := _target()

	_reg.dispatch_on_hit(carrier, [&"volt_shock_on_hit"], _damage_move(), false, target, _cfg)

	assert_true(target.statuses.has(StatusInstance.Type.SHOCK), "Shock applied on a DAMAGE hit")
	var shock := target.statuses.get_status(StatusInstance.Type.SHOCK)
	assert_eq(shock.magnitude, 15, "Shock magnitude = shock_magnitude(carrier processing 50) = 15")
	assert_eq(shock.duration, 1, "volt_shock_on_hit is a 1-turn Shock")


func test_volt_shock_rider_does_not_fire_on_repair() -> void:
	var carrier := _carrier()
	var target := _target()

	_reg.dispatch_on_hit(carrier, [&"volt_shock_on_hit"], _repair_move(), false, target, _cfg)

	assert_eq(target.statuses.count(), 0, "ON_HIT riders never trigger on a non-DAMAGE move")


# ---------------------------------------------------------------------------
# AC-TBC-30 — thermal_burn_on_weapon is WEAPON-slot only
# ---------------------------------------------------------------------------

func test_thermal_burn_rider_fires_only_on_weapon_slot() -> void:
	var carrier := _carrier()
	var weapon_target := _target()
	var head_target := _target()

	# WEAPON-slot hit → Burn 2T applied.
	_reg.dispatch_on_hit(carrier, [&"thermal_burn_on_weapon"], _damage_move(), true, weapon_target, _cfg)
	assert_true(weapon_target.statuses.has(StatusInstance.Type.BURN), "WEAPON-slot hit applies Burn")
	assert_eq(weapon_target.statuses.get_status(StatusInstance.Type.BURN).duration, 2,
		"thermal_burn_on_weapon is a 2-turn Burn")

	# HEAD-slot hit (is_weapon_slot false) → nothing.
	_reg.dispatch_on_hit(carrier, [&"thermal_burn_on_weapon"], _damage_move(), false, head_target, _cfg)
	assert_eq(head_target.statuses.count(), 0, "a non-WEAPON-slot hit applies no Burn (scope gate)")


# ---------------------------------------------------------------------------
# AC-TBC-14 — unknown effect id logs once + is skipped; known sibling still fires
# ---------------------------------------------------------------------------

func test_unknown_effect_id_logs_once_and_skips() -> void:
	var carrier := _carrier()
	var target := _target()

	_reg.dispatch_on_hit(carrier, [&"not_a_real_passive", &"kinetic_stagger_on_hit"],
		_damage_move(), false, target, _cfg)

	assert_eq(_log.errors.size(), 1, "exactly one content error for the unknown id")
	assert_eq(_log.errors[0]["code"], &"content_unknown_passive_effect", "correct error code")
	assert_true(target.statuses.has(StatusInstance.Type.STAGGER),
		"processing continues — the known kinetic_stagger_on_hit still fires")


# ---------------------------------------------------------------------------
# AC-TBC-40 — ON_BATTLE_START / ON_TURN_START generic dispatch
# ---------------------------------------------------------------------------

func test_battle_start_and_turn_start_triggers_dispatch_independently() -> void:
	var boot_hits := [0]
	var turn_hits := [0]
	var extra := {
		&"z_on_boot": PassiveEffectRegistry.generic(
			PassiveEffectRegistry.Trigger.ON_BATTLE_START, func(_c: Combatant) -> void: boot_hits[0] += 1),
		&"a_on_turn": PassiveEffectRegistry.generic(
			PassiveEffectRegistry.Trigger.ON_TURN_START, func(_c: Combatant) -> void: turn_hits[0] += 1),
	}
	var reg := PassiveEffectRegistry.new(_log, extra)
	var carrier := _carrier()
	var pool: Array = [&"z_on_boot", &"a_on_turn"]

	reg.dispatch_battle_start(carrier, pool)
	assert_eq(boot_hits[0], 1, "ON_BATTLE_START entry fired once at boot")
	assert_eq(turn_hits[0], 0, "the ON_TURN_START entry did NOT fire on the boot event")

	reg.dispatch_turn_start(carrier, pool)
	assert_eq(turn_hits[0], 1, "ON_TURN_START entry fired once at turn start")
	assert_eq(boot_hits[0], 1, "the boot entry did not re-fire on the turn event")
