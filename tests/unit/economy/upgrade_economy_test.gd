## Scrap economy — upgrade costs, rewards, and the tension they exist to create (§5).
##
## Most of these are not arithmetic checks. They are checks on the SHAPE of the curves,
## because the design's retention argument (§5.2) is a claim about shape: costs must climb
## faster than income, or the single Scrap pool stops being a constraint and every upgrade
## becomes a formality. A test on a specific number would pass a retune that broke the
## argument; a test on the shape does not.
extends GutTest

const UpgradeEconomyScript := preload("res://src/core/economy/upgrade_economy.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

var _cfg: BalanceConfig
var _wallet: Wallet
var _inst: SymbotInstance


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_wallet = Wallet.new()
	_inst = SymbotInstanceScript.new(&"probe", &"rustcrawler")


# ---------------------------------------------------------------------------
# Curve shape
# ---------------------------------------------------------------------------

func test_each_level_costs_more_than_the_one_before() -> void:
	var last := 0
	for lv in range(1, 60):
		var cost := UpgradeEconomyScript.level_cost(lv, _cfg)
		assert_gt(cost, last, "level %d must cost more than %d" % [lv, lv - 1])
		last = cost


func test_the_cost_curve_accelerates_rather_than_climbing_evenly() -> void:
	# A linear curve makes late levels trivial, and trivial upgrades dissolve the budget
	# decision §5.2 is built on. The gap between consecutive levels must itself grow.
	var early_gap := UpgradeEconomyScript.level_cost(5, _cfg) \
		- UpgradeEconomyScript.level_cost(4, _cfg)
	var late_gap := UpgradeEconomyScript.level_cost(50, _cfg) \
		- UpgradeEconomyScript.level_cost(49, _cfg)
	assert_gt(late_gap, early_gap * 3,
		"late levels must bite far harder (early gap %d, late gap %d)" % [early_gap, late_gap])


func test_upgrade_costs_outrun_battle_income() -> void:
	# THE economic claim. If a single battle's reward kept pace with a single level's cost,
	# Scrap would stop being scarce and every Symbot could be maxed — there would be no
	# "spread or concentrate" question left to bring the player back.
	var battles_for_early := ceili(float(UpgradeEconomyScript.level_cost(2, _cfg))
		/ float(UpgradeEconomyScript.battle_reward(1, _cfg)))
	var battles_for_late := ceili(float(UpgradeEconomyScript.level_cost(50, _cfg))
		/ float(UpgradeEconomyScript.battle_reward(50, _cfg)))
	assert_gt(battles_for_late, battles_for_early * 5,
		"a late level must cost far more battles than an early one (%d vs %d)"
			% [battles_for_late, battles_for_early])


func test_cost_to_reach_is_the_sum_of_the_steps() -> void:
	var summed := 0
	for lv in range(1, 5):
		summed += UpgradeEconomyScript.level_cost(lv, _cfg)
	assert_eq(UpgradeEconomyScript.cost_to_reach(1, 5, _cfg), summed)


func test_cost_to_reach_a_level_already_held_is_zero() -> void:
	assert_eq(UpgradeEconomyScript.cost_to_reach(10, 10, _cfg), 0)
	assert_eq(UpgradeEconomyScript.cost_to_reach(10, 5, _cfg), 0, "and never negative")


# ---------------------------------------------------------------------------
# Charging
# ---------------------------------------------------------------------------

func test_an_upgrade_charges_exactly_the_quoted_price() -> void:
	var quoted := UpgradeEconomyScript.level_cost(1, _cfg)
	_wallet.earn(Wallet.SCRAP, 10000)
	var spent := UpgradeEconomyScript.upgrade(_inst, 0, _wallet, _cfg)
	assert_eq(spent, quoted, "the price shown is the price charged")
	assert_eq(_wallet.scrap, 10000 - quoted)
	assert_eq(_inst.get_part_level(0), 2)


func test_an_unaffordable_upgrade_charges_nothing_and_changes_nothing() -> void:
	_wallet.earn(Wallet.SCRAP, 1)
	assert_eq(UpgradeEconomyScript.can_upgrade(_inst, 0, _wallet, _cfg),
		UpgradeEconomyScript.Refusal.CANNOT_AFFORD)
	assert_eq(UpgradeEconomyScript.upgrade(_inst, 0, _wallet, _cfg), 0)
	assert_eq(_wallet.scrap, 1, "a wallet debited for a level that did not apply is the "
		+ "one economy bug a player never forgives")
	assert_eq(_inst.get_part_level(0), 1)


func test_a_part_at_the_mark_cap_refuses_with_its_own_reason() -> void:
	# "You cannot afford this" and "this is capped until you retrofit" send the player to
	# completely different places, so they must be distinguishable.
	_wallet.earn(Wallet.SCRAP, 10_000_000)
	var cap := _inst.part_level_cap()
	for i in range(1, cap):
		UpgradeEconomyScript.upgrade(_inst, 0, _wallet, _cfg)
	assert_eq(_inst.get_part_level(0), cap)
	assert_eq(UpgradeEconomyScript.can_upgrade(_inst, 0, _wallet, _cfg),
		UpgradeEconomyScript.Refusal.AT_MARK_CAP)


func test_a_nonexistent_slot_is_refused_rather_than_crashing() -> void:
	_wallet.earn(Wallet.SCRAP, 10000)
	assert_eq(UpgradeEconomyScript.can_upgrade(_inst, 99, _wallet, _cfg),
		UpgradeEconomyScript.Refusal.NO_SUCH_PART)
	assert_eq(UpgradeEconomyScript.can_upgrade(_inst, -1, _wallet, _cfg),
		UpgradeEconomyScript.Refusal.NO_SUCH_PART)


func test_maxing_every_part_prices_all_five_slots() -> void:
	var one_slot := UpgradeEconomyScript.cost_to_reach(1, _inst.part_level_cap(), _cfg)
	assert_eq(UpgradeEconomyScript.cost_to_max_all_parts(_inst, _cfg),
		one_slot * SymbotInstanceScript.PART_COUNT)


func test_maxing_one_symbot_costs_many_battles() -> void:
	# The number that makes "spread or concentrate" concrete. If one Symbot could be maxed
	# in a handful of fights, there would be no budget to compete over.
	var total := UpgradeEconomyScript.cost_to_max_all_parts(_inst, _cfg)
	var per_battle := UpgradeEconomyScript.battle_reward(1, _cfg)
	assert_gt(total / per_battle, 100,
		"maxing a Mk I Symbot should be a campaign, not an afternoon")


# ---------------------------------------------------------------------------
# Rewards
# ---------------------------------------------------------------------------

func test_later_stages_pay_better() -> void:
	assert_gt(UpgradeEconomyScript.battle_reward(10, _cfg),
		UpgradeEconomyScript.battle_reward(1, _cfg))


func test_the_first_stage_still_pays_something() -> void:
	assert_gt(UpgradeEconomyScript.battle_reward(1, _cfg), 0)
	assert_eq(UpgradeEconomyScript.battle_reward(0, _cfg),
		UpgradeEconomyScript.battle_reward(1, _cfg),
		"a nonsense stage index floors at stage 1 rather than paying negative")


func test_the_completion_chest_beats_farming_the_first_battle() -> void:
	# Otherwise players optimise by replaying the easiest fight forever and the stage
	# structure stops meaning anything (§6).
	var chest := UpgradeEconomyScript.chest_reward(5, _cfg)
	var battle := UpgradeEconomyScript.battle_reward(5, _cfg)
	assert_gt(chest, battle * 3, "chest %d vs battle %d" % [chest, battle])
