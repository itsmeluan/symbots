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

## Shared battlefield used when no stage is set — the same fallback the battle uses.
const DEFAULT_BACKGROUND := "res://assets/art/battle/battle_arena_background.png"

## The stage that was just fought, set BEFORE setup — the victory screen keeps the
## battlefield the player was just standing on, so the beat reads as one continuous
## scene rather than a teleport to a stock backdrop.
var stage: StageDef = null

var _ctx: ServiceContext = null

var _title: Label
var _lines: VBoxContainer
var _continue_button: Button

## The running reveal tweens, so a tap can skip straight to the settled ledger.
var _reveal_tweens: Array = []


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background(_background_path(), 0.78)
	_build_layout()


func _background_path() -> String:
	if stage == null or stage.background_path.is_empty() \
			or not ResourceLoader.exists(stage.background_path):
		return DEFAULT_BACKGROUND
	return stage.background_path


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

	_play_reveal()


# ---------------------------------------------------------------------------
# The reveal
# ---------------------------------------------------------------------------

## The settlement plays as a sequence: the verdict stamps in, then each ledger line pops
## up one beat after the last, then the continue button. The most-tested moment in
## mobile: earnings that ARRIVE feel earned; a list that is simply there reads as a
## receipt. Content is all placed synchronously first — only alpha and scale animate, so
## every headless assertion sees the finished ledger.
func _play_reveal() -> void:
	_skip_reveal()
	if not is_inside_tree():
		return
	_reveal_tweens.clear()

	_title.pivot_offset = _title.size * 0.5
	_title.resized.connect(
		func() -> void: _title.pivot_offset = _title.size * 0.5, CONNECT_ONE_SHOT)
	_title.modulate.a = 0.0
	_title.scale = Vector2(1.3, 1.3)
	var title_tween := _title.create_tween()
	title_tween.tween_property(_title, "modulate:a", 1.0, 0.12)
	title_tween.parallel().tween_property(_title, "scale", Vector2.ONE, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tweens.append(title_tween)

	var order := 0
	for line in _lines.get_children():
		line.modulate.a = 0.0
		var tween := line.create_tween()
		tween.tween_interval(0.35 + 0.14 * order)
		tween.tween_property(line, "modulate:a", 1.0, 0.16)
		_reveal_tweens.append(tween)
		order += 1

	_continue_button.modulate.a = 0.0
	var button_tween := _continue_button.create_tween()
	button_tween.tween_interval(0.35 + 0.14 * order + 0.15)
	button_tween.tween_property(_continue_button, "modulate:a", 1.0, 0.20)
	_reveal_tweens.append(button_tween)


## Jump the whole reveal to its end state. Called by any tap on the backdrop — nobody
## should ever wait for a receipt they have already read.
func _skip_reveal() -> void:
	for tween in _reveal_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_reveal_tweens.clear()
	if _title != null:
		_title.modulate.a = 1.0
		_title.scale = Vector2.ONE
	if _continue_button != null:
		_continue_button.modulate.a = 1.0
	if _lines != null:
		for line in _lines.get_children():
			line.modulate.a = 1.0


func _reveal_running() -> bool:
	for tween in _reveal_tweens:
		if tween != null and tween.is_valid() and tween.is_running():
			return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _reveal_running():
		_skip_reveal()
		accept_event()


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
