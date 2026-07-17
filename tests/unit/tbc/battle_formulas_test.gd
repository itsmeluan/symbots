## TBC formula kernel — TBC-F1…F7 + SYN-F4 effective_stat (discriminating fixtures).
##
## Every worked example here is the GDD's own discriminating fixture: the expected
## integer differs from what a round()/ceil() implementation would produce, so a
## regression to round-half-away is caught. Coefficients come from a bare
## BalanceConfig.new() (its @export defaults mirror the GDD formula tables).
##
## The epsilons are DEFENSIVE (GDD scan-verified 2026-07-10/11); these fixtures
## discriminate floor-vs-round, which is the real risk. Framework: GUT · Godot 4.7.
extends GutTest

var _cfg: BalanceConfig


func before_each() -> void:
	_cfg = BalanceConfig.new()


# ---------------------------------------------------------------------------
# TBC-F1 — initiative order
# ---------------------------------------------------------------------------

func test_effective_mobility_subtracts_shock_floored_at_zero() -> void:
	# base 64, shock 15, no synergy → 49 (a round() shock 16 would give 48).
	assert_eq(BattleFormulas.effective_mobility(64, 0, 15), 49, "64 − 15 = 49")
	# Synergy delta adds; enemy path passes 0.
	assert_eq(BattleFormulas.effective_mobility(64, 8, 15), 57, "64 + 8 − 15 = 57")


func test_effective_mobility_floors_at_zero_never_negative() -> void:
	# A Shocked zero-mobility combatant: max(0, 0 + 0 − 15) = 0, not −15 (EC-TBC-01).
	assert_eq(BattleFormulas.effective_mobility(0, 0, 15), 0, "floored at 0")
	assert_eq(BattleFormulas.effective_mobility(10, 0, 33), 0, "10 − 33 → 0 not −23")


# ---------------------------------------------------------------------------
# TBC-F2 — energy recharge (integer, cap load-bearing)
# ---------------------------------------------------------------------------

func test_recharge_cap_fires_and_is_silent_paired() -> void:
	# Paired assertion (GDD): cap fires at 95, and stays silent below cap.
	assert_eq(BattleFormulas.recharge_energy(73, 22, 95, _cfg), 95,
		"min(95, 73+10+22) = 95 — cap fires (no-min would give 105)")
	assert_eq(BattleFormulas.recharge_energy(40, 22, 95, _cfg), 72,
		"min(95, 40+10+22) = 72 — cap silent")


# ---------------------------------------------------------------------------
# TBC-F3 — burn DoT
# ---------------------------------------------------------------------------

func test_burn_damage_discriminating_and_min() -> void:
	assert_eq(BattleFormulas.burn_damage(72, _cfg), 5, "max(2, floor(5.7601)) = 5 (round → 6)")
	# BURN_MIN floor: a zero-processing applier still ticks 2.
	assert_eq(BattleFormulas.burn_damage(0, _cfg), 2, "BURN_MIN = 2 for zero-CHIPSET builds")
	# Ceiling: processing 110 → floor(8.8001) = 8.
	assert_eq(BattleFormulas.burn_damage(110, _cfg), 8, "max tick = 8 at processing 110")


# ---------------------------------------------------------------------------
# TBC-F4 — shock mobility reduction (stored positive)
# ---------------------------------------------------------------------------

func test_shock_magnitude_discriminating_and_positive() -> void:
	assert_eq(BattleFormulas.shock_magnitude(53, _cfg), 15, "floor(15.9001) = 15 (round → 16)")
	# Sign discipline: magnitude is POSITIVE — TBC-F1 subtracts it.
	assert_true(BattleFormulas.shock_magnitude(110, _cfg) > 0, "stored positive")
	assert_eq(BattleFormulas.shock_magnitude(110, _cfg), 33, "ceiling 33 at processing 110")
	# Zero-processing → legal 0-penalty Shock (EC-TBC-09).
	assert_eq(BattleFormulas.shock_magnitude(0, _cfg), 0, "zero applier → 0 penalty")


# ---------------------------------------------------------------------------
# TBC-F5 — stagger (two discriminating steps)
# ---------------------------------------------------------------------------

func test_stagger_pct_discriminating() -> void:
	assert_eq(BattleFormulas.stagger_pct(86, _cfg), 21, "floor(21.5001) = 21 (round-half-away → 22)")
	assert_eq(BattleFormulas.stagger_pct(0, _cfg), 0, "zero applier → 0% (EC-TBC-09)")


func test_apply_stagger_discriminating_and_floored() -> void:
	# final_damage 50 at pct 21 → max(1, floor(39.5001)) = 39 (round → 40).
	assert_eq(BattleFormulas.apply_stagger(50, 21, _cfg), 39, "39 (round → 40)")
	# Stagger cannot zero a hit — floored at DAMAGE_FLOOR.
	assert_eq(BattleFormulas.apply_stagger(1, 27, _cfg), 1, "floored at 1, never 0")
	# 0% is the identity.
	assert_eq(BattleFormulas.apply_stagger(50, 0, _cfg), 50, "0% → unchanged")


# ---------------------------------------------------------------------------
# TBC-F6 — repair amount (scales on EFFECTIVE energy_power)
# ---------------------------------------------------------------------------

func test_repair_amount_discriminating_extremes() -> void:
	assert_eq(BattleFormulas.repair_amount(45, _cfg), 12, "max(5, floor(12.6501)) = 12 (round → 13)")
	assert_eq(BattleFormulas.repair_amount(110, _cfg), 23, "ep 110 → 23 (round → 24)")
	assert_eq(BattleFormulas.repair_amount(150, _cfg), 30, "ep 150 (max synergy) → 30 (round → 31)")
	# REPAIR_MIN floor for zero-investment.
	assert_eq(BattleFormulas.repair_amount(0, _cfg), 5, "REPAIR_MIN = 5")


# ---------------------------------------------------------------------------
# TBC-F7 — enemy enrage (post-Stagger)
# ---------------------------------------------------------------------------

func test_enrage_damage_discriminating_identity_and_maxstack() -> void:
	assert_eq(BattleFormulas.enrage_damage(43, 1, _cfg), 48, "hit 43, count 1 → 48 (round/ceil → 49)")
	assert_eq(BattleFormulas.enrage_damage(43, 0, _cfg), 43, "count 0 → identity 43 (×1.00)")
	assert_eq(BattleFormulas.enrage_damage(41, 3, _cfg), 55, "hit 41, count 3 → 55 (round/ceil → 56)")


# ---------------------------------------------------------------------------
# SYN-F4 — effective_stat clamp (StatMath)
# ---------------------------------------------------------------------------

func test_effective_stat_sums_and_clamps() -> void:
	var base := {&"energy_power": 110, &"armor": 8}
	var syn := {&"energy_power": 40}
	var aura := {}
	assert_eq(StatMath.effective_stat(base, syn, aura, &"energy_power"), 150,
		"110 + 40 + 0 = 150 (SYN-F4 max power)")
	assert_eq(StatMath.effective_stat(base, syn, aura, &"armor"), 8, "no synergy on armor → base")
	assert_eq(StatMath.effective_stat(base, syn, aura, &"targeting"), 0, "absent stat → 0")


func test_effective_stat_clamps_negative_to_zero() -> void:
	# A hypothetical negative synergy must not drive a stat below 0.
	var base := {&"mobility": 5}
	assert_eq(StatMath.effective_stat(base, {&"mobility": -20}, {}, &"mobility"), 0,
		"max(0, 5 − 20) = 0")
