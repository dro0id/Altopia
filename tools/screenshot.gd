extends SceneTree
## Capture d'écran de l'UI (nécessite un affichage, p. ex. xvfb-run).
## godot --path . --resolution 720x1280 -s tools/screenshot.gd -- <dossier>
## Joue une courte partie scriptée et enregistre un PNG par écran.

func _frames(n: int = 8) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(path: String) -> void:
	await _frames()
	root.get_viewport().get_texture().get_image().save_png(path)


func _advance(bv: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		bv.advance(0.05)
		t += 0.05


func _shot_tab(main: Node, tab: String, path: String, scroll: int = 0) -> void:
	main._show_tab(tab)
	main._refresh()
	await _frames(3)
	main._pages[tab].get_meta("scroll").scroll_vertical = scroll
	await _shot(path)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "/tmp"
	await process_frame   # laisse les autoloads finir leur _ready
	var gs = root.get_node("GameState")
	gs.save_path = "user://screenshot_save.json"
	gs.reset()
	gs.rng.seed = 5
	gs.captain.level = 8
	gs.captain.xp = 60
	gs.captain.look = {"suit": 0, "hair": 1, "style": 1}
	gs.give_hero("rex", 6)
	gs.give_hero("bolt", 5, 1)
	gs.give_hero("lumi", 4)
	gs.give_hero("nova", 3)
	gs.give_hero("gorn", 2, 2)
	var w = gs.make_item("weapon", "rare", 2); w.level = 3; w.xp = 25
	var su = gs.make_item("suit", "epic", 2); su.level = 2
	var mo = gs.make_item("module", "common", 1); mo.level = 4; mo.xp = 10
	for it in [w, su, mo, gs.make_item("weapon", "common", 1), gs.make_item("suit", "rare", 1), gs.make_item("module", "epic", 3)]:
		gs.items.append(it)
	gs.equip(w.id)
	gs.equip(su.id)
	gs.equip(mo.id)
	gs.auto_squad(0)
	gs.add_res("credits", 650.0)
	gs.add_res("data", 40.0)
	gs.add_res("minerals", 60.0)
	gs.add_res("energy", 30.0)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await _shot_tab(main, "captain", out_dir + "/shot_captain.png")
	await _shot_tab(main, "captain", out_dir + "/shot_captain_inv.png", 640)
	await _shot_tab(main, "crew", out_dir + "/shot_crew.png")
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
