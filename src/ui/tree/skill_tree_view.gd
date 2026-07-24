## SkillTreeView — the pannable node graph (Core Design §4).
##
## Draws the tree at its AUTHORED positions rather than a computed layout, because the
## positions are what make clusters read as deliberate regions instead of a force-directed
## blob — and a player navigating by shape is why "the DPS side" means anything.
##
## Custom-drawn rather than 156 Control nodes: at that count, per-node Controls cost real
## layout time on a phone every time the pan offset changes, and the 200-draw-call budget
## does not survive it. One _draw() pass is one batch.
class_name SkillTreeView
extends Control

## Emitted when the player taps a node. The screen decides what that means; the view does
## not know the allocation rules.
signal node_tapped(node_id: StringName)

## Emitted when the player taps the central hero sprite — opens the Symbot's dossier.
signal hero_tapped

const TAP_SLOP := 22.0     ## generous: a dot is the rendering, not the target

## Where the focused node sits vertically on open: below the middle, because the
## inspector overlays the top band and the hero (above the entry) needs headroom.
const VERTICAL_ANCHOR := 0.80
const DRAG_THRESHOLD := 6.0

## Colours carry the state, because on a phone there is no room for labels on 156 nodes.
const COLOUR_ALLOCATED := Color(0.38, 0.88, 0.48)
const COLOUR_FRONTIER := Color(0.96, 0.78, 0.28)
const COLOUR_LOCKED := Color(0.34, 0.38, 0.46)
const COLOUR_SOCKET := Color(0.42, 0.78, 0.98)
const COLOUR_KEYSTONE := Color(0.92, 0.47, 0.86)
const COLOUR_SELECTED := Color(1.0, 1.0, 1.0)
const COLOUR_EDGE := Color(0.30, 0.34, 0.42, 0.65)
const COLOUR_EDGE_LIVE := Color(0.40, 0.75, 0.50)
const NODE_FACE := Color(0.075, 0.10, 0.14)

## Radii per node type — bigger, and SHAPED: stats are small links, actives/passives the
## working circles, sockets hexagons, keystones diamonds, entries the doorways.
const RADII := {
	SkillNodeDef.NodeType.STAT: 8.0,
	SkillNodeDef.NodeType.PASSIVE: 11.0,
	SkillNodeDef.NodeType.ACTIVE: 11.0,
	SkillNodeDef.NodeType.KEYSTONE: 15.0,
	SkillNodeDef.NodeType.SOCKET: 12.0,
	SkillNodeDef.NodeType.ENTRY: 12.0,
}

var tree: SkillTree = null

## Node ids the Symbot holds, and the ones it could take next. Handed in by the screen so
## the view never derives a rule.
var allocated: Dictionary = {}
var frontier: Dictionary = {}
var selected: StringName = &""

## Socket node ids that hold an install item — drawn lit instead of hollow.
var fitted: Dictionary = {}

## The selected Symbot, standing at the heart of the graph. Purely presentational.
var hero_texture: Texture2D = null
var _hero_at := Vector2.ZERO

## The Respec control the screen hands us to FLOAT under the hero. Kept as a child so it pans
## with the sprite, and repositioned every time the hero is drawn so the two never drift.
var _respec_control: Control = null

## The symmetric gap that sets the name just above the sprite and the Respec just below it, so
## the label and the button sit an equal breath from the creature.
const HERO_LABEL_GAP := 8.0
const HERO_SPRITE_MAX := 150.0

## Zoom. Every authored point maps to the screen through _screen(): p * _zoom + _pan. The
## mouse wheel and a two-finger pinch drive it, always toward the focal point so the thing
## under the cursor/fingers stays put.
var _zoom := 1.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.9
const ZOOM_WHEEL_STEP := 1.12
## Live pinch tracking: active touch index -> position, and the last two-finger span.
var _touches: Dictionary = {}
var _pinch_span := -1.0


## Map an authored graph point to its on-screen position under the current pan and zoom. The
## single place the transform lives, so draw, hit-testing and centring can never disagree.
func _screen(authored: Vector2) -> Vector2:
	return authored * _zoom + _pan


## Zoom to [param target] keeping [param focal] (a screen point) pinned to the same graph
## point, so the tree grows/shrinks around the cursor or the pinch centre rather than jumping.
func _apply_zoom(target: float, focal: Vector2) -> void:
	var next := clampf(target, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(next, _zoom):
		return
	_pan = focal - (focal - _pan) * (next / _zoom)
	_zoom = next
	queue_redraw()

var _pan := Vector2.ZERO

## The node the view wants centred, re-applied whenever the control is resized.
##
## center_on() runs during setup(), when the control still measures 0x0 — centring on a
## zero-size rect puts the focus node in the top-left corner instead of the middle. Layout
## happens a frame later, so the pan has to be recomputed then.
var _focus_id: StringName = &""

## Once the player has dragged, the view is theirs: a resize must not yank it back.
var _has_user_panned := false

var _dragging := false
var _drag_started_at := Vector2.ZERO
var _drag_distance := 0.0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)


func _on_resized() -> void:
	if not _has_user_panned:
		center_on(_focus_id)


## Bind the tree and centre the view on [param focus] — normally the species' entry node,
## because opening on the origin of a 156-node graph would show the player empty space.
func bind(p_tree: SkillTree, focus: StringName) -> void:
	tree = p_tree
	_has_user_panned = false
	# The hero stands at the graph's centre of mass — the heart the paths radiate from.
	if p_tree != null and not p_tree.nodes.is_empty():
		var sum := Vector2.ZERO
		for node in p_tree.nodes:
			sum += node.position
		_hero_at = sum / float(p_tree.nodes.size())
	center_on(focus)


var hero_name: String = ""
var hero_points: int = 0


func set_hero(texture: Texture2D, name: String = "", points: int = 0) -> void:
	hero_texture = texture
	hero_name = name
	hero_points = points
	queue_redraw()


func center_on(node_id: StringName) -> void:
	_focus_id = node_id
	if tree == null:
		return
	var node := tree.get_node_def(node_id)
	if node != null:
		# Anchored at 62% height, not the middle: the inspector overlays the top band,
		# so "centred" visually means below it — this keeps the hero and its nameplate
		# out from underneath the card.
		_pan = Vector2(size.x * 0.5, size.y * VERTICAL_ANCHOR) - _display_pos(node) * _zoom
	queue_redraw()


## Refresh state and redraw. Cheap — it is a colour swap, not a rebuild.
func set_state(p_allocated: Dictionary, p_frontier: Dictionary,
		p_selected: StringName, p_fitted: Dictionary = {}) -> void:
	allocated = p_allocated
	frontier = p_frontier
	selected = p_selected
	fitted = p_fitted
	queue_redraw()


func _draw() -> void:
	if tree == null:
		return
	_draw_hero()
	# Edges first so nodes sit on top of them. Live edges get a soft under-glow pass.
	for node in tree.nodes:
		var from := _screen(_display_pos(node))
		for other_id in node.neighbours:
			var other := tree.get_node_def(other_id)
			if other == null:
				continue
			var to := _screen(_display_pos(other))
			if allocated.has(node.id) and allocated.has(other_id):
				draw_line(from, to, Color(COLOUR_EDGE_LIVE, 0.22), 5.0)
				draw_line(from, to, COLOUR_EDGE_LIVE, 2.0)
			else:
				draw_line(from, to, COLOUR_EDGE, 1.0)

	for node in tree.nodes:
		_draw_node(node)


## The selected Symbot at the heart of the tree — name over points over the creature,
## free-standing and big enough to own the space.
func _draw_hero() -> void:
	if hero_texture == null:
		if _respec_control != null:
			_respec_control.visible = false
		return
	var centre := _screen(_hero_at)
	var tex_size := hero_texture.get_size()
	var sprite_scale := minf(HERO_SPRITE_MAX / tex_size.x, HERO_SPRITE_MAX / tex_size.y) * _zoom
	var draw_size := tex_size * sprite_scale
	var top := centre.y - draw_size.y * 0.5
	var bottom := centre.y + draw_size.y * 0.5
	var font := UIPalette.bold_font()
	# Name over points, both sitting just above the sprite (a single HERO_LABEL_GAP breath) so
	# the label rides with the creature instead of drifting up into the first ring of nodes.
	var points_baseline := top - HERO_LABEL_GAP
	var name_baseline := points_baseline - 15.0
	draw_string_outline(font, Vector2(centre.x - 150.0, name_baseline), hero_name,
		HORIZONTAL_ALIGNMENT_CENTER, 300.0, 15, 5, Color("070b11"))
	draw_string(font, Vector2(centre.x - 150.0, name_baseline), hero_name,
		HORIZONTAL_ALIGNMENT_CENTER, 300.0, 15, Color("f2b92b"))
	var points_text := "%d pt" % hero_points
	draw_string_outline(font, Vector2(centre.x - 150.0, points_baseline), points_text,
		HORIZONTAL_ALIGNMENT_CENTER, 300.0, 12, 4, Color("070b11"))
	draw_string(font, Vector2(centre.x - 150.0, points_baseline), points_text,
		HORIZONTAL_ALIGNMENT_CENTER, 300.0, 12, Color("47d7ea"))
	draw_texture_rect(hero_texture,
		Rect2(centre - draw_size * 0.5, draw_size), false, Color(1, 1, 1, 0.94))
	_position_respec(centre.x, bottom)


## Attach the screen's Respec button so it floats under the hero. The screen keeps ownership
## (label, cost, the pressed handler and whether it shows at all); the view only parks it.
func attach_respec(control: Control) -> void:
	_respec_control = control
	if control.get_parent() != self:
		add_child(control)
	queue_redraw()


## Park the Respec centred under the sprite, the same HERO_LABEL_GAP below it as the name sits
## above — so the two read as a matched pair bracketing the creature. The screen's own logic
## decides whether it is visible; we only move it while it is.
func _position_respec(centre_x: float, sprite_bottom: float) -> void:
	if _respec_control == null or not _respec_control.visible:
		return
	var w := maxf(_respec_control.size.x, _respec_control.get_combined_minimum_size().x)
	var h := maxf(_respec_control.size.y, _respec_control.get_combined_minimum_size().y)
	# Tracks the sprite, but clamped fully on-screen: when the hero drifts to an edge (it lives
	# at the graph's centre of mass, which the doorway-centred view can push aside) the button
	# slides back into view rather than off the edge or under the roster strip.
	var x := clampf(centre_x - w * 0.5, 6.0, maxf(6.0, size.x - w - 6.0))
	var y := clampf(sprite_bottom + HERO_LABEL_GAP, 6.0, maxf(6.0, size.y - h - 6.0))
	_respec_control.position = Vector2(x, y)


## The on-screen rectangle the hero sprite occupies, matching _draw_hero's geometry so the
## tap target and the drawn sprite are always the same box. Empty when there is no hero.
func _hero_rect() -> Rect2:
	if hero_texture == null:
		return Rect2()
	var centre := _screen(_hero_at)
	var tex_size := hero_texture.get_size()
	var sprite_scale := minf(HERO_SPRITE_MAX / tex_size.x, HERO_SPRITE_MAX / tex_size.y) * _zoom
	var draw_size := tex_size * sprite_scale
	return Rect2(centre - draw_size * 0.5, draw_size)


## How far an ENTRY node is pulled toward the graph's centre when DRAWN, so it separates from
## the first node on its spoke. The authored gap is only ~15px — less than the two radii
## combined — so entry and its first socket sat on top of each other. A pure PRESENTATION
## offset: the authored data is untouched, and every place that reads a screen position goes
## through _display_pos(), so the drawn node, its edges and its tap target all move together.
const ENTRY_INSET := 22.0


## The on-graph position a node is drawn and hit-tested at. Identical to the authored position
## for everything except ENTRY nodes, which are nudged inward (see ENTRY_INSET).
func _display_pos(node: SkillNodeDef) -> Vector2:
	if node.node_type == SkillNodeDef.NodeType.ENTRY and node.position != Vector2.ZERO:
		return node.position - node.position.normalized() * ENTRY_INSET
	return node.position


func _radius_of(node: SkillNodeDef) -> float:
	return RADII.get(node.node_type, 9.0)


func _draw_node(node: SkillNodeDef) -> void:
	var centre := _screen(_display_pos(node))
	var radius := _radius_of(node) * _zoom
	var colour := _colour_for(node)
	var is_allocated := allocated.has(node.id)
	var is_frontier := frontier.has(node.id)

	match node.node_type:
		SkillNodeDef.NodeType.SOCKET:
			_draw_socket(centre, radius, colour, fitted.has(node.id))
		SkillNodeDef.NodeType.KEYSTONE:
			_draw_keystone(centre, radius, colour, is_allocated)
		SkillNodeDef.NodeType.ENTRY:
			_draw_entry(centre, radius, colour, is_allocated)
		_:
			_draw_round(centre, radius, colour, is_allocated, is_frontier)

	if node.id == selected:
		draw_arc(centre, radius + 4.0, 0.0, TAU, 24, COLOUR_SELECTED, 2.0)
		draw_arc(centre, radius + 7.5, 0.0, TAU, 24, Color(1, 1, 1, 0.25), 1.5)


## The standard node: a dark face inside a state ring; allocated fills solid with a
## bright core; the frontier breathes behind a soft outer glow.
func _draw_round(centre: Vector2, radius: float, colour: Color,
		is_allocated: bool, is_frontier: bool) -> void:
	if is_frontier:
		draw_circle(centre, radius + 4.0, Color(colour, 0.14))
	draw_circle(centre, radius, colour if is_allocated else NODE_FACE)
	draw_arc(centre, radius, 0.0, TAU, 24, colour, 2.0)
	if is_allocated:
		draw_circle(centre, radius * 0.35, Color(1, 1, 1, 0.85))
	elif is_frontier:
		draw_circle(centre, radius * 0.28, colour)


## A socket is a HEXAGON with a visible hole: hollow until an item is fitted, then lit
## with a core and a halo — "something goes here" vs "something is here" at a glance.
func _draw_socket(centre: Vector2, radius: float, colour: Color, is_fitted: bool) -> void:
	var points: PackedVector2Array = []
	for i in 6:
		var a := -PI * 0.5 + TAU * i / 6.0
		points.append(centre + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, NODE_FACE)
	draw_polyline(points + PackedVector2Array([points[0]]), colour, 2.0)
	if is_fitted:
		draw_circle(centre, radius * 0.42, colour)
		draw_arc(centre, radius + 3.5, 0.0, TAU, 18, Color(colour, 0.35), 2.0)
	else:
		draw_arc(centre, radius * 0.42, 0.0, TAU, 16, Color(colour, 0.7), 1.5)
		draw_circle(centre, radius * 0.16, Color(0, 0, 0, 0.6))


## A keystone is a DIAMOND in a halo ring — the build-definers earn ceremony.
func _draw_keystone(centre: Vector2, radius: float, colour: Color,
		is_allocated: bool) -> void:
	var points := PackedVector2Array([
		centre + Vector2(0, -radius), centre + Vector2(radius, 0),
		centre + Vector2(0, radius), centre + Vector2(-radius, 0)])
	draw_colored_polygon(points, colour if is_allocated else NODE_FACE)
	draw_polyline(points + PackedVector2Array([points[0]]), colour, 2.0)
	draw_arc(centre, radius + 4.0, 0.0, TAU, 28, Color(colour, 0.55), 1.5)
	if is_allocated:
		draw_circle(centre, radius * 0.3, Color(1, 1, 1, 0.9))


## An entry is a doorway: a double ring with a gate dot once walked through.
func _draw_entry(centre: Vector2, radius: float, colour: Color, is_allocated: bool) -> void:
	draw_circle(centre, radius, NODE_FACE)
	draw_arc(centre, radius, 0.0, TAU, 24, colour, 2.5)
	draw_arc(centre, radius - 4.0, 0.0, TAU, 20, Color(colour, 0.5), 1.5)
	if is_allocated:
		draw_circle(centre, radius * 0.3, colour)


func _colour_for(node: SkillNodeDef) -> Color:
	if node.node_type == SkillNodeDef.NodeType.SOCKET:
		return COLOUR_SOCKET if (fitted.has(node.id) or frontier.has(node.id)
			or allocated.has(node.id)) else Color(COLOUR_SOCKET, 0.5)
	if allocated.has(node.id):
		return COLOUR_ALLOCATED
	if node.node_type == SkillNodeDef.NodeType.KEYSTONE:
		return COLOUR_KEYSTONE if frontier.has(node.id) else Color(COLOUR_KEYSTONE, 0.55)
	if frontier.has(node.id):
		return COLOUR_FRONTIER
	return COLOUR_LOCKED


## The node nearest [param point], or empty when nothing is within TAP_SLOP.
##
## Slop is generous because a 7px circle is nowhere near the 44pt touch minimum — the dot
## is the *rendering*, not the target. Nearest-wins rather than first-hit so overlapping
## dots in a dense cluster resolve to the one the player aimed at.
func node_at(point: Vector2) -> StringName:
	if tree == null:
		return &""
	var best := &""
	var best_distance := TAP_SLOP
	for node in tree.nodes:
		var d := point.distance_to(_screen(_display_pos(node)))
		if d <= best_distance:
			best_distance = d
			best = node.id
	return best


## Touch and mouse share one press-drag-release path. A drag pans; a press that never
## travels past DRAG_THRESHOLD is a tap. Without that threshold every pan would also
## allocate whatever node it started on.
func _gui_input(event: InputEvent) -> void:
	# Mouse wheel zooms toward the cursor (desktop).
	if event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var factor := ZOOM_WHEEL_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP \
			else 1.0 / ZOOM_WHEEL_STEP
		_apply_zoom(_zoom * factor, event.position)
		accept_event()
		return

	# Two-finger pinch zooms toward the pinch centre (touch). Tracked from the raw screen
	# events so it works alongside the emulated-mouse pan the first finger also produces.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() < 2:
			_pinch_span = -1.0
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var span: float = pts[0].distance_to(pts[1])
			if _pinch_span > 0.0 and span > 0.0:
				_apply_zoom(_zoom * (span / _pinch_span), (pts[0] + pts[1]) * 0.5)
			_pinch_span = span
			accept_event()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_started_at = event.position
			_drag_distance = 0.0
		else:
			_dragging = false
			if _drag_distance <= DRAG_THRESHOLD:
				# The hero sits on top of the graph's centre, so test it BEFORE the nodes —
				# a tap on the sprite opens the dossier rather than the node beneath it.
				if _hero_rect().has_point(event.position):
					hero_tapped.emit()
				else:
					var hit := node_at(event.position)
					if hit != &"":
						node_tapped.emit(hit)
		accept_event()
	elif event is InputEventMouseMotion and _dragging and _touches.size() < 2:
		# Suppressed while pinching: two fingers zoom, they don't also pan.
		_has_user_panned = true
		_pan += event.relative
		_drag_distance += event.relative.length()
		queue_redraw()
		accept_event()
