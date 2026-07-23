## UIPalette — the single source of the game's visual language (from the approved v1 UI
## prototype, prototypes/symbots-ui-system).
##
## Colours, fonts and StyleBox factories in one place, so every screen reads from the same
## design tokens instead of inventing its own greys. The prototype is React/CSS; this is its
## translation to Godot. Change a token here and the whole game moves with it.
##
## Static-only — call as `UIPalette.CYAN`, `UIPalette.panel()`. Never instanced.
class_name UIPalette
extends RefCounted

# --- Colours (prototype :root tokens) --------------------------------------
const INK := Color("070b11")          ## deepest background
const BG := Color("080c12")           ## app background
const PANEL := Color("101823")        ## panel fill
const PANEL_2 := Color("17212d")      ## raised panel / control fill
const LINE := Color("516171")         ## borders
const LINE_SOFT := Color("2a3744")    ## subtle dividers
const TEXT := Color("f4f7f8")         ## primary text
const MUTED := Color("9ba8b5")        ## secondary text
const CYAN := Color("47d7ea")         ## the accent — selection, ally, focus
const CYAN_DARK := Color("155765")
const AMBER := Color("f2b92b")        ## currency, ultimate, primary action
const AMBER_DARK := Color("5f4714")
const CORAL := Color("ff6d4b")        ## enemy, danger, taunt
const GREEN := Color("69d783")        ## ally HP, success
const DISABLED := Color("65707a")
const SCRAP := AMBER                   ## Scrap currency — the common upgrade sink
const ALLOY := Color("7ec8ff")        ## Alloy currency — the rare blueprint metal (light blue)

# --- Fonts -----------------------------------------------------------------
# One family everywhere (Rajdhani), weight by size: small text light, large text bold.
const DISPLAY_BOLD := "res://assets/fonts/Rajdhani-Bold.woff"       ## titles, names
const DISPLAY_FONT := "res://assets/fonts/Rajdhani-SemiBold.woff"   ## buttons, emphasis
const DISPLAY_MEDIUM := "res://assets/fonts/Rajdhani-Medium.woff"   ## body
const DISPLAY_REGULAR := "res://assets/fonts/Rajdhani-Regular.woff" ## body
const DISPLAY_LIGHT := "res://assets/fonts/Rajdhani-Light.woff"     ## small numbers, captions
# Kept for any lingering references; the theme no longer uses them.
const MONO_FONT := "res://assets/fonts/IBMPlexMono-Regular.woff"
const MONO_BOLD := "res://assets/fonts/IBMPlexMono-SemiBold.woff"


static func display_font() -> FontFile:
	return load(DISPLAY_FONT)


static func bold_font() -> FontFile:
	return load(DISPLAY_BOLD)


static func regular_font() -> FontFile:
	return load(DISPLAY_REGULAR)


static func light_font() -> FontFile:
	return load(DISPLAY_LIGHT)


static func mono_font() -> FontFile:
	return load(DISPLAY_REGULAR)


# --- StyleBox factories ----------------------------------------------------
# The prototype's "tech-panel" look — dark fill, thin cyan-grey border, small radius. A
# factory rather than a saved .tres so a screen can vary one property (accent colour) off
# the shared base without a dozen near-identical resource files.

## A framed panel. [param accent] tints the border (CYAN for normal, CORAL for danger,
## AMBER for a highlighted panel).
static func panel(accent: Color = LINE, fill: Color = PANEL) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(1)
	box.border_color = accent
	box.set_corner_radius_all(4)
	box.set_content_margin_all(8)
	return box


## A list row: dark translucent fill with a coloured bar down its left edge. The v1 list
## idiom — the bar carries the row's state (cyan available, amber earned, grey locked) so a
## glance down a column reads as a column of states, not a wall of text.
static func row(accent: Color, dim: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PANEL, 0.55 if dim else 0.82)
	box.border_width_left = 3
	box.border_color = Color(accent, 0.45) if dim else accent
	box.set_corner_radius_all(3)
	box.set_content_margin(SIDE_LEFT, 10)
	box.set_content_margin(SIDE_RIGHT, 10)
	box.set_content_margin(SIDE_TOP, 7)
	box.set_content_margin(SIDE_BOTTOM, 7)
	return box


## A darker inset panel, for lists and wells.
static func well() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = INK
	box.set_border_width_all(1)
	box.border_color = LINE_SOFT
	box.set_corner_radius_all(3)
	box.set_content_margin_all(6)
	return box


## The amber primary-action button, in its three states.
static func primary_button(state: String = "normal") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(3)
	box.set_content_margin_all(8)
	match state:
		"hover":
			box.bg_color = AMBER.lightened(0.08)
		"pressed":
			box.bg_color = AMBER.darkened(0.15)
		"disabled":
			box.bg_color = PANEL_2
			box.set_border_width_all(1)
			box.border_color = LINE_SOFT
		_:
			box.bg_color = AMBER
	return box


## The dark secondary/normal button.
static func button(state: String = "normal") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_2
	box.set_border_width_all(1)
	box.border_color = LINE
	box.set_corner_radius_all(3)
	box.set_content_margin_all(6)
	match state:
		"hover":
			box.border_color = CYAN.darkened(0.2)
		"pressed":
			box.bg_color = PANEL_2.darkened(0.15)
		"disabled":
			box.bg_color = INK
			box.border_color = LINE_SOFT
	return box


## The angled "tech card" action button — the game's combat-tier control language: a
## skewed parallelogram with a heavier accent edge on the leading side. One factory so
## every screen's action row leans the same 8 degrees.
static func tech_button(accent: Color, state: String = "normal") -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PANEL_2, 0.94)
	box.skew = Vector2(0.14, 0.0)
	box.set_corner_radius_all(2)
	box.border_color = accent
	box.border_width_left = 3
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.set_content_margin_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	match state:
		"selected":
			box.border_color = CYAN
			box.border_width_left = 4
			box.border_width_top = 2
			box.border_width_right = 2
			box.border_width_bottom = 2
			box.bg_color = PANEL_2.lightened(0.07)
		"pressed":
			box.bg_color = PANEL_2.darkened(0.18)
		"disabled":
			box.bg_color = Color(INK, 0.88)
			box.border_color = Color(accent, 0.32)
	return box


## The chunky "volumetric" button — the mobile-game depth language: rounded face, a
## solid darker base edge below it (the 3D lift), and a pressed state that shortens the
## base and drops the face onto it, so a tap physically pushes the button down.
##
## [param base] is the face colour; the depth edge derives from it, so every family of
## button carries its own material. [param rim] (optional) draws a selection ring.
static func chunky(base: Color, state: String = "normal", rim: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(9)
	box.bg_color = base
	box.border_color = base.darkened(0.55)
	box.border_width_bottom = 5
	box.set_content_margin_all(6)
	box.content_margin_bottom = 11
	match state:
		"pressed":
			box.bg_color = base.darkened(0.10)
			box.border_width_bottom = 2
			box.content_margin_top = 9
			box.content_margin_bottom = 8
		"disabled":
			var grey := base.lerp(INK, 0.72)
			box.bg_color = grey
			box.border_color = grey.darkened(0.45)
			box.border_width_bottom = 3
	if rim.a > 0.0 and state != "pressed":
		box.border_color = rim
		box.border_width_top = 2
		box.border_width_left = 2
		box.border_width_right = 2
		box.border_width_bottom = 5
	return box


## A soft top-half sheen for chunky buttons: white fading to nothing. A child overlay
## rather than part of the stylebox, because StyleBoxFlat has no gradients.
static func gloss(strength: float = 0.10) -> TextureRect:
	var sheen := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, strength))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	sheen.texture = texture
	sheen.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sheen.anchor_bottom = 0.55
	sheen.grow_vertical = Control.GROW_DIRECTION_END
	sheen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sheen


## A flat empty box, for containers that should draw nothing.
static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
