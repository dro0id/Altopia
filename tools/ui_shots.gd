extends SceneTree
## Captures des fenêtres (xvfb-run -a godot --path . --resolution 720x1280 -s tools/ui_shots.gd -- <dossier>).
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot.json"
	g.reset()
	g.intro_seen = true
	g.tutorial_done = true
	g.stage = 9
	g.best_stage = 9
	g.credits = 900.0
	g.stars = {1: 3, 2: 3, 3: 2, 4: 3, 5: 3, 6: 1, 7: 3, 8: 2}
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 120:
		await process_frame
	await _shot(out + "/map.png", main, MapScreen.new(), 0.8)
	var chest := {"rarity": "rare", "credits": 1200.0, "shards": 8}
	await _shot(out + "/result.png", main, ResultScreen.new(5, 3, chest, "Monter à l'étage 6"), 3.2)
	await _shot(out + "/result_ultime.png", main, ResultScreen.new(10, 3, {"rarity": "ultime", "credits": 40000.0, "shards": 120}, "Monter à l'étage 11"), 3.2)
	await _shot(out + "/result_legendaire.png", main, ResultScreen.new(10, 3, {"rarity": "legendaire", "credits": 9000.0, "shards": 40}, "Monter à l'étage 11"), 3.2)
	await _shot(out + "/settings.png", main, SettingsScreen.new(), 0.5)
	await _shot(out + "/defeat.png", main, DefeatScreen.new(9), 0.5)
	await _shot(out + "/offline.png", main, OfflineScreen.new({"seconds": 18720.0, "credits": 4860.0}), 0.5)
	var intro := IntroScreen.new()
	main.add_child(intro)
	for i in 240:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/intro.png")
	intro.queue_free()
	quit()


func _shot(path: String, main: Control, ov: Control, secs: float) -> void:
	main._open_modal(ov)
	var t := 0.0
	while t < secs:
		await process_frame
		t += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	ov.queue_free()
	await process_frame
	await process_frame
