## V1Game root, stage select and the new-player gift (Core Design §2.1, §6; ADR-0008).
##
## This is the "can you actually open the game and play it" test. Everything below runs the
## real root against the real shipped catalogs — a stubbed context would happily pass while
## the game itself failed to boot.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const StageSelectScreenScript := preload("res://src/ui/stage_select_screen.gd")
const StageDefScript := preload("res://src/core/stages/stage_def.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")

var _game: V1Game



const MemoryBackend := preload("res://tests/support/memory_backend.gd")


## Build a V1Game whose persistence lives in memory. The backend has to be set before
## add_child, because _ready() boots the save service the moment the node enters the tree.
func _make_game(backend = null) -> V1Game:
	var game: V1Game = V1GameScript.new()
	game.save_backend = backend if backend != null else MemoryBackend.new()
	add_child_autofree(game)
	return game

func before_each() -> void:
	_game = _make_game()


func after_each() -> void:
	_game = null


# ---------------------------------------------------------------------------
# Boot
# ---------------------------------------------------------------------------

func test_the_game_boots_with_every_service_wired() -> void:
	# A null here is a screen that renders empty with no error — the worst kind of break.
	assert_not_null(_game.ctx)
	assert_not_null(_game.ctx.roster)
	assert_not_null(_game.ctx.wallet)
	assert_not_null(_game.ctx.progress)
	assert_not_null(_game.ctx.species)
	assert_not_null(_game.ctx.stages)
	assert_not_null(_game.ctx.tree)
	assert_gt(_game.ctx.skills.size(), 0)
	assert_gt(_game.ctx.items.size(), 0)


func test_a_new_player_is_handed_a_full_squad() -> void:
	assert_eq(_game.ctx.roster.symbots.size(), StartingSquad.SPECIES.size())
	assert_eq(_game.ctx.roster.squad_size(), 4, "and all four are fielded")


func test_the_starting_squad_covers_every_role() -> void:
	# The first battle should teach the role system by USING it. A player who starts with
	# four DPS learns that tanks and healers exist only by losing to them.
	var roles: Dictionary = {}
	for s in _game.ctx.roster.squad_symbots():
		roles[_game.ctx.species.get_species(s.species_id).role] = true
	assert_eq(roles.size(), 4, "one of each role")


func test_every_starting_species_is_common() -> void:
	# Handing out a rare on turn one spends the rarity ladder's first rung before the
	# player knows there is a ladder.
	for species_id in StartingSquad.SPECIES:
		var species: SpeciesDef = _game.ctx.species.get_species(species_id)
		assert_not_null(species, "%s must ship" % species_id)
		assert_eq(species.rarity, SpeciesDef.Rarity.COMMON, "%s" % species_id)


func test_the_gift_is_not_re_granted_to_an_existing_player() -> void:
	# Re-granting on every boot would quietly hand an existing player duplicates each
	# time they launched the game.
	var granted_again := StartingSquad.grant(_game.ctx.roster, _game.ctx.species)
	assert_eq(granted_again, 0)
	assert_eq(_game.ctx.roster.symbots.size(), StartingSquad.SPECIES.size())


func test_a_missing_starting_species_is_skipped_rather_than_fielding_a_ghost() -> void:
	var roster := PlayerRoster.new()
	var empty := SpeciesCatalog.new()
	assert_eq(StartingSquad.grant(roster, empty), 0)
	assert_true(roster.is_squad_empty())


# ---------------------------------------------------------------------------
# The map
# ---------------------------------------------------------------------------

func test_home_is_up_after_boot() -> void:
	# Home answers "who are you and who is with you" before the map asks "where do you fight".
	assert_not_null(_game._home)
	assert_null(_game._battle, "and no battle is open")


func test_the_map_is_one_tap_away() -> void:
	_game._navigate_to(&"map")
	assert_not_null(_game._map)
	assert_null(_game._home, "the previous screen steps aside")


func test_the_map_draws_every_stage_including_locked_ones() -> void:
	_game.show_map()
	# A map that only shows what you can play teaches nothing about where you are going.
	assert_eq(_game._map._cards.size(), _game.ctx.stages.entries.size())


func test_the_map_uses_the_authored_continuous_background() -> void:
	_game.show_map()
	await get_tree().process_frame
	var map := _game._map
	assert_not_null(map._map_background)
	assert_eq(map._map_background.texture.resource_path,
		StageSelectScreen.MAP_BACKGROUND_PATH)
	var expected_height := StageSelectScreen.TRACK_PAD * 2.0 \
		+ StageSelectScreen.NODE_SPACING * float(_game.ctx.stages.entries.size() - 1)
	assert_eq(map._track.custom_minimum_size.y, expected_height,
		"the timeline keeps the geometry the 2560px map was authored for")


func test_the_map_background_advances_with_scroll() -> void:
	_game.show_map()
	await get_tree().process_frame
	await get_tree().process_frame
	var map := _game._map
	var bar := map._scroll.get_v_scroll_bar()
	var max_scroll := int(bar.max_value - bar.page)
	assert_gt(max_scroll, 0)

	map._scroll.scroll_vertical = 0
	await get_tree().process_frame
	var top_y: float = map._map_background.position.y

	map._scroll.scroll_vertical = max_scroll
	await get_tree().process_frame
	var bottom_y: float = map._map_background.position.y
	var expected_bottom := -maxf(0.0, map._map_background.size.y - map.size.y)
	assert_lt(bottom_y, top_y - 1000.0,
		"scrolling from summit to scrap flats must visibly advance the authored journey")
	assert_almost_eq(bottom_y, expected_bottom, 2.0,
		"the bottom scroll limit must land on the bottom of map_full.png")


func test_locked_stages_are_shown_but_not_enterable() -> void:
	_game.show_map()
	var enabled := 0
	var disabled := 0
	for card in _game._map._cards:
		if card.disabled:
			disabled += 1
		else:
			enabled += 1
	assert_eq(enabled, 1, "exactly the one open stage on a fresh save")
	assert_gt(disabled, 0, "the rest are visible and locked")


func test_clearing_a_stage_opens_the_next_row_on_the_map() -> void:
	_game.show_map()
	_game.ctx.progress.mark_cleared(&"stage_01")
	_game._map.refresh()
	var enabled := 0
	for card in _game._map._cards:
		if not card.disabled:
			enabled += 1
	assert_eq(enabled, 2, "the cleared stage stays replayable and the next one opens")


func test_a_cleared_stage_stays_replayable() -> void:
	_game.show_map()
	# Replaying for Scrap is the grind the economy assumes (§5.2); locking a stage after
	# one win would remove the loop's floor.
	_game.ctx.progress.mark_cleared(&"stage_01")
	_game._map.refresh()
	# _cards is in STAGE order — index 0 is the first stage, drawn at the BOTTOM of the climb.
	assert_false(_game._map._cards[0].disabled)


func test_the_map_shows_the_wallet_and_follows_it() -> void:
	_game.show_map()
	# The header is shared chrome now (Screen.build_chrome), so the readout lives on the base.
	_game.ctx.wallet.earn(Wallet.SCRAP, 777)
	assert_true(_game._map._chrome_scrap.text.contains("777"),
		"the header renders from the signal, not from a poll")


# ---------------------------------------------------------------------------
# Entering a stage
# ---------------------------------------------------------------------------

func test_choosing_a_stage_opens_the_battle_screen() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	assert_not_null(_game._battle)
	assert_null(_game._map, "the map steps aside")
	assert_not_null(_game._battle.engine, "and a real fight is running")


func test_the_fielded_squad_reaches_the_battle() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	assert_eq(_game._battle.engine.player_units.size(), 4)
	assert_gt(_game._battle.engine.enemy_units.size(), 0)


func test_an_empty_squad_does_not_open_a_fight() -> void:
	for i in PlayerRoster.SQUAD_SIZE:
		_game.ctx.roster.clear_squad_slot(i)
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	assert_null(_game._battle, "an empty squad keeps the map up rather than opening a "
		+ "fight the player cannot act in")


func test_winning_pays_out_once_and_shows_the_reward() -> void:
	# Paying at the RUN level, not per fight: a dungeon that paid its chest once per room
	# would be the best Scrap source in the game.
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	_game._battle._on_auto_toggled(true)

	assert_not_null(_game._reward, "the payoff beat, not straight back to the map")
	assert_null(_game._battle)
	assert_gt(_game.ctx.wallet.scrap, 0, "and paid")


func test_dismissing_the_reward_returns_to_the_map() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	_game._battle._on_auto_toggled(true)
	_game._reward._on_continue_pressed()
	assert_not_null(_game._map)
	assert_null(_game._reward)


func test_a_won_stage_is_marked_cleared() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	_game._battle._on_auto_toggled(true)
	assert_true(_game.ctx.progress.is_cleared(&"stage_01"))


func test_a_dungeon_runs_its_rooms_without_returning_to_the_map() -> void:
	# Precondition: give the squad enough power to survive room one.
	for s in _game.ctx.roster.squad_symbots():
		s.level = 40
		for i in SymbotInstanceScript.PART_COUNT:
			s.part_levels[i] = 20
	var dungeon: StageDef = _game.ctx.stages.get_stage(&"stage_05")
	assert_gt(dungeon.battle_count(), 1, "precondition: stage_05 is multi-room")

	_game._on_stage_chosen(dungeon)
	_game._battle._on_auto_toggled(true)

	assert_gt(_game._result.battles_won, 1,
		"the run continued into room two rather than settling after the first fight")


func test_a_battle_opened_from_the_map_knows_its_stage() -> void:
	# The wiring that actually matters: the stage must reach the screen BEFORE setup() runs,
	# because setup() is where the battlefield art is chosen. Assigning it afterwards would
	# leave every fight on the default background with nothing failing.
	var stage: StageDef = _game.ctx.stages.get_stage(&"stage_01")
	_game._on_stage_chosen(stage)
	assert_not_null(_game._battle)
	assert_eq(_game._battle.stage, stage)


func test_the_sheet_never_says_one_fights() -> void:
	_game.show_map()
	var stage: StageDef = _game.ctx.stages.get_stage(&"stage_01")
	assert_eq(stage.battle_count(), 1, "precondition: stage_01 is a single fight")
	assert_eq(_game._map._fight_count(stage), "1 FIGHT")


func test_the_sheet_fits_every_stage_not_just_one() -> void:
	# The sheet's height is a fixed budget rather than derived from its contents; if the
	# contents outgrow it, DEPLOY is the thing that falls off the bottom.
	#
	# EVERY stage, because `max_lines_visible` caps the description rather than reserving the
	# space — so a one-line stage measures shorter than a two-line one, and a budget checked
	# against a single stage passes while another clips.
	_game.show_map()
	var map := _game._map
	for stage in _game.ctx.stages.entries:
		if stage == null:
			continue
		map._on_stage_pressed(stage)
		assert_lte(map._sheet.get_combined_minimum_size().y, StageSelectScreen.SHEET_HEIGHT,
			"'%s' does not fit the sheet's fixed height" % stage.display_name)


func test_the_map_still_scrolls_with_its_bar_hidden() -> void:
	# Hiding the scrollbar must not be done by DISABLING the axis — that would freeze the
	# track wherever it opened, with fourteen stages unreachable.
	_game.show_map()
	var scroll: ScrollContainer = _game._map._scroll
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	assert_ne(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
