extends SceneTree
## Capture d'écran de l'UI (nécessite un affichage, p. ex. xvfb-run).
## godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s tools/screenshot.gd -- <dossier>
## Joue une courte partie scriptée et enregistre un PNG par écran.

func _shot(path: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "/tmp"
	await process_frame   # laisse les autoloads finir leur _ready
	var gs = root.get_node("GameState")
	gs.save_path = "user://screenshot_save.json"
	gs.reset()
	gs.rng.seed = 3
	gs.give_hero("rex", 6)
	gs.give_hero("bolt", 5, 1)
	gs.give_hero("lumi", 4)
	gs.give_hero("nova", 3)
	gs.give_hero("gorn", 2, 2)
	gs.add_res("credits", 650.0)
	gs.add_res("data", 40.0)
	gs.add_res("minerals", 60.0)
	gs.add_res("energy", 30.0)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	gs.set_squad_member(0, 0, "rex")
	gs.set_squad_member(0, 1, "bolt")
	gs.set_squad_member(0, 2, "lumi")
	await _shot_tab(main, "heroes", out_dir + "/shot_heroes.png")
	await _shot_tab(main, "exp", out_dir + "/shot_exp_idle.png")
	gs.launch(0, "star")
	gs.tick(12.0)
	await _shot_tab(main, "exp", out_dir + "/shot_exp_star.png")
	gs.recall(0)
	gs.launch(0, "asteroids")
	gs.tick(5.0)
	await _shot_tab(main, "exp", out_dir + "/shot_exp_asteroids.png")
	gs.recall(0)
	gs.add_res("data", 80.0)      # de quoi débloquer la planète
	gs.launch(0, "planet")
	gs.tick(30.0)
	await _shot_tab(main, "exp", out_dir + "/shot_exp_planet.png")
	# Combat animé : on termine une expédition pendant que l'onglet Expéditions est visible.
	gs.recall(0)
	gs.slots[0].auto = false
	gs.launch(0, "asteroids")
	main._show_tab("exp")
	await process_frame
	gs.tick(500.0)
	main._refresh()
	var bv = main._slot_ui[0].bv
	_advance(bv, 1.6)
	main._slot_ui[0].view.visible = false
	await _shot_tab(main, "exp", out_dir + "/shot_battle_mid.png")
	while bv._ev_i < bv._events.size():
		bv.advance(0.05)
	_advance(bv, 0.4)      # juste après le dernier coup : le bandeau de résultat s'affiche
	await _shot_tab(main, "exp", out_dir + "/shot_battle_late.png")
	await _shot_tab(main, "ship", out_dir + "/shot_ship.png")
	quit()


func _advance(bv: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		bv.advance(0.05)
		t += 0.05


func _shot_tab(main: Node, tab: String, path: String) -> void:
	main._show_tab(tab)
	main._refresh()
	await _shot(path)
