## SymbotCard — THE roster card, shared by the Symbots screen and the workshop's roster
## drawer so a Symbot looks like the same object everywhere: bold name over the creature
## over its ROLE · MK · LV credentials, chunky frame, and a solid amber rim + FIELDED
## badge when it is in the squad.
##
## Static factory, no instances: the card is a plain Button whose whole summary also
## lives in tooltip_text (desktop hover, and the one string tests read without caring
## about internal layout).
class_name SymbotCard
extends RefCounted

const CARD_HEIGHT := 128


static func build(ctx: ServiceContext, symbot: SymbotInstance,
		on_pressed: Callable) -> Button:
	var species: SpeciesDef = ctx.species.get_species(symbot.species_id)
	var fielded: bool = ctx.roster.squad.has(symbot.instance_id)
	var display_name := species.display_name if species != null \
		else String(symbot.species_id)
	var caption := "%s · MK %s · LV.%d" % [
		UnitPanel.ROLE_TAGS.get(species.role, "—") if species != null else "—",
		_roman(symbot.mark), symbot.level]

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "%s\n%s%s" % [display_name.to_upper(), caption,
		"   ·   FIELDED" if fielded else ""]
	# Same surface as the detail modals (the lighter OVERLAY fill): the list cards and the
	# dossier now read as one raised family. Fielded keeps its solid amber rim.
	var face := UIPalette.OVERLAY
	var rim := UIPalette.AMBER if fielded else Color.TRANSPARENT
	button.add_theme_stylebox_override("normal",
		UIPalette.chunky(face, "normal", Color.TRANSPARENT, rim))
	button.add_theme_stylebox_override("hover",
		UIPalette.chunky(face, "normal", Color.TRANSPARENT, rim))
	button.add_theme_stylebox_override("pressed", UIPalette.chunky(face, "pressed"))
	button.add_theme_stylebox_override("focus", UIPalette.empty())
	button.add_child(UIPalette.gloss(0.06))
	button.pressed.connect(on_pressed)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 5
	column.offset_right = -5
	column.offset_top = 5
	column.offset_bottom = -8
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UIPalette.bold_font())
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)

	var sprite := TextureRect.new()
	sprite.texture = UnitPanel.art_texture(symbot.species_id, symbot.mark)
	sprite.custom_minimum_size = Vector2(0, 56)
	sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sprite)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 8)
	caption_label.add_theme_color_override("font_color", UIPalette.MUTED)
	caption_label.clip_text = true
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(caption_label)

	var badge := Label.new()
	badge.text = "FIELDED" if fielded else " "
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", UIPalette.AMBER)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(badge)
	return button


static func _roman(n: int) -> String:
	match n:
		1: return "I"
		2: return "II"
		3: return "III"
	return str(n)
