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
	_check(BattleSim.new(_team(20), 30, 1).run(300.0) == "clear", "le secteur 30 se gagne au niveau 20")


func test_progression_needs_levels() -> void:
	# la montée de niveau doit repousser le mur : le niveau 8 passe un secteur que le niveau 1 perd
	_check(BattleSim.new(_team(1), 15, 1).run(300.0) == "defeat", "secteur 15 perdu au niveau 1")
	_check(BattleSim.new(_team(8), 15, 1).run(300.0) == "clear", "secteur 15 gagné au niveau 8")


func test_boss_every_fifth_stage() -> void:
	var s := BattleSim.new(_team(1), 5, 1)
	s.wave = 2
	s._spawn_wave()
	var has_boss := false
	for u in s.enemies():
		has_boss = has_boss or u.boss
	_check(has_boss, "un boss à la dernière vague du secteur 5")
	var s4 := BattleSim.new(_team(1), 4, 1)
	s4.wave = 2
	s4._spawn_wave()
	var boss4 := false
	for u in s4.enemies():
		boss4 = boss4 or u.boss
	_check(not boss4, "pas de boss au secteur 4")


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
	_g.save_game()
	_g.reset()
	_check(_g.load_game(), "la sauvegarde se recharge")
	_check(_g.levels["zyra"] == 6 and _g.best_stage == 9 and _g.stage == 7 and _g.credits >= 123.0, "niveaux, secteur et crédits conservés")
	var off: Dictionary = _g.compute_offline(3600.0 * 100.0)
	_check(is_equal_approx(off.seconds, Data.OFFLINE_CAP_HOURS * 3600.0), "gains hors ligne plafonnés")
	_check(off.credits > 0.0, "des crédits hors ligne")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
