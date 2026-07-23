## BattleScreen — the portrait 4v4 battle view (ADR-0008, Core Design §3.1).
##
## Player squad in the LEFT column, enemies in the RIGHT, four rows a side, action bar
## along the bottom where a thumb reaches.
##
## The screen owns NO rules. Which skills are usable, which targets are legal and what a
## taunt permits all come from [BattleEngine] and [BattleTargeting]; the screen only asks
## and draws. That is deliberate: the moment a view re-derives a rule, it can disagree with
## the engine, and the player sees a target they are then not allowed to hit.
##
## Rendering is driven by [member BattleEngine.events], drained after every action, rather
## than by polling state (ADR-0008 forbids `view_state_polling`).
class_name BattleScreen
extends Screen

const UnitPanelScript := preload("res://src/ui/battle/unit_panel.gd")
const BattleTargetingScript := preload("res://src/core/battle_v1/targeting.gd")
const UnitInfoModalScript := preload("res://src/ui/battle/unit_info_modal.gd")

## Emitted once the battle resolves, so whatever pushed this screen can hand out rewards
## and pop back. Carries the [enum BattleEngine.Outcome].
signal battle_finished(outcome: int)

## Emitted when the player walks out mid-battle. The OWNER decides what leaving costs
## (v1 settles it as a defeat — §6 keeps whatever already dropped); the screen only asks.
signal exit_requested

const SQUAD_SIZE := 4
const MIN_BUTTON_HEIGHT := 44  ## touch minimum, technical-preferences.md

## Shared battlefield used by any stage that has not been given its own art.
const DEFAULT_BACKGROUND := "res://assets/art/battle/battle_arena_background.png"

## Scrim over the battlefield art. Low because the shipped backdrops are authored mid-to-dark
## and desaturated for exactly this purpose (design/v1/battle-background-prompts.md); the old
## 0.62 dated from a bright stock backdrop and now just buries the floor detail twice over.
const BACKDROP_DIM := 0.28

var engine: BattleEngine = null

## The stage being fought, set before [method setup] so the screen can draw its battlefield.
## Null is legal — the screen falls back to the shared art rather than rendering on black.
var stage: StageDef = null

var _ctx: ServiceContext = null
var _skills: Dictionary = {}

var _player_panels: Array[UnitPanel] = []
var _enemy_panels: Array[UnitPanel] = []

var _arena: Control
var _banner: Label
var _round_label: Label
var _wave_label: Label
var _turn_strip: HBoxContainer
var _log_label: Label
var _skill_bar: HBoxContainer
var _auto_toggle: CheckButton

## Which fight of a multi-fight stage this is (1-based) and how many there are. Drawn as
## a chip beside the banner so a dungeon run reads as a journey with a visible end rather
## than an unexplained second battle.
var _wave: int = 1
var _wave_count: int = 1

## The skill awaiting a target, or null when the player has not chosen one yet.
var _pending_skill: SkillDef = null

## The skill whose card is highlighted and whose info box is open. Wider than
## [member _pending_skill]: an uncharged ult can be SELECTED (read about) but never
## pending (armed). Cleared when the action fires or the selection is tapped again.
var _selected_skill_id: StringName = &""

## The floating skill-info panel at the top of the screen, and its text parts.
var _info_box: PanelContainer
var _info_glyph_slot: Control
var _info_title: Label
var _info_desc: Label
var _info_detail: Label

## The open unit modal, so a second tap re-uses rather than stacks.
var _unit_modal: UnitInfoModal = null

## How many events have already been rendered, so a drain never replays the whole battle.
var _events_drawn: int = 0

var _auto_enabled: bool = false

## Seconds of breathing room around each non-player action. The dial the whole battle
## rhythm hangs off: at 0 the screen collapses to the old fully-synchronous resolution,
## which is what headless tests set — a test must never wait on theatre.
var turn_pace: float = 0.55

## True while the paced playback coroutine is walking turns; input that would submit a
## second action is ignored until the stage is quiet again.
var _playback_running: bool = false

## unit_id -> display name, rebuilt per battle so the log and floats never leak raw ids.
var _display_names: Dictionary = {}


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background(_background_path(), BACKDROP_DIM)
	_build_layout()


## This stage's battlefield, or the shared one.
##
## Falls back on a MISSING file as well as on an empty field: there is no stage validator, so
## a typo in `background_path` would otherwise ship as a battle fought on a black screen.
func _background_path() -> String:
	if stage == null or stage.background_path.is_empty():
		return DEFAULT_BACKGROUND
	if not ResourceLoader.exists(stage.background_path):
		push_warning("Stage '%s' names a missing background '%s' — using the default."
			% [stage.id, stage.background_path])
		return DEFAULT_BACKGROUND
	return stage.background_path


## Tell the screen where it sits in a multi-fight stage, before [method begin_battle].
## Separate from begin_battle's signature so single-fight callers never think about waves.
func set_wave(wave: int, count: int) -> void:
	_wave = maxi(1, wave)
	_wave_count = maxi(1, count)
	if _wave_label != null:
		# Always shown — WAVE 1/1 included. A label that only sometimes exists reads as
		# a UI misconfiguration, not as information.
		_wave_label.text = "WAVE %d/%d" % [_wave, _wave_count]
		_wave_label.visible = true


## Start a battle. Separate from [method setup] because a screen is set up once but may
## run several battles (a dungeon run is a sequence of them, and ult charge carries
## between — §3.4b).
func begin_battle(p_engine: BattleEngine, skill_table: Dictionary) -> void:
	engine = p_engine
	_skills = skill_table
	_events_drawn = 0
	_pending_skill = null
	_selected_skill_id = &""
	_hide_skill_info()

	# Everything fielded in a battle the player watches is discovered — this is what
	# turns an enemy's silhouette into a sprite in the unit modal (DiscoveryCodex).
	if _ctx != null and _ctx.codex != null:
		for u in engine.player_units + engine.enemy_units:
			_ctx.codex.mark_seen(u.species_id, u.art_mark)

	_display_names.clear()
	for u in engine.player_units + engine.enemy_units:
		_display_names[u.unit_id] = u.display_name

	_bind_panels(engine.player_units, _player_panels)
	_bind_panels(engine.enemy_units, _enemy_panels)
	_layout_arena()

	engine.start()
	_drain_events()
	_refresh_all()
	_advance_if_not_player_turn()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

## Height of the band the figures stand in. Fixed rather than expanding: the empty scene
## above it is the battlefield, and the action controls below it must always be on screen.
const ARENA_HEIGHT := 392.0

## Width of a figure's tap target.
const SLOT_WIDTH := 108.0

## Where each squad slot stands, as fractions of the arena, for the LEFT side; the right
## side is mirrored (1 - x).
##
## Every slot on a side shares ONE x, so a side is a single vertical line — no figure ever
## stands in front of another and nothing is occluded. Depth is carried by the y step plus a
## per-row sprite height: the row nearest the bottom is nearest the camera and is drawn
## largest. This requires battlefield art with a deep receding floor (see
## design/v1/battle-background-prompts.md) — on a shallow floor the top row floats.
##
## [x, feet_y, sprite_height]
const COLUMN_X := 0.16
const FORMATION: Array = [
	[COLUMN_X, 0.990, 94.0],
	[COLUMN_X, 0.735, 88.0],
	[COLUMN_X, 0.480, 82.0],
	[COLUMN_X, 0.230, 76.0],
]


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets := _safe_insets()

	# A soft ink gradient behind the header, so the strip and banner sit on composed
	# ground instead of floating raw over the skybox.
	var header_shade := TextureRect.new()
	var shade_gradient := Gradient.new()
	shade_gradient.set_color(0, Color(UIPalette.INK, 0.85))
	shade_gradient.set_color(1, Color(UIPalette.INK, 0.0))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = shade_gradient
	shade_texture.fill_from = Vector2(0, 0)
	shade_texture.fill_to = Vector2(0, 1)
	header_shade.texture = shade_texture
	header_shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_shade.offset_bottom = 132 + insets.x
	header_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_shade)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	# Top strip: wave chip on the left, turn banner in the middle, auto on the right —
	# the auto toggle lives up here (the genre-standard corner for it) so the bottom of
	# the screen belongs entirely to the skill cards.
	var top := MarginContainer.new()
	top.add_theme_constant_override("margin_top", int(insets.x) + 4)
	top.add_theme_constant_override("margin_left", 8)
	top.add_theme_constant_override("margin_right", 8)
	root.add_child(top)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top.add_child(top_row)

	_wave_label = Label.new()
	_wave_label.text = "WAVE %d/%d" % [_wave, _wave_count]
	_wave_label.add_theme_font_override("font", UIPalette.display_font())
	_wave_label.add_theme_font_size_override("font_size", 11)
	_wave_label.add_theme_color_override("font_color", UIPalette.CYAN)
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_wave_label)

	# The banner is two lines: a small ROUND caption over the actor's name in bold —
	# the header reads as a title block, not a debug string.
	var banner_column := VBoxContainer.new()
	banner_column.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_column.add_theme_constant_override("separation", 0)
	banner_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(banner_column)

	_round_label = Label.new()
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 9)
	_round_label.add_theme_color_override("font_color", UIPalette.MUTED)
	banner_column.add_child(_round_label)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_override("font", UIPalette.bold_font())
	_banner.add_theme_font_size_override("font_size", 15)
	banner_column.add_child(_banner)

	# Exit lives where a mode flag would be a waste of the corner: walking out is a real
	# decision, and the corner is where every mobile player looks for the door.
	var exit_button := Button.new()
	exit_button.text = "EXIT"
	exit_button.add_theme_font_override("font", UIPalette.display_font())
	exit_button.add_theme_font_size_override("font_size", 11)
	exit_button.add_theme_color_override("font_color", UIPalette.MUTED)
	exit_button.add_theme_color_override("font_pressed_color", UIPalette.CORAL)
	exit_button.add_theme_stylebox_override("normal",
		UIPalette.tech_button(Color(UIPalette.LINE, 0.7)))
	exit_button.add_theme_stylebox_override("hover",
		UIPalette.tech_button(Color(UIPalette.LINE, 0.7)))
	exit_button.add_theme_stylebox_override("pressed",
		UIPalette.tech_button(UIPalette.CORAL, "pressed"))
	exit_button.add_theme_stylebox_override("focus", UIPalette.empty())
	exit_button.custom_minimum_size = Vector2(64, MIN_BUTTON_HEIGHT)
	_connect_owned(exit_button.pressed, Callable(self, "_on_exit_pressed"))
	top_row.add_child(exit_button)

	# The action-order strip (the genre's HSR-style queue, laid horizontally for
	# portrait): who moves next this round, current actor first and largest.
	var strip_margin := MarginContainer.new()
	strip_margin.add_theme_constant_override("margin_left", 8)
	strip_margin.add_theme_constant_override("margin_right", 8)
	root.add_child(strip_margin)

	_turn_strip = HBoxContainer.new()
	_turn_strip.add_theme_constant_override("separation", 4)
	_turn_strip.alignment = BoxContainer.ALIGNMENT_BEGIN
	_turn_strip.custom_minimum_size = Vector2(0, TURN_CHIP + 4)
	strip_margin.add_child(_turn_strip)

	# The empty upper scene. Everything below the arena is fixed-height, so this is the one
	# element that absorbs a taller phone — which is what keeps the action bar on screen.
	var sky := Control.new()
	sky.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sky)

	# The battlefield band: figures are positioned absolutely inside it (see _layout_arena),
	# not stacked by a container, because a formation is a picture rather than a list.
	_arena = Control.new()
	_arena.custom_minimum_size = Vector2(0, ARENA_HEIGHT)
	_arena.resized.connect(_layout_arena)
	root.add_child(_arena)

	_build_side(_player_panels)
	_build_side(_enemy_panels)

	_log_label = Label.new()
	_log_label.add_theme_font_size_override("font_size", 9)
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(0, 26)
	root.add_child(_log_label)

	# The action bar: one card per skill, thumb-height, padded off the screen edges.
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 8)
	bar_margin.add_theme_constant_override("margin_right", 8)
	bar_margin.add_theme_constant_override("margin_bottom", int(insets.y) + 8)
	root.add_child(bar_margin)

	_skill_bar = HBoxContainer.new()
	_skill_bar.add_theme_constant_override("separation", 6)
	_skill_bar.custom_minimum_size = Vector2(0, SKILL_CARD_HEIGHT)
	bar_margin.add_child(_skill_bar)

	_build_info_box(insets)

	# Auto FLOATS above the ult card (the bar's right end): the two "let it play"
	# controls share one corner of the thumb zone. Floating rather than a VBox row, so
	# it costs the battlefield no height — the arena must never shrink for chrome.
	_auto_toggle = CheckButton.new()
	_auto_toggle.text = "Auto"
	_auto_toggle.flat = true
	_auto_toggle.add_theme_font_size_override("font_size", 11)
	_auto_toggle.add_theme_stylebox_override("normal", UIPalette.empty())
	_auto_toggle.add_theme_stylebox_override("hover", UIPalette.empty())
	_auto_toggle.add_theme_stylebox_override("pressed", UIPalette.empty())
	_auto_toggle.add_theme_stylebox_override("hover_pressed", UIPalette.empty())
	_auto_toggle.add_theme_stylebox_override("focus", UIPalette.empty())
	_auto_toggle.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	_auto_toggle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_auto_toggle.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_auto_toggle.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_auto_toggle.offset_right = -14
	_auto_toggle.offset_bottom = -(SKILL_CARD_HEIGHT + int(insets.y) + 12)
	_connect_owned(_auto_toggle.toggled, Callable(self, "_on_auto_toggled"))
	add_child(_auto_toggle)


## The floating skill-info panel. A sibling of the main column, anchored under the top
## strip, so opening it never reflows the battlefield — the figures must not jump when
## the player is lining up a tap.
func _build_info_box(insets: Vector2) -> void:
	_info_box = PanelContainer.new()
	_info_box.add_theme_stylebox_override("panel",
		UIPalette.panel(UIPalette.CYAN_DARK, Color(UIPalette.PANEL, 0.94)))
	_info_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info_box.offset_left = 10
	_info_box.offset_right = -10
	_info_box.offset_top = insets.x + 58
	_info_box.grow_vertical = Control.GROW_DIRECTION_END
	_info_box.visible = false
	add_child(_info_box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_info_box.add_child(column)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 5)
	column.add_child(title_row)

	_info_glyph_slot = Control.new()
	_info_glyph_slot.custom_minimum_size = Vector2(14, 14)
	title_row.add_child(_info_glyph_slot)

	_info_title = Label.new()
	_info_title.add_theme_font_override("font", UIPalette.display_font())
	_info_title.add_theme_font_size_override("font_size", 13)
	title_row.add_child(_info_title)

	_info_desc = Label.new()
	_info_desc.add_theme_font_size_override("font_size", 9)
	_info_desc.add_theme_color_override("font_color", UIPalette.MUTED)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_info_desc)

	_info_detail = Label.new()
	_info_detail.add_theme_font_size_override("font_size", 10)
	_info_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_info_detail)


func _build_side(into: Array[UnitPanel]) -> void:
	for i in SQUAD_SIZE:
		var panel := UnitPanelScript.new()
		_connect_owned(panel.tapped, Callable(self, "_on_unit_tapped"))
		_arena.add_child(panel)
		into.append(panel)


## Place the eight figures in their formation. Called on every arena resize rather than once,
## so the picture survives a rotation or a different phone.
func _layout_arena() -> void:
	if _arena == null:
		return
	var w := _arena.size.x
	var h := _arena.size.y
	if w <= 0.0 or h <= 0.0:
		return
	for i in SQUAD_SIZE:
		_place(_player_panels[i], FORMATION[i], w, h, false)
		_place(_enemy_panels[i], FORMATION[i], w, h, true)


func _place(panel: UnitPanel, spot: Array, w: float, h: float, mirrored: bool) -> void:
	var sprite_h: float = float(spot[2])
	panel.set_display_height(sprite_h)
	var panel_h: float = sprite_h + 10.0  # the hairline bars under the feet
	panel.size = Vector2(SLOT_WIDTH, panel_h)

	var fx: float = (1.0 - float(spot[0])) if mirrored else float(spot[0])
	var feet_y: float = h * float(spot[1])
	panel.position = Vector2(
		clampf(w * fx - SLOT_WIDTH * 0.5, 0.0, maxf(0.0, w - SLOT_WIDTH)),
		feet_y - panel_h)


## Bind up to SQUAD_SIZE units into a column, hiding the leftover rows. Enemies number
## 1–4 (§3.1), so empty rows are the normal case, not an error.
func _bind_panels(units: Array, panels: Array[UnitPanel]) -> void:
	for i in panels.size():
		var panel: UnitPanel = panels[i]
		if i < units.size():
			var u: BattleUnit = units[i]
			panel.visible = true
			panel.set_ult_cost(_ult_cost_of(u))
			panel.bind(u)
		else:
			panel.visible = false
			panel.unit = null


func _ult_cost_of(u: BattleUnit) -> int:
	if not u.has_ultimate():
		return 100
	var s: SkillDef = _skills.get(u.ultimate_skill)
	return s.charge_cost if s != null else 100


# ---------------------------------------------------------------------------
# Turn flow
# ---------------------------------------------------------------------------

## Let the engine run every turn the player does not own — enemies always, and the
## player's own units when auto is on. Stops as soon as a decision is the player's.
##
## At [member turn_pace] 0 this resolves synchronously (tests, offline). Otherwise it
## hands off to the paced playback coroutine, so the battle opens on a quiet field and
## every action — enemy AND auto — is watched happening rather than reported done.
func _advance_if_not_player_turn() -> void:
	if turn_pace > 0.0:
		_run_paced_playback()
		return
	while not engine.is_over():
		var actor := engine.current_actor()
		if actor == null:
			break
		if actor.side == BattleUnit.Side.PLAYER and not _auto_enabled:
			break
		engine.take_auto_action()
		_drain_events()
	_refresh_all()
	if engine.is_over():
		_finish()


## The paced walk: present anything already emitted (the player's own action), then take
## and present each non-player turn with a beat before it. Exits back to the player's
## input, or into _finish(). Fire-and-forget async — re-entry is blocked by the flag.
func _run_paced_playback() -> void:
	if _playback_running:
		return
	_playback_running = true
	await _present_new_events()
	_refresh_all()
	while engine != null and is_inside_tree() and not engine.is_over():
		var actor := engine.current_actor()
		if actor == null:
			break
		if actor.side == BattleUnit.Side.PLAYER and not _auto_enabled:
			break
		await _beat(turn_pace)
		if engine == null or not is_inside_tree():
			return
		engine.take_auto_action()
		await _present_new_events()
		_refresh_all()
	_playback_running = false
	if engine != null and engine.is_over():
		_finish()
	_refresh_all()


func _beat(seconds: float) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


## Play the not-yet-presented engine events one at a time: the attacker lunges, the
## victim blinks and its number rises, the log narrates — each on its own beat, so a
## turn reads as a sentence rather than a lump sum.
func _present_new_events() -> void:
	while engine != null and _events_drawn < engine.events.size():
		var event: Dictionary = engine.events[_events_drawn]
		_events_drawn += 1
		var line := _describe(event)
		if line != "":
			_log_label.text = line
		match event.get(&"event", &""):
			&"skill_used", &"ultimate_fired":
				var actor_panel := _panel_of(event.get(&"unit", &""))
				if actor_panel != null and actor_panel.unit != null:
					actor_panel.play_lunge(
						1.0 if actor_panel.unit.side == BattleUnit.Side.PLAYER else -1.0)
				await _beat(0.34)
			&"damaged":
				_float_for_event(event, 0)
				await _beat(0.30)
			&"healed", &"shielded", &"stunned":
				_float_for_event(event, 0)
				await _beat(0.26)
			&"destroyed":
				var dead_panel := _panel_of(event.get(&"unit", &""))
				if dead_panel != null:
					dead_panel.refresh()
				await _beat(0.30)
			_:
				pass


func _finish() -> void:
	_banner.text = _outcome_text(engine.outcome)
	# Emptied, never hidden: the bar's row keeps its height so the battlefield doesn't
	# jump on the final frame (the reward screen replaces this whole view anyway).
	for child in _skill_bar.get_children():
		_skill_bar.remove_child(child)
		child.queue_free()
	_clear_selection()
	battle_finished.emit(engine.outcome)


func _outcome_text(outcome: int) -> String:
	match outcome:
		BattleEngine.Outcome.PLAYER_WON: return "VICTORY"
		BattleEngine.Outcome.ENEMY_WON: return "DEFEAT"
		BattleEngine.Outcome.DRAW: return "STALEMATE"
	return ""


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_exit_pressed() -> void:
	exit_requested.emit()


func _on_auto_toggled(pressed: bool) -> void:
	_auto_enabled = pressed
	_clear_selection()
	if pressed:
		_advance_if_not_player_turn()
	else:
		_refresh_all()


## Tapping a skill SELECTS it: the card highlights and the info box opens. What the
## selection then means depends on the skill:
##   - usable single-target: armed; the next unit tap resolves it (§3.3 — the player
##     picks the target).
##   - usable auto-target (AoE, self, lowest-HP): a second tap on the same card fires
##     it. The confirm tap exists so the info box can be read before committing.
##   - uncharged ult: info only — tappable so the player can always read their ult.
## Tapping the selected card again deselects.
func _on_skill_pressed(skill_id: StringName) -> void:
	if engine == null or engine.is_over() or _playback_running:
		return
	var actor := engine.current_actor()
	if actor == null or actor.side != BattleUnit.Side.PLAYER:
		return
	var skill: SkillDef = _skills.get(skill_id)
	if skill == null:
		return
	var usable := _usable_ids(actor).has(skill_id)

	if _selected_skill_id == skill_id:
		if usable and not skill.is_single_target():
			_submit(skill, null)
			return
		_clear_selection()
		_refresh_all()
		return

	_selected_skill_id = skill_id
	_pending_skill = skill if (usable and skill.is_single_target()) else null
	_show_skill_info(skill, actor)
	_refresh_all()


## Tapping a unit resolves the armed skill when the unit is a legal target; any other
## unit tap opens the full info modal — which is also how enemies are inspected.
func _on_unit_tapped(unit: BattleUnit) -> void:
	if engine == null:
		return
	if _pending_skill != null and not engine.is_over() and not _playback_running:
		var actor := engine.current_actor()
		if actor != null and engine.legal_targets(actor, _pending_skill).has(unit):
			_submit(_pending_skill, unit)
			return
	_open_unit_modal(unit)


func _open_unit_modal(unit: BattleUnit) -> void:
	if _unit_modal != null:
		return
	_unit_modal = UnitInfoModalScript.new()
	_unit_modal.closed.connect(func() -> void: _unit_modal = null)
	add_child(_unit_modal)
	_unit_modal.open(unit, _ctx, _ult_cost_of(unit))


func _usable_ids(actor: BattleUnit) -> Dictionary:
	var ids: Dictionary = {}
	for s in engine.available_skills(actor):
		ids[s.id] = true
	return ids


func _clear_selection() -> void:
	_selected_skill_id = &""
	_pending_skill = null
	_hide_skill_info()


func _submit(skill: SkillDef, target: BattleUnit) -> void:
	# The engine is the authority and may refuse — a target legal when the player tapped
	# can have died to a damage-over-time tick since. A refusal is not an error: the screen
	# simply redraws and the player picks again.
	if not engine.submit_action(skill.id, target):
		_clear_selection()
		_refresh_all()
		return
	_clear_selection()
	if turn_pace > 0.0:
		# The playback coroutine presents the player's own action first, then walks the
		# replies — one paced rhythm for everything that happens on the field.
		_advance_if_not_player_turn()
		return
	_drain_events()
	_advance_if_not_player_turn()


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	var actor := engine.current_actor() if engine != null else null
	for panel in _player_panels + _enemy_panels:
		if panel.unit == null:
			continue
		panel.set_active_turn(actor != null and panel.unit == actor)
		panel.set_targetable(_is_targetable(panel.unit, actor))
		panel.refresh()
	_refresh_banner(actor)
	_rebuild_turn_strip(actor)
	_rebuild_skill_bar(actor)


# ---------------------------------------------------------------------------
# Turn order strip
# ---------------------------------------------------------------------------

## Chip edge — ONE size for everyone. Whose turn it is reads from the border, never from
## a size jump: uniform boxes are what makes the strip scannable as a queue.
const TURN_CHIP := 32

## The queue as it was last drawn, so a redraw with the same shape does not replay the
## entrance animation on every refresh.
var _turn_strip_ids: Array = []


## Redraw the action-order strip: everyone still to move this round, current actor
## first. When the queue actually advances, the chips ease in (scale + fade, softly
## staggered) instead of popping — the row reads as moving forward.
func _rebuild_turn_strip(actor: BattleUnit) -> void:
	if _turn_strip == null:
		return
	if engine == null or engine.is_over():
		_turn_strip.visible = false
		_turn_strip_ids = []
		return

	var upcoming := engine.upcoming_actors()
	var ids := upcoming.map(func(u): return u.unit_id)
	var changed: bool = ids != _turn_strip_ids
	_turn_strip_ids = ids

	for child in _turn_strip.get_children():
		_turn_strip.remove_child(child)
		child.queue_free()
	_turn_strip.visible = true

	var index := 0
	for u in upcoming:
		var is_actor: bool = u == actor
		var chip := PanelContainer.new()
		var accent := UIPalette.CYAN if u.side == BattleUnit.Side.PLAYER else UIPalette.CORAL
		var box := UIPalette.panel(accent if is_actor else Color(accent, 0.40),
			Color(UIPalette.INK, 0.80))
		box.set_content_margin_all(2)
		if is_actor:
			box.set_border_width_all(2)
		chip.add_theme_stylebox_override("panel", box)
		chip.custom_minimum_size = Vector2(TURN_CHIP, TURN_CHIP)
		chip.pivot_offset = Vector2(TURN_CHIP, TURN_CHIP) * 0.5
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var face := TextureRect.new()
		face.texture = UnitPanelScript.art_texture(u.species_id, u.art_mark)
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.flip_h = u.side == BattleUnit.Side.ENEMY
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(face)
		_turn_strip.add_child(chip)

		if changed and turn_pace > 0.0:
			chip.modulate.a = 0.0
			chip.scale = Vector2(0.82, 0.82)
			var tween := chip.create_tween()
			tween.tween_interval(0.03 * index)
			tween.tween_property(chip, "modulate:a", 1.0, 0.14)
			tween.parallel().tween_property(chip, "scale", Vector2.ONE, 0.16) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		index += 1


## A unit is highlighted as targetable only while a skill is armed AND the engine agrees
## it is legal — which is what makes the taunt rule visible rather than a surprise
## rejection after the tap.
func _is_targetable(unit: BattleUnit, actor: BattleUnit) -> bool:
	if _pending_skill == null or actor == null:
		return false
	return engine.legal_targets(actor, _pending_skill).has(unit)


func _refresh_banner(actor: BattleUnit) -> void:
	if engine == null:
		return
	_round_label.text = "ROUND %d" % engine.round_number
	if engine.is_over():
		_round_label.text = ""
		_banner.text = _outcome_text(engine.outcome)
	elif _pending_skill != null:
		_banner.text = "Choose a target"
	elif actor != null:
		_banner.text = actor.display_name
	else:
		_banner.text = ""


## Rebuild the action bar for the current actor. Rebuilt rather than updated because the
## roster of usable skills changes every turn (cooldowns, charge, whether any legal target
## exists) and a stale button is a button that lies.
func _rebuild_skill_bar(actor: BattleUnit) -> void:
	for child in _skill_bar.get_children():
		# Deferred free would leave last turn's buttons in the bar alongside this turn's
		# for the rest of the frame — including ones that are no longer usable.
		_skill_bar.remove_child(child)
		child.queue_free()

	# Not the player's move: the bar goes EMPTY, never hidden. Hiding would collapse its
	# row and the whole battlefield column would jump downward every enemy turn — the
	# reserved space is what keeps the figures planted while the theatre plays.
	if engine == null or engine.is_over() or actor == null \
			or actor.side != BattleUnit.Side.PLAYER or _auto_enabled:
		return

	# available_skills() already filters by cooldown, charge and whether a legal target
	# exists, so the bar cannot offer something the engine would refuse.
	var usable := engine.available_skills(actor)
	var usable_ids: Dictionary = {}
	for s in usable:
		usable_ids[s.id] = true

	for sid in actor.skills:
		_add_skill_button(sid, usable_ids.has(sid), actor)
	if actor.has_ultimate():
		_add_skill_button(actor.ultimate_skill, usable_ids.has(actor.ultimate_skill),
			actor, true)


## Height of one skill card. Taller than the bare touch minimum because each card carries
## two lines — the name and its state — the way every shipped turn-based mobile RPG does.
const SKILL_CARD_HEIGHT := 58


## One card in the action bar: the skill's name over a one-line state readout (target
## shape, cooldown left, or ult charge). A Button rather than a custom Control so
## disabled/pressed behaviour and the tests' `child is Button` contract stay stock.
##
## The ULT card is never disabled: an uncharged ult still opens its info on tap (the
## player may always read their own kit); firing stays gated by `enabled` in
## [method _on_skill_pressed]'s usable check, not by the widget.
func _add_skill_button(skill_id: StringName, enabled: bool, actor: BattleUnit,
		is_ult := false) -> void:
	var skill: SkillDef = _skills.get(skill_id)
	if skill == null:
		return
	var selected := skill_id == _selected_skill_id
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, SKILL_CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not enabled and not is_ult
	var accent := UIPalette.AMBER if is_ult else UIPalette.LINE
	var normal_state := "selected" if selected else "normal"
	button.add_theme_stylebox_override("normal", _card_style(accent, normal_state, is_ult))
	button.add_theme_stylebox_override("hover", _card_style(accent, normal_state, is_ult))
	button.add_theme_stylebox_override("pressed", _card_style(accent, "pressed", is_ult))
	button.add_theme_stylebox_override("disabled", _card_style(accent, "disabled", is_ult))
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.pressed.connect(Callable(self, "_on_skill_pressed").bind(skill_id))

	# The card's two lines. Centered as a column; mouse_filter IGNORE so every pixel of
	# the card is still the button's tap target.
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var name_tone := UIPalette.TEXT
	if not enabled:
		name_tone = UIPalette.DISABLED
	elif is_ult:
		name_tone = UIPalette.AMBER

	# Name row: the skill's icon beside its name, centered as a pair. The row clips at
	# the card's edge — clip_text on the LABEL would zero its minimum width inside an
	# HBox and the name would vanish entirely.
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 4)
	name_row.clip_contents = true
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_row)

	var glyph_kind := Glyph.for_skill(skill)
	name_row.add_child(Glyph.make(glyph_kind, 12.0,
		_glyph_colour(glyph_kind, name_tone) if enabled else UIPalette.DISABLED))

	var name_label := Label.new()
	name_label.text = skill.display_name
	name_label.add_theme_font_override("font", UIPalette.display_font())
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_color_override("font_color", name_tone)
	name_row.add_child(name_label)

	var state_label := Label.new()
	state_label.text = _skill_state_text(skill, actor, is_ult)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 9)
	state_label.clip_text = true
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.add_theme_color_override("font_color",
		UIPalette.AMBER if (is_ult and enabled) else UIPalette.MUTED)
	column.add_child(state_label)

	_skill_bar.add_child(button)


## The one-line state readout under a skill's name. The rule: say why a card is dark
## (cooling down, still charging), otherwise say what tapping it will aim at.
func _skill_state_text(skill: SkillDef, actor: BattleUnit, is_ult: bool) -> String:
	if is_ult:
		if actor.is_ultimate_ready(skill.charge_cost):
			return "READY"
		return "CHARGE %d%%" % int(actor.ultimate_charge * 100.0 / maxf(1.0, skill.charge_cost))
	var cooling: int = int(actor.cooldowns.get(skill.id, 0))
	if cooling > 0:
		return "COOLDOWN %d" % cooling
	if not skill.is_single_target():
		return "AREA"
	return "SINGLE TARGET" if skill.targets_enemies() else "ALLY"


## Icon tints: each skill family keeps one colour everywhere it appears, so the icon
## alone carries meaning before the name is read.
const GLYPH_COLOURS := {
	&"star": UIPalette.AMBER,
	&"bolt": UIPalette.CYAN,
	&"sword": Color(1.0, 0.80, 0.70),
	&"wrench": UIPalette.GREEN,
	&"shield": Color(0.45, 0.70, 0.95),
	&"arrow_up": UIPalette.GREEN,
	&"arrow_down": UIPalette.CORAL,
	&"sparkle": UIPalette.CYAN,
	&"core": UIPalette.AMBER,
}


func _glyph_colour(kind: StringName, fallback: Color) -> Color:
	return GLYPH_COLOURS.get(kind, fallback)


## Card styling: the skewed tech-card language from UIPalette. Ults keep their amber
## edge even while disabled — a charging ultimate is a promise, not a dead control. The
## selected card gets the cyan frame: the accent the whole UI uses for "this one".
func _card_style(accent: Color, state: String, is_ult: bool) -> StyleBoxFlat:
	var box := UIPalette.tech_button(accent, state)
	if state == "disabled" and not is_ult:
		box.border_color = Color(UIPalette.LINE_SOFT, 0.8)
	return box


# ---------------------------------------------------------------------------
# Skill info box
# ---------------------------------------------------------------------------

## Human label per scaling stat, for the damage line.
const STAT_LABELS := {
	&"physical_power": "Physical Power",
	&"energy_power": "Energy Power",
	&"processing": "Processing",
}

const TARGET_LABELS := {
	SkillDef.TargetMode.SELF: "Self",
	SkillDef.TargetMode.SINGLE_ALLY: "One ally",
	SkillDef.TargetMode.ALL_ALLIES: "All allies",
	SkillDef.TargetMode.LOWEST_HP_ALLY: "Most damaged ally",
	SkillDef.TargetMode.SINGLE_ENEMY: "One enemy",
	SkillDef.TargetMode.ALL_ENEMIES: "All enemies",
	SkillDef.TargetMode.RANDOM_ENEMY: "Random enemy",
}


func _show_skill_info(skill: SkillDef, actor: BattleUnit) -> void:
	for child in _info_glyph_slot.get_children():
		_info_glyph_slot.remove_child(child)
		child.queue_free()
	var glyph_kind := Glyph.for_skill(skill)
	_info_glyph_slot.add_child(Glyph.make(glyph_kind, 14.0,
		_glyph_colour(glyph_kind, UIPalette.TEXT)))
	_info_title.text = skill.display_name
	_info_desc.text = skill.description
	_info_desc.visible = not skill.description.is_empty()
	_info_detail.text = "\n".join(_skill_info_lines(skill, actor))
	_info_box.visible = true


func _hide_skill_info() -> void:
	if _info_box != null:
		_info_box.visible = false


## The numbers: one line per effect, then targeting and cost. Magnitudes come from
## [method BattleEngine.preview_magnitude] — the engine's own formula, not a UI copy —
## and are pre-defense, because no target is chosen yet.
func _skill_info_lines(skill: SkillDef, actor: BattleUnit) -> PackedStringArray:
	var lines: PackedStringArray = []
	var magnitude := engine.preview_magnitude(actor, skill)
	for effect in skill.effects:
		match int(effect.get("kind", SkillDef.EffectKind.INVALID)):
			SkillDef.EffectKind.DAMAGE:
				lines.append("Damage ≈ %d  (%d%% %s, before defense)" % [magnitude,
					skill.power_percent, STAT_LABELS.get(skill.scaling_stat, "Power")])
			SkillDef.EffectKind.HEAL:
				lines.append("Repairs ≈ %d structure" % magnitude)
			SkillDef.EffectKind.SHIELD:
				lines.append("Shields ≈ %d" % magnitude)
			SkillDef.EffectKind.APPLY_STATUS:
				lines.append("Applies %s (%d turns)" % [
					StatusEffect.kind_name(int(effect.get("status", 0))),
					int(effect.get("turns", 1))])
			SkillDef.EffectKind.CLEANSE:
				lines.append("Cleanses debuffs")
			SkillDef.EffectKind.REVIVE:
				lines.append("Revives at %d%% structure" % int(effect.get("percent", 25)))
	lines.append("Target: %s" % TARGET_LABELS.get(skill.target_mode, "—"))
	if skill.is_ultimate:
		lines.append("Charge: %d / %d" % [mini(actor.ultimate_charge, skill.charge_cost),
			skill.charge_cost])
	elif skill.cooldown > 0:
		lines.append("Cooldown: %d turns" % skill.cooldown)
	return lines


## Turn newly-emitted engine events into the on-screen log. Only events past
## [member _events_drawn] are read, so a drain never replays the battle.
func _drain_events() -> void:
	if engine == null:
		return
	var lines: PackedStringArray = []
	var float_order := 0
	while _events_drawn < engine.events.size():
		var event: Dictionary = engine.events[_events_drawn]
		if _float_for_event(event, float_order):
			float_order += 1
		var line := _describe(event)
		if line != "":
			lines.append(line)
		_events_drawn += 1
	if not lines.is_empty():
		_log_label.text = "\n".join(lines.slice(maxi(0, lines.size() - 2)))


# ---------------------------------------------------------------------------
# Floating combat numbers
# ---------------------------------------------------------------------------

const FLOAT_RISE := 34.0
const FLOAT_DURATION := 0.9
## Events resolve synchronously in a batch (a whole enemy round can land in one drain),
## so each popup starts a beat after the previous one — a cascade the eye can follow
## instead of eight numbers appearing in the same frame.
const FLOAT_STAGGER := 0.22

const FLOAT_DAMAGE_COLOUR := Color(1.0, 0.92, 0.85)
const FLOAT_CRIT_COLOUR := UIPalette.AMBER
const FLOAT_HEAL_COLOUR := UIPalette.GREEN
const FLOAT_SHIELD_COLOUR := Color(0.45, 0.70, 0.95)


## Spawn the floating number for one engine event, if it deserves one. Returns whether
## it did, so the caller advances the cascade order only for visible popups.
func _float_for_event(event: Dictionary, order: int) -> bool:
	match event.get(&"event", &""):
		&"damaged":
			var crit: bool = event.get(&"crit", false)
			var text := "-%d" % int(event.get(&"amount", 0)) + ("!" if crit else "")
			_spawn_float(event.get(&"unit", &""), text,
				FLOAT_CRIT_COLOUR if crit else FLOAT_DAMAGE_COLOUR, order, crit)
			var hit_panel := _panel_of(event.get(&"unit", &""))
			if hit_panel != null:
				hit_panel.flash_hit()
			return true
		&"healed":
			_spawn_float(event.get(&"unit", &""), "+%d" % int(event.get(&"amount", 0)),
				FLOAT_HEAL_COLOUR, order)
			return true
		&"shielded":
			_spawn_float(event.get(&"unit", &""), "+%d" % int(event.get(&"amount", 0)),
				FLOAT_SHIELD_COLOUR, order)
			return true
		&"stunned":
			_spawn_float(event.get(&"unit", &""), "STUNNED", FLOAT_CRIT_COLOUR, order)
			return true
	return false


func _panel_of(unit_id: StringName) -> UnitPanel:
	for panel in _player_panels + _enemy_panels:
		if panel.unit != null and panel.unit.unit_id == unit_id:
			return panel
	return null


## One rising, fading number above a unit's head. Crits are bigger — the reward for the
## roll is seeing it land. The label owns its tween and frees itself, so a popup never
## outlives the battle screen's interest in it.
func _spawn_float(unit_id: StringName, text: String, colour: Color, order: int,
		big := false) -> void:
	var panel := _panel_of(unit_id)
	if panel == null or _arena == null or not panel.visible:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UIPalette.bold_font())
	label.add_theme_font_size_override("font_size", 18 if big else 13)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", UIPalette.INK)
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	# Sized to the slot and centered over it, so the number hangs above the figure's head
	# without needing the label's own metrics (unknown until layout).
	label.size = Vector2(SLOT_WIDTH, 22)
	label.position = panel.position + Vector2((panel.size.x - SLOT_WIDTH) * 0.5, -18.0)
	label.modulate.a = 0.0
	_arena.add_child(label)

	var tween := label.create_tween()
	if order > 0:
		tween.tween_interval(order * FLOAT_STAGGER)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(label, "position:y", label.position.y - FLOAT_RISE,
		FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


## The name a player should read — never a raw content id. Units resolve through the
## per-battle map; skills through the table; anything unknown falls back to the id
## rather than an empty string, so a gap is visible instead of silent.
func _name_of(unit_id) -> String:
	return _display_names.get(unit_id, String(unit_id))


func _skill_name(skill_id) -> String:
	var skill: SkillDef = _skills.get(skill_id)
	return skill.display_name if skill != null else String(skill_id)


func _describe(event: Dictionary) -> String:
	match event.get(&"event", &""):
		&"skill_used":
			return "%s uses %s" % [_name_of(event.get(&"unit")), _skill_name(event.get(&"skill"))]
		&"ultimate_fired":
			return "%s unleashes %s!" % [_name_of(event.get(&"unit")),
				_skill_name(event.get(&"skill"))]
		&"damaged":
			var crit: String = " CRIT" if event.get(&"crit", false) else ""
			return "%s takes %d%s" % [_name_of(event.get(&"unit")), event.get(&"amount"), crit]
		&"healed":
			return "%s repairs %d" % [_name_of(event.get(&"unit")), event.get(&"amount")]
		&"destroyed":
			return "%s is destroyed" % _name_of(event.get(&"unit"))
		&"stunned":
			return "%s is stunned" % _name_of(event.get(&"unit"))
		&"revived":
			return "%s is back online" % _name_of(event.get(&"unit"))
	return ""
