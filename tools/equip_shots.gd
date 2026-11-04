extends SceneTree
## Captures des écrans d'équipement (xvfb-run -a godot --path . --resolution 720x1280 -s tools/equip_shots.gd -- <dossier>)
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://shot.json"
	g.reset()
	g.stage = 12
	g.best_stage = 12
	g.tutorial_done = true
	g.intro_seen = true
	for id in g.levels.keys():
		g.levels[id] = 14
	g.auto_recycle = false
	g.credits = 5000.0
	g.shards = 40
	g.tokens = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for r in ["epique", "rare", "epique", "legendaire", "rare", "normal", "epique", "rare", "normal", "commun", "rare", "legendaire", "normal", "epique", "rare", "commun"]:
		g.receive_item(Items.roll(rng, r, 12, Items.SLOTS[rng.randi() % 4]))
	g.equip_best("mara")
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(1.0)
	await _shot(main, HeroScreen.new("mara", 1), out + "/hero_equip.png")
	await _shot(main, ItemPickScreen.new("mara", "arme"), out + "/pick.png")
	await _shot(main, ItemWhoScreen.new(int(g.inventory_items()[0].id), "Nouvel objet"), out + "/who.png")
	await _shot(main, ItemDetailScreen.new(int(g.inventory_items()[1].id)), out + "/detail.png")
	var f := ForgeScreen.new()
	main._open_modal(f)
	await _wait(0.5)
	await _snap(out + "/forge.png")
	f._auto_pick()
	await _wait(0.3)
	await _snap(out + "/forge2.png")
	f.queue_free()
	await _wait(0.2)
	var c := CollectionScreen.new()
	main._open_modal(c, 1)
	c.show_tab(1)
	await _wait(0.5)
	await _snap(out + "/items.png")
	c.show_tab(2)
	await _wait(0.5)
	await _snap(out + "/sets.png")
	c.close()
	await _wait(0.3)
	main._start_battle()
	main._show_item_toast({"item": g.inventory_items()[0], "status": "added"})
	await _wait(1.0)
	await _snap(out + "/combat.png")
	var chest: Dictionary = g.open_chest("legendaire", 20, 0.0, true, true)
	g.pending_chest = chest
	var rs := ResultScreen.new(20, 3, chest, "Monter à l'étage 21", 9)
	main._open_modal(rs)
	await _wait(0.5)
	rs._cv.arm()
	rs._cv.t = rs._cv._t0 + rs._cv.open_at - 0.02
	await _wait(3.2)
	await _snap(out + "/loot.png")
	quit()


func _shot(main, scr: Control, path: String) -> void:
	main._open_modal(scr)
	await _wait(0.5)
	await _snap(path)
	if is_instance_valid(scr):
		scr.queue_free()
	await _wait(0.2)


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0
