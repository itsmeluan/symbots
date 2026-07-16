## Consumable-DB Story 005 — Salvage Beacon: CD-4 drop-boost math + per-battle flag.
##
## Covers AC-CD-04 (boost_drop clamp math), AC-CD-11 (one Beacon per battle — second
## rejected), AC-CD-12 (spent-on-flee-never-refunded + victory-only application). The
## CD-4 math is pure; the flag lifecycle is DI via [BeaconState] (the live drop roll is
## the TBC erratum AC-CD-21, DEFERRED). GUT · Godot 4.7.
extends GutTest

const OK := ConsumableUse.Outcome.USE_OK
const REJECTED := ConsumableUse.Outcome.USE_REJECTED


# ---------------------------------------------------------------------------
# AC-CD-04 — boost_drop clamp math (Beacon factor isolated, cond_mults = [])
# ---------------------------------------------------------------------------

func test_boost_drop_doubles_base_rate() -> void:
	# 0.25 × (empty product = 1.0) × 2.0 = 0.50. An impl that treats the empty
	# product as 0.0 wrongly returns 0.0.
	assert_almost_eq(ConsumableEffects.boost_drop(0.25, [], 2.0), 0.50, 0.0000001)

func test_boost_drop_clamps_over_one() -> void:
	# 0.70 × 2.0 = 1.40 → clamped to the 1.0 probability ceiling.
	assert_almost_eq(ConsumableEffects.boost_drop(0.70, [], 2.0), 1.0, 0.0000001)

func test_boost_drop_empty_product_is_identity() -> void:
	# No Beacon (multiplier 1.0), no conditions → base rate unchanged.
	assert_almost_eq(ConsumableEffects.boost_drop(0.25, [], 1.0), 0.25, 0.0000001)

func test_boost_drop_composes_condition_multipliers() -> void:
	# 0.10 × (0.5 × 4.0 = 2.0) × 2.0 = 0.40 — the Beacon factor multiplies INTO the
	# drop-condition product, it does not replace it.
	assert_almost_eq(ConsumableEffects.boost_drop(0.10, [0.5, 4.0], 2.0), 0.40, 0.0000001)


# ---------------------------------------------------------------------------
# AC-CD-11 — one Beacon per battle (second use rejected, not stacked/wasted)
# ---------------------------------------------------------------------------

func test_first_beacon_used_sets_flag_and_consumes() -> void:
	var beacon := BeaconState.new()
	beacon.beacon_qty = 2
	var r := beacon.use_beacon()
	assert_eq(r["outcome"], OK, "first Beacon of the battle applies")
	assert_true(beacon.beacon_used_this_battle, "flag raised")
	assert_eq(beacon.beacon_qty, 1, "exactly one consumed")
	assert_eq(r["new_qty"], 1)

func test_second_beacon_rejected_and_not_consumed() -> void:
	var beacon := BeaconState.new()
	beacon.beacon_qty = 2
	beacon.use_beacon()
	var second := beacon.use_beacon()
	assert_eq(second["outcome"], REJECTED, "a second Beacon while active is rejected")
	assert_eq(second["reason"], ConsumableUse.Reason.SECOND_BEACON)
	assert_eq(beacon.beacon_qty, 1, "the rejected second Beacon is NOT consumed")

func test_beacon_with_zero_qty_rejected() -> void:
	var beacon := BeaconState.new()
	beacon.beacon_qty = 0
	var r := beacon.use_beacon()
	assert_eq(r["outcome"], REJECTED)
	assert_eq(r["reason"], ConsumableUse.Reason.QUANTITY_ZERO)
	assert_false(beacon.beacon_used_this_battle, "no flag on a failed use")


# ---------------------------------------------------------------------------
# AC-CD-12 — victory-only application; spent on flee/loss, never refunded
# ---------------------------------------------------------------------------

func test_multiplier_applies_on_victory() -> void:
	var beacon := BeaconState.new()
	beacon.beacon_qty = 1
	beacon.use_beacon()
	beacon.on_battle_end(BeaconState.BattleOutcome.WIN)
	assert_true(beacon.beacon_drop_multiplier_applied, "boost applies on a win")
	assert_false(beacon.beacon_used_this_battle, "per-battle flag cleared at end")

func test_flee_spends_beacon_no_effect_no_refund() -> void:
	var beacon := BeaconState.new()
	beacon.beacon_qty = 1
	beacon.use_beacon()  # qty 1 → 0
	beacon.on_battle_end(BeaconState.BattleOutcome.FLEE)
	assert_false(beacon.beacon_drop_multiplier_applied, "no boost on flee")
	assert_eq(beacon.beacon_qty, 0, "the Beacon is spent — NOT refunded on flee")

func test_loss_spends_beacon_no_effect_no_refund() -> void:
	var beacon := BeaconState.new()
	beacon.beacon_qty = 1
	beacon.use_beacon()
	beacon.on_battle_end(BeaconState.BattleOutcome.LOSS)
	assert_false(beacon.beacon_drop_multiplier_applied, "no boost on loss")
	assert_eq(beacon.beacon_qty, 0, "spent on loss — never refunded")

func test_unused_beacon_never_applies() -> void:
	var beacon := BeaconState.new()
	beacon.beacon_qty = 1
	beacon.on_battle_end(BeaconState.BattleOutcome.WIN)
	assert_false(beacon.beacon_drop_multiplier_applied, "no use → no boost even on a win")
	assert_eq(beacon.beacon_qty, 1, "an unused Beacon is retained")
