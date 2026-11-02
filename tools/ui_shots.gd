extends SceneTree

const Data = preload("res://scripts/data.gd")
## Captures des fenêtres (xvfb-run -a godot --path . --resolution 720x1280 -s tools/ui_shots.gd -- <dossier>).
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot.json"
	g.reset()
	g.intro_seen = true
	g.tutorial_done = true
	g.stage = 9
	g.best_stage = 9
	g.credits = 900.0
	g.stars = {1: 3, 2: 3, 3: 2, 4: 3, 5: 3, 6: 1, 7: 3, 8: 2}
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 120:
		await process_frame
	await _shot(out + "/map.png", main, MapScreen.new(), 0.8)
	for r in ["commun", "rare", "epique", "legendaire", "ultime"]:
		var tier: int = Data.RARITIES.find(r)
		var rs := ResultScreen.new(10, 3, {"rarity": r, "credits": 1200.0, "shards": 8}, "Monter")
		main._open_modal(rs)
		await process_frame
		var cv: ChestView = _find_chest(rs)
		cv.t = cv.open_at - 0.02
		for i in 14:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out + "/open_%s.png" % r)
		rs.queue_free()
		await process_frame
		await process_frame
	await _shot(out + "/settings.png", main, SettingsScreen.new(), 0.5)
	await _shot(out + "/defeat.png", main, DefeatScreen.new(9), 0.5)
	await _shot(out + "/offline.png", main, OfflineScreen.new({"seconds": 18720.0, "credits": 4860.0}), 0.5)
	g.shards = 12
	g.credits = 5000.0
	g.levels["mara"] = 10
	g.perseverance = 3
	g.boosts = ["tir", "vitalite"]
	for id in ["sora", "dax", "aria", "lumi"]:
		g.owned[id] = true
	g.hero_stars["mara"] = 3
	g.fragments["kai"] = 12
	g.fragments["oru"] = 4
	g.tokens = 40
	g.crystals = 85
	await _shot(out + "/collection.png", main, CollectionScreen.new(), 0.6)
	await _shot(out + "/hero_owned.png", main, HeroScreen.new("kai"), 0.5)
	await _shot(out + "/hero_locked.png", main, HeroScreen.new("omega"), 0.5)
	var rec := RecruitScreen.new()
	main._open_modal(rec)
	await process_frame
	rec._pull(10)
	for i in 240:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/recruit.png")
	rec.queue_free()
	await process_frame
	await process_frame
	await _shot(out + "/shop.png", main, ShopScreen.new(), 0.5)
	main._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/main2.png")
	await _shot(out + "/boost.png", main, BoostScreen.new(["tir", "bouclier", "butin"], 10), 0.6)
	await _shot(out + "/evolve.png", main, EvolveScreen.new("mara"), 0.6)
	await _shot(out + "/defeat2.png", main, DefeatScreen.new(10), 0.6)
	main._refresh()
	await process_frame
	var intro := IntroScreen.new()
	main.add_child(intro)
	for i in 240:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out + "/intro.png")
	intro.queue_free()
	quit()


func _shot(path: String, main: Control, ov: Control, secs: float) -> void:
	main._open_modal(ov)
	var t := 0.0
	while t < secs:
		await process_frame
		t += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	ov.queue_free()
	await process_frame
	await process_frame


func _find_chest(n: Node) -> ChestView:
	if n is ChestView:
		return n
	for c in n.get_children():
		var r := _find_chest(c)
		if r != null:
			return r
	return null
