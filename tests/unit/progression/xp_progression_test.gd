## XP into levels, and levels into skill points (Core Design §2.2, §4.2).
##
## Levels are the ONLY source of skill points, and XP the only source of levels. If this
## curve is wrong the tree is dead content — the player would have nodes they can reach and
## no points to spend. So the checks here are mostly about the loop actually turning.
extends GutTest

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const StageRunnerScript := preload("res://src/core/stages/stage_runner.gd")
const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")

var _cfg: BalanceConfig
var _inst: SymbotInstance


func before_each() -> void:
	_cfg = BalanceConfig.new()
	_inst = SymbotInstanceScript.new(&"probe", &"rustcrawler")


# ---------------------------------------------------------------------------
# The curve
# ---------------------------------------------------------------------------

func test_each_level_needs_more_xp_than_the_last() -> void:
	var last := 0
	for lv in range(1, 60):
		var needed := XpProgression.xp_to_next(lv, _cfg)
		assert_gt(needed, last, "level %d must cost more than %d" % [lv, lv - 1])
		last = needed


func test_the_xp_curve_accelerates() -> void:
	# A flat curve makes late levels arrive on their own, and the decision of WHERE to
	# fight stops mattering.
	var early := XpProgression.xp_to_next(5, _cfg) - XpProgression.xp_to_next(4, _cfg)
	var late := XpProgression.xp_to_next(50, _cfg) - XpProgression.xp_to_next(49, _cfg)
	assert_gt(late, early * 3, "early gap %d, late gap %d" % [early, late])


func test_a_harder_stage_pays_more_xp() -> void:
	assert_gt(XpProgression.battle_xp(20, 2, _cfg), XpProgression.battle_xp(1, 2, _cfg))


func test_more_enemies_pay_more_xp() -> void:
	assert_gt(XpProgression.battle_xp(5, 4, _cfg), XpProgression.battle_xp(5, 1, _cfg))


# ---------------------------------------------------------------------------
# Granting
# ---------------------------------------------------------------------------

func test_enough_xp_levels_the_symbot() -> void:
	XpProgression.grant(_inst, XpProgression.xp_to_next(1, _cfg), _cfg)
	assert_eq(_inst.level, 2)


func test_a_large_award_can_grant_several_levels_at_once() -> void:
	var needed := XpProgression.xp_to_next(1, _cfg) + XpProgression.xp_to_next(2, _cfg)
	assert_eq(XpProgression.grant(_inst, needed, _cfg), 2)
	assert_eq(_inst.level, 3)


func test_leftover_xp_carries_toward_the_next_level() -> void:
	var needed := XpProgression.xp_to_next(1, _cfg)
	XpProgression.grant(_inst, needed + 25, _cfg)
	assert_eq(_inst.level, 2)
	assert_eq(_inst.xp, 25, "the remainder is banked, not rounded away")


func test_levelling_grants_skill_points() -> void:
	# The whole reason XP exists (§4.2). Without this the tree is unreachable content.
	assert_eq(TreeAllocator.unspent_points(_inst), 0)
	XpProgression.grant(_inst, XpProgression.xp_to_next(1, _cfg), _cfg)
	assert_eq(TreeAllocator.unspent_points(_inst), 1)


func test_a_zero_or_negative_award_changes_nothing() -> void:
	XpProgression.grant(_inst, 0, _cfg)
	XpProgression.grant(_inst, -500, _cfg)
	assert_eq(_inst.level, 1)
	assert_eq(_inst.xp, 0)


func test_the_whole_squad_earns_the_full_amount_rather_than_splitting_a_pot() -> void:
	# Splitting would punish fielding four Symbots — exactly the shape the game wants —
	# and make the optimal play a solo carry, the opposite of a squad game.
	var a := SymbotInstanceScript.new(&"a", &"rustcrawler")
	var b := SymbotInstanceScript.new(&"b", &"boltshell")
	XpProgression.grant_squad([a, b], 500, _cfg)
	assert_eq(a.xp + XpProgression.total_xp_to_reach(a.level, _cfg), 500)
	assert_eq(b.xp + XpProgression.total_xp_to_reach(b.level, _cfg), 500)


# ---------------------------------------------------------------------------
# The cap
# ---------------------------------------------------------------------------

func test_levelling_stops_at_the_mark_cap() -> void:
	XpProgression.grant(_inst, 100_000_000, _cfg)
	assert_eq(_inst.level, _inst.level_cap(), "Mk I stops at its cap")


func test_xp_earned_past_the_cap_is_banked_not_burned() -> void:
	# A capped Symbot that has been fighting should not have wasted that time. The moment a
	# Retrofit raises the cap, the banked XP cashes in — discarding it would silently
	# punish playing before upgrading.
	XpProgression.grant(_inst, 100_000_000, _cfg)
	var banked := _inst.xp
	assert_gt(banked, 0, "the overflow is held")

	_inst.mark = 2
	var gained := XpProgression.grant(_inst, 1, _cfg)
	assert_gt(gained, 0, "and cashes in the moment the cap rises")


func test_the_progress_bar_reads_full_at_the_cap() -> void:
	XpProgression.grant(_inst, 100_000_000, _cfg)
	assert_eq(XpProgression.percent_to_next(_inst, _cfg), 100,
		"rather than sitting at an arbitrary fraction forever")


func test_the_progress_bar_tracks_partial_progress() -> void:
	XpProgression.grant(_inst, XpProgression.xp_to_next(1, _cfg) / 2, _cfg)
	var pct := XpProgression.percent_to_next(_inst, _cfg)
	assert_between(pct, 40, 60, "roughly half way")


# ---------------------------------------------------------------------------
# Reaching the player through a real run
# ---------------------------------------------------------------------------

func test_winning_a_stage_levels_the_squad() -> void:
	var game: V1Game = V1GameScript.new()
	add_child_autofree(game)
	var symbot: SymbotInstance = game.ctx.roster.squad_symbots()[0]
	var xp_before := symbot.xp
	var level_before := symbot.level

	game._on_stage_chosen(game.ctx.stages.get_stage(&"stage_01"))
	game._battle._on_auto_toggled(true)

	assert_true(symbot.xp > xp_before or symbot.level > level_before,
		"a won fight must move the squad's XP — otherwise the tree never opens")


func test_a_lost_run_still_pays_for_the_fights_that_were_won() -> void:
	# §6: defeat costs the chest and the time, never the session.
	var result := StageRunnerScript.Result.new()
	result.battles_won = 2
	var game: V1Game = V1GameScript.new()
	add_child_autofree(game)
	var runner := StageRunnerScript.new(game.ctx.stages.get_stage(&"stage_05"),
		game.ctx.species, game.ctx.skills, game.ctx.tree, _cfg, RandomNumberGenerator.new(),
		null, game.ctx.items)

	runner.settle(result, false)

	assert_gt(result.xp_each, 0, "two won rooms still paid XP")
	assert_true(result.chest_items.is_empty(), "but no chest")
