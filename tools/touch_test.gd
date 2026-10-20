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
	var page: String = "base" if tab in ["salles", "atelier", "lab", "ship", "rang"] else tab
	var sc: ScrollContainer = main._pages[page].get_meta("scroll")
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
	# Atelier : un glissement sur un emplacement visé ne doit pas le choisir ; un tap le choisit.
	main._show_tab("atelier")
	await process_frame
	await process_frame
	var chip: Button = main._base_ui._at_slot_btns["helmet"]
	var cc := chip.get_global_rect().get_center()
	await _drag(cc, cc + Vector2(0, -150))
	var picked_by_drag: bool = gs.atelier_slot != ""
	print(("ok   " if not picked_by_drag else "FAIL ") + "glissement sur un emplacement visé : choisi=%s" % picked_by_drag)
	if picked_by_drag:
		failures += 1
	main._pages["base"].get_meta("scroll").scroll_vertical = 0
	await process_frame
	cc = chip.get_global_rect().get_center()
	await _drag(cc, cc)
	var picked_by_tap: bool = gs.atelier_slot == "helmet"
	print(("ok   " if picked_by_tap else "FAIL ") + "tap sur un emplacement visé : choisi=%s" % picked_by_tap)
	if not picked_by_tap:
		failures += 1
	gs.atelier_slot = ""
	await _check_scroll(main, "ship", Vector2(360, 700), "vaisseau depuis une carte")
	await _check_scroll(main, "lab", Vector2(360, 760), "labo depuis un bouton")
	await _check_scroll(main, "rang", Vector2(360, 760), "rang depuis une carte")
	# Une tuile de salle : un glissement ne l'ouvre pas, un simple tap ouvre la fiche.
	main._show_tab("salles")
	await process_frame
	await process_frame
	var tile: Button = main._base_ui._tiles["mine"].btn
	var tc := tile.get_global_rect().get_center()
	await _drag(tc, tc + Vector2(0, -200))
	var opened_by_drag: bool = main._base_ui.sheet_open()
	print(("ok   " if not opened_by_drag else "FAIL ") + "glissement sur une tuile de salle : fiche ouverte=%s" % opened_by_drag)
	if opened_by_drag:
		failures += 1
	main._base_ui.close_sheet()
	main._pages["base"].get_meta("scroll").scroll_vertical = 0
	await process_frame
	tc = tile.get_global_rect().get_center()
	await _drag(tc, tc)
	var opened_by_tap: bool = main._base_ui.sheet_open()
	print(("ok   " if opened_by_tap else "FAIL ") + "tap sur une tuile de salle : fiche ouverte=%s" % opened_by_tap)
	if not opened_by_tap:
		failures += 1
	main._base_ui.close_sheet()
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
	var launched: bool = main._live != null      # un tap lance le combat en direct du vaisseau 1
	print(("ok   " if launched else "FAIL ") + "nouvelle partie : un tap sur « Champ d'astéroïdes » lance le combat en direct (combat ouvert=%s, bouton désactivé=%s)" % [launched, btn.disabled])
	if not launched:
		failures += 1
	else:
		# Dans l'arène, un tap à droite doit envoyer le vaisseau dans le couloir de droite.
		var lv: Control = main._live.view
		var vr: Rect2 = lv.get_global_rect()
		var tap := vr.position + Vector2(vr.size.x * 0.5 + lv._sc() * 130.0, vr.size.y * 0.5)
		await _drag(tap, tap)
		await process_frame
		var right: bool = main._live.sim.lane == 2
		print(("ok   " if right else "FAIL ") + "arène : un tap à droite choisit le couloir de droite (couloir=%d)" % main._live.sim.lane)
		if not right:
			failures += 1
		main._live.closed.emit(false)
		await process_frame
		# Dérive : un premier tap choisit la case voisine, un second la scanne.
		main._exp_mode = "derive"
		main._refresh()
		await process_frame
		var esc2: ScrollContainer = main._pages["exp"].get_meta("scroll")
		var btn2: Button = main._slot_ui[0].dest["asteroids"]
		esc2.ensure_control_visible(btn2)
		await process_frame
		await process_frame
		var c2 := btn2.get_global_rect().get_center()
		await _drag(c2, c2)
		await process_frame
		var d_ok: bool = main._live != null and main._live.has_method("_on_cell")
		print(("ok   " if d_ok else "FAIL ") + "dérive : un tap sur la destination ouvre la grille")
		if not d_ok:
			failures += 1
		else:
			main._live._guide.visible = false
			var cell: Button = main._live._cells[5 * 6 + 2]
			var cell_c := cell.get_global_rect().get_center()
			await _drag(cell_c, cell_c)
			await process_frame
			var sel_ok: bool = main._live.sel == [5, 2]
			print(("ok   " if sel_ok else "FAIL ") + "dérive : un premier tap choisit la case voisine (sel=%s)" % str(main._live.sel))
			var e0: float = main._live.sim.energy
			await _drag(cell_c, cell_c)
			await process_frame
			var scan_ok: bool = main._live.sim.cells[6 * 0 + 5 * 6 + 2].seen and main._live.sim.energy < e0
			print(("ok   " if scan_ok else "FAIL ") + "dérive : un second tap scanne la case (énergie %s -> %s)" % [str(e0), str(main._live.sim.energy)])
			if not sel_ok or not scan_ok:
				failures += 1
			main._live.closed.emit(false)
			await process_frame
	quit(1 if failures > 0 else 0)
