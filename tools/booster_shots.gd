extends SceneTree
## Captures des boosters d'objets (xvfb-run -a godot --path . --resolution 720x1280 -s tools/booster_shots.gd -- <dossier>)
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot.json"
	g.reset()
	g.stage = 12
	g.best_stage = 12
	g.tutorial_done = true
	g.intro_seen = true
	for id in g.levels.keys():
		g.levels[id] = 14
	g.item_tokens = 40
	g.item_pack_pity = {"epic": 6, "leg": 14}
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(1.0)
	var rs := RecruitScreen.new()
	main._open_modal(rs, 3)
	await _wait(0.4)
	await _snap(out + "/rec_heros.png")
	rs._set_mode(1)
	g.item_pulls = [{"slot": "arme", "rarity": "rare"}, {"slot": "module", "rarity": "normal"}, {"slot": "relique", "rarity": "epique"}]
	await _wait(0.4)
	await _snap(out + "/rec_objets.png")
	rs._pull(10)
	await _wait(2.5)
	await _snap(out + "/rec_res10.png")
	quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0
