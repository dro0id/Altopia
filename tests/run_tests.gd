extends SceneTree
## Tests de la logique du jeu. Lancer :
##   godot --headless --path . -s tests/run_tests.gd
## Code de sortie 0 = tout est OK, 1 = au moins un échec.

const Data = preload("res://scripts/game_data.gd")
const Battle = preload("res://scripts/battle.gd")
const LiveSim = preload("res://scripts/live_sim.gd")
const DeriveSim = preload("res://scripts/derive_sim.gd")
const RouteSim = preload("res://scripts/route_sim.gd")

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


## Place les cartes données à leurs postes (la classe détermine le poste).
## Place des équipiers au travail dans la Base : Pilote -> Mine, Ingénieur -> Centrale, Scientifique -> Labo.
func _work(ids: Array) -> void:
	for rid in Data.ROOM_ORDER:
		_gs.room_crew[rid] = ""
	var by_class := {"pilot": "mine", "engineer": "centrale", "scientist": "labo"}
	for id in ids:
		_gs.room_crew[by_class[Data.HEROES[id]["class"]]] = id


func _crew(slot_i: int, ids: Array) -> void:
	for id in ids:
		_gs.set_squad_member(slot_i, Data.CREW_ORDER.find(Data.HEROES[id]["class"]), id)


func _item(slot: String, rarity: String, ilvl: int, affixes: Array = []) -> Dictionary:
	var it: Dictionary = _gs.make_item(slot, rarity, ilvl, false)
	it.affixes = affixes
	return it


func test_hero_stats_scale() -> void:
	var s1: Dictionary = Data.hero_stats("rex", 1, 0)
	var s2: Dictionary = Data.hero_stats("rex", 5, 0)
	var s3: Dictionary = Data.hero_stats("rex", 1, 2)
	_check(is_equal_approx(s1.atk, 14.0), "rex niveau 1 : atk de base")
	_check(s2.atk > s1.atk and s3.atk > s1.atk, "niveau et étoiles augmentent les stats")


func test_battle_deterministic_and_events() -> void:
	var a := [Battle.make_unit("A", 100, 20, 5, 10), Battle.make_unit("B", 100, 15, 5, 8)]
	var e := [Battle.make_unit("E1", 40, 5, 0, 5), Battle.make_unit("E2", 40, 5, 0, 4)]
	var r1: Dictionary = Battle.simulate(a, e)
	var r2: Dictionary = Battle.simulate(a, e)
	_check(r1.win and r1.rounds == r2.rounds, "combat déterministe et gagné")
	var hp := {"0:0": 100.0, "0:1": 100.0, "1:0": 40.0, "1:1": 40.0}
	var kos := 0
	for ev in r1.events:
		var key := "%d:%d" % [1 - ev.s, ev.t]
		hp[key] -= ev.d
		if ev.ko:
			kos += 1
			_check(hp[key] <= 0.0, "un K.O. correspond à 0 PV")
	_check(hp["1:0"] <= 0.0 and hp["1:1"] <= 0.0 and kos == 2, "rejouer les événements retrouve le résultat")
	_check(not Battle.simulate([Battle.make_unit("A", 20, 3, 0, 5)], [Battle.make_unit("E", 500, 30, 10, 5)]).win, "trop faible : défaite")


func test_crit_and_lifesteal_in_battle() -> void:
	var foe := [Battle.make_unit("E", 100000, 1, 0, 1)]
	var plain: Dictionary = Battle.simulate([Battle.make_unit("A", 100, 20, 0, 10)], foe)
	var crit: Dictionary = Battle.simulate([Battle.make_unit("A", 100, 20, 0, 10, 0.5, 0.0)], foe)
	_check(crit.events[0].d > plain.events[0].d, "le critique augmente les dégâts moyens")
	var tank := Battle.make_unit("A", 100, 20, 0, 10, 0.0, 0.5)
	tank.hp = 50.0
	var r: Dictionary = Battle.simulate([tank], [Battle.make_unit("E", 100000, 1, 0, 1)])
	_check(r.events[0].h > 0.0, "le vol de vie soigne l'attaquant")
	_check(r.allies[0].hp <= r.allies[0].max_hp, "les PV ne dépassent pas le maximum")


func test_new_game_is_playable_immediately() -> void:
	_gs.new_game()
	_check(_gs.captain.level == 1, "Capitaine niveau 1")
	_check(not _gs.equipped_item("weapon").is_empty() and not _gs.equipped_item("suit").is_empty(), "arme et combinaison de départ")
	_check(_gs.equipped_item("helmet").is_empty(), "le reste de l'équipement est à looter")
	_check(_gs.squad_ids(0).has("rex") and _gs.squad_ids(0).has("bolt"), "équipage placé aux postes")
	_check(_gs.launch_block_reason("asteroids", 0) == "", "première expédition lançable")
	_check(_gs.preview_battle("asteroids", 0).win, "le Capitaine débutant gagne le premier combat")
	_check(_gs.data_per_sec() > 0.0, "des données arrivent sans scientifique")


func test_item_generation_by_rarity() -> void:
	for r in Data.ITEM_RARITY_ORDER:
		var it: Dictionary = _gs.make_item("weapon", r, 10)
		_check(it.affixes.size() == Data.ITEM_RARITY[r].affixes, "%s : %d affixes" % [r, Data.ITEM_RARITY[r].affixes])
		var keys := {}
		for a in it.affixes:
			keys[a.k] = true
			_check(a.v > 0.0, "valeur d'affixe positive")
		_check(keys.size() == it.affixes.size(), "pas deux fois le même affixe")
	var low: Dictionary = _gs.item_stats(_item("weapon", "common", 1))
	var high: Dictionary = _gs.item_stats(_item("weapon", "common", 20))
	var epic: Dictionary = _gs.item_stats(_item("weapon", "epic", 1))
	_check(high.atk > low.atk and epic.atk > low.atk, "le niveau d'objet et la rareté augmentent les stats")
	_check(_gs.make_item("suit", "legendary", 5).name.length() > 10, "un légendaire a un nom propre")


func test_affixes_change_captain_stats() -> void:
	_gs.new_game()
	var before: Dictionary = _gs.captain_stats(0)
	var it := _item("helmet", "rare", 10, [{"k": "atk_pct", "v": 20.0}, {"k": "crit", "v": 10.0}])
	_gs.add_item(it)
	_gs.equip(it.id)
	var after: Dictionary = _gs.captain_stats(0)
	_check(after.atk > before.atk * 1.15, "+20 %% ATQ appliqué (%d -> %d)" % [before.atk, after.atk])
	_check(is_equal_approx(after.crit, 0.10), "critique 10 %")
	var vs := _item("boots", "rare", 5, [{"k": "spd", "v": 4.0}, {"k": "lifesteal", "v": 5.0}])
	_gs.add_item(vs)
	_gs.equip(vs.id)
	var after2: Dictionary = _gs.captain_stats(0)
	_check(after2.spd > after.spd + 3.9 and is_equal_approx(after2.lifesteal, 0.05), "vitesse et vol de vie")


func test_equip_compare_and_auto_equip() -> void:
	_gs.new_game()
	var weak: Dictionary = _gs.equipped_item("weapon")
	var strong: Dictionary = _item("weapon", "epic", 12, [{"k": "atk_pct", "v": 8.0}])
	_gs.add_item(strong)
	_check(_gs.power_delta(strong) > 0.0, "l'objet fort est une amélioration")
	_check(_gs.power_delta(weak) < _gs.power_delta(strong), "comparaison cohérente")
	_check(_gs.equip(strong.id) and _gs.equipped_item("weapon").id == strong.id, "équiper")
	_gs.equip(weak.id)
	_gs.auto_equip()
	_check(_gs.equipped["weapon"] == strong.id, "auto-équipement : le plus puissant")
	_gs.unequip("weapon")
	_check(_gs.equipped_item("weapon").is_empty(), "retrait")


func test_scrap_recycle_and_cap() -> void:
	_gs.new_game()
	var extra: Dictionary = _item("module", "common", 1)
	_gs.add_item(extra)
	var credits_before: float = _gs.res["credits"]
	_check(_gs.scrap(extra.id) and _gs.res["credits"] > credits_before, "recyclage = crédits")
	_check(not _gs.scrap(_gs.equipped["weapon"]), "un objet équipé ne se recycle pas")
	var junk: Dictionary = _item("weapon", "common", 1)
	var good: Dictionary = _item("weapon", "epic", 15, [{"k": "atk_pct", "v": 9.0}])
	_gs.add_item(junk)
	_gs.add_item(good)
	_gs.equip(good.id)
	var gained: float = _gs.recycle_useless()
	_check(gained > 0.0 and _gs.item_by_id(junk.id).is_empty() and not _gs.item_by_id(good.id).is_empty(), "recycler l'inutile garde l'équipé")
	for i in Data.INVENTORY_MAX + 20:
		_gs.add_item(_item("suit", "common", 1))
	_check(_gs.items.size() <= Data.INVENTORY_MAX, "inventaire plafonné")
	for slot in ["weapon", "suit"]:
		_check(not _gs.equipped_item(slot).is_empty(), "les objets équipés survivent au plafond (%s)" % slot)


func test_auto_recycle_on_drop() -> void:
	_gs.new_game()
	_gs.auto_recycle = 0
	var credits_before: float = _gs.res["credits"]
	var junk: Dictionary = _item("weapon", "common", 1)
	_check(_gs._receive(junk).is_empty() and _gs.res["credits"] > credits_before, "un commun inutile est recyclé tout de suite")
	var upgrade: Dictionary = _item("helmet", "common", 3)
	_check(not _gs._receive(upgrade).is_empty(), "un objet pour un emplacement vide est gardé")
	var rare: Dictionary = _item("boots", "rare", 3, [{"k": "spd", "v": 2.0}])
	_check(not _gs._receive(rare).is_empty(), "un rare est gardé quand le réglage est « communs »")
	_gs.auto_recycle = -1
	_check(not _gs._receive(_item("weapon", "common", 1)).is_empty(), "recyclage auto désactivé : tout est gardé")
	_gs.auto_recycle = Data.AUTO_RECYCLE_MAX
	_gs.cycle_auto_recycle()
	_check(_gs.auto_recycle == -1, "le réglage fait le tour")


func test_drops_distribution() -> void:
	_gs.new_game()
	_gs.auto_recycle = -1
	var ranks := {}
	for i in 4000:
		var it: Dictionary = _gs.roll_afk_drop()
		if not it.is_empty():
			ranks[it.rarity] = ranks.get(it.rarity, 0) + 1
	_check(ranks.get("common", 0) > ranks.get("uncommon", 0) and ranks.get("uncommon", 0) > ranks.get("rare", 0), "communs > peu communs > rares")
	_check(ranks.has("epic"), "des épiques tombent")


func test_recruit_cost_and_pull() -> void:
	_check(_gs.recruit().is_empty(), "recrutement refusé sans crédits")
	_give({"credits": 1000.0})
	var c0: float = _gs.recruit_cost()
	var r: Dictionary = _gs.recruit()
	_check(not r.is_empty() and _gs.heroes.has(r.id), "une carte est recrutée")
	_check(_gs.recruit_cost() > c0, "le coût augmente")


func test_duplicate_gives_star() -> void:
	_gs.give_hero("rex")
	_give({"credits": 100000.0})
	var got_dup := false
	for i in 40:
		var r: Dictionary = _gs.recruit()
		if r.id == "rex" and not r.new:
			got_dup = true
			break
	_check(got_dup and _gs.heroes["rex"].stars >= 1, "un doublon ajoute une étoile")


func test_rarity_distribution() -> void:
	var counts := {"common": 0, "rare": 0, "epic": 0}
	for i in 600:
		counts[Data.HEROES[_gs._roll_hero()].rarity] += 1
	_check(counts.common > counts.rare and counts.rare > counts.epic and counts.epic > 0, "communs > rares > épiques")


func test_train_captain_and_crew() -> void:
	_gs.give_hero("rex")
	_check(not _gs.train("rex") and not _gs.train_captain(), "entraînement refusé sans crédits")
	_give({"credits": 5000.0})
	_check(_gs.train("rex") and _gs.heroes["rex"].level == 2, "carte : niveau +1")
	_check(_gs.train_captain() and _gs.captain.level == 2, "Capitaine : niveau +1")
	var lv: int = _gs.captain.level
	_check(_gs.gain_captain_xp(Data.captain_xp_needed(lv) + 1) == 1 and _gs.captain.level == lv + 1, "assez d'XP : niveau +1")


func test_look_cycle() -> void:
	var before: int = _gs.captain.look.suit
	_gs.cycle_look("suit")
	_check(_gs.captain.look.suit == (before + 1) % Data.LOOK_SUITS.size(), "la combinaison change")
	for i in 5:
		_gs.cycle_look("style")
	_check(_gs.captain.look.style >= 0 and _gs.captain.look.style < Data.LOOK_STYLES, "la coupe reste valide")


func test_crew_produces_only_when_working_in_a_room() -> void:
	_gs.give_hero("rex", 5)
	_gs.give_hero("bolt", 5)
	_gs.give_hero("lumi", 5)
	var idle: Dictionary = _gs.production_per_sec()
	_check(is_equal_approx(idle.minerals, 0.0) and is_equal_approx(idle.energy, 0.0) and idle.credits == 0.0, "sans salle, l'équipage ne produit rien")
	_work(["rex"])
	var one: Dictionary = _gs.production_per_sec()
	_check(one.minerals > 0.0 and is_equal_approx(one.energy, 0.0) and one.credits > 0.0, "à la Mine : minerais et crédits")
	_work(["rex", "bolt", "lumi"])
	var all: Dictionary = _gs.production_per_sec()
	_check(all.energy > 0.0 and all.data > Data.BASE_DATA_RATE, "la Centrale produit de l'énergie, le Labo des données")
	_check(all.minerals > one.minerals, "la synergie des 3 classes augmente la production")
	var before: float = _gs.res["minerals"]
	_gs.tick(3600.0)
	_check(_gs.res["minerals"] - before > 100.0, "une heure de production")


func test_production_scales_with_level_rarity_stars() -> void:
	_gs.give_hero("rex", 1)
	_gs.give_hero("nova", 1, 2)
	_work(["rex"])
	var p1: float = _gs.production_per_sec().minerals
	_work(["nova"])
	_check(_gs.production_per_sec().minerals > p1 * 1.2, "rare + étoiles produisent plus qu'un commun, même face à un spécialiste")
	_gs.heroes["nova"].level = 10
	_check(_gs.production_per_sec().minerals > p1 * 5.0, "le niveau multiplie la production")


func test_offline_efficiency_and_cap() -> void:
	_check(is_equal_approx(_gs.offline_efficiency(), 0.5), "rendement hors ligne : 50 %")
	_check(is_equal_approx(_gs.offline_cap_seconds(), Data.OFFLINE_BASE_HOURS * 3600.0), "durée de base hors ligne")
	_gs.give_hero("rex", 10)
	_gs.give_hero("bolt", 10)
	_work(["rex", "bolt"])
	_check(is_equal_approx(_gs.offline_efficiency(), 0.5), "le rendement ne dépend plus de l'équipage")
	_check(_gs.offline_cap_seconds() > Data.OFFLINE_BASE_HOURS * 3600.0, "les Ingénieurs allongent la durée hors ligne")
	_gs.give_hero("lumi", 200)
	_work(["lumi"])
	_check(_gs.offline_cap_seconds() <= Data.OFFLINE_MAX_HOURS * 3600.0, "plafond de durée respecté")
	_gs.crystals = 200
	_check(_gs.buy_premium("offline_boost") and is_equal_approx(_gs.offline_efficiency(), 0.7), "200 Cristaux : rendement hors ligne 70 %")


func test_simulate_offline_uses_efficiency_and_cap() -> void:
	_gs.new_game()
	_gs.captain.level = 30
	_gs.launch(0, "asteroids")
	var cap: float = _gs.offline_cap_seconds()
	var r: Dictionary = _gs.simulate_offline(cap * 10.0)
	_check(is_equal_approx(r.seconds, cap), "la durée est plafonnée")
	_check(r.gains.minerals > 0.0 and r.gains.credits > 0.0, "le travail aux postes rapporte hors ligne")
	_check(_gs.slots[0].dest == "asteroids", "l'expédition est en pause, pas perdue")
	# même durée, rendement plus bas qu'en ligne
	var a := _fresh_offline_minerals(1.0)
	var b := _fresh_offline_minerals(0.5)
	_check(b < a * 0.6 and b > a * 0.4, "le rendement hors ligne réduit les gains (%d vs %d)" % [a, b])


func _fresh_offline_minerals(scale: float) -> float:
	_gs.new_game()
	_gs.captain.level = 30
	_gs.launch(0, "asteroids")
	_gs._gain_scale = scale
	var before: float = _gs.res["minerals"]
	_gs.tick(600.0)
	_gs._gain_scale = 1.0
	return _gs.res["minerals"] - before


func test_xp_credits_drop_affixes() -> void:
	_gs.new_game()
	var base_credit: float = _gs.credit_mult()
	var base_xp: float = _gs.captain_run_xp(1.0)
	var it := _item("module", "rare", 5, [{"k": "credits_pct", "v": 20.0}, {"k": "xp_pct", "v": 10.0}])
	_gs.add_item(it)
	_gs.equip(it.id)
	_check(_gs.credit_mult() > base_credit + 0.19, "affixe crédits")
	_check(is_equal_approx(_gs.equipped_bonus("xp_pct"), 10.0), "affixe XP")
	_check(_gs.captain_run_xp(1.0) > base_xp * 1.09, "le bonus d'XP de l'équipement s'applique au Capitaine")


func test_station_rules() -> void:
	_gs.give_hero("rex")
	_gs.give_hero("nova")
	_gs.give_hero("bolt")
	_check(_gs.set_squad_member(0, 0, "rex"), "Rex (Pilote) au poste Pilote")
	_check(not _gs.set_squad_member(0, 1, "rex"), "Rex ne peut pas aller au poste Ingénieur")
	_check(_gs.set_squad_member(0, 1, "bolt"), "Bolt au poste Ingénieur")
	_check(_gs.set_squad_member(0, 0, "nova"), "Nova remplace Rex")
	_check(_gs.squad_ids(0) == ["nova", "bolt"], "postes = [Nova, Bolt]")
	_gs.docks_for_test()
	_gs.set_squad_member(1, 0, "nova")
	_check(_gs.hero_slot("nova") == 1 and _gs.slots[0].squad[0] == "", "une carte ne sert qu'à un seul poste")
	_check(not _gs.set_squad_member(0, 0, "inconnu"), "carte non possédée refusée")


func test_launch_needs_role_and_unlock() -> void:
	_gs.give_hero("rex")
	_gs.give_hero("bolt")
	_check(not _gs.launch(0, "asteroids"), "postes vides : refusé")
	_crew(0, ["bolt"])
	_check(not _gs.launch(0, "asteroids"), "sans pilote au poste : refusé")
	_crew(0, ["rex"])
	_check(_gs.launch(0, "asteroids"), "pilote au poste : lancement OK")
	_check(not _gs.launch(0, "asteroids"), "vaisseau déjà occupé")
	_gs.recall(0)
	_check(not _gs.launch(0, "star"), "étoile verrouillée (données)")
	_give({"data": 30.0})
	_crew(0, ["bolt"])
	_check(_gs.launch(0, "star"), "étoile débloquée")


func test_victory_pays_and_levels() -> void:
	_gs.give_hero("rex", 10)
	_crew(0, ["rex"])
	_gs.captain.level = 30
	_gs.slots[0].auto = false
	_check(_gs.preview_battle("asteroids", 0).win, "victoire prévue")
	_gs.launch(0, "asteroids")
	var minerals_before: float = _gs.res["minerals"]
	var expected: Dictionary = _gs.rewards_of("asteroids", 0)
	_gs._advance_expeditions(500.0)
	_check(_gs.slots[0].dest == "", "fini : vaisseau libre")
	_check(is_equal_approx(_gs.res["minerals"] - minerals_before, expected["minerals"]), "butin complet crédité")
	_check(_gs.captain.xp > 0 or _gs.captain.level > 30, "le Capitaine gagne de l'XP")
	_check(_gs.dest_wins["asteroids"] == 1, "victoire comptée")
	var b: Dictionary = _gs.slots[0].battle
	_check(not b.is_empty() and b.allies.size() == 1 and b.allies[0].id == "captain" and b.events.size() > 0, "combat mémorisé (Capitaine)")


func test_defeat_reduces_loot() -> void:
	_gs.new_game()
	_gs.slots[0].auto = false
	_gs.dest_wins["asteroids"] = 100000
	_check(not _gs.preview_battle("asteroids", 0).win, "défaite prévue")
	_gs.launch(0, "asteroids")
	var full: Dictionary = _gs.rewards_of("asteroids", 0)
	var minerals_before: float = _gs.res["minerals"]
	var items_before: int = _gs.items.size()
	_gs._advance_expeditions(500.0)
	_check(is_equal_approx(_gs.res["minerals"] - minerals_before, full["minerals"] * Data.LOSS_REWARD), "défaite : butin réduit")
	_check(_gs.captain.level == 1 and _gs.captain.xp == 0, "pas d'XP en cas de défaite")


func test_captain_joins_expeditions_on_ship_1() -> void:
	_gs.new_game()
	_gs.upgrade_levels["docks"] = 1
	_check(_gs.make_allies(0)[0].name == _gs.captain.name, "vaisseau 1 : le Capitaine combat")
	_check(_gs.make_allies(1)[0].name == "Drone", "vaisseau 2 : drone (équipage seul)")
	_gs.slots[0].auto = false
	_gs.captain.level = 20
	_gs.launch(0, "asteroids")
	var lv: int = _gs.captain.level
	var xp0: float = _gs.captain.xp
	_gs._advance_expeditions(500.0)
	_check(_gs.captain.xp > xp0 or _gs.captain.level > lv, "le Capitaine gagne de l'XP en expédition")
	_check(_gs.slots[0].battle.allies[0].id == "captain", "combat mémorisé avec le Capitaine")


func test_expeditions_are_paused_offline() -> void:
	_gs.new_game()
	_gs.launch(0, "asteroids")
	var remaining: float = _gs.slots[0].remaining
	var done: int = _gs.expeditions_done
	var res_before: Dictionary = _gs.res.duplicate()
	_gs.simulate_offline(6.0 * 3600.0)
	_check(_gs.expeditions_done == done and is_equal_approx(_gs.slots[0].remaining, remaining), "hors ligne, l'expédition ne bouge pas")
	_check(_gs.res["credits"] > res_before["credits"] - 0.001 and _gs.res["data"] > res_before["data"], "mais le travail aux postes continue (ressources)")


func test_crew_gains_xp_by_working_at_stations() -> void:
	_gs.new_game()
	var lv0: int = _gs.heroes["rex"].level
	var xp0: float = _gs.heroes["rex"].xp
	_gs.tick(3600.0)
	_check(_gs.heroes["rex"].xp > xp0 or _gs.heroes["rex"].level > lv0, "un équipier au poste gagne de l'XP en travaillant")
	var idle_id := ""
	for id in _gs.hero_order:
		if _gs.hero_slot(id) < 0:
			idle_id = id
	if idle_id == "":
		_gs.give_hero("nova")
		idle_id = "nova"
	var xp1: float = _gs.heroes[idle_id].xp
	_gs.tick(3600.0)
	_check(is_equal_approx(_gs.heroes[idle_id].xp, xp1), "un équipier au repos n'en gagne pas")
	_gs.simulate_offline(8.0 * 3600.0)
	_check(_gs.heroes["rex"].level > lv0, "et ça continue hors ligne")


func test_atelier_makes_items_for_the_captain() -> void:
	_gs.new_game()
	_gs.auto_recycle = -1
	_gs.give_hero("tess", 10)
	_gs.set_room_crew("atelier", "tess")
	var items0: int = _gs.items.size()
	_gs.tick(3600.0 * 10.0)
	_check(_gs.items.size() >= items0 + 8, "10 h d'AFK : l'Atelier fabrique des objets (%d)" % (_gs.items.size() - items0))
	_gs.new_game()
	_gs.auto_recycle = -1
	for rid in Data.ROOM_ORDER:
		_gs.room_crew[rid] = ""
	var n0: int = _gs.items.size()
	_gs.tick(3600.0 * 10.0)
	_check(_gs.items.size() == n0 and _gs.afk_drops_per_hour() == 0.0, "sans équipier, l'Atelier ne fabrique rien")


func test_afk_level_raises_loot_quality() -> void:
	_gs.new_game()
	var w0: Dictionary = _gs.drop_weights(1)
	var l0: int = _gs.loot_level()
	_gs.give_hero("nova", 60)
	_gs.give_hero("tess", 60)
	_gs.give_hero("quark", 60)
	_work(["nova", "tess", "quark"])
	_gs.room_levels["mine"] = 20
	_gs.captain.level = 80
	_check(_gs.afk_level() > 100, "niveau d'AFK (%d)" % _gs.afk_level())
	var w1: Dictionary = _gs.drop_weights(1)
	var share0: float = w0["legendary"] / (w0["common"] + w0["uncommon"] + w0["rare"] + w0["epic"] + w0["legendary"])
	var share1: float = w1["legendary"] / (w1["common"] + w1["uncommon"] + w1["rare"] + w1["epic"] + w1["legendary"])
	_check(share1 > share0 * 1.5, "la part de légendaires explose avec le niveau d'AFK (%.3f -> %.3f)" % [share0, share1])
	_check(_gs.loot_level() > l0 + 8, "le niveau d'objet monte aussi")
	_gs.captain.level = 10
	_check(_gs.loot_level() <= 3 + int(_gs.captain_p() * Data.AFK_ILVL_CAP_RATIO), "mais il reste borné par le niveau du Capitaine")
	_check(w1["common"] / w0["common"] < 1.01, "les communs ne bénéficient pas du niveau d'AFK")


func test_anomalies_basics() -> void:
	_gs.new_game()
	_check(_gs.anomaly_unlocked_max() == 1 and _gs.anomaly_charges >= float(Data.ANOMALY_CHARGES_MAX) - 0.1 and _gs.anomaly_runs_available() == 10, "failles : la 1re est ouverte, charges pleines (10 entrées)")
	_check(not _gs.enter_anomaly(2), "la faille 2 est fermée")
	var xp0: int = _gs.captain.xp
	var c0: float = _gs.res["credits"]
	_check(_gs.enter_anomaly(1), "entrée dans la faille 1")
	_check(_gs.last_anomaly.win, "victoire au niveau 1")
	_check(_gs.anomaly_max == 1 and _gs.anomaly_unlocked_max() == 2, "la faille 2 s'ouvre")
	_check(_gs.captain.xp > xp0 or _gs.captain.level > 1, "le Capitaine gagne de l'XP")
	_check(_gs.res["credits"] > c0 and _gs.anomaly_best.has(1), "crédits et record enregistrés")
	_check(is_equal_approx(_gs.anomaly_charges, Data.ANOMALY_CHARGES_MAX - Data.ANOMALY_COST), "10 charges dépensées par entrée")
	_check(_gs.last_anomaly.first and not _gs.last_anomaly.found.is_empty(), "1re réussite : bonus de ressources")
	_check(_gs.enter_anomaly(1) and not _gs.last_anomaly.first, "refaire la faille 1")


func test_anomaly_defeat_refunds_charge() -> void:
	_gs.new_game()
	_gs.anomaly_max = 60
	var ch: float = _gs.anomaly_charges
	_check(_gs.enter_anomaly(61), "entrée dans une faille trop forte")
	_check(not _gs.last_anomaly.win, "défaite")
	_check(is_equal_approx(_gs.anomaly_charges, ch - Data.ANOMALY_COST * (1.0 - Data.ANOMALY_DEFEAT_REFUND)), "la moitié des charges est rendue")
	_check(_gs.anomaly_max == 60 and _gs.last_anomaly.xp == 0, "aucun progrès, aucune perte")


func test_combat_has_real_risk() -> void:
	var weak := [Battle.make_unit("A", 100, 10, 0, 10)]
	var strong := [Battle.make_unit("E", 100, 10, 0, 10)]
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 99
	r2.seed = 99
	_check(Battle.simulate(weak, strong, r1).events == Battle.simulate(weak, strong, r2).events, "même graine : même combat")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wins := 0
	for i in 200:
		if Battle.simulate(weak, strong, rng).win:
			wins += 1
	_check(wins > 40 and wins < 160, "combat à égalité : le hasard fait basculer le résultat (%d / 200)" % wins)
	_check(Battle.simulate(weak, strong).win == Battle.simulate(weak, strong).win, "l'aperçu sans hasard reste déterministe")
	var crushed := [Battle.make_unit("C", 1000, 100, 0, 10)]
	var always := true
	for i in 50:
		always = always and Battle.simulate(crushed, strong, rng).win
	_check(always, "écrasant : jamais d'échec")
	_gs.new_game()
	var allies := [Battle.make_unit("A", 100, 10, 0, 10)]
	var p_even: float = _gs.battle_chance(allies, [Battle.make_unit("E", 100, 10, 0, 10)])
	var p_easy: float = _gs.battle_chance(allies, [Battle.make_unit("E", 100, 6, 0, 10)])
	var p_hard: float = _gs.battle_chance(allies, [Battle.make_unit("E", 100, 16, 0, 10)])
	_check(p_easy > p_even and p_even > p_hard, "la chance de victoire baisse avec la force des ennemis (%.2f > %.2f > %.2f)" % [p_easy, p_even, p_hard])
	_check(is_equal_approx(p_even, _gs.battle_chance(allies, [Battle.make_unit("E", 100, 10, 0, 10)])), "la chance annoncée est stable")
	_gs.rng.seed = 11
	_gs.captain.level = 1
	_gs.anomaly_max = 60
	var defeats := 0
	for i in 20:
		_gs.anomaly_charges = 100.0
		_gs.enter_anomaly(61)
		if not _gs.last_anomaly.win:
			defeats += 1
	_check(defeats == 20, "une faille bien trop forte est toujours perdue")


func test_grouped_expeditions_mix_wins_and_losses() -> void:
	_gs.new_game()
	_gs.rng.seed = 3
	_gs.launch(0, "asteroids")
	var before: int = _gs.afk_wins + _gs.afk_defeats
	_gs._complete(0, 40)
	_check(_gs.afk_wins + _gs.afk_defeats - before == 40, "40 expéditions regroupées : toutes comptées (victoires + défaites)")


func test_anomaly_cost_and_old_saves() -> void:
	_gs.new_game()
	_gs.anomaly_charges = 9.0
	_check(not _gs.enter_anomaly(1) and _gs.anomaly_runs_available() == 0, "moins de 10 charges : pas d'entrée")
	_check(_gs.anomaly_next_run_in() > 0.0 and is_equal_approx(_gs.anomaly_next_run_in(), Data.ANOMALY_REGEN_SECONDS), "il manque 1 charge : 6 min d'attente")
	_gs.anomaly_charges = 10.0
	_check(_gs.enter_anomaly(1) and is_equal_approx(_gs.anomaly_charges, 0.0), "10 charges : une entrée, réserve vide")
	_check(is_equal_approx(Data.ANOMALY_REGEN_SECONDS, 150.0), "+1 charge par tranche de 2 min 30")
	_gs.anomaly_charges = 0.0
	_gs.anomaly_regen_acc = 0.0
	_gs.tick(149.0)
	_check(is_equal_approx(_gs.anomaly_charges, 0.0), "rien avant la fin de la tranche")
	_gs.tick(2.0)
	_check(is_equal_approx(_gs.anomaly_charges, 1.0), "un point entier à 2 min 30")
	_gs.tick(300.0)
	_check(is_equal_approx(_gs.anomaly_charges, 3.0), "puis un point par tranche")
	_check(is_equal_approx(_gs.anomaly_next_run_in(), 6.0 * 150.0 + 149.0), "temps avant la prochaine entrée : 7 points à regagner")
	_gs.save_path = "user://test_old_charges.json"
	var old := {"version": 5, "res": {"credits": 10.0}, "data_total": 0.0, "captain": {"level": 1, "xp": 0, "name": "Capitaine", "look": {"suit": 0, "hair": 0, "style": 0}},
		"items": [], "equipped": {}, "heroes": {}, "hero_order": [], "upgrades": {}, "slots": [], "last_seen": Time.get_unix_time_from_system(),
		"anomaly": {"max": 3, "best": {}, "charges": 7.0}}
	var f := FileAccess.open(_gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	_gs.reset()
	_check(_gs.load_game() and absf(_gs.anomaly_charges - 70.0) < 1.0, "ancienne sauvegarde : 7 charges deviennent 70 (7 entrées)")
	_gs.save_game()
	_gs.reset()
	_gs.load_game()
	_check(absf(_gs.anomaly_charges - 70.0) < 1.0, "la conversion n'est pas refaite")


func test_anomaly_charges_regen_and_limits() -> void:
	_gs.new_game()
	_gs.anomaly_charges = 0.0
	_check(not _gs.enter_anomaly(1), "sans charge, pas d'entrée")
	_gs.tick(Data.ANOMALY_REGEN_SECONDS * 2.0)
	_check(is_equal_approx(_gs.anomaly_charges, 2.0), "recharge en temps réel")
	_gs.simulate_offline(Data.ANOMALY_REGEN_SECONDS * 100.0)
	_check(is_equal_approx(_gs.anomaly_charges, float(Data.ANOMALY_CHARGES_MAX)), "recharge hors ligne, plafonnée au maximum")


func test_anomaly_record_bonus_and_save() -> void:
	_gs.save_path = "user://test_anomaly.json"
	_gs.new_game()
	_gs.anomaly_max = 3
	_gs.anomaly_best[2] = 99
	_gs.captain.level = 40
	_check(_gs.enter_anomaly(2) and _gs.last_anomaly.win and _gs.last_anomaly.record, "record battu")
	_gs.save_game()
	_gs.reset()
	_check(_gs.load_game(), "chargement")
	_check(_gs.anomaly_max == 3 and _gs.anomaly_best.get(2, 0) < 99 and _gs.anomaly_charges < float(Data.ANOMALY_CHARGES_MAX) + 0.001, "anomalies restaurées")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_anomaly.json"))
	_gs.save_path = _gs.SAVE_PATH


func test_auto_squad_and_autoplace() -> void:
	_gs.give_hero("rex")
	_gs.give_hero("nova")
	_gs.give_hero("bolt")
	_gs.give_hero("lumi")
	_gs.auto_squad(0)
	var ids: Array = _gs.squad_ids(0)
	_check(ids.size() == 3, "un équipier par poste")
	_check(ids.has("nova") and not ids.has("rex"), "le plus fort d'une classe est choisi")
	_gs.reset()
	_give({"credits": 100000.0})
	for i in 8:
		_gs.recruit()
	_check(_gs.squad_ids(0).size() > 0, "un équipier recruté prend son poste libre")


func test_auto_repeat_offline() -> void:
	_gs.new_game()
	_gs.captain.level = 30
	var d: float = _gs.duration_of("asteroids", 0)
	_gs.launch(0, "asteroids")
	_gs._advance_expeditions(d * 10.0 + 0.5)
	_check(_gs.expeditions_done == 1 and _gs.slots[0].dest == "", "sans déblocage : une seule expédition, pas de relance")
	_gs.set_auto(0, true)
	_check(not _gs.auto_relaunch(0), "relance automatique verrouillée sans Cristaux")
	_gs.crystals = 100
	_check(_gs.buy_premium("exp_auto") and _gs.crystals == 0, "100 Cristaux : relance automatique débloquée")
	_gs.set_auto(0, true)
	_check(_gs.auto_relaunch(0), "relance automatique active")
	_gs.expeditions_done = 0
	_gs.launch(0, "asteroids")
	_gs._advance_expeditions(d * 10.0 + 0.5)
	_check(_gs.expeditions_done == 10, "10 cycles auto en une longue absence (obtenu %d)" % _gs.expeditions_done)
	_check(_gs.slots[0].dest == "asteroids", "toujours en expédition")


func test_upgrades() -> void:
	_gs.new_game()
	_check(not _gs.buy_upgrade("laser"), "amélioration refusée sans ressources")
	_give({"credits": 1000.0, "minerals": 100.0, "energy": 100.0})
	var before: float = _gs.rewards_of("asteroids", 0)["minerals"]
	_check(_gs.buy_upgrade("laser") and _gs.rewards_of("asteroids", 0)["minerals"] > before, "le laser augmente les minerais")
	_check(_gs.buy_upgrade("docks") and _gs.slot_count() == 2, "baie d'amarrage : 2 vaisseaux")
	_check(not _gs.buy_upgrade("docks"), "baie au maximum")
	var d0: float = _gs.duration_of("asteroids", 0)
	_gs.buy_upgrade("engines")
	_check(_gs.duration_of("asteroids", 0) < d0, "les moteurs réduisent la durée")


func test_data_unlocks() -> void:
	_check(not _gs.is_unlocked("planet"), "planète verrouillée au départ")
	_give({"data": 100.0})
	_check(_gs.is_unlocked("planet"), "planète débloquée à 100 données cumulées")
	_gs.res["data"] = 0.0
	_check(_gs.is_unlocked("planet"), "reste débloquée même après dépense")


func test_star_unlocks_in_reasonable_time() -> void:
	_gs.new_game()
	_gs.launch(0, "asteroids")
	var elapsed := 0.0
	while not _gs.is_unlocked("star") and elapsed < 1800.0:
		_gs.tick(1.0)
		elapsed += 1.0
	_check(elapsed < 360.0, "l'étoile se débloque en moins de 6 minutes (obtenu %d s)" % int(elapsed))


func test_save_load_roundtrip() -> void:
	_gs.save_path = "user://test_save.json"
	_gs.new_game()
	_gs.give_hero("nova", 7, 2)
	_crew(0, ["nova"])
	_gs.captain.level = 12
	_gs.captain.look.hair = 3
	_gs.auto_recycle = 1
	var it := _item("weapon", "epic", 9, [{"k": "atk_pct", "v": 6.5}, {"k": "crit", "v": 3.2}, {"k": "xp_pct", "v": 4.0}])
	_gs.add_item(it)
	_gs.equip(it.id)
	_gs.launch(0, "asteroids")
	_gs.res["minerals"] = 42.0
	_gs.save_game()
	_gs.reset()
	_check(_gs.heroes.is_empty() and _gs.items.is_empty(), "état vidé")
	_check(_gs.load_game(), "chargement réussi")
	_check(_gs.captain.level == 12 and _gs.captain.look.hair == 3 and _gs.auto_recycle == 1, "Capitaine et réglages restaurés")
	var w: Dictionary = _gs.equipped_item("weapon")
	_check(w.rarity == "epic" and w.ilvl == 9 and w.affixes.size() == 3, "objet et affixes restaurés")
	_check(is_equal_approx(_gs.equipped_bonus("crit"), 3.2), "bonus restaurés")
	_check(_gs.heroes["nova"].level == 7 and _gs.heroes["nova"].stars == 2, "équipage restauré")
	_check(is_equal_approx(_gs.res["minerals"], 42.0), "ressources restaurées")
	_check(_gs.squad_ids(0).has("nova") and _gs.slots[0].dest == "asteroids", "postes et expédition restaurés")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	_gs.save_path = _gs.SAVE_PATH


func test_room_upgrade_boosts_production() -> void:
	_gs.new_game()
	var before: float = _gs.production_per_sec().credits
	_gs.res["credits"] = 1.0e6
	_gs.res["minerals"] = 1.0e4
	_check(_gs.buy_room_upgrade("mine"), "Mine améliorée")
	var after: float = _gs.production_per_sec().credits
	_check(after > before * 1.02 and _gs.room_level("mine") == 2, "la production augmente (%.4f -> %.4f)" % [before, after])
	var c1: float = _gs.room_upgrade_cost("mine")["credits"]
	_gs.room_levels["mine"] = 10
	_check(_gs.room_upgrade_cost("mine")["credits"] > c1 * 10.0, "le coût monte vite avec le niveau")
	_gs.room_levels["mine"] = Data.ROOM_MAX_LEVEL
	_check(not _gs.buy_room_upgrade("mine"), "niveau maximum de salle")


func test_base_goals_reward_items_and_persist() -> void:
	_gs.new_game()
	_gs.auto_recycle = -1
	var g13 := {}
	for g in Data.GOALS:
		if g.id == "g13":
			g13 = g
	_check(not g13.is_empty() and g13.reward.get("item", "") == "epic", "un objectif de Base donne un objet épique")
	_gs.goals_claimed = []
	for g in Data.GOALS:
		if g.id != "g13":
			_gs.goals_claimed.append(g.id)
	var n0: int = _gs.items.size()
	_check(not _gs.claim_goal(), "objectif d'AFK : pas encore atteint")
	for rid in Data.ROOM_ORDER:
		_gs.room_levels[rid] = 300
	_gs.give_hero("tess", 1)
	_gs.give_hero("gorn", 1)
	_gs.give_hero("zara", 1)
	_gs.give_hero("nova", 1)
	_gs.give_hero("quark", 1)
	_gs.give_hero("lumi", 1)
	_gs.auto_rooms()
	_check(_gs.claim_goal() and _gs.items.size() == n0 + 1 and _gs.items[_gs.items.size() - 1].rarity == "epic", "récupéré : l'objet épique arrive")
	_gs.crafted_total = 77
	_gs.save_path = "user://test_crafted.json"
	_gs.save_game()
	_gs.reset()
	_gs.load_game()
	_check(_gs.crafted_total == 77, "le compteur d'objets fabriqués est sauvegardé")


func test_prestige_rules() -> void:
	_gs.new_game()
	_check(_gs.prestige_block_reason() != "" and _gs.do_prestige() == 0, "refonte impossible tant que les salles sont trop basses")
	for rid in Data.ROOM_ORDER:
		_gs.room_levels[rid] = 20
	_gs.heroes["rex"].level = 40
	_gs.upgrade_levels["laser"] = 5
	_gs.upgrade_levels["docks"] = 1
	_gs.res["credits"] = 5.0e6
	_gs.launch(0, "asteroids")
	var gain: int = _gs.prestige_gain()
	_check(_gs.base_power() == 120 and gain == 32, "120 niveaux de salles promettent 32 éclats (%d)" % gain)
	var cap_before: float = _gs.captain_stats(0).atk
	_check(_gs.do_prestige() == gain and _gs.prestige_points == gain and _gs.prestige_count == 1, "la refonte donne les éclats")
	_check(_gs.room_level("mine") == 1 and _gs.upgrade_levels["laser"] == 0, "salles et améliorations remises à zéro")
	_check(_gs.upgrade_levels["docks"] == 1, "le 2e vaisseau est conservé")
	_check(_gs.heroes["rex"].level == 40, "les niveaux d'équipage sont conservés")
	_check(is_equal_approx(_gs.res.credits, Data.START_CREDITS), "ressources remises au départ")
	_check(_gs.slots[0].dest == "", "l'expédition en cours est rappelée")
	_check(is_equal_approx(_gs.captain_stats(0).atk, cap_before), "le Capitaine n'est pas affaibli")
	_check(_gs.prestige_block_reason() != "" and _gs.do_prestige() == 0, "pas de refonte en boucle : il faut remonter les salles")
	_check(_gs.room_max_level() == Data.ROOM_MAX_LEVEL + Data.PRESTIGE_ROOM_CAP_PER_RANK, "le niveau maximal des salles monte")
	for rid in Data.ROOM_ORDER:
		_gs.room_levels[rid] = 20
	_check(_gs.prestige_gain() == 0, "la même Base ne rapporte rien de nouveau")
	for rid in Data.ROOM_ORDER:
		_gs.room_levels[rid] = 24
	_check(_gs.prestige_gain() > 0, "une Base plus haute rapporte de nouveaux éclats")


func test_prestige_perks() -> void:
	_gs.new_game()
	var p0: float = _gs.production_per_sec().credits
	_gs.prestige_points = 10
	_check(_gs.perk_cost("prod") == 1 and _gs.buy_perk("prod"), "premier niveau de Rendement : 1 éclat")
	_check(_gs.perk_cost("prod") == 2, "le coût monte")
	_check(_gs.production_per_sec().credits > p0 * 1.1, "Rendement augmente la production")
	var x0: float = _gs.crew_xp_mult()
	_gs.buy_perk("xp")
	_check(_gs.crew_xp_mult() > x0 * 1.1, "Formation augmente l'XP")
	_gs.buy_perk("found")
	_check(_gs.prestige_start_level() == 3, "Fondations : les salles repartent au niveau 3")
	_gs.prestige_points = 0
	_check(not _gs.buy_perk("xp"), "pas assez d'éclats")
	_gs.prestige_points = 5
	_gs.save_path = "user://test_prestige.json"
	_gs.save_game()
	_gs.reset()
	_gs.load_game()
	_check(_gs.prestige_points == 5 and _gs.perk_level("prod") == 1 and _gs.perk_level("found") == 1, "refonte sauvegardée et rechargée")


func test_prestige_goals() -> void:
	_gs.new_game()
	_gs.auto_recycle = -1
	_check(_gs.next_prestige_goal().id == "pg1" and not _gs.claim_prestige_goal(), "objectif de refonte : pas avant la première refonte")
	var earned0: int = _gs.prestige_earned
	_gs.prestige_count = 1
	var n0: int = _gs.items.size()
	_check(_gs.claim_prestige_goal() and _gs.prestige_points == 3 and _gs.items.size() == n0 + 1, "1re refonte : 3 éclats et un objet épique")
	_check(_gs.prestige_earned == earned0, "les éclats d'objectif ne réduisent pas les gains de refonte")
	_check(_gs.next_prestige_goal().id == "pg2" and _gs.next_goal().id == "g1", "la chaîne de refonte est indépendante de la chaîne principale")
	_gs.prestige_perks = {"prod": 6, "xp": 4}
	_check(_gs.claim_prestige_goal() and _gs.next_prestige_goal().id == "pg3", "10 niveaux de bonus : objectif suivant")


func test_lab_slots_and_premium_unlocks() -> void:
	_gs.new_game()
	_check(_gs.research_slots() == 1, "un seul poste de recherche au départ")
	_gs.research_levels["labo_annexe"] = 1
	_check(_gs.research_slots() == 2, "le Laboratoire annexe donne le 2e poste")
	_check(Data.RESEARCH["labo_annexe"].max == 1, "pas de 3e poste par la recherche")
	_gs.set_research_auto(true)
	_check(not _gs.research_auto, "la recherche automatique est verrouillée")
	_check(not _gs.buy_premium("lab_slot") and not _gs.buy_premium("lab_auto"), "pas de Cristaux : achats impossibles")
	_gs.crystals = 300
	_check(_gs.buy_premium("lab_slot") and _gs.research_slots() == 3 and _gs.crystals == 0, "300 Cristaux : 3e poste débloqué")
	_check(not _gs.buy_premium("lab_slot"), "déjà débloqué")
	_gs.crystals = 150
	_check(_gs.buy_premium("lab_auto"), "recherche automatique débloquée")
	_gs.set_research_auto(true)
	_check(_gs.research_auto, "elle peut alors être activée")
	_gs.save_path = "user://test_premium.json"
	_gs.save_game()
	_gs.reset()
	_gs.load_game()
	_check(_gs.research_slots() == 3 and _gs.research_auto and _gs.premium_unlocked("lab_auto"), "déblocages sauvegardés")


func test_old_lab_unlocks_are_kept() -> void:
	_gs.save_path = "user://test_old_lab.json"
	var old := {"version": 5, "res": {"credits": 10.0}, "data_total": 0.0, "captain": {"level": 1, "xp": 0, "name": "Capitaine", "look": {"suit": 0, "hair": 0, "style": 0}},
		"items": [], "equipped": {}, "heroes": {}, "hero_order": [], "upgrades": {}, "slots": [], "last_seen": 0,
		"research": {"levels": {"labo_annexe": 2}, "active": [], "queue": [], "auto": true}}
	var f := FileAccess.open(_gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	_gs.reset()
	_check(_gs.load_game(), "chargement")
	_check(_gs.research_slots() == 3 and _gs.research_auto, "une ancienne sauvegarde garde son 3e poste et la recherche auto")


func test_goals() -> void:
	_gs.new_game()
	var g: Dictionary = _gs.next_goal()
	_check(g.id == "g1" and not _gs.goal_ready(g), "premier objectif non atteint")
	_check(not _gs.claim_goal(), "récupération impossible avant le palier")
	_gs.captain.level = 5
	_check(_gs.goal_ready(_gs.next_goal()), "objectif atteint au niveau 5")
	var credits_before: float = _gs.res["credits"]
	_check(_gs.claim_goal(), "récompense récupérée")
	_check(_gs.res["credits"] >= credits_before + 399.0, "crédits reçus")
	_check(_gs.next_goal().id == "g2", "objectif suivant")
	_gs.save_path = "user://test_goals.json"
	_gs.save_game()
	_gs.reset()
	_check(_gs.load_game() and _gs.goals_claimed.has("g1"), "objectifs sauvegardés")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_goals.json"))
	_gs.save_path = _gs.SAVE_PATH


func test_offline_24h_is_fast() -> void:
	_gs.new_game()
	_gs.give_hero("nova", 30)
	_gs.give_hero("tess", 30)
	_gs.give_hero("zara", 30)
	_crew(0, ["nova", "tess", "zara"])
	var t0 := Time.get_ticks_msec()
	var rep: Dictionary = _gs.simulate_offline(24.0 * 3600.0)
	var ms := Time.get_ticks_msec() - t0
	_check(ms < 2000, "24 h hors ligne calculées en moins de 2 s (obtenu %d ms)" % ms)
	_check(rep.gains.credits > 0.0, "des gains sont crédités")


func test_enemy_level_is_capped() -> void:
	_gs.new_game()
	_gs.dest_wins["asteroids"] = 1000000
	_check(_gs.enemy_level("asteroids") == Data.ENEMY_LEVEL_MAX, "niveau des ennemis plafonné")


func test_research_start_queue_and_cancel() -> void:
	_gs.new_game()
	_give({"credits": 100000.0, "data": 1000.0, "minerals": 1000.0, "energy": 1000.0})
	var c0: float = _gs.res["credits"]
	_check(_gs.start_research("calibrage"), "recherche lancée")
	_check(_gs.res["credits"] < c0, "coût payé d'avance")
	_check(_gs.research_active.size() == 1, "une recherche en cours")
	_check(not _gs.start_research("calibrage"), "pas deux fois la même en même temps")
	_check(_gs.start_research("cartographie") and _gs.research_queue.has("cartographie"), "2e recherche mise en file (1 seul poste)")
	var d0: float = _gs.res["data"]
	_check(_gs.cancel_research("cartographie") and _gs.res["data"] > d0 and _gs.research_queue.is_empty(), "annulation de la file : remboursée en entier")
	_check(_gs.research_block_reason("propulsion") != "", "prérequis : Calibrage niv. 3")


func test_research_completes_and_applies() -> void:
	_gs.new_game()
	_give({"credits": 1.0e6})
	var p0: float = _gs.production_per_sec().data
	_check(_gs.start_research("calibrage"), "lancée")
	_gs.tick(Data.research_curve(Data.RESEARCH.calibrage.time, 0, 25) + 1.0)
	_check(_gs.research_level("calibrage") == 1 and _gs.research_active.is_empty(), "terminée en temps réel")
	_check(_gs.production_per_sec().data > p0, "l'effet s'applique (production)")


func test_research_offline_runs_to_the_end() -> void:
	_gs.new_game()
	_give({"credits": 1.0e7, "data": 1.0e5, "minerals": 1.0e5, "energy": 1.0e5})
	_gs.research_levels["calibrage"] = 3
	_check(_gs.start_research("propulsion"), "propulsion lancée")
	var total: float = _gs.research_active[0].remaining
	_gs.simulate_offline(total + 10.0)
	_check(_gs.research_level("propulsion") == 1, "terminée hors ligne")
	_check(not _gs.research_done_log.is_empty(), "la recherche terminée est notée pour le rapport")


func test_captain_levels_are_compressed() -> void:
	_gs.new_game()
	_check(_gs.captain_p() == 1, "niveau 1 : puissance 1")
	_gs.captain.level = 11
	_check(_gs.captain_p() == 51, "niveau 11 : puissance 51 (5 niveaux de puissance par niveau)")
	var m: float = 1.0 + Data.CAPTAIN_LEVEL_BONUS * 50.0
	_check(is_equal_approx(_gs.captain_stats(0).base.atk, Data.CAPTAIN_BASE.atk * m), "les stats suivent la puissance, pas le niveau affiché")
	var sum_old := 0
	for p in range(51, 56):
		sum_old += Data.xp_needed(p)
	_check(abs(Data.captain_xp_needed(11) - sum_old) <= 1, "un niveau coûte l'XP cumulée de ses 5 niveaux de puissance (%d / %d)" % [Data.captain_xp_needed(11), sum_old])
	var old_run: float = Data.XP_PER_LEVEL * 53.0 / (3.0 + 53.0 / 2.5)
	_check(abs(_gs.captain_run_xp(1.0) - old_run) < 1.0, "une victoire rapporte autant qu'avant")


func test_old_captain_save_is_converted() -> void:
	_gs.save_path = "user://test_old_captain.json"
	var old := {"version": 5, "res": {"credits": 10.0}, "data_total": 0.0, "captain": {"level": 47, "xp": 100, "name": "Capitaine", "look": {"suit": 0, "hair": 0, "style": 0}},
		"items": [], "equipped": {}, "heroes": {}, "hero_order": [], "upgrades": {}, "slots": [], "last_seen": 0}
	var f := FileAccess.open(_gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	_gs.reset()
	_check(_gs.load_game(), "chargement de l'ancienne sauvegarde")
	_check(_gs.captain.level == 10 and _gs.captain.xp == 100 + Data.xp_needed(46), "ancien niveau 47 = niveau 10 + le reste en XP")
	_gs.save_game()
	_gs.reset()
	_gs.load_game()
	_check(_gs.captain.level == 10, "la sauvegarde convertie ne l'est pas deux fois")


func test_captain_level_cap() -> void:
	_gs.new_game()
	_gs.captain.level = Data.CAPTAIN_MAX_LEVEL - 1
	_gs.captain.xp = 0
	var gained: int = _gs.gain_captain_xp(Data.captain_xp_needed(Data.CAPTAIN_MAX_LEVEL - 1) * 5)
	_check(gained == 1 and _gs.captain.level == 50 and _gs.captain.xp == 0, "niveau 50 atteint : l'XP en trop est perdue (%d)" % _gs.captain.level)
	_check(_gs.gain_captain_xp(1000000) == 0 and _gs.captain.level == 50, "rien ne fait passer au-dessus du niveau 50")
	_gs.res["credits"] = 1.0e30
	_check(not _gs.train_captain() and _gs.captain.level == 50, "l'entraînement est refusé au niveau maximum")
	_check(_gs.anomaly_xp(10, false) == 0, "plus d'XP d'anomalie au niveau maximum")
	_gs.give_hero("rex", 90)
	var lv: int = _gs.heroes["rex"].level
	_gs.gain_xp("rex", Data.xp_needed(lv) + 1)
	_check(_gs.heroes["rex"].level == lv + 1, "l'équipage n'a pas de plafond")


func test_research_boost_costs_energy_and_is_limited() -> void:
	_gs.new_game()
	_give({"credits": 1.0e6, "data": 1.0e4, "minerals": 1.0e4})
	_gs.research_levels["calibrage"] = 3
	_give({"energy": 1000.0})
	_check(_gs.start_research("propulsion"), "lancée")
	var total: float = _gs.research_active[0].total
	_gs.res["energy"] = 0.0
	_check(not _gs.boost_research("propulsion"), "pas assez d'énergie")
	_give({"energy": 1.0e9})
	_check(_gs.boost_research("propulsion"), "1re accélération")
	_check(is_equal_approx(_gs.research_active[0].remaining, total * 0.75), "−25 % de la durée totale")
	_check(_gs.boost_research("propulsion"), "2e accélération")
	_check(not _gs.boost_research("propulsion") and _gs.research_level("propulsion") == 0, "3e refusée : la recherche n'est pas terminée d'un coup")


func test_research_save_load() -> void:
	_gs.save_path = "user://test_research.json"
	_gs.new_game()
	_give({"credits": 1.0e6, "data": 1.0e4, "minerals": 1.0e4})
	_gs.research_levels["calibrage"] = 4
	_check(_gs.start_research("cartographie"), "lancée")
	_gs.save_game()
	_gs.reset()
	_check(_gs.load_game(), "chargement")
	_check(_gs.research_level("calibrage") == 4 and _gs.research_active.size() == 1 and _gs.research_active[0].id == "cartographie", "recherches restaurées")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_research.json"))
	_gs.save_path = _gs.SAVE_PATH


func test_research_auto_fills_free_slot() -> void:
	_gs.new_game()
	_give({"credits": 1.0e6, "data": 1.0e4, "minerals": 1.0e4, "energy": 1.0e4})
	_check(_gs.research_active.is_empty(), "rien en cours")
	_gs.premium_unlocks["lab_auto"] = true
	_gs.set_research_auto(true)
	_check(_gs.research_active.size() == 1, "le poste libre est rempli tout seul")
	var first: String = _gs.research_active[0].id
	_gs.tick(_gs.research_active[0].remaining + 1.0)
	_check(_gs.research_level(first) >= 1 and _gs.research_active.size() == 1, "à la fin, la suivante démarre toute seule")
	_gs.set_research_auto(false)
	_gs.research_active.clear()
	_gs.tick(100.0)
	_check(_gs.research_active.is_empty(), "automatique coupé : rien ne démarre")


func test_room_crew_rules() -> void:
	_gs.new_game()
	_gs.give_hero("nova")
	_check(_gs.set_room_crew("quartiers", "nova"), "Nova aux Quartiers")
	_check(_gs.set_room_crew("mine", "nova") and _gs.room_worker("quartiers") == "" and _gs.room_worker("mine") == "nova", "un équipier ne travaille que dans une salle")
	_check(not _gs.set_room_crew("mine", "inconnu") and not _gs.set_room_crew("salon", "nova"), "carte ou salle inconnue refusée")
	_check(_gs.set_room_crew("mine", "") and _gs.hero_room("nova") == "", "salle vidée")


func test_room_affinity_and_specialty() -> void:
	_gs.new_game()
	_gs.give_hero("rex", 1)
	_gs.give_hero("zara", 1)
	var base: float = _gs.crew_prod_mult("rex")
	_check(is_equal_approx(_gs.room_hero_mult("mine", "rex"), base * 1.25 * 1.5), "Rex : classe Pilote (+25 %) et spécialité Mine (+50 %)")
	_check(is_equal_approx(_gs.room_hero_mult("quartiers", "rex"), base * 1.25), "Rex aux Quartiers : affinité de classe seulement")
	_check(is_equal_approx(_gs.room_hero_mult("centrale", "rex"), base), "Rex à la Centrale : aucun bonus")


func test_auto_rooms_places_everyone_sensibly() -> void:
	_gs.new_game()
	for id in ["nova", "zara", "tess", "gorn", "lumi", "quark", "elara"]:
		_gs.give_hero(id)
	_gs.auto_rooms()
	var workers := {}
	for rid in Data.ROOM_ORDER:
		var w: String = _gs.room_worker(rid)
		_check(w != "", "la salle %s a un équipier" % rid)
		_check(not workers.has(w), "%s n'est placé qu'une fois" % w)
		workers[w] = true
	_check(_gs.room_worker("mine") == "zara", "la Mine reçoit la meilleure Pilote (Zara, épique)")


func test_atelier_targeting() -> void:
	_gs.new_game()
	_gs.auto_recycle = -1
	_gs.room_levels["atelier"] = 20      # puissance de fabrication élevée : des objets à bonus
	_gs.atelier_slot = "helmet"
	_gs.atelier_focus = "crit"
	var all_helmets := true
	var all_crit := true
	var fancy := 0
	for i in 300:
		var it: Dictionary = _gs.roll_afk_drop()
		if it.is_empty():
			continue
		all_helmets = all_helmets and it.slot == "helmet"
		if it.affixes.size() > 0:
			fancy += 1
			var has_crit := false
			for a in it.affixes:
				has_crit = has_crit or a.k == "crit"
			all_crit = all_crit and has_crit
	_check(all_helmets, "l'emplacement visé est respecté")
	_check(fancy > 20 and all_crit, "le bonus visé est garanti sur tous les objets à bonus (%d objets)" % fancy)
	_gs.atelier_slot = ""
	_gs.atelier_focus = ""
	var free: float = _gs.afk_drops_per_hour()
	_gs.atelier_slot = "helmet"
	_check(is_equal_approx(_gs.afk_drops_per_hour(), free * Data.ATELIER_TARGET_FACTOR), "cibler l'emplacement coûte 15 % de cadence")
	_gs.atelier_focus = "crit"
	_check(is_equal_approx(_gs.afk_drops_per_hour(), free * Data.ATELIER_TARGET_FACTOR * Data.ATELIER_TARGET_FACTOR), "cibler le bonus aussi")


func test_atelier_level_and_staff_raise_cadence_and_quality() -> void:
	_gs.new_game()
	for rid in Data.ROOM_ORDER:
		_gs.room_crew[rid] = ""
	var c0: float = _gs.afk_drops_per_hour()
	var q0: int = _gs.craft_power()
	_gs.give_hero("tess", 1)
	_gs.set_room_crew("atelier", "tess")
	c0 = _gs.afk_drops_per_hour()
	_gs.room_levels["atelier"] = 11
	_check(_gs.afk_drops_per_hour() > c0 * 1.5, "le niveau de l'Atelier accélère la fabrication")
	_check(_gs.craft_power() >= q0 + 30, "et améliore la qualité des objets")
	var c1: float = _gs.afk_drops_per_hour()
	_gs.heroes["tess"].level = 30
	_check(_gs.afk_drops_per_hour() > c1 * 1.4, "un équipier (spécialiste) accélère encore")


func test_quarters_and_soute_effects() -> void:
	_gs.new_game()
	var x0: float = _gs.crew_xp_mult()
	_check(is_equal_approx(x0, 1.0), "Quartiers niveau 1 : pas de bonus d'XP")
	_gs.room_levels["quartiers"] = 11
	_check(is_equal_approx(_gs.crew_xp_mult(), 1.0), "Quartiers sans équipier : aucun effet")
	_gs.give_hero("nova", 10)
	_gs.set_room_crew("quartiers", "nova")
	_check(_gs.crew_xp_mult() > 1.25, "Quartiers niveau 11 : environ +30 % d'XP")
	var lv0: int = _gs.heroes["rex"].level
	var xp_rate: float = _gs.crew_xp_per_sec("rex")
	_check(xp_rate > 0.0, "un équipier au travail gagne de l'XP")
	var cap0: float = _gs.offline_cap_seconds()
	var eff0: float = _gs.offline_efficiency()
	_gs.room_levels["soute"] = 11
	_check(is_equal_approx(_gs.offline_cap_seconds(), cap0), "Soute sans équipier : aucun effet")
	_gs.give_hero("quark", 10)
	_gs.set_room_crew("soute", "quark")
	_check(_gs.offline_cap_seconds() > cap0 + 3.0 * 3600.0, "la Soute allonge le coffre hors ligne")
	_check(is_equal_approx(_gs.offline_efficiency(), eff0), "mais pas le rendement (fixe à 50 %)")
	_check(lv0 >= 1, "niveau cohérent")


func test_old_save_migrates_stations_to_rooms() -> void:
	_gs.save_path = "user://test_old_save.json"
	var old := {"version": 5, "res": {"credits": 123.0}, "data_total": 0.0, "captain": {"level": 3, "xp": 0, "name": "Capitaine", "look": {"suit": 0, "hair": 0, "style": 0}},
		"items": [], "equipped": {}, "heroes": {"rex": {"level": 7, "xp": 0, "stars": 0}, "bolt": {"level": 4, "xp": 0, "stars": 0}},
		"hero_order": ["rex", "bolt"], "upgrades": {"laser": 2, "st_pilot": 5, "st_engineer": 2, "st_scientist": 0}, "slots": [], "last_seen": 0}
	var f := FileAccess.open(_gs.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	_gs.reset()
	_check(_gs.load_game(), "chargement de l'ancienne sauvegarde")
	_check(_gs.room_level("mine") == 6 and _gs.room_level("quartiers") == 6 and _gs.room_level("centrale") == 3 and _gs.room_level("labo") == 1, "les niveaux de postes deviennent des niveaux de salles (par affinité)")
	_check(_gs.room_worker("mine") == "rex" and _gs.room_worker("centrale") == "bolt", "placement automatique à la migration")
	_check(_gs.upgrade_levels["laser"] == 2 and not _gs.upgrade_levels.has("st_pilot"), "les autres améliorations restent")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_old_save.json"))
	_gs.save_path = _gs.SAVE_PATH


func test_base_save_load_roundtrip() -> void:
	_gs.save_path = "user://test_base.json"
	_gs.new_game()
	_gs.room_levels["atelier"] = 7
	_gs.atelier_slot = "boots"
	_gs.atelier_focus = "xp_pct"
	_gs.give_hero("tess", 12)
	_gs.set_room_crew("atelier", "tess")
	_gs.save_game()
	_gs.reset()
	_check(_gs.load_game(), "chargement")
	_check(_gs.room_level("atelier") == 7 and _gs.atelier_slot == "boots" and _gs.atelier_focus == "xp_pct" and _gs.room_worker("atelier") == "tess", "Base restaurée")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_base.json"))
	_gs.save_path = _gs.SAVE_PATH


# ---------- expéditions en direct ----------

func _live_run(seed_value: int, cfg: Dictionary, human: bool = false) -> LiveSim:
	var s := LiveSim.new(seed_value)
	s.human_bot = human
	s.setup(cfg)
	var steps := 0
	while not s.over and steps < 20000:
		s.step(1.0 / 30.0)
		steps += 1
	return s


func test_live_sim_is_deterministic() -> void:
	var a := _live_run(77, {"tier": 1, "assist": true})
	var b := _live_run(77, {"tier": 1, "assist": true})
	_check(a.over and a.win == b.win and a.hits == b.hits and is_equal_approx(a.t, b.t), "même graine, même combat")
	_check(a.objectives == b.objectives, "mêmes objectifs tirés avec la même graine")


func test_live_objectives_two_distinct_and_weak_needs_boss() -> void:
	var weak_with_boss := false
	for i in 60:
		var s := LiveSim.new(1000 + i)
		s.setup({"tier": 0, "use_boss": true})
		_check(s.objectives.size() == 2 and s.objectives[0] != s.objectives[1], "deux objectifs différents")
		if s.objectives.has("weak"):
			weak_with_boss = true
		var n := LiveSim.new(2000 + i)
		n.setup({"tier": 0, "use_boss": false})
		_check(not n.objectives.has("weak"), "pas d'objectif de points faibles sans gardien")
	_check(weak_with_boss, "l'objectif des points faibles existe face à un gardien")


func test_live_combo_counts_in_assist_mode() -> void:
	var s := _live_run(5, {"tier": 0, "assist": true})
	_check(s.max_combo >= 10, "le combo compte aussi en équipage assisté (x%d)" % s.max_combo)


func test_live_projectiles_have_varied_speeds() -> void:
	var s := LiveSim.new(3)
	s.setup({"tier": 0})
	var speeds := {}
	for i in 1500:
		s.step(1.0 / 30.0)
		for b in s.ebullets:
			speeds[b.kind] = true
		if s.over:
			break
	_check(speeds.size() >= 3, "au moins trois sortes de projectiles ennemis (%d)" % speeds.size())


func test_live_win_rates_stay_under_the_cap() -> void:
	for tier in [0, 2, 4]:
		var wins_auto := 0
		var wins_human := 0
		for i in 40:
			if _live_run(9000 + i * 31, {"tier": tier, "assist": true}).win:
				wins_auto += 1
			if _live_run(7000 + i * 17, {"tier": tier}, true).win:
				wins_human += 1
		_check(wins_auto <= 34 and wins_human <= 34, "palier %d : au plus ~85 %% de victoires (auto %d/40, joueur %d/40)" % [tier + 1, wins_auto, wins_human])
		_check(wins_auto >= 8 and wins_human >= 8, "palier %d : le combat reste gagnable (auto %d/40, joueur %d/40)" % [tier + 1, wins_auto, wins_human])


func test_live_assist_shoots_weaker() -> void:
	var s := LiveSim.new(1)
	s.setup({"tier": 0, "assist": true})
	var e := {"k": "drone", "x": 180.0, "y": 100.0, "hp": 1000.0, "max": 1000.0, "r": 24.0, "flash": 0.0, "dead": false}
	s._damage_enemy(e, 100.0, 1)
	_check(is_equal_approx(e.hp, 1000.0 - 100.0 * LiveSim.ASSIST_DAMAGE), "l'équipage assisté tire à 75 % de la puissance")


func test_live_abandon_is_a_defeat() -> void:
	var s := LiveSim.new(1)
	s.setup({"tier": 0})
	s.abandon()
	_check(s.over and not s.win, "abandonner est une défaite")


func test_ship_tier_follows_upgrades_and_survives_prestige() -> void:
	_gs.new_game()
	_check(_gs.ship_tier() == 0, "palier 1 au départ")
	_gs.upgrade_levels["laser"] = 10
	_check(_gs.ship_tier() == 1, "10 niveaux : palier 2")
	_gs.upgrade_levels["solar"] = 15
	_check(_gs.ship_tier() == 2, "25 niveaux : palier 3")
	for id in ["laser", "solar", "scanner", "engines"]:
		_gs.upgrade_levels[id] = 20
	_check(_gs.ship_tier() == 4, "80 niveaux : palier 5")
	_gs.ship_tier_best = 4
	for id in ["laser", "solar", "scanner", "engines"]:
		_gs.upgrade_levels[id] = 0
	_check(_gs.ship_tier() == 4, "le palier le plus haut est gardé quand les améliorations repartent à zéro")
	_gs.save_path = "user://test_ship_tier.json"
	_gs.save_game()
	_gs.reset()
	_gs.load_game()
	_check(_gs.ship_tier() == 4, "le palier est sauvegardé")


func test_sector_of_day_rotates() -> void:
	var seen := {}
	for h in range(0, 24 * 3, Data.SECTOR_HOURS):
		_gs._sector_clock = float(h) * 3600.0
		seen[_gs.sector_of_day()] = true
	_check(seen.size() == Data.DEST_ORDER.size(), "le secteur du jour passe par toutes les destinations")
	_gs._sector_clock = 1000.0
	var s0: String = _gs.sector_of_day()
	_gs._sector_clock = 1000.0 + float(Data.SECTOR_HOURS) * 3600.0
	_check(_gs.sector_of_day() != s0, "il change toutes les %d heures" % Data.SECTOR_HOURS)
	_gs._sector_clock = -1.0


func test_live_mode_multipliers() -> void:
	_gs._sector_clock = 5.0 * 3600.0
	var sd: String = _gs.sector_of_day()
	var other := ""
	for d in Data.DEST_ORDER:
		if d != sd:
			other = d
	_check(is_equal_approx(_gs.live_mode_mult(other, false), 1.0), "mode choisi hors secteur : x1")
	_check(is_equal_approx(_gs.live_mode_mult(other, true), 1.5), "Aléatoire hors secteur : x1,5")
	_check(is_equal_approx(_gs.live_mode_mult(sd, false), 1.3), "mode choisi sur le secteur du jour : x1,3")
	_check(is_equal_approx(_gs.live_mode_mult(sd, true), 1.6), "Aléatoire sur le secteur du jour : x1,6 (les bonus ne se cumulent pas)")
	_gs._sector_clock = -1.0


func test_random_mode_available_with_two_ready_modes() -> void:
	_check(_gs.ready_modes() == ["combat", "derive", "route"], "combat, dérive et route sont prêts")
	_check(_gs.random_mode_available(), "le mode Aléatoire a plusieurs modes à tirer")


func test_random_pick_is_weighted_and_never_three_in_a_row() -> void:
	_gs.last_modes = []
	var counts := {"combat": 0, "derive": 0, "route": 0}
	var run := 1
	var prev := ""
	var max_run := 0
	for i in 400:
		var m: String = _gs.pick_random_mode("asteroids")
		_check(counts.has(m), "seuls les modes prêts sont tirés (%s)" % m)
		counts[m] = int(counts.get(m, 0)) + 1
		run = run + 1 if m == prev else 1
		prev = m
		max_run = maxi(max_run, run)
		_gs.note_mode(m)
	_check(max_run <= 2, "jamais trois fois le même mode de suite (série max %d)" % max_run)
	_check(counts.derive > counts.combat * 0.9 and counts.combat > 80 and counts.route > 15 and counts.route < counts.combat * 0.6, "poids : dérive > combat > route sur le champ d'astéroïdes (%s)" % str(counts))


func test_derive_mode_reward_multiplier() -> void:
	_gs._sector_clock = 7.0 * 3600.0         # secteur du jour : l'étoile naine
	_check(is_equal_approx(_gs.live_mode_mult("asteroids", false, "derive"), 1.3), "la dérive rapporte x1,3")
	_check(is_equal_approx(_gs.live_mode_mult("asteroids", true, "derive"), 1.5 * 1.3), "Aléatoire + dérive : x1,5 puis x1,3")
	_check(is_equal_approx(_gs.live_mode_mult("star", true, "derive"), 1.6 * 1.3), "secteur du jour + Aléatoire + dérive")
	_check(is_equal_approx(_gs.live_mode_mult("star", false, "derive"), 1.3 * 1.3), "secteur du jour + dérive")
	_check(is_equal_approx(_gs.live_mode_mult("asteroids", false, "combat"), 1.0), "le combat reste à x1")
	_gs._sector_clock = -1.0


func test_finish_live_derive_message_and_rewards() -> void:
	_gs.new_game()
	_gs._sector_clock = 7.0 * 3600.0
	var cr0: float = _gs.res["credits"]
	var info: Dictionary = _gs.finish_live(0, "asteroids", {"win": true, "time": 40.0, "objectives_done": 1}, false, "derive")
	_check(is_equal_approx(info.mult, 1.3 * 1.1), "dérive x1,3 et un objectif : x1,43")
	_check(String(_gs.slots[0].last).begins_with("Dérive réussie"), "le message annonce la dérive")
	_check(_gs.res["credits"] > cr0, "le butin est ajouté")
	_check(_gs.last_modes == ["derive"], "le mode joué est mémorisé")
	_gs._sector_clock = -1.0


func test_derive_derive_config() -> void:
	_gs.new_game()
	var cfg: Dictionary = _gs.derive_config("asteroids", 0)
	_check(cfg.hull == 1000.0 and cfg.hazards >= 10, "la coque suit le palier du vaisseau et le nombre de dangers la destination")
	_check(_gs.derive_config("planet", 0).hazards >= _gs.derive_config("asteroids", 0).hazards, "plus de dangers sur les destinations difficiles")


func _derive(seed_value: int = 11, cfg: Dictionary = {}) -> DeriveSim:
	var d := DeriveSim.new(seed_value)
	d.setup(cfg)
	return d


func test_derive_setup_is_fair() -> void:
	for sd in 40:
		var d := _derive(100 + sd)
		var haz := 0
		var res := 0
		for c in d.cells:
			if c.haz:
				haz += 1
			if c.res != "":
				res += 1
				_check(not c.haz, "une ressource n'est jamais sur un danger")
		_check(haz == 10 and res == 9, "10 dangers et 9 ressources (%d, %d)" % [haz, res])
		_check(not d.cells[DeriveSim.idx(6, 2)].haz, "la case de départ est sûre")
		for n in DeriveSim.neigh4(6, 2):
			_check(not d.cells[DeriveSim.idx(n[0], n[1])].haz, "les cases voisines du départ sont sûres")


func test_derive_numbers_count_adjacent_hazards() -> void:
	var d := _derive(21)
	for r in DeriveSim.ROWS:
		for c in DeriveSim.COLS:
			var n := 0
			for nb in DeriveSim.neigh8(r, c):
				if d.cells[DeriveSim.idx(nb[0], nb[1])].haz:
					n += 1
			_check(d.cells[DeriveSim.idx(r, c)].num == n, "le chiffre compte les dangers voisins")


func test_derive_scan_costs_energy_and_reveals() -> void:
	var d := _derive(5)
	var e0: float = d.energy
	_check(d.act_scan(5, 2), "scanner une case voisine")
	_check(is_equal_approx(d.energy, e0 - 1.0) and d.cells[DeriveSim.idx(5, 2)].seen, "1 énergie, la case est révélée")
	_check(not d.act_scan(5, 2), "on ne scanne pas deux fois la même case")
	d.step(1.0)
	d.energy = 0.0
	_check(not d.act_scan(5, 3), "sans énergie on ne peut plus scanner")


func test_derive_blind_move_onto_hazard_hurts() -> void:
	var d := _derive(5)
	d.cells[DeriveSim.idx(5, 2)].haz = true
	var h0: float = d.hull
	_check(d.act_move(5, 2), "avancer sur une case inconnue est possible")
	_check(d.hits == 1 and is_equal_approx(d.hull, h0 - roundf(h0 * 0.34)), "un danger heurté retire 34 % de la coque")
	d.busy = 0.0
	d.cells[DeriveSim.idx(6, 2)].haz = false
	_check(d.act_move(6, 2), "on peut repartir vers une case sûre")


func test_derive_known_hazard_is_not_entered() -> void:
	var d := _derive(5)
	d.cells[DeriveSim.idx(5, 2)].haz = true
	d.cells[DeriveSim.idx(5, 2)].seen = true
	_check(not d.act_move(5, 2) and d.hits == 0, "on n'entre pas volontairement sur un danger connu")


func test_derive_extraction_starts_alone_and_collects() -> void:
	var d := _derive(5)
	d.cells[DeriveSim.idx(5, 2)].res = "ene"
	d.cells[DeriveSim.idx(5, 2)].haz = false
	d.cells[DeriveSim.idx(5, 2)].seen = true
	d.energy = 5.0
	d.meteor_t = 999.0
	d.act_move(5, 2)
	for i in 90:
		d.step(1.0 / 30.0)
	_check(d.extracted == 1 and d.loot.ene == 1, "arriver sur une ressource lance l'extraction seule")
	_check(is_equal_approx(d.energy, 9.0), "une énergie récoltée rend 4 points")


func test_derive_extraction_interrupted_by_leaving() -> void:
	var d := _derive(5)
	d.cells[DeriveSim.idx(5, 2)].res = "min"
	d.cells[DeriveSim.idx(5, 2)].haz = false
	d.cells[DeriveSim.idx(5, 2)].seen = true
	d.meteor_t = 999.0
	d.act_move(5, 2)
	for i in 20:
		d.step(1.0 / 30.0)
	_check(d.extracting_at >= 0, "l'extraction est en cours")
	d.extracting_at = -1          # le joueur touche une autre case : l'interface annule
	for i in 90:
		d.step(1.0 / 30.0)
	_check(d.extracted == 0, "une extraction annulée ne rapporte rien")


func test_derive_meteor_destroys_cell_and_resource() -> void:
	var d := _derive(5)
	d.meteor_t = 999.0
	d.cells[DeriveSim.idx(3, 3)].res = "dat"
	d.cells[DeriveSim.idx(3, 3)].haz = false
	d.meteors.append({"r": 3, "c": 3, "t": 0.0})
	for i in 90:
		d.step(1.0 / 30.0)
	var cell: Dictionary = d.cells[DeriveSim.idx(3, 3)]
	_check(cell.destroyed and cell.res == "" and not d.over, "le météore détruit la case et sa ressource")
	d.busy = 0.0
	d.ship = [4, 3]
	_check(not d.act_move(3, 3), "on ne peut plus entrer sur une case détruite")


func test_derive_meteor_on_ship_is_instant_defeat() -> void:
	var d := _derive(5)
	d.meteor_t = 999.0
	d.meteors.append({"r": 6, "c": 2, "t": 0.0})
	for i in 90:
		d.step(1.0 / 30.0)
	_check(d.over and not d.win and d.hull == 0.0 and d.over_reason == "meteor", "un météore sur le vaisseau le pulvérise d'un coup")


func test_derive_meteor_is_announced_before_impact() -> void:
	var d := _derive(5)
	d.meteor_t = 999.0
	d.meteors.append({"r": 3, "c": 3, "t": 0.0})
	for i in 30:        # 1 s : le météore est annoncé mais n'est pas tombé
		d.step(1.0 / 30.0)
	_check(d.meteors.size() == 1 and not d.cells[DeriveSim.idx(3, 3)].destroyed, "le météore est annoncé %.1f s à l'avance" % float(DeriveSim.CFG.meteor_tele))


func test_derive_win_needs_the_minimum_loot() -> void:
	var d := _derive(5)
	d.extracted = 2
	d.act_leave()
	_check(d.over and not d.win and d.over_reason == "leave", "moins de 3 ressources : la dérive est manquée")
	var e := _derive(5)
	e.extracted = 3
	e.act_leave()
	_check(e.win, "3 ressources : la dérive est réussie")


func test_derive_objectives_and_stars() -> void:
	for sd in 30:
		var d := _derive(300 + sd)
		_check(d.objectives.size() == 2 and d.objectives[0] != d.objectives[1], "deux objectifs différents")
	var d2 := _derive(1)
	d2.objectives = ["hull", "loot"]
	d2.extracted = 6
	d2.act_leave()
	var r: Dictionary = d2.result()
	_check(r.win and r.objectives_done == 2, "deux objectifs atteints après une victoire")
	var d3 := _derive(1)
	d3.objectives = ["hull", "loot"]
	d3.extracted = 1
	d3.act_leave()
	_check(d3.result().objectives_done == 0, "pas d'objectif compté après une défaite")


func test_derive_assist_is_slower() -> void:
	var d := DeriveSim.new(5)
	d.setup({"assist": true})
	d.act_scan(5, 2)
	_check(is_equal_approx(d.busy, float(DeriveSim.CFG.scan_time) * 1.3), "l'équipage assisté agit 30 % plus lentement")


func test_derive_bots_stay_under_the_cap() -> void:
	var wins_auto := 0
	var wins_human := 0
	var n := 60
	for i in n:
		for mode in ["auto", "human"]:
			var d := DeriveSim.new(31000 + i * 13)
			d.assist = mode == "auto"
			d.human_bot = mode == "human"
			d.setup({"hull": 1000.0, "assist": mode == "auto"})
			var steps := 0
			while not d.over and steps < 6000:
				d.step(1.0 / 30.0)
				steps += 1
			if not d.over:
				d.finish(false)
			if d.win:
				if mode == "auto":
					wins_auto += 1
				else:
					wins_human += 1
	_check(wins_auto <= 51 and wins_human <= 51, "la dérive reste sous ~85 %% de victoires (auto %d/%d, joueur %d/%d)" % [wins_auto, n, wins_human, n])
	_check(wins_auto >= 30 and wins_human >= 30, "la dérive reste gagnable (auto %d/%d, joueur %d/%d)" % [wins_auto, n, wins_human, n])


func test_finish_live_rewards_and_defeat() -> void:
	_gs.new_game()
	_gs._sector_clock = 7.0 * 3600.0         # secteur du jour : l'étoile naine, donc pas les astéroïdes
	var dest := "asteroids"
	var base_cr: float = _gs.res["credits"]
	var win_info: Dictionary = _gs.finish_live(0, dest, {"win": true, "time": 20.0, "objectives_done": 2}, false)
	var gain_win: float = _gs.res["credits"] - base_cr
	_check(is_equal_approx(win_info.mult, 1.2) and gain_win > 0.0, "victoire avec deux objectifs : butin x1,2 (+10 % par objectif)")
	var cr2: float = _gs.res["credits"]
	_gs.finish_live(0, dest, {"win": false, "time": 20.0, "objectives_done": 0}, false)
	var gain_loss: float = _gs.res["credits"] - cr2
	_check(gain_loss > 0.0 and gain_loss < gain_win * 0.3, "une défaite ne garde qu'un quart du butin de base")
	_check(_gs.expeditions_done == 2, "chaque combat compte comme une expédition")
	_gs._sector_clock = -1.0


func test_finish_live_gives_captain_xp_only_on_victory() -> void:
	_gs.new_game()
	var xp0: int = _gs.captain.xp
	var lv0: int = _gs.captain.level
	_gs.finish_live(0, "asteroids", {"win": false, "time": 10.0, "objectives_done": 0}, false)
	_check(_gs.captain.xp == xp0 and _gs.captain.level == lv0, "pas d'XP après une défaite")
	_gs.finish_live(0, "asteroids", {"win": true, "time": 10.0, "objectives_done": 0}, false)
	_check(_gs.captain.xp != xp0 or _gs.captain.level != lv0, "le Capitaine gagne de l'XP après une victoire")


func test_live_config_gets_harder_when_underpowered() -> void:
	_gs.new_game()
	var weak: Dictionary = _gs.live_config("asteroids", 0)
	_gs.captain.level = 40
	for id in ["weapon", "suit", "helmet", "gloves", "boots", "module"]:
		var it: Dictionary = _gs.make_item(id, "legendary", 150)
		_gs.items.append(it)
		_gs.equipped[id] = it.id
	var strong: Dictionary = _gs.live_config("asteroids", 0)
	_check(weak.hp_scale >= strong.hp_scale and strong.hp_scale >= 1.0, "des ennemis plus durs si le Capitaine est faible, jamais plus faciles que la base")
	_check(weak.use_boss and not _gs.live_config("star", 0).use_boss, "le gardien dépend de la destination")
	_check(_gs.live_chance("asteroids", 0) <= Data.WIN_CHANCE_SAFE, "la chance affichée ne dépasse jamais 80 %")



# ---------- Route ----------

func _route_crew() -> Dictionary:
	return {"pilot": {"name": "Rex", "level": 6, "present": true}, "engineer": {"name": "Gorn", "level": 4, "present": true}, "scientist": {"name": "Lumi", "level": 4, "present": true}}


func _route(seed_v: int, tier: int = 1) -> RouteSim:
	var r := RouteSim.new(seed_v)
	r.setup({"tier": tier, "hp_scale": 1.0, "dmg_scale": 1.0, "cap_level": 20, "crew": _route_crew()})
	return r


func test_route_map_is_valid_and_varied() -> void:
	var sigs := {}
	var lens := {}
	for i in 200:
		var r := _route(1000 + i * 31)
		var n: int = r.meta.layers
		lens[n] = true
		_check(n >= 7 and n <= 11, "7 à 11 couches (%d)" % n)
		_check(r.nodes[0].type == "depart" and r.nodes[r.nodes.size() - 1].type == "gardien", "départ et gardien aux extrémités")
		# toutes les étapes sont atteignables depuis le départ et mènent au gardien
		var seen := {0: true}
		var queue: Array = [0]
		while not queue.is_empty():
			var cur: int = queue.pop_back()
			for nx in r.nodes[cur].next:
				if not seen.has(nx):
					seen[nx] = true
					queue.append(nx)
		_check(seen.size() == r.nodes.size(), "toutes les étapes sont atteignables (graine %d)" % i)
		for nd in r.nodes:
			if nd.type != "gardien":
				_check(not nd.next.is_empty(), "chaque étape mène quelque part")
		var kinds := ""
		for nd in r.nodes:
			kinds += String(nd.type)[0]
		sigs["%d|%s|%s|%s|%s|%s" % [n, r.meta.shape, r.meta.theme.id, r.meta.mod.id, r.meta.guard.name, kinds]] = true
	_check(sigs.size() >= 195, "les voyages ne se ressemblent pas (%d différents sur 200)" % sigs.size())
	_check(lens.size() == 5, "toutes les longueurs de 7 à 11 apparaissent")


func test_route_same_seed_same_voyage() -> void:
	var a := _route(777)
	var b := _route(777)
	_check(a.nodes.size() == b.nodes.size() and a.meta.name == b.meta.name and a.meta.theme.id == b.meta.theme.id, "même graine, même secteur")
	for i in a.nodes.size():
		_check(a.nodes[i].type == b.nodes[i].type and a.nodes[i].next == b.nodes[i].next, "même carte")


func test_route_flow_rules() -> void:
	var r := _route(4321)
	# on se déplace seulement vers une étape voisine
	var far: int = r.nodes.size() - 1
	_check(not r.go_to(far), "on ne saute pas vers une étape lointaine")
	var first: int = r.nodes[0].next[0]
	_check(r.go_to(first), "on peut aller vers une étape voisine")
	_check(not r.go_to(first), "pas de déplacement tant que l'étape n'est pas réglée (sauf carte)")
	# récolte
	r.phase = "harvest"
	var before := r.total_loot()
	r.harvest("min")
	_check(r.total_loot() > before and r.phase == "map", "la récolte remplit la soute")
	# repos : seul lui soigne, et il rend de la coque et des PV à l'équipage
	r.hull = 30.0
	r.crew.pilot.hp = 40.0
	r.phase = "rest"
	r.rest()
	_check(r.hull == 70.0 and r.crew.pilot.hp == 90.0 and r.rests == 1, "le repos soigne la coque et l'équipage")
	# événement : l'option sans risque ne coûte rien ; un échec peut blesser
	r.phase = "event"
	r.event = RouteSim.EVENTS[0]
	var res := r.pick_option(2)
	_check(res.ok and r.hull == 70.0, "passer son chemin est sans risque")
	r.phase = "event"
	r.event = RouteSim.EVENTS[0]
	var inj := r.injuries
	r.pick_option(0, 0.999)
	_check(r.injuries == inj + 1, "forcer les soutes en cas d'échec blesse un équipier")
	r.phase = "event"
	r.event = RouteSim.EVENTS[0]
	r.pick_option(0, 0.0)
	_check(r.events_won == 1 and int(r.loot.min) >= 34, "un succès rapporte le butin de l'option")


func test_route_event_chances_depend_on_crew_and_mod() -> void:
	var r := _route(99)
	var opt: Dictionary = RouteSim.EVENTS[0].opts[0]
	r.meta.mod = RouteSim.MODS[3]       # équipage motivé
	var p_good: float = r.option_chance(opt)
	r.meta.mod = RouteSim.MODS[0]       # orage magnétique
	var p_storm: float = r.option_chance(opt)
	_check(p_good > p_storm + 0.1, "l'orage baisse les chances, l'équipage motivé les monte (%f / %f)" % [p_good, p_storm])
	r.meta.mod = RouteSim.MODS[1]
	var p_ok: float = r.option_chance(opt)
	r.crew.engineer.hp = 20.0
	_check(r.option_chance(opt) < p_ok, "un équipier blessé a moins de chances")
	r.crew.engineer.present = false
	_check(r.option_chance(opt) < p_ok, "sans équipier au poste, le Capitaine s'en charge moins bien")
	_check(r.option_chance(RouteSim.EVENTS[0].opts[2]) == 1.0, "l'option sans risque est sûre")


func test_route_fight_cfg_and_hull_carries_over() -> void:
	var r := _route(2024, 2)
	r.phase = "combat"
	r.at = 1
	r.nodes[1].type = "combat"
	var cfg: Dictionary = r.fight_cfg()
	_check(cfg.waves == [0, 1] and not cfg.use_boss and cfg.hull_frac == 1.0, "un combat ordinaire joue deux vagues, coque pleine")
	r.hull = 45.0
	_check(is_equal_approx(r.fight_cfg().hull_frac, 0.45), "la coque se garde d'un combat à l'autre")
	r.nodes[1].type = "gardien"
	_check(r.fight_cfg().use_boss and r.fight_cfg().waves == [3, 4], "le gardien joue la dernière vague avec le boss")
	# LiveSim : la coque de départ et le nombre de vagues suivent la config
	var s := LiveSim.new(5)
	s.setup({"tier": 1, "waves": [0, 1], "hull_frac": 0.5})
	_check(is_equal_approx(s.hull, s.hull_max * 0.5) and s.wave_total == 2, "LiveSim démarre à mi-coque, deux vagues")
	s.human_bot = true
	var steps := 0
	while not s.over and steps < 20000:
		s.step(1.0 / 30.0)
		steps += 1
	_check(s.over and s.result().has("hull_frac") and s.result().hull_frac <= 0.5 + 0.001, "le résultat donne la coque restante")


func test_route_apply_fight_and_end_rules() -> void:
	var r := _route(555)
	r.phase = "combat"
	r.at = 1
	r.nodes[1].type = "combat"
	r.meta.mod = RouteSim.MODS[4]       # eaux calmes : -25 % de dégâts de coque
	var txt := r.apply_fight({"win": true, "hull_frac": 0.6, "time": 30.0})
	_check(is_equal_approx(r.hull, 70.0) and r.phase == "map" and txt.find("Combat gagné") >= 0, "eaux calmes : 40 points perdus comptés pour 30 (%f)" % r.hull)
	_check(int(r.loot.min) > 0, "un combat gagné rapporte du butin")
	# défaite : le voyage se termine
	r.phase = "combat"
	r.apply_fight({"win": false, "hull_frac": 0.0, "time": 10.0})
	_check(r.over and not r.win and r.phase == "end", "une défaite termine le voyage")
	# gardien vaincu : voyage réussi
	var g := _route(556)
	g.at = g.nodes.size() - 1
	g.phase = "combat"
	g.apply_fight({"win": true, "hull_frac": 0.5, "time": 40.0})
	_check(g.over and g.win, "le gardien vaincu réussit le voyage")
	_check(g.result().route_mult > 1.0, "un voyage réussi a un multiplicateur de gains")


func test_route_objectives_and_reward() -> void:
	var r := _route(31)
	_check(r.objectives.size() == 2 and r.objectives[0] != r.objectives[1], "deux objectifs différents par voyage")
	r.objectives = ["hull", "noinj"]
	r.hull = 80.0
	_check(r.objectives_done() == 2, "coque à 80 % et aucun blessé : deux objectifs")
	r.hull = 50.0
	r.injuries = 1
	_check(r.objectives_done() == 0, "coque à 50 % et un blessé : aucun objectif")
	# récompense : thème, longueur et soute se cumulent ; la soute ne change que de ±20 %
	var low := _route(32)
	var high := _route(32)
	high.loot = {"min": 300, "dat": 100, "ene": 100}
	_check(high.route_mult() > low.route_mult() and high.route_mult() <= low.route_mult() * 1.5 + 0.001, "la soute améliore un peu le gain")


func test_finish_live_route_rewards_and_message() -> void:
	_gs.reset()
	# le « secteur du jour » (+30 %) change avec l'heure : on fige une horloge où ce n'est pas les astéroïdes
	_gs._sector_clock = 1.0e9
	while _gs.sector_of_day() == "asteroids":
		_gs._sector_clock += float(Data.SECTOR_HOURS) * 3600.0
	var base: Dictionary = _gs.rewards_of("asteroids", 0)
	var before: float = _gs.res["minerals"]
	var res := {"win": true, "time": 120.0, "objectives_done": 1, "route_mult": 1.6, "steps": 8}
	var info: Dictionary = _gs.finish_live(0, "asteroids", res, false, "route")
	_check(info.win and is_equal_approx(info.mult, 1.6 * 1.1), "gain route = multiplicateur du voyage x objectifs (%f)" % info.mult)
	_check(String(_gs.slots[0].last).begins_with("Voyage réussi en 8 étapes"), "message de voyage réussi : %s" % _gs.slots[0].last)
	_check(_gs.res["minerals"] > before + base.get("minerals", 0.0), "le butin est versé")
	var lost := {"win": false, "time": 60.0, "objectives_done": 0, "route_mult": 1.7, "steps": 3}
	_gs.finish_live(0, "asteroids", lost, false, "route")
	_check(String(_gs.slots[0].last).begins_with("Voyage interrompu"), "message de voyage interrompu : %s" % _gs.slots[0].last)
	_gs._sector_clock = -1.0


func test_route_config_uses_the_squad() -> void:
	_gs.reset()
	_gs.give_hero("rex", 9)
	_gs.give_hero("gorn", 7)
	_gs.auto_squad(0)
	var cfg: Dictionary = _gs.route_config("planet", 0)
	_check(cfg.crew.pilot.present and cfg.crew.pilot.level == 9, "le pilote du vaisseau est dans la config")
	_check(cfg.crew.engineer.present and cfg.crew.engineer.level == 7, "l'ingénieur aussi")
	_check(not cfg.crew.scientist.present, "sans scientifique, le poste est vide")
	_check(cfg.cap_level == int(_gs.captain.level) and cfg.has("tier") and cfg.has("hp_scale"), "niveau du Capitaine et réglages de combat")


func test_route_bots_stay_under_the_cap() -> void:
	var n := 30
	for tier in [0, 2, 4]:
		for human in [false, true]:
			var wins := 0
			for i in n:
				var r := _route(9100 + i * 7919, tier)
				var counter := [0]
				var fb := func(cfg: Dictionary) -> Dictionary:
					counter[0] += 1
					var s := LiveSim.new(500 + i * 104729 + counter[0])
					cfg["assist"] = not human
					s.human_bot = human
					s.setup(cfg)
					var steps := 0
					while not s.over and steps < 20000:
						s.step(1.0 / 30.0)
						steps += 1
					return s.result()
				var guard := 0
				while not r.over and guard < 200:
					guard += 1
					if not r.auto_step(fb):
						break
				if r.win:
					wins += 1
			_check(wins <= int(n * 0.87), "la route reste sous ~85 %% de victoires (palier %d, %s : %d/%d)" % [tier + 1, "joueur" if human else "auto", wins, n])
			_check(wins >= int(n * 0.3), "la route reste gagnable (palier %d, %s : %d/%d)" % [tier + 1, "joueur" if human else "auto", wins, n])


func test_route_abstract_flow_finishes() -> void:
	for i in 40:
		var r := _route(7000 + i)
		var guard := 0
		while not r.over and guard < 200:
			guard += 1
			r.auto_step(func(cfg: Dictionary) -> Dictionary:
				return {"win": true, "hull_frac": maxf(0.0, r.hull - 12.0) / 100.0, "time": 10.0})
		_check(r.over, "le voyage finit toujours (graine %d)" % i)


func test_route_ui_builds_every_panel() -> void:
	var RouteUI = load("res://scripts/route_ui.gd")
	_gs.reset()
	_gs.give_hero("rex", 5)
	_gs.give_hero("lumi", 5)
	_gs.auto_squad(0)
	var ui: Control = RouteUI.new()
	root.add_child(ui)
	ui.begin(0, "asteroids", _gs.route_config("asteroids", 0), false, 1.0, 1234)
	_check(ui._action.get_child_count() >= 0 and ui.sim.phase == "map", "l'écran démarre sur la carte")
	for phase in ["map", "event", "combat", "harvest", "rest"]:
		ui.sim.phase = phase
		if phase == "event":
			ui.sim.event = RouteSim.EVENTS[2]
		if phase == "combat":
			ui.sim.at = 1
			ui.sim.nodes[1].type = "combat"
		ui._clear_action()
		ui._build_action()
		_check(ui._action.get_child_count() > 0, "le panneau « %s » se construit" % phase)
	ui.sim.phase = "map"
	ui.sim.hull = 0.0
	ui._abandon()
	_check(ui._settled and ui._result.visible and ui._res_title.text.find("ABANDONNÉ") >= 0, "l'abandon règle le voyage et montre le résultat")
	_check(String(_gs.slots[0].last).begins_with("Voyage interrompu"), "le butin réduit est annoncé")
	ui.free()
