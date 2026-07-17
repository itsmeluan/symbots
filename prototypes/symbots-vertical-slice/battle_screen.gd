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

# --- 4c drop / rematch state (built once in _setup_battle, reused per fight) ---
var _cfg: BalanceConfig
var _enemy_def: EnemyDef
var _enemy_spec: Dictionary = {}
var _loadout                                   # SymbotLoadout — rebuilt after an equip
var _loot_pool: Array[PartDef] = []
var _drop_system: DropSystem                   # created ONCE so pity survives rematches
var _harvested_drops: Array = []               # last fight's PartInstances (Phase 4d re-equip)
var _fired_events: Dictionary = {}

# --- 4d workshop state (the live build the workshop re-equips into) ---
var _build: SymbotBuild
var _core_element
var _slot_types: Array = []

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

# --- 4c/4d overlay refs (reveal + workshop share one overlay, modes swap content) ---
var _overlay: Control
var _overlay_title: Label
var _overlay_body: VBoxContainer
var _overlay_buttons: VBoxContainer


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
	_cfg = load(BALANCE_PATH) as BalanceConfig
	var part_catalog := load(PART_CATALOG_PATH) as PartCatalog
	var enemy_catalog := load(ENEMY_CATALOG_PATH) as EnemyCatalog

	var starters := _pick_stock_starters(part_catalog)
	_build = SymbotBuild.with_starters(starters, _cfg, _log)
	_slot_types = starters.keys()
	_core_element = starters[PartDef.SlotType.CORE].part.element
	_atk = _make_basic_attack(_core_element)
	_rebuild_loadout()

	_enemy_def = _find_enemy(enemy_catalog, TARGET_ENEMY)
	_arm_break_hp = _break_hp_for_region(_enemy_def, &"arm")
	_head_break_hp = _break_hp_for_region(_enemy_def, &"head")
	_enemy_spec = {
		"id": _enemy_def.id, "stats": _enemy_def.stats,
		"core_element": _enemy_def.core_element, "level": _enemy_def.level,
		"xp_value": _enemy_def.xp_value,
		"completion_bonus_xp": _enemy_def.completion_bonus_xp,
		"is_first_boss_defeat": false,
	}
	_enemy_name_label.text = "%s   Lv%d" % [_enemy_def.display_name, _enemy_def.level]

	# Loot pool + DropSystem are built ONCE — the seeded RNG stream and gradient
	# pity are internal to _drop_system, so reusing it across rematches lets the
	# rare accumulate exactly like the real farm loop (mirrors slice_bootstrap.gd).
	_loot_pool = _resolve_loot_pool(_enemy_def, part_catalog)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260717
	_drop_system = DropSystem.new(rng, _cfg, _log)

	_controller = BattleController.new(_cfg, _log)
	_controller.hit_resolved.connect(_on_hit_resolved)
	_controller.battle_ended.connect(_on_battle_ended)
	_start_fight()


# Rebuild the frozen loadout from the live _build — called at setup and after every
# workshop equip, so the NEXT fight is driven by the upgraded stats/passives.
func _rebuild_loadout() -> void:
	var part_defs: Array = []
	for slot in _slot_types:
		var inst: PartInstance = _build.get_equipped(slot)
		if inst != null:
			part_defs.append(inst.part)
	_loadout = SymbotLoadout.make(
		0, _build.get_final_stat(), [_atk, null, null, null],
		_build.get_passive_pool(), _core_element, part_defs)


# Reset per-fight break state and (re)start the encounter on the SAME controller.
# Called for the first fight and every "LUTAR DE NOVO" — never rebuilds the
# DropSystem, so pity persists across the farm.
func _start_fight() -> void:
	_arm_dmg = 0
	_head_dmg = 0
	_arm_broken = false
	_head_broken = false
	_battle_over = false
	_harvested_drops = []
	_fired_events = {}
	_round_lines.clear()
	# Reset the target back to the harvest-nudge default — otherwise a rematch keeps
	# the stale CORE selection from the previous fight's finisher and the arm never breaks.
	_current_target = &"arm"
	if _target_btns.has(&"arm"):
		(_target_btns[&"arm"] as Button).button_pressed = true
	_attack_btn.disabled = false
	_attack_btn.text = "ATTACK"
	for sub in _target_btns:
		(_target_btns[sub] as Button).disabled = false
	_controller.start_battle(
		[_loadout], _enemy_spec, BattleController.EncounterType.WILD, null)


# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------
func _on_target_selected(sub_target: StringName) -> void:
	_current_target = sub_target
	# Re-mark the enemy readout immediately so the aim shows before you attack.
	# ctx is live between rounds (ACTION_PENDING); _refresh no-ops if it isn't.
	if not _battle_over:
		_refresh()


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


func _on_battle_ended(outcome: int, _enemy_id: StringName, fired: Dictionary,
		_xp: int, _bonus: int, _first_boss: bool, _level: int, _deployed: Array) -> void:
	_battle_over = true
	_fired_events = fired.duplicate()
	_attack_btn.disabled = true
	_attack_btn.text = "— BATTLE OVER —"
	for sub in _target_btns:
		(_target_btns[sub] as Button).disabled = true

	if outcome == BattleController.Outcome.VICTORY:
		# Same DropSystem call the harness makes — victory-gated, break-event-driven,
		# seeded/pity RNG. Drops feed the reveal panel and are kept for Phase 4d.
		_harvested_drops = _drop_system.resolve_drops(
			DropSystem.OUTCOME_VICTORY, _loot_pool, _fired_events, _enemy_def.level)
		_round_lines.append("VICTORY!")
		_show_reveal(_harvested_drops)
	elif outcome == BattleController.Outcome.DEFEAT:
		_round_lines.append("DEFEATED.")
		_show_defeat()
	else:
		_round_lines.append("Battle ended (outcome %d)." % outcome)


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
	_set_enemy_readout(_enemy_struct_label, BattleResolver.STRUCTURE,
		"STRUCTURE  %d/%d" % [e.current_structure, e.max_structure])
	# Break bars now read as the PART's own HP: they start FULL and DEPLETE as you batter
	# them (playtest 4e: a bar that grew toward "broken" was counterintuitive).
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
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Battle info (enemy / log / player) lives in a ScrollContainer so it absorbs
	# any vertical overflow; the action bar is a sibling AFTER it, pinned to the
	# bottom of the window and therefore always visible/clickable.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 10)
	scroll.add_child(info)

	# --- Enemy panel ---
	# The target picker lives INSIDE this panel, directly under the enemy's readouts,
	# so "ARM / HEAD / CORE" reads unambiguously as "which part of THIS enemy do I hit"
	# (playtest 4e: at the bottom, between your Symbot and ATTACK, it read as ambiguous).
	var enemy_panel := _panel(info)
	_enemy_name_label = _label(enemy_panel, "Rustcrawler", 22, true)
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

	# --- Action bar (pinned below the scroll) — just the commit button now ---
	var action_panel := _panel(root)
	_attack_btn = Button.new()
	_attack_btn.text = "ATTACK"
	_attack_btn.custom_minimum_size = Vector2(0, 64)
	_attack_btn.add_theme_font_size_override("font_size", 22)
	_attack_btn.pressed.connect(_on_attack_pressed)
	action_panel.add_child(_attack_btn)

	_build_overlay()


# Reveal/defeat overlay — hidden until a battle ends. Full-rect dim blocks input to
# the battle behind it; a centered panel shows the loot (or defeat) + rematch.
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


# Add a full-width action button to the overlay's button strip (touch ≥44px height).
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


# Set an enemy readout label's text + a ▶ marker/brightness when it is the current aim,
# so the player can see which enemy part their next hit lands on before committing.
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


func _resolve_loot_pool(enemy_def: EnemyDef, catalog: PartCatalog) -> Array[PartDef]:
	var pool: Array[PartDef] = []
	for entry in enemy_def.loot_pool:
		if not bool(entry.get("enabled", true)):
			continue
		var want := StringName(entry.get("id", &""))
		for p in catalog.entries:
			if p.id == want:
				pool.append(p)
				break
	return pool


# ---------------------------------------------------------------------------
# 4c reveal overlay
# ---------------------------------------------------------------------------
func _show_reveal(drops: Array) -> void:
	_overlay_title.text = "PILHAGEM"
	_overlay_title.add_theme_color_override("font_color", COL_BREAK)
	_clear_overlay_body()

	# Flavor line per broken region — the harvest we gated.
	for ev in _fired_events:
		_overlay_line(_region_flavor(ev), 16, COL_BREAK)

	if drops.is_empty():
		_overlay_line("Nada se soltou desta vez.", 18, Color(0.75, 0.76, 0.80))
		_overlay_line("Lute de novo para forçar o drop.", 14, Color(0.60, 0.61, 0.65))
	else:
		for d in drops:
			var rarity = d.part.rarity
			var mark := "★ " if rarity >= PartDef.Rarity.RARE else "• "
			_overlay_line("%s%s   [%s]" % [
				mark, d.part.display_name, _rarity_text(rarity)],
				20, _rarity_color(rarity))

	_clear_overlay_buttons()
	if not _equippable_arms().is_empty():
		_overlay_button("OFICINA  →", _show_workshop)
	_overlay_button("LUTAR DE NOVO", _on_rematch_pressed)
	_overlay.visible = true


func _show_defeat() -> void:
	_overlay_title.text = "DERROTA"
	_overlay_title.add_theme_color_override("font_color", COL_ENEMY)
	_clear_overlay_body()
	_overlay_line("Seu Symbot virou sucata.", 18, Color(0.80, 0.55, 0.55))
	_overlay_line("Nenhuma peça colhida.", 14, Color(0.60, 0.61, 0.65))
	_clear_overlay_buttons()
	_overlay_button("LUTAR DE NOVO", _on_rematch_pressed)
	_overlay.visible = true


func _on_rematch_pressed() -> void:
	_overlay.visible = false
	_start_fight()
	_refresh()
	_log_label.text = "Outra Rustcrawler se aproxima. Quebre o BRAÇO para colher."


# ---------------------------------------------------------------------------
# 4d workshop — equip a harvested ARMS part; preview + realized stat delta.
# ---------------------------------------------------------------------------
# Harvested drops that fit the ARMS slot (the ones the workshop can install).
func _equippable_arms() -> Array:
	var out: Array = []
	for d in _harvested_drops:
		if d.part.slot_type == PartDef.SlotType.ARMS:
			out.append(d)
	return out


func _show_workshop() -> void:
	_overlay_title.text = "OFICINA"
	_overlay_title.add_theme_color_override("font_color", COL_PLAYER)
	_clear_overlay_body()

	var equipped: PartInstance = _build.get_equipped(PartDef.SlotType.ARMS)
	var equipped_name := equipped.part.display_name if equipped != null else "—"
	_overlay_line("BRAÇO equipado:  %s" % equipped_name, 15, Color(0.80, 0.82, 0.86))
	_overlay_line("Peças colhidas para o BRAÇO:", 14, Color(0.60, 0.61, 0.65))

	var current := _build.get_final_stat()
	for cand in _equippable_arms():
		var is_equipped: bool = equipped != null and equipped.part.id == cand.part.id
		_overlay_line("%s  [%s]%s" % [
			cand.part.display_name, _rarity_text(cand.part.rarity),
			"   (equipado ✓)" if is_equipped else ""],
			18, _rarity_color(cand.part.rarity))
		if not is_equipped:
			# preview_swap returns a SIGNED DELTA dict (hypothetical − current),
			# not absolute stats — rebuild the "after" row from current + delta.
			var delta := _build.preview_swap(cand.part, PartDef.SlotType.ARMS)
			var after := current.duplicate()
			for k in delta:
				after[k] = int(current.get(k, 0)) + int(delta[k])
			_render_delta(current, after)

	_clear_overlay_buttons()
	for cand in _equippable_arms():
		var is_equipped: bool = equipped != null and equipped.part.id == cand.part.id
		if not is_equipped:
			_overlay_button("EQUIPAR  %s" % cand.part.display_name,
				_on_equip_pressed.bind(cand))
	_overlay_button("← VOLTAR À BATALHA", _on_rematch_pressed)
	_overlay.visible = true


func _on_equip_pressed(cand: PartInstance) -> void:
	var before := _build.get_final_stat()
	var result := _build.equip_part(PartDef.SlotType.ARMS, cand)
	if not bool(result.get("ok", false)):
		_overlay_line("EQUIP RECUSADO: %s — %s" % [
			result.get("reason", "?"), result.get("message", "")],
			15, COL_ENEMY)
		return
	var after := _build.get_final_stat()
	_rebuild_loadout()   # the next fight runs on the stronger Symbot

	# Re-render the workshop showing the realized delta (matches the preview exactly).
	_overlay_title.text = "OFICINA — %s equipado" % cand.part.display_name
	_clear_overlay_body()
	_overlay_line("★ %s instalado no BRAÇO." % cand.part.display_name, 18, _rarity_color(cand.part.rarity))
	_overlay_line("Seu Symbot ficou mais forte:", 15, COL_PLAYER)
	_render_delta(before, after)
	_clear_overlay_buttons()
	_overlay_button("← VOLTAR À BATALHA", _on_rematch_pressed)


# Render a compact stat-delta block (only stats that changed get an arrow row).
func _render_delta(before: Dictionary, after: Dictionary) -> void:
	var any := false
	for key in [&"structure", &"physical_power", &"armor", &"energy_capacity", &"mobility"]:
		var b := int(before.get(key, 0))
		var a := int(after.get(key, 0))
		if a == b:
			continue
		any = true
		var up := a > b
		_overlay_line("%s  %d → %d  (%+d)" % [_stat_label(key), b, a, a - b],
			15, COL_PLAYER if up else COL_ENEMY)
	if not any:
		_overlay_line("(sem mudança de stat)", 14, Color(0.60, 0.61, 0.65))


func _stat_label(key: StringName) -> String:
	match key:
		&"structure": return "ESTRUTURA "
		&"physical_power": return "DANO FÍS. "
		&"armor": return "ARMADURA  "
		&"energy_capacity": return "ENERGIA   "
		&"mobility": return "MOBILIDADE"
	return String(key)


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
		&"arm_broken": return "O BRAÇO se despedaçou!"
		&"head_broken": return "A CABEÇA se despedaçou!"
		&"leg_broken": return "A PERNA se despedaçou!"
		&"weapon_broken": return "A ARMA se despedaçou!"
	return "%s disparou." % String(break_event)


func _rarity_text(rarity: int) -> String:
	match rarity:
		PartDef.Rarity.COMMON: return "COMUM"
		PartDef.Rarity.RARE: return "RARO"
		PartDef.Rarity.BOSS_GRADE: return "BOSS"
		PartDef.Rarity.PROTOTYPE: return "PROTÓTIPO"
	return "?"


func _rarity_color(rarity: int) -> Color:
	match rarity:
		PartDef.Rarity.RARE: return Color(0.95, 0.78, 0.30)      # gold — the payoff
		PartDef.Rarity.BOSS_GRADE: return Color(0.85, 0.40, 0.85)
		PartDef.Rarity.PROTOTYPE: return Color(0.40, 0.85, 0.90)
	return Color(0.72, 0.74, 0.78)                              # common gray
