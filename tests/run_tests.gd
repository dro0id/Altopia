extends SceneTree
## Tests de la logique du jeu. Lancer :
##   godot --headless --path . -s tests/run_tests.gd
## Code de sortie 0 = tout est OK, 1 = au moins un échec.

var _failures := 0
var _gs: Node


func _initialize() -> void:
	_gs = root.get_node_or_null("GameState")
	if _gs == null:
		printerr("Autoload GameState introuvable")
		quit(1)
		return
	for t in get_method_list():
		if str(t.name).begins_with("test_"):
			var before := _failures
			_reset()
			call(t.name)
			print(("ok   " if _failures == before else "FAIL ") + str(t.name))
	if _failures > 0:
		printerr("%d échec(s)" % _failures)
	else:
		print("Tous les tests passent.")
	quit(1 if _failures > 0 else 0)


func _reset() -> void:
	_gs.reset()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL ", msg)


func _give(amounts: Dictionary) -> void:
	for id in amounts:
		_gs.add_res(id, amounts[id])


func test_no_crew_no_income() -> void:
	_check(_gs.credits_per_sec() == 0.0, "sans équipage, revenu = 0")


func test_buy_crew_requires_credits() -> void:
	_check(not _gs.buy_crew("pilot"), "achat refusé sans crédits")
	_give({"credits": 10.0})
	_check(_gs.buy_crew("pilot"), "achat accepté avec crédits")
	_check(_gs.crew_levels["pilot"] == 1 and _gs.res["credits"] == 0.0, "niveau +1 et crédits débités")


func test_crew_cost_grows() -> void:
	var c0: float = _gs.crew_cost("pilot")
	_gs.crew_levels["pilot"] = 5
	_check(_gs.crew_cost("pilot") > c0, "le coût augmente avec le niveau")


func test_synergy() -> void:
	_gs.crew_levels["pilot"] = 1
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.0), "un seul rôle : pas de synergie")
	_gs.crew_levels["engineer"] = 1
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.1), "une paire : x1.1")
	_gs.crew_levels["scientist"] = 1
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.0 + 0.3 + 0.25), "équipage complet")


func test_launch_needs_role_and_unlock() -> void:
	_check(not _gs.launch(0, "asteroids"), "pas de pilote : lancement refusé")
	_gs.crew_levels["pilot"] = 1
	_check(_gs.launch(0, "asteroids"), "pilote recruté : lancement OK")
	_check(not _gs.launch(0, "asteroids"), "vaisseau déjà occupé")
	_gs.crew_levels["engineer"] = 1
	_check(not _gs.launch(1, "star"), "2e baie verrouillée")
	_gs.recall(0)
	_check(not _gs.launch(0, "star"), "étoile verrouillée (données insuffisantes)")
	_give({"data": 30.0})
	_check(_gs.launch(0, "star"), "étoile débloquée avec 25+ données")


func test_expedition_completes_and_pays() -> void:
	_gs.crew_levels["pilot"] = 1
	_gs.slots[0].auto = false
	_gs.launch(0, "asteroids")
	var expected: Dictionary = _gs.rewards_of("asteroids")
	var minerals_before: float = _gs.res["minerals"]
	_gs._advance_expeditions(5.0)
	_check(_gs.slots[0].dest != "", "pas fini après 5 s")
	_gs._advance_expeditions(100.0)
	_check(_gs.slots[0].dest == "", "fini : vaisseau libre (auto désactivé)")
	_check(is_equal_approx(_gs.res["minerals"] - minerals_before, expected["minerals"]), "minerais crédités")
	_check(_gs.expeditions_done == 1, "compteur d'expéditions")


func test_auto_repeat_offline() -> void:
	_gs.crew_levels["pilot"] = 1
	_gs.launch(0, "asteroids")
	var d: float = _gs.duration_of("asteroids")
	_gs._advance_expeditions(d * 10.0 + 0.5)
	_check(_gs.expeditions_done == 10, "10 cycles auto en une longue absence (obtenu %d)" % _gs.expeditions_done)
	_check(_gs.slots[0].dest == "asteroids", "toujours en expédition")


func test_upgrades() -> void:
	_check(not _gs.buy_upgrade("laser"), "amélioration refusée sans ressources")
	_give({"credits": 1000.0, "minerals": 100.0, "energy": 100.0})
	var base: float = _gs.rewards_of("asteroids").get("minerals", 5.0)
	_gs.crew_levels["pilot"] = 1
	var before: float = _gs.rewards_of("asteroids")["minerals"]
	_check(_gs.buy_upgrade("laser"), "laser acheté")
	_check(_gs.rewards_of("asteroids")["minerals"] > before, "le laser augmente les minerais")
	_check(_gs.buy_upgrade("docks") and _gs.slot_count() == 2, "baie d'amarrage : 2 vaisseaux")
	_check(not _gs.buy_upgrade("docks"), "baie au maximum")
	var d0: float = _gs.duration_of("asteroids")
	_gs.buy_upgrade("engines")
	_check(_gs.duration_of("asteroids") < d0, "les moteurs réduisent la durée")


func test_data_unlocks_via_total() -> void:
	_check(not _gs.is_unlocked("planet"), "planète verrouillée au départ")
	_give({"data": 100.0})
	_check(_gs.is_unlocked("planet"), "planète débloquée à 100 données cumulées")
	_gs.res["data"] = 0.0
	_check(_gs.is_unlocked("planet"), "reste débloquée même après dépense")


func test_tick_produces_resources() -> void:
	_gs.crew_levels["scientist"] = 2
	_gs.tick(10.0)
	_check(_gs.res["credits"] > 0.0 and _gs.res["data"] > 0.0, "le temps produit crédits et données")
