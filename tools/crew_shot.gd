extends SceneTree
## Capture de la fiche 3D d'un équipier (xvfb-run -a godot --path . --resolution 720x1280 -s tools/crew_shot.gd -- <id> <clip> <png>)
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://crew_shot.json"
	gs.reset()
	gs.give_hero(a[0], 5)
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	main._show_tab("crew")
	main._open_sheet(a[0], a.size() > 3)
	for i in 20:
		await process_frame
	main._sheet_view.play(a[1])
	for i in 40:
		await process_frame
	print("ANIM ", main._sheet_view._anim.current_animation, " ", main._sheet_view._anim.current_animation_position, " ", main._sheet_view._anim.is_playing())
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(a[2])
	quit()
