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
	_check(_gs.gain_captain_xp(Data.xp_needed(lv) + 1) == 1 and _gs.captain.level == lv + 1, "assez d'XP : niveau +1")


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
	_check(is_equal_approx(_gs.offline_efficiency(), Data.OFFLINE_BASE_EFFICIENCY), "rendement de base hors ligne")
	_check(is_equal_approx(_gs.offline_cap_seconds(), Data.OFFLINE_BASE_HOURS * 3600.0), "durée de base hors ligne")
	_gs.give_hero("rex", 10)
	_gs.give_hero("bolt", 10)
	_work(["rex", "bolt"])
	_check(_gs.offline_efficiency() > Data.OFFLINE_BASE_EFFICIENCY, "l'équipage au travail améliore le rendement")
	_check(_gs.offline_cap_seconds() > Data.OFFLINE_BASE_HOURS * 3600.0, "les Ingénieurs allongent la durée hors ligne")
	_gs.give_hero("lumi", 200)
	_work(["lumi"])
	_check(_gs.offline_efficiency() <= Data.OFFLINE_EFF_MAX and _gs.offline_cap_seconds() <= Data.OFFLINE_MAX_HOURS * 3600.0, "plafonds respectés")
	var it := _item("gloves", "rare", 5, [{"k": "offline_pct", "v": 8.0}])
	var eff0: float = _gs.offline_efficiency()
	_gs.add_item(it)
	_gs.equip(it.id)
	_check(_gs.offline_efficiency() >= eff0, "un affixe « gains hors ligne » ne baisse pas le rendement")


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
	_check(_gs.afk_level() > 100, "niveau d'AFK (%d)" % _gs.afk_level())
	var w1: Dictionary = _gs.drop_weights(1)
	var share0: float = w0["legendary"] / (w0["common"] + w0["uncommon"] + w0["rare"] + w0["epic"] + w0["legendary"])
	var share1: float = w1["legendary"] / (w1["common"] + w1["uncommon"] + w1["rare"] + w1["epic"] + w1["legendary"])
	_check(share1 > share0 * 3.0, "la part de légendaires explose avec le niveau d'AFK (%.3f -> %.3f)" % [share0, share1])
	_check(_gs.loot_level() > l0 + 8, "le niveau d'objet monte aussi")
	_check(w1["common"] / w0["common"] < 1.01, "les communs ne bénéficient pas du niveau d'AFK")


func test_anomalies_basics() -> void:
	_gs.new_game()
	_check(_gs.anomaly_unlocked_max() == 1 and _gs.anomaly_charges >= 7.9, "failles : la 1re est ouverte, charges pleines")
	_check(not _gs.enter_anomaly(2), "la faille 2 est fermée")
	var xp0: int = _gs.captain.xp
	var c0: float = _gs.res["credits"]
	_check(_gs.enter_anomaly(1), "entrée dans la faille 1")
	_check(_gs.last_anomaly.win, "victoire au niveau 1")
	_check(_gs.anomaly_max == 1 and _gs.anomaly_unlocked_max() == 2, "la faille 2 s'ouvre")
	_check(_gs.captain.xp > xp0 or _gs.captain.level > 1, "le Capitaine gagne de l'XP")
	_check(_gs.res["credits"] > c0 and _gs.anomaly_best.has(1), "crédits et record enregistrés")
	_check(is_equal_approx(_gs.anomaly_charges, Data.ANOMALY_CHARGES_MAX - 1.0), "une charge dépensée")
	_check(_gs.last_anomaly.first and not _gs.last_anomaly.found.is_empty(), "1re réussite : bonus de ressources")
	_check(_gs.enter_anomaly(1) and not _gs.last_anomaly.first, "refaire la faille 1")


func test_anomaly_defeat_refunds_charge() -> void:
	_gs.new_game()
	_gs.anomaly_max = 60
	var ch: float = _gs.anomaly_charges
	_check(_gs.enter_anomaly(61), "entrée dans une faille trop forte")
	_check(not _gs.last_anomaly.win, "défaite")
	_check(is_equal_approx(_gs.anomaly_charges, ch), "la charge est rendue")
	_check(_gs.anomaly_max == 60 and _gs.last_anomaly.xp == 0, "aucun progrès, aucune perte")


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
	var it := _item("weapon", "epic", 9, [{"k": "atk_pct", "v": 6.5}, {"k": "crit", "v": 3.2}, {"k": "offline_pct", "v": 4.0}])
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
	_check(_gs.base_power() == 120 and gain == 16, "120 niveaux de salles promettent 16 éclats (%d)" % gain)
	var cap_before: float = _gs.captain_stats(0).atk
	_check(_gs.do_prestige() == gain and _gs.prestige_points == gain and _gs.prestige_count == 1, "la refonte donne les éclats")
	_check(_gs.room_level("mine") == 1 and _gs.upgrade_levels["laser"] == 0, "salles et améliorations remises à zéro")
	_check(_gs.upgrade_levels["docks"] == 1, "le 2e vaisseau est conservé")
	_check(_gs.heroes["rex"].level == 40, "les niveaux d'équipage sont conservés")
	_check(is_equal_approx(_gs.res.credits, Data.START_CREDITS), "ressources remises au départ")
	_check(_gs.slots[0].dest == "", "l'expédition en cours est rappelée")
	_check(is_equal_approx(_gs.captain_stats(0).atk, cap_before), "le Capitaine n'est pas affaibli")
	_check(_gs.prestige_block_reason() != "" and _gs.do_prestige() == 0, "pas de refonte en boucle : il faut remonter les salles")


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


func test_no_level_cap() -> void:
	_gs.new_game()
	_gs.captain.level = 100
	_gs.captain.xp = 0
	var gained: int = _gs.gain_captain_xp(Data.xp_needed(100) * 3)
	_check(gained >= 2 and _gs.captain.level >= 102, "pas de plafond : l'XP continue de donner des niveaux (%d)" % _gs.captain.level)
	_gs.give_hero("rex", 90)
	var lv: int = _gs.heroes["rex"].level
	_gs.gain_xp("rex", Data.xp_needed(lv) + 1)
	_check(_gs.heroes["rex"].level == lv + 1, "équipage : pas de plafond non plus")


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
	_check(_gs.offline_efficiency() > eff0 + 0.05, "et améliore le rendement")
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
