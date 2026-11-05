extends SceneTree
## Vérifie que chaque bouton de barre du haut reçoit bien l'appui, sur tous les écrans qui en ont une
## (xvfb-run -a godot --path . --resolution 720x1280 -s tools/topbar_check.gd).
var g
var main: Control
var fails := 0


func _initialize() -> void:
	await process_frame
	g = root.get_node("Game")
	g.save_path = "user://check.json"
	g.reset()
	g.intro_seen = true
	g.tutorial_done = true
	g.seen_scenes = ["prologue", "c1_entree"]
	g.best_stage = 12
	g.stage = 12
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for r in ["rare", "rare", "rare", "epique"]:
		g.receive_item(Items.roll(rng, r, 12, "arme"))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(0.5)
	var screens := {
		"Héros": func(): main._open_collection(0),
		"Fiche": func(): main._open_modal(HeroScreen.new("mara", 1)),
		"Recruter": func(): main._open_recruit(),
		"Boutique": func(): main._open_shop(),
		"Carte": func(): main._open_map(),
		"Réglages": func(): main._open_settings(),
		"Détail d'objet": func(): main._open_item(int(g.inventory_items()[0].id)),
		"Choix d'objet": func(): main._open_pick("mara", "arme"),
		"À qui": func(): main._open_who(int(g.inventory_items()[0].id), "Nouvel objet"),
		"Forge": func(): main._open_forge(),
		"Évolution": func(): main._open_modal(EvolveScreen.new("mara")),
		"Journal": func(): main._open_journal(),
	}
	for name in screens:
		(screens[name] as Callable).call()
		await _wait(0.4)
		var m = main._modal
		if m == null or not is_instance_valid(m):
			print("— ", name, " : écran non ouvert")
			continue
		var bar: Node = _find_bar(m)
		if bar == null:
			print("— ", name, " : pas de barre du haut")
		else:
			var kids: Array = bar.get_children()
			kids.reverse()
			for b in kids:
				if not is_instance_valid(b) or not is_instance_valid(bar):
					break
				if not (b is Button) or not (b as Button).is_visible_in_tree():
					continue
				var ok := [false]
				(b as Button).pressed.connect(func(): ok[0] = true)
				var c: Vector2 = (b as Button).get_global_rect().get_center()
				var label: String = (b as Button).text if (b as Button).text != "" else "(icône)"
				_click(c)
				await _wait(0.2)
				if ok[0]:
					print("ok  ", name, " · ", label)
				else:
					fails += 1
					print("ÉCHEC ", name, " · ", label)
				if not is_instance_valid(m) or main._modal != m:
					break
				# un menu ⋮ ouvert : on le referme en appuyant ailleurs
				_click(Vector2(300, 56))
				await _wait(0.2)
		if main._modal != null and is_instance_valid(main._modal):
			main._modal.queue_free()
		await _wait(0.3)
	print("TOPBAR échecs : ", fails)
	quit()


func _find_bar(n: Node) -> Node:
	if n == null:
		return null
	if n.name == "TopBar":
		return n
	for ch in n.get_children():
		var r := _find_bar(ch)
		if r != null:
			return r
	return null


func _click(p: Vector2) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = p
	d.global_position = p
	root.push_input(d)
	var u := d.duplicate()
	u.pressed = false
	root.push_input(u)


func _wait(s: float) -> void:
	var t := 0.0
	while t < s:
		await process_frame
		t += 1.0 / 60.0
