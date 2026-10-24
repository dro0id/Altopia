extends SceneTree
## Captures de l'introduction et du bandeau de mission (xvfb-run -a godot --path . --resolution 720x1280 -s tools/tuto_shot.gd -- <dossier>)
func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://tuto_shot.json"
	gs.reset()
	gs.new_game()
	gs.start_tutorial()
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(10)
	var intro = null
	for c in main.get_children():
		if c is IntroUI:
			intro = c
	print("INTRO ", intro != null, " size=", intro.size, " vis=", intro.visible, " rect=", intro.get_global_rect(), " parent=", intro.get_parent().name, " psize=", main.size, " children=", intro.get_child_count(), " page=", intro._page)
	for n in 6:
		intro._tween.kill()
		intro._fade.color.a = 0.0
		intro._build(n)
		await _frames(40)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/intro_%d.png" % [out, n])
	intro.finished.emit()
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/after_intro.png" % out)
	print("STEP ", gs.tuto_step, " intro_seen ", gs.tuto_intro_seen)
	quit()
