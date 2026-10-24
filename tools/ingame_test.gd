extends SceneTree
## Test en jeu : la vraie scène principale, pilotée par de vrais clics (comme un doigt), sans appeler les fonctions internes.
## xvfb-run -a godot --path . --resolution 720x1280 -s tools/ingame_test.gd -- <dossier de captures>
## Parcours : onglet Équipage -> « Voir en 3D » -> les 17 gestes -> recrutement -> expédition (briefing -> Décoller -> combat -> résultat).

var failures := 0
var out := "/tmp"
var main: Control
var gs: Node


func _check(ok: bool, label: String) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/ig_%s.png" % [out, name])


## Vrai clic au centre d'un contrôle (appui puis relâchement).
func _click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.position = p
	b.global_position = p
	b.pressed = true
	b.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(b)
	await _frames(2)
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.position = p
	r.global_position = p
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(3)


func _visible_on_screen(c: Control) -> bool:
	return c.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(720, 1280)).encloses(c.get_global_rect())


func _scroll_to(page: String, c: Control) -> void:
	var sc: ScrollContainer = main._pages[page].get_meta("scroll")
	sc.ensure_control_visible(c)
	await _frames(3)


func _fps_phase(label: String) -> void:
	await _frames(30)
	print("FPS  %s : %d images/s (rendu logiciel llvmpipe, non représentatif d'un téléphone)" % [label, Engine.get_frames_per_second()])


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	await process_frame
	gs = root.get_node("GameState")
	gs.save_path = "user://ingame_test.json"
	gs.reset()
	gs.rng.seed = 11
	gs.give_hero("rex", 4)
	gs.give_hero("bolt", 3)
	gs.give_hero("lumi", 3)
	gs.give_hero("jett", 2)
	gs.give_hero("vega", 2)
	gs.give_hero("sira", 2)
	gs.res["credits"] = 50000.0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(6)

	# --- Onglet Équipage (clic sur le vrai bouton d'onglet)
	await _click(main._tab_buttons["crew"])
	_check(main._pages["crew"].visible, "clic sur l'onglet Équipage : la page s'affiche")
	await _shot("crew")

	# --- Les 18 cartes existent, les 6 possédées montrent « Voir en 3D »
	var owned := 0
	for id in main._hero_ui:
		if main._hero_ui[id].view3d.visible:
			owned += 1
	_check(main._hero_ui.size() == 18 and owned == 6, "18 cartes d'équipage, 6 possédées avec le bouton Voir en 3D (%d)" % owned)

	# --- Fiche 3D de chaque équipier possédé : clic, modèle chargé, geste d'accueil
	for id in ["rex", "bolt", "lumi", "jett", "vega", "sira"]:
		var btn: Button = main._hero_ui[id].view3d
		await _scroll_to("crew", btn)
		await _click(btn)
		_check(main._sheet.visible, "%s : clic sur Voir en 3D ouvre la fiche" % id)
		var v = main._sheet_view
		_check(v._model != null and v.hero_id == id, "%s : modèle 3D chargé" % id)
		_check(v._anim != null and v._anim.current_animation == "Talk", "%s : il parle d'abord (geste = %s)" % [id, v._anim.current_animation if v._anim else "?"])
		_check(main._sheet_quote.text.begins_with("«"), "%s : réplique affichée" % id)
		await _fps_phase("fiche 3D " + id)
		if id == "rex":
			await _shot("sheet_rex")
			# --- les 17 gestes par de vrais clics
			var flow_buttons: Array = []
			for b in main._sheet.find_children("*", "Button", true, false):
				for g in main.GESTURES:
					if b.text == g[1]:
						flow_buttons.append([b, g[0]])
			_check(flow_buttons.size() == 17, "17 boutons de geste dans la fiche (%d)" % flow_buttons.size())
			for fb in flow_buttons:
				await _click(fb[0])
				var cur: String = v._anim.current_animation
				_check(cur == fb[1], "geste %s : l'animation jouée est %s" % [fb[1], cur])
				if fb[1] in ["Wave", "Hit", "Laugh"]:
					await _shot("gesture_" + fb[1])
		# fermeture
		var close: Button = main._sheet_close
		await _click(close)
		_check(not main._sheet.visible, "%s : Fermer referme la fiche" % id)

	# --- Après 3 s, le geste d'accueil passe à Work (en salle) ou Wave
	gs.set_room_worker("mine", "jett") if gs.has_method("set_room_worker") else null
	var jb: Button = main._hero_ui["jett"].view3d
	await _scroll_to("crew", jb)
	await _click(jb)
	await create_timer(3.4).timeout
	await _frames(3)
	var after: String = main._sheet_view._anim.current_animation
	_check(after in ["Wave", "Work", "Idle"], "après 3 s : geste de situation (%s)" % after)
	await _click(main._sheet_close)

	# --- Recrutement par vrai clic : la nouvelle carte ouvre la fiche
	await _scroll_to("crew", main._recruit_btn)
	var got_new := false
	for i in 12:
		await _click(main._recruit_btn)
		if main._sheet.visible:
			got_new = main._sheet_title.text.begins_with("Nouvel équipier")
			if got_new:
				await _shot("recruit_new")
			await _click(main._sheet_close)
			if got_new:
				break
	_check(got_new, "recruter : une nouvelle carte ouvre « Nouvel équipier » (ouverte au bout de %d recrutements)" % gs.recruits)

	# --- Expédition : briefing puis combat puis résultat
	gs.set_squad_member(0, 0, "jett")
	await _click(main._tab_buttons["exp"])
	await _frames(3)
	var dest: Button = main._slot_ui[0].dest["asteroids"]
	await _scroll_to("exp", dest)
	await _click(dest)
	_check(main._sheet.visible and main._live == null, "expédition : le briefing s'affiche avant le combat")
	_check(main._sheet_go.visible and main._sheet_title.text.begins_with("Briefing"), "briefing : bouton Décoller visible")
	await _shot("briefing")
	await _click(main._sheet_go)
	_check(main._live != null, "Décoller lance le combat en direct")
	await _frames(5)
	await _shot("combat")
	var lv = main._live
	lv.sim.assist = true
	var guard := 0
	while not lv.sim.over and guard < 4000:
		lv.sim.step(1.0 / 30.0)
		guard += 1
	await _frames(6)
	_check(lv._result.visible, "fin de combat : l'écran de résultat s'affiche")
	_check(lv._res_crew != null and lv._res_crew.visible, "résultat : un équipier est affiché en 3D")
	var res_clip: String = lv._res_crew._anim.current_animation if lv._res_crew != null and lv._res_crew._anim != null else ""
	_check(res_clip in ["Cheer", "Hit", "Idle"], "résultat : geste %s (Victoire ou Coup reçu)" % res_clip)
	await _fps_phase("résultat")
	await _shot("result")
	lv.closed.emit(false)
	await _frames(3)
	_check(main._live == null, "retour à l'écran des expéditions")

	# --- Deuxième lancement de la même destination : pas de nouveau briefing
	await _scroll_to("exp", dest)
	await _click(dest)
	_check(main._live != null and not main._sheet.visible, "relance de la même destination : pas de second briefing")

	print("Échecs : %d" % failures)
	quit(1 if failures > 0 else 0)
