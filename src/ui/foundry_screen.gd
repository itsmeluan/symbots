## FoundryScreen — craft new Symbots from learned blueprints (Core Design §5.1).
##
## Portrait list of the whole roster: species whose blueprint you own show a Craft button
## with its Alloy cost; ones you have not found yet are shown greyed with "defeat to learn".
##
## Showing the LOCKED species too, not just the ones you can build, is deliberate — it is
## the collection board. Seeing the silhouette of what you have not caught is the reason to
## keep fighting; a screen that only listed what you already own would teach nothing about
## what is left.
class_name FoundryScreen
extends Screen

const CraftingServiceScript := preload("res://src/core/economy/crafting_service.gd")
const UnitPanelScript := preload("res://src/ui/battle/unit_panel.gd")

signal closed

## Bottom-dock navigation; the game root routes it.
signal navigate(dest: StringName)

const MIN_ROW_HEIGHT := 52
const CARD_COLUMNS := 2
const CARD_HEIGHT := 168

var _ctx: ServiceContext = null
var _craft_counter: int = 0

var _list: GridContainer


func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	# A craft counter seeded from the roster size keeps crafted ids unique across a session
	# even if the player crafts, releases, and crafts again.
	_craft_counter = ctx.roster.symbots.size()
	_build_layout()
	refresh()


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _build_layout() -> void:
	_set_background("res://assets/art/workshop/bench_backdrop.png", 0.62)
	var content := build_chrome(_ctx, "FORGE", &"foundry", func(d): navigate.emit(d))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	UIPalette.thin_scrollbar(scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_right", 8)
	scroll.add_child(pad)

	_list = GridContainer.new()
	_list.columns = CARD_COLUMNS
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 6)
	_list.add_theme_constant_override("v_separation", 6)
	pad.add_child(_list)


func refresh() -> void:
	if _ctx == null:
		return
	refresh_chrome_wallet()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	# Whole roster, so locked species are visible as targets — but ordered by what the player
	# can act on RIGHT NOW: buildable first, then known-but-unaffordable, then locked. Sorting
	# only by "known" still buried the one row worth tapping under recipes you cannot pay for.
	var all := _ctx.species.entries.duplicate()
	all.sort_custom(func(a, b):
		var ra := _craft_rank(a)
		var rb := _craft_rank(b)
		if ra != rb:
			return ra < rb
		return String(a.id) < String(b.id))
	for species in all:
		_list.add_child(_build_card(species))


## 0 buildable now, 1 recipe known but not affordable, 2 still locked.
func _craft_rank(species: SpeciesDef) -> int:
	if not _ctx.blueprints.has_blueprint(species.id):
		return 2
	var refusal := CraftingServiceScript.can_craft(species.id, _ctx.species,
		_ctx.blueprints, _ctx.wallet)
	return 0 if refusal == CraftingServiceScript.Refusal.OK else 1


## One collection-board card: the species over its status over a craft/cost action.
## A KNOWN blueprint shows the full creature and an amber CRAFT; an UNFOUND one is a black
## silhouette labelled "Blueprint not found" — the same collection tease as the unit
## modal's evolution strip, and the reason to keep fighting.
func _build_card(species: SpeciesDef) -> Control:
	var known := _ctx.blueprints.has_blueprint(species.id)
	var refusal := CraftingServiceScript.can_craft(species.id, _ctx.species,
		_ctx.blueprints, _ctx.wallet)
	var owned := _count_owned(species.id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var face := Color("1b242f") if known else Color("161e27")
	var rim := Color(UIPalette.ALLOY, 0.6) if known else Color.TRANSPARENT
	card.add_theme_stylebox_override("panel",
		UIPalette.chunky(face, "normal", Color.TRANSPARENT, rim))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	card.add_child(column)

	var name_label := Label.new()
	name_label.text = ("Blueprint: %s" % species.display_name) if known else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIPalette.bold_font())
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color",
		UIPalette.TEXT if known else UIPalette.MUTED)
	name_label.clip_text = true
	column.add_child(name_label)

	var sprite := TextureRect.new()
	sprite.texture = UnitPanelScript.art_texture(species.id, 1)
	sprite.custom_minimum_size = Vector2(0, 62)
	sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not known:
		sprite.modulate = Color.BLACK   # the "who's that" silhouette
	column.add_child(sprite)

	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 9)
	caption.clip_text = true
	if known:
		caption.text = ("OWNED ×%d" % owned) if owned else "Not built yet"
		caption.add_theme_color_override("font_color",
			UIPalette.ALLOY if owned else UIPalette.MUTED)
	else:
		caption.text = "Blueprint not found"
		caption.add_theme_color_override("font_color", UIPalette.DISABLED)
	column.add_child(caption)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 34)
	button.clip_text = true
	button.text = _button_text(species, refusal)
	button.disabled = refusal != CraftingServiceScript.Refusal.OK
	button.add_theme_font_size_override("font_size", 11)
	if refusal == CraftingServiceScript.Refusal.OK:
		button.theme_type_variation = &"Primary"
		button.add_child(UIPalette.gloss())
		button.pressed.connect(Callable(self, "_on_craft_pressed").bind(species.id))
	column.add_child(button)
	return card


## The button says WHY it cannot be pressed, because "locked" and "cannot afford" mean
## different next actions — find the boss versus grind Alloy.
func _button_text(species: SpeciesDef, refusal: int) -> String:
	match refusal:
		CraftingServiceScript.Refusal.BLUEPRINT_LOCKED:
			return "Locked"
		CraftingServiceScript.Refusal.CANNOT_AFFORD:
			return "%d Alloy" % species.craft_alloy_cost
	return "Craft (%d)" % species.craft_alloy_cost


func _count_owned(species_id: StringName) -> int:
	var n := 0
	for s in _ctx.roster.symbots:
		if s.species_id == species_id:
			n += 1
	return n


func _on_craft_pressed(species_id: StringName) -> void:
	_craft_counter += 1
	var crafted := CraftingServiceScript.craft(species_id, _ctx.species, _ctx.blueprints,
		_ctx.wallet, _ctx.roster, _craft_counter)
	refresh()
	if crafted != null:
		_show_craft_success(_ctx.species.get_species(species_id))


## The forge moment: SUCCESS stamps over a scrim with the newborn standing under it —
## the same celebration grammar as the battle's victory. Any tap dismisses.
func _show_craft_success(species: SpeciesDef) -> void:
	if species == null:
		return
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(UIPalette.INK, 0.82)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			overlay.queue_free())
	overlay.add_child(scrim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(column)

	var stamp := Label.new()
	stamp.text = "SUCCESS"
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_theme_font_override("font", UIPalette.bold_font())
	stamp.add_theme_font_size_override("font_size", 40)
	stamp.add_theme_color_override("font_color", UIPalette.GREEN)
	stamp.add_theme_color_override("font_outline_color", UIPalette.INK)
	stamp.add_theme_constant_override("outline_size", 8)
	column.add_child(stamp)

	# The newborn stands in a little stage so a burst of light can flare BEHIND it as it lands.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 150)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)

	var burst := Control.new()
	burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.draw.connect(_draw_forge_burst.bind(burst))
	stage.add_child(burst)

	var sprite := TextureRect.new()
	sprite.texture = UnitPanel.art_texture(species.id, 1)
	sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.resized.connect(func() -> void: sprite.pivot_offset = sprite.size * 0.5)
	stage.add_child(sprite)

	var caption := Label.new()
	caption.text = "%s joins the roster" % species.display_name
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", UIPalette.MUTED)
	column.add_child(caption)

	# The stamp-and-reveal, now with life: the title scales in, then the newborn POPS —
	# growing past its size while a ring of light flares out behind it, then settling back to
	# rest. The overshoot-and-settle is the "it's alive" beat the flat fade was missing.
	stamp.modulate.a = 0.0
	stamp.scale = Vector2(1.35, 1.35)
	stamp.resized.connect(func() -> void: stamp.pivot_offset = stamp.size * 0.5)
	sprite.modulate.a = 0.0
	sprite.pivot_offset = Vector2(sprite.size.x * 0.5, 75.0)
	sprite.scale = Vector2(0.45, 0.45)
	caption.modulate.a = 0.0
	var tween := overlay.create_tween()
	tween.tween_property(stamp, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The newborn fades in while growing PAST full size, with the light burst in lockstep.
	tween.tween_property(sprite, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(
		func(v: float) -> void: burst.set_meta(&"t", v); burst.queue_redraw(), 0.0, 1.0, 0.5)
	# ...then settles back to its true size, and the caption arrives.
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(caption, "modulate:a", 1.0, 0.18)


## A one-shot ring of light behind a newly-forged Symbot: twelve rays and a ring that expand
## outward and fade as [param ctrl]'s "t" meta runs 0→1. Purely celebratory (Rodada 3).
func _draw_forge_burst(ctrl: Control) -> void:
	var t := float(ctrl.get_meta(&"t", 0.0))
	if t <= 0.0 or t >= 1.0:
		return
	var centre := ctrl.size * 0.5
	var reach := minf(ctrl.size.x, ctrl.size.y) * 0.62
	var radius := reach * t
	var alpha := 1.0 - t
	for i in 12:
		var ang := TAU * float(i) / 12.0
		var dir := Vector2(cos(ang), sin(ang))
		ctrl.draw_line(centre + dir * radius * 0.5, centre + dir * radius,
			Color(UIPalette.AMBER, alpha * 0.8), 3.0)
	ctrl.draw_arc(centre, radius * 0.9, 0.0, TAU, 40, Color(UIPalette.AMBER, alpha * 0.45), 2.0)


func _on_close_pressed() -> void:
	closed.emit()
