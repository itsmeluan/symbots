# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can a human drive one full turn-based encounter by touch —
#   read structure/energy/break state, choose a component target, break the arm —
#   on top of the finished pure core, at representative UI quality?
# Date: 2026-07-17
#
# Phase 4b — the first interactive scene in the project. Run it from the Godot
# editor: open battle_screen.tscn and press F6 (Play Scene). It reuses the REAL
# src/core (SymbotBuild, BattleController, DropSystem's combat siblings) and REAL
# .tres content; it synthesizes only the basic_attack MoveDef and the Part-Break
# subscriber (both unbuilt in src/ — see BUILD-PLAN Findings 1 & 2). All widgets are
# built in code to avoid hand-authoring theme sub-resources in the .tscn.
#
# ADR-0008: signal-driven view (subscribe in _ready, disconnect on EXIT_TREE), no
# _process polling; touch-first (≥56px targets, press-release, no hover-only).
extends Control

const SliceLogSink := preload("res://prototypes/symbots-vertical-slice/slice_log_sink.gd")

const BALANCE_PATH := "res://assets/data/balance_config.tres"
const PART_CATALOG_PATH := "res://assets/data/catalogs/part_catalog.tres"
const ENEMY_CATALOG_PATH := "res://assets/data/catalogs/enemy_catalog.tres"
const TARGET_ENEMY := &"rustcrawler"

const COL_ENEMY := Color(0.85, 0.30, 0.28)     # red — enemy structure
const COL_PLAYER := Color(0.32, 0.72, 0.40)    # green — player structure
const COL_ENERGY := Color(0.30, 0.55, 0.85)    # blue — energy
const COL_BREAK := Color(0.92, 0.70, 0.24)     # amber — break meter (harvest gate)

# --- core wiring ---
var _log: SliceLogSink
var _controller: BattleController
var _atk: MoveDef

# --- Part-Break subscriber state (presentation-tier glue, unbuilt in src/) ---
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


func _ready() -> void:
	_log = SliceLogSink.new()
	_build_ui()
	_setup_battle()
	_refresh()
	_log_label.text = "A Rustcrawler skitters into range. Break its ARM to harvest the Reinforced Servo Arm."


func _notification(what: int) -> void:
	# ADR-0008: named-Callable disconnect on teardown to avoid leaked subscriptions.
	if what == NOTIFICATION_EXIT_TREE and _controller != null:
		if _controller.hit_resolved.is_connected(_on_hit_resolved):
			_controller.hit_resolved.disconnect(_on_hit_resolved)
		if _controller.battle_ended.is_connected(_on_battle_ended):
			_controller.battle_ended.disconnect(_on_battle_ended)


# ---------------------------------------------------------------------------
# Battle assembly (mirrors slice_bootstrap.gd — prototype copy-paste is allowed)
# ---------------------------------------------------------------------------
func _setup_battle() -> void:
	var cfg := load(BALANCE_PATH) as BalanceConfig
	var part_catalog := load(PART_CATALOG_PATH) as PartCatalog
	var enemy_catalog := load(ENEMY_CATALOG_PATH) as EnemyCatalog

	var starters := _pick_stock_starters(part_catalog)
	var build := SymbotBuild.with_starters(starters, cfg, _log)
	var base_stats := build.get_final_stat()
	var core_element = starters[PartDef.SlotType.CORE].part.element
	var part_defs: Array = []
	for slot_type in starters:
		part_defs.append(starters[slot_type].part)
	_atk = _make_basic_attack(core_element)
	var loadout := SymbotLoadout.make(
		0, base_stats, [_atk, null, null, null], build.get_passive_pool(),
		core_element, part_defs)

	var enemy_def := _find_enemy(enemy_catalog, TARGET_ENEMY)
	_arm_break_hp = _break_hp_for_region(enemy_def, &"arm")
	_head_break_hp = _break_hp_for_region(enemy_def, &"head")
	var enemy_spec := {
		"id": enemy_def.id, "stats": enemy_def.stats,
		"core_element": enemy_def.core_element, "level": enemy_def.level,
		"xp_value": enemy_def.xp_value,
		"completion_bonus_xp": enemy_def.completion_bonus_xp,
		"is_first_boss_defeat": false,
	}
	_enemy_name_label.text = "%s   Lv%d" % [enemy_def.display_name, enemy_def.level]

	_controller = BattleController.new(cfg, _log)
	_controller.hit_resolved.connect(_on_hit_resolved)
	_controller.battle_ended.connect(_on_battle_ended)
	_controller.start_battle([loadout], enemy_spec, BattleController.EncounterType.WILD, null)


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------
func _on_target_selected(sub_target: StringName) -> void:
	_current_target = sub_target


func _on_attack_pressed() -> void:
	if _battle_over:
		return
	if _controller.state() != BattleController.BattleState.ACTION_PENDING:
		return
	_round_lines.clear()
	_controller.submit_action({
		"type": BattleController.ActionType.MOVE,
		"move": _atk, "sub_target": _current_target,
		"is_weapon_slot": false, "crit_mult": 1.0, "part_heat_generation": 0,
	})
	# hit_resolved / battle_ended fired synchronously during submit and populated
	# _round_lines + refreshed the bars (context is live only during resolution).
	if not _round_lines.is_empty():
		_log_label.text = "\n".join(_round_lines)


func _on_hit_resolved(_move: MoveDef, damage: int, target: Combatant, sub_target: StringName) -> void:
	if target.is_enemy:
		_on_player_hit(damage, sub_target)
	else:
		_round_lines.append("Rustcrawler strikes you for %d." % damage)
	_refresh()


func _on_player_hit(damage: int, sub_target: StringName) -> void:
	if sub_target == &"arm":
		_arm_dmg += damage
		if not _arm_broken and _arm_dmg >= _arm_break_hp:
			_arm_broken = true
			_controller.note_break_event(&"arm_broken")
			_round_lines.append("★ ARM BROKEN — the Reinforced Servo Arm is exposed!")
		elif _arm_broken:
			_round_lines.append("Its arm is already wrecked — hit CORE to finish faster.")
		else:
			_round_lines.append("You batter its ARM  (+%d break, %d/%d)." % [
				damage, mini(_arm_dmg, _arm_break_hp), _arm_break_hp])
	elif sub_target == &"head":
		_head_dmg += damage
		if not _head_broken and _head_dmg >= _head_break_hp:
			_head_broken = true
			_controller.note_break_event(&"head_broken")
			_round_lines.append("★ HEAD BROKEN — optics shattered!")
		elif _head_broken:
			_round_lines.append("Its head is already wrecked — hit CORE to finish faster.")
		else:
			_round_lines.append("You crack its HEAD  (+%d break, %d/%d)." % [
				damage, mini(_head_dmg, _head_break_hp), _head_break_hp])
	else:
		_round_lines.append("You strike its CORE for %d." % damage)


func _on_battle_ended(outcome: int, _enemy_id: StringName, _fired: Dictionary,
		_xp: int, _bonus: int, _first_boss: bool, _level: int, _deployed: Array) -> void:
	_battle_over = true
	if outcome == BattleController.Outcome.VICTORY:
		if _arm_broken:
			_round_lines.append("VICTORY!  The arm was broken — harvest is unlocked (Phase 4c).")
		else:
			_round_lines.append("VICTORY!  (Arm intact — no rare harvest this time.)")
	elif outcome == BattleController.Outcome.DEFEAT:
		_round_lines.append("DEFEATED.  Your Symbot is scrap. (Retry from the editor.)")
	else:
		_round_lines.append("Battle ended (outcome %d)." % outcome)
	_attack_btn.disabled = true
	_attack_btn.text = "— BATTLE OVER —"
	for sub in _target_btns:
		(_target_btns[sub] as Button).disabled = true


# ---------------------------------------------------------------------------
# View refresh — reads the live BattleContext (valid only while battle active)
# ---------------------------------------------------------------------------
func _refresh() -> void:
	var ctx := _controller.context()
	if ctx == null or ctx.active() == null or ctx.enemy == null:
		return
	var p := ctx.active()
	var e := ctx.enemy
	_set_bar(_enemy_struct_bar, e.current_structure, e.max_structure)
	_enemy_struct_label.text = "STRUCTURE  %d/%d" % [e.current_structure, e.max_structure]
	_set_bar(_arm_bar, mini(_arm_dmg, _arm_break_hp), _arm_break_hp)
	_arm_label.text = ("ARM  BROKEN ✓" if _arm_broken else "ARM  %d/%d" % [
		mini(_arm_dmg, _arm_break_hp), _arm_break_hp])
	_set_bar(_head_bar, mini(_head_dmg, _head_break_hp), _head_break_hp)
	_head_label.text = ("HEAD  BROKEN ✓" if _head_broken else "HEAD  %d/%d" % [
		mini(_head_dmg, _head_break_hp), _head_break_hp])
	_set_bar(_player_struct_bar, p.current_structure, p.max_structure)
	_player_struct_label.text = "STRUCTURE  %d/%d" % [p.current_structure, p.max_structure]
	_set_bar(_player_energy_bar, p.current_energy, p.max_energy_capacity)
	_player_energy_label.text = "ENERGY  %d/%d" % [p.current_energy, p.max_energy_capacity]
	_player_heat_label.text = "HEAT  %d" % p.current_heat


# ---------------------------------------------------------------------------
# UI construction (all in code — prototype-tier, shared sizing for touch)
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# --- Enemy panel ---
	var enemy_panel := _panel(root)
	_enemy_name_label = _label(enemy_panel, "Rustcrawler", 24, true)
	_enemy_struct_label = _label(enemy_panel, "STRUCTURE  --/--", 16)
	_enemy_struct_bar = _bar(enemy_panel, COL_ENEMY)
	_arm_label = _label(enemy_panel, "ARM  0/0", 15)
	_arm_bar = _bar(enemy_panel, COL_BREAK)
	_head_label = _label(enemy_panel, "HEAD  0/0", 15)
	_head_bar = _bar(enemy_panel, COL_BREAK)

	# --- Log panel (grows to fill middle) ---
	var log_panel := _panel(root)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label = _label(log_panel, "", 18)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# --- Player panel ---
	var player_panel := _panel(root)
	_label(player_panel, "YOUR SYMBOT", 20, true)
	_player_struct_label = _label(player_panel, "STRUCTURE  --/--", 16)
	_player_struct_bar = _bar(player_panel, COL_PLAYER)
	_player_energy_label = _label(player_panel, "ENERGY  --/--", 16)
	_player_energy_bar = _bar(player_panel, COL_ENERGY)
	_player_heat_label = _label(player_panel, "HEAT  0", 15)

	# --- Action bar ---
	var action_panel := _panel(root)
	_label(action_panel, "TARGET", 15)
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)
	action_panel.add_child(target_row)
	var group := ButtonGroup.new()
	_add_target_btn(target_row, group, "ARM", &"arm", true)
	_add_target_btn(target_row, group, "HEAD", &"head", false)
	_add_target_btn(target_row, group, "CORE", BattleResolver.STRUCTURE, false)

	_attack_btn = Button.new()
	_attack_btn.text = "ATTACK"
	_attack_btn.custom_minimum_size = Vector2(0, 64)
	_attack_btn.add_theme_font_size_override("font_size", 22)
	_attack_btn.pressed.connect(_on_attack_pressed)
	action_panel.add_child(_attack_btn)


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
	btn.toggled.connect(func(on: bool) -> void:
		if on: _on_target_selected(sub_target))
	row.add_child(btn)
	_target_btns[sub_target] = btn


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


func _bar(parent: Node, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
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


# ---------------------------------------------------------------------------
# Content helpers (mirror slice_bootstrap.gd)
# ---------------------------------------------------------------------------
func _pick_stock_starters(catalog: PartCatalog) -> Dictionary:
	var by_slot: Dictionary = {}
	for p in catalog.entries:
		if p.rarity == PartDef.Rarity.COMMON and not by_slot.has(p.slot_type):
			by_slot[p.slot_type] = PartInstance.new(
				StringName("stock_" + String(p.id)), p, 0)
	return by_slot


func _make_basic_attack(core_element) -> MoveDef:
	var m := MoveDef.new()
	m.id = &"slice_basic_attack"
	m.behavior = MoveDef.Behavior.DAMAGE
	m.power_tier = MoveDef.PowerTier.STANDARD
	m.damage_type = PartDef.DamageType.PHYSICAL
	m.element = core_element if core_element != null else PartDef.Element.KINETIC
	m.energy_cost = 0
	return m


func _find_enemy(catalog: EnemyCatalog, id: StringName) -> EnemyDef:
	for e in catalog.entries:
		if e.id == id:
			return e
	return null


func _break_hp_for_region(enemy_def: EnemyDef, region: StringName) -> int:
	for r in enemy_def.break_regions:
		if StringName(r.get("region_id", &"")) == region:
			return int(r.get("break_hp", 0))
	return 0
