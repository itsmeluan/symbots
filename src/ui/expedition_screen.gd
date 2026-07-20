## ExpeditionScreen — send the bench on timed offline runs (Core Design §7).
##
## Slots at the top (active runs with a live countdown, or empty), a duration selector, and
## the bench below — the Symbots not in the squad and not already out, which are exactly who
## expeditions are for. A run is a decision: a Symbot on an expedition cannot fight.
##
## POLLING NOTE: this screen runs a one-second timer to update the countdowns. ADR-0008
## forbids polling MODEL state — but a countdown reads the wall clock, which has no signal
## to subscribe to. The board's state (which slot holds what) is still event-driven via
## `board_changed`; only the elapsed-time display is polled, because time is the one input
## that genuinely changes on its own.
class_name ExpeditionScreen
extends Screen

const ExpeditionBoardScript := preload("res://src/core/expeditions/expedition_board.gd")

signal closed

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const MIN_ROW_HEIGHT := 52
const TICK_SECONDS := 1.0

var _ctx: ServiceContext = null
var _screen_root: VBoxContainer
var _armed_duration: int = ExpeditionBoardScript.Duration.SHORT

var _slots_box: VBoxContainer
var _duration_row: HBoxContainer
var _bench_box: VBoxContainer
var _bench_hint: Label
var _tick: Timer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_build_layout()
	_attach_bottom_dock(_screen_root, &"expeditions", func(d): navigate.emit(d))
	if _ctx.expeditions != null:
		_connect_owned(_ctx.expeditions.board_changed, Callable(self, "_on_board_changed"))
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	_screen_root = root
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
	var title := Label.new()
	title.text = "Expeditions"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	header.add_child(title)

	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 4)
	root.add_child(_slots_box)

	# Duration selector — the run length the next Send uses.
	_duration_row = HBoxContainer.new()
	root.add_child(_duration_row)
	for d in [ExpeditionBoardScript.Duration.SHORT, ExpeditionBoardScript.Duration.MEDIUM,
			ExpeditionBoardScript.Duration.LONG]:
		var b := Button.new()
		b.text = _duration_label(d)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(Callable(self, "_on_duration_pressed").bind(d))
		_duration_row.add_child(b)

	var bench_title := Label.new()
	bench_title.text = "Bench — tap Send to dispatch"
	bench_title.add_theme_font_size_override("font_size", 9)
	root.add_child(bench_title)

	_bench_hint = Label.new()
	_bench_hint.add_theme_font_size_override("font_size", 9)
	_bench_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_bench_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_bench_box = VBoxContainer.new()
	_bench_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bench_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_bench_box)

	# The countdown ticker. See the polling note on the class.
	_tick = Timer.new()
	_tick.wait_time = TICK_SECONDS
	_tick.timeout.connect(Callable(self, "_on_tick"))
	add_child(_tick)
	_tick.start()


func refresh() -> void:
	if _ctx == null:
		return
	_rebuild_slots()
	_refresh_duration_selector()
	_rebuild_bench()


## Only the countdown labels change per second — a full rebuild every tick would rebuild
## the bench and duration row for nothing, and fight the player's scroll position.
func _on_tick() -> void:
	if _ctx == null or _ctx.expeditions == null:
		return
	_rebuild_slots()


func _on_board_changed() -> void:
	refresh()


# ---------------------------------------------------------------------------
# Slots
# ---------------------------------------------------------------------------

func _rebuild_slots() -> void:
	_clear(_slots_box)
	var board := _ctx.expeditions
	for i in board.slots:
		if i < board.active.size():
			_slots_box.add_child(_build_active_slot(i))
		else:
			_slots_box.add_child(_build_empty_slot())


func _build_active_slot(index: int) -> Control:
	var board := _ctx.expeditions
	var entry: Dictionary = board.active[index]
	var symbot := _ctx.roster.get_symbot(entry.get("symbot_id", &""))
	var species: SpeciesDef = _ctx.species.get_species(symbot.species_id) \
		if symbot != null else null

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	var name := species.display_name if species != null else String(entry.get("symbot_id"))
	label.text = "%s  ·  %s  ·  %s" % [name,
		_duration_label(int(entry.get("duration", 1))),
		_time_text(board.seconds_remaining(index))]
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(110, MIN_ROW_HEIGHT)
	button.clip_text = true
	if board.is_ready(index):
		button.text = "Collect"
		button.pressed.connect(Callable(self, "_on_collect_pressed").bind(index))
	else:
		# Recalling pays nothing — the label warns, because losing the run's reward to an
		# early recall would otherwise read as a bug.
		button.text = "Recall"
		button.pressed.connect(Callable(self, "_on_recall_pressed").bind(index))
	row.add_child(button)
	return row


func _build_empty_slot() -> Control:
	var label := Label.new()
	label.text = "— empty slot —"
	label.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.6, 0.6, 0.65)
	return label


# ---------------------------------------------------------------------------
# Duration selector
# ---------------------------------------------------------------------------

func _refresh_duration_selector() -> void:
	var order := [ExpeditionBoardScript.Duration.SHORT,
		ExpeditionBoardScript.Duration.MEDIUM, ExpeditionBoardScript.Duration.LONG]
	for i in _duration_row.get_child_count():
		var b: Button = _duration_row.get_child(i)
		b.button_pressed = (order[i] == _armed_duration)


func _on_duration_pressed(duration: int) -> void:
	_armed_duration = duration
	refresh()


# ---------------------------------------------------------------------------
# Bench
# ---------------------------------------------------------------------------

## Owned, not in the squad, not already out. That intersection is who an expedition is for —
## the squad fights, and a Symbot cannot be in two places.
func _benched() -> Array:
	var out: Array = []
	for s in _ctx.roster.symbots:
		if _ctx.roster.squad.has(s.instance_id):
			continue
		if _ctx.expeditions.is_busy(s.instance_id):
			continue
		out.append(s)
	return out


func _rebuild_bench() -> void:
	_clear(_bench_box)
	var bench := _benched()
	var free := _ctx.expeditions.free_slots()

	if bench.is_empty():
		# A fresh player has all four Symbots in the squad, so the bench is empty. Say why,
		# rather than showing a blank panel that looks broken.
		_bench_hint.text = "No benched Symbots. Craft more, or take one out of the squad, " \
			+ "to send it on an expedition."
		return
	_bench_hint.text = "%d expedition slot%s free" % [free, "" if free == 1 else "s"]

	for symbot in bench:
		_bench_box.add_child(_build_bench_row(symbot, free > 0))


func _build_bench_row(symbot: SymbotInstance, a_slot_is_free: bool) -> Control:
	var species: SpeciesDef = _ctx.species.get_species(symbot.species_id)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, MIN_ROW_HEIGHT)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text = "%s  L%d" % [
		species.display_name if species != null else String(symbot.species_id), symbot.level]
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(110, MIN_ROW_HEIGHT)
	button.clip_text = true
	button.text = "Send" if a_slot_is_free else "Slots full"
	button.disabled = not a_slot_is_free
	if a_slot_is_free:
		button.pressed.connect(Callable(self, "_on_send_pressed").bind(symbot.instance_id))
	row.add_child(button)
	return row


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_send_pressed(symbot_id: StringName) -> void:
	_ctx.expeditions.send(symbot_id, _armed_duration, _ctx.roster)
	refresh()  # board_changed also fires, but refresh here keeps the tap responsive


func _on_collect_pressed(index: int) -> void:
	var payout := _ctx.expeditions.collect(index, _ctx.balance, _ctx.roster, _ctx.rng)
	# The board returns the payout; the screen applies it, so the board stays a pure
	# simulation with no reach into the wallet or inventory.
	if not payout.is_empty():
		if _ctx.wallet != null and int(payout.get("scrap", 0)) > 0:
			_ctx.wallet.earn(Wallet.SCRAP, int(payout["scrap"]))
		if _ctx.inventory_items != null:
			for item_id in payout.get("items", []):
				_ctx.inventory_items.add(item_id)
	refresh()


func _on_recall_pressed(index: int) -> void:
	_ctx.expeditions.cancel(index)
	refresh()


func _on_close_pressed() -> void:
	closed.emit()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _duration_label(duration: int) -> String:
	match duration:
		ExpeditionBoardScript.Duration.SHORT: return "1h"
		ExpeditionBoardScript.Duration.MEDIUM: return "4h"
		ExpeditionBoardScript.Duration.LONG: return "8h"
	return "?"


## Remaining time as the coarsest useful unit — a player glancing at a slot wants "2h 14m",
## not a second-by-second readout that never sits still.
func _time_text(seconds: int) -> String:
	if seconds <= 0:
		return "READY"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, s]
	return "%ds" % s


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
