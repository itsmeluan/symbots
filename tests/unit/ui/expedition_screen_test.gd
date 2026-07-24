## ExpeditionScreen — sending the bench on offline runs (Core Design §7).
##
## The board is already tested in isolation with an injected clock; these tests pin the
## SCREEN — that it fields only benched Symbots, shows live countdowns, collects a finished
## run into the wallet, and warns that a recall pays nothing. A fake clock drives time so
## nothing here waits an hour.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const ExpeditionScreenScript := preload("res://src/ui/expedition_screen.gd")
const ExpeditionBoardScript := preload("res://src/core/expeditions/expedition_board.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")

var _game: V1Game
var _screen: ExpeditionScreen
var _now: int = 1_000_000


func _clock() -> int:
	return _now


func before_each() -> void:
	_game = V1GameScript.new()
	_game.save_backend = MemoryBackend.new()
	add_child_autofree(_game)
	_game.ctx.expeditions.clock = Callable(self, "_clock")
	_now = 1_000_000
	_game.show_expeditions()
	_screen = _game._expeditions


func after_each() -> void:
	_game = null
	_screen = null


## Add an owned-but-not-fielded Symbot — the only kind an expedition accepts.
func _bench_one(id := "bench") -> SymbotInstance:
	var s := SymbotInstanceScript.new(StringName(id), &"voltfang")
	s.level = 20
	_game.ctx.roster.add(s)
	_screen.refresh()
	return s


func _bench_send_buttons() -> Array:
	var out: Array = []
	for row in _screen._bench_box.get_children():
		_collect_buttons(row, out)
	return out


func _collect_buttons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Button:
			out.append(c)
		_collect_buttons(c, out)


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func test_the_screen_shows_a_row_per_slot() -> void:
	assert_eq(_screen._slots_box.get_child_count(), _game.ctx.expeditions.slots)


func test_a_fresh_player_has_an_empty_bench_and_is_told_why() -> void:
	# All four starting Symbots are in the squad, so nobody is benched.
	assert_eq(_screen._bench_box.get_child_count(), 0)
	assert_true(_screen._bench_hint.text.contains("No benched"))


func test_a_squad_member_is_not_offered_for_expedition() -> void:
	# A Symbot cannot fight and be away at once.
	var fielded: StringName = _game.ctx.roster.squad[0]
	var offered := false
	for s in _screen._benched():
		if s.instance_id == fielded:
			offered = true
	assert_false(offered)


# ---------------------------------------------------------------------------
# Sending
# ---------------------------------------------------------------------------

func test_sending_a_benched_symbot_fills_a_slot() -> void:
	var s := _bench_one()
	_screen._on_send_pressed(s.instance_id)
	assert_eq(_game.ctx.expeditions.free_slots(),
		ExpeditionBoardScript.STARTING_SLOTS - 1)
	assert_true(_game.ctx.expeditions.is_busy(s.instance_id))


func test_a_sent_symbot_leaves_the_bench() -> void:
	var s := _bench_one()
	_screen._on_send_pressed(s.instance_id)
	assert_eq(_screen._benched().size(), 0, "it is out, so no longer benched")


func test_the_selected_duration_is_the_one_dispatched() -> void:
	var s := _bench_one()
	_screen._on_duration_pressed(ExpeditionBoardScript.Duration.LONG)
	_screen._on_send_pressed(s.instance_id)
	assert_eq(int(_game.ctx.expeditions.active[0]["duration"]),
		ExpeditionBoardScript.Duration.LONG)


func test_the_bench_send_is_disabled_when_all_slots_are_full() -> void:
	# Fill both slots, bench a third, and its Send must be dead rather than silently failing.
	for i in ExpeditionBoardScript.STARTING_SLOTS:
		var s := _bench_one("filler_%d" % i)
		_screen._on_send_pressed(s.instance_id)
	_bench_one("overflow")
	var disabled := 0
	for b in _bench_send_buttons():
		if b.disabled:
			disabled += 1
	assert_gt(disabled, 0, "a full board must not offer a live Send")


# ---------------------------------------------------------------------------
# Countdown and collect
# ---------------------------------------------------------------------------

func test_a_running_slot_shows_a_countdown_then_ready() -> void:
	var s := _bench_one()
	_screen._on_send_pressed(s.instance_id)
	var running_text := _slot_text(0)
	assert_false(running_text.contains("READY"), "still counting down")

	_now += ExpeditionBoardScript.DURATION_SECONDS[ExpeditionBoardScript.Duration.SHORT]
	_screen._on_tick()
	assert_true(_slot_text(0).contains("READY"), "reads READY once the time elapses")


func test_collecting_a_finished_run_pays_into_the_wallet_and_frees_the_slot() -> void:
	var s := _bench_one()
	_screen._on_send_pressed(s.instance_id)
	_now += ExpeditionBoardScript.DURATION_SECONDS[ExpeditionBoardScript.Duration.SHORT]
	var scrap_before := _game.ctx.wallet.scrap

	_screen._on_collect_pressed(0)

	assert_gt(_game.ctx.wallet.scrap, scrap_before, "the screen applies the payout")
	assert_eq(_game.ctx.expeditions.free_slots(), ExpeditionBoardScript.STARTING_SLOTS)


func test_collecting_returns_the_symbot_to_the_bench() -> void:
	var s := _bench_one()
	_screen._on_send_pressed(s.instance_id)
	_now += ExpeditionBoardScript.DURATION_SECONDS[ExpeditionBoardScript.Duration.SHORT]
	_screen._on_collect_pressed(0)
	assert_false(_game.ctx.expeditions.is_busy(s.instance_id))
	assert_eq(_screen._benched().size(), 1, "free again, back on the bench")


func test_recalling_early_pays_nothing_but_frees_the_slot() -> void:
	var s := _bench_one()
	_screen._on_duration_pressed(ExpeditionBoardScript.Duration.LONG)
	_screen._on_send_pressed(s.instance_id)
	var scrap_before := _game.ctx.wallet.scrap

	_screen._on_recall_pressed(0)

	assert_eq(_game.ctx.wallet.scrap, scrap_before, "recall is the cost of changing your mind")
	assert_eq(_game.ctx.expeditions.free_slots(), ExpeditionBoardScript.STARTING_SLOTS)


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func test_the_screen_is_reachable_from_the_map_and_returns() -> void:
	_game.show_map()
	_game._map._on_expeditions_pressed()
	assert_not_null(_game._expeditions)
	_game._expeditions._on_close_pressed()
	assert_not_null(_game._map)
	assert_null(_game._expeditions)


func _slot_text(index: int) -> String:
	return _all_text(_screen._slots_box.get_child(index))


## Every Label and Button caption under a node — the slot's text however it is nested now
## that a slot is a framed card, not a flat row.
func _all_text(node: Node) -> String:
	var out := ""
	for c in node.get_children():
		if c is Label:
			out += c.text
		elif c is Button:
			out += c.text
		out += _all_text(c)
	return out
