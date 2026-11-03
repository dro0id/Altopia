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
	g.crystals = 130
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(1.5)
	for i in [1, 2, 3, 9, 7]:
		if i == 9:
			main._open_map()
		elif i == 7:
			main._open_modal(HeroScreen.new("mara"))
		else:
			main._on_tab(i)
		await _wait(0.5)
		print("onglet ", i, " actif=", main._nav.active, " barre visible=", main._nav.visible, " pause=", paused)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/tab%d.png" % [a[0], i])
	# vrais appuis sur la barre : Héros puis Boutique puis Combat
	for x in [270.0, 630.0, 90.0]:
		_click(Vector2(x, 1240))
		await _wait(0.3)
		print("clic x=", x, " actif=", main._nav.active, " modal=", main._modal != null, " pause=", paused)
	main._on_tab(0)
	await _wait(0.3)
	print("retour combat actif=", main._nav.active, " modal=", main._modal, " pause=", paused)
	quit()


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0


func _click(p: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		root.push_input(ev)
