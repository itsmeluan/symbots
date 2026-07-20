## Offline expeditions (Core Design §7).
##
## The clock is injected throughout, so every timing rule is tested rather than waited for.
## Time bugs — a negative elapsed span from a restored save, an early collect that pays —
## are exactly the ones that cannot be left to manual checking.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")

var _game: V1Game
var _board: ExpeditionBoard
var _cfg: BalanceConfig
var _rng: RandomNumberGenerator

## The fake clock. Tests move it directly instead of sleeping.
var _now: int = 1_000_000


func _clock() -> int:
	return _now


func before_each() -> void:
	_game = V1GameScript.new()
	_game.save_backend = MemoryBackend.new()
	add_child_autofree(_game)
	_board = _game.ctx.expeditions
	_board.clock = Callable(self, "_clock")
	_cfg = _game.ctx.balance
	_rng = RandomNumberGenerator.new()
	_rng.seed = 7
	_now = 1_000_000


func after_each() -> void:
	_game = null
	_board = null


## A Symbot the player owns but is NOT fielding — the bench is who expeditions are for.
func _benched() -> SymbotInstance:
	var extra := SymbotInstanceScript.new(&"bench", &"voltfang")
	extra.level = 20
	_game.ctx.roster.add(extra)
	return extra


func _advance(seconds: int) -> void:
	_now += seconds


# ---------------------------------------------------------------------------
# Sending
# ---------------------------------------------------------------------------

func test_the_board_starts_with_the_designed_slot_count() -> void:
	assert_eq(_board.slots, ExpeditionBoard.STARTING_SLOTS)
	assert_eq(_board.free_slots(), ExpeditionBoard.STARTING_SLOTS)


func test_a_benched_symbot_can_be_sent() -> void:
	var bench := _benched()
	assert_true(_board.send(bench.instance_id, ExpeditionBoard.Duration.SHORT,
		_game.ctx.roster))
	assert_eq(_board.free_slots(), ExpeditionBoard.STARTING_SLOTS - 1)


func test_a_fielded_symbot_cannot_be_sent() -> void:
	# A Symbot cannot be away AND in the squad, or the player fields a unit that is
	# supposed to be gone.
	var fielded: StringName = _game.ctx.roster.squad[0]
	assert_false(_board.send(fielded, ExpeditionBoard.Duration.SHORT, _game.ctx.roster))


func test_a_symbot_cannot_be_sent_twice() -> void:
	var bench := _benched()
	_board.send(bench.instance_id, ExpeditionBoard.Duration.SHORT, _game.ctx.roster)
	assert_false(_board.send(bench.instance_id, ExpeditionBoard.Duration.LONG,
		_game.ctx.roster))


func test_an_unowned_symbot_cannot_be_sent() -> void:
	assert_false(_board.send(&"ghost", ExpeditionBoard.Duration.SHORT, _game.ctx.roster))


func test_slots_are_finite() -> void:
	for i in ExpeditionBoard.STARTING_SLOTS:
		var s := SymbotInstanceScript.new(StringName("b%d" % i), &"voltfang")
		_game.ctx.roster.add(s)
		assert_true(_board.send(s.instance_id, ExpeditionBoard.Duration.SHORT,
			_game.ctx.roster))
	var overflow := SymbotInstanceScript.new(&"overflow", &"voltfang")
	_game.ctx.roster.add(overflow)
	assert_false(_board.send(overflow.instance_id, ExpeditionBoard.Duration.SHORT,
		_game.ctx.roster))


# ---------------------------------------------------------------------------
# Time
# ---------------------------------------------------------------------------

func test_an_expedition_is_not_ready_before_its_duration() -> void:
	var bench := _benched()
	_board.send(bench.instance_id, ExpeditionBoard.Duration.SHORT, _game.ctx.roster)
	_advance(ExpeditionBoard.DURATION_SECONDS[ExpeditionBoard.Duration.SHORT] - 1)
	assert_false(_board.is_ready(0))
	assert_eq(_board.seconds_remaining(0), 1)


func test_an_expedition_is_ready_the_moment_its_duration_elapses() -> void:
	var bench := _benched()
	_board.send(bench.instance_id, ExpeditionBoard.Duration.SHORT, _game.ctx.roster)
	_advance(ExpeditionBoard.DURATION_SECONDS[ExpeditionBoard.Duration.SHORT])
	assert_true(_board.is_ready(0))
	assert_eq(_board.seconds_remaining(0), 0)


func test_collecting_early_pays_nothing_and_keeps_the_slot() -> void:
	# An early collect that paid anything would make the timer decorative.
	var bench := _benched()
	_board.send(bench.instance_id, ExpeditionBoard.Duration.LONG, _game.ctx.roster)
	assert_eq(_board.collect(0, _cfg, _game.ctx.roster, _rng), {})
	assert_eq(_board.free_slots(), ExpeditionBoard.STARTING_SLOTS - 1, "still out")


func test_a_clock_that_went_backwards_does_not_produce_a_wild_timer() -> void:
	# A save restored on a machine whose clock is behind the one that wrote it. Treated as
	# "just started" rather than a nonsensically huge remaining time.
	var bench := _benched()
	_board.send(bench.instance_id, ExpeditionBoard.Duration.SHORT, _game.ctx.roster)
	_now -= 100_000
	assert_lte(_board.seconds_remaining(0),
		ExpeditionBoard.DURATION_SECONDS[ExpeditionBoard.Duration.SHORT])


func test_a_longer_expedition_takes_longer() -> void:
	assert_gt(ExpeditionBoard.DURATION_SECONDS[ExpeditionBoard.Duration.LONG],
		ExpeditionBoard.DURATION_SECONDS[ExpeditionBoard.Duration.SHORT])


# ---------------------------------------------------------------------------
# Payout
# ---------------------------------------------------------------------------

func _collect(duration: int, level: int = 20) -> Dictionary:
	var bench := _benched()
	bench.level = level
	_board.send(bench.instance_id, duration, _game.ctx.roster)
	_advance(ExpeditionBoard.DURATION_SECONDS[duration])
	return _board.collect(0, _cfg, _game.ctx.roster, _rng)


func test_collecting_pays_scrap_and_frees_the_slot() -> void:
	var payout := _collect(ExpeditionBoard.Duration.SHORT)
	assert_gt(int(payout.get("scrap", 0)), 0)
	assert_eq(_board.free_slots(), ExpeditionBoard.STARTING_SLOTS)


func test_the_overnight_run_beats_eight_hourly_ones() -> void:
	# Superlinear on purpose. The opposite shape would punish players who cannot check in
	# often — the exact group offline rewards exist for.
	var ratio := float(ExpeditionBoard.DURATION_YIELD[ExpeditionBoard.Duration.LONG]) \
		/ float(ExpeditionBoard.DURATION_YIELD[ExpeditionBoard.Duration.SHORT])
	var hours := float(ExpeditionBoard.DURATION_SECONDS[ExpeditionBoard.Duration.LONG]) \
		/ float(ExpeditionBoard.DURATION_SECONDS[ExpeditionBoard.Duration.SHORT])
	assert_gt(ratio, hours, "8h yield %fx for %fx the time" % [ratio, hours])


func test_a_higher_level_symbot_earns_more() -> void:
	# A bench that pays level-1 rates forever is a bench nobody uses twice.
	var low := _collect(ExpeditionBoard.Duration.SHORT, 1)
	_board.active.clear()
	_game.ctx.roster.release(&"bench")
	var high := _collect(ExpeditionBoard.Duration.SHORT, 50)
	assert_gt(int(high["scrap"]), int(low["scrap"]))


func test_the_payout_names_who_came_back() -> void:
	# The screen has to say which Symbot is free again.
	var payout := _collect(ExpeditionBoard.Duration.SHORT)
	assert_eq(payout.get("symbot_id"), &"bench")


func test_expeditions_never_return_top_tier_hardware() -> void:
	# The bench should supplement the player's kit, never out-earn actually playing a stage.
	for item_id in _cfg.expedition_item_pool:
		var item: InstallItemDef = _game.ctx.item_catalog.get_item(item_id)
		assert_not_null(item, "%s must ship" % item_id)
		assert_lte(int(item.tier), int(InstallItemDef.Tier.T2), "%s is too good" % item_id)


# ---------------------------------------------------------------------------
# Recall
# ---------------------------------------------------------------------------

func test_recalling_early_pays_nothing_but_frees_the_slot() -> void:
	# The cost of changing your mind — otherwise a player parks the bench on 8h runs and
	# yanks them back the moment a stage needs a fifth body.
	var bench := _benched()
	_board.send(bench.instance_id, ExpeditionBoard.Duration.LONG, _game.ctx.roster)
	var scrap_before := _game.ctx.wallet.scrap

	assert_true(_board.cancel(0))

	assert_eq(_board.free_slots(), ExpeditionBoard.STARTING_SLOTS)
	assert_eq(_game.ctx.wallet.scrap, scrap_before)
	assert_false(_board.is_busy(bench.instance_id))


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func test_an_expedition_in_progress_survives_a_relaunch() -> void:
	var backend := MemoryBackend.new()
	var game: V1Game = V1GameScript.new()
	game.save_backend = backend
	add_child_autofree(game)
	var bench := SymbotInstanceScript.new(&"bench", &"voltfang")
	game.ctx.roster.add(bench)
	game.ctx.expeditions.send(&"bench", ExpeditionBoard.Duration.LONG, game.ctx.roster)
	game.save_now()

	var reopened: V1Game = V1GameScript.new()
	reopened.save_backend = backend
	add_child_autofree(reopened)

	assert_eq(reopened.ctx.expeditions.active.size(), 1,
		"closing the app must not cancel an 8h run")
	assert_true(reopened.ctx.expeditions.is_busy(&"bench"))


func test_an_expedition_naming_a_lost_symbot_is_dropped() -> void:
	# It could never be collected, and would hold a slot forever with no way to clear it.
	var board := ExpeditionBoard.from_dict(
		{"slots": 2, "active": [{"symbot_id": "gone", "duration": 1, "started_at": 0}]},
		_game.ctx.roster)
	assert_eq(board.active.size(), 0)


func test_stage_progress_survives_a_relaunch() -> void:
	# Found while wiring expeditions: cleared stages were NOT being persisted at all, so
	# every relaunch re-locked the whole map back to stage one.
	var backend := MemoryBackend.new()
	var game: V1Game = V1GameScript.new()
	game.save_backend = backend
	add_child_autofree(game)
	game.ctx.progress.mark_cleared(&"stage_01")
	game.ctx.progress.mark_cleared(&"stage_02")
	game.save_now()

	var reopened: V1Game = V1GameScript.new()
	reopened.save_backend = backend
	add_child_autofree(reopened)

	assert_true(reopened.ctx.progress.is_cleared(&"stage_01"))
	assert_true(reopened.ctx.progress.is_cleared(&"stage_02"))
	assert_eq(reopened.ctx.progress.available_stages(reopened.ctx.stages).size(), 3,
		"and the map is still open where the player left it")
