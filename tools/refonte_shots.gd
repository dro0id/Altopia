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
	g.save_path = "user://shot.json"
	g.reset()
	g.stage = 12
	g.best_stage = 19
	g.tutorial_done = true
	g.intro_seen = true
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
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(1.0)
	var shots := {
		"combat": func(): pass,
		"heros": func(): main._open_collection(0),
		"objets": func(): main._open_collection(1),
		"ensembles": func(): main._open_collection(2),
		"fiche": func(): main._open_modal(HeroScreen.new("mara", 1)),
		"fiche_stats": func(): main._open_modal(HeroScreen.new("mara", 0)),
		"recrutement": func(): main._open_recruit(),
		"boutique": func(): main._open_shop(),
		"carte": func(): main._open_map(),
		"reglages": func(): main._open_settings(),
	}
	for k in shots:
		if not only.is_empty() and not only.has(k):
			continue
		(shots[k] as Callable).call()
		await _wait(0.6)
		await _snap(out + "/" + k + ".png")
		if main._modal != null and is_instance_valid(main._modal):
			main._modal.queue_free()
		await _wait(0.3)
	quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0
