extends SceneTree
## Déroulé d'une partie en captures : un joueur « robot » (3 sessions de 8 min par jour) joue sur la vraie interface.
## Une série de captures est prise à chaque étape (jour 1, 7, 30, 60, 90).
##   xvfb-run -a godot --path . --resolution 720x1280 -s tools/playthrough.gd -- <dossier> [profil]
const Bot = preload("res://tools/bot.gd")
const Data = preload("res://scripts/game_data.gd")
const PROFILES := {
	"casual": [[8.0, 5.0]],
	"regular": [[8.0, 8.0], [12.5, 8.0], [19.0, 8.0]],
	"hardcore": [[7.0, 10.0], [10.0, 10.0], [13.0, 10.0], [16.0, 10.0], [19.0, 10.0], [22.0, 10.0]],
}
const CHECKPOINTS := [1, 7, 30, 60, 90]


func _frames(n: int = 6) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(main: Node, tab: String, path: String, scroll: int = 0) -> void:
	main._show_tab(tab)
	main._refresh()
	await _frames(3)
	main._pages[tab].get_meta("scroll").scroll_vertical = scroll
	await _frames()
	root.get_viewport().get_texture().get_image().save_png(path)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "/tmp"
	var profile := args[1] if args.size() > 1 else "regular"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://playthrough_save.json"
	gs.new_game()
	gs.rng.seed = 2024
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var bot = Bot.new(gs)
	var sessions: Array = PROFILES[profile]
	var clock := 0.0
	await _shot(main, "captain", out_dir + "/j0_0_capitaine.png")
	var stats := []
	for day in 90:
		for s in sessions:
			var start: float = day * 86400.0 + float(s[0]) * 3600.0
			if start > clock:
				var away: float = start - clock
				if away > 60.0:
					var rep: Dictionary = gs.simulate_offline(away)
					if day + 1 == 7 and s == sessions[0]:      # le rapport de retour du jour 7
						main._show_offline_report(rep)
						await _frames()
						root.get_viewport().get_texture().get_image().save_png(out_dir + "/j7_5_retour.png")
						main.get_child(main.get_child_count() - 1).queue_free()
						await process_frame
				else:
					gs.tick(away)
				clock = start
			bot.play(float(s[1]) * 60.0)
			clock += float(s[1]) * 60.0
		if CHECKPOINTS.has(day + 1):
			var d := day + 1
			var best_ilvl := 0
			for slot in Data.EQUIP_SLOTS:
				best_ilvl = maxi(best_ilvl, int(gs.equipped_item(slot).get("ilvl", 0)))
			stats.append({"day": d, "captain": gs.captain.level, "faille": gs.anomaly_max, "afk": gs.afk_level(), "ilvl": best_ilvl,
				"items": gs.items.size(), "research": gs.research_levels.values().reduce(func(a, b): return a + b, 0)})
			main._an_sel = clampi(gs.anomaly_max + 1, 1, gs.anomaly_unlocked_max())
			await _shot(main, "captain", "%s/j%d_0_capitaine.png" % [out_dir, d])
			await _shot(main, "captain", "%s/j%d_1_anomalies.png" % [out_dir, d], 620)
			await _shot(main, "crew", "%s/j%d_2_equipage.png" % [out_dir, d])
			await _shot(main, "exp", "%s/j%d_3_expeditions.png" % [out_dir, d])
			await _shot(main, "lab", "%s/j%d_4_labo.png" % [out_dir, d])
			if d == 30:       # un combat d'anomalie en cours
				gs.anomaly_charges = 50.0
				gs.enter_anomaly(clampi(gs.anomaly_max + 1, 1, gs.anomaly_unlocked_max()))
				main._refresh()
				for i in 10:
					main._an_view.advance(0.05)
				await _shot(main, "captain", out_dir + "/j30_6_combat.png", 620)
				while main._an_view.playing:
					main._an_view.advance(0.1)
	var f := FileAccess.open(out_dir + "/stats.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(stats))
	quit()
