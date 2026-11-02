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
	_check(_g.at_cap("mara") and _g.can_evolve("mara") and not _g.level_up("mara"), "au niveau 10 il faut évoluer")
	_g.credits = 1.0e6
	_g.shards = 0
	_check(not _g.evolve("mara"), "pas d'évolution sans éclats")
	_g.shards = 3
	var c: Dictionary = _g.evolve_cost("mara")
	_check(c.shards == 3 and _g.evolve("mara") and _g.tier("mara") == 1 and _g.shards == 0, "évolution payée en crédits et éclats")
	_check(not _g.at_cap("mara") and _g.level_up("mara"), "après l'évolution on peut monter jusqu'au niveau 20")
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
	_g.evolved["kai"] = 2
	_g.save_game()
	_g.reset()
	_check(_g.load_game(), "rechargement v3")
	_check(_g.perseverance == 3 and _g.boosts == ["tir", "butin"] and _g.tier("kai") == 2, "persévérance, renforts et paliers conservés")
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
		_check(any == frags, "les doublons donnent des fragments")


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
	_g.fragments["mara"] = 10
	_check(_g.can_star_up("mara") and _g.star_up("mara") and _g.hero_stars["mara"] == 2 and _g.fragments["mara"] == 0, "10 fragments : deuxième étoile")
	_check(not _g.can_star_up("mara"), "il en faut 20 pour la troisième")
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


func test_shop_and_tokens() -> void:
	_g.crystals = 5
	_check(_g.buy("token1") == "" and _g.crystals == 5, "pas d'achat sans assez de cristaux")
	_g.crystals = 100
	var t0: int = _g.tokens
	_check(_g.buy("token1") != "" and _g.tokens == t0 + 1 and _g.crystals == 90, "un jeton coûte 10 cristaux")
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
