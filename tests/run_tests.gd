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
	for id in Data.STARTER:
		out.append({"id": id, "level": level})
	return out


func test_data_is_consistent() -> void:
	_check(Data.STARTER.size() == 5 and Data.ALL_HEROES.size() == 15, "cinq héros de départ, quinze au total")
	var counts := {"common": 0, "rare": 0, "epic": 0}
	for id in Data.ALL_HEROES:
		counts[Data.HEROES[id].rarity] += 1
	_check(counts.common == 5 and counts.rare == 6 and counts.epic == 4, "5 communs, 6 rares, 4 épiques")
	for id in Data.ALL_HEROES:
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
	_check(_boss_kinds(20) == ["sentinelle"] and _boss_kinds(30) == ["reine"] and _boss_kinds(40) == ["titan"], "un gros boss différent tous les 10 étages, en boucle")
	_check(Data.boss_name(20) == "Sentinelle prismatique" and Data.boss_name(5) == "Foreur éclaté" and Data.boss_name(4) == "", "noms des boss")


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
	_g.auto_recycle = false
	_g.credits = 0.0
	_g.stage = 1
	var chest: Dictionary = _g.stage_cleared(3)
	_check(chest.rarity == "normal" and _g.credits > 0.0 and _g.shards > 0, "un étage vaincu en 3 étoiles donne un coffre normal")
	_check(_g.best_stage == 2 and _g.stars[1] == 3, "l'étage suivant se débloque et les étoiles sont gardées")
	# butin différé : rien n'est versé avant l'ouverture
	_g.credits = 0.0
	_g.shards = 0
	_g.stage = 2
	var held: Dictionary = _g.stage_cleared(3, 1, true)
	_check(_g.credits == 0.0 and _g.shards == 0 and not _g.pending_chest.is_empty(), "le coffre en attente ne verse rien avant l'ouverture")
	_g.claim_pending()
	_check(is_equal_approx(_g.credits, held.credits) and _g.shards == int(held.shards) and _g.pending_chest.is_empty(), "l'ouverture verse le butin une seule fois")
	_g.claim_pending()
	_check(is_equal_approx(_g.credits, held.credits), "pas de double versement")


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


func test_perseverance() -> void:
	_check(_g.perseverance == 0 and _g.team()[0].bonus == 1.0, "pas de bonus au départ")
	for i in 8:
		_g.defeated()
	_check(_g.perseverance == Data.PERSEVERANCE_MAX and _g.perseverance_pct() == 30, "persévérance plafonnée à +30 %")
	_check(is_equal_approx(_g.team()[0].bonus, 1.3), "la persévérance gonfle les statistiques")
	var weak := BattleSim.new(_team(1), 12, 3)
	var strong_team: Array = _g.team()
	var boosted := BattleSim.new(strong_team, 12, 3)
	var hp_a := 0.0
	var hp_b := 0.0
	for u in weak.allies():
		hp_a += u.max_hp
	for u in boosted.allies():
		hp_b += u.max_hp
	_check(hp_b > hp_a * 1.25, "les PV augmentent de 30 % en simulation")
	_g.stage = 1
	_g.stage_cleared(3)
	_check(_g.perseverance == 0, "une victoire remet la persévérance à zéro")


func test_boosts() -> void:
	var base := BattleSim.new(_team(5), 4, 2)
	var tir := BattleSim.new(_team(5), 4, 2, ["tir", "bouclier", "pouvoirs", "vitalite", "butin"])
	var a: BattleSim.Unit = base.allies()[0]
	var b: BattleSim.Unit = tir.allies()[0]
	_check(b.interval < a.interval * 0.81 and b.skill_max < a.skill_max * 0.76, "tir et pouvoirs accélérés")
	_check(b.max_hp > a.max_hp * 1.19 and b.shield > 0.0, "vitalité et bouclier de départ")
	_check(is_equal_approx(tir.gold_mult, 1.25), "butin doré")
	var offer: Array = _g.offer_boosts()
	_check(offer.size() == 3 and offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2], "trois renforts distincts proposés")
	_g.add_boost("tir")
	_g.stage = 5
	_g.best_stage = 5
	_g.stage_cleared(3)
	_check(_g.boosts.is_empty(), "les renforts disparaissent après un boss")


func test_evolution_gate() -> void:
	_g.levels["mara"] = 10
	_g.credits = 1.0e6
	_check(_g.at_cap("mara") and _g.needs_star("mara") and not _g.level_up("mara"), "à 1★ le niveau 10 est la limite")
	_check(not _g.star_up("mara"), "pas d'étoile sans doublons")
	_g.fragments["mara"] = 5
	_check(_g.star_up("mara") and _g.hero_stars["mara"] == 2 and _g.tier("mara") == 1 and _g.fragments["mara"] == 0, "5 doublons : 2★")
	_check(not _g.at_cap("mara") and _g.level_up("mara"), "à 2★ on monte jusqu'au niveau 20")
	_g.levels["mara"] = 20
	_check(_g.at_cap("mara") and not _g.level_up("mara"), "à 2★ le niveau 20 est la limite")
	var evo := BattleSim.new(_g.team(), 3, 1)
	var plain := BattleSim.new(_team(11), 3, 1)
	var m1: BattleSim.Unit = evo.allies()[0]
	var m2: BattleSim.Unit = plain.allies()[0]
	_check(m1.evo == 1 and m1.atk > m2.atk * 1.05, "les statistiques montent de 10 %")


func test_combo() -> void:
	var s := BattleSim.new(_team(8), 12, 1)
	s.auto_cast = false
	for i in 120:
		s.step(0.05)
	_check(s.cast(0) and s.combo == 1, "un premier pouvoir démarre l'enchaînement")
	s.step(0.5)
	_check(s.cast(1) and s.combo == 2 and s.max_combo == 2, "deux pouvoirs rapprochés forment un combo")
	var got := false
	for e in s.events:
		got = got or e.type == "combo"
	_check(got, "un événement de combo est émis")
	for i in 100:
		s.step(0.05)
	_check(s.cast(2) and s.combo == 1, "l'enchaînement retombe après 3 s")
	_check(Data.combo_mult(2) > 1.09 and Data.combo_mult(20) <= 1.5 and Data.combo_loot(20) <= 0.25, "bonus plafonnés")


func test_save_v3() -> void:
	_g.perseverance = 3
	_g.boosts = ["tir", "butin"]
	_g.hero_stars["kai"] = 3
	_g.wild = 7
	_g.save_game()
	_g.reset()
	_check(_g.load_game(), "rechargement v3")
	_check(_g.perseverance == 3 and _g.boosts == ["tir", "butin"] and _g.tier("kai") == 2 and _g.wild == 7, "persévérance, renforts, étoiles et doublons au choix conservés")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))


func test_boss_variants_skills() -> void:
	# la Sentinelle touche toute l'escouade ; la Reine appelle des mites ; les deux passent en phase 2
	var sent := BattleSim.new(_team(15), 20, 1)
	sent.wave = 2
	sent._spawn_wave()
	var b: BattleSim.Unit
	for u in sent.enemies():
		if u.kind == "sentinelle":
			b = u
	_check(b != null and b.skill_kind == "prism" and b.ranged, "la Sentinelle tire à distance avec son faisceau")
	b.skill_cd = 0.0
	sent.cast_enemy(b)
	var hits := 0
	for p in sent.pending:
		if p.src == b:
			hits += 1
	_check(hits >= 5, "le faisceau vise chaque héros, plus le plus fragile")
	var reine := BattleSim.new(_team(15), 30, 1)
	reine.wave = 2
	reine._spawn_wave()
	var q: BattleSim.Unit
	for u in reine.enemies():
		if u.kind == "reine":
			q = u
	for u in reine.enemies():
		if u != q:
			u.alive = false
	var before := reine.enemies().size()
	reine.cast_enemy(q)
	_check(reine.enemies().size() == before + 2, "la Reine appelle deux mites")
	q.hp = q.max_hp * 0.4
	reine._apply_hit({"dst": q, "dmg": 1.0, "fx": ""})
	_check(q.phase2, "la Reine passe en phase 2")


func test_collection_and_recruit() -> void:
	_check(_g.owned.size() == 5 and _g.squad == Data.STARTER and _g.tokens == 6, "départ : cinq héros, escouade de départ, six jetons")
	_g.tokens = 2
	_check(_g.recruit(1).is_empty() and _g.tokens == 2, "pas de recrutement sans assez de jetons")
	_g.tokens = 30
	var res: Array = _g.recruit(10)
	_check(res.size() == 10 and _g.tokens == 3 and _g.pulls == 10, "dix tirages coûtent 27 jetons")
	var news := 0
	var frags := 0
	for r in res:
		_check(Data.HEROES.has(r.id) and Data.HEROES[r.id].rarity == r.rarity, "le héros tiré correspond à la rareté")
		if r.new:
			news += 1
		frags += int(r.fragments)
	_check(_g.owned.size() == 5 + news, "les nouveaux héros rejoignent la collection")
	if frags > 0:
		var any := 0
		for id in Data.ALL_HEROES:
			any += int(_g.fragments[id])
		_check(any == frags and frags % Data.DUP_COPIES == 0, "un tirage en double donne 5 doublons")


func test_recruit_rates_and_pity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts := {"common": 0, "rare": 0, "epic": 0}
	var pity := {"rare": 0, "epic": 0}
	var n := 20000
	var worst_gap := 0
	var gap := 0
	for i in n:
		var r := Data.roll_recruit(rng, pity)
		counts[r] += 1
		if r == "common":
			gap += 1
			worst_gap = maxi(worst_gap, gap)
		else:
			gap = 0
	_check(float(counts.epic) / n > 0.04 and float(counts.epic) / n < 0.075, "environ 5 %% d'épiques (%.3f)" % (float(counts.epic) / n))
	_check(float(counts.rare) / n > 0.2 and float(counts.rare) / n < 0.32, "environ 25 %% de rares (%.3f)" % (float(counts.rare) / n))
	_check(worst_gap < Data.PITY_RARE, "un rare ou mieux au plus tard au 10e tirage")
	var p2 := {"rare": 0, "epic": Data.PITY_EPIC - 1}
	_check(Data.roll_recruit(rng, p2) == "epic" and p2.epic == 0, "épique garanti au 30e tirage")


func test_stars_and_squad() -> void:
	_g.fragments["mara"] = 5
	_check(_g.can_star_up("mara") and _g.star_up("mara") and _g.hero_stars["mara"] == 2 and _g.fragments["mara"] == 0, "5 doublons : deuxième étoile")
	_check(not _g.can_star_up("mara") and _g.star_cost("mara") == 10, "il en faut 10 pour la troisième")
	# doublons au choix : dépensés après ceux du héros
	_g.fragments["mara"] = 4
	_g.wild = 8
	_check(_g.can_star_up("mara") and _g.star_up("mara") and _g.hero_stars["mara"] == 3 and _g.fragments["mara"] == 0 and _g.wild == 2, "10 doublons dont 6 au choix : 3★")
	_check(Data.STAR_COSTS == [5, 10, 20, 40, 100] and Data.level_cap(1) == 10 and Data.level_cap(3) == 30 and Data.level_cap(5) == 50, "5, 10, 20, 40, 100 doublons ; 10 niveaux par étoile")
	_g.hero_stars["mara"] = 5
	_g.wild = 100
	_check(_g.star_up("mara") and _g.hero_stars["mara"] == 6 and Data.level_cap(6) == 50 and not _g.can_star_up("mara"), "« 5★ max » à 100 doublons, limite de niveau inchangée")
	_g.wild = 0
	_g.hero_stars["mara"] = 3
	_check(Data.star_mult(3) > Data.star_mult(2) and is_equal_approx(Data.star_mult(1), 1.0), "chaque étoile renforce")
	var a: BattleSim.Unit = BattleSim.new(_g.team(), 3, 1).allies()[0]
	_g.hero_stars["mara"] = 1
	var b: BattleSim.Unit = BattleSim.new(_g.team(), 3, 1).allies()[0]
	_check(a.max_hp > b.max_hp * 1.1, "les étoiles augmentent les PV en combat")
	_g.owned["sora"] = true
	_check(_g.set_slot(2, "sora") and _g.squad[2] == "sora" and _g.squad.size() == 5, "un héros possédé entre dans l'escouade")
	_g.set_slot(0, "sora")
	_check(_g.squad[0] == "sora" and _g.squad[2] == "mara", "placer un héros déjà présent échange les emplacements")
	_check(not _g.set_slot(1, "omega"), "un héros non possédé ne peut pas entrer")


func test_synergies() -> void:
	var start: Dictionary = Data.synergies(Data.STARTER)
	_check(start.list.size() >= 4, "l'escouade de départ a plusieurs synergies")
	var mono: Dictionary = Data.synergies(["kai", "dax", "mara", "vance", "sora"])
	_check(mono.mods.atk > 1.2, "cinq humains : bonus d'attaque élevé")
	var none: Dictionary = Data.synergies(["kai"])
	_check(none.list.is_empty() and is_equal_approx(none.mods.hp, 1.0), "un héros seul : aucune synergie")
	var hp0: float = BattleSim.new(_team(5), 3, 1).allies()[0].max_hp
	_g.levels["mara"] = 5
	var team: Array = _g.team()
	var hp1: float = BattleSim.new(team, 3, 1).allies()[0].max_hp
	_check(hp1 > hp0, "les synergies s'appliquent en combat")


func test_all_heroes_fight() -> void:
	for id in Data.ALL_HEROES:
		var t: Array = [{"id": id, "level": 5}, {"id": "mara", "level": 5}, {"id": "t9", "level": 5}, {"id": "kai", "level": 5}, {"id": "oru", "level": 5}]
		var s := BattleSim.new(t, 2, 1)
		s.run(120.0)
		_check(s.state == "clear" or s.state == "defeat", "%s combat jusqu'au bout" % id)


func test_item_packs() -> void:
	_g.reset()
	_g.best_stage = 15
	_g.item_tokens = 1
	_check(_g.open_item_packs(1).is_empty() and _g.item_tokens == 1, "pas de caisse sans assez de jetons d'objet")
	_g.item_tokens = 40
	var one: Array = _g.open_item_packs(1)
	_check(one.size() == 1 and _g.item_tokens == 38 and _g.item_pulls.size() == 1, "une caisse coûte 2 jetons d'objet")
	var ten: Array = _g.open_item_packs(10)
	var has_rare := false
	for r in ten:
		if Items.rarity_index(r.item.rarity) >= 2:
			has_rare = true
	_check(ten.size() == 10 and _g.item_tokens == 20 and has_rare, "dix caisses coûtent 18 jetons et donnent un objet rare ou mieux")
	_check(_g.item_pulls.size() == 6, "les six derniers objets sont gardés")
	# garanties : épique au plus tard à la 10e, légendaire à la 40e
	var pity := {"epic": 0, "leg": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var since_epic := 0
	var since_leg := 0
	var worst_epic := 0
	var worst_leg := 0
	for i in 4000:
		var r := Items.roll_pack_rarity(rng, pity)
		since_epic = 0 if Items.rarity_index(r) >= 3 else since_epic + 1
		since_leg = 0 if Items.rarity_index(r) >= 4 else since_leg + 1
		worst_epic = maxi(worst_epic, since_epic)
		worst_leg = maxi(worst_leg, since_leg)
	_check(worst_epic <= 9 and worst_leg <= 39, "garanties épique 10 et légendaire 40")
	_g.crystals = 100
	var it0: int = _g.item_tokens
	_check(_g.buy("itokens6") != "" and _g.item_tokens == it0 + 6 and _g.crystals == 92, "six jetons d'objet coûtent 8 cristaux")
	var ch: Dictionary = _g.open_chest("rare", 5, 0.0, false, true)
	_check(int(ch.item_tokens) == 1 and _g.item_tokens == it0 + 7, "un gros boss donne un jeton d'objet")
	_g.save_game()
	var g2: Node = load("res://scripts/game.gd").new()
	g2.save_path = _g.save_path
	g2.load_game()
	_check(g2.item_tokens == _g.item_tokens and g2.item_pulls.size() == _g.item_pulls.size(), "jetons d'objet et derniers objets sauvegardés")
	g2.free()


func test_boosts_reach_battle() -> void:
	_g.reset()
	var bv: Node2D = load("res://scripts/battle.gd").new()
	bv.start(_g.team(), 3, true, ["vitalite", "tir"])
	var base := BattleSim.new(_g.team(), 3, 1)
	var hp_with := 0.0
	var hp_without := 0.0
	for u in bv.sim.units:
		if u.side == 0:
			hp_with += u.max_hp
	for u in base.units:
		if u.side == 0:
			hp_without += u.max_hp
	_check(is_equal_approx(hp_with, hp_without * 1.2), "les renforts choisis s'appliquent au combat affiché")
	bv.free()


func test_story() -> void:
	_g.reset()
	var seen: Array = []
	_check(Story.pending(seen, 1, 1).get("id", "") == "c1_entree", "scène d'entrée avant l'étage 1")
	seen.append("c1_entree")
	_check(Story.pending(seen, 4, 4).is_empty(), "pas de scène avant d'avoir vaincu l'étage 4")
	_check(Story.pending(seen, 5, 5).get("id", "") == "c1_soleil", "scène après l'étage 4")
	seen.append("c1_soleil")
	_check(Story.pending(seen, 3, 5).is_empty(), "pas de scène « avant » en farmant un étage déjà passé")
	for sc in Story.SCENES:
		for l in sc.lines:
			_check(Story.SPEAKERS.has(String(l.who)) or Data.HEROES.has(String(l.who)), "personnage connu : %s" % l.who)
			if l.has("choice"):
				_check(l.choice.size() == 2 and l.replies.size() == 2, "deux réponses et deux répliques : %s" % sc.id)
	_g.see_scene("c1_haut", 1)
	var r1: Dictionary = _g.complete_chapter(2)
	_check(int(r1.get("credits", 0)) == 1700 and _g.complete_chapter(2).is_empty(), "récompense de fin de chapitre versée une seule fois")
	# un chapitre = 10 étages ; le chapitre 2 suit le Gardien et finit après la Sentinelle
	for c in Story.CHAPTERS:
		if not c.get("board", false):
			_check(int(c.to) - int(c.from) == 9, "chapitre %d sur 10 étages" % int(c.n))
	_check(Story.chapter_scenes(3).size() == 7 and int(Story.scene("c1_fin").stage) == 10 and int(Story.scene("c1_fin").end) == 2 and int(Story.scene("c2_fin").end) == 3, "chapitre 2 jusqu'à 10, chapitre 3 en 7 scènes")
	_check(Story.pending(["prologue", "c1_entree", "c1_soleil", "c1_haut", "c1_aurore", "c1_gardien"], 11, 11).get("id", "") == "c1_fin", "fin du chapitre 1 après le Gardien")
	_check(Story.pending(["prologue", "c1_entree", "c1_soleil", "c1_haut", "c1_aurore", "c1_gardien", "c1_fin"], 11, 11).get("id", "") == "c2_voix", "scène avant l'étage 11")
	_check(Story.pending([], 20, 20).get("id", "") == "c1_soleil", "scène manquée jouée tant qu'on n'a pas rattrapé")
	# partie déjà loin : les scènes passées vont au journal sans rafale, chapitres payés une fois
	_g.best_stage = 22
	_g.stage = 22
	var credits0: float = _g.credits
	_g.story_catch_up()
	_check(_g.seen_scenes.has("c2_temple") and _g.seen_scenes.has("c2_fin") and _g.chapters_done.has(3), "scènes dépassées débloquées dans le journal")
	_check(is_equal_approx(_g.credits - credits0, 5700.0), "chapitre 2 déjà payé, chapitre 3 payé une fois")
	_check(Story.pending(_g.seen_scenes, 22, 22).is_empty(), "pas de rafale de scènes")
	# chapitres 3 et 4 : l'histoire finit à l'étage 40, puis la Ceinture sans fin
	_check(Story.chapter_scenes(4).size() == 7 and Story.chapter_scenes(5).size() == 7 and Story.last_chapter() == 5, "chapitres 4 et 5 en 7 scènes")
	_check(int(Story.scene("c4_fin").end) == 5 and int(Story.chapter(5).to) == Sector.GEN_START - 1, "l'histoire finit juste avant les secteurs générés")
	var prev := 0.0
	var grows := true
	for n in range(2, 6):
		var ch: Dictionary = Story.chapter(n)
		var loot: float = float(Data.chest_rewards(int(ch.to), "normal").credits)
		grows = grows and float(ch.reward.credits) > prev and float(ch.reward.credits) >= 5.0 * float(loot)
		prev = float(ch.reward.credits)
	_check(grows, "récompenses de chapitre croissantes, au moins 5 coffres du dernier étage")
	_check(Data.boss_name(40) == "Gardien du dernier seuil" and Data.boss_name(10) == "Gardien de verre", "le dernier Gardien a son nom")
	_check(Story.short_name("holt") == "Holt" and Story.short_name("kai") == "Kaï", "noms courts")
	_g.best_stage = 45
	var credits1: float = _g.credits
	_g.story_catch_up()
	_check(_g.chapters_done.has(5) and is_equal_approx(_g.credits - credits1, 84000.0) and _g.tips.has("badge:Héros de la Ceinture"), "chapitres 4 et 5 payés une fois en rattrapage")
	_g.save_game()
	var g2: Node = load("res://scripts/game.gd").new()
	g2.save_path = _g.save_path
	g2.load_game()
	_check(g2.seen_scenes.has("c1_haut") and int(g2.story_choices.get("c1_haut", -1)) == 1 and g2.chapters_done.has(2), "scènes, choix et chapitres sauvegardés")
	g2.free()
	_check(not _g.seen_scenes.has("b1_bord") and not _g.chapters_done.has(1), "le rattrapage ne touche pas au chapitre 1 à bord")


## Chapitre 1 « Cap sur Altopia » (maquettes SA à SH) : objectifs de bord, scènes entre les objectifs, mission à l'arrivée.
func test_board_chapter() -> void:
	_g.reset()
	ShipState.clock_offset = 0
	_check(Story.chapter(1).get("board", false) and Story.chapter(2).title == "Le signal" and Story.chapter(5).title == "Le dernier seuil", "chapitre 1 à bord, puis Le signal (2) à Le dernier seuil (5)")
	_check(Story.pending([], 1, 1).get("id", "") == "c1_entree" and Story.pending(["c1_entree"], 6, 6).get("id", "") == "c1_soleil", "les scènes à bord ne passent pas par les étages")
	_g.ship_update()
	var s: ShipState = _g.ship
	_check(s.unlocked and not _g.mission_open() and _g.credits >= 250.0, "Aurore ouverte dès le départ, prime de départ, mission fermée")
	_check(_g.is_owned("vance") and s.post_of("vance") == "pont" and not _g.squad.has("vance") and _g.voyage_done() == 0, "Vance à bord dès le départ, au Pont, hors escouade")
	_check(_g.voyage_done() == 0 and Story.board_pending([], 0).get("id", "") == "b1_bord", "scène « À bord » d'abord")
	var seen: Array = ["b1_bord"]
	_check(Story.board_pending(seen, 0).is_empty(), "rien avant le premier objectif")
	s.collect(_g, "raffinerie")
	_check(_g.voyage_done() == 1 and Story.board_pending(seen, 1).get("id", "") == "b1_recolte", "objectif 1 : récolte, puis T-9")
	var got: Array = _g.recruit(1)
	_check(got.size() == 1 and bool(got[0].new) and _g.voyage_done() == 2, "objectif 2 : première recrue, toujours nouvelle")
	_check(s.assign(_g, String(got[0].id), "raffinerie") and _g.voyage_done() == 3, "objectif 3 : la recrue au poste")
	_g.credits = 0.0
	_check(s.start_upgrade(_g, "pont") and _g.voyage_done() == 4, "objectif 4 : chantier du Pont lancé, crédits payés par l'Amirauté")
	ShipState.clock_offset += 60
	_g.ship_update()
	_check(s.level == 2 and s.start_upgrade(_g, "raffinerie") and _g.voyage_done() == 5, "objectif 5 : Raffinerie niveau 2")
	_check(Story.board_pending(["b1_bord", "b1_recolte", "b1_recrue", "b1_pont"], 5).get("id", "") == "b1_signal", "Zyra entend le signal")
	_g.see_scene("b1_signal", 0)
	_check(_g.voyage_done() == 6 and Story.board_pending(_g.seen_scenes + ["b1_bord", "b1_recolte", "b1_recrue", "b1_pont"], 6).get("id", "") == "b1_fin", "arrivée : fin du chapitre 1")
	_g.wild = 0
	var rw: Dictionary = _g.complete_chapter(1)
	_check(int(rw.get("credits", 0)) == 500 and _g.mission_open(), "fin du chapitre 1 payée, la mission s'ouvre")
	_check(_g.wild == 10 and _g.complete_chapter(1).is_empty() and _g.wild == 10, "le chapitre 1 donne 10 doublons au choix, une seule fois")
	_g.wild = 0
	_g.crystals = 100
	_check(_g.buy("copies10") != "" and _g.wild == 10 and _g.crystals == 88, "la boutique vend 10 doublons au choix")
	_g.wild = 0
	var sh: ShipState = _g.ship
	sh.shuttles["colibri"] = {"dest": "asteroides", "end": 0, "pilot": ""}
	_g.rng.seed = 5
	var found := 0
	for i in 200:
		sh.shuttles["colibri"] = {"dest": "asteroides", "end": 0, "pilot": ""}
		var out: Dictionary = sh.claim(_g, "colibri")
		found += int(out.get("copies", 0))
	_check(found > 0 and _g.wild == found, "une trouvaille rare en expédition donne 3 doublons au choix (%d)" % found)
	_g.wild = 0
	# sauvegarde d'avant le chapitre 1 : chapitres décalés, voyage déjà fait
	_g.reset()
	_g.best_stage = 14
	_g.chapters_done = [1]
	_g.seen_scenes = ["prologue", "c1_entree", "c1_fin"]
	_g._migrate_story()
	_check(_g.chapters_done.has(2) and _g.chapters_done.has(1) and _g.mission_open() and _g.seen_scenes.has("b1_fin"), "ancienne sauvegarde : chapitres décalés, voyage fait")
	_g.reset()


func test_generated_sectors() -> void:
	_g.reset()
	_check(Sector.info(40).is_empty() and not Sector.info(41).is_empty(), "secteurs générés à partir de l'étage 41")
	var a := Sector.info(55)
	var b := Sector.info(52)
	_check(a.name == b.name and a.rule == b.rule and int(a.index) == 6 and int(a.from) == 51 and int(a.to) == 60, "un secteur est identique pour tous ses étages")
	_check(Sector.info(55).hash() == Sector.info(55).hash(), "génération déterministe")
	var names := {}
	for k in range(5, 25):
		names[Sector.info(k * 10).name] = true
	_check(names.size() >= 12, "des noms de secteurs variés")
	_check(Data.boss_type(60) == "big" and Data.boss_name(60).find(String(Sector.info(60).boss_title)) >= 0, "le gros boss d'un secteur généré porte un titre")
	# difficulté adaptative : l'équilibre des pas donne environ 85 % de victoires
	var p := -log(Sector.STEP_LOSS) / (log(Sector.STEP_WIN) - log(Sector.STEP_LOSS))
	_check(absf(p - Sector.TARGET_WIN) < 0.02, "les pas visent 85 %% de victoires (%.3f)" % p)
	_g.best_stage = 45
	_g.stage = 45
	var f0: float = _g.inf_diff
	_g.record_generated(45, true)
	_check(_g.inf_diff > f0 and is_equal_approx(Sector.factor, _g.inf_diff), "une victoire durcit le secteur")
	_g.record_generated(45, false)
	_check(_g.inf_diff < f0, "une défaite l'adoucit")
	_g.record_generated(30, false)
	_check(_g.gen_tries == 2, "les étages de l'histoire ne comptent pas")
	# le butin suit la difficulté
	Sector.factor = 2.0
	var c2: Dictionary = _g.open_chest("rare", 45)
	Sector.factor = 1.0
	var c1: Dictionary = _g.open_chest("rare", 45)
	_check(float(c2.credits) > float(c1.credits) * 1.8, "le butin des secteurs générés suit la difficulté")
	_g.sectors_seen = [5]
	_g.save_game()
	var g2: Node = load("res://scripts/game.gd").new()
	g2.save_path = _g.save_path
	g2.load_game()
	_check(is_equal_approx(g2.inf_diff, _g.inf_diff) and g2.sectors_seen.has(5) and g2.gen_tries == 2, "difficulté adaptative et secteurs vus sauvegardés")
	g2.free()
	Sector.factor = 1.0


func test_safe_save() -> void:
	_g.reset()
	_g.credits = 111.0
	_g.save_game()
	_g.credits = 222.0
	_g.save_game()
	# sauvegarde principale tronquée (coupure pendant une écriture) : on retrouve la précédente
	var f := FileAccess.open(_g.save_path, FileAccess.WRITE)
	f.store_string("{\"version\": 5, \"cred")
	f.close()
	var g2: Node = load("res://scripts/game.gd").new()
	g2.save_path = _g.save_path
	_check(g2.load_game() and is_equal_approx(g2.credits, 111.0), "sauvegarde tronquée : la copie de secours est rechargée")
	g2.free()
	_check(not FileAccess.file_exists(_g.save_path + ".tmp"), "pas de fichier temporaire laissé après une sauvegarde réussie")
	_g.save_game()
	var g3: Node = load("res://scripts/game.gd").new()
	g3.save_path = _g.save_path
	_check(g3.load_game() and is_equal_approx(g3.credits, 222.0), "la sauvegarde suivante répare le fichier principal")
	g3.free()


func test_settings_display_and_battery() -> void:
	_g.reset()
	var lv: int = _g.battery_level()
	_check(lv == -1 or (lv >= 0 and lv <= 100), "niveau de batterie lisible ou -1")
	_g.text_size = 2
	_g.battery_saver = true
	_g.apply_performance()
	_check(is_equal_approx(UI.text_scale, 1.2) and Engine.max_fps == 30, "texte très grand et économie de batterie appliqués")
	_g.text_size = 0
	_g.battery_saver = false
	_g.battery_auto = false
	_g.apply_performance()
	_check(is_equal_approx(UI.text_scale, 1.0) and Engine.max_fps == 60, "retour aux réglages normaux")
	_g.battery_auto = true


func test_shop_and_tokens() -> void:
	_g.crystals = 5
	_check(_g.buy("tokens6") == "" and _g.crystals == 5, "pas d'achat sans assez de cristaux")
	_g.crystals = 100
	var t0: int = _g.tokens
	_check(_g.buy("tokens6") != "" and _g.tokens == t0 + 6 and _g.crystals == 92, "six jetons coûtent 8 cristaux")
	_check(not _g.boost_active() and _g.buy("boost2") != "" and _g.boost_active() and _g.crystals == 82, "le boost ×2 coûte 10 cristaux et s'active")
	_g.boost_until = 0
	_g.daily_day = -1
	var t1: int = _g.tokens
	_check(_g.buy("daily") != "" and _g.tokens >= t1 + 3 and _g.crystals == 62 and not _g.daily_available(), "l'offre du jour coûte 20 cristaux et s'achète une fois par jour")
	_check(_g.buy("daily") == "", "l'offre du jour n'est pas rachetable le même jour")
	_g.crystals = 100
	_g.stage = 10
	_g.best_stage = 10
	var c: Dictionary = _g.stage_cleared(3)
	_check(_g.crystals >= 100 and c.crystals == 10, "un gros boss en 3 étoiles rapporte 10 cristaux")
	var before: int = _g.tokens
	_g.open_chest("rare", 3)
	_check(_g.tokens == before + 3, "un coffre rare donne 3 jetons")


func test_save_v4_and_migration() -> void:
	_g.owned["sora"] = true
	_g.hero_stars["sora"] = 3
	_g.fragments["sora"] = 7
	_g.squad = ["sora", "kai", "zyra", "t9", "oru"]
	_g.tokens = 12
	_g.crystals = 40
	_g.recruit_pity = {"rare": 4, "epic": 9}
	_g.pulls = 25
	_g.save_game()
	_g.reset()
	_check(_g.load_game(), "rechargement v4")
	_check(_g.is_owned("sora") and _g.hero_stars["sora"] == 3 and _g.fragments["sora"] == 7 and _g.squad[0] == "sora", "collection, étoiles, fragments et escouade conservés")
	_check(_g.tokens == 12 and _g.crystals == 40 and _g.recruit_pity.epic == 9 and _g.pulls == 25, "jetons, cristaux, garanties et tirages conservés")
	# ancienne sauvegarde (version 3, sans collection) : les cinq héros de départ et un cadeau de jetons
	var f := FileAccess.open("user://test_save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 3, "credits": 10, "levels": {"mara": 4}, "stage": 2, "best": 3, "last_seen": 0}))
	f.close()
	_g.reset()
	_check(_g.load_game() and _g.owned.size() == 5 and _g.squad == Data.STARTER and _g.tokens == 6 and _g.levels["mara"] == 4, "migration d'une sauvegarde v3")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))


func _item(slot: String, rarity: String, stage: int = 10) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	return Items.roll(r, rarity, stage, slot)


func test_items_roll_and_power() -> void:
	var counts := {"commun": 0, "normal": 1, "rare": 2, "epique": 3, "legendaire": 3, "ultime": 3}
	for r in counts:
		var it := _item("arme", r)
		_check(it.subs.size() == counts[r], "%s : %d bonus secondaires" % [r, counts[r]])
		_check((it.set != "") == (Items.rarity_index(r) >= 2), "%s : ensemble à partir de rare" % r)
	_check(Items.power(_item("arme", "legendaire")) > Items.power(_item("arme", "epique")) and Items.power(_item("arme", "epique")) > Items.power(_item("arme", "commun")), "la puissance monte avec la rareté")
	var weak := _item("arme", "rare")
	var strong: Dictionary = weak.duplicate(true)
	strong.level = 8
	_check(Items.power(strong) > Items.power(weak), "la puissance monte avec le niveau")
	var drops := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 2000:
		var r := Items.roll_rarity("epique", rng)
		drops[r] = int(drops.get(r, 0)) + 1
	_check(not drops.has("commun") and not drops.has("ultime") and drops.get("rare", 0) > drops.get("legendaire", 0), "un coffre épique ne donne ni commun ni ultime")


func test_items_equip_and_binding() -> void:
	_g.credits = 5000.0
	var a: Dictionary = _g.receive_item(_item("arme", "epique")).item
	var b: Dictionary = _g.receive_item(_item("arme", "rare")).item
	_g.levels["mara"] = 20
	_check(_g.equip(int(a.id), "mara") == "" and _g.slot_item("mara", "arme").id == a.id, "équiper une arme")
	_check(_g.equip(int(b.id), "mara") == "" and a.on == "" and b.on == "mara", "équiper une seconde arme renvoie la première dans l'inventaire")
	_check(_g.slot_unlocked("mara", "relique") and not _g.slot_unlocked("kai", "relique"), "la relique se débloque au niveau 15")
	var c0: float = _g.credits
	_check(_g.equip(int(a.id), "kai") == "" and _g.credits == c0, "premier changement de héros gratuit")
	var before: float = _g.credits
	_check(_g.equip(int(a.id), "mara") == "" and before - _g.credits == Items.REBIND_COST, "les changements suivants coûtent 400 crédits")
	_g.credits = 0.0
	_check(_g.equip(int(a.id), "kai") != "", "pas assez de crédits pour délier")
	_g.levels["kai"] = 3
	var rel: Dictionary = _g.receive_item(_item("relique", "rare")).item
	_check(_g.equip(int(rel.id), "kai") != "", "emplacement verrouillé : relique au niveau 15")


func test_items_inventory_forge() -> void:
	_g.auto_recycle = false
	_g.credits = 10000.0
	var ids: Array = []
	for i in 3:
		ids.append(int(_g.receive_item(_item("armure", "rare")).item.id))
	var fused: Dictionary = _g.fuse_items(ids)
	_check(not fused.is_empty() and fused.rarity == "epique" and fused.slot == "armure" and _g.item_by_id(ids[0]).is_empty(), "trois armures rares donnent une armure épique")
	var mix: Array = [int(_g.receive_item(_item("arme", "rare")).item.id), int(_g.receive_item(_item("armure", "rare")).item.id), int(_g.receive_item(_item("arme", "rare")).item.id)]
	_check(_g.fuse_items(mix).is_empty(), "la fusion refuse des emplacements différents")
	var sh: int = _g.shards
	var res: Dictionary = _g.recycle_items([mix[0], mix[1]])
	_check(res.count == 2 and _g.shards == sh + 8, "recyclage : 4 éclats par objet rare")
	_g.auto_recycle = true
	var n: int = _g.items.size()
	_check(_g.receive_item(_item("arme", "commun")).status == "recycled" and _g.items.size() == n, "un objet commun est recyclé tout seul")
	_g.auto_recycle = false
	for i in Items.INVENTORY_MAX:
		_g.receive_item(_item("arme", "normal"))
	_check(_g.receive_item(_item("arme", "normal")).status == "stash" and _g.stash.size() >= 1, "inventaire plein : l'objet reste de côté")


func test_items_combat_and_save() -> void:
	_g.auto_recycle = false
	var w: Dictionary = _g.receive_item(_item("arme", "legendaire", 10)).item
	_g.levels["mara"] = 10
	var plain := BattleSim.new(_g.team(), 6, 1)
	var atk0: float = plain.allies()[0].atk
	_g.equip(int(w.id), "mara")
	var armed := BattleSim.new(_g.team(), 6, 1)
	_check(armed.allies()[0].atk > atk0, "l'arme augmente l'attaque en combat")
	_check(_g.power() > Data.team_power(_g.levels, _g.squad_ids()), "l'équipement compte dans la puissance de l'escouade")
	_g.save_game()
	var before: int = _g.items.size()
	_g.items = []
	_g.load_game()
	_check(_g.items.size() == before and _g.slot_item("mara", "arme").name == w.name, "l'équipement survit à la sauvegarde")
	_g.item_pity = 0
	var rarities: Array = []
	for i in 3:
		_g.stage = 10
		var c: Dictionary = _g.open_chest("commun", 10, 0.0, false, true)
		rarities.append(c.item.rarity)
	_check(Items.rarity_index(rarities[2]) >= 4 or Items.rarity_index(rarities[0]) >= 4 or Items.rarity_index(rarities[1]) >= 4, "un objet légendaire est garanti au 3e gros boss")


func test_ship() -> void:
	ShipState.clock_offset = 0
	var s: ShipState = _g.ship
	_check(not s.unlocked, "vaisseau fermé au départ")
	_g.best_stage = 6
	_g.ship_update()
	_check(s.unlocked and s.room_level("pont") == 1 and s.room_level("raffinerie") == 1 and s.room_level("atelier") == 0, "vaisseau ouvert, salles du niveau 1")
	_check(is_equal_approx(float(s.stock.raffinerie), 10.0), "soute de la Raffinerie pleine au départ")
	s.stock["raffinerie"] = 0.0
	# chantier conseillé sur l'accueil : le Pont d'abord, lançable s'il y a de quoi payer
	_g.best_stage = 20
	_g.credits = 0.0
	_g.shards = 0
	var adv: Dictionary = s.advice(_g)
	_check(adv.get("room", "") == "pont" and not bool(adv.ok), "chantier conseillé : le Pont, en attente de ressources (%s)" % str(adv))
	_g.credits = 1e6
	_g.shards = 1000
	adv = s.advice(_g)
	_check(adv.get("room", "") == "pont" and bool(adv.ok), "chantier conseillé : le Pont, lançable")
	_g.best_stage = 6
	_g.credits = 0.0
	_g.shards = 0
	var nb = load("res://scripts/nav_bar.gd").new()
	nb.ship_on = true
	_check(nb.tabs()[0] == 2 and nb.label_of(2) == "Aurore" and nb.label_of(0) == "Mission", "barre du bas : l'Aurore en premier, le combat devient Mission")
	nb.ship_on = false
	_check(nb.tabs() == [0, 1, 3, 4] and nb.label_of(0) == "Combat", "avant l'Aurore : quatre onglets, Combat en premier")
	nb.free()
	# production en temps réel, plafonnée par l'autonomie
	ShipState.clock_offset += 3600
	_g.ship_update()
	var r1: float = s.stock.raffinerie
	_check(r1 > 2.0 and r1 < 4.0, "la Raffinerie produit environ 2,6 éclats par heure (%.2f)" % r1)
	ShipState.clock_offset += 3600 * 100
	_g.ship_update()
	_check(is_equal_approx(float(s.stock.raffinerie), s.capacity("raffinerie", _g.best_stage)), "réserve plafonnée par l'autonomie")
	var sh0: int = _g.shards
	var got: Dictionary = s.collect(_g, "raffinerie")
	_check(_g.shards == sh0 + int(got.amount) and float(s.stock.raffinerie) < 1.0, "récolte des éclats")
	# améliorations : le Pont exige l'étage, les salles ne dépassent pas le Pont
	_g.credits = 1.0e9
	_g.shards = 100000
	_check(s.upgrade_block(_g, "raffinerie") != "", "une salle ne dépasse pas le niveau du Pont")
	_g.best_stage = 6
	_check(Ship.PONT_STAGE[2] <= 1 and s.upgrade_block(_g, "pont") == "", "Pont niveau 2 dès le voyage")
	_g.best_stage = 9
	_check(s.start_upgrade(_g, "pont") and s.builds.size() == 1, "chantier du Pont lancé")
	_check(not s.start_upgrade(_g, "raffinerie"), "un seul chantier à la fois au début")
	ShipState.clock_offset += 3600
	_g.ship_update()
	_check(s.level == 2 and s.room_level("pont") == 2 and s.builds.is_empty(), "chantier terminé en temps réel")
	_check(s.upgrade_block(_g, "pont").begins_with("Étage"), "le Pont exige ensuite l'étage suivant")
	_check(s.start_upgrade(_g, "raffinerie"), "chantier de salle")
	_g.crystals = 0
	_check(not s.rush_build(_g, "raffinerie"), "accélérer demande des cristaux")
	_g.crystals = 50
	var cost := Ship.rush_cost(s.remaining(int(s.building("raffinerie").end)))
	_check(s.rush_build(_g, "raffinerie") and s.room_level("raffinerie") == 2 and _g.crystals == 50 - cost, "terminé tout de suite contre %d cristaux" % cost)
	# postes : seulement les héros hors escouade
	_g.owned["dax"] = true
	_check(not s.assign(_g, "mara", "raffinerie"), "un héros de l'escouade ne travaille pas")
	_check(s.assign(_g, "dax", "raffinerie") and s.posts.raffinerie.has("dax"), "un héros hors escouade prend un poste")
	_check(s.production_mult("raffinerie") > 1.2, "le poste augmente la production")
	_g.set_slot(0, "dax")
	_check(s.post_of("dax") == "", "entré dans l'escouade, il quitte son poste")
	# salles à construire : les trois salles de départ le sont d'office, les autres s'ouvrent mais attendent le joueur
	s.level = 3
	s.open_rooms()
	_check(s.room_level("centrale") == 1 and s.room_level("raffinerie") >= 1 and s.room_level("atelier") == 0, "l'Atelier s'ouvre au niveau 3 sans être construit")
	_check(s.is_buildable("atelier") and s.buildable() == ["atelier"] and not s.is_buildable("serre"), "seule l'Atelier est à construire (la Serre attend le niveau 5)")
	_check(s.max_posts("atelier") == 0 and not s.producers().has("atelier"), "une salle non construite ne produit rien")
	_check(is_equal_approx(float(Ship.build_cost("atelier").credits), float(Ship.upgrade_cost("atelier", 3).credits)), "la construction coûte comme une amélioration au niveau d'ouverture")
	_g.credits = 1.0e9
	_g.shards = 100000
	_check(s.upgrade_block(_g, "serre") != "" and s.start_upgrade(_g, "atelier") and s.building("atelier").to == 1, "construction lancée par le joueur")
	_check(s.buildable().is_empty(), "pas deux constructions de la même salle")
	ShipState.clock_offset += 3600
	_g.ship_update()
	_check(s.room_level("atelier") == 1 and s.producers().has("atelier") and s.max_posts("atelier") > 0, "Atelier construite : elle produit et accueille un poste")
	# recherche : bonus de combat
	s.level = 10
	s.open_rooms()
	s.rooms["labo"] = 3
	_check(s.start_research(_g, "armement"), "recherche lancée")
	ShipState.clock_offset += 3600 * 3
	_g.ship_update()
	_check(s.rank("armement") == 1 and is_equal_approx(float(_g.team()[0].ship.atk), 0.03), "recherche terminée, +3 % d'attaque")
	var sim := BattleSim.new(_g.team(), 1, 7)
	var sim0 := BattleSim.new(_team(1), 1, 7)
	_check(sim.units[0].atk > sim0.units[0].atk, "le bonus du Labo s'applique au combat")
	# expéditions
	s.rooms["hangar"] = 1
	_g.owned["sora"] = true
	_check(s.fleet() == ["colibri"] and s.launch(_g, "colibri", "asteroides", "sora"), "expédition lancée")
	ShipState.clock_offset += 3600 * 2
	_g.ship_update()
	var sh1: int = _g.shards
	var res: Dictionary = s.claim(_g, "colibri")
	_check(int(res.get("shards", 0)) > 0 and _g.shards == sh1 + int(res.shards) and s.shuttle_state("colibri").is_empty(), "navette rentrée, butin versé")
	# entraînement des Quartiers
	s.rooms["quartiers"] = 10
	_g.levels["sora"] = 1
	for id in _g.squad_ids():
		_g.levels[id] = 30
	_check(s.assign(_g, "sora", "quartiers"), "un héros au repos")
	ShipState.clock_offset += 3600 * 20
	_g.ship_update()
	_check(int(_g.levels.sora) > 1 and int(_g.levels.sora) <= 27, "l'entraînement monte son niveau, sans dépasser l'escouade − 3 (%d)" % int(_g.levels.sora))
	# sauvegarde
	_g.save_game()
	var g2: Node = load("res://scripts/game.gd").new()
	g2.save_path = _g.save_path
	g2.load_game()
	_check(g2.ship.unlocked and g2.ship.level == 10 and g2.ship.rank("armement") == 1 and g2.ship.posts.quartiers.has("sora"), "vaisseau sauvegardé")
	g2.free()
	# rythme : le vaisseau atteint le niveau 10 pendant l'histoire (étages 1 à 40), les niveaux 11 à 20 viennent ensuite
	_check(int(Ship.PONT_STAGE[10]) <= 35 and int(Ship.PONT_STAGE[11]) > 40, "niveau 10 pendant l'histoire, 11 et plus après l'étage 40")
	var total := 0
	for lv in range(2, 11):
		total += int(Ship.upgrade_cost("pont", lv).time)
	_check(total <= 600, "chantiers du Pont jusqu'au niveau 10 courts (%d s)" % total)
	_check(int(Ship.upgrade_cost("pont", 11).time) >= 1800, "chantiers longs au-delà du niveau 10")
	_check(Ship.tier_of(1) == 1 and Ship.tier_of(6) == 2 and Ship.tier_of(15) == 3 and Ship.tier_of(19) == 4 and Ship.tier_of(20) == 5, "cinq versions du vaisseau")
	ShipState.clock_offset = 0
