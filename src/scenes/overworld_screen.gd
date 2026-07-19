## OverworldScreen — the walkable world where the player finds and engages enemies.
##
## WORLD, NOT SCREEN (rewritten 2026-07-19): the map used to be a single fixed
## 1024x600 Control field with the player clamped inside it. It is now a real
## scrolling world — a TileMapLayer of WORLD_TILES cells with a Camera2D that
## follows the player, so the map moves under the character and the viewport is a
## window onto something larger than itself. This is what makes exploration and
## multi-area maps possible.
##
## STRUCTURE vs STYLE (ADR-0008): the static shell (WorldView / Terrain / Player /
## Camera / UI) and its styling live in overworld_screen.tscn + the central Theme.
## This script owns behaviour, terrain fill, and the enemy markers, which are
## generated from live EnemyDB data (not editor-authorable).
##
## CAMERA ISOLATION: the world lives inside a SubViewport. A Camera2D transforms the
## whole canvas it belongs to, so a camera in the main viewport would also offset the
## Battle and Workshop screens (Control nodes are subject to the canvas transform).
## The SubViewport confines it. Its size tracks the container, so there is no extra
## rescale stage and pixel art stays crisp.
##
## The player moves by keyboard (arrows / WASD) or tap-to-move (touch-first). Taps are
## converted from screen space to world space through the SubViewport canvas transform.
## Walking onto an enemy marker triggers a battle via ScreenManager.enter_battle().
## On VICTORY the marker is cleared.
##
## KEEP-ALIVE (ADR-0004 §3): ScreenManager hides + PROCESS_MODE_DISABLED's this screen on
## battle entry and restores it on encounter_resolved. Movement lives in _physics_process
## and taps in _unhandled_input — both are suppressed by PROCESS_MODE_DISABLED, so the map
## is inert during battle. We deliberately do NOT use _input (it is NOT suppressed).
extends Screen

const MOVE_SPEED := 170.0                    # world px/sec
const TILE := 64                             # world px per tile (matches terrain_tileset.tres)
const WORLD_TILES := Vector2i(40, 26)        # 40x26 tiles = 2560x1664 world px (~2.7 x 3 screens)
const PLAYER_HEIGHT := 96.0                  # on-screen height; width follows the sheet aspect
const TRIGGER_RADIUS := 46.0
const MAX_MARKERS := 6
const MARKER_HEIGHT := 84.0                  # on-screen height; width follows the sprite aspect
const ARRIVE_EPSILON := 4.0
const DECAL_TILES := 3                       # atlas tiles 1..3 are transparent overlay decals

# ---------------------------------------------------------------------------
# SWAPPING THE PLAYER SPRITE
# ---------------------------------------------------------------------------
# Drop a new PNG at assets/art/characters/<PLAYER_SPRITE>.png and it is picked up on
# the next Godot import — no code change needed. Two requirements:
#
#   1. The sheet is a grid of SHEET_COLS x SHEET_ROWS frames. Any pixel resolution
#      works (128x192, 256x384, 512x768 ...) as long as it divides evenly by the grid;
#      the frame size is measured from the texture, not hardcoded. An uneven sheet is
#      logged as overworld_bad_walk_sheet and the old sprite is kept rather than
#      silently slicing frames at the wrong offsets.
#   2. Row order is the direction convention below. Only rows 0/2/3 are drawn.
#
# To use one of the other shipped variants, point PLAYER_SPRITE at it — e.g.
# &"char_mechanic_fem_overworld_walk" or &"char_mechanic_masc_overworld_walk".
#
# On-screen size is driven by PLAYER_HEIGHT with width following the sheet's own
# aspect, so a taller or wider character still reads at a consistent height.
const PLAYER_SPRITE := &"char_mechanic_walk"
const SHEET_COLS := 4
const SHEET_ROWS := 4
const ROW_DOWN := 0                          # row 0 — facing the camera
const ROW_SIDE := 2                          # row 2 — profile facing right (flipped for left)
const ROW_UP := 3                            # row 3 — facing away
const WALK_FPS := 8.0

# encounter_resolved result codes (EventBus): WIN=1, LOSS=2, FLEE=3.
const RESULT_WIN := 1
# encounter_type codes: WILD=1, BOSS=2.
const ENCOUNTER_WILD := 1

const COL_ENEMY := Color(0.85, 0.30, 0.28)   # fallback tint when an enemy has no sprite

var _ctx: ServiceContext
var _log: LogSink

# Static shell authored in overworld_screen.tscn; resolved via % unique names.
@onready var _view: SubViewportContainer = %WorldView
@onready var _vp: SubViewport = %WorldViewport
@onready var _terrain: TileMapLayer = %Terrain
@onready var _decals: TileMapLayer = %Decals
@onready var _markers_root: Node2D = %Markers
@onready var _player: AnimatedSprite2D = %Player
@onready var _camera: Camera2D = %Camera

var _target_pos: Vector2 = Vector2.INF        # INF = no active tap-move target
var _markers: Array = []                      # [{node: Node2D, enemy: EnemyDef}]
var _in_encounter: bool = false
var _pending_marker = null
var _facing: StringName = &"down"


func _ready() -> void:
	%WorkshopBtn.pressed.connect(_on_workshop_pressed)
	_build_terrain()
	_build_player_frames()
	_configure_camera()
	# Spawn the player at the centre of the world (position is behaviour, not layout).
	# The camera must be placed here too — it only tracks the player while moving, so
	# without this the first frame looks at the world origin instead of the character.
	_player.position = _world_size() * 0.5
	_camera.position = _player.position
	_camera.reset_smoothing()


## Screen contract: cache deps, spawn markers from real enemy data, subscribe to the
## battle-resolved signal so we can clear a defeated enemy.
func setup(ctx: ServiceContext) -> void:
	_ctx = ctx
	_log = ctx.log
	_spawn_enemy_markers()
	_connect_owned(EventBus.encounter_resolved, Callable(self, "_on_encounter_resolved"))
	_log.info(&"overworld_entered", {"markers": _markers.size()})


func _on_exit_tree() -> void:
	super._on_exit_tree()
	_ctx = null


func _world_size() -> Vector2:
	return Vector2(WORLD_TILES) * float(TILE)


# ---------------------------------------------------------------------------
# World construction
# ---------------------------------------------------------------------------

## Fill the two terrain layers with a deterministic pattern. Deterministic (a fixed
## integer hash, no RNG) so the map is stable across sessions and headless-verifiable —
## the same discipline the old fixed scatter used.
##
## TWO LAYERS, ON PURPOSE: atlas tile 0 is the only real ground tile; tiles 1..3 are
## transparent overlay decals (scrap, plants), not ground. Painting a decal into the
## ground layer punches a hole in the floor — so ground fills every cell on _terrain and
## decals are sprinkled sparsely on _decals above it.
##
## This is a starting fill, not a hand-authored map: both TileMapLayers are normal editor
## nodes, so the map can be repainted in the Godot editor and this fill only applies to
## cells left empty.
func _build_terrain() -> void:
	for y in WORLD_TILES.y:
		for x in WORLD_TILES.x:
			var cell := Vector2i(x, y)
			if _terrain.get_cell_source_id(cell) == -1:
				_terrain.set_cell(cell, 0, Vector2i(0, 0))
			if _decals.get_cell_source_id(cell) == -1:
				var decal := _decal_for(x, y)
				if decal > 0:
					_decals.set_cell(cell, 0, Vector2i(decal, 0))


## Sparse deterministic decal placement — ~1 in 9 cells gets an overlay. Returns 0 for
## "no decal", else the atlas column (1..DECAL_TILES).
func _decal_for(x: int, y: int) -> int:
	var h := absi((x * 73856093) ^ (y * 19349663))
	if h % 9 != 0:
		return 0
	return 1 + (h / 9) % DECAL_TILES


## Build the 3 directional walk animations from the walk sheet using AtlasTextures
## (one shared source texture — no per-frame image copies).
##
## The frame size is MEASURED from the texture rather than hardcoded, so any sheet
## resolution works as long as it is a SHEET_COLS x SHEET_ROWS grid — see the
## "SWAPPING THE PLAYER SPRITE" notes at the top of this file.
func _build_player_frames() -> void:
	var sheet := Art.texture("characters", PLAYER_SPRITE)
	if sheet == null:
		_warn(&"overworld_no_player_sprite", {"sprite": String(PLAYER_SPRITE)})
		return
	var tex_size := sheet.get_size()
	if int(tex_size.x) % SHEET_COLS != 0 or int(tex_size.y) % SHEET_ROWS != 0:
		# Slicing an uneven sheet would silently shear every frame. Refuse instead —
		# a missing sprite is obvious; subtly misaligned frames are not.
		_warn(&"overworld_bad_walk_sheet", {
			"sprite": String(PLAYER_SPRITE),
			"size": "%dx%d" % [int(tex_size.x), int(tex_size.y)],
			"expected_grid": "%dx%d" % [SHEET_COLS, SHEET_ROWS],
		})
		return
	var frame := Vector2(tex_size.x / SHEET_COLS, tex_size.y / SHEET_ROWS)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for entry in [[&"down", ROW_DOWN], [&"side", ROW_SIDE], [&"up", ROW_UP]]:
		var anim: StringName = entry[0]
		var row: int = entry[1]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, WALK_FPS)
		frames.set_animation_loop(anim, true)
		for col in SHEET_COLS:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(Vector2(col * frame.x, row * frame.y), frame)
			frames.add_frame(anim, at)
	_player.sprite_frames = frames
	_player.animation = &"down"
	# Scale to PLAYER_HEIGHT with width following the sheet's own aspect, so swapping in
	# a taller or wider character keeps a consistent on-screen size instead of changing
	# how big the player reads. At the shipped 64x96 frame this is 1:1 — no resampling.
	var k := PLAYER_HEIGHT / frame.y
	_player.scale = Vector2(k, k)
	_player.centered = true


## Half the player's on-screen size, measured from the live sprite frame. Falls back to
## a PLAYER_HEIGHT-square when no sheet loaded, so movement still clamps sanely.
func _player_half_extents() -> Vector2:
	var frames := _player.sprite_frames
	if frames == null or not frames.has_animation(_player.animation):
		return Vector2(PLAYER_HEIGHT, PLAYER_HEIGHT) * 0.5
	var tex := frames.get_frame_texture(_player.animation, 0)
	if tex == null:
		return Vector2(PLAYER_HEIGHT, PLAYER_HEIGHT) * 0.5
	return tex.get_size() * _player.scale * 0.5


## Warn through the injected LogSink when setup() has run, else through the Log autoload.
## _ready() builds the sprite before setup() injects the context, so the sink may be null.
func _warn(event: StringName, data: Dictionary) -> void:
	if _log != null:
		_log.warn(event, data)
	else:
		Log.sink.warn(event, data)


## Camera follows the player and is clamped to the world bounds, so the map scrolls
## under the character but never shows past its edges.
func _configure_camera() -> void:
	var ws := _world_size()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(ws.x)
	_camera.limit_bottom = int(ws.y)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.enabled = true


# ---------------------------------------------------------------------------
# Movement + encounter triggering
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _ctx == null or _in_encounter:
		return
	var dir := _keyboard_dir()
	var pos := _player.position
	if dir == Vector2.ZERO and _target_pos != Vector2.INF:
		var to_target := _target_pos - pos
		if to_target.length() > ARRIVE_EPSILON:
			dir = to_target.normalized()
		else:
			_target_pos = Vector2.INF  # arrived
	if dir == Vector2.ZERO:
		_player.pause()
		return
	pos += dir * MOVE_SPEED * delta
	var ws := _world_size()
	# Keep the whole sprite inside the world. Half-extents come from the live sprite so a
	# swapped-in sheet of different proportions clamps correctly without a code change.
	var half := _player_half_extents()
	pos.x = clampf(pos.x, half.x, ws.x - half.x)
	pos.y = clampf(pos.y, half.y, ws.y - half.y)
	_player.position = pos
	_camera.position = pos
	_apply_facing(dir)
	_check_encounters(pos)


## Pick the directional animation from the movement vector. Horizontal wins ties so
## diagonal movement reads as the side profile (the most legible walk pose).
func _apply_facing(dir: Vector2) -> void:
	var want: StringName
	if absf(dir.x) >= absf(dir.y):
		want = &"side"
		_player.flip_h = dir.x < 0.0
	elif dir.y < 0.0:
		want = &"up"
	else:
		want = &"down"
	if want != _facing:
		_facing = want
		if _player.sprite_frames != null and _player.sprite_frames.has_animation(want):
			_player.play(want)
	elif not _player.is_playing():
		_player.play(want)


func _unhandled_input(event: InputEvent) -> void:
	if _in_encounter:
		return
	var screen_pos := Vector2.INF
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		screen_pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		screen_pos = (event as InputEventScreenTouch).position
	if screen_pos == Vector2.INF:
		return
	_target_pos = _screen_to_world(screen_pos)


## Convert a viewport-space tap into world space. The world is inside a SubViewport with
## an active Camera2D, so the mapping goes through that subviewport's canvas transform —
## using the raw tap position would ignore the camera scroll entirely.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var local := screen_pos - _view.get_global_rect().position
	return _vp.get_canvas_transform().affine_inverse() * local


func _keyboard_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		d.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		d.y += 1.0
	if d != Vector2.ZERO:
		_target_pos = Vector2.INF  # keyboard overrides an in-flight tap target
		return d.normalized()
	return Vector2.ZERO


func _check_encounters(player_pos: Vector2) -> void:
	for m in _markers:
		var node: Node2D = m["node"]
		if not is_instance_valid(node):
			continue
		if player_pos.distance_to(node.position) < TRIGGER_RADIUS:
			_trigger_encounter(m)
			return


func _trigger_encounter(marker: Dictionary) -> void:
	_in_encounter = true
	_pending_marker = marker
	_target_pos = Vector2.INF
	_player.pause()
	var e: EnemyDef = marker["enemy"]
	# Pass only the id + type — the Battle screen re-resolves the full EnemyDef
	# (stats, break_regions, loot_pool) from EnemyDB so the encounter payload stays thin.
	_log.info(&"encounter_triggered", {"enemy": e.id})
	_ctx.screens.enter_battle({"enemy_id": e.id, "encounter_type": ENCOUNTER_WILD})


## Battle finished — ScreenManager has (or will) restore us. Clear the enemy on a win.
func _on_encounter_resolved(result: int, _encounter_type: int) -> void:
	_in_encounter = false
	if result == RESULT_WIN and _pending_marker != null:
		var node: Node2D = _pending_marker["node"]
		if is_instance_valid(node):
			node.queue_free()
		_markers.erase(_pending_marker)
	_pending_marker = null


# ---------------------------------------------------------------------------
# Enemy markers (data-generated from EnemyDB — not editor-authorable)
# ---------------------------------------------------------------------------

## Place up to MAX_MARKERS enemy markers from real EnemyDB data across the world.
func _spawn_enemy_markers() -> void:
	var enemies := EnemyDB.all_enemies()
	if enemies.is_empty():
		_log.warn(&"overworld_no_enemies", {})
		return
	var spots := _scatter_spots()
	var n: int = mini(MAX_MARKERS, mini(enemies.size(), spots.size()))
	for i in n:
		var e: EnemyDef = enemies[i]
		var node := _make_marker_node(e.id)
		node.position = spots[i]
		_markers_root.add_child(node)

		node.add_child(_make_marker_label(e.display_name))

		_markers.append({"node": node, "enemy": e})


## Placeholder-or-sprite marker: a Sprite2D with the enemy art when
## assets/art/enemies/<id>.png exists, else the encounter-frame proxy tinted red.
## Both are Node2D, so the caller treats them uniformly. Drop the sprite in → the
## marker upgrades with no code change.
##
## Scaling is driven by MARKER_HEIGHT with the width left to follow the source aspect,
## so enemies of different proportions (a squat crawler vs. a tall sentinel) all read at
## a consistent on-screen height instead of being squashed into one square.
func _make_marker_node(enemy_id) -> Node2D:
	var s := Sprite2D.new()
	s.centered = true
	var tex := Art.texture("enemies", enemy_id)
	if tex == null:
		tex = Art.texture("overworld", &"encounter_marker_frame")
		s.modulate = COL_ENEMY
	if tex == null:
		return s
	s.texture = tex
	var k := MARKER_HEIGHT / float(tex.get_height())
	s.scale = Vector2(k, k)
	return s


## Name plate under a marker. Centred by measuring the rendered string, so long and
## short enemy names both sit under their sprite instead of drifting left.
func _make_marker_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.84))
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.09, 0.11))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 12)
	var w := lbl.get_theme_default_font().get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	lbl.position = Vector2(-w * 0.5, MARKER_HEIGHT * 0.5 + 10.0)
	return lbl


## Six deterministic scatter points spread across the world (no RNG, so the map is
## stable across sessions and headless-verifiable).
func _scatter_spots() -> Array:
	var ws := _world_size()
	return [
		Vector2(ws.x * 0.18, ws.y * 0.24),
		Vector2(ws.x * 0.78, ws.y * 0.20),
		Vector2(ws.x * 0.26, ws.y * 0.74),
		Vector2(ws.x * 0.82, ws.y * 0.70),
		Vector2(ws.x * 0.52, ws.y * 0.14),
		Vector2(ws.x * 0.46, ws.y * 0.88),
	]


func _on_workshop_pressed() -> void:
	if _ctx == null or _in_encounter:
		return
	_ctx.screens.open_workshop()
