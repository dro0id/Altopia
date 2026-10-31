extends SceneTree
## Simulation d'équilibrage : un joueur type monte les étages et dépense ses crédits (godot --headless --path . -s tools/balance.gd -- [étages max] [seed]).
## Sortie : pour chaque étage atteint, temps de combat cumulé, niveau moyen des héros, puissance, puissance recommandée, victoires/défaites.

const Data = preload("res://scripts/data.gd")


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var max_stage := int(a[0]) if a.size() > 0 else 40
	var seed_v := int(a[1]) if a.size() > 1 else 1
	var levels := {}
	for id in Data.HERO_ORDER:
		levels[id] = 1
	var credits := 0.0
	var stage := 1
	var best := 1
	var total_time := 0.0
	var attempts := 0
	var farm_time := 0.0
	var rows: Array = []
	var stage_time := 0.0
	var fails := 0
	while best <= max_stage and total_time < 3600.0 * 6.0:
		# dépense tous les crédits dans le meilleur achat
		while true:
			var pick := _best_buy(levels)
			var cost := Data.level_cost(int(levels[pick]))
			if credits < cost:
				break
			credits -= cost
			levels[pick] = int(levels[pick]) + 1
		var team: Array = []
		for id in Data.HERO_ORDER:
			team.append({"id": id, "level": int(levels[id])})
		var sim := BattleSim.new(team, stage, seed_v + attempts)
		var res := sim.run(240.0)
		attempts += 1
		total_time += sim.time
		stage_time += sim.time
		credits += sim.credits
		if res == "clear":
			# coffre : on compte seulement les crédits
			credits += Data.chest_rewards(stage, Data.roll_chest(stage, sim.stars, RandomNumberGenerator.new(), {})).credits
			if stage >= best:
				rows.append({"stage": stage, "time": total_time, "stage_time": stage_time, "power": Data.team_power(levels), "reco": Data.recommended_power(stage), "fails": fails, "stars": sim.stars, "avg": _avg(levels)})
				best = stage + 1
				stage_time = 0.0
				fails = 0
			stage = best
		else:
			fails += 1
			# défaite : on farme l'étage précédent jusqu'à pouvoir retenter
			stage = maxi(1, best - 1)
			var farmed := 0
			while farmed < 12:
				var t2: Array = []
				for id in Data.HERO_ORDER:
					t2.append({"id": id, "level": int(levels[id])})
				var s2 := BattleSim.new(t2, stage, seed_v + attempts)
				s2.run(240.0)
				attempts += 1
				total_time += s2.time
				stage_time += s2.time
				farm_time += s2.time
				credits += s2.credits + Data.chest_rewards(stage, "commun").credits
				farmed += 1
				var pick2 := _best_buy(levels)
				if credits >= Data.level_cost(int(levels[pick2])) * 3.0:
					break
			stage = best
	print("étage ; temps cumulé (min) ; temps sur l'étage (s) ; niveau moyen ; puissance ; reco ; défaites ; étoiles")
	for r in rows:
		print("%d ; %.1f ; %.0f ; %.1f ; %d ; %d ; %d ; %d" % [r.stage, r.time / 60.0, r.stage_time, r.avg, r.power, r.reco, r.fails, r.stars])
	print("TOTAL %.1f min, dont %.1f min de farm" % [total_time / 60.0, farm_time / 60.0])
	quit()


func _best_buy(levels: Dictionary) -> String:
	var best := ""
	var best_ratio := -1.0
	for id in Data.HERO_ORDER:
		var h: Dictionary = Data.HEROES[id]
		var lv := int(levels[id])
		var gain: float = (h.hp * 0.25 + h.atk * 6.0 + h.def * 3.0) * (Data.hero_mult(lv + 1) - Data.hero_mult(lv))
		var ratio: float = gain / float(Data.level_cost(lv))
		if ratio > best_ratio:
			best_ratio = ratio
			best = id
	return best


func _avg(levels: Dictionary) -> float:
	var t := 0.0
	for id in levels:
		t += float(levels[id])
	return t / float(levels.size())
