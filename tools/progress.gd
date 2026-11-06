extends SceneTree

const Data = preload("res://scripts/data.gd")
## Progression réelle d'un joueur type, sans écran mais avec tout le jeu : équipement, renforts, évolutions,
## persévérance, farm après une défaite (godot --headless --path . -s tools/progress.gd -- [étage max] [graine]).
## Sortie : par étage de boss, temps de combat passé dessus (avec le farm) et défaites ; puis le total.

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var max_stage := int(a[0]) if a.size() > 0 else 40
	var seed_v := int(a[1]) if a.size() > 1 else 1
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://progress.json"
	g.reset()
	g.rng.seed = seed_v
	g.tutorial_done = true
	g.auto_recycle = true
	var t_total := 0.0
	var t_stage := 0.0
	var fails := 0
	var attempts := 0
	var rows: Array = []
	var timeouts := 0
	var facs: Array = []
	var real_defeats := 0
	var t0 := int(Time.get_unix_time_from_system())
	while g.best_stage <= max_stage and t_total < 3600.0 * 4.0:
		# le vaisseau suit le temps de jeu : production, chantiers, puis on investit comme un joueur
		ShipState.clock_offset = int(t_total) - (int(Time.get_unix_time_from_system()) - t0)
		g.ship_update()
		g.ship.collect_all(g)
		if _ship(g):
			_spend(g)
		var sim := BattleSim.new(g.team(), g.stage, seed_v * 7919 + attempts, g.boosts)
		attempts += 1
		var res: String = sim.run(240.0)
		if Sector.is_generated(g.stage) and g.stage >= g.best_stage:
			if res == "fighting" or sim.timed_out:
				timeouts += 1
			if res == "defeat" and not sim.timed_out:
				real_defeats += 1
		t_total += sim.time
		t_stage += sim.time
		g.credits += sim.credits * (Data.BOOST_MULT if g.boost_active() else 1.0)
		if res == "clear":
			var frontier: bool = g.stage >= g.best_stage
			var st: int = g.stage
			if frontier:
				g.record_generated(st, true)
			g.stage_cleared(sim.stars, sim.max_combo, false)
			g.equip_best_all()
			if frontier:
				if st % 10 == 0 and Sector.is_generated(st):
					facs.append("%d:%.2f" % [st, g.inf_diff])
				if Data.is_boss_stage(st):
					rows.append({"stage": st, "type": Data.boss_type(st), "time": t_stage, "fails": fails, "lvl": _avg(g), "total": t_total, "ship": g.ship.level})
				t_stage = 0.0
				fails = 0
				var offer: Array = g.offer_boosts()
				g.add_boost(offer[0])
				g.advance()
		else:
			fails += 1
			g.record_generated(g.stage, false)
			g.defeated()
			# farm de l'étage précédent jusqu'à pouvoir acheter quelque chose d'utile
			g.retreat()
			for k in 8:
				_spend(g)
				var s2 := BattleSim.new(g.team(), g.stage, seed_v * 104729 + attempts, g.boosts)
				attempts += 1
				s2.run(240.0)
				t_total += s2.time
				t_stage += s2.time
				g.credits += s2.credits
				g.stage_cleared(s2.stars, s2.max_combo, false)
				g.equip_best_all()
				if _affordable(g):
					break
			g.go_to(g.best_stage)
	print("FACTEURS ", facs)
	print("étage ; type ; temps sur l'étage (s) ; défaites ; niveau moyen ; temps cumulé (min) ; vaisseau")
	for r in rows:
		print("%d ; %s ; %.0f ; %d ; %.1f ; %.1f ; %d" % [r.stage, r.type, r.time, r.fails, r.lvl, r.total / 60.0, r.ship])
	print("VAISSEAU niveau %d, salles %s, Pont : %s, crédits %d, éclats %d, coût %s" % [g.ship.level, str(g.ship.rooms), g.ship.upgrade_block(g, "pont"), g.credits, g.shards, str(Ship.upgrade_cost("pont", g.ship.level + 1))])
	print("TOTAL %.1f min de combat jusqu'à l'étage %d" % [t_total / 60.0, g.best_stage - 1])
	if g.gen_tries > 0:
		print("GÉNÉRÉ échecs : %d défaites, %d combats trop longs (> 240 s)" % [real_defeats, timeouts])
		print("GÉNÉRÉ tentatives %d · victoires %.0f %% · difficulté ×%.2f" % [g.gen_tries, 100.0 * g.gen_wins / g.gen_tries, g.inf_diff])
	quit()


## Joueur type : le Pont dès que possible, une salle quand il reste de quoi faire monter les héros.
func _ship(g) -> bool:
	if not g.ship.unlocked:
		return true
	var blk: String = g.ship.upgrade_block(g, "pont")
	if blk == "":
		g.ship.start_upgrade(g, "pont")
	elif blk == "Pas assez de ressources":
		return false
	for r in Ship.ORDER:
		if r == "pont" or g.ship.upgrade_block(g, r) != "":
			continue
		var c: Dictionary = Ship.upgrade_cost(r, g.ship.room_level(r) + 1)
		var pc: Dictionary = Ship.upgrade_cost("pont", mini(Ship.MAX_LEVEL, g.ship.level + 1))
		if g.credits > 2.0 * float(c.credits) and g.shards - int(c.shards) >= int(pc.shards):
			g.ship.start_upgrade(g, r)
	return true


func _affordable(g) -> bool:
	for id in g.squad_ids():
		if g.can_afford_evolve(id) or g.can_level(id):
			return true
	return false


func _spend(g) -> void:
	var guard := 0
	while guard < 200:
		guard += 1
		var did := false
		for id in g.squad_ids():
			if g.can_afford_evolve(id):
				g.evolve(id)
				did = true
		var b: String = g.best_buy()
		if b != "" and g.can_level(b):
			g.level_up(b)
			did = true
		if not did:
			break


func _avg(g) -> float:
	var t := 0.0
	var ids: Array = g.squad_ids()
	for id in ids:
		t += float(g.levels[id])
	return t / float(maxi(1, ids.size()))
