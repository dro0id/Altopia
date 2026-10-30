extends SceneTree
## Capture du jeu (xvfb-run -a godot --path . --resolution 720x1280 -s tools/shot.gd -- <png> [secondes] [secteur])
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot.json"
	g.reset()
	if a.size() > 2:
		g.stage = int(a[2])
		g.best_stage = int(a[2])
	g.credits = 500.0
	if a.size() > 3:
		g.speed = float(a[3])
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var secs := float(a[1]) if a.size() > 1 else 4.0
	var t := 0.0
	while t < secs:
		await process_frame
		t += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
