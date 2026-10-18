extends SceneTree
const Data = preload("res://scripts/game_data.gd")
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
	var page: String = "base" if tab in ["salles", "atelier", "lab", "ship", "rang"] else tab
	main._pages[page].get_meta("scroll").scroll_vertical = scroll
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
	var worn := [["weapon", "legendary", 14], ["helmet", "epic", 12], ["suit", "epic", 11],
		["gloves", "rare", 9], ["boots", "uncommon", 7], ["module", "legendary", 13]]
	for e in worn:
		var it = gs.make_item(e[0], e[1], e[2])
		gs.items.append(it)
		gs.equipped[e[0]] = it.id
	for e in [["weapon", "rare", 12], ["helmet", "legendary", 15], ["boots", "epic", 13], ["gloves", "common", 3], ["suit", "rare", 10]]:
		gs.items.append(gs.make_item(e[0], e[1], e[2]))
	gs.auto_squad(0)
	gs.auto_rooms()
	gs.add_res("credits", 650.0)
	gs.add_res("data", 40.0)
	gs.add_res("minerals", 60.0)
	gs.add_res("energy", 30.0)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await _shot_tab(main, "captain", out_dir + "/shot_captain.png")
	await _shot_tab(main, "captain", out_dir + "/shot_anomalies.png", 560)
	gs.anomaly_max = 6
	gs.enter_anomaly(7)
	main._refresh()
	for i in 12:
		main._an_view.advance(0.05)
	await _shot_tab(main, "captain", out_dir + "/shot_anomaly_fight.png", 560)
	while main._an_view.playing:
		main._an_view.advance(0.1)
	await _shot_tab(main, "captain", out_dir + "/shot_anomaly_result.png", 560)
	await _shot_tab(main, "captain", out_dir + "/shot_captain_inv.png", 1500)
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
	gs.research_levels["calibrage"] = 7
	gs.research_levels["cartographie"] = 4
	gs.add_res("credits", 2.0e6)
	gs.add_res("data", 5.0e5)
	gs.add_res("minerals", 1.0e5)
	gs.start_research("propulsion")
	gs.start_research("protocoles")
	gs.tick(3000.0)
	gs.auto_rooms()
	gs.give_hero("tess", 20)
	gs.give_hero("nova", 15)
	gs.give_hero("quark", 12)
	gs.give_hero("lumi", 18)
	gs.auto_rooms()
	gs.room_crew["soute"] = ""
	for rid in ["mine", "centrale", "labo", "atelier", "quartiers"]:
		gs.room_levels[rid] = 6 + gs.room_levels.size()
	gs.atelier_slot = "weapon"
	gs.atelier_focus = "crit"
	gs.tick(2400.0)
	await _shot_tab(main, "salles", out_dir + "/shot_base.png")
	main._base_ui.open_room("mine")
	await _shot(out_dir + "/shot_base_sheet.png")
	main._base_ui.close_sheet()
	await _shot_tab(main, "atelier", out_dir + "/shot_atelier.png")
	await _shot_tab(main, "atelier", out_dir + "/shot_atelier_end.png", 900)
	await _shot_tab(main, "lab", out_dir + "/shot_lab.png")
	await _shot_tab(main, "lab", out_dir + "/shot_lab_list.png", 1000)
	gs.prestige_count = 2
	gs.prestige_points = 7
	gs.prestige_best = 132
	gs.prestige_perks = {"prod": 3, "xp": 2, "atelier": 1, "found": 2}
	for rid in Data.ROOM_ORDER:
		gs.room_levels[rid] = 25
	await _shot_tab(main, "rang", out_dir + "/shot_rang.png")
	await _shot_tab(main, "rang", out_dir + "/shot_rang_end.png", 900)
	await _shot_tab(main, "ship", out_dir + "/shot_ship.png")
	gs.captain.level = 5
	var rep: Dictionary = gs.simulate_offline(6.0 * 3600.0)
	main._show_tab("captain")
	main._base_ui.show_offline_report(rep)
	await _shot(out_dir + "/shot_offline.png")
	quit()
