extends SceneTree
## Captures de la refonte Android (xvfb-run -a godot --path . --resolution 720x1280 -s tools/refonte_shots.gd -- <dossier> [écran…])
var g
var main: Control
var out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var only: Array = args.slice(1)
	await process_frame
	g = root.get_node("Game")
	var big := only.has("grand")
	only.erase("grand")
	g.save_path = "user://shot.json"
	g.reset()
	g.stage = 12
	g.best_stage = 19
	g.tutorial_done = true
	g.intro_seen = true
	g.chapters_done = [1]                # le voyage (chapitre 1) est fait, sauf pour les captures du voyage
	for id in g.levels.keys():
		g.levels[id] = 14
	g.levels["mara"] = 10
	g.credits = 4200.0
	g.shards = 53
	g.tokens = 6
	g.item_tokens = 8
	g.crystals = 87
	for id in ["aria", "brix"]:
		g.owned[id] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for r in ["epique", "rare", "epique", "legendaire", "rare", "normal", "epique", "rare", "normal", "rare", "legendaire", "normal"]:
		g.receive_item(Items.roll(rng, r, 12, Items.SLOTS[rng.randi() % 4]))
	g.equip_best("mara")
	if big:
		g.text_size = 2
		g.apply_performance()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(1.0)
	var shots := {
		"combat": func(): pass,
		"heros": func(): main._open_collection(0),
		"objets": func(): main._open_collection(1),
		"ensembles": func(): main._open_collection(2),
		"etoile": func():
			g.levels["mara"] = 10
			g.fragments["mara"] = 3
			g.wild = 4
			main._open_modal(EvolveScreen.new("mara")),
		"fiche_etoiles": func():
			g.levels["mara"] = 10
			g.fragments["mara"] = 3
			g.wild = 4
			main._open_modal(HeroScreen.new("mara", 0)),
		"fiche": func(): main._open_modal(HeroScreen.new("mara", 1)),
		"fiche_stats": func(): main._open_modal(HeroScreen.new("mara", 0)),
		"recrutement": func(): main._open_recruit(),
		"boutique": func(): main._open_shop(),
		"monnaies": func():
			main._open_shop()
			await process_frame
			var w = root.find_children("*", "Wallet", true, false)[0]
			w._explain(["coin", "shard", "crystal", "token", "itoken", "wild"]),
		"carte": func(): main._open_map(),
		"reglages": func(): main._open_settings(),
		"defaite": func(): main._open_modal(DefeatScreen.new(12)),
		"renfort": func(): main._open_modal(BoostScreen.new(g.offer_boosts(), 15)),
		"palier": func(): main._open_modal(EvolveScreen.new("mara")),
		"horsligne": func(): main._open_modal(OfflineScreen.new({"seconds": 18720, "credits": 9400.0, "shards": 27})),
		"intro": func():
			var it := IntroScreen.new()
			main.add_child(it)
			main._modal = it,
		"detail": func(): main._open_item(int(g.inventory_items()[0].id)),
		"choix": func(): main._open_pick("mara", "arme"),
		"pourqui": func(): main._open_who(int(g.inventory_items()[1].id), "Nouvel objet"),
		"forge": func():
			var f := ForgeScreen.new()
			main._open_modal(f)
			f._auto_pick(),
		"boss": func():
			g.best_stage = 21
			g.go_to(20)
			main._start_battle(),
		"tuto": func():
			g.go_to(12)
			main._tuto = 1
			main._start_battle(),
		"prologue1": func(): main._open_modal(PrologueScreen.new(true)),
		"prologue2": func():
			var p := PrologueScreen.new(true)
			main._open_modal(p)
			p._next(),
		"prologue3": func():
			var p := PrologueScreen.new(true)
			main._open_modal(p)
			p._next()
			p._next(),
		"dialogue": func(): main._open_modal(DialogueScreen.new(Story.scene("c1_soleil"), true)),
		"choixcap": func(): main._open_modal(DialogueScreen.new(Story.scene("c1_haut"), true)),
		"gardien": func(): main._open_modal(DialogueScreen.new(Story.scene("c1_gardien"), true)),
		"epave": func(): main._open_modal(DialogueScreen.new(Story.scene("c2_epave"))),
		"phare": func(): main._open_modal(DialogueScreen.new(Story.scene("c2_porteuse"), true)),
		"reine30": func(): main._open_modal(DialogueScreen.new(Story.scene("c3_reine"), true)),
		"holt": func(): main._open_modal(DialogueScreen.new(Story.scene("c4_rendormir"))),
		"seuil": func(): main._open_modal(DialogueScreen.new(Story.scene("c4_seuil"), true)),
		"finhist": func(): main._open_modal(ChapterEndScreen.new(5, Story.chapter(5).reward)),
		"journal4": func():
			g.seen_scenes = ["prologue"]
			for s0 in Story.SCENES:
				if int(s0.stage) <= 35:
					g.seen_scenes.append(String(s0.id))
			g.chapters_done = [1, 2, 3, 4]
			main._open_journal()
			var j = main._modal
			j._ch = 5
			j._chips.sel = 4
			j._rebuild(),
		"finchap2": func(): main._open_modal(ChapterEndScreen.new(3, Story.chapter(3).reward)),
		"finchap": func(): main._open_modal(ChapterEndScreen.new(2, Story.chapter(2).reward)),
		"journal": func():
			g.seen_scenes = ["prologue", "b1_bord", "b1_recolte", "b1_recrue", "b1_pont", "b1_signal", "b1_fin", "c1_entree", "c1_soleil", "c1_haut", "c1_gardien"]
			main._open_journal()
			var j = main._modal
			j._ch = 2
			j._chips.sel = 1
			j._rebuild(),
		"journal2": func():
			g.seen_scenes = ["prologue", "c1_entree", "c1_soleil", "c1_haut", "c1_gardien", "c1_fin", "c2_voix", "c2_epave", "c2_holt"]
			g.chapters_done = [1, 2]
			main._open_journal()
			var j = main._modal
			j._ch = 3
			j._chips.sel = 2
			j._rebuild(),
		"secteur": func():
			main._open_modal(SectorScreen.new(53)),
		"combat53": func():
			g.best_stage = 53
			g.go_to(53)
			g.sectors_seen = [6]
			for id in g.levels.keys():
				g.levels[id] = 60
			g.hero_stars = {"mara": 3, "kai": 3, "zyra": 3, "t9": 3, "oru": 3}
			g.fragments["mara"] = 7
			g.wild = 6
			main._start_battle(),
		"vaisseau": func():
			_ship(10)
			main._open_ship(),
		"vaisseau20": func():
			_ship(20)
			main._open_ship(),
		"vaisseau8": func():
			_ship(8)
			main._open_ship(),
		"vaisseau5": func():
			_ship(5)
			main._open_ship(),
		"vaisseau15": func():
			_ship(15)
			main._open_ship(),
		"vaisseau1": func():
			_ship(3)
			main._open_ship(),
		"salle": func():
			_ship(10)
			main._open_ship()
			main._open_room("raffinerie"),
		"pont": func():
			_ship(10)
			main._open_ship()
			main._open_room("pont"),
		"labo": func():
			_ship(10)
			main._open_ship()
			main._open_room("labo"),
		"quartiers": func():
			_ship(10)
			main._open_ship()
			main._open_room("quartiers"),
		"hangar": func():
			_ship(10)
			main._open_ship()
			main._open_room("hangar"),
		"ameliorer": func():
			_ship(10)
			main._open_ship()
			main._open_room("raffinerie")
			await process_frame
			var rs = main._modal.get_child(main._modal.get_child_count() - 1)
			rs._upgrade_dialog(),
		"affecter": func():
			_ship(10)
			main._open_ship()
			main._open_room("atelier")
			await process_frame
			var rs = main._modal.get_child(main._modal.get_child_count() - 1)
			rs._assign_sheet(""),
		"expedition": func():
			_ship(10)
			main._open_ship()
			main._open_room("hangar")
			await process_frame
			var rs = main._modal.get_child(main._modal.get_child_count() - 1)
			rs._expedition_sheet("martin"),
		"version": func():
			_ship(11)
			var ts := ShipTierScreen.new(11)
			main._open_modal(ts),
		"niveau20": func():
			_ship(20)
			var ts := ShipTierScreen.new(20)
			main._open_modal(ts),
		"voyage": func():
			g.chapters_done = []
			g.tips.append("ship")
			g.credits = 300.0
			g.shards = 4
			g.ship.unlock()
			g.ship.harvests = 1
			g.ship.stock["raffinerie"] = 1.5
			main._open_ship(),
		"voyage_mission": func():
			g.chapters_done = []
			g.ship.unlock()
			g.ship.harvests = 1
			g.pulls = 1
			g.owned["brix"] = true
			g.ship.posts["raffinerie"] = ["brix"]
			main._open_mission(),
		"voyage_pont": func():
			g.chapters_done = []
			g.ship.unlock()
			main._open_ship()
			main._open_room("pont"),
		"scene_bord": func():
			g.ship.unlock()
			main._open_modal(DialogueScreen.new(Story.scene("b1_bord"), true)),
		"fin_voyage": func(): main._open_modal(ChapterEndScreen.new(1, Story.chapter(1).reward)),
		"bord": func():
			_ship(5)
			main._open_modal(AboardScreen.new()),
		"mission": func():
			_ship(12)
			g.tips.append("ship")
			g.ship.research["blindage"] = 4
			g.ship.research["armement"] = 3
			main._start_battle(),
		"horsligne_vaisseau": func():
			_ship(10)
			main._open_modal(OfflineScreen.new({"seconds": 33600.0, "credits": 24600.0, "shards": 12, "ship": {"stock": {"raffinerie": 56.0, "atelier": 3.0, "antenne": 2.0}, "done": [{"room": "raffinerie", "to": 9}], "research": "blindage", "trained": {"neelo": 2}, "shuttles": ["colibri"]}})),
		"construire": func():
			_ship(5)
			g.ship.rooms["serre"] = 0
			g.ship.builds = []
			g.tips.append("ship")
			main._open_ship()
			await create_timer(1.0).timeout,
		"hangar_construire": func():
			_ship(11)
			g.ship.rooms["hangar"] = 0
			g.ship.builds = []
			g.tips.append("ship")
			g.tips.append("build")
			main._open_ship()
			await process_frame
			main._modal._select("hangar"),
		"construire_fiche": func():
			_ship(5)
			g.ship.rooms["serre"] = 0
			g.ship.builds = []
			g.tips.append("ship")
			g.tips.append("build")
			main._open_ship()
			await process_frame
			main._modal._select("serre"),
		"fiche_salle": func():
			_ship(10)
			main._open_ship()
			await process_frame
			main._modal._select("raffinerie"),
		"coffre": func():
			var ch: Dictionary = g.open_chest("legendaire", 20, 0.0, true, true)
			g.pending_chest = ch
			main._open_modal(ResultScreen.new(20, 3, ch, "Monter à l'étage 21", 4)),
		"victoire": func():
			var ch: Dictionary = g.open_chest("legendaire", 20, 0.0, true, true)
			g.pending_chest = ch
			var rs := ResultScreen.new(20, 3, ch, "Monter à l'étage 21", 4)
			main._open_modal(rs)
			rs._cv.arm()
			rs._cv.t = rs._cv._t0 + rs._cv.open_at - 0.02,
	}
	for k in shots:
		if not only.is_empty() and not only.has(k):
			continue
		(shots[k] as Callable).call()
		await _wait(2.6 if k == "victoire" else (1.4 if k == "combat53" or k.begins_with("vaisseau") or k == "fiche_salle" else (3.5 if k == "intro" or k == "boss" else 0.6)))
		await _snap(out + "/" + k + ".png")
		if main._modal != null and is_instance_valid(main._modal):
			main._modal.queue_free()
		await _wait(0.3)
	quit()


## Vaisseau d'exemple (comme les maquettes) : niveau donné, équipage, réserves, un chantier, une recherche, une expédition.
func _ship(lv: int) -> void:
	var sh = g.ship
	sh.unlock()
	sh.level = lv
	sh.open_rooms()
	var lvs := {"centrale": lv - 1, "raffinerie": lv - 1, "atelier": lv - 2, "antenne": maxi(1, lv - 9), "labo": maxi(1, lv - 9), "quartiers": maxi(1, lv - 5), "hangar": maxi(1, lv - 7), "serre": maxi(1, lv - 4), "observatoire": maxi(1, lv - 11)}
	for r in lvs:
		if lv >= int(Ship.ROOMS[r].unlock):
			sh.rooms[r] = maxi(1, lvs[r])
	for id in ["dax", "pim", "neelo", "sora", "lumi", "gorn", "omega", "vance", "t9", "brix"]:
		g.owned[id] = true
	g.squad = ["mara", "kai", "zyra", "aria", "oru"]
	var posts := {"raffinerie": ["gorn", "omega"], "atelier": ["pim"], "antenne": ["lumi"], "labo": ["t9"], "quartiers": ["neelo", "dax"], "pont": ["vance"], "centrale": ["brix"]}
	for r in sh.posts:
		sh.posts[r] = []
	for r in posts:
		for h in posts[r]:
			if sh.room_level(r) > 0:
				sh.posts[r].append(h)
	sh.stock["raffinerie"] = 38.0
	sh.stock["atelier"] = 3.4
	sh.stock["antenne"] = 2.2
	sh.builds = [{"room": "labo", "to": sh.room_level("labo") + 1, "end": ShipState.now() + 720}]

	sh.research = {"blindage": 1, "armement": 2}
	sh.research_job = {"id": "blindage", "end": ShipState.now() + 720}
	if sh.room_level("hangar") > 0:
		sh.rooms["hangar"] = maxi(4, sh.room_level("hangar"))
		sh.shuttles = {"colibri": {"dest": "epave", "hero": "dax", "end": ShipState.now() + 7800}}
	g.credits = 1.2e6
	g.shards = 900
	g.crystals = 14


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0
