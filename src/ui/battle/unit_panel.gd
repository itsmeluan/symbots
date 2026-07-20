## UnitPanel — one combatant's card on the battle screen (ADR-0008, Core Design §3.1).
##
## Built in code rather than as a .tscn because eight of these are laid out
## programmatically and a scene file would need the same wiring anyway — this way the
## layout and the contract live in one reviewable place.
##
## Renders as a PURE FUNCTION of the last [BattleUnit] state it was handed (ADR-0008
## forbids `view_state_polling`). Nothing here reads the model on a timer; the screen calls
## [method refresh] when the engine says something changed.
class_name UnitPanel
extends PanelContainer

## Emitted when the player taps this unit. The screen decides whether that means anything
## — the panel does not know the targeting rules.
signal tapped(unit: BattleUnit)

## Touch minimum from technical-preferences.md. Applied to the whole card, so the tap
## target is the card and never a sub-widget.
const MIN_TAP_HEIGHT := 44

const BAR_HEIGHT := 6

var unit: BattleUnit = null

var _name_label: Label
var _structure_bar: ProgressBar
var _shield_bar: ProgressBar
var _charge_bar: ProgressBar
var _status_label: Label
var _root: VBoxContainer

## Visual state the screen drives. Kept as fields rather than as style overrides applied
## immediately so [method refresh] stays the single place that touches appearance.
var is_active_turn: bool = false
var is_targetable: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(0, MIN_TAP_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 1)
	add_child(_root)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 10)
	_root.add_child(_name_label)

	_structure_bar = _make_bar(Color(0.30, 0.78, 0.35))
	_root.add_child(_structure_bar)

	_shield_bar = _make_bar(Color(0.45, 0.70, 0.95))
	_root.add_child(_shield_bar)

	_charge_bar = _make_bar(Color(0.95, 0.72, 0.20))
	_root.add_child(_charge_bar)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 8)
	_root.add_child(_status_label)


func _make_bar(colour: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.show_percentage = false
	bar.max_value = 100
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Bind a unit and draw it. Call once per battle, then [method refresh] on every change.
func bind(u: BattleUnit) -> void:
	unit = u
	refresh()


## Redraw from the unit's current state. Safe to call every frame or once an hour — it
## reads, never writes.
func refresh() -> void:
	if unit == null:
		return

	_name_label.text = unit.display_name if unit.display_name != "" else String(unit.unit_id)

	_structure_bar.max_value = maxi(1, unit.max_structure)
	_structure_bar.value = unit.current_structure

	# The shield bar is scaled against max structure, not against itself, so a 10-point
	# shield on a 500-HP tank reads as the sliver it actually is rather than as a full bar.
	_shield_bar.max_value = maxi(1, unit.max_structure)
	_shield_bar.value = unit.shield
	_shield_bar.visible = unit.shield > 0

	_charge_bar.visible = unit.has_ultimate()
	if unit.has_ultimate():
		_charge_bar.max_value = maxi(1, _ult_cost)
		_charge_bar.value = mini(unit.ultimate_charge, _ult_cost)

	_status_label.text = _status_text()

	modulate = Color(0.45, 0.45, 0.45) if not unit.is_alive() else Color.WHITE
	_apply_highlight()


## Charge cost of this unit's ult, injected by the screen (which owns the skill table).
## Defaults to 100 so a panel is drawable before the table is bound.
var _ult_cost: int = 100

func set_ult_cost(cost: int) -> void:
	_ult_cost = maxi(1, cost)


## Compact status readout. Icons come later; text keeps it legible and testable now.
func _status_text() -> String:
	if unit.statuses.is_empty():
		return ""
	var parts: PackedStringArray = []
	for s in unit.statuses:
		parts.append("%d:%d" % [s.kind, s.remaining])
	return " ".join(parts)


func _apply_highlight() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.12, 0.16, 0.9)
	box.set_content_margin_all(3)
	if is_active_turn:
		box.border_color = Color(1.0, 0.85, 0.3)
		box.set_border_width_all(2)
	elif is_targetable:
		box.border_color = Color(0.95, 0.35, 0.35)
		box.set_border_width_all(2)
	else:
		box.set_border_width_all(0)
	add_theme_stylebox_override("panel", box)


func set_active_turn(active: bool) -> void:
	is_active_turn = active
	_apply_highlight()


func set_targetable(targetable: bool) -> void:
	is_targetable = targetable
	_apply_highlight()


## Touch and mouse share one press-release path (ADR-0008 touch-first): both arrive as
## InputEventMouseButton on Godot's default emulation, so there is no hover-only affordance
## and no second code path to keep in sync.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if unit != null:
			tapped.emit(unit)
			accept_event()
