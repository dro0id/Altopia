extends SceneTree
## Suite d'images du combat (xvfb-run -a godot --path . --resolution 720x1280 -s tools/frames.gd -- <dossier> <départ s> <nombre> <secteur> [vitesse])
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot.json"
	g.reset()
	g.stage = int(a[3])
	g.best_stage = int(a[3])
	g.speed = float(a[4]) if a.size() > 4 else 1.0
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var t := 0.0
	while t < float(a[1]):
		await process_frame
		t += 1.0 / 60.0
	for i in int(a[2]):
		for k in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/f%03d.png" % [a[0], i])
	quit()
