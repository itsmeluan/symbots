## WorkshopScreenV1 — the Scrap sink (Core Design §2.3, §2.4, §5).
##
## The screen where "spread or concentrate" (§5.2) actually happens. What is pinned here is
## that it never quotes one price and charges another, that it says WHY a button is dead,
## and that Retrofit appears exactly when it is earned.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const WorkshopScreenScript := preload("res://src/ui/workshop/workshop_screen_v1.gd")
const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const UpgradeEconomyScript := preload("res://src/core/economy/upgrade_economy.gd")

var _game: V1Game
var _shop: WorkshopScreenV1



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
	_game.show_workshop()
	_shop = _game._workshop


func after_each() -> void:
	_game = null
	_shop = null


func _selected() -> SymbotInstance:
	return _shop._selected


func _upgrade_buttons() -> Array:
	# The upgrade button now sits inside a sub-column of each part row, so search the whole
	# row subtree rather than just its direct children.
	var out: Array = []
	for row in _shop._part_list.get_children():
		_collect_buttons(row, out)
	return out


func _collect_buttons(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		else:
			_collect_buttons(child, out)


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func test_the_workshop_opens_on_a_fielded_symbot() -> void:
	assert_not_null(_selected(), "landing on an empty screen makes the player hunt")


func test_the_carousel_lists_everything_owned() -> void:
	assert_eq(_shop._carousel.item_count(), _game.ctx.roster.symbots.size())


func test_all_five_parts_are_shown() -> void:
	assert_eq(_shop._part_list.get_child_count(), SymbotInstanceScript.PART_COUNT)


func test_every_control_meets_the_touch_minimum() -> void:
	for row in _shop._part_list.get_children():
		assert_gte(row.custom_minimum_size.y, float(WorkshopScreenScript.MIN_ROW_HEIGHT))


func test_selecting_another_symbot_redraws_its_parts() -> void:
	var first := _selected()
	var second: SymbotInstance = _game.ctx.roster.symbots[1]
	_shop._on_symbot_selected(second)
	assert_eq(_selected(), second)
	assert_ne(_selected(), first)


# ---------------------------------------------------------------------------
# Prices
# ---------------------------------------------------------------------------

func test_the_button_quotes_the_price_the_economy_charges() -> void:
	# A view that re-derived the price could quote one number and charge another — the
	# single worst bug an upgrade screen can have.
	_game.ctx.wallet.earn(Wallet.SCRAP, 10000)
	_shop.refresh()
	var expected := UpgradeEconomyScript.level_cost(
		_selected().get_part_level(0), _game.ctx.balance)
	assert_true(_upgrade_buttons()[0].text.contains(str(expected)),
		"button reads '%s', economy says %d" % [_upgrade_buttons()[0].text, expected])


func test_upgrading_charges_exactly_what_was_quoted() -> void:
	_game.ctx.wallet.earn(Wallet.SCRAP, 10000)
	_shop.refresh()
	var quoted := UpgradeEconomyScript.level_cost(
		_selected().get_part_level(0), _game.ctx.balance)

	_shop._on_upgrade_pressed(0)

	assert_eq(_game.ctx.wallet.scrap, 10000 - quoted)
	assert_eq(_selected().get_part_level(0), 2)


func test_an_unaffordable_part_cannot_be_pressed() -> void:
	# The wallet starts empty on a fresh save.
	for button in _upgrade_buttons():
		assert_true(button.disabled, "nothing is affordable with 0 Scrap")


func test_earning_scrap_enables_the_buttons_without_a_manual_redraw() -> void:
	_game.ctx.wallet.earn(Wallet.SCRAP, 10000)
	_shop.refresh()
	var enabled := 0
	for button in _upgrade_buttons():
		if not button.disabled:
			enabled += 1
	assert_eq(enabled, SymbotInstanceScript.PART_COUNT)


# ---------------------------------------------------------------------------
# Evolved Symbots must LOOK evolved
# ---------------------------------------------------------------------------

func test_a_later_mark_gets_a_bigger_hero_sprite() -> void:
	# The sprite is fitted to a band, so a fixed band would flatten every mark to one size.
	# The art cannot carry the progression either — Coilsprite's Mk I canvas (317x323) is
	# larger than its Mk III (209x209) — so the screen guarantees it from the mark.
	_selected().mark = 1
	_shop.refresh()
	var band_1 := absf(_shop._hero.offset_top)
	_selected().mark = 2
	_shop.refresh()
	var band_2 := absf(_shop._hero.offset_top)
	_selected().mark = 3
	_shop.refresh()
	var band_3 := absf(_shop._hero.offset_top)

	assert_gt(band_2, band_1, "Mk II looms larger than Mk I")
	assert_gt(band_3, band_2, "and Mk III larger still")


func test_genning_up_updates_the_carousel_sprite() -> void:
	# The strip was built once at setup, so it kept showing the old form until the player
	# left the screen and came back.
	_max_every_part()
	_shop.refresh()
	var index := _shop._index_of(_selected())
	var before: Texture2D = _shop._carousel._textures[index]

	_shop._on_gen_up_pressed()

	assert_eq(_selected().mark, 2, "precondition: it genned up")
	assert_ne(_shop._carousel._textures[index], before,
		"the carousel shows the new mark without leaving the screen")


# ---------------------------------------------------------------------------
# Hold-to-repeat on the Upgrade pill
# ---------------------------------------------------------------------------

func test_holding_the_upgrade_button_keeps_levelling() -> void:
	_game.ctx.wallet.earn(Wallet.SCRAP, 1_000_000)
	_shop.refresh()

	_shop._on_upgrade_hold_start(0)
	var after_press := _selected().get_part_level(0)
	_shop._on_repeat_tick()
	_shop._on_repeat_tick()

	assert_eq(_selected().get_part_level(0), after_press + 2, "each tick adds one level")


func test_holding_arms_the_repeat_only_while_there_is_more_to_buy() -> void:
	_game.ctx.wallet.earn(Wallet.SCRAP, 1_000_000)
	_shop.refresh()
	_shop._on_upgrade_hold_start(0)
	assert_eq(_shop._repeat_slot, 0, "armed while levels remain")


func test_a_press_with_exactly_one_level_of_scrap_does_not_arm_the_repeat() -> void:
	# The press spends the lot; there is nothing left to repeat, so the timer must stay down.
	var cost := UpgradeEconomyScript.level_cost(_selected().get_part_level(0), _game.ctx.balance)
	_game.ctx.wallet.earn(Wallet.SCRAP, cost)
	_shop.refresh()

	_shop._on_upgrade_hold_start(0)

	assert_eq(_game.ctx.wallet.scrap, 0)
	assert_eq(_shop._repeat_slot, -1, "nothing left to repeat")


func test_the_repeat_stops_rather_than_overspending() -> void:
	# The safety property: a finger left on the button can never charge Scrap that is not there.
	_game.ctx.wallet.earn(Wallet.SCRAP, 1_000_000)
	_shop.refresh()
	_shop._on_upgrade_hold_start(0)
	_game.ctx.wallet.spend(Wallet.SCRAP, _game.ctx.wallet.scrap)  # drain mid-hold
	var level_before := _selected().get_part_level(0)

	_shop._on_repeat_tick()

	assert_eq(_selected().get_part_level(0), level_before, "no level bought on an empty wallet")
	assert_eq(_game.ctx.wallet.scrap, 0)
	assert_eq(_shop._repeat_slot, -1, "and the repeat disarms itself")


func test_a_capped_part_says_capped_rather_than_going_quietly_grey() -> void:
	# "Capped" and "cannot afford" send the player to different places — one means go
	# retrofit, the other means go fight.
	_game.ctx.wallet.earn(Wallet.SCRAP, 10_000_000)
	var cap := _selected().part_level_cap()
	for i in range(1, cap):
		UpgradeEconomyScript.upgrade(_selected(), 0, _game.ctx.wallet, _game.ctx.balance)
	_shop.refresh()
	assert_eq(_upgrade_buttons()[0].text, "Capped")


# ---------------------------------------------------------------------------
# Retrofit (§2.3)
# ---------------------------------------------------------------------------

func _max_every_part() -> void:
	_game.ctx.wallet.earn(Wallet.SCRAP, 100_000_000)
	var cap := _selected().part_level_cap()
	for slot in SymbotInstanceScript.PART_COUNT:
		for i in range(1, cap):
			UpgradeEconomyScript.upgrade(_selected(), slot, _game.ctx.wallet, _game.ctx.balance)


func test_gen_up_is_unavailable_until_every_part_is_capped() -> void:
	assert_false(_shop._can_gen_up())
	assert_true(_shop._gen_requirement_text().contains("all five parts"),
		"and tapping it explains the requirement")


func test_gen_up_unlocks_once_every_part_is_capped() -> void:
	_max_every_part()
	_shop.refresh()
	assert_true(_shop._can_gen_up())


func test_genning_up_raises_the_cap_without_resetting_levels() -> void:
	# §2.3: progression is always forward. Resetting part levels would make the reward for
	# maxing five parts feel like a punishment.
	_max_every_part()
	var cap_before := _selected().part_level_cap()
	_shop.refresh()

	_shop._on_gen_up_pressed()

	assert_eq(_selected().mark, 2)
	assert_gt(_selected().part_level_cap(), cap_before)
	assert_eq(_selected().get_part_level(0), cap_before, "levels survive the gen-up")


func test_a_final_generation_symbot_says_so() -> void:
	_selected().mark = SymbotInstanceScript.MAX_MARK
	_shop.refresh()
	assert_false(_shop._can_gen_up())
	assert_true(_shop._gen_requirement_text().contains("Mk III"))
	# The arrow would promise a generation that does not exist.
	assert_eq(_shop._gen_button.text, "MAX", "the button reads MAX at the final mark")


func test_the_gen_button_offers_the_next_generation_below_the_cap() -> void:
	_selected().mark = 1
	_shop.refresh()
	assert_eq(_shop._gen_button.text, "GEN ▲")


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func test_the_workshop_is_reachable_from_the_map_and_returns_to_it() -> void:
	# Reachable from where the player lands after every fight — an upgrade screen buried a
	# level deeper is one they forget exists.
	_game.show_map()
	_game._map._on_workshop_pressed()
	assert_not_null(_game._workshop)
	assert_null(_game._map)

	_game._workshop._on_close_pressed()
	assert_not_null(_game._map)
	assert_null(_game._workshop)
