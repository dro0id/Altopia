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
	_gs.credits = 0.0
	_gs.data = 0.0
	for id in _gs.levels:
		_gs.levels[id] = 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL ", msg)


func test_no_crew_no_income() -> void:
	_check(_gs.credits_per_sec() == 0.0, "sans équipage, revenu = 0")


func test_buy_requires_credits() -> void:
	_gs.buy("pilot")
	_check(_gs.levels["pilot"] == 0, "achat refusé sans crédits")
	_gs.credits = 10.0
	_gs.buy("pilot")
	_check(_gs.levels["pilot"] == 1, "achat accepté avec crédits")
	_check(_gs.credits == 0.0, "crédits débités")


func test_cost_grows() -> void:
	var c0: float = _gs.cost_of("pilot")
	_gs.levels["pilot"] = 5
	_check(_gs.cost_of("pilot") > c0, "le coût augmente avec le niveau")


func test_synergy() -> void:
	_gs.levels["pilot"] = 1
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.0), "un seul rôle : pas de synergie")
	_gs.levels["engineer"] = 1
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.1), "une paire : x1.1")
	_gs.levels["scientist"] = 1
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.0 + 0.3 + 0.25), "équipage complet")
	_check(_gs.is_crew_complete(), "équipage complet détecté")


func test_tick_produces_resources() -> void:
	_gs.levels["scientist"] = 2
	_gs._tick(10.0)
	_check(_gs.credits > 0.0 and _gs.data > 0.0, "le temps produit crédits et données")
