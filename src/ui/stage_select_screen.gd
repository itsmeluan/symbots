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

const MIN_ROW_HEIGHT := 60  ## comfortably past the 44pt touch minimum
const CARD_SEPARATION := 6

var _ctx: ServiceContext = null

var _scrap_label: Label
var _alloy_label: Label
var _list: VBoxContainer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
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
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_scrap_label = Label.new()
	_scrap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_scrap_label)
	_alloy_label = Label.new()
	header.add_child(_alloy_label)

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


func _on_stage_pressed(stage: StageDef) -> void:
	# The map requests; the root decides. A screen never performs its own transition.
	stage_chosen.emit(stage)
