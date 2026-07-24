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
		_pan = Vector2(size.x * 0.5, size.y * VERTICAL_ANCHOR) - node.position
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
		var from := node.position + _pan
		for other_id in node.neighbours:
			var other := tree.get_node_def(other_id)
			if other == null:
				continue
			var to := other.position + _pan
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
		return
	var centre := _hero_at + _pan
	var tex_size := hero_texture.get_size()
	var sprite_scale := minf(150.0 / tex_size.x, 150.0 / tex_size.y)
	var draw_size := tex_size * sprite_scale
	var top := centre.y - draw_size.y * 0.5
	var font := UIPalette.bold_font()
	draw_string_outline(font, Vector2(centre.x - 150.0, top - 26.0), hero_name,
		HORIZONTAL_ALIGNMENT_CENTER, 300.0, 15, 5, Color("070b11"))
	draw_string(font, Vector2(centre.x - 150.0, top - 26.0), hero_name,
		HORIZONTAL_ALIGNMENT_CENTER, 300.0, 15, Color("f2b92b"))
	var points_text := "%d pt" % hero_points
	draw_string_outline(font, Vector2(centre.x - 150.0, top - 9.0), points_text,
		HORIZONTAL_ALIGNMENT_CENTER, 300.0, 12, 4, Color("070b11"))
	draw_string(font, Vector2(centre.x - 150.0, top - 9.0), points_text,
		HORIZONTAL_ALIGNMENT_CENTER, 300.0, 12, Color("47d7ea"))
	draw_texture_rect(hero_texture,
		Rect2(centre - draw_size * 0.5, draw_size), false, Color(1, 1, 1, 0.94))


func _radius_of(node: SkillNodeDef) -> float:
	return RADII.get(node.node_type, 9.0)


func _draw_node(node: SkillNodeDef) -> void:
	var centre := node.position + _pan
	var radius := _radius_of(node)
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
		var d := point.distance_to(node.position + _pan)
		if d <= best_distance:
			best_distance = d
			best = node.id
	return best


## Touch and mouse share one press-drag-release path. A drag pans; a press that never
## travels past DRAG_THRESHOLD is a tap. Without that threshold every pan would also
## allocate whatever node it started on.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_started_at = event.position
			_drag_distance = 0.0
		else:
			_dragging = false
			if _drag_distance <= DRAG_THRESHOLD:
				var hit := node_at(event.position)
				if hit != &"":
					node_tapped.emit(hit)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_has_user_panned = true
		_pan += event.relative
		_drag_distance += event.relative.length()
		queue_redraw()
		accept_event()
