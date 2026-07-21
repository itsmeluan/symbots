## UITheme — builds the Godot Theme from [UIPalette] (approved v1 UI prototype).
##
## Applied once at the game root so EVERY screen inherits the dark sci-fi look at once,
## instead of each screen fighting Godot's editor-grey defaults. Built in code rather than
## saved as a .tres so it can never drift from the palette tokens.
##
## Static-only. Call [method build] once and assign it to the root Control's `theme`.
class_name UITheme
extends RefCounted


## Assemble the whole theme. Sets fonts, colours and StyleBoxes for the control types the
## game actually uses; anything else falls back to Godot defaults tinted by the base font
## colour, which is close enough for the rare unstyled control.
static func build() -> Theme:
	var t := Theme.new()
	var display := UIPalette.display_font()

	# One family (Rajdhani) everywhere; body is Regular.
	t.default_font = UIPalette.regular_font()
	t.default_font_size = 13

	_style_label(t)
	_style_button(t, display)
	_style_check_button(t, display)
	_style_panel(t)
	_style_progress(t)
	_style_scroll(t)
	return t


static func _style_label(t: Theme) -> void:
	# Base labels: Rajdhani Regular, primary text.
	t.set_font(&"font", &"Label", UIPalette.regular_font())
	t.set_color(&"font_color", &"Label", UIPalette.TEXT)
	# "Heading" — the bold weight, for titles and Symbot names.
	t.set_type_variation(&"Heading", &"Label")
	t.set_font(&"font", &"Heading", UIPalette.bold_font())
	t.set_color(&"font_color", &"Heading", UIPalette.TEXT)
	t.set_font_size(&"font_size", &"Heading", 20)
	# "Light" — the thin weight, for small numbers and captions (Lv, stat values).
	t.set_type_variation(&"Light", &"Label")
	t.set_font(&"font", &"Light", UIPalette.light_font())
	t.set_color(&"font_color", &"Light", UIPalette.TEXT)
	t.set_font_size(&"font_size", &"Light", 11)


static func _style_button(t: Theme, display: FontFile) -> void:
	t.set_font(&"font", &"Button", display)
	t.set_font_size(&"font_size", &"Button", 15)
	t.set_color(&"font_color", &"Button", UIPalette.TEXT)
	t.set_color(&"font_hover_color", &"Button", UIPalette.CYAN)
	t.set_color(&"font_pressed_color", &"Button", UIPalette.CYAN)
	t.set_color(&"font_disabled_color", &"Button", UIPalette.DISABLED)
	t.set_stylebox(&"normal", &"Button", UIPalette.button("normal"))
	t.set_stylebox(&"hover", &"Button", UIPalette.button("hover"))
	t.set_stylebox(&"pressed", &"Button", UIPalette.button("pressed"))
	t.set_stylebox(&"disabled", &"Button", UIPalette.button("disabled"))
	t.set_stylebox(&"focus", &"Button", UIPalette.empty())

	# A "Primary" variation — the amber call-to-action button.
	t.set_type_variation(&"Primary", &"Button")
	t.set_font(&"font", &"Primary", display)
	t.set_font_size(&"font_size", &"Primary", 16)
	t.set_color(&"font_color", &"Primary", UIPalette.INK)
	t.set_color(&"font_hover_color", &"Primary", UIPalette.INK)
	t.set_color(&"font_pressed_color", &"Primary", UIPalette.INK)
	t.set_color(&"font_disabled_color", &"Primary", UIPalette.DISABLED)
	t.set_stylebox(&"normal", &"Primary", UIPalette.primary_button("normal"))
	t.set_stylebox(&"hover", &"Primary", UIPalette.primary_button("hover"))
	t.set_stylebox(&"pressed", &"Primary", UIPalette.primary_button("pressed"))
	t.set_stylebox(&"disabled", &"Primary", UIPalette.primary_button("disabled"))
	t.set_stylebox(&"focus", &"Primary", UIPalette.empty())


static func _style_check_button(t: Theme, display: FontFile) -> void:
	t.set_font(&"font", &"CheckButton", display)
	t.set_color(&"font_color", &"CheckButton", UIPalette.MUTED)
	t.set_color(&"font_pressed_color", &"CheckButton", UIPalette.CYAN)


static func _style_panel(t: Theme) -> void:
	t.set_stylebox(&"panel", &"PanelContainer", UIPalette.panel())
	t.set_stylebox(&"panel", &"Panel", UIPalette.panel())


static func _style_progress(t: Theme) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIPalette.INK
	bg.set_border_width_all(1)
	bg.border_color = UIPalette.LINE
	bg.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIPalette.CYAN
	fill.set_corner_radius_all(2)
	t.set_stylebox(&"background", &"ProgressBar", bg)
	t.set_stylebox(&"fill", &"ProgressBar", fill)
	t.set_color(&"font_color", &"ProgressBar", UIPalette.TEXT)


static func _style_scroll(t: Theme) -> void:
	# Scroll containers and their inner boxes draw nothing — the screen behind shows through.
	t.set_stylebox(&"panel", &"ScrollContainer", UIPalette.empty())
