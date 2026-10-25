class_name AutoTest
extends Node
## Parcours de test en jeu piloté par de vrais clics, embarquable dans l'APK de test (fonction « autotest ») ou lancé par tools/ingame_test.gd.
## Écrit un rapport (report.txt), des captures (ig_*.png) et un fichier done dans le dossier de sortie ; 0 échec = succès.
## Test en jeu : la vraie scène principale, pilotée par de vrais clics (comme un doigt), sans appeler les fonctions internes.
## xvfb-run -a godot --path . --resolution 720x1280 -s tools/ingame_test.gd -- <dossier de captures>
## Parcours : onglet Équipage -> « Voir en 3D » -> les 17 gestes -> recrutement -> expédition (briefing -> Décoller -> combat -> résultat).

var failures := 0
var out := "/tmp"
var _report: FileAccess
var main: Control
var gs: Node


func _log(line: String) -> void:
	print(line)
	if _report != null:
		_report.store_line(line)
		_report.flush()


func _check(ok: bool, label: String) -> void:
	_log(("ok   " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	get_tree().root.get_viewport().get_texture().get_image().save_png("%s/ig_%s.png" % [out, name])


## Vrai clic au centre d'un contrôle (appui puis relâchement).
func _click(c: Control) -> void:
	# position en pixels de fenêtre : le contenu est mis à l'échelle (mode canvas_items), donc on applique la transformation d'affichage
	var p: Vector2 = get_tree().root.get_final_transform() * c.get_global_rect().get_center()
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


func _scroll_to(page: String, c: Control) -> void:
	var sc: ScrollContainer = main._pages[page].get_meta("scroll")
	sc.ensure_control_visible(c)
	await _frames(3)


## Contrôles visibles qui dépassent de l'écran (débordement de mise en page).
func _overflow(label: String) -> void:
	var win := Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size)
	var bad := 0
	for n in main.find_children("*", "Control", true, false):
		var c: Control = n
		if c.is_visible_in_tree() and c.get_global_rect().size.x > win.size.x + 2.0:
			bad += 1
	_log("LAYOUT %s : zone %dx%d, contrôles plus larges que l'écran : %d" % [label, int(win.size.x), int(win.size.y), bad])


func _fps_phase(label: String) -> void:
	await _frames(30)
	_log("FPS  %s : %d images/s" % [label, Engine.get_frames_per_second()])


func run(main_scene: Control, out_dir: String) -> int:
	main = main_scene
	out = out_dir
	DirAccess.make_dir_recursive_absolute(out)
	_report = FileAccess.open(out + "/report.txt", FileAccess.WRITE)
	_log("démarrage du parcours (fenêtre %dx%d)" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y])
	await get_tree().process_frame
	gs = get_tree().root.get_node("GameState")
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
	main._refresh()
	await _frames(20)

	# --- Écran « Pendant ton absence » éventuel (sauvegarde existante) : on clique sur « Tout récupérer »
	for b in main.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and b.text == "Tout récupérer":
			await _click(b)
			_log("info : écran de retour d'absence fermé par un clic")
			break
	await _frames(10)

	# --- Onglet Équipage (clic sur le vrai bouton d'onglet)
	await _click(main._tab_buttons["crew"])
	_check(main._pages["crew"].visible, "clic sur l'onglet Équipage : la page s'affiche")
	await _shot("crew")
	_overflow("équipage")

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
	await get_tree().create_timer(3.4).timeout
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

	if main._live != null:       # la relance du dernier scénario a ouvert un combat : on le ferme
		main._live.closed.emit(false)
		await _frames(5)
	# --- Tutoriel sur une partie neuve : introduction, missions, onglets verrouillés, récompense
	gs.reset()
	gs.new_game()
	gs.start_tutorial()
	gs.save_path = "user://ingame_test.json"
	main._refresh()
	main._show_intro()
	await _frames(20)
	var intro: Node = null
	for c in main.get_children():
		if c is IntroUI:
			intro = c
	_check(intro != null, "partie neuve : l'introduction s'affiche")
	await _frames(40)
	await _shot("intro")
	if intro != null:
		await _click(intro._skip)
		await _frames(5)
		_check(gs.tuto_intro_seen, "« Passer » ferme l'introduction (marquée comme vue)")
	await _frames(25)
	main._refresh()
	await _frames(5)
	_check(main._tuto_panel.visible and main._tuto_title.text == "Mettre Rex aux Moteurs", "mission 1 affichée dans le bandeau")
	_check(main._tab_buttons["exp"].disabled and main._tab_buttons["captain"].disabled and not main._tab_buttons["base"].disabled, "Expéditions et Capitaine verrouillés au départ")
	_check(main._tab_buttons["base"].text == "Vaisseau", "au départ : pas de Base, l'onglet s'appelle Vaisseau")
	var visible_tiles := 0
	for rid in main._base_ui._tiles:
		if (main._base_ui._tiles[rid].btn as Button).visible:
			visible_tiles += 1
	_check(visible_tiles == 3, "au départ : trois postes seulement (%d)" % visible_tiles)
	_check(not main._recruit_btn.visible, "au départ : pas de recrutement (il vient avec la Base)")
	await _click(main._tab_buttons["crew"])
	await _click(main._tab_buttons["exp"])
	_check(not main._pages["exp"].get_meta("scroll").visible, "un clic sur un onglet verrouillé ne l'ouvre pas")
	await _frames(15)
	_check(main._tuto_target == main._tab_buttons["base"], "la cible de la mission pulse (onglet Base) quand on est ailleurs")
	await _shot("tuto_mission1")
	gs.set_room_crew("mine", "rex")
	await _frames(25)
	_check(main._tuto_btn.visible, "mission 1 faite : le bouton de récompense apparaît")
	var cr0: float = gs.res["credits"]
	await _click(main._tuto_btn)
	_check(gs.tuto_step == 1 and gs.res["credits"] >= cr0 + 400.0, "clic sur Récupérer : +400 crédits, mission 2")
	_check(main._toast_label.modulate.a > 0.3 and main._toast_label.text.begins_with("Mission accomplie"), "annonce « Mission accomplie » affichée")
	for i in 120:
		gs.tick(1.0)
	await _frames(25)
	await _click(main._tuto_btn)
	await _frames(10)
	_check(gs.tuto_step == 2 and not main._tab_buttons["exp"].disabled and main._tab_buttons["captain"].disabled, "mission 2 faite : Expéditions s'ouvre, Capitaine reste fermé")
	_check(main._toast_label.text.contains("Expéditions"), "annonce du déblocage « Expéditions »")
	await _shot("tuto_unlock")

	_log("Échecs : %d" % failures)
	_log("Appareil : %s, Android %s, rendu %s, fenêtre %dx%d" % [OS.get_model_name(), OS.get_version(), RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size().x, DisplayServer.window_get_size().y])
	_report.close()
	_report = null
	var done := FileAccess.open(out + "/done", FileAccess.WRITE)
	done.store_string(str(failures))
	done.close()
	return failures
