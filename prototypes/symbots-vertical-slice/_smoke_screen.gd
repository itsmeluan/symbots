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

	# 4c: farm through rematches until the RARE drops (or a cap), proving the reveal
	# panel populates, the harvest is stored, and DropSystem pity survives rematches.
	var fights := 0
	var harvested_rare := false
	while fights < 40 and not harvested_rare:
		fights += 1
		_drive_one_fight(s)
		var names: Array = []
		for d in s._harvested_drops:
			names.append(String(d.part.id))
			if d.part.rarity >= PartDef.Rarity.RARE:
				harvested_rare = true
		print("[fight %d] arm_broken=%s head_broken=%s fired=%s drops=%s%s" % [
			fights, s._arm_broken, s._head_broken, s._fired_events.keys(), names,
			("  ← RARE" if harvested_rare else "")])
		if not harvested_rare:
			s._on_rematch_pressed()   # reset + restart on the same controller/drop_system

	print("--- farm done after %d fight(s) — rare harvested: %s ---" % [fights, harvested_rare])
	print("overlay title: ", s._overlay_title.text, " | rematch btn: ", s._rematch_btn.text)
	print("final harvest: ", ("[]" if s._harvested_drops.is_empty()
		else s._harvested_drops[0].part.display_name if s._harvested_drops.size() > 0 else "?"))

	s.queue_free()
	return true   # quit the main loop


# Drive a single encounter to a terminal state (attack arm, break it, finish CORE).
func _drive_one_fight(s: Node) -> void:
	var round := 0
	while not s._battle_over and round < 40:
		round += 1
		if s._arm_broken:
			s._on_target_selected(BattleResolver.STRUCTURE)
		s._on_attack_pressed()
