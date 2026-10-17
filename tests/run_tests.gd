extends SceneTree
## Tests de la logique du jeu. Lancer :
##   godot --headless --path . -s tests/run_tests.gd
## Code de sortie 0 = tout est OK, 1 = au moins un échec.

const Data = preload("res://scripts/game_data.gd")
const Battle = preload("res://scripts/battle.gd")

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
	_gs.rng.seed = 12345


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL ", msg)


func _give(amounts: Dictionary) -> void:
	for id in amounts:
		_gs.add_res(id, amounts[id])


func _squad(slot_i: int, ids: Array) -> void:
	for k in ids.size():
		_gs.set_squad_member(slot_i, k, ids[k])


func test_hero_stats_scale() -> void:
	var s1: Dictionary = Data.hero_stats("rex", 1, 0)
	var s2: Dictionary = Data.hero_stats("rex", 5, 0)
	var s3: Dictionary = Data.hero_stats("rex", 1, 2)
	_check(is_equal_approx(s1.atk, 14.0), "rex niveau 1 : atk de base")
	_check(s2.atk > s1.atk and s3.atk > s1.atk, "niveau et étoiles augmentent les stats")


func test_battle_deterministic_and_fair() -> void:
	var a := [Battle.make_unit("A", 100, 20, 5, 10)]
	var e := [Battle.make_unit("E", 40, 5, 0, 5)]
	var r1: Dictionary = Battle.simulate(a, e)
	var r2: Dictionary = Battle.simulate(a, e)
	_check(r1.win and r1.rounds == r2.rounds, "combat déterministe et gagné")
	var weak := [Battle.make_unit("A", 20, 3, 0, 5)]
	var strong := [Battle.make_unit("E", 500, 30, 10, 5)]
	_check(not Battle.simulate(weak, strong).win, "héros trop faible : défaite")


func test_new_game_starters() -> void:
	_gs.new_game()
	_check(_gs.heroes.has("rex") and _gs.heroes.has("bolt"), "héros de départ")
	_check(_gs.res["credits"] == Data.START_CREDITS, "crédits de départ")


func test_new_game_is_playable_immediately() -> void:
	_gs.new_game()
	_check(_gs.squad_ids(0).has("rex"), "escouade composée dès le début")
	_check(_gs.launch_block_reason("asteroids", 0) == "", "première expédition lançable sans rien faire")
	_check(_gs.launch(0, "asteroids"), "lancement des astéroïdes OK")
	_check(_gs.data_per_sec() > 0.0, "des données arrivent même sans scientifique")


func test_data_unlocks_star_in_reasonable_time() -> void:
	_gs.new_game()
	_gs.launch(0, "asteroids")
	var elapsed := 0.0
	while not _gs.is_unlocked("star") and elapsed < 1800.0:
		_gs.tick(1.0)
		elapsed += 1.0
	_check(elapsed < 360.0, "l'étoile se débloque en moins de 6 minutes (obtenu %d s)" % int(elapsed))


func test_auto_squad_and_autoplace() -> void:
	_gs.give_hero("rex")
	_gs.give_hero("bolt")
	_gs.give_hero("lumi")
	_gs.give_hero("nova")
	_gs.auto_squad(0)
	var ids: Array = _gs.squad_ids(0)
	_check(ids.size() == 3, "3 héros choisis")
	var classes := {}
	for id in ids:
		classes[Data.HEROES[id]["class"]] = true
	_check(classes.size() == 3, "une classe de chaque d'abord")
	_check(ids.has("nova") == false or ids.has("rex") == false, "le plus fort d'une classe est préféré")
	_gs.reset()
	_give({"credits": 100000.0})
	for i in 5:
		_gs.recruit()
	_check(_gs.squad_ids(0).size() > 0, "un héros recruté rejoint l'escouade libre")


func test_recruit_cost_and_pull() -> void:
	_check(_gs.recruit().is_empty(), "recrutement refusé sans crédits")
	_give({"credits": 1000.0})
	var c0: float = _gs.recruit_cost()
	var r: Dictionary = _gs.recruit()
	_check(not r.is_empty() and _gs.heroes.has(r.id), "un héros est recruté")
	_check(_gs.recruit_cost() > c0, "le coût du recrutement augmente")


func test_duplicate_gives_star() -> void:
	_gs.give_hero("rex")
	_give({"credits": 100000.0})
	var star_before := 0
	var got_dup := false
	for i in 40:
		var r: Dictionary = _gs.recruit()
		if r.id == "rex" and not r.new:
			got_dup = true
			break
	_check(got_dup, "un doublon de Rex finit par tomber")
	_check(_gs.heroes["rex"].stars >= 1, "le doublon ajoute une étoile")


func test_rarity_distribution() -> void:
	var counts := {"common": 0, "rare": 0, "epic": 0}
	for i in 600:
		counts[Data.HEROES[_gs._roll_hero()].rarity] += 1
	_check(counts.common > counts.rare and counts.rare > counts.epic, "communs > rares > épiques")
	_check(counts.epic > 0, "des épiques existent")


func test_train_and_xp() -> void:
	_gs.give_hero("rex")
	_check(not _gs.train("rex"), "entraînement refusé sans crédits")
	_give({"credits": 1000.0})
	_check(_gs.train("rex") and _gs.heroes["rex"].level == 2, "entraînement : niveau +1")
	var lv: int = _gs.heroes["rex"].level
	var gained: int = _gs.gain_xp("rex", Data.xp_needed(lv) + 1)
	_check(gained == 1 and _gs.heroes["rex"].level == lv + 1, "assez d'XP : niveau +1")


func test_passive_income_and_synergy() -> void:
	_check(_gs.credits_per_sec() == 0.0, "sans héros, pas de revenu")
	_gs.give_hero("rex")
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.0), "un seul rôle : pas de synergie")
	_gs.give_hero("bolt")
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.1), "une paire : x1.1")
	_gs.give_hero("lumi")
	_check(is_equal_approx(_gs.synergy_multiplier(), 1.0 + 0.3 + 0.25), "équipage complet")
	_gs.tick(10.0)
	_check(_gs.res["credits"] > 0.0 and _gs.res["data"] > 0.0, "le temps produit crédits et données")


func test_squad_rules() -> void:
	_gs.give_hero("rex")
	_gs.give_hero("bolt")
	_check(_gs.set_squad_member(0, 0, "rex"), "rex dans l'escouade")
	_check(_gs.squad_ids(0) == ["rex"], "escouade = [rex]")
	_gs.set_squad_member(1, 0, "rex")
	_check(_gs.hero_slot("rex") == 1 and _gs.squad_ids(0).is_empty(), "un héros ne sert qu'une fois")
	_check(not _gs.set_squad_member(0, 0, "inconnu"), "héros non possédé refusé")


func test_launch_needs_squad_role_unlock() -> void:
	_gs.give_hero("rex")
	_gs.give_hero("bolt")
	_check(not _gs.launch(0, "asteroids"), "sans escouade : refusé")
	_squad(0, ["bolt"])
	_check(not _gs.launch(0, "asteroids"), "sans pilote dans l'escouade : refusé")
	_squad(0, ["rex"])
	_check(_gs.launch(0, "asteroids"), "pilote présent : lancement OK")
	_check(not _gs.launch(0, "asteroids"), "vaisseau déjà occupé")
	_gs.recall(0)
	_squad(0, ["rex", "bolt"])
	_check(not _gs.launch(0, "star"), "étoile verrouillée (données)")
	_give({"data": 30.0})
	_check(_gs.launch(0, "star"), "étoile débloquée")


func test_victory_pays_and_gives_xp() -> void:
	_gs.give_hero("rex", 10)
	_gs.give_hero("bolt", 10)
	_gs.give_hero("lumi", 10)
	_squad(0, ["rex", "bolt", "lumi"])
	_gs.slots[0].auto = false
	_check(_gs.preview_battle("asteroids", 0).win, "escouade forte : victoire prévue")
	_gs.launch(0, "asteroids")
	var xp_before: int = _gs.heroes["rex"].xp
	var minerals_before: float = _gs.res["minerals"]
	var expected: Dictionary = _gs.rewards_of("asteroids", 0)
	_gs._advance_expeditions(500.0)
	_check(_gs.slots[0].dest == "", "fini : vaisseau libre")
	_check(is_equal_approx(_gs.res["minerals"] - minerals_before, expected["minerals"]), "butin complet crédité")
	_check(_gs.heroes["rex"].xp != xp_before or _gs.heroes["rex"].level > 10, "les héros gagnent de l'XP")
	_check(_gs.dest_wins["asteroids"] == 1, "victoire comptée")


func test_defeat_reduces_loot() -> void:
	_gs.give_hero("rex", 1)
	_squad(0, ["rex"])
	_gs.slots[0].auto = false
	_gs.dest_wins["asteroids"] = 200      # ennemis très forts
	_check(not _gs.preview_battle("asteroids", 0).win, "défaite prévue")
	_gs.launch(0, "asteroids")
	var full: Dictionary = _gs.rewards_of("asteroids", 0)
	var minerals_before: float = _gs.res["minerals"]
	_gs._advance_expeditions(500.0)
	var got: float = _gs.res["minerals"] - minerals_before
	_check(is_equal_approx(got, full["minerals"] * Data.LOSS_REWARD), "défaite : butin réduit")
	_check(_gs.heroes["rex"].level == 1 and _gs.dest_wins["asteroids"] == 200, "pas d'XP ni de victoire en cas de défaite")


func test_auto_repeat_offline() -> void:
	_gs.give_hero("rex", 10)
	_gs.give_hero("bolt", 10)
	_squad(0, ["rex", "bolt"])
	_gs.launch(0, "asteroids")
	var d: float = _gs.duration_of("asteroids", 0)
	_gs._advance_expeditions(d * 10.0 + 0.5)
	_check(_gs.expeditions_done == 10, "10 cycles auto en une longue absence (obtenu %d)" % _gs.expeditions_done)
	_check(_gs.slots[0].dest == "asteroids", "toujours en expédition")


func test_upgrades() -> void:
	_gs.give_hero("rex")
	_squad(0, ["rex"])
	_check(not _gs.buy_upgrade("laser"), "amélioration refusée sans ressources")
	_give({"credits": 1000.0, "minerals": 100.0, "energy": 100.0})
	var before: float = _gs.rewards_of("asteroids", 0)["minerals"]
	_check(_gs.buy_upgrade("laser"), "laser acheté")
	_check(_gs.rewards_of("asteroids", 0)["minerals"] > before, "le laser augmente les minerais")
	_check(_gs.buy_upgrade("docks") and _gs.slot_count() == 2, "baie d'amarrage : 2 vaisseaux")
	_check(not _gs.buy_upgrade("docks"), "baie au maximum")
	var d0: float = _gs.duration_of("asteroids", 0)
	_gs.buy_upgrade("engines")
	_check(_gs.duration_of("asteroids", 0) < d0, "les moteurs réduisent la durée")


func test_data_unlocks_via_total() -> void:
	_check(not _gs.is_unlocked("planet"), "planète verrouillée au départ")
	_give({"data": 100.0})
	_check(_gs.is_unlocked("planet"), "planète débloquée à 100 données cumulées")
	_gs.res["data"] = 0.0
	_check(_gs.is_unlocked("planet"), "reste débloquée même après dépense")


func test_save_load_roundtrip() -> void:
	_gs.save_path = "user://test_save.json"
	_gs.new_game()
	_gs.give_hero("nova", 7, 2)
	_squad(0, ["rex", "nova"])
	_gs.launch(0, "asteroids")
	_gs.res["minerals"] = 42.0
	_gs.save_game()
	var snapshot_level: int = _gs.heroes["nova"].level
	_gs.reset()
	_check(_gs.heroes.is_empty(), "état vidé")
	_check(_gs.load_game(), "chargement réussi")
	_check(_gs.heroes.has("nova") and _gs.heroes["nova"].level == snapshot_level and _gs.heroes["nova"].stars == 2, "héros restaurés")
	_check(is_equal_approx(_gs.res["minerals"], 42.0), "ressources restaurées")
	_check(_gs.squad_ids(0) == ["rex", "nova"] and _gs.slots[0].dest == "asteroids", "escouade et expédition restaurées")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	_gs.save_path = _gs.SAVE_PATH
