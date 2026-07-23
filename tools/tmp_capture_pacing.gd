## Throwaway capture: paced battle opening, enemy action mid-animation, header,
## skewed cards, and the reward screen keeping the battlefield.
extends SceneTree

const OUT := "/private/tmp/claude-501/-Volumes-SSDLuan-Projetos-symbots/61b52282-5c91-4428-a950-501f945a016a/scratchpad"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://src/scenes/v1/v1_game.gd").new()
	game.save_backend = load("res://tests/support/memory_backend.gd").new()
	root.add_child(game)
	for i in 5:
		await process_frame

	# Stage 3 opens with a faster enemy, so the paced opening is visible.
	game._on_stage_chosen(game.ctx.stages.entries[0])
	for i in 3:
		await process_frame
	await _snap("pace_open.png")           # quiet field — nobody has swung yet

	await create_timer(0.75).timeout       # enemy beat + lunge underway
	await _snap("pace_enemy_acting.png")

	await create_timer(1.4).timeout        # back at player input
	await _snap("pace_player_turn.png")

	# Auto to the end at a quick pace, then the reward screen with the stage's art.
	game._battle.turn_pace = 0.12
	game._battle._auto_toggle.button_pressed = true
	var guard := 0
	while game._reward == null and guard < 600:
		await process_frame
		guard += 1
	await create_timer(0.2).timeout
	await _snap("pace_victory.png")
	quit()

func _snap(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(OUT + "/" + name)
	print("saved ", name)
