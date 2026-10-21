extends SceneTree
## Captures de la Route en 3D (nécessite un affichage : xvfb-run). godot --path . --resolution 720x1280 -s tools/route_shots.gd -- <dossier> [graine]
const Data = preload("res://scripts/game_data.gd")


func _frames(n: int = 6) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(path: String) -> void:
	await _frames()
	root.get_viewport().get_texture().get_image().save_png(path)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


## Attend que l'interface ait fini son animation (le rendu logiciel est lent : on ne peut pas compter sur un signal ponctuel).
func _idle(ui: Object, max_sec: float = 20.0) -> void:
	var t0 := Time.get_ticks_msec()
	while ui._busy and float(Time.get_ticks_msec() - t0) / 1000.0 < max_sec:
		await process_frame


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "/tmp"
	var seed_v := int(args[1]) if args.size() > 1 else 4242
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://route_shots_save.json"
	gs.reset()
	gs.captain.level = 12
	gs.give_hero("rex", 6)
	gs.give_hero("gorn", 4)
	gs.give_hero("lumi", 5)
	gs.auto_squad(0)
	gs.add_res("data", 80.0)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var UI = load("res://scripts/route_ui.gd")
	var ui = UI.new()
	main.add_child(ui)
	main._live = ui
	ui.begin(0, "planet", gs.route_config("planet", 0), false, 1.0, seed_v)
	await _wait(1.0)
	await _shot(out_dir + "/route_0_start.png")
	# on joue les étapes une à une, en capturant le voyage, l'arrivée et l'action
	var n := 0
	var guard := 0
	while not ui.sim.over and guard < 40:
		guard += 1
		var sim = ui.sim
		match sim.phase:
			"map":
				ui._choose_node(sim.auto_node())
				await _wait(0.55)
				await _shot(out_dir + "/route_%02d_travel.png" % n)
				await _idle(ui)
				await _wait(0.6)
				await _shot(out_dir + "/route_%02d_arrive_%s.png" % [n, sim.current_type()])
				n += 1
			"event":
				ui._pick_option(sim.auto_option())
				await _wait(0.5)
				await _shot(out_dir + "/route_%02d_event_fx.png" % n)
				await _idle(ui)
			"combat":
				ui._start_fight()          # le vrai combat en direct (LiveUI en mode Route), joué à toute vitesse
				await _wait(0.5)
				await _shot(out_dir + "/route_%02d_fight_ui.png" % n)
				var lui = ui._fight
				lui.sim.assist = true
				var st := 0
				while not lui.sim.over and st < 20000:
					lui.sim.step(1.0 / 30.0)
					st += 1
				await _wait(0.6)
				await _shot(out_dir + "/route_%02d_fight_result.png" % n)
				lui._again_btn.pressed.emit()
				await _wait(1.0)
				await _shot(out_dir + "/route_%02d_fight_fx.png" % n)
				await _idle(ui)
				await _wait(0.4)
			"harvest":
				ui._harvest("min")
				await _wait(0.7)
				await _shot(out_dir + "/route_%02d_harvest_fx.png" % n)
				await _idle(ui)
			"rest":
				ui._rest()
				await _wait(0.6)
				await _shot(out_dir + "/route_%02d_rest_fx.png" % n)
				await _idle(ui)
		await _wait(0.2)
	await _wait(2.5)
	await _shot(out_dir + "/route_99_result.png")
	print("fin du voyage : victoire=%s étapes=%d" % [ui.sim.win, ui.sim.steps])
	ui._toggle_sheet(true)
	await _frames()
	await _shot(out_dir + "/route_98_map.png")
	quit()
