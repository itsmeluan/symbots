## SquadScreen — choosing the four who fight (Core Design §2.1, §3.1).
##
## Squad composition is the strategic layer that replaced build-from-parts in v1, so the
## screen's job is to make a bad composition VISIBLE before the fight rather than after it.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const SquadScreenScript := preload("res://src/ui/squad_screen.gd")
const SpeciesDefScript := preload("res://src/core/species/species_def.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")

var _game: V1Game
var _screen: SquadScreen


func before_each() -> void:
	_game = V1GameScript.new()
	_game.save_backend = MemoryBackend.new()
	add_child_autofree(_game)
	_game.show_squad()
	_screen = _game._squad


func after_each() -> void:
	_game = null
	_screen = null


func _bench_button(index: int) -> Button:
	return _screen._bench.get_child(index)


func _slot_button(index: int) -> Button:
	return _screen._slot_row.get_child(index)


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func test_the_screen_shows_four_slots_and_the_whole_roster() -> void:
	assert_eq(_screen._slot_row.get_child_count(), PlayerRoster.SQUAD_SIZE)
	assert_eq(_screen._bench.get_child_count(), _game.ctx.roster.symbots.size())


func test_every_row_meets_the_touch_minimum() -> void:
	for i in _screen._bench.get_child_count():
		assert_gte(_bench_button(i).custom_minimum_size.y,
			float(SquadScreenScript.MIN_ROW_HEIGHT))


func test_each_symbot_shows_its_role() -> void:
	# A player who cannot see at a glance that they fielded three DPS and no healer will
	# field it.
	var text := ""
	for i in _screen._bench.get_child_count():
		text += _bench_button(i).text
	for role_name in ["DPS", "TANK", "HEAL", "SUPP"]:
		assert_true(text.contains(role_name), "%s missing from the bench" % role_name)


func test_a_fielded_symbot_is_marked_on_the_bench() -> void:
	assert_true(_bench_button(0).text.begins_with("*"),
		"otherwise the player cannot tell who is already in")


func test_an_empty_slot_says_empty() -> void:
	_game.ctx.roster.clear_squad_slot(2)
	_screen.refresh()
	assert_eq(_slot_button(2).text, "empty")


# ---------------------------------------------------------------------------
# Assigning
# ---------------------------------------------------------------------------

func test_arming_a_slot_and_tapping_a_symbot_fields_them() -> void:
	_game.ctx.roster.clear_squad_slot(1)
	_screen.refresh()
	var extra := SymbotInstanceScript.new(&"extra", &"voltfang")
	_game.ctx.roster.add(extra)
	_screen.refresh()

	_screen._on_slot_pressed(1)
	_screen._on_bench_pressed(extra)

	assert_eq(_game.ctx.roster.squad[1], &"extra")
	assert_eq(_screen._armed_slot, -1, "and the slot disarms after use")


func test_tapping_a_symbot_with_no_slot_armed_uses_the_first_empty_one() -> void:
	# Forcing the player to arm a slot for the common case would be a step with no decision
	# in it.
	_game.ctx.roster.clear_squad_slot(0)
	var extra := SymbotInstanceScript.new(&"extra", &"voltfang")
	_game.ctx.roster.add(extra)
	_screen.refresh()

	_screen._on_bench_pressed(extra)

	assert_eq(_game.ctx.roster.squad[0], &"extra")


func test_fielding_someone_already_in_the_squad_moves_them() -> void:
	# The roster moves rather than duplicates — fielding the same unit twice would double
	# its turns.
	var first: StringName = _game.ctx.roster.squad[0]
	_screen._on_slot_pressed(3)
	_screen._on_bench_pressed(_game.ctx.roster.get_symbot(first))

	assert_eq(_game.ctx.roster.squad[3], first)
	assert_eq(_game.ctx.roster.squad[0], &"", "vacated, not duplicated")
	assert_eq(_game.ctx.roster.squad_size(), 3)


func test_tapping_an_armed_slot_again_empties_it() -> void:
	# How a player removes someone, without needing a separate control.
	_screen._on_slot_pressed(0)
	_screen._on_slot_pressed(0)
	assert_eq(_game.ctx.roster.squad[0], &"")
	assert_eq(_screen._armed_slot, -1)


func test_a_full_squad_with_nothing_armed_ignores_a_bench_tap() -> void:
	# Rather than silently displacing someone the player did not choose.
	var extra := SymbotInstanceScript.new(&"extra", &"voltfang")
	_game.ctx.roster.add(extra)
	_screen.refresh()

	_screen._on_bench_pressed(extra)

	assert_false(_game.ctx.roster.squad.has(&"extra"))


# ---------------------------------------------------------------------------
# Composition warnings
# ---------------------------------------------------------------------------

func test_a_starting_squad_raises_no_warning() -> void:
	assert_eq(_screen._warning.text, "", "one of each role is a healthy squad")


func test_a_short_handed_squad_is_flagged() -> void:
	_game.ctx.roster.clear_squad_slot(2)
	_screen.refresh()
	assert_true(_screen._warning.text.contains("short-handed"))


func test_a_squad_with_no_tank_is_flagged() -> void:
	# Without a tank nothing holds the enemy taunt line and the back row takes everything.
	for i in PlayerRoster.SQUAD_SIZE:
		_game.ctx.roster.clear_squad_slot(i)
	for i in PlayerRoster.SQUAD_SIZE:
		var dps := SymbotInstanceScript.new(StringName("d%d" % i), &"rustcrawler")
		_game.ctx.roster.add(dps)
		_game.ctx.roster.set_squad_slot(i, dps.instance_id)
	_screen.refresh()

	assert_true(_screen._warning.text.contains("No tank"))


func test_a_bad_composition_is_warned_about_but_not_blocked() -> void:
	# The design does not forbid four DPS — it just makes them lose. Informing beats
	# forbidding.
	for i in PlayerRoster.SQUAD_SIZE:
		_game.ctx.roster.clear_squad_slot(i)
	for i in PlayerRoster.SQUAD_SIZE:
		var dps := SymbotInstanceScript.new(StringName("d%d" % i), &"rustcrawler")
		_game.ctx.roster.add(dps)
		_game.ctx.roster.set_squad_slot(i, dps.instance_id)
	_screen.refresh()

	assert_eq(_game.ctx.roster.squad_size(), 4, "the squad stands as chosen")


# ---------------------------------------------------------------------------
# Navigation and persistence
# ---------------------------------------------------------------------------

func test_the_squad_screen_is_reachable_from_the_map_and_returns() -> void:
	_game.show_map()
	_game._map._on_squad_pressed()
	assert_not_null(_game._squad)
	_game._squad._on_close_pressed()
	assert_not_null(_game._map)
	assert_null(_game._squad)


func test_leaving_the_squad_screen_saves_the_change() -> void:
	var backend := MemoryBackend.new()
	var game: V1Game = V1GameScript.new()
	game.save_backend = backend
	add_child_autofree(game)
	game.show_squad()
	game._squad._on_slot_pressed(2)
	game._squad._on_slot_pressed(2)  # empty slot 2
	game._squad._on_close_pressed()

	var reopened: V1Game = V1GameScript.new()
	reopened.save_backend = backend
	add_child_autofree(reopened)
	assert_eq(reopened.ctx.roster.squad[2], &"",
		"a squad change is a decision the player expects to stick")
