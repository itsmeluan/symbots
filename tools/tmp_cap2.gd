extends SceneTree
const OUT := "/private/tmp/claude-501/-Volumes-SSDLuan-Projetos-symbots/61b52282-5c91-4428-a950-501f945a016a/scratchpad"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://src/scenes/v1/v1_game.gd").new()
	game.save_backend = load("res://tests/support/memory_backend.gd").new()
	root.add_child(game)
	for i in 5: await process_frame
	game._on_stage_chosen(game.ctx.stages.entries[0])
	for i in 10: await process_frame
	var battle = game._battle
	var actor = battle.engine.current_actor()
	battle._on_skill_pressed(actor.skills[0])
	battle._on_unit_tapped(battle.engine.legal_targets(actor, battle._pending_skill)[0])
	await create_timer(0.15).timeout
	var img: Image = root.get_texture().get_image(); img.save_png(OUT + "/pace_player_lunge.png"); print("saved 1")
	await create_timer(0.85).timeout
	img = root.get_texture().get_image(); img.save_png(OUT + "/pace_enemy_reply.png"); print("saved 2")
	quit()
