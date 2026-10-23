extends SceneTree
## Capture du briefing d'expédition (xvfb-run -a godot --path . --resolution 720x1280 -s tools/briefing_shot.gd -- <png>)
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://briefing_shot.json"
	gs.reset()
	gs.give_hero("rex", 5)
	gs.give_hero("jett", 3)
	gs.set_squad_member(0, 0, "jett")
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	main._start_live(0, "asteroids")
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(a[0])
	print("LIVE ", main._live != null, " SHEET ", main._sheet.visible)
	main._sheet_go.pressed.emit()
	await process_frame
	print("LIVE after go ", main._live != null)
	quit()
