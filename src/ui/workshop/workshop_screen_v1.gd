## WorkshopScreenV1 — level parts with Scrap, and advance a generation (Core Design §2.3,
## §2.4, §5).
##
## Portrait, redesigned from the v1 prototype: the focused Symbot fills the centre as a big
## sprite, a chamfered nameplate and a GEN ▲ button sit under the header, the five parts run
## down the left as icons with small upgrade buttons, and a draggable carousel of the roster
## runs along the bottom. Spinning the carousel changes who is in focus everywhere.
##
## The screen carries NO written labels for things a glyph can say — part names live in a
## tap tooltip, roles are icons. The "spread or concentrate" decision (§5.2) still needs its
## numbers on screen, so the cost-to-max and each part's price stay visible; those are digits,
## not names.
##
## Owns no rules. Prices come from [UpgradeEconomy], caps from [SymbotInstance]; the screen
## asks and draws. A view that re-derived a price could quote one number and charge another.
class_name WorkshopScreenV1
extends Screen

const SymbotInstanceScript := preload("res://src/core/species/symbot_instance.gd")
const UpgradeEconomyScript := preload("res://src/core/economy/upgrade_economy.gd")

## Emitted when the player wants to leave. The root decides where to (ADR-0004/0008).
signal closed

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const MIN_ROW_HEIGHT := 48  ## past the 44pt touch minimum
const PART_ROW_HEIGHT := 52
const PART_NAMES: Array[String] = ["Core", "Chassis", "Head", "Arms", "Legs"]
const PART_GLYPHS: Array[StringName] = [&"part_core", &"part_chassis", &"part_head", &"part_arms", &"part_legs"]
const ART_DIR := "res://assets/art/symbots/"

var _ctx: ServiceContext = null
var _screen_root: VBoxContainer
var _selected: SymbotInstance = null

var _scrap_label: Label
var _alloy_label: Label
var _nameplate: SymbotNameplate
var _gen_button: Button
var _hero: TextureRect
var _part_list: VBoxContainer
var _summary_label: Label
var _carousel: SymbotCarousel

# Tap overlay (part names, the gen-up requirement) — one reusable layer on top of everything.
var _overlay_layer: Control
var _overlay_panel: PanelContainer
var _overlay_label: Label
var _overlay_timer: Timer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.55)
	_build_layout()
	_attach_bottom_dock(_screen_root, &"workshop", func(d): navigate.emit(d))
	if _ctx.wallet != null:
		_connect_owned(_ctx.wallet.balance_changed, Callable(self, "_on_balance_changed"))
	_populate_carousel()
	var squad := _ctx.roster.squad_symbots()
	_selected = squad[0] if not squad.is_empty() else (
		_ctx.roster.symbots[0] if not _ctx.roster.symbots.is_empty() else null)
	if _selected != null:
		_carousel.focus(_index_of(_selected))
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null
	_selected = null


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	_screen_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 8)
	add_child(pad)
	pad.add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_subheader())
	root.add_child(_build_mid())

	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 9)
	_summary_label.add_theme_color_override("font_color", UIPalette.MUTED)
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_summary_label)

	_carousel = SymbotCarousel.new()
	_carousel.focused_changed.connect(_on_focus_changed)
	root.add_child(_carousel)

	_build_overlay_layer()


## Left: the screen name. Right: the two currencies stacked, Scrap over Alloy, each led by
## its own glyph in its own colour.
func _build_header() -> Control:
	var header := HBoxContainer.new()

	var title := Label.new()
	title.theme_type_variation = &"Heading"
	title.text = "WORKSHOP"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)

	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 1)
	money.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(money)
	_scrap_label = _make_currency_row(money, &"scrap", UIPalette.SCRAP)
	_alloy_label = _make_currency_row(money, &"alloy", UIPalette.ALLOY)
	return header


func _make_currency_row(parent: VBoxContainer, glyph: StringName, colour: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(row)
	row.add_child(IconGlyph.new(glyph, colour, 16.0))
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", colour)
	row.add_child(label)
	return label


## The nameplate on the left, the GEN ▲ button on the right, on one line under the header.
func _build_subheader() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	_nameplate = SymbotNameplate.new()
	_nameplate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_nameplate)

	_gen_button = Button.new()
	_gen_button.text = "GEN ▲"
	_gen_button.custom_minimum_size = Vector2(76, 46)
	_gen_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gen_button.clip_text = true
	_gen_button.pressed.connect(Callable(self, "_on_gen_up_pressed"))
	row.add_child(_gen_button)
	return row


## Parts down the left, the hero sprite filling the centre. The right is reserved for the
## stats/skills drawer (a later pass); for now it is empty space so the sprite is not off-centre.
func _build_mid() -> Control:
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)

	_part_list = VBoxContainer.new()
	_part_list.custom_minimum_size = Vector2(122, 0)
	_part_list.add_theme_constant_override("separation", 4)
	mid.add_child(_part_list)

	var hero_wrap := CenterContainer.new()
	hero_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(hero_wrap)
	_hero = TextureRect.new()
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.custom_minimum_size = Vector2(180, 220)
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_wrap.add_child(_hero)

	var drawer_reserve := Control.new()
	drawer_reserve.custom_minimum_size = Vector2(22, 0)
	mid.add_child(drawer_reserve)
	return mid


func _build_overlay_layer() -> void:
	_overlay_layer = Control.new()
	_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.visible = false
	_overlay_layer.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_hide_overlay())
	add_child(_overlay_layer)

	_overlay_panel = PanelContainer.new()
	_overlay_panel.add_theme_stylebox_override("panel", UIPalette.panel(UIPalette.CYAN, UIPalette.PANEL_2))
	_overlay_layer.add_child(_overlay_panel)
	_overlay_label = Label.new()
	_overlay_label.add_theme_font_size_override("font_size", 12)
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_label.custom_minimum_size = Vector2(0, 0)
	_overlay_panel.add_child(_overlay_label)

	_overlay_timer = Timer.new()
	_overlay_timer.one_shot = true
	_overlay_timer.timeout.connect(_hide_overlay)
	add_child(_overlay_timer)


# ---------------------------------------------------------------------------
# Data → view
# ---------------------------------------------------------------------------

func refresh() -> void:
	if _ctx == null:
		return
	_refresh_wallet()
	_refresh_hero_and_name()
	_rebuild_parts()
	_refresh_gen()


func _refresh_wallet() -> void:
	if _ctx.wallet == null:
		return
	_scrap_label.text = _fmt(_ctx.wallet.scrap)
	_alloy_label.text = _fmt(_ctx.wallet.alloy)


func _on_balance_changed(_currency: StringName, _amount: int) -> void:
	_refresh_wallet()
	_refresh_gen()


func _refresh_hero_and_name() -> void:
	var species: SpeciesDef = _species_of(_selected)
	_nameplate.set_symbot(species, _selected)
	_hero.texture = _sprite_for(_selected)


func _rebuild_parts() -> void:
	_clear(_part_list)
	if _selected == null:
		_summary_label.text = ""
		return

	# The number that makes "spread or concentrate" a real decision rather than a default.
	var to_max := UpgradeEconomyScript.cost_to_max_all_parts(_selected, _ctx.balance)
	_summary_label.text = "Part cap %d  ·  max all parts %d Scrap" % [
		_selected.part_level_cap(), to_max]

	for slot in SymbotInstanceScript.PART_COUNT:
		_part_list.add_child(_build_part_row(slot))


## One part: a tappable glyph (shows the part's name), its level, and a small upgrade button
## with the Scrap price. The glyph is the only thing that names the part, and only when tapped.
func _build_part_row(slot: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, PART_ROW_HEIGHT)
	row.add_theme_constant_override("separation", 4)

	var icon := IconGlyph.new(PART_GLYPHS[slot], UIPalette.TEXT, 30.0)
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.gui_input.connect(func(e): _on_part_icon_input(e, slot, icon))
	row.add_child(icon)

	var level := Label.new()
	level.add_theme_font_size_override("font_size", 11)
	level.add_theme_color_override("font_color", UIPalette.MUTED)
	level.text = "%d/%d" % [_selected.get_part_level(slot), _selected.part_level_cap()]
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(level)

	var refusal := UpgradeEconomyScript.can_upgrade(_selected, slot, _ctx.wallet, _ctx.balance)
	var button := Button.new()
	button.custom_minimum_size = Vector2(50, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 11)
	button.disabled = refusal != UpgradeEconomyScript.Refusal.OK
	button.text = _upgrade_label(slot, refusal)
	if refusal == UpgradeEconomyScript.Refusal.OK:
		button.theme_type_variation = &"Primary"
		button.pressed.connect(Callable(self, "_on_upgrade_pressed").bind(slot))
	row.add_child(button)
	return row


## The button says WHY it cannot be pressed. "Capped" and "cannot afford" send the player to
## different places — one means go gen-up, the other means go fight — and a button that just
## greys out tells them neither.
func _upgrade_label(slot: int, refusal: int) -> String:
	match refusal:
		UpgradeEconomyScript.Refusal.AT_MARK_CAP:
			return "Capped"
		UpgradeEconomyScript.Refusal.NO_SUCH_PART:
			return "—"
	return "%d" % UpgradeEconomyScript.level_cost(_selected.get_part_level(slot), _ctx.balance)


## GEN ▲ stays visually present but greyed until every part is capped; tapping it while it is
## not ready explains the requirement rather than doing nothing (the player's ask).
func _refresh_gen() -> void:
	var ready := _can_gen_up()
	if ready:
		_gen_button.theme_type_variation = &"Primary"
		_gen_button.remove_theme_color_override("font_color")
		_gen_button.modulate = Color.WHITE
	else:
		_gen_button.theme_type_variation = &""
		_gen_button.add_theme_color_override("font_color", UIPalette.DISABLED)
		_gen_button.modulate = Color(1, 1, 1, 0.75)


## True when advancing a generation is allowed right now.
func _can_gen_up() -> bool:
	return _selected != null and _selected.mark < SymbotInstanceScript.MAX_MARK \
		and _selected.can_retrofit()


## What the player must do before GEN ▲ works — shown in the tap overlay when they try early.
func _gen_requirement_text() -> String:
	if _selected == null:
		return ""
	if _selected.mark >= SymbotInstanceScript.MAX_MARK:
		return "Mk III reached — this Symbot is at its final generation."
	return "GEN ▲ needs all 5 parts at level %d.\nMax every part, then advance to Mk %s." % [
		_selected.part_level_cap(), _roman(_selected.mark + 1)]


# ---------------------------------------------------------------------------
# Carousel
# ---------------------------------------------------------------------------

func _populate_carousel() -> void:
	var textures: Array = []
	for symbot in _ctx.roster.symbots:
		textures.append(_sprite_for(symbot))
	_carousel.set_items(textures)


func _on_focus_changed(index: int) -> void:
	if index < 0 or index >= _ctx.roster.symbots.size():
		return
	_selected = _ctx.roster.symbots[index]
	refresh()


func _index_of(symbot: SymbotInstance) -> int:
	return _ctx.roster.symbots.find(symbot)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## A tap on a part icon names the part; a scroll/other event is ignored.
func _on_part_icon_input(event: InputEvent, slot: int, icon: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_tooltip(PART_NAMES[slot], icon.global_position + Vector2(icon.size.x + 6, 0))


## Kept for the carousel-free path (tests, external selection). Sets the focus without
## animating the carousel to avoid a feedback loop.
func _on_symbot_selected(symbot: SymbotInstance) -> void:
	_selected = symbot
	refresh()


func _on_upgrade_pressed(slot: int) -> void:
	# The economy is the authority and re-checks. A price quoted a moment ago can be stale if
	# the wallet moved — better a no-op than a charge the player did not agree to.
	UpgradeEconomyScript.upgrade(_selected, slot, _ctx.wallet, _ctx.balance)
	refresh()


func _on_gen_up_pressed() -> void:
	if _can_gen_up():
		if _selected.retrofit():
			refresh()
	else:
		_show_message(_gen_requirement_text())


func _on_close_pressed() -> void:
	closed.emit()


# ---------------------------------------------------------------------------
# Overlay
# ---------------------------------------------------------------------------

## A small tooltip near a point, auto-dismissed shortly — for part names.
func _show_tooltip(text: String, near: Vector2) -> void:
	_overlay_label.add_theme_color_override("font_color", UIPalette.TEXT)
	_overlay_label.text = text
	_overlay_panel.reset_size()
	_overlay_layer.visible = true
	await get_tree().process_frame
	_place_overlay(near, false)
	_overlay_timer.start(1.6)


## A centred message dismissed on tap — for the gen-up requirement.
func _show_message(text: String) -> void:
	_overlay_timer.stop()
	_overlay_label.add_theme_color_override("font_color", UIPalette.TEXT)
	_overlay_label.text = text
	_overlay_panel.custom_minimum_size = Vector2(minf(260, size.x - 40), 0)
	_overlay_panel.reset_size()
	_overlay_layer.visible = true
	await get_tree().process_frame
	_place_overlay(size * 0.5, true)


func _place_overlay(anchor: Vector2, centred: bool) -> void:
	var panel_size := _overlay_panel.size
	var pos := anchor - (panel_size * 0.5 if centred else Vector2.ZERO)
	pos.x = clampf(pos.x, 8, size.x - panel_size.x - 8)
	pos.y = clampf(pos.y, 8, size.y - panel_size.y - 8)
	_overlay_panel.position = pos


func _hide_overlay() -> void:
	_overlay_timer.stop()
	_overlay_layer.visible = false
	_overlay_panel.custom_minimum_size = Vector2.ZERO


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _species_of(symbot: SymbotInstance) -> SpeciesDef:
	if symbot == null or _ctx == null:
		return null
	return _ctx.species.get_species(symbot.species_id)


## The Symbot's art at its current mark, or null if that art is not authored yet.
func _sprite_for(symbot: SymbotInstance) -> Texture2D:
	if symbot == null:
		return null
	var path := "%s%s_mk%d.png" % [ART_DIR, symbot.species_id, clampi(symbot.mark, 1, 3)]
	return load(path) if ResourceLoader.exists(path) else null


func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(n)


## Group thousands with a dot, matching the prototype's currency readout (8.085).
func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out


func _clear(container: Node) -> void:
	for child in container.get_children():
		# remove_child before queue_free — queue_free is deferred, so a rebuild that only
		# queued would leave the old rows on screen for the rest of the frame.
		container.remove_child(child)
		child.queue_free()
