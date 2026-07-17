# VERTICAL SLICE - NOT FOR PRODUCTION
# Headless smoke-runner for battle_screen.tscn — proves the scene instantiates,
# _ready() assembles the battle, and driving ATTACK in code breaks the arm + wins,
# all inside the REAL scene (not the harness). No visual validation — that's F6.
# Usage: godot --headless -s prototypes/symbots-vertical-slice/_smoke_screen.gd
#
# Drives from _process (not _initialize) so deferred _ready() has flushed and the
# widgets exist before we touch them.
extends SceneTree

var _screen: Node
var _done := false


func _initialize() -> void:
	var scn := load("res://prototypes/symbots-vertical-slice/battle_screen.tscn") as PackedScene
	if scn == null:
		push_error("could not load battle_screen.tscn")
		quit(1)
		return
	_screen = scn.instantiate()
	get_root().add_child(_screen)   # _ready() fires on the next frame, before _process


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var s := _screen

	print("--- after _ready() ---")
	print("log: ", s._log_label.text)
	print("enemy struct: ", s._enemy_struct_label.text,
		" | arm: ", s._arm_label.text, " | head: ", s._head_label.text)
	print("player: ", s._player_struct_label.text, " | energy: ", s._player_energy_label.text)
	print("target default: ", s._current_target)

	var round := 0
	while not s._battle_over and round < 40:
		round += 1
		if s._arm_broken:
			s._on_target_selected(BattleResolver.STRUCTURE)
		s._on_attack_pressed()
		print("[round %d] %s | %s | you: %s" % [
			round, s._enemy_struct_label.text,
			(s._arm_label.text if not s._arm_broken else "ARM BROKEN"),
			s._player_struct_label.text])

	print("--- battle over after %d rounds ---" % round)
	print("arm_broken: ", s._arm_broken, " | final log: ", s._log_label.text)
	print("attack btn disabled: ", s._attack_btn.disabled)

	s.queue_free()
	return true   # quit the main loop
