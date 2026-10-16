extends SceneTree
## Capture d'écran de l'UI (nécessite un affichage, p. ex. xvfb-run).
## godot --path . -s tools/screenshot.gd -- <dossier_sortie> [setup]
## Joue une courte partie scriptée et enregistre un PNG par onglet.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "/tmp"
	await process_frame   # laisse les autoloads finir leur _ready
	var gs = root.get_node("GameState")
	gs.reset()
	gs.add_res("credits", 400.0)
	gs.add_res("data", 40.0)
	gs.add_res("minerals", 60.0)
	gs.add_res("energy", 30.0)
	for id in ["pilot", "engineer"]:
		gs.crew_levels[id] = 2
	gs.crew_levels["scientist"] = 1
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	gs.launch(0, "asteroids")
	gs.tick(8.0)
	for tab in ["crew", "exp", "ship"]:
		main._show_tab(tab)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/shot_%s.png" % [out_dir, tab])
	quit()
