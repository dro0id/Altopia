extends SceneTree
## Capture de la navigation (xvfb-run -a godot --path . --resolution 720x1280 -s tools/nav_shot.gd -- <dossier>)
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot.json"
	g.reset()
	g.stage = 12
	g.best_stage = 12
	g.tutorial_done = true
	g.intro_seen = true
	for id in g.levels.keys():
		g.levels[id] = 6
	g.credits = 500.0
	g.tokens = 7
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(1.5)
	for i in [1, 2, 3]:
		main._on_tab(i)
		await _wait(0.5)
		print("onglet ", i, " actif=", main._nav.active, " barre visible=", main._nav.visible, " pause=", paused)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/tab%d.png" % [a[0], i])
	main._on_tab(0)
	await _wait(0.3)
	print("retour combat actif=", main._nav.active, " modal=", main._modal, " pause=", paused)
	quit()


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0
