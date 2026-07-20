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

## Emitted once the battle resolves, so whatever pushed this screen can hand out rewards
## and pop back. Carries the [enum BattleEngine.Outcome].
signal battle_finished(outcome: int)

const SQUAD_SIZE := 4
const MIN_BUTTON_HEIGHT := 44  ## touch minimum, technical-preferences.md

var engine: BattleEngine = null

var _ctx: ServiceContext = null
var _skills: Dictionary = {}

var _player_panels: Array[UnitPanel] = []
var _enemy_panels: Array[UnitPanel] = []

var _banner: Label
var _log_label: Label
var _skill_bar: HBoxContainer
var _auto_toggle: CheckButton

## The skill awaiting a target, or null when the player has not chosen one yet. This is
## the whole of the screen's interaction state — everything else is derived.
var _pending_skill: SkillDef = null

## How many events have already been rendered, so a drain never replays the whole battle.
var _events_drawn: int = 0

var _auto_enabled: bool = false


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/battle/battle_arena_background.png", 0.62)
	_build_layout()


## Start a battle. Separate from [method setup] because a screen is set up once but may
## run several battles (a dungeon run is a sequence of them, and ult charge carries
## between — §3.4b).
func begin_battle(p_engine: BattleEngine, skill_table: Dictionary) -> void:
	engine = p_engine
	_skills = skill_table
	_events_drawn = 0
	_pending_skill = null

	_bind_panels(engine.player_units, _player_panels)
	_bind_panels(engine.enemy_units, _enemy_panels)

	engine.start()
	_drain_events()
	_refresh_all()
	_advance_if_not_player_turn()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 12)
	root.add_child(_banner)

	var field := HBoxContainer.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 8)
	root.add_child(field)

	field.add_child(_build_column(_player_panels))
	field.add_child(_build_column(_enemy_panels))

	_log_label = Label.new()
	_log_label.add_theme_font_size_override("font_size", 9)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(0, 28)
	root.add_child(_log_label)

	_skill_bar = HBoxContainer.new()
	_skill_bar.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	root.add_child(_skill_bar)

	_auto_toggle = CheckButton.new()
	_auto_toggle.text = "Auto"
	_auto_toggle.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	_connect_owned(_auto_toggle.toggled, Callable(self, "_on_auto_toggled"))
	root.add_child(_auto_toggle)


func _build_column(into: Array[UnitPanel]) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	for i in SQUAD_SIZE:
		var panel := UnitPanelScript.new()
		_connect_owned(panel.tapped, Callable(self, "_on_unit_tapped"))
		col.add_child(panel)
		into.append(panel)
	return col


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

## Let the engine run every turn the player does not own — enemies always, and the player's
## own units when auto is on. Stops as soon as a decision is the player's.
func _advance_if_not_player_turn() -> void:
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


func _finish() -> void:
	_banner.text = _outcome_text(engine.outcome)
	_skill_bar.visible = false
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

func _on_auto_toggled(pressed: bool) -> void:
	_auto_enabled = pressed
	_pending_skill = null
	if pressed:
		_advance_if_not_player_turn()
	else:
		_refresh_all()


## Tapping a skill arms it; the next unit tap resolves it. Two taps rather than one
## because a single-tap "use on best target" would remove the choice the design says is
## the player's (§3.3 — the player picks the target).
func _on_skill_pressed(skill_id: StringName) -> void:
	if engine == null or engine.is_over():
		return
	var actor := engine.current_actor()
	if actor == null or actor.side != BattleUnit.Side.PLAYER:
		return
	var skill: SkillDef = _skills.get(skill_id)
	if skill == null:
		return

	# A skill that picks its own target needs no second tap.
	if not skill.is_single_target():
		_submit(skill, null)
		return

	_pending_skill = skill
	_refresh_all()


func _on_unit_tapped(unit: BattleUnit) -> void:
	if _pending_skill == null or engine == null or engine.is_over():
		return
	_submit(_pending_skill, unit)


func _submit(skill: SkillDef, target: BattleUnit) -> void:
	# The engine is the authority and may refuse — a target legal when the player tapped
	# can have died to a damage-over-time tick since. A refusal is not an error: the screen
	# simply redraws and the player picks again.
	if not engine.submit_action(skill.id, target):
		_pending_skill = null
		_refresh_all()
		return
	_pending_skill = null
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
	_rebuild_skill_bar(actor)


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
	if engine.is_over():
		_banner.text = _outcome_text(engine.outcome)
	elif _pending_skill != null:
		_banner.text = "Choose a target for %s" % _pending_skill.display_name
	elif actor != null:
		_banner.text = "Round %d — %s" % [engine.round_number, actor.display_name]
	else:
		_banner.text = "Round %d" % engine.round_number


## Rebuild the action bar for the current actor. Rebuilt rather than updated because the
## roster of usable skills changes every turn (cooldowns, charge, whether any legal target
## exists) and a stale button is a button that lies.
func _rebuild_skill_bar(actor: BattleUnit) -> void:
	for child in _skill_bar.get_children():
		# Deferred free would leave last turn's buttons in the bar alongside this turn's
		# for the rest of the frame — including ones that are no longer usable.
		_skill_bar.remove_child(child)
		child.queue_free()

	if engine == null or engine.is_over() or actor == null \
			or actor.side != BattleUnit.Side.PLAYER or _auto_enabled:
		_skill_bar.visible = false
		return
	_skill_bar.visible = true

	# available_skills() already filters by cooldown, charge and whether a legal target
	# exists, so the bar cannot offer something the engine would refuse.
	var usable := engine.available_skills(actor)
	var usable_ids: Dictionary = {}
	for s in usable:
		usable_ids[s.id] = true

	for sid in actor.skills:
		_add_skill_button(sid, usable_ids.has(sid))
	if actor.has_ultimate():
		_add_skill_button(actor.ultimate_skill, usable_ids.has(actor.ultimate_skill), true)


func _add_skill_button(skill_id: StringName, enabled: bool, is_ult := false) -> void:
	var skill: SkillDef = _skills.get(skill_id)
	if skill == null:
		return
	var button := Button.new()
	button.text = ("★ " if is_ult else "") + skill.display_name
	button.custom_minimum_size = Vector2(0, MIN_BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Truncate a long skill name rather than letting it widen the bar past the screen edge —
	# an overflowing row puts the last button somewhere the thumb cannot reach.
	button.clip_text = true
	button.disabled = not enabled
	button.pressed.connect(Callable(self, "_on_skill_pressed").bind(skill_id))
	_skill_bar.add_child(button)


## Turn newly-emitted engine events into the on-screen log. Only events past
## [member _events_drawn] are read, so a drain never replays the battle.
func _drain_events() -> void:
	if engine == null:
		return
	var lines: PackedStringArray = []
	while _events_drawn < engine.events.size():
		var line := _describe(engine.events[_events_drawn])
		if line != "":
			lines.append(line)
		_events_drawn += 1
	if not lines.is_empty():
		_log_label.text = "\n".join(lines.slice(maxi(0, lines.size() - 2)))


func _describe(event: Dictionary) -> String:
	match event.get(&"event", &""):
		&"skill_used":
			return "%s uses %s" % [event.get(&"unit"), event.get(&"skill")]
		&"ultimate_fired":
			return "%s unleashes %s!" % [event.get(&"unit"), event.get(&"skill")]
		&"damaged":
			var crit: String = " CRIT" if event.get(&"crit", false) else ""
			return "%s takes %d%s" % [event.get(&"unit"), event.get(&"amount"), crit]
		&"healed":
			return "%s repairs %d" % [event.get(&"unit"), event.get(&"amount")]
		&"destroyed":
			return "%s is destroyed" % event.get(&"unit")
		&"stunned":
			return "%s is stunned" % event.get(&"unit")
		&"revived":
			return "%s is back online" % event.get(&"unit")
	return ""
