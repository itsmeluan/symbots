## StageSelectScreen — the portrait stage map (Core Design §6, ADR-0008).
##
## The screen that replaced the overworld. A vertical timeline the player CLIMBS: stage one
## sits at the bottom, each node is a circle on a dashed centre line, and its name card sits
## beside it, alternating sides. Tapping a card opens a detail sheet along the bottom; the
## sheet's DEPLOY button is what actually commits.
##
## Bottom-up rather than top-down because the run reads as ascent — the fiction is a climb
## from the scrap flats to the core, and a list that grows downward fights that.
##
## Locked stages are DRAWN rather than hidden. A map that only shows what you can play
## teaches nothing about where you are going; seeing the locked nodes above you is the
## reason to keep going.
##
## Owns no rules — availability comes from [StageProgress], which derives it from what is
## cleared. The screen only asks and draws.
class_name StageSelectScreen
extends Screen

const StageDefScript := preload("res://src/core/stages/stage_def.gd")
const UpgradeEconomyScript := preload("res://src/core/economy/upgrade_economy.gd")

## Emitted when the player commits to a stage. The game root builds the runner and pushes
## the battle screen; the map does not perform transitions itself (ADR-0004/0008).
signal stage_chosen(stage: StageDef)

## Emitted when the player wants the Workshop. Same discipline — the map requests, the
## root transitions.
signal workshop_requested

## Emitted when the player wants the skill tree.
signal tree_requested

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

## Emitted when the player wants to change who fights.
signal squad_requested

## Emitted when the player wants the Foundry (crafting).
signal foundry_requested

## Emitted when the player wants offline expeditions.
signal expeditions_requested

## Vertical distance between two nodes on the timeline.
const NODE_SPACING := 128.0

## Empty track above the last node and below the first, so either end can still be scrolled
## to the middle of the screen. Without it the first stage can only ever sit at the bottom.
const TRACK_PAD := 240.0

const NODE_DIAMETER := 34.0
const CARD_W := 152.0
const CARD_H := 46.0
## Clearance between the node circle and the card beside it.
const CARD_GAP := 12.0

const MIN_ROW_HEIGHT := 60  ## comfortably past the 44pt touch minimum

## Height of the detail sheet.
##
## Fixed rather than derived from its contents. Deriving it meant asking an autowrapped Label
## for a minimum height before layout had given the sheet a width — it wrapped to one
## character per line and reported a height taller than the screen. The description is capped
## at two lines (see _build_sheet) so this budget always holds.
##
## The sheet therefore looks slightly roomy under a one-line description: the second line is
## reserved whether or not it is used. That is deliberate — a sheet that changed height as the
## player browsed stages would make DEPLOY move under their thumb.
const SHEET_HEIGHT := 220.0

var _ctx: ServiceContext = null

var _scroll: ScrollContainer
var _track: Control
var _line: Control

## Cards in STAGE order — index 0 is the first stage, which is drawn at the BOTTOM.
var _cards: Array[Button] = []
var _nodes: Array[Control] = []

# The detail sheet along the bottom.
var _sheet: PanelContainer
var _sheet_name: Label
var _sheet_chips: HBoxContainer
var _sheet_body: Label
var _sheet_reward: Label
var _deploy: Button
var _selected: StageDef = null


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/overworld/map_background.png", 0.6)
	_build_layout()
	refresh()
	# Land on what the player is meant to do next rather than at an arbitrary end of a
	# 2200px track.
	call_deferred("scroll_to_next_stage")


## ADR-0008: a screen must not hold the context past EXIT_TREE, or the RefCounted bundle
## never tears down.
func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null
	_selected = null


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	var content := build_chrome(_ctx, "MAP", &"map", func(d): navigate.emit(d))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)

	# Nodes are positioned absolutely inside the track: the timeline is a picture with a
	# fixed vertical rhythm, not a stack whose spacing a container would decide.
	_track = Control.new()
	_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_track)

	_line = Control.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.draw.connect(_draw_line)
	_track.add_child(_line)

	_build_sheet()


## The dashed spine the nodes sit on. Drawn rather than tiled from an image so it stretches
## to whatever the track's height works out to be.
func _draw_line() -> void:
	var x := _line.size.x * 0.5
	var dash := 7.0
	var gap := 6.0
	var y := 0.0
	while y < _line.size.y:
		_line.draw_line(Vector2(x, y), Vector2(x, minf(y + dash, _line.size.y)),
			Color(UIPalette.LINE, 0.55), 2.0)
		y += dash + gap


## The detail sheet. Hidden until a card is tapped, and it is the ONLY way into a fight —
## tapping a node no longer launches one. A map where a stray tap starts a battle is a map
## the player cannot browse.
func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.visible = false
	# Anchored by hand rather than with PRESET_BOTTOM_WIDE: the preset derives offset_top
	# from the control's minimum size AT THE TIME OF THE CALL, which is zero before the
	# contents exist — the sheet ends up 0px tall and invisible. _size_sheet() sets the
	# height once there is something to measure.
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 0.0
	_sheet.offset_right = 0.0
	# Sits ABOVE the dock so navigation stays reachable while a stage is selected.
	_sheet.offset_bottom = -(BottomDock.HEIGHT + _safe_insets().y)
	_sheet.offset_top = _sheet.offset_bottom - SHEET_HEIGHT
	var box := UIPalette.panel(UIPalette.CYAN, UIPalette.INK)
	box.set_content_margin_all(14)
	_sheet.add_theme_stylebox_override("panel", box)
	add_child(_sheet)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_sheet.add_child(v)

	var eyebrow := Label.new()
	eyebrow.text = "SELECTED STAGE"
	eyebrow.add_theme_font_size_override("font_size", 9)
	eyebrow.add_theme_color_override("font_color", UIPalette.MUTED)
	v.add_child(eyebrow)

	_sheet_name = Label.new()
	_sheet_name.theme_type_variation = &"Heading"
	_sheet_name.add_theme_font_size_override("font_size", 22)
	_sheet_name.add_theme_color_override("font_color", UIPalette.TEXT)
	v.add_child(_sheet_name)

	_sheet_chips = HBoxContainer.new()
	_sheet_chips.add_theme_constant_override("separation", 6)
	v.add_child(_sheet_chips)

	_sheet_body = Label.new()
	_sheet_body.add_theme_font_size_override("font_size", 11)
	_sheet_body.add_theme_color_override("font_color", UIPalette.MUTED)
	_sheet_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Two lines, then ellipsis: a long description must not be able to push DEPLOY off the
	# sheet. The full text is still in the card's tooltip.
	_sheet_body.max_lines_visible = 2
	_sheet_body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_sheet_body)

	_sheet_reward = Label.new()
	_sheet_reward.add_theme_font_size_override("font_size", 11)
	_sheet_reward.add_theme_color_override("font_color", UIPalette.AMBER)
	v.add_child(_sheet_reward)

	_deploy = Button.new()
	_deploy.text = "▶  DEPLOY SQUAD"
	_deploy.custom_minimum_size = Vector2(0, 48)
	var deploy_box := StyleBoxFlat.new()
	deploy_box.bg_color = UIPalette.AMBER
	deploy_box.set_corner_radius_all(4)
	_deploy.add_theme_stylebox_override("normal", deploy_box)
	_deploy.add_theme_stylebox_override("hover", deploy_box)
	_deploy.add_theme_stylebox_override("pressed", deploy_box)
	_deploy.add_theme_stylebox_override("focus", UIPalette.empty())
	_deploy.add_theme_color_override("font_color", UIPalette.INK)
	_connect_owned(_deploy.pressed, Callable(self, "_on_deploy_pressed"))
	v.add_child(_deploy)


# ---------------------------------------------------------------------------
# Drawing the timeline
# ---------------------------------------------------------------------------

## Redraw the whole map. Cheap enough at fifteen stages that incremental updates would be
## complexity with no payoff, and a full rebuild cannot leave a stale node behind.
func refresh() -> void:
	refresh_chrome_wallet()
	for card in _cards:
		_track.remove_child(card)
		card.queue_free()
	for node in _nodes:
		_track.remove_child(node)
		node.queue_free()
	_cards.clear()
	_nodes.clear()
	if _ctx == null or _ctx.stages == null or _ctx.progress == null:
		return

	var stages: Array = []
	for stage in _ctx.stages.entries:
		if stage != null:
			stages.append(stage)

	var height := TRACK_PAD * 2.0 + NODE_SPACING * maxf(0.0, float(stages.size() - 1))
	_track.custom_minimum_size = Vector2(0, height)
	_line.position = Vector2.ZERO
	_line.size = Vector2(_track.size.x, height)

	for i in stages.size():
		var stage: StageDef = stages[i]
		var node := _build_node(stage, i)
		var card := _build_card(stage)
		_track.add_child(node)
		_track.add_child(card)
		_nodes.append(node)
		_cards.append(card)

	_place_all()
	_track.resized.connect(_place_all, CONNECT_REFERENCE_COUNTED)


## Position every node and card. Index 0 is placed at the BOTTOM of the track and the index
## climbs upward, which is the whole point of the screen.
func _place_all() -> void:
	var w := _track.size.x
	if w <= 0.0:
		return
	_line.size = Vector2(w, _track.custom_minimum_size.y)
	_line.queue_redraw()
	var centre := w * 0.5
	for i in _cards.size():
		var y := _node_y(i)
		_nodes[i].position = Vector2(centre - NODE_DIAMETER * 0.5, y - NODE_DIAMETER * 0.5)
		# Alternate sides so consecutive names never stack into one unreadable block.
		var on_right := i % 2 == 0
		var x := centre + NODE_DIAMETER * 0.5 + CARD_GAP if on_right \
			else centre - NODE_DIAMETER * 0.5 - CARD_GAP - CARD_W
		_cards[i].position = Vector2(clampf(x, 4.0, maxf(4.0, w - CARD_W - 4.0)),
			y - CARD_H * 0.5)
		_cards[i].size = Vector2(CARD_W, CARD_H)


## Where stage [param index] sits, measured from the BOTTOM of the track upward.
func _node_y(index: int) -> float:
	return _track.custom_minimum_size.y - TRACK_PAD - NODE_SPACING * float(index)


func _build_node(stage: StageDef, index: int) -> Control:
	var cleared := _ctx.progress.is_cleared(stage.id)
	var available := _ctx.progress.is_available(stage)

	var node := Panel.new()
	node.custom_minimum_size = Vector2(NODE_DIAMETER, NODE_DIAMETER)
	node.size = Vector2(NODE_DIAMETER, NODE_DIAMETER)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var accent := UIPalette.LINE
	if cleared:
		accent = UIPalette.AMBER
	elif available:
		accent = UIPalette.CYAN

	var box := StyleBoxFlat.new()
	box.bg_color = UIPalette.INK if not cleared else Color(UIPalette.AMBER_DARK, 0.9)
	box.set_corner_radius_all(int(NODE_DIAMETER * 0.5))
	box.border_color = accent
	box.set_border_width_all(2)
	node.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	# A cleared stage shows a tick, not its number — the number is only useful while it is
	# still ahead of you.
	label.text = "✓" if cleared else str(index + 1)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", accent)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label)
	return node


func _build_card(stage: StageDef) -> Button:
	var available := _ctx.progress.is_available(stage)
	var cleared := _ctx.progress.is_cleared(stage.id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(CARD_W, CARD_H)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = _card_text(stage, cleared)
	button.disabled = not available
	button.clip_text = true
	button.tooltip_text = stage.description
	_style_card(button, available, cleared)

	if available:
		button.pressed.connect(Callable(self, "_on_stage_pressed").bind(stage))
	# A cleared stage stays enterable — replaying for Scrap is the grind the economy
	# assumes (§5.2), so locking it after one win would remove the loop's floor.
	return button


## Two lines: the stage's name, then what it is. The number lives on the node now, so the
## card no longer repeats it.
func _card_text(stage: StageDef, cleared: bool) -> String:
	var kind := "%d FIGHT" % stage.battle_count()
	if stage.battle_count() != 1:
		kind = "%d FIGHTS" % stage.battle_count()
	match stage.mode:
		StageDefScript.Mode.DUNGEON: kind = "DUNGEON · %s" % kind
		StageDefScript.Mode.RAID: kind = "RAID · %s" % kind
		StageDefScript.Mode.ENDLESS: kind = "ENDLESS"
	var state := "CLEAR" if cleared else ("LV %d" % stage.enemy_level)
	return "%s\n%s · %s" % [stage.display_name.to_upper(), state, kind]


## Amber once beaten, cyan when it is the next thing to do, dim when it is still out of reach.
func _style_card(button: Button, available: bool, cleared: bool) -> void:
	var accent := UIPalette.LINE
	var text := UIPalette.DISABLED
	if cleared:
		accent = UIPalette.AMBER
		text = UIPalette.TEXT
	elif available:
		accent = UIPalette.CYAN
		text = UIPalette.TEXT
	var box := UIPalette.row(accent, not available)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("disabled", box)
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_disabled_color", text)
	button.add_theme_font_size_override("font_size", 11)


# ---------------------------------------------------------------------------
# Scrolling
# ---------------------------------------------------------------------------

## Put the next stage the player has NOT cleared in the middle of the screen. Falls back to
## the last stage once everything is cleared, so the view never snaps back to the bottom.
func scroll_to_next_stage() -> void:
	if _ctx == null or _cards.is_empty():
		return
	var target := _cards.size() - 1
	for i in _ctx.stages.entries.size():
		var stage: StageDef = _ctx.stages.entries[i]
		if stage != null and not _ctx.progress.is_cleared(stage.id):
			target = i
			break
	centre_on(target)


## Scroll so stage [param index] sits mid-screen.
func centre_on(index: int) -> void:
	if _scroll == null or index < 0 or index >= _cards.size():
		return
	_scroll.scroll_vertical = int(_node_y(index) - _scroll.size.y * 0.5)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_workshop_pressed() -> void:
	workshop_requested.emit()


func _on_tree_pressed() -> void:
	tree_requested.emit()


func _on_squad_pressed() -> void:
	squad_requested.emit()


func _on_foundry_pressed() -> void:
	foundry_requested.emit()


func _on_expeditions_pressed() -> void:
	expeditions_requested.emit()


## Tapping a card SELECTS it. Committing is a second, deliberate tap on DEPLOY — browsing the
## map should never cost the player a fight they did not mean to start.
func _on_stage_pressed(stage: StageDef) -> void:
	_selected = stage
	_fill_sheet(stage)
	_sheet.visible = true


func _on_deploy_pressed() -> void:
	if _selected == null:
		return
	# The map requests; the root decides. A screen never performs its own transition.
	stage_chosen.emit(_selected)


func _fill_sheet(stage: StageDef) -> void:
	_sheet_name.text = stage.display_name.to_upper()
	_sheet_body.text = stage.description

	for chip in _sheet_chips.get_children():
		_sheet_chips.remove_child(chip)
		chip.queue_free()
	_sheet_chips.add_child(_chip("LV. %d" % stage.enemy_level, UIPalette.CYAN))
	_sheet_chips.add_child(_chip(_mode_name(stage.mode), UIPalette.CYAN))
	_sheet_chips.add_child(_chip(_fight_count(stage), UIPalette.CYAN))

	var reward := ""
	if _ctx.balance != null:
		reward = "First clear: %s Scrap" % Screen.fmt_thousands(
			UpgradeEconomyScript.chest_reward(stage.stage_level, _ctx.balance))
	if stage.chest_blueprint_id != &"":
		reward += " · Blueprint"
	_sheet_reward.text = reward
	_sheet_reward.visible = reward != ""


func _fight_count(stage: StageDef) -> String:
	return "1 FIGHT" if stage.battle_count() == 1 else "%d FIGHTS" % stage.battle_count()


func _mode_name(mode: int) -> String:
	match mode:
		StageDefScript.Mode.DUNGEON: return "DUNGEON"
		StageDefScript.Mode.RAID: return "RAID"
		StageDefScript.Mode.ENDLESS: return "ENDLESS"
	return "STAGE"


func _chip(text: String, accent: Color) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent, 0.14)
	box.border_color = Color(accent, 0.55)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.set_content_margin(SIDE_LEFT, 7)
	box.set_content_margin(SIDE_RIGHT, 7)
	box.set_content_margin(SIDE_TOP, 3)
	box.set_content_margin(SIDE_BOTTOM, 3)
	panel.add_theme_stylebox_override("panel", box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", accent)
	panel.add_child(label)
	return panel
