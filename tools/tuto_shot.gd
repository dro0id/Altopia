extends SceneTree
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot.json"
	g.reset()
	g.intro_seen = true
	g.credits = float(a[2]) if a.size() > 2 else 0.0
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var t := 0.0
	while t < float(a[1]):
		await process_frame
		t += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
