## BattleScreen — the turn-based combat view (ADR-0008 Screen; ADR-0007 drives the TBC).
##
## Production rewrite of prototypes/symbots-vertical-slice/battle_screen.gd (rules:
## prototype code is REWRITTEN, never imported). Differences from the slice:
##   - extends Screen; battle wiring moves from _ready() into setup(ctx)+begin_encounter().
##   - drives the persistent TBC autoload (ADR-0007 Option A), not a local RefCounted.
##   - subscribes via _connect_owned() so EXIT_TREE auto-disconnects (ADR-0008).
##   - on battle end it emits EventBus.encounter_resolved; ScreenManager tears this
##     screen down and restores the Overworld (ADR-0004 §3 keep-alive).
##   - DropSystem is constructed with ctx.inventory, so harvested parts persist into the
##     session inventory automatically and carry into the Workshop + the next fight.
##
## TWO PROMOTED SLICE HACKS (were unbuilt in src/, BUILD-PLAN Findings 1 & 2):
##   1. _make_basic_attack() — the always-available cost-0 MoveDef every Symbot swings.
##   2. the Part-Break subscriber — tallies per-region damage from hit_resolved and
##      calls TBC.note_break_event() when a region's cumulative damage crosses break_hp.
##
## Touch-first (≥56px targets, press-release, no hover-only). Signal-driven: bars refresh
## inside hit_resolved/battle_ended handlers, never polled in _process.
extends Screen

# Outcome ints (BattleController.Outcome): VICTORY=1, DEFEAT=2, FLED=3.
const OUTCOME_VICTORY := 1
const OUTCOME_DEFEAT := 2

const COL_ENEMY := Color(0.85, 0.30, 0.28)     # red — enemy structure
const COL_PLAYER := Color(0.32, 0.72, 0.40)    # green — player structure
const COL_ENERGY := Color(0.30, 0.55, 0.85)    # blue — energy
const COL_BREAK := Color(0.92, 0.70, 0.24)     # amber — break meter (harvest gate)

# --- injected context ---
var _ctx: ServiceContext
var _log: LogSink

# --- per-encounter wiring ---
var _atk: MoveDef
var _loadout                                   # SymbotLoadout
var _enemy_def: EnemyDef
var _enemy_spec: Dictionary = {}
var _encounter_type: int = 1
var _loot_pool: Array[PartDef] = []
var _drop_system: DropSystem
var _fired_events: Dictionary = {}

# --- Part-Break subscriber state (presentation glue over the pure core) ---
var _arm_break_hp: int = 0
var _head_break_hp: int = 0
var _arm_dmg: int = 0
var _head_dmg: int = 0
var _arm_broken: bool = false
var _head_broken: bool = false

# --- interaction state ---
var _current_target: StringName = &"arm"       # default nudges toward the harvest path
var _round_lines: Array[String] = []
var _battle_over: bool = false

# --- widget refs ---
var _enemy_name_label: Label
var _enemy_struct_bar: ProgressBar
var _enemy_struct_label: Label
var _arm_bar: ProgressBar
var _arm_label: Label
var _head_bar: ProgressBar
var _head_label: Label
var _log_label: Label
var _player_struct_bar: ProgressBar
var _player_struct_label: Label
var _player_energy_bar: ProgressBar
var _player_energy_label: Label
var _player_heat_label: Label
var _attack_btn: Button
var _target_btns: Dictionary = {}              # StringName sub_target -> Button

# --- reveal overlay ---
var _overlay: Control
var _overlay_title: Label
var _overlay_body: VBoxContainer
var _overlay_buttons: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


## Screen contract: cache deps + subscribe. The actual fight is kicked off by
## begin_encounter(), called by ScreenManager immediately after setup().
func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_log = ctx.log
	# ADR-0008: every subscription goes through _connect_owned for EXIT_TREE teardown.
	_connect_owned(TBC.hit_resolved, Callable(self, "_on_hit_resolved"))
	_connect_owned(TBC.battle_ended, Callable(self, "_on_battle_ended"))


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


# ---------------------------------------------------------------------------
# Encounter assembly — called by ScreenManager.enter_battle after setup()
# ---------------------------------------------------------------------------

## Resolve the enemy from EnemyDB, build the player loadout from ctx.build, and start
## the fight on the TBC. [param payload] = {enemy_id: StringName, encounter_type: int}.
func begin_encounter(payload: Dictionary) -> void:
	_encounter_type = int(payload.get("encounter_type", 1))
	var enemy_id := StringName(payload.get("enemy_id", &""))
	_enemy_def = EnemyDB.get_enemy(enemy_id)
	if _enemy_def == null:
		_log.error(&"battle_enemy_not_found", {"enemy_id": enemy_id})
		return

	# Player loadout, rebuilt from the live build so equips from the Workshop take effect.
	var core_inst: PartInstance = _ctx.build.get_equipped(PartDef.SlotType.CORE)
	var core_element = core_inst.part.element if core_inst != null else null
	_atk = _make_basic_attack(core_element)
	var part_defs: Array = []
	for slot in [PartDef.SlotType.CORE, PartDef.SlotType.LEGS, PartDef.SlotType.CHASSIS,
			PartDef.SlotType.CHIPSET, PartDef.SlotType.ENERGY_CELL, PartDef.SlotType.HEAD,
			PartDef.SlotType.ARMS, PartDef.SlotType.WEAPON]:
		var inst: PartInstance = _ctx.build.get_equipped(slot)
		if inst != null:
			part_defs.append(inst.part)
	_loadout = SymbotLoadout.make(0, _ctx.build.get_final_stat(), [_atk, null, null, null],
		_ctx.build.get_passive_pool(), core_element, part_defs)

	# Break gates + loot pool + a per-fight DropSystem (writes drops into the session
	# inventory). Pity is per-fight for the MVP — see TODO below.
	_arm_break_hp = _break_hp_for_region(_enemy_def, &"arm")
	_head_break_hp = _break_hp_for_region(_enemy_def, &"head")
	_loot_pool = _resolve_loot_pool(_enemy_def)
	# TODO(pity persistence): DropSystem pity resets each fight because the screen is
	#   queue_free()'d. Move DropSystem to a persistent owner to farm pity across fights.
	_drop_system = DropSystem.new(RngService.make_rng(), _ctx.balance, _log, _ctx.inventory)

	_enemy_spec = {
		"id": _enemy_def.id, "stats": _enemy_def.stats,
		"core_element": _enemy_def.core_element, "level": _enemy_def.level,
		"xp_value": _enemy_def.xp_value,
		"completion_bonus_xp": _enemy_def.completion_bonus_xp,
		"is_first_boss_defeat": false,
	}
	_enemy_name_label.text = "%s   Lv%d" % [_enemy_def.display_name, _enemy_def.level]

	_reset_encounter_state()
	TBC.start_battle([_loadout], _enemy_spec, _encounter_type, _ctx.synergy)
	_refresh()
	_log_label.text = "A %s moves into range. Break its ARM to harvest a part." % _enemy_def.display_name


func _reset_encounter_state() -> void:
	_arm_dmg = 0
	_head_dmg = 0
	_arm_broken = false
	_head_broken = false
	_battle_over = false
	_fired_events = {}
	_round_lines.clear()
	_current_target = &"arm"
	if _target_btns.has(&"arm"):
		(_target_btns[&"arm"] as Button).button_pressed = true
	_attack_btn.disabled = false
	_attack_btn.text = "ATTACK"
	for sub in _target_btns:
		(_target_btns[sub] as Button).disabled = false


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func _on_target_selected(sub_target: StringName) -> void:
	_current_target = sub_target
	if not _battle_over:
		_refresh()


func _on_attack_pressed() -> void:
	if _battle_over:
		return
	if TBC.state() != BattleController.BattleState.ACTION_PENDING:
		return
	_round_lines.clear()
	TBC.submit_action({
		"type": BattleController.ActionType.MOVE,
		"move": _atk, "sub_target": _current_target,
		"is_weapon_slot": false, "crit_mult": 1.0, "part_heat_generation": 0,
	})
	# hit_resolved / battle_ended fired synchronously during submit and populated
	# _round_lines + refreshed the bars (context is live only during resolution).
	if not _round_lines.is_empty():
		_log_label.text = "\n".join(_round_lines)


# The Part-Break subscriber (promoted slice hack): tally per-region damage and fire the
# break event through the TBC once cumulative damage crosses the region's break_hp.
func _on_hit_resolved(_move: MoveDef, damage: int, target: Combatant, sub_target: StringName) -> void:
	if target.is_enemy:
		_on_player_hit(damage, sub_target)
	else:
		_round_lines.append("%s strikes you for %d." % [_enemy_def.display_name, damage])
	_refresh()


func _on_player_hit(damage: int, sub_target: StringName) -> void:
	if sub_target == &"arm":
		_arm_dmg += damage
		if not _arm_broken and _arm_dmg >= _arm_break_hp:
			_arm_broken = true
			TBC.note_break_event(&"arm_broken")
			_round_lines.append("★ ARM BROKEN — a part is exposed to harvest!")
		elif _arm_broken:
			_round_lines.append("Its arm is already wrecked — hit CORE to finish faster.")
		else:
			_round_lines.append("You batter its ARM  (+%d break, %d/%d)." % [
				damage, mini(_arm_dmg, _arm_break_hp), _arm_break_hp])
	elif sub_target == &"head":
		_head_dmg += damage
		if not _head_broken and _head_dmg >= _head_break_hp:
			_head_broken = true
			TBC.note_break_event(&"head_broken")
			_round_lines.append("★ HEAD BROKEN — optics shattered!")
		elif _head_broken:
			_round_lines.append("Its head is already wrecked — hit CORE to finish faster.")
		else:
			_round_lines.append("You crack its HEAD  (+%d break, %d/%d)." % [
				damage, mini(_head_dmg, _head_break_hp), _head_break_hp])
	else:
		_round_lines.append("You strike its CORE for %d." % damage)


func _on_battle_ended(outcome: int, _enemy_id: StringName, fired: Dictionary,
		_xp: int, _bonus: int, _first_boss: bool, _level: int, _deployed: Array) -> void:
	_battle_over = true
	_fired_events = fired.duplicate()
	_attack_btn.disabled = true
	_attack_btn.text = "— BATTLE OVER —"
	for sub in _target_btns:
		(_target_btns[sub] as Button).disabled = true

	if outcome == OUTCOME_VICTORY:
		# Victory-gated, break-event-driven drops. DropSystem was built with ctx.inventory,
		# so each PartInstance is appended to the session inventory as it resolves.
		var drops := _drop_system.resolve_drops(
			DropSystem.OUTCOME_VICTORY, _loot_pool, _fired_events, _enemy_def.level)
		_round_lines.append("VICTORY!")
		_show_reveal(drops, outcome)
	elif outcome == OUTCOME_DEFEAT:
		_round_lines.append("DEFEATED.")
		_show_defeat(outcome)
	else:
		_show_defeat(outcome)


# ---------------------------------------------------------------------------
# View refresh — reads the live BattleContext via the TBC proxy (in a signal handler,
# never in _process — that would be the forbidden view_state_polling, ADR-0008).
# ---------------------------------------------------------------------------
func _refresh() -> void:
	var ctx := TBC.context()
	if ctx == null or ctx.active() == null or ctx.enemy == null:
		return
	var p := ctx.active()
	var e := ctx.enemy
	_set_bar(_enemy_struct_bar, e.current_structure, e.max_structure)
	_set_enemy_readout(_enemy_struct_label, BattleResolver.STRUCTURE,
		"STRUCTURE  %d/%d" % [e.current_structure, e.max_structure])
	var arm_rem := _arm_break_hp - mini(_arm_dmg, _arm_break_hp)
	_set_bar(_arm_bar, arm_rem, _arm_break_hp)
	_set_enemy_readout(_arm_label, &"arm",
		"ARM  BROKEN ✓" if _arm_broken else "ARM  %d/%d" % [arm_rem, _arm_break_hp])
	var head_rem := _head_break_hp - mini(_head_dmg, _head_break_hp)
	_set_bar(_head_bar, head_rem, _head_break_hp)
	_set_enemy_readout(_head_label, &"head",
		"HEAD  BROKEN ✓" if _head_broken else "HEAD  %d/%d" % [head_rem, _head_break_hp])
	_set_bar(_player_struct_bar, p.current_structure, p.max_structure)
	_player_struct_label.text = "STRUCTURE  %d/%d" % [p.current_structure, p.max_structure]
	_set_bar(_player_energy_bar, p.current_energy, p.max_energy_capacity)
	_player_energy_label.text = "ENERGY  %d/%d" % [p.current_energy, p.max_energy_capacity]
	_player_heat_label.text = "HEAT  %d" % p.current_heat


# ---------------------------------------------------------------------------
# UI construction (all in code — prototype-tier fidelity, shared sizing for touch)
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 10)
	scroll.add_child(info)

	# --- Enemy panel (target picker lives directly under the enemy readouts) ---
	var enemy_panel := _panel(info)
	_enemy_name_label = _label(enemy_panel, "Enemy", 22, true)
	_enemy_struct_label = _label(enemy_panel, "STRUCTURE  --/--", 15)
	_enemy_struct_bar = _bar(enemy_panel, COL_ENEMY)
	_arm_label = _label(enemy_panel, "ARM  0/0", 14)
	_arm_bar = _bar(enemy_panel, COL_BREAK)
	_head_label = _label(enemy_panel, "HEAD  0/0", 14)
	_head_bar = _bar(enemy_panel, COL_BREAK)

	_label(enemy_panel, "AIM AT →", 13)
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)
	enemy_panel.add_child(target_row)
	var group := ButtonGroup.new()
	_add_target_btn(target_row, group, "ARM", &"arm", true)
	_add_target_btn(target_row, group, "HEAD", &"head", false)
	_add_target_btn(target_row, group, "CORE", BattleResolver.STRUCTURE, false)

	# --- Log panel ---
	var log_panel := _panel(info)
	_log_label = _label(log_panel, "", 17)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(0, 72)

	# --- Player panel ---
	var player_panel := _panel(info)
	_label(player_panel, "YOUR SYMBOT", 18, true)
	_player_struct_label = _label(player_panel, "STRUCTURE  --/--", 15)
	_player_struct_bar = _bar(player_panel, COL_PLAYER)
	_player_energy_label = _label(player_panel, "ENERGY  --/--", 15)
	_player_energy_bar = _bar(player_panel, COL_ENERGY)
	_player_heat_label = _label(player_panel, "HEAT  0", 14)

	# --- Action bar (pinned below the scroll) ---
	var action_panel := _panel(root)
	_attack_btn = Button.new()
	_attack_btn.text = "ATTACK"
	_attack_btn.custom_minimum_size = Vector2(0, 64)
	_attack_btn.add_theme_font_size_override("font_size", 22)
	_attack_btn.pressed.connect(_on_attack_pressed)
	action_panel.add_child(_attack_btn)

	_build_overlay()


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.18)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(20)
	sb.set_border_width_all(2)
	sb.border_color = COL_BREAK
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(360, 0)
	center.add_child(pc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pc.add_child(vb)

	_overlay_title = Label.new()
	_overlay_title.add_theme_font_size_override("font_size", 26)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_overlay_title)

	_overlay_body = VBoxContainer.new()
	_overlay_body.add_theme_constant_override("separation", 8)
	vb.add_child(_overlay_body)

	_overlay_buttons = VBoxContainer.new()
	_overlay_buttons.add_theme_constant_override("separation", 8)
	vb.add_child(_overlay_buttons)


# ---------------------------------------------------------------------------
# Reveal / defeat overlay — one CONTINUE button returns to the Overworld.
# ---------------------------------------------------------------------------
func _show_reveal(drops: Array, outcome: int) -> void:
	_overlay_title.text = "SALVAGE"
	_overlay_title.add_theme_color_override("font_color", COL_BREAK)
	_clear_overlay_body()

	for ev in _fired_events:
		_overlay_line(_region_flavor(ev), 16, COL_BREAK)

	if drops.is_empty():
		_overlay_line("Nothing dropped this time.", 18, Color(0.75, 0.76, 0.80))
		_overlay_line("Break more regions to force a drop.", 14, Color(0.60, 0.61, 0.65))
	else:
		for d in drops:
			var rarity = d.part.rarity
			var mark := "★ " if rarity >= PartDef.Rarity.RARE else "• "
			_overlay_line("%s%s   [%s]" % [mark, d.part.display_name, _rarity_text(rarity)],
				20, _rarity_color(rarity))
		_overlay_line("Harvested parts added to your inventory.", 13, Color(0.60, 0.61, 0.65))

	_clear_overlay_buttons()
	_overlay_button("CONTINUE →", _on_continue_pressed.bind(outcome))
	_overlay.visible = true


func _show_defeat(outcome: int) -> void:
	_overlay_title.text = "DEFEAT"
	_overlay_title.add_theme_color_override("font_color", COL_ENEMY)
	_clear_overlay_body()
	_overlay_line("Your Symbot was scrapped.", 18, Color(0.80, 0.55, 0.55))
	_overlay_line("No parts harvested.", 14, Color(0.60, 0.61, 0.65))
	_clear_overlay_buttons()
	_overlay_button("CONTINUE →", _on_continue_pressed.bind(outcome))
	_overlay.visible = true


## Return to the Overworld. Emitting encounter_resolved drives ScreenManager to tear
## this screen down and restore the keep-alive'd Overworld (ADR-0004 §3). The Overworld
## clears the defeated enemy's marker on a WIN.
func _on_continue_pressed(outcome: int) -> void:
	EventBus.encounter_resolved.emit(outcome, _encounter_type)


# ---------------------------------------------------------------------------
# Content helpers
# ---------------------------------------------------------------------------
func _make_basic_attack(core_element) -> MoveDef:
	var m := MoveDef.new()
	m.id = &"basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = core_element if core_element != null else PartDef.Element.KINETIC
	m.energy_cost = 0
	return m


func _break_hp_for_region(enemy_def: EnemyDef, region: StringName) -> int:
	for r in enemy_def.break_regions:
		if StringName(r.get("region_id", &"")) == region:
			return int(r.get("break_hp", 0))
	return 0


func _resolve_loot_pool(enemy_def: EnemyDef) -> Array[PartDef]:
	var pool: Array[PartDef] = []
	for entry in enemy_def.loot_pool:
		if not bool(entry.get("enabled", true)):
			continue
		var part := PartDB.get_part(StringName(entry.get("id", &"")))
		if part != null:
			pool.append(part)
	return pool


# ---------------------------------------------------------------------------
# Widget factories (touch-first sizing)
# ---------------------------------------------------------------------------
func _add_target_btn(row: HBoxContainer, group: ButtonGroup, text: String,
		sub_target: StringName, pressed: bool) -> void:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = group
	btn.button_pressed = pressed
	btn.custom_minimum_size = Vector2(96, 56)   # ≥44×44 touch target
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	btn.set_meta("sub_target", sub_target)
	btn.toggled.connect(_on_target_btn_toggled.bind(btn))
	row.add_child(btn)
	_target_btns[sub_target] = btn


func _on_target_btn_toggled(on: bool, btn: Button) -> void:
	if on:
		_on_target_selected(StringName(btn.get_meta("sub_target")))


func _panel(parent: Node) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.17, 0.20)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)
	return vb


func _label(parent: Node, text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if bold:
		l.add_theme_color_override("font_color", Color(1, 1, 1))
	parent.add_child(l)
	return l


func _set_enemy_readout(label: Label, sub: StringName, body: String) -> void:
	var selected := _current_target == sub
	label.text = ("▶ " if selected else "   ") + body
	label.add_theme_color_override("font_color",
		Color(1, 1, 1) if selected else Color(0.62, 0.64, 0.68))


func _bar(parent: Node, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	bar.min_value = 0
	bar.max_value = 1
	bar.value = 0
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.10)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	parent.add_child(bar)
	return bar


func _set_bar(bar: ProgressBar, value: int, maximum: int) -> void:
	bar.max_value = maxi(1, maximum)
	bar.value = clampi(value, 0, maxi(1, maximum))


func _overlay_button(text: String, on_press: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(on_press)
	_overlay_buttons.add_child(btn)


func _clear_overlay_buttons() -> void:
	for child in _overlay_buttons.get_children():
		child.queue_free()


func _clear_overlay_body() -> void:
	for child in _overlay_body.get_children():
		child.queue_free()


func _overlay_line(text: String, size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.add_child(l)


func _region_flavor(break_event: StringName) -> String:
	match break_event:
		&"arm_broken": return "The ARM shattered!"
		&"head_broken": return "The HEAD shattered!"
		&"leg_broken": return "The LEG shattered!"
		&"weapon_broken": return "The WEAPON shattered!"
	return "%s fired." % String(break_event)


func _rarity_text(rarity: int) -> String:
	match rarity:
		PartDef.Rarity.COMMON: return "COMMON"
		PartDef.Rarity.RARE: return "RARE"
		PartDef.Rarity.BOSS_GRADE: return "BOSS"
		PartDef.Rarity.PROTOTYPE: return "PROTOTYPE"
	return "?"


func _rarity_color(rarity: int) -> Color:
	match rarity:
		PartDef.Rarity.RARE: return Color(0.95, 0.78, 0.30)
		PartDef.Rarity.BOSS_GRADE: return Color(0.85, 0.40, 0.85)
		PartDef.Rarity.PROTOTYPE: return Color(0.40, 0.85, 0.90)
	return Color(0.72, 0.74, 0.78)
