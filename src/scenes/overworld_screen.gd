## OverworldScreen — the walkable map where the player finds and engages enemies.
##
## STRUCTURE vs STYLE (ADR-0008): the static shell (Bg / Title / WorkshopBtn / Token)
## and its styling live in overworld_screen.tscn + the central Theme. This script owns
## behaviour + the enemy markers, which are generated from live EnemyDB data (not
## editor-authorable). Placeholder colour token → swap Token for a player sprite later.
##
## The player token moves by keyboard (arrows / WASD) or tap-to-move (touch-first).
## Walking onto an enemy marker triggers a battle via ScreenManager.enter_battle().
## On VICTORY the marker is cleared.
##
## KEEP-ALIVE (ADR-0004 §3): ScreenManager hides + PROCESS_MODE_DISABLED's this screen on
## battle entry and restores it on encounter_resolved. Movement lives in _physics_process
## and taps in _unhandled_input — both are suppressed by PROCESS_MODE_DISABLED, so the map
## is inert during battle. We deliberately do NOT use _input (it is NOT suppressed).
extends Screen

const MOVE_SPEED := 240.0
const TOKEN_SIZE := 44.0
const TRIGGER_RADIUS := 40.0
const WORLD := Vector2(1024, 600)
const MAX_MARKERS := 6

# encounter_resolved result codes (EventBus): WIN=1, LOSS=2, FLEE=3.
const RESULT_WIN := 1
# encounter_type codes: WILD=1, BOSS=2.
const ENCOUNTER_WILD := 1

const COL_ENEMY := Color(0.85, 0.30, 0.28)   # red — an enemy marker (data-generated)

var _ctx: ServiceContext
var _log: LogSink

# Static shell authored in overworld_screen.tscn; resolved via % unique names.
@onready var _token: ColorRect = %Token
var _target_pos: Vector2 = Vector2.INF       # INF = no active tap-move target
var _markers: Array = []                      # [{node: ColorRect, enemy: EnemyDef}]
var _in_encounter: bool = false
var _pending_marker = null


func _ready() -> void:
	%WorkshopBtn.pressed.connect(_on_workshop_pressed)
	# Centre the player token on the field (position is behaviour, not editor layout).
	_token.position = WORLD * 0.5 - Vector2(TOKEN_SIZE, TOKEN_SIZE) * 0.5


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


# ---------------------------------------------------------------------------
# Movement + encounter triggering
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _ctx == null or _in_encounter:
		return
	var dir := _keyboard_dir()
	var center := _token.position + Vector2(TOKEN_SIZE, TOKEN_SIZE) * 0.5
	if dir == Vector2.ZERO and _target_pos != Vector2.INF:
		var to_target := _target_pos - center
		if to_target.length() > 4.0:
			dir = to_target.normalized()
		else:
			_target_pos = Vector2.INF  # arrived
	if dir == Vector2.ZERO:
		return
	center += dir * MOVE_SPEED * delta
	center.x = clampf(center.x, TOKEN_SIZE * 0.5, WORLD.x - TOKEN_SIZE * 0.5)
	center.y = clampf(center.y, TOKEN_SIZE * 0.5, WORLD.y - TOKEN_SIZE * 0.5)
	_token.position = center - Vector2(TOKEN_SIZE, TOKEN_SIZE) * 0.5
	_check_encounters(center)


func _unhandled_input(event: InputEvent) -> void:
	if _in_encounter:
		return
	if event is InputEventMouseButton and event.pressed:
		_target_pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and event.pressed:
		_target_pos = (event as InputEventScreenTouch).position


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


func _check_encounters(player_center: Vector2) -> void:
	for m in _markers:
		var node: Control = m["node"]
		if not is_instance_valid(node):
			continue
		var mc := node.position + Vector2(TOKEN_SIZE, TOKEN_SIZE) * 0.5
		if player_center.distance_to(mc) < TRIGGER_RADIUS:
			_trigger_encounter(m)
			return


func _trigger_encounter(marker: Dictionary) -> void:
	_in_encounter = true
	_pending_marker = marker
	_target_pos = Vector2.INF
	var e: EnemyDef = marker["enemy"]
	# Pass only the id + type — the Battle screen re-resolves the full EnemyDef
	# (stats, break_regions, loot_pool) from EnemyDB so the encounter payload stays thin.
	_log.info(&"encounter_triggered", {"enemy": e.id})
	_ctx.screens.enter_battle({"enemy_id": e.id, "encounter_type": ENCOUNTER_WILD})


## Battle finished — ScreenManager has (or will) restore us. Clear the enemy on a win.
func _on_encounter_resolved(result: int, _encounter_type: int) -> void:
	_in_encounter = false
	if result == RESULT_WIN and _pending_marker != null:
		var node: Control = _pending_marker["node"]
		if is_instance_valid(node):
			node.queue_free()
		_markers.erase(_pending_marker)
	_pending_marker = null


# ---------------------------------------------------------------------------
# Enemy markers (data-generated from EnemyDB — not editor-authorable)
# ---------------------------------------------------------------------------

## Place up to MAX_MARKERS enemy markers from real EnemyDB data at scattered positions.
func _spawn_enemy_markers() -> void:
	var enemies := EnemyDB.all_enemies()
	if enemies.is_empty():
		_log.warn(&"overworld_no_enemies", {})
		return
	# Deterministic scatter around the field, avoiding the centre spawn.
	var spots := _scatter_spots()
	var n: int = mini(MAX_MARKERS, mini(enemies.size(), spots.size()))
	for i in n:
		var e: EnemyDef = enemies[i]
		# Asset pipeline hook: use enemies/<id>.png when authored, else the placeholder
		# ColorRect. Drop the sprite in → the marker upgrades with no code change.
		var node := _make_marker_node(e.id)
		node.size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
		node.position = spots[i] - Vector2(TOKEN_SIZE, TOKEN_SIZE) * 0.5
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(node)

		var lbl := Label.new()
		lbl.text = e.display_name
		lbl.position = Vector2(-20, TOKEN_SIZE + 2)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.72))
		node.add_child(lbl)

		_markers.append({"node": node, "enemy": e})


## Placeholder-or-sprite marker: a TextureRect when enemies/<id>.png exists, else the
## flat-colour ColorRect. Both are Controls, so the caller treats them uniformly.
func _make_marker_node(enemy_id) -> Control:
	var tex := Art.texture("enemies", enemy_id)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return tr
	var rect := ColorRect.new()
	rect.color = COL_ENEMY
	return rect


## Six fixed scatter points around the field perimeter/quadrants (deterministic — no RNG,
## so the map is stable across sessions and headless-verifiable).
func _scatter_spots() -> Array:
	return [
		Vector2(WORLD.x * 0.18, WORLD.y * 0.30),
		Vector2(WORLD.x * 0.80, WORLD.y * 0.28),
		Vector2(WORLD.x * 0.22, WORLD.y * 0.78),
		Vector2(WORLD.x * 0.78, WORLD.y * 0.76),
		Vector2(WORLD.x * 0.50, WORLD.y * 0.20),
		Vector2(WORLD.x * 0.50, WORLD.y * 0.85),
	]


func _on_workshop_pressed() -> void:
	if _ctx == null or _in_encounter:
		return
	_ctx.screens.open_workshop()
