extends SceneTree
## Simule un glissement au doigt (écran tactile) et vérifie que la page défile.
## xvfb-run -a godot --path . --resolution 720x1280 -s tools/touch_test.gd

var failures := 0


func _drag(from: Vector2, to: Vector2) -> void:
	# Souris -> toucher émulé : le chemin le plus proche d'un vrai doigt sur Android.
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.position = from
	b.global_position = from
	b.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(b)
	await process_frame
	var steps := 8
	for i in steps:
		var m := InputEventMouseMotion.new()
		m.position = from.lerp(to, float(i + 1) / steps)
		m.global_position = m.position
		m.relative = (to - from) / steps
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await process_frame
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	r.position = to
	r.global_position = to
	Input.parse_input_event(r)
	await process_frame
	await process_frame


func _snapshot() -> String:
	var gs = root.get_node("GameState")
	var lv := 0
	for id in gs.heroes:
		lv += gs.heroes[id].level
	var ups := 0
	for id in gs.upgrade_levels:
		ups += gs.upgrade_levels[id]
	return "%d/%d/%d/%d" % [gs.recruits, lv, ups, gs.expeditions_done + (1 if gs.slots[0].dest != "" else 0)]


func _check_scroll(main: Node, tab: String, start: Vector2, label: String) -> void:
	main._show_tab(tab)
	await process_frame
	await process_frame
	var sc: ScrollContainer = main._pages[tab].get_meta("scroll")
	sc.scroll_vertical = 0
	await process_frame
	var before := _snapshot()
	await _drag(start, start + Vector2(0, -300))
	var accidental := _snapshot() != before
	var ok := sc.scroll_vertical > 100 and not accidental
	print(("ok   " if ok else "FAIL ") + "%s : scroll_vertical=%d%s" % [label, sc.scroll_vertical,
		"  ACHAT ACCIDENTEL !" if accidental else ""])
	if not ok:
		failures += 1


func _initialize() -> void:
	await process_frame
	Input.emulate_touch_from_mouse = true
	var gs = root.get_node("GameState")
	gs.save_path = "user://touch_test_save.json"
	gs.new_game()
	gs.add_res("credits", 5000.0)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Héros : on part d'un portrait, d'un texte, d'un bouton.
	await _check_scroll(main, "captain", Vector2(100, 500), "capitaine depuis le personnage")
	await _check_scroll(main, "captain", Vector2(400, 1000), "capitaine depuis un bouton")
	await _check_scroll(main, "crew", Vector2(80, 700), "équipage depuis le portrait")
	await _check_scroll(main, "crew", Vector2(400, 640), "équipage depuis un texte de carte")
	await _check_scroll(main, "crew", Vector2(400, 790), "équipage depuis un bouton")
	await _check_scroll(main, "exp", Vector2(360, 450), "exp depuis la scène 3D")
	main._show_tab("exp")
	await process_frame
	await process_frame
	var opt: Control = main._slot_ui[0].members[1].opt
	main._pages["exp"].get_meta("scroll").scroll_vertical = 0
	await process_frame
	await process_frame
	print("liste déroulante (poste Ingénieur) : ", opt.get_global_rect(), " filtre=", opt.mouse_filter)
	var squad_before: Array = gs.slots[0].squad.duplicate()
	await _check_scroll(main, "exp", opt.get_global_rect().get_center(), "exp depuis une liste déroulante de poste")
	await process_frame
	await process_frame
	var popup_open: bool = opt.get_popup().visible
	var same: bool = gs.slots[0].squad == squad_before
	print(("ok   " if (not popup_open and same) else "FAIL ") + "après glissement sur la liste : fermée=%s, poste inchangé=%s" % [not popup_open, same])
	if popup_open or not same:
		failures += 1
	await _check_scroll(main, "exp", Vector2(360, 1060), "exp depuis un bouton")
	await _check_scroll(main, "ship", Vector2(360, 700), "ship depuis une carte")
	# Un simple tap (sans glisser) doit toujours déclencher le bouton.
	main._show_tab("crew")
	await process_frame
	await process_frame
	var sc: ScrollContainer = main._pages["crew"].get_meta("scroll")
	sc.scroll_vertical = 0
	await process_frame
	var before: int = gs.recruits
	await _drag(main._recruit_btn.get_global_rect().get_center(), main._recruit_btn.get_global_rect().get_center())
	var tapped: bool = gs.recruits == before + 1
	print(("ok   " if tapped else "FAIL ") + "tap simple sur « Recruter » : recrues %d -> %d" % [before, gs.recruits])
	if not tapped:
		failures += 1
	# Un tap simple sur une liste de poste doit l'ouvrir.
	gs.new_game()
	main._refresh()
	main._show_tab("exp")
	await process_frame
	await process_frame
	var opt2: OptionButton = main._slot_ui[0].members[0].opt
	main._pages["exp"].get_meta("scroll").scroll_vertical = 0
	await process_frame
	await process_frame
	await _drag(opt2.get_global_rect().get_center(), opt2.get_global_rect().get_center())
	await process_frame
	var opened: bool = opt2.get_popup().visible
	print(("ok   " if opened else "FAIL ") + "tap simple sur une liste de poste : ouverte=%s" % opened)
	if not opened:
		failures += 1
	opt2.get_popup().hide()
	await process_frame
	# Scénario du joueur : nouvelle partie -> Expéditions -> toucher « Champ d'astéroïdes ».
	gs.new_game()
	main._refresh()
	main._show_tab("exp")
	await process_frame
	await process_frame
	var esc: ScrollContainer = main._pages["exp"].get_meta("scroll")
	var btn: Button = main._slot_ui[0].dest["asteroids"]
	esc.ensure_control_visible(btn)
	await process_frame
	await process_frame
	var c := btn.get_global_rect().get_center()
	await _drag(c, c)
	var launched: bool = gs.slots[0].dest == "asteroids"
	print(("ok   " if launched else "FAIL ") + "nouvelle partie : un tap sur « Champ d'astéroïdes » lance l'expédition (dest=%s, bouton désactivé=%s)" % [gs.slots[0].dest, btn.disabled])
	if not launched:
		failures += 1
	quit(1 if failures > 0 else 0)
