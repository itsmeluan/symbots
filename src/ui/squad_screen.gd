## SquadScreen — choose the four who fight (Core Design §2.1, §3.1).
##
## Four slots on top, the bench below. Tap a slot to select it, tap a Symbot to put them
## in. The screen shows each Symbot's ROLE prominently, because squad composition is the
## strategic layer that replaced build-from-parts in v1 — a player who cannot see at a
## glance that they have fielded three DPS and no healer will field it.
class_name SquadScreen
extends Screen

const SpeciesDefScript := preload("res://src/core/species/species_def.gd")

signal closed

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const MIN_ROW_HEIGHT := 52
const ROLE_NAMES: Dictionary = {
	SpeciesDefScript.Role.DPS: "DPS",
	SpeciesDefScript.Role.TANK: "TANK",
	SpeciesDefScript.Role.HEALER: "HEAL",
	SpeciesDefScript.Role.SUPPORT: "SUPP",
}

var _ctx: ServiceContext = null

## Which slot the next bench tap fills. -1 means none is armed.
var _armed_slot: int = -1

var _slot_row: HBoxContainer
var _bench: VBoxContainer
var _warning: Label


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_build_layout()
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	var content := build_chrome(_ctx, "SQUAD", &"squad", func(d): navigate.emit(d))

	_slot_row = HBoxContainer.new()
	_slot_row.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT + 12)
	content.add_child(_slot_row)

	_warning = Label.new()
	_warning.add_theme_font_size_override("font_size", 9)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_warning)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_bench = VBoxContainer.new()
	_bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bench.add_theme_constant_override("separation", 4)
	scroll.add_child(_bench)


func refresh() -> void:
	if _ctx == null:
		return
	_rebuild_slots()
	_rebuild_bench()
	_refresh_warning()


func _rebuild_slots() -> void:
	_clear(_slot_row)
	for slot in PlayerRoster.SQUAD_SIZE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_pressed = (_armed_slot == slot)
		button.text = _slot_text(slot)
		button.pressed.connect(Callable(self, "_on_slot_pressed").bind(slot))
		_slot_row.add_child(button)


func _slot_text(slot: int) -> String:
	var id: StringName = _ctx.roster.squad[slot]
	if id == &"":
		return "empty"
	var symbot := _ctx.roster.get_symbot(id)
	var species: SpeciesDef = _ctx.species.get_species(symbot.species_id) \
		if symbot != null else null
	if species == null:
		return "?"
	return "%s\n%s" % [species.display_name, ROLE_NAMES.get(species.role, "")]


func _rebuild_bench() -> void:
	_clear(_bench)
	for symbot in _ctx.roster.symbots:
		_bench.add_child(_build_bench_row(symbot))


func _build_bench_row(symbot: SymbotInstance) -> Control:
	var species: SpeciesDef = _ctx.species.get_species(symbot.species_id)
	var fielded := _ctx.roster.squad.has(symbot.instance_id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s\n%s · MK %s · LV.%d%s" % [
		(species.display_name if species != null else String(symbot.species_id)).to_upper(),
		ROLE_NAMES.get(species.role, "—") if species != null else "—",
		_roman(symbot.mark), symbot.level,
		"   ·   FIELDED" if fielded else ""]
	_style_bench(button, fielded)
	# Enabled even when already fielded: tapping a fielded Symbot into another slot is how
	# the player reorders, and the roster moves rather than duplicates.
	button.pressed.connect(Callable(self, "_on_bench_pressed").bind(symbot))
	return button


## Cyan while it fights, quiet on the bench — the column reads as who is in and who is out.
func _style_bench(button: Button, fielded: bool) -> void:
	var box := UIPalette.row(UIPalette.CYAN if fielded else UIPalette.LINE, not fielded)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_theme_color_override("font_color",
		UIPalette.TEXT if fielded else UIPalette.MUTED)
	button.add_theme_font_size_override("font_size", 12)


func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(n)


## Warn about a composition that will not work, without blocking it. The design does not
## forbid four DPS — it just makes them lose — so this informs rather than forbids.
func _refresh_warning() -> void:
	var roles: Dictionary = {}
	for symbot in _ctx.roster.squad_symbots():
		var species: SpeciesDef = _ctx.species.get_species(symbot.species_id)
		if species != null:
			roles[species.role] = true

	if _ctx.roster.squad_size() < PlayerRoster.SQUAD_SIZE:
		_warning.text = "Squad is short-handed (%d of %d)" % [
			_ctx.roster.squad_size(), PlayerRoster.SQUAD_SIZE]
	elif not roles.has(SpeciesDefScript.Role.TANK):
		# Without a tank, nothing holds the enemy taunt line and the back row takes
		# everything (§3.3).
		_warning.text = "No tank — your back row will take every hit"
	elif not roles.has(SpeciesDefScript.Role.HEALER):
		_warning.text = "No healer — damage taken is permanent for the run"
	else:
		_warning.text = ""


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_slot_pressed(slot: int) -> void:
	# Tapping the armed slot again clears it — that is how a player empties a slot without
	# needing a separate "remove" control.
	if _armed_slot == slot:
		_ctx.roster.clear_squad_slot(slot)
		_armed_slot = -1
	else:
		_armed_slot = slot
	refresh()


func _on_bench_pressed(symbot: SymbotInstance) -> void:
	# With no slot armed, drop them into the first empty one. Making the player arm a slot
	# first for the common case would be a step with no decision in it.
	var slot := _armed_slot if _armed_slot >= 0 else _first_empty_slot()
	if slot < 0:
		return
	_ctx.roster.set_squad_slot(slot, symbot.instance_id)
	_armed_slot = -1
	refresh()


func _first_empty_slot() -> int:
	for i in PlayerRoster.SQUAD_SIZE:
		if _ctx.roster.squad[i] == &"":
			return i
	return -1


func _on_close_pressed() -> void:
	closed.emit()


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
