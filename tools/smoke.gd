extends SceneTree
## Partie automatique de contrôle : joue plusieurs étages en accéléré en validant les fenêtres (godot --headless --path . -s tools/smoke.gd -- [secondes de jeu]).
func _initialize() -> void:
	var secs := float(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 240.0
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://smoke.json"
	g.reset()
	g.intro_seen = true
	g.seen_scenes = ["prologue"]
	g.tutorial_done = true
	g.tips = ["items", "ship"]
	g.speed = 3.0
	Engine.time_scale = 6.0
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var t := 0.0
	var results := 0
	var scenes := 0
	var chapters := 0
	var defeats := 0
	var tiers := 0
	var ship_t := 0.0
	var ups := 0
	var last_stage := 1
	var aboard := 0
	var last_print := -1
	var farm_t := 0.0
	while t < secs:
		await process_frame
		t += 1.0 / 60.0 * Engine.time_scale / Engine.time_scale * 6.0
		if int(t) % 60 == 0 and int(t) != last_print:
			last_print = int(t)
			print("t=%d étage=%d meilleur=%d modal=%s" % [int(t), g.stage, g.best_stage, str(main._modal)])
		var m = main._modal
		if m != null and is_instance_valid(m):
			if m is ResultScreen:
				results += 1
				m.next_pressed.emit()
				m.close()
			elif m is BoostScreen:
				m.picked.emit(m.offer[0])
				m.close()
			elif m is DialogueScreen:
				scenes += 1
				m._finish()
			elif m is SectorScreen:
				m.close()
			elif m is ChapterEndScreen:
				chapters += 1
				m.close()
			elif m is ShipTierScreen:
				tiers += 1
				m.close()
			elif m is AboardScreen:
				aboard += 1
				m.board_requested.emit()
				m.close()
			elif m.get_script() == ShipScreen:
				m.mission_requested.emit()
			elif m is DefeatScreen:
				defeats += 1
				m.farm_pressed.emit()
				m.close()
		# après un moment de farm, on retente l'étage le plus haut
		if g.stage < g.best_stage and m == null:
			farm_t += 1.0 / 60.0 * 6.0
			if farm_t > 40.0:
				farm_t = 0.0
				g.go_to(g.best_stage)
				main._start_battle()
		# le vaisseau : récolte, améliorations, le temps avance plus vite (10 min par seconde de jeu simulé)
		ship_t += 1.0 / 60.0 * 6.0
		if g.ship.unlocked and ship_t > 1.0:
			ship_t = 0.0
			ShipState.clock_offset += 600
			g.ship_update()
			g.ship.collect_all(g)
		var ship_need := 0.0
		if g.ship.unlocked:
			for r in Ship.ORDER:
				var blk: String = g.ship.upgrade_block(g, r)
				if blk == "":
					if g.ship.start_upgrade(g, r):
						ups += 1
				elif blk == "Pas assez de ressources":
					var cc: float = float(Ship.upgrade_cost(r, g.ship.room_level(r) + 1).credits)
					ship_need = cc if ship_need == 0.0 else minf(ship_need, cc)
		# on évolue dès que possible, puis on dépense les crédits comme un joueur
		for id in g.squad_ids():
			if g.can_afford_evolve(id):
				g.evolve(id)
		for id in g.squad_ids():
			if g.can_level(id) and (ship_need == 0.0 or g.credits - float(g.level_cost(id)) > ship_need * 0.5 or int(t) % 5 == 0):
				g.level_up(id)
		if int(t) % 7 == 0:
			g.equip_best_all()
			g.recycle_items(g.inventory_items().filter(func(it): return Items.rarity_index(it.rarity) < 2).map(func(it): return int(it.id)))
	print("SMOKE histoire : %d scènes, %d chapitre(s) terminé(s), vues : %s" % [scenes, chapters, str(g.seen_scenes)])
	print("SMOKE vaisseau : niveau %d, salles %s, améliorations %d, nouvelles versions vues %d, bienvenue à bord %d" % [g.ship.level, str(g.ship.rooms), ups, tiers, aboard])
	print("SMOKE objets : %d, équipés : %d, éclats : %d" % [g.items.size(), g.items.filter(func(it): return it.on != "").size(), g.shards])
	print("SMOKE étage atteint : %d, meilleur : %d, résultats : %d, défaites : %d, niveaux : %s, paliers : %s, renforts : %s, persévérance : %d, crédits : %d, éclats : %d" % [g.stage, g.best_stage, results, defeats, str(g.levels.values()), str(g.evolved.values()), str(g.boosts), g.perseverance, g.credits, g.shards])
	Engine.time_scale = 1.0
	quit()
