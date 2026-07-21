## StageSelectScreen — the portrait stage map (Core Design §6, ADR-0008).
##
## The screen that replaced the overworld. A scrolling column of stage cards: cleared ones
## marked, the next ones highlighted, locked ones shown but unenterable.
##
## Locked stages are DRAWN rather than hidden. A map that only shows what you can play
## teaches nothing about where you are going; seeing the locked rows above you is the
## reason to keep going.
##
## Owns no rules — availability comes from [StageProgress], which derives it from what is
## cleared. The screen only asks and draws.
class_name StageSelectScreen
extends Screen

const StageDefScript := preload("res://src/core/stages/stage_def.gd")

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

const MIN_ROW_HEIGHT := 60  ## comfortably past the 44pt touch minimum
const CARD_SEPARATION := 6

var _ctx: ServiceContext = null
var _list: VBoxContainer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/overworld/map_background.png", 0.6)
	_build_layout()
	refresh()


## ADR-0008: a screen must not hold the context past EXIT_TREE, or the RefCounted bundle
## never tears down.
func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	var content := build_chrome(_ctx, "MAP", &"map", func(d): navigate.emit(d))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", CARD_SEPARATION)
	scroll.add_child(_list)


## Redraw the whole map. Cheap enough at ten stages that incremental updates would be
## complexity with no payoff, and a full rebuild cannot leave a stale row behind.
func refresh() -> void:
	refresh_chrome_wallet()
	for child in _list.get_children():
		# remove_child BEFORE queue_free: queue_free is DEFERRED, so a rebuild that only
		# queued would leave the old rows in the tree for the rest of the frame — the list
		# transiently shows every stage twice.
		_list.remove_child(child)
		child.queue_free()
	if _ctx == null or _ctx.stages == null or _ctx.progress == null:
		return
	for stage in _ctx.stages.entries:
		if stage != null:
			_list.add_child(_build_card(stage))


func _build_card(stage: StageDef) -> Control:
	var available := _ctx.progress.is_available(stage)
	var cleared := _ctx.progress.is_cleared(stage.id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = _card_text(stage, cleared)
	button.disabled = not available
	button.tooltip_text = stage.description
	_style_card(button, available, cleared)

	if available:
		button.pressed.connect(Callable(self, "_on_stage_pressed").bind(stage))
	# A cleared stage stays enterable — replaying for Scrap is the grind the economy
	# assumes (§5.2), so locking it after one win would remove the loop's floor.
	return button


## Two lines: the stage's name, then what it is and what it wants. The left bar carries the
## state, so scanning the column reads as a progress track rather than a list of names.
func _card_text(stage: StageDef, cleared: bool) -> String:
	var kind := "%d fight" % stage.battle_count()
	if stage.battle_count() != 1:
		kind = "%d fights" % stage.battle_count()
	match stage.mode:
		StageDefScript.Mode.DUNGEON: kind = "DUNGEON · %s · Core" % kind
		StageDefScript.Mode.RAID: kind = "RAID · %s" % kind
		StageDefScript.Mode.ENDLESS: kind = "ENDLESS"
	var mark := "CLEARED · " if cleared else ""
	return "%02d   %s\n%sLv %d · %s" % [
		stage.stage_level, stage.display_name.to_upper(), mark, stage.enemy_level, kind]


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
	button.add_theme_font_size_override("font_size", 12)


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


func _on_stage_pressed(stage: StageDef) -> void:
	# The map requests; the root decides. A screen never performs its own transition.
	stage_chosen.emit(stage)
