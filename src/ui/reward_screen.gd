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
	_set_background("res://assets/art/battle/battle_arena_background.png", 0.78)
	_build_layout()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Centred column with generous margins, over the dimmed arena — the prototype's victory
	# layout: a big title, a framed ledger of what was won, and a primary continue button.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(root)

	_title = Label.new()
	_title.theme_type_variation = &"Heading"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 52)
	root.add_child(_title)

	# The ledger — a framed panel holding the reward lines.
	var ledger := PanelContainer.new()
	ledger.add_theme_stylebox_override("panel", UIPalette.panel(UIPalette.LINE))
	root.add_child(ledger)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 6)
	ledger.add_child(_lines)

	_continue_button = Button.new()
	_continue_button.theme_type_variation = &"Primary"
	_continue_button.text = "RETURN TO MAP"
	_continue_button.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT + 6)
	_continue_button.pressed.connect(Callable(self, "_on_continue_pressed"))
	root.add_child(_continue_button)


## Fill from a settled run. [param stage] is only used for its name, so the screen never
## needs the runner itself.
func show_result(result, stage: StageDef) -> void:
	_title.text = "VICTORY" if result.cleared else "DEFEAT"
	_title.add_theme_color_override("font_color",
		UIPalette.GREEN if result.cleared else UIPalette.CORAL)

	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()

	_add_line("%s — %d of %d fights won" % [
		stage.display_name if stage != null else "", result.battles_won,
		stage.battle_count() if stage != null else 0])
	_add_line("Scrap  +%d" % result.scrap_earned)
	if result.alloy_earned > 0:
		_add_line("Alloy  +%d" % result.alloy_earned)
	_add_line("XP     +%d each" % result.xp_each)

	# Only mention levels when some were gained. "Levels +0" is noise that makes the line
	# the player actually cares about harder to find.
	if result.levels_gained > 0:
		_add_line("Levels +%d across the squad" % result.levels_gained)

	# The Core is the rarest thing a run can pay, and it is spent on a different screen —
	# announcing it here is the only place the player learns they have one.
	if result.cores_earned > 0:
		_add_line("CHIPSET  +%d" % result.cores_earned, UIPalette.AMBER)

	# A newly-learned blueprint is the headline of a boss clear — announce it above the loot,
	# in amber so it stands out as the prize it is.
	if result.blueprint_was_new and result.chest_blueprint != &"":
		_add_line("BLUEPRINT LEARNED: %s" % _species_name(result.chest_blueprint), UIPalette.AMBER)

	if result.chest_items.is_empty() and result.chest_blueprint == &"":
		if not result.cleared:
			# Naming what was missed is what makes the next attempt feel worth making.
			_add_line("No chest — the stage was not cleared")
	elif not result.chest_items.is_empty():
		# The blueprint has its own amber headline above; the chest list is just the loot.
		_add_line("Chest:")
		for item_id in result.chest_items:
			_add_line("   %s" % _item_name(item_id))


func _species_name(species_id: StringName) -> String:
	if _ctx == null or _ctx.species == null:
		return String(species_id)
	var sp: SpeciesDef = _ctx.species.get_species(species_id)
	return sp.display_name if sp != null else String(species_id)


func _item_name(item_id: StringName) -> String:
	if _ctx == null:
		return String(item_id)
	var item: InstallItemDef = _ctx.items.get(item_id)
	return item.display_name if item != null else String(item_id)


func _add_line(text: String, colour: Color = UIPalette.TEXT) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", colour)
	_lines.add_child(label)


func _on_continue_pressed() -> void:
	dismissed.emit()
