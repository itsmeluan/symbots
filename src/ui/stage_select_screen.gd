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

## Emitted when the player wants to change who fights.
signal squad_requested

## Emitted when the player wants the Foundry (crafting).
signal foundry_requested

## Emitted when the player wants offline expeditions.
signal expeditions_requested

const MIN_ROW_HEIGHT := 60  ## comfortably past the 44pt touch minimum
const CARD_SEPARATION := 6

var _ctx: ServiceContext = null

var _scrap_label: Label
var _alloy_label: Label
var _list: VBoxContainer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/overworld/map_background.png", 0.6)
	_build_layout()
	if _ctx.wallet != null:
		_connect_owned(_ctx.wallet.balance_changed, Callable(self, "_on_balance_changed"))
	refresh()


## ADR-0008: a screen must not hold the context past EXIT_TREE, or the RefCounted bundle
## never tears down.
func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_scrap_label = Label.new()
	_scrap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_scrap_label)
	_alloy_label = Label.new()
	header.add_child(_alloy_label)

	var menu := HBoxContainer.new()
	root.add_child(menu)
	var workshop_button := Button.new()
	workshop_button.text = "Workshop"
	workshop_button.custom_minimum_size = Vector2(0, 44)
	workshop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workshop_button.clip_text = true
	workshop_button.pressed.connect(Callable(self, "_on_workshop_pressed"))
	menu.add_child(workshop_button)
	var squad_button := Button.new()
	squad_button.text = "Squad"
	squad_button.custom_minimum_size = Vector2(0, 44)
	squad_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	squad_button.clip_text = true
	squad_button.pressed.connect(Callable(self, "_on_squad_pressed"))
	menu.add_child(squad_button)
	var foundry_button := Button.new()
	foundry_button.text = "Foundry"
	foundry_button.custom_minimum_size = Vector2(0, 44)
	foundry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foundry_button.clip_text = true
	foundry_button.pressed.connect(Callable(self, "_on_foundry_pressed"))
	menu.add_child(foundry_button)
	var exped_button := Button.new()
	exped_button.text = "Expeditions"
	exped_button.custom_minimum_size = Vector2(0, 44)
	exped_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exped_button.clip_text = true
	exped_button.pressed.connect(Callable(self, "_on_expeditions_pressed"))
	menu.add_child(exped_button)
	var tree_button := Button.new()
	tree_button.text = "Skill Tree"
	tree_button.custom_minimum_size = Vector2(0, 44)
	tree_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_button.clip_text = true
	tree_button.pressed.connect(Callable(self, "_on_tree_pressed"))
	menu.add_child(tree_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", CARD_SEPARATION)
	scroll.add_child(_list)


## Redraw the whole map. Cheap enough at ten stages that incremental updates would be
## complexity with no payoff, and a full rebuild cannot leave a stale row behind.
func refresh() -> void:
	_refresh_wallet()
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


func _refresh_wallet() -> void:
	if _ctx == null or _ctx.wallet == null:
		return
	_scrap_label.text = "Scrap %d" % _ctx.wallet.scrap
	_alloy_label.text = "Alloy %d" % _ctx.wallet.alloy


func _on_balance_changed(_currency: StringName, _amount: int) -> void:
	_refresh_wallet()


func _build_card(stage: StageDef) -> Control:
	var available := _ctx.progress.is_available(stage)
	var cleared := _ctx.progress.is_cleared(stage.id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = _card_text(stage, cleared)
	button.disabled = not available
	button.tooltip_text = stage.description

	if available:
		button.pressed.connect(Callable(self, "_on_stage_pressed").bind(stage))
	# A cleared stage stays enterable — replaying for Scrap is the grind the economy
	# assumes (§5.2), so locking it after one win would remove the loop's floor.
	return button


func _card_text(stage: StageDef, cleared: bool) -> String:
	var marker := "[cleared] " if cleared else ""
	var kind := ""
	match stage.mode:
		StageDefScript.Mode.DUNGEON: kind = "  DUNGEON x%d" % stage.battle_count()
		StageDefScript.Mode.RAID: kind = "  RAID"
		StageDefScript.Mode.ENDLESS: kind = "  ENDLESS"
	return "%s%d. %s%s" % [marker, stage.stage_level, stage.display_name, kind]


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
