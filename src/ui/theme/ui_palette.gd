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
const DISPLAY_FONT := "res://assets/fonts/Rajdhani-SemiBold.woff"   ## headings, names, buttons
const DISPLAY_BOLD := "res://assets/fonts/Rajdhani-Bold.woff"
const MONO_FONT := "res://assets/fonts/IBMPlexMono-Regular.woff"    ## body, numbers
const MONO_BOLD := "res://assets/fonts/IBMPlexMono-SemiBold.woff"


static func display_font() -> FontFile:
	return load(DISPLAY_FONT)


static func mono_font() -> FontFile:
	return load(MONO_FONT)


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


## A flat empty box, for containers that should draw nothing.
static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()
