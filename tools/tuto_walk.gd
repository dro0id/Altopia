extends SceneTree
## Parcours du tutoriel comme un joueur : touche l'élément éclairé (ou le bouton de la bulle) à chaque étape,
## prend une capture par étape et vérifie que le tutoriel se termine
## (xvfb-run -a godot --path . --resolution 720x1280 -s tools/tuto_walk.gd -- <dossier>).
## Point de départ : l'arrivée du chapitre 1 (voyage fait à bord), comme pour un joueur qui rejoint la mission.
var g
var main: Control
var out := ""


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	await process_frame
	g = root.get_node("Game")
	g.save_path = "user://tuto.json"
	g.reset()
	g.intro_seen = true
	# le tutoriel de combat commence à l'arrivée, une fois le voyage du chapitre 1 fait à bord de l'Aurore
	g.seen_scenes = ["prologue"]
	for sc in Story.chapter_scenes(1):
		g.seen_scenes.append(String(sc.id))
	g.chapters_done = [1]
	g.ship.unlock()
	g.vance_aboard()
	g.tips.append("ship")
	g.credits = 30.0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(1.5)
	# l'accueil est l'Aurore : on rejoint la mission comme un joueur (« Rejoindre »)
	if main._modal is ShipScreen:
		print("Aurore → Rejoindre")
		main._open_mission()
		await _wait(1.0)
	await _play_dialogues()
	await _wait(1.0)
	var coach: Coach = main.coach
	var guard := 0
	while coach.step >= 0 and guard < 12:
		guard += 1
		await _wait(0.8)
		if coach.step < 0:
			break
		var st: int = coach.step
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/tuto_%d.png" % [out, st + 1])
		var lv0: int = int(g.levels[coach.hero_id()])
		var p: Vector2 = coach._btn_rect.get_center() if coach._btn_rect.size != Vector2.ZERO else coach._target.get_center()
		print("étape %d · paused=%s · cible %s · appui %s" % [st + 1, str(paused), str(coach._target), str(p)])
		_click(p)
		await _wait(0.4)
		if st == 4:
			print("  niveau : %d → %d" % [lv0, int(g.levels[coach.hero_id()])])
	print("TUTO terminé=%s pause=%s modal=%s" % [str(g.tutorial_done), str(paused), str(main._modal)])
	quit(0 if g.tutorial_done else 1)


## Scènes d'histoire qui s'ouvrent en chemin (ex. l'arrivée) : on les lit jusqu'au bout comme un joueur,
## en prenant la première réponse quand le Capitaine doit choisir.
func _play_dialogues() -> void:
	var guard := 0
	while main._modal is DialogueScreen and guard < 80:
		guard += 1
		var d: DialogueScreen = main._modal
		var l: Dictionary = d._cur()
		if l.has("choice") and d._choice < 0:
			d._pick(0)
		else:
			d._next()
		await _wait(0.15)
		if main._modal is DialogueScreen and main._modal != d:
			print("scène suivante")
	if guard > 0:
		print("scènes lues (%d répliques)" % guard)


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
