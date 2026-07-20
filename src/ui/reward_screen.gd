## RewardScreen — what you just won (Core Design §6).
##
## Shown between the last fight and the map. The moment a run ends is the single most
## motivating beat in the loop; dropping the player straight back on the map spends it for
## nothing and makes a hard-won chest indistinguishable from a routine clear.
##
## Shows a DEFEAT summary too, because §6 says a loss still keeps what dropped. A defeat
## screen that showed nothing would read as "you lost everything", which is not what
## happened.
class_name RewardScreen
extends Screen

const StageRunnerScript := preload("res://src/core/stages/stage_runner.gd")
const BattleEngineScript := preload("res://src/core/battle_v1/battle_engine.gd")

## The player has read it and wants to move on.
signal dismissed

const MIN_BUTTON_HEIGHT := 44

var _ctx: ServiceContext = null

var _title: Label
var _lines: VBoxContainer
var _continue_button: Button


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_build_layout()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	root.add_child(_title)

	_lines = VBoxContainer.new()
	_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 4)
	root.add_child(_lines)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	_continue_button.pressed.connect(Callable(self, "_on_continue_pressed"))
	root.add_child(_continue_button)


## Fill from a settled run. [param stage] is only used for its name, so the screen never
## needs the runner itself.
func show_result(result, stage: StageDef) -> void:
	_title.text = "VICTORY" if result.cleared else "DEFEAT"

	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()

	_add_line("%s — %d of %d fights won" % [
		stage.display_name if stage != null else "", result.battles_won,
		stage.battle_count() if stage != null else 0])
	_add_line("Scrap  +%d" % result.scrap_earned)
	_add_line("XP     +%d each" % result.xp_each)

	# Only mention levels when some were gained. "Levels +0" is noise that makes the line
	# the player actually cares about harder to find.
	if result.levels_gained > 0:
		_add_line("Levels +%d across the squad" % result.levels_gained)

	if result.chest_items.is_empty() and result.chest_blueprint == &"":
		if not result.cleared:
			# Naming what was missed is what makes the next attempt feel worth making.
			_add_line("No chest — the stage was not cleared")
	else:
		_add_line("Chest:")
		for item_id in result.chest_items:
			_add_line("   %s" % _item_name(item_id))
		if result.chest_blueprint != &"":
			_add_line("   Blueprint: %s" % result.chest_blueprint)


func _item_name(item_id: StringName) -> String:
	if _ctx == null:
		return String(item_id)
	var item: InstallItemDef = _ctx.items.get(item_id)
	return item.display_name if item != null else String(item_id)


func _add_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	_lines.add_child(label)


func _on_continue_pressed() -> void:
	dismissed.emit()
