## WorkshopScreenV1 — level parts with Scrap, and retrofit (Core Design §2.3, §2.4, §5).
##
## Portrait: roster strip along the top, the selected Symbot's five parts below, each with
## its level and the Scrap price of the next one. The whole "spread or concentrate"
## decision (§5.2) happens on this screen, so the numbers that make it a decision — what a
## level costs, what maxing everything would cost — are on screen rather than discoverable.
##
## Owns no rules. Prices come from [UpgradeEconomy], caps from [SymbotInstance]; the screen
## asks and draws. A view that re-derived a price could quote one number and charge another.
class_name WorkshopScreenV1
extends Screen

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const UpgradeEconomyScript := preload("res://src/core/economy/upgrade_economy.gd")

## Emitted when the player wants to leave. The root decides where to (ADR-0004/0008).
signal closed

const MIN_ROW_HEIGHT := 48  ## past the 44pt touch minimum
const PART_NAMES: Array[String] = ["Core", "Chassis", "Head", "Arms", "Legs"]

var _ctx: ServiceContext = null
var _selected: SymbotInstance = null

var _scrap_label: Label
var _title_label: Label
var _summary_label: Label
var _roster_strip: HBoxContainer
var _part_list: VBoxContainer
var _retrofit_button: Button


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.6)
	_build_layout()
	if _ctx.wallet != null:
		_connect_owned(_ctx.wallet.balance_changed, Callable(self, "_on_balance_changed"))
	var squad := _ctx.roster.squad_symbots()
	_selected = squad[0] if not squad.is_empty() else null
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null
	_selected = null


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	var back := Button.new()
	back.text = "< Map"
	back.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	back.pressed.connect(Callable(self, "_on_close_pressed"))
	header.add_child(back)
	_scrap_label = Label.new()
	_scrap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_scrap_label)

	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT + 8)
	roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(roster_scroll)
	_roster_strip = HBoxContainer.new()
	roster_scroll.add_child(_roster_strip)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 13)
	root.add_child(_title_label)

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 9)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_summary_label)

	_part_list = VBoxContainer.new()
	_part_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_part_list.add_theme_constant_override("separation", 4)
	root.add_child(_part_list)

	_retrofit_button = Button.new()
	_retrofit_button.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	_retrofit_button.pressed.connect(Callable(self, "_on_retrofit_pressed"))
	root.add_child(_retrofit_button)


## Full redraw. Cheap at five parts and a handful of Symbots, and a rebuild cannot leave a
## stale price on screen — which on this screen would mean quoting one number and charging
## another.
func refresh() -> void:
	if _ctx == null:
		return
	_refresh_wallet()
	_rebuild_roster_strip()
	_rebuild_parts()
	_refresh_retrofit()


func _refresh_wallet() -> void:
	if _ctx.wallet != null:
		_scrap_label.text = "Scrap %d" % _ctx.wallet.scrap


func _on_balance_changed(_currency: StringName, _amount: int) -> void:
	_refresh_wallet()


func _rebuild_roster_strip() -> void:
	_clear(_roster_strip)
	for symbot in _ctx.roster.symbots:
		var species: SpeciesDef = _ctx.species.get_species(symbot.species_id)
		if species == null:
			continue
		var button := Button.new()
		button.text = "%s\nMk%d L%d" % [species.display_name, symbot.mark, symbot.level]
		button.custom_minimum_size = Vector2(72, MIN_ROW_HEIGHT)
		button.toggle_mode = true
		button.button_pressed = (_selected == symbot)
		button.pressed.connect(Callable(self, "_on_symbot_selected").bind(symbot))
		_roster_strip.add_child(button)


func _rebuild_parts() -> void:
	_clear(_part_list)
	if _selected == null:
		_title_label.text = "No Symbot selected"
		_summary_label.text = ""
		return

	var species: SpeciesDef = _ctx.species.get_species(_selected.species_id)
	_title_label.text = "%s — Mk %d, level %d" % [
		species.display_name if species != null else String(_selected.species_id),
		_selected.mark, _selected.level]

	# The number that makes "spread or concentrate" a real decision rather than a default.
	var to_max := UpgradeEconomyScript.cost_to_max_all_parts(_selected, _ctx.balance)
	_summary_label.text = "Part cap %d · %d Scrap to max every part at this mark" % [
		_selected.part_level_cap(), to_max]

	for slot in SymbotInstanceScript.PART_COUNT:
		_part_list.add_child(_build_part_row(slot))


func _build_part_row(slot: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)

	var level := _selected.get_part_level(slot)
	var label := Label.new()
	label.text = "%s  %d/%d" % [PART_NAMES[slot], level, _selected.part_level_cap()]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var refusal := UpgradeEconomyScript.can_upgrade(_selected, slot, _ctx.wallet, _ctx.balance)
	var button := Button.new()
	button.custom_minimum_size = Vector2(110, MIN_ROW_HEIGHT)
	button.disabled = refusal != UpgradeEconomyScript.Refusal.OK
	button.text = _upgrade_label(slot, refusal)
	if refusal == UpgradeEconomyScript.Refusal.OK:
		button.pressed.connect(Callable(self, "_on_upgrade_pressed").bind(slot))
	row.add_child(button)
	return row


## The button says WHY it cannot be pressed. "Capped" and "cannot afford" send the player
## to completely different places — one means go fight, the other means go retrofit — and a
## button that just greys out tells them neither.
func _upgrade_label(slot: int, refusal: int) -> String:
	match refusal:
		UpgradeEconomyScript.Refusal.AT_MARK_CAP:
			return "Capped"
		UpgradeEconomyScript.Refusal.NO_SUCH_PART:
			return "—"
	return "%d Scrap" % UpgradeEconomyScript.level_cost(_selected.get_part_level(slot), _ctx.balance)


func _refresh_retrofit() -> void:
	if _selected == null:
		_retrofit_button.visible = false
		return
	_retrofit_button.visible = true
	if _selected.mark >= SymbotInstanceScript.MAX_MARK:
		_retrofit_button.text = "Mk III — fully retrofitted"
		_retrofit_button.disabled = true
	elif _selected.can_retrofit():
		# Retrofit raises the cap rather than resetting levels (§2.3), so it is pure upside
		# and never needs a confirmation prompt.
		_retrofit_button.text = "RETROFIT to Mk %d" % (_selected.mark + 1)
		_retrofit_button.disabled = false
	else:
		_retrofit_button.text = "Retrofit at every part %d" % _selected.part_level_cap()
		_retrofit_button.disabled = true


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_symbot_selected(symbot: SymbotInstance) -> void:
	_selected = symbot
	refresh()


func _on_upgrade_pressed(slot: int) -> void:
	# The economy is the authority and re-checks. A price quoted a moment ago can be stale
	# if the wallet moved — better a no-op than a charge the player did not agree to.
	UpgradeEconomyScript.upgrade(_selected, slot, _ctx.wallet, _ctx.balance)
	refresh()


func _on_retrofit_pressed() -> void:
	if _selected != null and _selected.retrofit():
		refresh()


func _on_close_pressed() -> void:
	closed.emit()


func _clear(container: Node) -> void:
	for child in container.get_children():
		# remove_child before queue_free — queue_free is deferred, so a rebuild that only
		# queued would leave the old rows on screen for the rest of the frame, showing two
		# prices for the same part.
		container.remove_child(child)
		child.queue_free()
