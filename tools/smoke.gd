extends SceneTree
## Partie automatique de contrôle : joue plusieurs étages en accéléré en validant les fenêtres (godot --headless --path . -s tools/smoke.gd -- [secondes de jeu]).
func _initialize() -> void:
	var secs := float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 240.0
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://smoke.json"
	g.reset()
	g.intro_seen = true
	g.speed = 3.0
	Engine.time_scale = 6.0
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var t := 0.0
	var results := 0
	var defeats := 0
	var last_stage := 1
	while t < secs:
		await process_frame
		t += 1.0 / 60.0 * Engine.time_scale / Engine.time_scale * 6.0
		var m = main._modal
		if m != null and is_instance_valid(m):
			if m is ResultScreen:
				results += 1
				m.next_pressed.emit()
				m.close()
			elif m is DefeatScreen:
				defeats += 1
				m.farm_pressed.emit()
				m.close()
		# on dépense les crédits comme un joueur
		for id in g.levels.keys():
			if g.can_level(id):
				g.level_up(id)
	print("SMOKE étage atteint : %d, meilleur : %d, résultats : %d, défaites : %d, niveaux : %s, crédits : %d, éclats : %d" % [g.stage, g.best_stage, results, defeats, str(g.levels.values()), g.credits, g.shards])
	Engine.time_scale = 1.0
	quit()
