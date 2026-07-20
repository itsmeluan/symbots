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

const NODE_RADIUS := 7.0
const KEYSTONE_RADIUS := 11.0
const TAP_SLOP := 18.0     ## generous: a 7px circle is not a 44pt tap target
const DRAG_THRESHOLD := 6.0

## Colours carry the state, because on a phone there is no room for labels on 156 nodes.
const COLOUR_ALLOCATED := Color(0.35, 0.85, 0.45)
const COLOUR_FRONTIER := Color(0.95, 0.80, 0.30)
const COLOUR_LOCKED := Color(0.30, 0.32, 0.38)
const COLOUR_SOCKET := Color(0.50, 0.70, 0.95)
const COLOUR_KEYSTONE := Color(0.90, 0.45, 0.85)
const COLOUR_SELECTED := Color(1.0, 1.0, 1.0)
const COLOUR_EDGE := Color(0.25, 0.27, 0.32)
const COLOUR_EDGE_LIVE := Color(0.40, 0.60, 0.45)

var tree: SkillTree = null

## Node ids the Symbot holds, and the ones it could take next. Handed in by the screen so
## the view never derives a rule.
var allocated: Dictionary = {}
var frontier: Dictionary = {}
var selected: StringName = &""

var _pan := Vector2.ZERO
var _dragging := false
var _drag_started_at := Vector2.ZERO
var _drag_distance := 0.0


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


## Bind the tree and centre the view on [param focus] — normally the species' entry node,
## because opening on the origin of a 156-node graph would show the player empty space.
func bind(p_tree: SkillTree, focus: StringName) -> void:
	tree = p_tree
	center_on(focus)


func center_on(node_id: StringName) -> void:
	if tree == null:
		return
	var node := tree.get_node_def(node_id)
	if node != null:
		_pan = size * 0.5 - node.position
	queue_redraw()


## Refresh state and redraw. Cheap — it is a colour swap, not a rebuild.
func set_state(p_allocated: Dictionary, p_frontier: Dictionary,
		p_selected: StringName) -> void:
	allocated = p_allocated
	frontier = p_frontier
	selected = p_selected
	queue_redraw()


func _draw() -> void:
	if tree == null:
		return
	# Edges first so nodes sit on top of them. Each undirected edge is drawn twice (once
	# from each end); at 157 edges that is cheaper than building a deduplicated edge list
	# on every redraw.
	for node in tree.nodes:
		var from := node.position + _pan
		for other_id in node.neighbours:
			var other := tree.get_node_def(other_id)
			if other == null:
				continue
			var live: bool = allocated.has(node.id) and allocated.has(other_id)
			draw_line(from, other.position + _pan,
				COLOUR_EDGE_LIVE if live else COLOUR_EDGE, 2.0 if live else 1.0)

	for node in tree.nodes:
		_draw_node(node)


func _draw_node(node: SkillNodeDef) -> void:
	var centre := node.position + _pan
	var radius := KEYSTONE_RADIUS if node.node_type == SkillNodeDef.NodeType.KEYSTONE \
		else NODE_RADIUS
	draw_circle(centre, radius, _colour_for(node))
	if node.id == selected:
		draw_arc(centre, radius + 4.0, 0.0, TAU, 20, COLOUR_SELECTED, 2.0)


func _colour_for(node: SkillNodeDef) -> Color:
	if allocated.has(node.id):
		return COLOUR_ALLOCATED
	if node.node_type == SkillNodeDef.NodeType.SOCKET:
		return COLOUR_SOCKET
	if node.node_type == SkillNodeDef.NodeType.KEYSTONE:
		return COLOUR_KEYSTONE
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
		_pan += event.relative
		_drag_distance += event.relative.length()
		queue_redraw()
		accept_event()
