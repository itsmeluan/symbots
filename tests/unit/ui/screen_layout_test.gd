## Every screen actually occupies the viewport (ADR-0008).
##
## This file exists because 1301 tests passed while the game was visibly broken. They all
## checked logical state — is the button disabled, is the node allocated — and none checked
## SIZE. The V1Game root was a plain Node, so every Screen parented to it never resolved
## its anchors and measured 0x0: fixed-size widgets still drew, while everything with
## EXPAND_FILL (the stage list, the tree graph, the battlefield) silently got no space and
## vanished. The game rendered as a strip in the corner.
##
## The rule these tests encode: a screen that is added to the tree must fill the viewport,
## and its expanding region must actually have room. Assertions are on non-zero and
## in-bounds rather than exact pixels, so a layout tweak does not break them but a
## collapsed layout does.
extends GutTest

const V1GameScript := preload("res://src/scenes/v1/v1_game.gd")
const MemoryBackend := preload("res://tests/support/memory_backend.gd")

var _game: V1Game


func before_each() -> void:
	_game = V1GameScript.new()
	_game.save_backend = MemoryBackend.new()
	_game.battle_turn_pace = 0.0
	# Deliberately NOT sizing the root here. V1Game._ready() must do it. An earlier draft
	# of this file called set_anchors_and_offsets_preset on the game itself in before_each —
	# performing the very fix under test — which made every assertion below unfalsifiable.
	add_child_autofree(_game)


func after_each() -> void:
	_game = null


## Containers only size themselves during layout, which runs on a frame.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _viewport_size() -> Vector2:
	return _game.get_viewport().get_visible_rect().size


## The tallest expanding descendant — the region a collapsed layout starves first.
func _tallest_expanding(node: Node) -> float:
	var best := 0.0
	for child in node.get_children():
		if child is Control and child.size_flags_vertical & Control.SIZE_EXPAND:
			best = maxf(best, child.size.y)
		best = maxf(best, _tallest_expanding(child))
	return best


func _assert_fills(screen: Control, label: String) -> void:
	assert_gt(screen.size.x, 0.0, "%s has zero width" % label)
	assert_gt(screen.size.y, 0.0, "%s has zero height" % label)
	assert_almost_eq(screen.size, _viewport_size(), Vector2(1, 1),
		"%s does not fill the viewport" % label)


# ---------------------------------------------------------------------------
# The root
# ---------------------------------------------------------------------------

func test_the_game_root_is_a_control() -> void:
	# A Control child of a plain Node never resolves its anchors. This is the single fact
	# that broke every screen at once.
	assert_true(_game is Control,
		"screens are Controls and need a Control parent to size against")


func test_the_root_fills_the_viewport() -> void:
	await _settle()
	assert_almost_eq(_game.size, _viewport_size(), Vector2(1, 1))


func test_the_viewport_keeps_its_portrait_shape() -> void:
	# `expand` stretched 9:16 to whatever shape the desktop window happened to be — 640x640
	# on a near-square window. A mobile-first game letterboxes instead.
	await _settle()
	var size := _viewport_size()
	assert_lt(size.x, size.y, "portrait, not squashed to the window's aspect (%s)" % size)


# ---------------------------------------------------------------------------
# Each screen
# ---------------------------------------------------------------------------

func test_the_stage_map_fills_the_viewport() -> void:
	_game.show_map()
	await _settle()
	_assert_fills(_game._map, "stage map")


func test_home_fills_the_viewport() -> void:
	await _settle()
	_assert_fills(_game._home, "home")


func test_the_stage_list_has_room_to_show_cards() -> void:
	_game.show_map()
	# The exact failure in the screenshot: ten cards existed, the ScrollContainer around
	# them was 0px tall, and the player saw an empty grey panel.
	await _settle()
	assert_eq(_game._map._cards.size(), _game.ctx.stages.entries.size())
	assert_gt(_tallest_expanding(_game._map), 100.0,
		"the scrolling region collapsed — cards exist but nothing can be seen")


func test_a_stage_card_is_wide_enough_to_read() -> void:
	# Cards no longer span the screen — they sit BESIDE the timeline, so the bar to clear is
	# "wide enough for the longest stage name", not "half the viewport".
	_game.show_map()
	await _settle()
	var card: Control = _game._map._cards[0]
	assert_gte(card.size.x, StageSelectScreen.CARD_W, "cards are squeezed to nothing")


func test_stage_cards_alternate_sides_without_crossing_the_timeline() -> void:
	# The dashed spine and the node circles live at the centre; a card that ran across it
	# would bury the very thing the card belongs to.
	_game.show_map()
	await _settle()
	var map := _game._map
	var centre: float = map._track.size.x * 0.5
	var left := 0
	var right := 0
	for i in map._cards.size():
		var card: Button = map._cards[i]
		if card.position.x > centre:
			right += 1
			assert_gte(card.position.x, centre, "a right card crosses the spine")
		else:
			left += 1
			assert_lte(card.position.x + card.size.x, centre, "a left card crosses the spine")
	assert_gt(left, 0, "no cards on the left")
	assert_gt(right, 0, "no cards on the right")


func test_the_workshop_fills_the_viewport() -> void:
	_game.show_workshop()
	await _settle()
	_assert_fills(_game._workshop, "workshop")
	assert_gt(_tallest_expanding(_game._workshop), 50.0, "the part list has no room")


func test_the_skill_tree_fills_the_viewport() -> void:
	_game.show_tree()
	await _settle()
	_assert_fills(_game._tree_screen, "skill tree")
	assert_gt(_game._tree_screen._view.size.y, 100.0,
		"the graph view collapsed — a 156-node tree in 0px shows nothing")


func test_the_squad_screen_fills_the_viewport() -> void:
	_game.show_squad()
	await _settle()
	_assert_fills(_game._squad, "squad")
	assert_gt(_tallest_expanding(_game._squad), 50.0, "the bench has no room")


func test_the_foundry_fills_the_viewport_without_overflow() -> void:
	_game.show_foundry()
	await _settle()
	_assert_fills(_game._foundry, "foundry")
	# The row labels can be long ("blueprint not found"); none may push its row past the edge.
	for row in _game._foundry._list.get_children():
		assert_lte(row.size.x, _viewport_size().x + 1.0,
			"a foundry row overflows horizontally")


func test_the_battle_screen_fills_the_viewport() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	await _settle()
	_assert_fills(_game._battle, "battle")


func test_the_battlefield_has_room_for_the_unit_columns() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	await _settle()
	var panel: Control = _game._battle._player_panels[0]
	assert_gt(panel.size.x, 0.0, "unit cards have no width")
	assert_gt(panel.size.y, 0.0, "unit cards have no height")


func test_the_reward_screen_fills_the_viewport() -> void:
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	_game._battle._on_auto_toggled(true)
	await _settle()
	_assert_fills(_game._reward, "reward")


# ---------------------------------------------------------------------------
# Nothing overflows
# ---------------------------------------------------------------------------

func test_the_battle_skill_bar_fits_on_screen() -> void:
	# A long skill name ("Resonance Field") used to widen the row past the right edge,
	# putting the last button — often the ultimate — where a thumb cannot reach it.
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	await _settle()
	var bar: Control = _game._battle._skill_bar
	assert_lte(bar.size.x, _viewport_size().x + 1.0, "the skill bar overflows")
	for button in bar.get_children():
		assert_lte(button.position.x + button.size.x, _viewport_size().x + 1.0,
			"'%s' sits off the right edge" % button.text)


func test_no_screen_is_wider_than_the_viewport() -> void:
	# Horizontal overflow on a phone means controls the player physically cannot reach.
	for opener in ["show_map", "show_workshop", "show_tree", "show_squad", "show_foundry"]:
		_game.call(opener)
		await _settle()
		for child in _game.get_children():
			if child is Control:
				assert_lte(child.size.x, _viewport_size().x + 1.0,
					"%s overflows horizontally" % opener)


# ---------------------------------------------------------------------------
# Nothing overflows DOWNWARD either
# ---------------------------------------------------------------------------

func test_the_battle_controls_are_on_screen() -> void:
	# Regression: the battlefield used to be two columns of four sprite-plus-nameplate cards,
	# needing ~600px of column height on a 640px screen. The log, the skill bar and the auto
	# toggle were pushed off the bottom edge — the player could not see their own attacks.
	# Every overflow test here checked WIDTH only, so the suite stayed green through it.
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	await _settle()
	var bottom := _viewport_size().y
	var battle := _game._battle
	for named in [["skill bar", battle._skill_bar], ["auto toggle", battle._auto_toggle],
			["log", battle._log_label]]:
		var control: Control = named[1]
		assert_lte(control.global_position.y + control.size.y, bottom + 1.0,
			"the %s sits below the bottom edge" % named[0])


func test_no_battle_figure_stands_outside_the_arena_band() -> void:
	# The figures are positioned absolutely, so nothing but this arithmetic keeps them inside
	# the band — a container would have complained, and there is no container here.
	_game._on_stage_chosen(_game.ctx.stages.get_stage(&"stage_01"))
	await _settle()
	var battle := _game._battle
	var band := battle._arena.get_global_rect()
	for panel in battle._player_panels + battle._enemy_panels:
		if not panel.visible:
			continue
		var rect: Rect2 = panel.get_global_rect()
		assert_gte(rect.position.x, band.position.x - 1.0, "a figure hangs off the left")
		assert_lte(rect.position.x + rect.size.x, band.position.x + band.size.x + 1.0,
			"a figure hangs off the right")
		assert_lte(rect.position.y + rect.size.y, band.position.y + band.size.y + 1.0,
			"a figure stands below the band")
