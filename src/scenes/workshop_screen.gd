## WorkshopScreen — the build bench (ADR-0008 presentation tier).
##
## Opens over the Overworld (kept alive + disabled by ScreenManager). Shows the eight
## equip slots, the part currently in each, and — for the selected slot — the harvested
## parts in the player Inventory that fit it. Selecting a candidate previews the per-stat
## delta (pure SA-F2 via SymbotBuild.preview_swap — no live mutation); EQUIP commits it
## through SymbotBuild.equip_part (which displaces the old part back to Inventory).
##
## All display-only: the screen never owns build state. It reads SymbotBuild + Inventory,
## calls equip_part on a player action, and re-renders on the build's stats_changed /
## part_equipped signals (signal-driven, no _process polling — ADR-0008).
class_name WorkshopScreen
extends Screen

# Canonical slot presentation order (matches SymbotBuild.SLOT_ORDER intent).
const SLOT_ORDER: Array[int] = [
	PartDef.SlotType.CORE, PartDef.SlotType.CHASSIS, PartDef.SlotType.CHIPSET,
	PartDef.SlotType.ENERGY_CELL, PartDef.SlotType.HEAD, PartDef.SlotType.ARMS,
	PartDef.SlotType.LEGS, PartDef.SlotType.WEAPON,
]

const COL_POS := Color(0.42, 0.85, 0.50)   # stat gain (dynamic preview tint)
const COL_NEG := Color(0.90, 0.45, 0.45)   # stat loss
const COL_DIM := Color(0.62, 0.64, 0.68)

var _ctx: ServiceContext = null
var _log: LogSink = null

var _selected_slot: int = PartDef.SlotType.CORE
var _candidate: PartInstance = null

# Static shell authored in workshop_screen.tscn (structure + styling via the central
# Theme); resolved via % unique names. The three lists below are filled at runtime with
# data-driven rows the editor can't author (slots, inventory candidates, stat readout).
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _candidate_list: VBoxContainer = %CandidateList
@onready var _stat_rows_box: VBoxContainer = %StatRows
@onready var _detail_label: Label = %DetailLabel
@onready var _equip_btn: Button = %EquipBtn
var _slot_buttons: Dictionary = {}   # slot_type:int -> Button
var _stat_rows: Dictionary = {}      # stat_key:StringName -> Label


func _ready() -> void:
	%CloseBtn.pressed.connect(_on_close_pressed)
	_equip_btn.pressed.connect(_on_equip_pressed)
	_build_slot_buttons()
	_build_stat_rows()


## Screen contract: cache deps, subscribe to build signals, render the initial view.
func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_log = ctx.log
	# Signal-driven refresh (ADR-0008 — no MODEL-state polling in _process).
	_connect_owned(_ctx.build.stats_changed, Callable(self, "_on_stats_changed"))
	_connect_owned(_ctx.build.part_equipped, Callable(self, "_on_part_equipped"))
	_refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


# ---------------------------------------------------------------------------
# Data-driven content builders (rows the editor can't author — injected into the
# named containers of workshop_screen.tscn)
# ---------------------------------------------------------------------------

## One toggle button per equip slot, in canonical order, into %SlotList.
func _build_slot_buttons() -> void:
	for slot_type: int in SLOT_ORDER:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.set_meta("slot_type", slot_type)
		b.pressed.connect(_on_slot_pressed.bind(slot_type))
		_slot_list.add_child(b)
		_slot_buttons[slot_type] = b


## One name/value row per canonical stat into %StatRows (count is balance-driven).
func _build_stat_rows() -> void:
	for key: StringName in _stat_keys():
		var row := HBoxContainer.new()
		_stat_rows_box.add_child(row)
		var name_l := _label(row, String(key).capitalize(), 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_color_override("font_color", COL_DIM)
		var val_l := _label(row, "0", 14, true)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_l.custom_minimum_size = Vector2(120, 0)
		_stat_rows[key] = val_l


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

## Full re-render: slot rows, candidate list, and the current stat block.
func _refresh() -> void:
	if _ctx == null:
		return
	for slot_type: int in SLOT_ORDER:
		var equipped: PartInstance = _ctx.build.get_equipped(slot_type)
		var occupant := equipped.part.display_name if equipped != null else "— empty —"
		var btn: Button = _slot_buttons[slot_type]
		btn.text = "%s\n  %s" % [_slot_name(slot_type), occupant]
		btn.button_pressed = (slot_type == _selected_slot)
		_apply_part_icon(btn, equipped)
	_refresh_candidates()
	_render_stats({})


## Rebuild the candidate list for the selected slot from the player Inventory.
func _refresh_candidates() -> void:
	for child in _candidate_list.get_children():
		child.queue_free()
	_candidate = null

	var parts: Array = _ctx.inventory.parts_for_slot(_selected_slot)
	if parts.is_empty():
		var empty := _label(_candidate_list, "No harvested %s parts yet.\nWin fights to salvage more." % _slot_name(_selected_slot).to_lower(), 13)
		empty.add_theme_color_override("font_color", COL_DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return

	var equipped: PartInstance = _ctx.build.get_equipped(_selected_slot)
	for inst: PartInstance in parts:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\n  %s · %s" % [
			inst.part.display_name, _element_name(inst.part.element),
			_rarity_name(inst.part.rarity)]
		var is_current := equipped != null and equipped.part.id == inst.part.id
		if is_current:
			b.text += "   (equipped)"
			b.disabled = true
		_apply_part_icon(b, inst)
		b.pressed.connect(_on_candidate_pressed.bind(inst))
		_candidate_list.add_child(b)


## Render the stat block. When [param delta] is non-empty, append the preview change.
func _render_stats(delta: Dictionary) -> void:
	var final: Dictionary = _ctx.build.get_final_stat()
	for key: StringName in _stat_keys():
		var base: int = int(final.get(key, 0))
		var label: Label = _stat_rows[key]
		var d: int = int(delta.get(key, 0))
		if d == 0:
			label.text = str(base)
			label.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			label.text = "%d  →  %d  (%s%d)" % [base, base + d, "+" if d > 0 else "", d]
			label.add_theme_color_override("font_color", COL_POS if d > 0 else COL_NEG)


# ---------------------------------------------------------------------------
# Input handlers (named Callables — no lambdas, ADR-0008)
# ---------------------------------------------------------------------------

func _on_slot_pressed(slot_type: int) -> void:
	_selected_slot = slot_type
	_equip_btn.disabled = true
	_detail_label.text = "Select a part to preview its effect."
	_detail_label.add_theme_color_override("font_color", COL_DIM)
	_refresh()


func _on_candidate_pressed(inst: PartInstance) -> void:
	_candidate = inst
	# Pure preview — SA-F2, zero mutation.
	var delta: Dictionary = _ctx.build.preview_swap(inst.part, _selected_slot)
	_render_stats(delta)
	_detail_label.text = "%s\n%s" % [inst.part.display_name, inst.part.flavor_text]
	_detail_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_equip_btn.disabled = false
	_equip_btn.text = "EQUIP  %s" % inst.part.display_name


func _on_equip_pressed() -> void:
	if _candidate == null:
		return
	# equip_part emits stats_changed / part_equipped SYNCHRONOUSLY, which re-enters
	# _refresh() → _refresh_candidates() and nulls _candidate mid-call. Capture the id
	# and slot up front so post-equip logging never dereferences the cleared field.
	var part_id: StringName = _candidate.part.id
	var slot: int = _selected_slot
	var result: Dictionary = _ctx.build.equip_part(slot, _candidate)
	if not bool(result.get("ok", false)):
		_detail_label.text = String(result.get("message", "Cannot equip that part."))
		_detail_label.add_theme_color_override("font_color", COL_NEG)
		if _log != null:
			_log.info(&"workshop_equip_rejected",
				{"slot": slot, "reason": result.get("reason", &"")})
		return
	if _log != null:
		_log.info(&"workshop_equipped", {"slot": slot, "part": part_id})
	# stats_changed / part_equipped fired synchronously → _refresh already ran.


func _on_close_pressed() -> void:
	if _ctx != null:
		_ctx.screens.close_workshop()


# ---------------------------------------------------------------------------
# Signal handlers (build model changed)
# ---------------------------------------------------------------------------

func _on_stats_changed(_final_stat: Dictionary) -> void:
	_refresh()


func _on_part_equipped(_slot_type: int, _part_id: StringName) -> void:
	_refresh()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _stat_keys() -> Array[StringName]:
	if _ctx != null and _ctx.balance != null:
		return _ctx.balance.canonical_stat_keys
	return [&"structure", &"armor", &"resistance", &"physical_power", &"energy_power",
		&"mobility", &"targeting", &"processing", &"cooling", &"energy_capacity", &"recharge"]


func _slot_name(slot_type: int) -> String:
	match slot_type:
		PartDef.SlotType.CORE: return "CORE"
		PartDef.SlotType.CHASSIS: return "CHASSIS"
		PartDef.SlotType.CHIPSET: return "CHIPSET"
		PartDef.SlotType.ENERGY_CELL: return "ENERGY CELL"
		PartDef.SlotType.HEAD: return "HEAD"
		PartDef.SlotType.ARMS: return "ARMS"
		PartDef.SlotType.LEGS: return "LEGS"
		PartDef.SlotType.WEAPON: return "WEAPON"
	return "SLOT %d" % slot_type


func _element_name(element: int) -> String:
	match element:
		PartDef.Element.VOLT: return "Volt"
		PartDef.Element.THERMAL: return "Thermal"
		PartDef.Element.KINETIC: return "Kinetic"
	return "—"


func _rarity_name(rarity: int) -> String:
	match rarity:
		PartDef.Rarity.COMMON: return "Common"
		PartDef.Rarity.RARE: return "Rare"
		PartDef.Rarity.BOSS_GRADE: return "Boss"
		PartDef.Rarity.PROTOTYPE: return "Prototype"
	return "—"


## Show the part's sprite on a slot/candidate button, or clear it for an empty slot.
## Resolved by convention through Art.texture("parts", <part_id>) — art-bible §8.4: the
## filename IS the content id. expand_icon lets one 200-ish px source serve any button
## height without a per-size asset.
func _apply_part_icon(btn: Button, inst: PartInstance) -> void:
	if inst == null:
		btn.icon = null
		return
	btn.icon = Art.texture("parts", inst.part.id)
	btn.expand_icon = true


func _label(parent: Node, text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if bold:
		l.add_theme_color_override("font_color", Color(1, 1, 1))
	parent.add_child(l)
	return l
