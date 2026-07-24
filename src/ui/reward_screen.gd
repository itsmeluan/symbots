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
var _xp_panel: VBoxContainer
var _lines: VBoxContainer
var _continue_button: Button

## The running reveal tweens, so a tap can skip straight to the settled ledger.
var _reveal_tweens: Array = []

## Per squad-member XP bar, with its animation data, so the reveal can fill each bar and the
## skip can slam them all to their settled state. Each entry:
## { bar, level_label, xp_label, arrow, before_pct, after_pct, leveled, level_after }.
var _xp_rows: Array = []


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

	# The squad's XP: one row per fielded Symbot — sprite, level, a bar that fills, and the
	# XP-to-next readout. Filled by show_result() from result.xp_gains; empty (and so this
	# panel simply takes no room) when a Result carries no per-member XP.
	_xp_panel = VBoxContainer.new()
	_xp_panel.add_theme_constant_override("separation", 6)
	root.add_child(_xp_panel)

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

	_build_xp_panel(result)

	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()

	_add_line("%s — %d of %d fights won" % [
		stage.display_name if stage != null else "", result.battles_won,
		stage.battle_count() if stage != null else 0])
	_add_line("Scrap  +%d" % result.scrap_earned, UIPalette.TEXT, _scrap_icon())
	if result.alloy_earned > 0:
		_add_line("Alloy  +%d" % result.alloy_earned, UIPalette.TEXT, _alloy_icon())
	_add_line("XP     +%d each" % result.xp_each, UIPalette.TEXT,
		Glyph.make(&"star", 13.0, UIPalette.CYAN))

	# Only mention levels when some were gained. "Levels +0" is noise that makes the line
	# the player actually cares about harder to find.
	if result.levels_gained > 0:
		_add_line("Levels +%d across the squad" % result.levels_gained, UIPalette.GREEN,
			Glyph.make(&"arrow_up", 13.0, UIPalette.GREEN))

	# The Core is the rarest thing a run can pay, and it is spent on a different screen —
	# announcing it here is the only place the player learns they have one.
	if result.cores_earned > 0:
		_add_line("CHIPSET  +%d" % result.cores_earned, UIPalette.AMBER,
			Glyph.make(&"chip", 13.0, UIPalette.AMBER))

	# A newly-learned blueprint is the headline of a boss clear — announce it above the loot,
	# in amber so it stands out as the prize it is.
	if result.blueprint_was_new and result.chest_blueprint != &"":
		_add_line("BLUEPRINT LEARNED: %s" % _species_name(result.chest_blueprint),
			UIPalette.AMBER, Glyph.make(&"sparkle", 13.0, UIPalette.AMBER))

	if result.chest_items.is_empty() and result.chest_blueprint == &"":
		if not result.cleared:
			# Naming what was missed is what makes the next attempt feel worth making.
			_add_line("No chest — the stage was not cleared")
	elif not result.chest_items.is_empty():
		# The blueprint has its own amber headline above; the chest list is just the loot.
		_add_line("Chest:")
		for item_id in result.chest_items:
			_add_line("   %s" % _item_name(item_id), UIPalette.TEXT,
				Glyph.make(&"star", 12.0, UIPalette.MUTED))

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

	# The XP rows fade in and their bars FILL — the earned-not-given beat. A row that gained
	# a level fills to full, flashes its arrow and ticks the level, then wraps to the leftover.
	var j := 0
	for data in _xp_rows:
		var row: Control = data["row"]
		row.modulate.a = 0.0
		var bar: ProgressBar = data["bar"]
		bar.value = data["before_pct"]
		var rt := row.create_tween()
		rt.tween_interval(0.22 + 0.12 * j)
		rt.tween_property(row, "modulate:a", 1.0, 0.15)
		if data["leveled"]:
			rt.tween_property(bar, "value", 100.0, 0.32).set_ease(Tween.EASE_IN_OUT)
			rt.tween_callback(_mark_level_up.bind(data))
			rt.tween_property(bar, "value", 0.0, 0.001)
			rt.tween_property(bar, "value", data["after_pct"], 0.28).set_ease(Tween.EASE_OUT)
		else:
			rt.tween_property(bar, "value", data["after_pct"], 0.34).set_ease(Tween.EASE_OUT)
		_reveal_tweens.append(rt)
		j += 1

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


## Reveal a row's level-up arrow and advance its level tag, popping the arrow so the eye
## catches it. Called mid-fill by the reveal tween the instant the bar tops out.
func _mark_level_up(data: Dictionary) -> void:
	var arrow: Label = data["arrow"]
	arrow.visible = true
	arrow.pivot_offset = arrow.size * 0.5
	arrow.scale = Vector2(1.4, 1.4)
	arrow.create_tween().tween_property(arrow, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var level_label: Label = data["level_label"]
	level_label.text = "Lv %d" % data["level_after"]


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
	# Settle every XP bar to its final fill, level tag and arrow — a skipped reveal must not
	# leave a bar frozen mid-slide or a level-up that never showed.
	for data in _xp_rows:
		var row: Control = data["row"]
		row.modulate.a = 1.0
		var bar: ProgressBar = data["bar"]
		bar.value = data["after_pct"]
		var level_label: Label = data["level_label"]
		level_label.text = "Lv %d" % data["level_after"]
		var arrow: Label = data["arrow"]
		arrow.visible = data["leveled"]
		arrow.scale = Vector2.ONE


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


## One ledger line: an optional standard resource/item icon, then the text. A row rather
## than a bare Label so the loot reads with the same icons the wallet and workshop use.
func _add_line(text: String, colour: Color = UIPalette.TEXT, icon: Control = null) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if icon != null:
		icon.custom_minimum_size = Vector2(14, 14)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(16, 16)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(icon)
		row.add_child(holder)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", colour)
	row.add_child(label)
	_lines.add_child(row)


func _scrap_icon() -> Control:
	return IconGlyph.new(&"scrap", UIPalette.SCRAP, 14.0)


func _alloy_icon() -> Control:
	return IconGlyph.new(&"alloy", UIPalette.ALLOY, 14.0)


# ---------------------------------------------------------------------------
# Squad XP panel
# ---------------------------------------------------------------------------

## Build one XP row per squad member from the run's snapshot. No rows (and so no panel) when
## the Result carries no per-member XP, or when there is no balance config to read the curve.
func _build_xp_panel(result) -> void:
	for child in _xp_panel.get_children():
		_xp_panel.remove_child(child)
		child.queue_free()
	_xp_rows.clear()
	if _ctx == null or _ctx.balance == null:
		return
	for gain in result.xp_gains:
		_build_xp_row(gain)


func _build_xp_row(gain) -> void:
	var cfg: BalanceConfig = _ctx.balance
	var need_before := maxi(1, XpProgression.xp_to_next(gain.level_before, cfg))
	var need_after := maxi(1, XpProgression.xp_to_next(gain.level_after, cfg))
	var before_pct := clampf(float(gain.xp_before) / need_before * 100.0, 0.0, 100.0)
	var after_pct := clampf(float(gain.xp_after) / need_after * 100.0, 0.0, 100.0)
	var leveled: bool = gain.level_after > gain.level_before

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var sprite := TextureRect.new()
	sprite.texture = UnitPanel.art_texture(gain.species_id, gain.mark)
	sprite.custom_minimum_size = Vector2(40, 40)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(sprite)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	# Header: name on the left, a "level up" arrow (hidden until it fires) and the level tag.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)

	var name_label := Label.new()
	name_label.text = gain.display_name
	name_label.add_theme_font_override("font", UIPalette.display_font())
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)

	var arrow := Label.new()
	arrow.text = "▲ LEVEL UP"
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.add_theme_color_override("font_color", UIPalette.GREEN)
	arrow.visible = false
	head.add_child(arrow)

	var level_label := Label.new()
	level_label.text = "Lv %d" % gain.level_before
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", UIPalette.AMBER)
	head.add_child(level_label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 100
	bar.value = before_pct
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIPalette.CYAN
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", back)
	col.add_child(bar)

	# The readout the plan asks for: current XP into this level and how much the next costs.
	var xp_label := Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp_label.add_theme_font_size_override("font_size", 9)
	xp_label.add_theme_color_override("font_color", UIPalette.MUTED)
	xp_label.text = "%d / %d XP" % [gain.xp_after, need_after]
	col.add_child(xp_label)

	_xp_panel.add_child(row)
	_xp_rows.append({
		"row": row, "bar": bar, "level_label": level_label, "arrow": arrow,
		"before_pct": before_pct, "after_pct": after_pct,
		"leveled": leveled, "level_after": gain.level_after,
	})


func _on_continue_pressed() -> void:
	dismissed.emit()
