## UnitPanel — one combatant standing on the battlefield (ADR-0008, Core Design §3.1).
##
## Built in code rather than as a .tscn because eight of these are laid out
## programmatically and a scene file would need the same wiring anyway — this way the
## layout and the contract live in one reviewable place.
##
## This used to be a CARD: sprite stacked on a framed nameplate carrying name, role tag, HP
## text and status text. Eight of those in two four-row columns needed ~600px of column
## height on a 640px screen, so the action bar and the log were pushed off the bottom edge —
## the player could not see their own attacks. It is now just the figure itself: sprite, a
## ground shadow that seats it in the scene, and hairline bars. Everything the card used to
## spell out is either in the banner (whose turn) or readable from the figure (who is hurt,
## who is dead).
##
## Renders as a PURE FUNCTION of the last [BattleUnit] state it was handed (ADR-0008
## forbids `view_state_polling`). Nothing here reads the model on a timer; the screen calls
## [method refresh] when the engine says something changed.
class_name UnitPanel
extends PanelContainer

## Emitted when the player taps this unit. The screen decides whether that means anything
## — the panel does not know the targeting rules.
signal tapped(unit: BattleUnit)

## Touch minimum from technical-preferences.md. Applied to the whole figure, so the tap
## target is the whole standing unit and never a sub-widget.
const MIN_TAP_HEIGHT := 44

## Default sprite height. The screen overrides it per formation row via
## [method set_display_height] — the back rank is drawn smaller to read as further away.
const SPRITE_HEIGHT := 64

const BAR_HEIGHT := 3

## Bars are drawn narrower than the figure and centred under it. At full slot width they
## touched the neighbouring unit's bar and read as one continuous UI strip laid over the
## battlefield rather than as a readout belonging to a figure.
const BAR_WIDTH := 52

## Where the art lives and how art_id() names it (SpeciesDef.art_id → "<id>_mk<n>").
const ART_DIR := "res://assets/art/symbots/"

var unit: BattleUnit = null

const SpeciesDefScript := preload("res://src/core/species/species_def.gd")

## Role → short tag. No longer painted on the field, but kept as the one place the mapping
## lives — the battle log and any future inspector read it from here.
const ROLE_TAGS := {
	SpeciesDefScript.Role.DPS: "DPS",
	SpeciesDefScript.Role.TANK: "TANK",
	SpeciesDefScript.Role.HEALER: "HEAL",
	SpeciesDefScript.Role.SUPPORT: "SUPP",
}

var _sprite: TextureRect
var _ground: Control
var _structure_bar: ProgressBar
var _shield_bar: ProgressBar
var _charge_bar: ProgressBar
var _root: VBoxContainer

## Visual state the screen drives. Kept as fields rather than as style overrides applied
## immediately so [method refresh] stays the single place that touches appearance.
var is_active_turn: bool = false
var is_targetable: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(0, MIN_TAP_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# No card. The figure stands directly on the battlefield art behind it.
	add_theme_stylebox_override("panel", UIPalette.empty())

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 1)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# The figure: a ground shadow drawn first (so it sits behind), the sprite over it.
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, SPRITE_HEIGHT)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(stage)

	_ground = Control.new()
	_ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.draw.connect(_draw_ground)
	stage.add_child(_ground)

	# A fixed display HEIGHT is what normalises the wildly varying source sizes (102-323px):
	# every Symbot reads at the scale its formation row calls for, regardless of how big its
	# PNG happened to be exported.
	_sprite = TextureRect.new()
	_sprite.custom_minimum_size = Vector2(0, SPRITE_HEIGHT)
	_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps go to the panel, not the image
	stage.add_child(_sprite)

	# Hairline bars under the feet. Structure always; the other two only when they mean
	# something. Anything thicker starts reading as UI pasted over the scene.
	_structure_bar = _make_bar(UIPalette.GREEN, BAR_HEIGHT)
	_root.add_child(_structure_bar)

	_shield_bar = _make_bar(Color(0.45, 0.70, 0.95), 2)
	_root.add_child(_shield_bar)

	_charge_bar = _make_bar(UIPalette.AMBER, 2)
	_root.add_child(_charge_bar)


func _make_bar(colour: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(BAR_WIDTH, height)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 100
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	bar.add_theme_stylebox_override("background", back)
	return bar


## Draw this unit at [param height] pixels tall. The screen calls it per formation row so
## the back rank reads as further away rather than as a smaller species.
func set_display_height(height: float) -> void:
	_sprite.custom_minimum_size = Vector2(0, height)
	if _sprite.get_parent() is Control:
		(_sprite.get_parent() as Control).custom_minimum_size = Vector2(0, height)


## Bind a unit and draw it. Call once per battle, then [method refresh] on every change.
func bind(u: BattleUnit) -> void:
	unit = u
	_load_sprite()
	refresh()


## Load the unit's art once at bind time — the sprite never changes mid-battle, so pulling
## it here keeps it out of refresh(), which runs on every state change.
##
## Enemies face LEFT, so an enemy sprite is flipped horizontally rather than kept as a
## second mirrored file on disk — one source of truth per Symbot, and every future species
## works with no manual mirror step. A missing texture leaves the slot blank rather than
## erroring: a species whose art is not authored yet still fights, just without a portrait.
func _load_sprite() -> void:
	if unit == null or unit.species_id == &"":
		_sprite.texture = null
		return
	var path := "%s%s_mk%d.png" % [ART_DIR, unit.species_id, clampi(unit.art_mark, 1, 3)]
	_sprite.texture = load(path) if ResourceLoader.exists(path) else null
	_sprite.flip_h = unit.side == BattleUnit.Side.ENEMY


## Redraw from the unit's current state. Safe to call every frame or once an hour — it
## reads, never writes.
func refresh() -> void:
	if unit == null:
		return

	# Ally structure reads green, enemy coral — the side colour, so at a glance the player
	# knows whose bar is dropping.
	var tone := UIPalette.GREEN if unit.side == BattleUnit.Side.PLAYER else UIPalette.CORAL
	var fill := StyleBoxFlat.new()
	fill.bg_color = tone
	_structure_bar.add_theme_stylebox_override("fill", fill)

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

	modulate = Color(0.45, 0.45, 0.45) if not unit.is_alive() else Color.WHITE
	_ground.queue_redraw()


## Charge cost of this unit's ult, injected by the screen (which owns the skill table).
## Defaults to 100 so a panel is drawable before the table is bound.
var _ult_cost: int = 100

func set_ult_cost(cost: int) -> void:
	_ult_cost = maxi(1, cost)


## The shadow that seats the figure on the ground, plus the turn/target ring.
##
## The ring is drawn at the FEET rather than as a box around the unit: a rectangle reads as
## a card, which is the thing this screen just stopped being.
func _draw_ground() -> void:
	var w := _ground.size.x
	var h := _ground.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var centre := Vector2(w * 0.5, h - 3.0)
	var radius := w * 0.34

	# Squash the circle into an ellipse so it lies on the ground rather than standing up.
	_ground.draw_set_transform(centre, 0.0, Vector2(1.0, 0.32))
	_ground.draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, 0.38))
	if is_active_turn:
		_ground.draw_arc(Vector2.ZERO, radius * 1.12, 0.0, TAU, 28,
			Color(1.0, 0.85, 0.3), 4.0)
	elif is_targetable:
		_ground.draw_arc(Vector2.ZERO, radius * 1.12, 0.0, TAU, 28,
			Color(0.95, 0.35, 0.35), 4.0)
	_ground.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func set_active_turn(active: bool) -> void:
	is_active_turn = active
	_ground.queue_redraw()


func set_targetable(targetable: bool) -> void:
	is_targetable = targetable
	_ground.queue_redraw()


## Touch and mouse share one press-release path (ADR-0008 touch-first): both arrive as
## InputEventMouseButton on Godot's default emulation, so there is no hover-only affordance
## and no second code path to keep in sync.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if unit != null:
			tapped.emit(unit)
			accept_event()
