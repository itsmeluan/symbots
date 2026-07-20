## Saving to disk, end to end (ADR-0001; Core Design §2, §5).
##
## The provider was already tested in isolation. What is pinned here is the WIRING — that
## the game actually calls it, at the moments a player would be upset to redo, and that a
## reopened game finds what it left. A provider nobody invokes passes every one of its own
## tests while the player loses their progress.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const V1StateProviderScript := preload("res://src/persistence/v1_state_provider.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")
const SpyLogSink := preload("res://tests/unit/part_database/spy_log_sink.gd")

var _backend
var _game: V1Game


## Build a game whose save service writes into [param backend] rather than to disk.
## The backend is set before add_child so the real boot path — load-or-grant included —
## runs against memory.
func _new_game(backend, log: LogSink = null) -> V1Game:
	var game: V1Game = V1GameScript.new()
	game.save_backend = backend
	game.log_override = log
	add_child_autofree(game)
	return game


func before_each() -> void:
	_backend = MemoryBackend.new()
	_game = _new_game(_backend)


func after_each() -> void:
	_game = null


func _first() -> SymbotInstance:
	return _game.ctx.roster.symbots[0]


# ---------------------------------------------------------------------------
# The provider is actually registered
# ---------------------------------------------------------------------------

func test_the_v1_provider_is_registered_with_the_save_service() -> void:
	# A provider nobody registers passes all its own tests while the player loses progress.
	assert_true(_game.save_service.has_provider(V1StateProviderScript.KEY))


func test_a_fresh_launch_with_no_save_grants_the_starting_squad() -> void:
	assert_eq(_game.ctx.roster.symbots.size(), StartingSquad.SPECIES.size())


func test_saving_writes_something_to_the_backend() -> void:
	_game.save_now()
	assert_gt(_backend.files.size(), 0)


# ---------------------------------------------------------------------------
# Round trip through a simulated relaunch
# ---------------------------------------------------------------------------

func test_a_reopened_game_finds_what_it_left() -> void:
	_first().level = 22
	_first().part_levels[2] = 11
	_game.ctx.wallet.earn(Wallet.SCRAP, 4321)
	_game.ctx.progress.mark_cleared(&"stage_01")
	_game.save_now()

	# Close and reopen against the same storage.
	var reopened := _new_game(_backend)

	assert_eq(reopened.ctx.roster.symbots.size(), StartingSquad.SPECIES.size())
	assert_eq(reopened.ctx.roster.symbots[0].level, 22)
	assert_eq(reopened.ctx.roster.symbots[0].get_part_level(2), 11)
	assert_eq(reopened.ctx.wallet.scrap, 4321)


func test_reopening_does_not_hand_out_a_second_starting_squad() -> void:
	# The gift is gated on the LOAD finding nothing, not on the roster being empty. Gating
	# on emptiness would re-gift to anyone who had scrapped everything.
	_game.save_now()
	var reopened := _new_game(_backend)
	assert_eq(reopened.ctx.roster.symbots.size(), StartingSquad.SPECIES.size(),
		"not double")


func test_allocated_tree_nodes_survive_a_relaunch() -> void:
	var species: SpeciesDef = _game.ctx.species.get_species(_first().species_id)
	_first().level = 10
	var step := TreeAllocator.frontier(_game.ctx.tree, _first(), species)[0]
	TreeAllocator.allocate(_game.ctx.tree, _first(), species, step)
	_game.save_now()

	var reopened := _new_game(_backend)

	assert_true(reopened.ctx.roster.symbots[0].allocated_nodes.has(step),
		"a build the player spent points on must not evaporate")


func test_the_fielded_squad_survives_a_relaunch() -> void:
	_game.ctx.roster.clear_squad_slot(2)
	_game.save_now()
	var reopened := _new_game(_backend)
	assert_eq(reopened.ctx.roster.squad[2], &"",
		"a deliberately empty slot is a choice, not a bug to repair on load")


# ---------------------------------------------------------------------------
# Saving happens at the moments that matter
# ---------------------------------------------------------------------------

func test_finishing_a_run_saves() -> void:
	# The single most painful thing to redo.
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	_game._battle._on_auto_toggled(true)

	var reopened := _new_game(_backend)
	assert_gt(reopened.ctx.wallet.scrap, 0, "the payout survived")


func test_leaving_the_workshop_saves() -> void:
	# Walking away from a session of spending decisions is a natural commit point.
	_game.ctx.wallet.earn(Wallet.SCRAP, 50000)
	_game.show_workshop()
	_game._workshop._on_upgrade_pressed(0)
	var level_after := _first().get_part_level(0)
	_game._workshop._on_close_pressed()

	var reopened := _new_game(_backend)
	assert_eq(reopened.ctx.roster.symbots[0].get_part_level(0), level_after)


func test_leaving_the_skill_tree_saves() -> void:
	_first().level = 10
	_game.show_tree()
	var species: SpeciesDef = _game.ctx.species.get_species(_first().species_id)
	var step := TreeAllocator.frontier(_game.ctx.tree, _first(), species)[0]
	_game._tree_screen._on_node_tapped(step)
	_game._tree_screen._on_allocate_pressed()
	_game._tree_screen._on_close_pressed()

	var reopened := _new_game(_backend)
	assert_true(reopened.ctx.roster.symbots[0].allocated_nodes.has(step))


func test_the_app_being_backgrounded_saves() -> void:
	# On a phone, being backgrounded is a real close. Losing a run to a phone call is not
	# acceptable (ADR-0001 save_emergency path).
	_game.ctx.wallet.earn(Wallet.SCRAP, 999)
	_game._notification(NOTIFICATION_APPLICATION_PAUSED)

	var reopened := _new_game(_backend)
	assert_eq(reopened.ctx.wallet.scrap, 999)


# ---------------------------------------------------------------------------
# Failure modes
# ---------------------------------------------------------------------------

func test_a_corrupt_save_starts_a_new_game_rather_than_crashing() -> void:
	_game.save_now()
	for path in _backend.files.keys():
		_backend.files[path] = "{ this is not json"

	# A spy sink, so the service's (correct) corruption report does not reach push_error and
	# get counted as an unexpected error by the runner.
	var spy := SpyLogSink.new()
	var reopened := _new_game(_backend, spy)

	assert_eq(reopened.ctx.roster.symbots.size(), StartingSquad.SPECIES.size(),
		"a broken file costs the save, not the ability to play")
	assert_gt(spy.errors.size(), 0, "and the corruption is reported rather than swallowed")


func test_the_save_stays_well_inside_the_size_budget() -> void:
	# ADR-0001 caps a save at 2 MiB. A full roster nowhere near it means there is room for
	# the roster to grow without the budget becoming a design constraint.
	for i in 20:
		var extra := SymbotInstanceScript.new(StringName("extra_%d" % i), &"rustcrawler")
		extra.level = 60
		_game.ctx.roster.add(extra)
	_game.save_now()

	var biggest := 0
	for path in _backend.files:
		biggest = maxi(biggest, String(_backend.files[path]).to_utf8_buffer().size())
	assert_lt(biggest, SaveLoadService.MAX_SAVE_BYTES / 4,
		"24 Symbots should not approach the cap (%d bytes)" % biggest)
