## Consumable-DB Story 004 — use-transaction validation, targeting, resource-neutrality.
##
## Covers AC-CD-05 (zero-net rejected / partial allowed), AC-CD-06 (downed rejected),
## AC-CD-07 (wrong context rejected / BOTH valid), AC-CD-08 (quantity 0 rejected, no
## underflow), AC-CD-24 (living-target predicate), AC-CD-25 (resource-neutral use).
## The transaction is pure/DI — target state + context are injected. GUT · Godot 4.7.
extends GutTest

const OK := ConsumableUse.Outcome.USE_OK
const REJECTED := ConsumableUse.Outcome.USE_REJECTED
const BATTLE := ConsumableDef.UseContext.BATTLE
const WORLD := ConsumableDef.UseContext.WORLD


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

func _restorative(id: StringName, effect: ConsumableDef.EffectType, amount: int,
		ctx: ConsumableDef.UseContext) -> ConsumableDef:
	var cd := ConsumableDef.new()
	cd.consumable_id = id
	cd.effect_type = effect
	cd.effect_params = {"amount": amount}
	cd.use_context = ctx
	cd.target = ConsumableDef.Target.LIVING_TEAM_MEMBER
	return cd

func _weld_patch(ctx := ConsumableDef.UseContext.BOTH) -> ConsumableDef:
	return _restorative(&"weld_patch", ConsumableDef.EffectType.RESTORE_STRUCTURE, 25, ctx)

func _coolant(ctx := ConsumableDef.UseContext.BOTH) -> ConsumableDef:
	return _restorative(&"coolant_flush", ConsumableDef.EffectType.REDUCE_HEAT, 50, ctx)

## A living target with plenty of headroom (structure below max, heat present).
func _living_state() -> Dictionary:
	return {"structure": 45, "max_structure": 594, "heat": 30, "energy": 90, "max_energy": 100}


# ---------------------------------------------------------------------------
# AC-CD-05 — zero-net rejected, partial allowed
# ---------------------------------------------------------------------------

func test_full_structure_target_rejected_not_consumed() -> void:
	var state := {"structure": 594, "max_structure": 594}
	var r := ConsumableUse.resolve(_weld_patch(), state, BATTLE, 1)
	assert_eq(r["outcome"], REJECTED, "full-structure heal is inert → rejected")
	assert_eq(r["reason"], ConsumableUse.Reason.NO_NET_EFFECT)
	assert_eq(r["new_qty"], 1, "rejected use consumes nothing")

func test_heat_zero_target_rejected() -> void:
	var state := {"structure": 100, "heat": 0}
	var r := ConsumableUse.resolve(_coolant(), state, BATTLE, 1)
	assert_eq(r["outcome"], REJECTED, "Heat already 0 → inert Coolant Flush rejected")
	assert_eq(r["new_qty"], 1)

func test_partial_heal_allowed_and_consumed() -> void:
	# max 594 / current 580, heals 14 → USE_OK, consumed. A reject-any-clamped-heal
	# impl wrongly rejects this.
	var state := {"structure": 580, "max_structure": 594}
	var r := ConsumableUse.resolve(_weld_patch(), state, BATTLE, 1)
	assert_eq(r["outcome"], OK, "a partial heal is allowed")
	assert_eq(r["applied_delta"], 14, "delta is the clamped change, not the raw amount")
	assert_eq(r["new_qty"], 0, "successful use decrements by 1")


# ---------------------------------------------------------------------------
# AC-CD-06 — downed target rejected
# ---------------------------------------------------------------------------

func test_downed_target_rejected() -> void:
	var repair := _restorative(&"repair_kit", ConsumableDef.EffectType.RESTORE_STRUCTURE, 50, ConsumableDef.UseContext.BOTH)
	var state := {"structure": 0, "max_structure": 594}
	var r := ConsumableUse.resolve(repair, state, BATTLE, 1)
	assert_eq(r["outcome"], REJECTED, "structure 0 is downed — no revive")
	assert_eq(r["reason"], ConsumableUse.Reason.INVALID_TARGET)
	assert_eq(r["new_qty"], 1)


# ---------------------------------------------------------------------------
# AC-CD-07 — wrong context rejected, BOTH valid in either
# ---------------------------------------------------------------------------

func test_battle_only_item_rejected_in_world() -> void:
	var beacon := _restorative(&"salvage_beacon", ConsumableDef.EffectType.BOOST_DROP, 0, BATTLE)
	beacon.effect_params = {"multiplier": 2.0}
	var r := ConsumableUse.resolve(beacon, {}, WORLD, 1)
	assert_eq(r["outcome"], REJECTED, "a BATTLE item used in world is rejected on context")
	assert_eq(r["reason"], ConsumableUse.Reason.WRONG_CONTEXT)
	assert_eq(r["new_qty"], 1)

func test_world_only_item_rejected_in_battle() -> void:
	var jammer := _restorative(&"signal_jammer", ConsumableDef.EffectType.MODIFY_ENCOUNTER_RATE, 0, WORLD)
	jammer.effect_params = {"rate_multiplier": 0.1, "duration_steps": 20}
	var r := ConsumableUse.resolve(jammer, {}, BATTLE, 1)
	assert_eq(r["outcome"], REJECTED, "a WORLD item used in battle is rejected on context")
	assert_eq(r["new_qty"], 1)

func test_both_context_item_valid_in_battle() -> void:
	var r := ConsumableUse.resolve(_weld_patch(BATTLE), _living_state(), BATTLE, 1)
	assert_eq(r["outcome"], OK, "a BOTH item with a valid living target is OK in battle")

func test_both_context_item_valid_in_world() -> void:
	# AC-CD-07 "BOTH valid in either" — the world half of the claim. A context gate
	# that only whitelists BATTLE would wrongly reject this.
	var r := ConsumableUse.resolve(_weld_patch(ConsumableDef.UseContext.BOTH), _living_state(), WORLD, 1)
	assert_eq(r["outcome"], OK, "a BOTH item with a valid living target is OK in world")


# ---------------------------------------------------------------------------
# AC-CD-08 — quantity 0 rejected, no underflow
# ---------------------------------------------------------------------------

func test_quantity_zero_rejected_no_underflow() -> void:
	var r := ConsumableUse.resolve(_weld_patch(), _living_state(), BATTLE, 0)
	assert_eq(r["outcome"], REJECTED, "qty 0 is rejected")
	assert_eq(r["reason"], ConsumableUse.Reason.QUANTITY_ZERO)
	assert_eq(r["new_qty"], 0, "no underflow to −1")

func test_quantity_one_ok_decrements_to_zero() -> void:
	var r := ConsumableUse.resolve(_weld_patch(), _living_state(), BATTLE, 1)
	assert_eq(r["outcome"], OK)
	assert_eq(r["new_qty"], 0)


# ---------------------------------------------------------------------------
# AC-CD-24 — living-target predicate (boundary structure == 1 is valid)
# ---------------------------------------------------------------------------

func test_is_valid_target_predicate() -> void:
	assert_true(ConsumableUse.is_valid_target(1), "boundary structure 1 is alive")
	assert_true(ConsumableUse.is_valid_target(45))
	assert_true(ConsumableUse.is_valid_target(594))
	assert_false(ConsumableUse.is_valid_target(0), "structure 0 is downed")


# ---------------------------------------------------------------------------
# AC-CD-25 — resource-neutral use
# ---------------------------------------------------------------------------

func test_successful_use_is_resource_neutral() -> void:
	var r := ConsumableUse.resolve(_weld_patch(), _living_state(), BATTLE, 1)
	assert_eq(r["outcome"], OK, "precondition: the use applies")
	assert_eq(r["heat_generated"], 0, "item-use generates no Heat")
	assert_eq(r["energy_consumed"], 0, "item-use consumes no Energy")
