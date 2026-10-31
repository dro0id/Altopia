extends SceneTree
## Tests de logique (lancer : godot --headless --path . -s tests/run_tests.gd). Code de sortie 0 = tout est OK.

const Data = preload("res://scripts/data.gd")

var _failures := 0
var _g: Node


func _initialize() -> void:
	_g = root.get_node_or_null("Game")
	if _g == null:
		printerr("Autoload Game introuvable")
		quit(1)
		return
	for t in get_method_list():
		if str(t.name).begins_with("test_"):
			var before := _failures
			_g.reset()
			_g.save_path = "user://test_save.json"
			call(t.name)
			print(("ok   " if _failures == before else "FAIL ") + str(t.name))
	if _failures > 0:
		printerr("%d échec(s)" % _failures)
	else:
		print("Tous les tests passent.")
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL ", msg)


func _team(level: int) -> Array:
	var out: Array = []
	for id in Data.HERO_ORDER:
		out.append({"id": id, "level": level})
	return out


func test_data_is_consistent() -> void:
	_check(Data.HERO_ORDER.size() == 5, "cinq héros")
	for id in Data.HERO_ORDER:
		var h: Dictionary = Data.HEROES[id]
		_check(h.hp > 0.0 and h.atk > 0.0 and h.interval > 0.0, "%s : statistiques valides" % id)
		_check(["shield", "volley", "pierce", "repair", "gravity"].has(h.skill.kind), "%s : pouvoir connu" % id)
		_check(h.look.has("suit") and h.look.has("weapon"), "%s : apparence définie" % id)
	_check(Data.level_cost(2) > Data.level_cost(1) and Data.hero_mult(5) > Data.hero_mult(4), "coûts et puissance croissent")


func test_sim_is_deterministic() -> void:
	var a := BattleSim.new(_team(3), 4, 7)
	var b := BattleSim.new(_team(3), 4, 7)
	a.run(300.0)
	b.run(300.0)
	_check(a.state == b.state and is_equal_approx(a.time, b.time) and is_equal_approx(a.credits, b.credits), "même graine, même combat")


func test_early_stages_are_winnable_and_late_ones_are_not() -> void:
	_check(BattleSim.new(_team(1), 1, 1).run(300.0) == "clear", "le secteur 1 se gagne au niveau 1")
	_check(BattleSim.new(_team(1), 3, 1).run(300.0) == "clear", "le secteur 3 se gagne au niveau 1")
	_check(BattleSim.new(_team(1), 30, 1).run(300.0) == "defeat", "le secteur 30 est perdu au niveau 1")
	_check(BattleSim.new(_team(30), 30, 1).run(300.0) == "clear", "le secteur 30 se gagne au niveau 30")


func test_progression_needs_levels() -> void:
	# la montée de niveau doit repousser le mur : le niveau 8 passe un secteur que le niveau 1 perd
	_check(BattleSim.new(_team(1), 15, 1).run(300.0) == "defeat", "secteur 15 perdu au niveau 1")
	_check(BattleSim.new(_team(9), 15, 1).run(300.0) == "clear", "secteur 15 gagné au niveau 9")


func _boss_kinds(stage: int) -> Array:
	var sim := BattleSim.new(_team(1), stage, 1)
	sim.wave = 2
	sim._spawn_wave()
	var out: Array = []
	for u in sim.enemies():
		if u.boss:
			out.append(u.kind)
	return out


func test_boss_rules() -> void:
	_check(Data.boss_type(5) == "mini" and Data.boss_type(15) == "mini", "mini-boss aux étages 5 et 15")
	_check(Data.boss_type(10) == "big" and Data.boss_type(20) == "big", "gros boss aux étages 10 et 20")
	_check(Data.boss_type(4) == "" and Data.boss_type(9) == "", "pas de boss ailleurs")
	_check(_boss_kinds(5) == ["foreur"], "le Foreur éclaté arrive à l'étage 5")
	_check(_boss_kinds(10) == ["titan"], "le Gardien de verre arrive à l'étage 10")
	_check(_boss_kinds(4).is_empty(), "pas de boss à l'étage 4")


func test_big_boss_phase_two() -> void:
	var sim := BattleSim.new(_team(12), 10, 1)
	sim.wave = 2
	sim._spawn_wave()
	var boss: BattleSim.Unit
	for u in sim.enemies():
		if u.boss:
			boss = u
	var atk_before := boss.atk
	boss.hp = boss.max_hp * 0.4
	sim._apply_hit({"dst": boss, "dmg": 1.0, "fx": ""})
	_check(boss.phase2 and boss.atk > atk_before, "le gros boss passe en phase 2 sous 50 % de PV")
	var mites := 0
	for u in sim.enemies():
		if u.kind == "mite":
			mites += 1
	_check(mites >= 2, "deux mites arrivent en renfort")


func test_stars_and_warning() -> void:
	_check(Data.stars_for(0) == 3 and Data.stars_for(1) == 2 and Data.stars_for(3) == 1, "étoiles selon les héros tombés")
	var sim := BattleSim.new(_team(30), 1, 1)
	_check(sim.run(300.0) == "clear" and sim.stars == 3, "victoire facile : 3 étoiles")
	var boss_sim := BattleSim.new(_team(8), 10, 1)
	var warned := false
	while boss_sim.state == "fighting" and boss_sim.time < 300.0:
		boss_sim.step(0.05)
		for e in boss_sim.events:
			warned = warned or e.type == "warn"
		boss_sim.events.clear()
	_check(warned, "le boss avertit avant son coup puissant")


func test_chests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pity := {"leg": 0, "ult": 0}
	_check(Data.roll_chest(3, 2, rng, pity) == "commun" and Data.roll_chest(3, 3, rng, pity) == "normal", "commun puis normal selon les étoiles")
	_check(Data.roll_chest(5, 3, rng, pity) == "rare", "le mini-boss donne un coffre rare")
	# garanties : au 2e gros boss en 3 étoiles on a au moins un légendaire
	var got_leg_by_two := false
	for trial in 200:
		var pt := {"leg": 0, "ult": 0}
		var a := Data.roll_chest(10, 3, rng, pt)
		var b := Data.roll_chest(10, 3, rng, pt)
		got_leg_by_two = a in ["legendaire", "ultime"] or b in ["legendaire", "ultime"]
		if not got_leg_by_two:
			break
	_check(got_leg_by_two, "légendaire garanti au plus tard au 2e gros boss en 3 étoiles")
	var pt2 := {"leg": 0, "ult": 9}
	_check(Data.roll_chest(10, 3, rng, pt2) == "ultime" and pt2.ult == 0, "ultime garanti au 10e gros boss en 3 étoiles")
	var r3 := Data.chest_rewards(10, "legendaire")
	_check(r3.credits > Data.chest_rewards(10, "commun").credits and r3.shards == 40, "plus rare, plus généreux")
	_g.credits = 0.0
	_g.stage = 1
	var chest: Dictionary = _g.stage_cleared(3)
	_check(chest.rarity == "normal" and _g.credits > 0.0 and _g.shards > 0, "un étage vaincu en 3 étoiles donne un coffre normal")
	_check(_g.best_stage == 2 and _g.stars[1] == 3, "l'étage suivant se débloque et les étoiles sont gardées")


func test_free_chest() -> void:
	_g.last_free_chest = 0
	_check(_g.free_chest_ready(), "le coffre gratuit est prêt au départ")
	var c: Dictionary = _g.claim_free_chest()
	_check(not c.is_empty() and c.rarity in ["commun", "normal"], "le coffre gratuit est commun ou normal")
	_check(not _g.free_chest_ready() and _g.free_chest_remaining() > 3.9 * 3600.0, "puis 4 h d'attente")


func test_recommended_power_grows() -> void:
	_check(Data.recommended_power(20) > Data.recommended_power(10) and Data.recommended_power(10) > Data.recommended_power(5), "la puissance recommandée croît")
	_check(Data.recommended_level(10) > Data.recommended_level(9) + 3, "un gros boss demande nettement plus")


func test_manual_skills_work() -> void:
	var s := BattleSim.new(_team(8), 12, 1)
	s.auto_cast = false
	for i in 100:
		s.step(0.05)
	_check(s.cast(1), "Salve de missiles lancée à la main")
	_check(not s.cast(1), "…et en recharge ensuite")
	var before := 0.0
	for e in s.enemies():
		before += e.hp
	for i in 20:
		s.step(0.05)
	var after := 0.0
	for e in s.enemies():
		after += e.hp
	_check(after < before or s.enemies().is_empty(), "la salve blesse les ennemis")


func test_level_up_costs_credits() -> void:
	_check(not _g.level_up("kai"), "pas de niveau sans crédits")
	_g.credits = 1000.0
	var c: float = _g.credits
	_check(_g.level_up("kai") and _g.levels["kai"] == 2 and _g.credits == c - Data.level_cost(1), "monter Kaï coûte le prix annoncé")


func test_save_and_offline() -> void:
	_g.credits = 123.0
	_g.levels["zyra"] = 6
	_g.best_stage = 9
	_g.stage = 7
	_g.stars[3] = 2
	_g.shards = 11
	_g.pity = {"leg": 1, "ult": 4}
	_g.tutorial_done = true
	_g.save_game()
	_g.reset()
	_check(_g.load_game(), "la sauvegarde se recharge")
	_check(_g.levels["zyra"] == 6 and _g.best_stage == 9 and _g.stage == 7 and _g.credits >= 123.0, "niveaux, étage et crédits conservés")
	_check(_g.stars[3] == 2 and _g.shards == 11 and _g.pity.ult == 4 and _g.tutorial_done, "étoiles, éclats, garanties et tutoriel conservés")
	var off: Dictionary = _g.compute_offline(3600.0 * 100.0)
	_check(is_equal_approx(off.seconds, Data.OFFLINE_CAP_HOURS * 3600.0), "gains hors ligne plafonnés")
	_check(off.credits > 0.0, "des crédits hors ligne")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
