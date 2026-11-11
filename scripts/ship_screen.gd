class_name ShipScreen
extends Overlay
## Onglet Aurore, l'accueil du jeu dès l'étage 5 (maquettes KB, JE, PA, RC) : l'Aurore en coupe 3D, étiquettes des salles,
## fiche d'une salle touchée, carte « Mission en cours » (le combat, qui continue pendant qu'on est à bord),
## chantier conseillé et « Tout récolter ». Les écrans de salle s'ouvrent par-dessus (signal room_requested).

signal room_requested(room: String)
signal builds_requested
signal mission_requested
signal recruit_requested
signal todo_requested


var view: ShipView
var _st: Control
var _bg: Control
var _labels: Control
var _sheet: Control
var _harvest: Button
var _cut: Button
var _sel := ""
var _sheet_btns: Array = []
var _t := 0.0
var _sub: Label
var _lab_rects := {}
var _mission: Control
var _advice: Control
var _advice_btn: Button
var _todo: Button
var _adv := {}
var _join: Button
static var mission_gain := 0.0      # crédits gagnés par la mission pendant qu'on est à bord (affichés sur la carte)


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_bg)
	_st.add_child(_bg)
	view = ShipView.new()
	view.position = Vector2(0, 236)
	view.size = Vector2(720, UI.H - 236 - NavBar.total() - 150)
	_st.add_child(view)
	view.setup(Game.ship.level, Game.ship.posts, Game.ship.rooms)
	view.room_tapped.connect(_select)
	_labels = Control.new()
	_labels.position = view.position
	_labels.size = view.size
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.draw.connect(_draw_labels)
	_st.add_child(_labels)
	# la vue 3D montre une image non initialisée tant que ses premières images ne sont pas rendues
	# (au tout premier affichage, le temps de compiler les shaders) : elle apparaît en fondu ensuite
	view.modulate.a = 0.0
	_labels.modulate.a = 0.0
	_reveal_view.call_deferred()
	var bar := M3.top_bar(_st, "L’Aurore", Callable(), [Wallet.make()], false)
	var title: Label = bar.get_node("Title")
	title.position.y = 18
	_sub = UI.label(bar, "", M3.fs(22), UI.MUTED)
	_sub.position = Vector2(32, 66)
	_sub.size = Vector2(340, 32)
	_sub.clip_text = true
	_cut = _round_button("◐", Vector2(720 - 32 - 88, 300))
	_cut.pressed.connect(func():
		view.set_cut(not view.cut_mode)
		_cut.text = "◐" if view.cut_mode else "●"
		_close_sheet())
	var b2 := _round_button("🛠", Vector2(720 - 32 - 88, 404))
	b2.text = "⚒"
	b2.pressed.connect(func(): builds_requested.emit())
	# mémo de l'écran (maquette E5) : ici avec les boutons ronds, pour laisser les monnaies en haut
	var b3 := _round_button("?", Vector2(720 - 32 - 88, 508))
	if not Help.seen("L’Aurore"):
		b3.add_theme_color_override("font_color", UI.GOLD)
	b3.pressed.connect(func():
		b3.add_theme_color_override("font_color", UI.TEXT)
		Help.show(self, "L’Aurore"))
	# « À faire » (maquette XB) : tout ce qui attend ; pastille rouge = ce qui se réclame
	_todo = _round_button("✓", Vector2(720 - 32 - 88, 612))
	_todo.pressed.connect(func(): todo_requested.emit())
	_todo.draw.connect(func():
		var n := TodoScreen.claim_count()
		if n > 0:
			_todo.draw_circle(Vector2(76, 14), 18, UI.BAR)
			_todo.draw_circle(Vector2(76, 14), 15, UI.RED)
			_todo.draw_string(UI.bold_font(), Vector2(60, 22), str(mini(n, 9)), HORIZONTAL_ALIGNMENT_CENTER, 32, 20, Color.WHITE))
	_harvest = M3.button(_st, "Tout récolter", Rect2(32, UI.H - NavBar.total() - 32 - 96, 656, 96), "success", 30)
	_harvest.pressed.connect(_harvest_all)
	# carte « Mission en cours » (maquette RC)
	_mission = Control.new()
	_mission.position = Vector2(24, 112)
	_mission.size = Vector2(672, 128)
	_mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission.draw.connect(_draw_mission)
	_st.add_child(_mission)
	_join = M3.button(_mission, "Rejoindre", Rect2(472, 24, 184, 80), "main", 26)
	_join.pressed.connect(func():
		if Game.mission_open():
			mission_requested.emit()
		else:
			_objective_go())
	# chantier conseillé
	_advice = Control.new()
	_advice.position = Vector2(24, UI.H - NavBar.total() - 32 - 96 - 16 - 124)
	_advice.size = Vector2(672, 124)
	_advice.draw.connect(_draw_advice)
	_advice.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and not _adv.is_empty():
			accept_event()
			if Game.ship.room_level(String(_adv.room)) <= 0:
				_select(String(_adv.room))
			else:
				room_requested.emit(String(_adv.room)))
	_st.add_child(_advice)
	_advice_btn = M3.button(_advice, "Lancer", Rect2(452, 22, 204, 84), "success", 26)
	_advice_btn.pressed.connect(_launch_advice)
	_sheet = Control.new()
	_sheet.size = Vector2(720, 420)
	_sheet.position = Vector2(0, UI.H - NavBar.total() - 420)
	_sheet.visible = false
	_sheet.draw.connect(_draw_sheet)
	_sheet.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev):
			accept_event())
	_st.add_child(_sheet)
	var b_open := M3.button(_sheet, "Ouvrir la salle", Rect2(368, 300, 320, 96), "secondary", 28)
	b_open.pressed.connect(func(): room_requested.emit(_sel))
	var b_col := M3.button(_sheet, "Récolter", Rect2(32, 300, 320, 96), "success", 28)
	b_col.pressed.connect(_harvest_one)
	var b_build := M3.button(_sheet, "Construire", Rect2(32, 300, 656, 96), "main", 28)
	b_build.pressed.connect(_build_selected)
	_sheet_btns = [b_col, b_open, b_build]
	_labels.gui_input.connect(func(_e): pass)
	move_child(_st, get_child_count() - 1)
	Game.changed.connect(_refresh)
	_refresh()


func _reveal_view() -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(view):
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(view, "modulate:a", 1.0, 0.35)
	tw.tween_property(_labels, "modulate:a", 1.0, 0.35)


func _round_button(glyph: String, p: Vector2) -> Button:
	var b := M3.icon_button(_st, glyph, 34)
	b.size = Vector2(88, 88)
	b.custom_minimum_size = Vector2(88, 88)
	b.position = p
	return b


func _exit_tree() -> void:
	if Game.changed.is_connected(_refresh):
		Game.changed.disconnect(_refresh)


func _refresh() -> void:
	var s: ShipState = Game.ship
	if _todo != null:
		_todo.queue_redraw()
	if view.level != s.level or view.opened != s.rooms.duplicate():
		view.setup(s.level, s.posts, s.rooms)
	var ti := Ship.tier_info(s.level)
	# titres gagnés : Amiral de l'Aurore (niveau 20), sinon Héros de la Ceinture (fin de l'histoire)
	if Game.tips.has("prestige"):
		_sub.text = "Niveau %d · Amiral de l’Aurore" % s.level
	elif Game.tips.has("badge:Héros de la Ceinture"):
		_sub.text = "Niveau %d · Héros de la Ceinture" % s.level
	else:
		_sub.text = "Niveau %d · %s" % [s.level, ti.name]
	var n := s.ready_rooms().size()
	_harvest.text = "Tout récolter · %d salle%s" % [n, "s" if n > 1 else ""] if n > 0 else "Rien à récolter pour l’instant"
	_harvest.disabled = n == 0
	_adv = s.advice(Game) if Game.mission_open() else {}
	_advice.visible = not _adv.is_empty() and not _sheet.visible
	var voyage := not Game.mission_open()
	_mission.size.y = 184.0 if voyage else 128.0
	_join.text = "Y aller" if voyage else "Rejoindre"
	# la plaque de verre déborde (lueur) : en voyage, plus petite et plus haute pour libérer la frise
	_join.position.y = 26.0 if voyage else 24.0
	_join.size.y = 72.0 if voyage else 80.0
	var od := Game.voyage_done()
	_join.visible = not voyage or (od < Story.OBJECTIVES.size() and String(Story.OBJECTIVES[od].go) != "signal")
	if not _adv.is_empty():
		_advice_btn.disabled = not bool(_adv.ok)
		M3.price(_advice_btn, "Lancer" if bool(_adv.ok) else "Bientôt", RoomScreen.price_items(Game.ship.cost_of(Game, String(_adv.room))))
	_advice.queue_redraw()
	_sheet.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	# la mission continue pendant qu'on est à bord, au rythme du farm automatique
	if is_visible_in_tree() and Game.intro_seen and Game.mission_open():
		var g := Game.offline_rate_per_minute() / 60.0 * delta
		Game.credits += g
		mission_gain += g
	_mission.queue_redraw()
	_labels.queue_redraw()
	if _sheet.visible:
		_sheet.queue_redraw()
	if fmod(_t, 1.0) < delta:
		_refresh()


func _draw_bg() -> void:
	var c := _bg
	c.draw_rect(Rect2(0, 0, 720, UI.H), Color("070b1a"))
	for k in 18:
		c.draw_circle(Vector2(110, 1060), 520.0 - k * 28.0, Color(0.7, 0.53, 1.0, 0.012))
	for k in 14:
		c.draw_circle(Vector2(360, 520), 420.0 - k * 28.0, Color(0.1, 0.17, 0.35, 0.03))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 110:
		var p := Vector2(rng.randf() * 720.0, rng.randf() * UI.H)
		var a := 0.25 + rng.randf() * 0.55 + sin(_t * 1.3 + i) * 0.1
		c.draw_circle(p, 1.2 + (2.0 if i % 9 == 0 else 0.0) * 0.6, Color(1, 1, 1, a))


## Étiquettes des salles : nom court, niveau, réserve prête (maquette KB).
## Largeur d'une pastille de salle (même calcul que le dessin).
func _label_w(r: String) -> float:
	var s: ShipState = Game.ship
	var lv := s.room_level(r)
	var to_build := s.is_buildable(r)
	var w := M3.text_w(String(Ship.ROOMS[r].short), 22, true) + 32.0 + (30.0 if lv <= 0 and not to_build else 0.0)
	if lv > 0:
		w += M3.text_w(str(lv), 22, true) + 10.0
	var ready := floorf(float(s.stock.get(r, 0.0)))
	if to_build:
		w += M3.text_w("Construire" if s.building(r).is_empty() else "En chantier", 18, true) + 20.0
	if ready >= 1.0:
		w += M3.text_w("+" + (UI.num(ready) if String(Ship.ROOMS[r].res) == "credits" else str(int(ready))), 20, true) + 28.0
	return w


## Deux salles sur un même pont : leurs pastilles s'écartent l'une de l'autre au lieu de se recouvrir.
func _label_rects(order: Array) -> Dictionary:
	var items: Array = []
	for r in order:
		var lp := view.label_pos(r)
		if lp.is_empty() or not lp.visible:
			continue
		var w := _label_w(r)
		items.append({"r": r, "x": clampf(float(lp.pos.x), 8.0, 712.0 - w), "y": float(lp.pos.y), "w": w})
	items.sort_custom(func(a, b): return a.x < b.x)
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: Dictionary = items[i]
			var b: Dictionary = items[j]
			if absf(a.y - b.y) > 40.0:
				continue
			var over: float = a.x + a.w + 8.0 - b.x
			if over > 0.0:
				a.x = maxf(8.0, a.x - over * 0.5)
				b.x = minf(712.0 - b.w, maxf(b.x, a.x + a.w + 8.0))
	var out := {}
	for it in items:
		out[it.r] = it.x
	return out


func _draw_labels() -> void:
	var c := _labels
	_lab_rects = {}
	var s: ShipState = Game.ship
	# les salles à construire passent en dernier, au-dessus des pastilles voisines
	var order: Array = view.anchors.keys()
	order.sort_custom(func(a, b): return int(s.is_buildable(a)) < int(s.is_buildable(b)))
	var placed := _label_rects(order)
	for r in order:
		var lp := view.label_pos(r)
		if lp.is_empty() or not lp.visible:
			continue
		var col: Color = Ship.ROOMS[r].color
		var lv := s.room_level(r)
		var to_build := s.is_buildable(r)
		var sealed := lv <= 0 and not to_build
		var name := String(Ship.ROOMS[r].short)
		var txt := name
		var w := M3.text_w(txt, 22, true) + 32.0 + (30.0 if sealed else 0.0)
		var lvtxt := "" if lv <= 0 else str(lv)
		var csz := 20
		w += M3.text_w(lvtxt, 22, true) + (10.0 if lvtxt != "" else 0.0)
		var ready := floorf(float(s.stock.get(r, 0.0)))
		var rtxt := ""
		if to_build:
			rtxt = "Construire" if s.building(r).is_empty() else "En chantier"
			csz = 18
			w += M3.text_w(rtxt, csz, true) + 20.0
		if ready >= 1.0:
			rtxt = "+" + (UI.num(ready) if String(Ship.ROOMS[r].res) == "credits" else str(int(ready)))
			w += M3.text_w(rtxt, 20, true) + 28.0
		var p: Vector2 = lp.pos
		var rect := Rect2(p.x, p.y - 22.0, w, 44.0)
		rect.position.x = clampf(rect.position.x, 8.0, 712.0 - w)
		if placed.has(r):
			rect.position.x = float(placed[r])
		var sb := UI.box(Color(0.04, 0.07, 0.15, 0.85), col if not sealed else UI.MUTED, 22, 0)
		if to_build:
			sb.border_color = Color(col, 0.55 + 0.45 * absf(sin(_t * 3.0)))
		sb.set_border_width_all(2)
		c.draw_style_box(sb, rect)
		var x := rect.position.x + 16.0
		if sealed:
			M3.lock(c, Vector2(x + 10, rect.position.y + 22), UI.MUTED, 0.8)
			x += 30.0
		M3.text(c, Vector2(x, rect.position.y + 30), txt, 22, UI.TEXT if not sealed else UI.MUTED, true)
		x += M3.text_w(txt, 22, true) + 10.0
		if lvtxt != "":
			M3.text(c, Vector2(x, rect.position.y + 30), lvtxt, 22, col, true)
			x += M3.text_w(lvtxt, 22, true) + 10.0
		if rtxt != "":
			var rr := Rect2(x, rect.position.y + 6, M3.text_w(rtxt, csz, true) + 20.0, 32)
			c.draw_style_box(UI.box(col, Color(0, 0, 0, 0), 16, 0), rr)
			M3.text(c, Vector2(rr.position.x + 10, rr.position.y + 23), rtxt, csz, Color("06101f"), true)
		# événement à bord (maquette WK) : un « ! » doré au bout de l'étiquette
		if not Game.board.at_room(r).is_empty():
			var ec := Vector2(maxf(22.0, rect.position.x - 2.0), rect.position.y + 2.0)     # coin gauche : la voisine est souvent à droite
			var pulse := 1.0 + 0.12 * sin(_t * 5.0)
			c.draw_circle(ec, 21.0 * pulse, Color(UI.GOLD, 0.25))
			c.draw_circle(ec, 17.0, UI.GOLD)
			M3.text(c, ec + Vector2(-17, 9), "!", 24, Color("06101f"), true, 34, HORIZONTAL_ALIGNMENT_CENTER)
			rect = rect.grow_individual(24, 18, 0, 0)
		_lab_rects[r] = Rect2(rect.position + c.position, rect.size)


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or not M3.is_tap(ev):
		return
	# coordonnées de la scène (sous l'encoche), comme les rectangles des étiquettes
	var p: Vector2 = _st.get_global_transform_with_canvas().affine_inverse() * ev.position
	if _sheet.visible and Rect2(_sheet.position, _sheet.size).has_point(p):
		return
	for r in _lab_rects:
		if (_lab_rects[r] as Rect2).has_point(p):
			var ev2: Dictionary = Game.board.at_room(r)
			if not ev2.is_empty():
				open_event(ev2)
				get_viewport().set_input_as_handled()
				return
			_select(r)
			get_viewport().set_input_as_handled()
			return


## Ouvre la feuille d'un événement à bord.
func open_event(e: Dictionary) -> void:
	Sfx.play("click", -6.0)
	add_child(EventScreen.new(e))


func _select(r: String) -> void:
	_sel = r
	Sfx.play("click", -6.0)
	_sheet.visible = true
	_harvest.visible = false
	_advice.visible = false
	var res := String(Ship.ROOMS[r].res)
	var b: Button = _sheet_btns[0]
	b.visible = res != ""
	(_sheet_btns[1] as Button).position.x = 368.0 if res != "" else 32.0
	(_sheet_btns[1] as Button).size.x = 320.0 if res != "" else 656.0
	_sheet.queue_redraw()


func _close_sheet() -> void:
	_sel = ""
	_sheet.visible = false
	_harvest.visible = true
	_advice.visible = not _adv.is_empty()


func _unhandled_input(ev: InputEvent) -> void:
	if _sheet.visible and M3.is_tap(ev):
		_close_sheet()


## Fiche d'une salle (maquette JE) : nom, niveau, production, réserve, équipage.
func _draw_sheet() -> void:
	if _sel == "":
		return
	var c := _sheet
	var s: ShipState = Game.ship
	var r := _sel
	var info: Dictionary = Ship.ROOMS[r]
	var col: Color = info.color
	M3.sheet(c, Rect2(0, 0, 720, 460))
	c.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, 16, 64, 8))
	var lv := s.room_level(r)
	c.draw_style_box(UI.box(Color("0a1424"), col, 24, 0), Rect2(32, 48, 88, 88))
	RoomScreen._room_glyph(c, r, Vector2(76, 92), col, 0.9)
	var res := String(info.res)
	if lv <= 0:
		_draw_build_sheet(c, r)
		return
	_sheet_btns[2].visible = false
	_sheet_btns[0].visible = res != ""
	_sheet_btns[1].visible = true
	_sheet_btns[1].position.x = 368.0 if res != "" else 32.0
	_sheet_btns[1].size.x = 320.0 if res != "" else 656.0
	M3.text(c, Vector2(144, 88), "%s · niv. %d" % [info.name, lv], 32, UI.TEXT, true, 540)
	M3.text(c, Vector2(144, 126), room_line(r), 24, UI.MUTED, false, 540)
	if res != "":
		var cap := s.capacity(r, Game.best_stage)
		var st := float(s.stock.get(r, 0.0))
		M3.bar(c, Rect2(32, 176, 656, 16), st / maxf(0.001, cap), col)
		var left := (cap - st) / maxf(0.0001, s.rate(r, Game.best_stage)) * 3600.0
		M3.text(c, Vector2(32, 228), "Réserve %s / %s" % [_n(st, res), _n(cap, res)], 24, UI.MUTED)
		M3.text(c, Vector2(32, 228), "pleine" if left <= 1.0 else "pleine dans " + UI.duration(left), 24, UI.MUTED, false, 656, HORIZONTAL_ALIGNMENT_RIGHT)
		(_sheet_btns[0] as Button).text = "Récolter %s" % _n(floorf(st), res) if st >= 1.0 else "Récolter"
		(_sheet_btns[0] as Button).disabled = st < 1.0
	var b := s.building(r)
	var x := 32.0
	var crew: Array = s.posts.get(r, [])
	var y := 266.0 if res != "" else 190.0
	if not b.is_empty():
		M3.text(c, Vector2(32, y), "⏱ Amélioration → niv. %d · %s" % [int(b.to), UI.duration(s.remaining(int(b.end)))], 24, UI.GOLD, true)
	elif crew.is_empty():
		M3.text(c, Vector2(32, y), "Aucun poste occupé" if r != "quartiers" else "Aucun héros au repos", 24, UI.MUTED)
	else:
		for h in crew:
			var nm := String(Data.HEROES[h].name).split(" ")[0]
			var w := M3.text_w(nm + " au poste", 22) + 40.0
			c.draw_style_box(UI.box(Color("0a1424"), M3.OUT, 22, 0), Rect2(x, y - 30, w, 44))
			M3.text(c, Vector2(x + 20, y), nm + " au poste", 22, UI.TEXT)
			x += w + 12.0


## Carte « Mission en cours » : l'étage du combat, son rythme, ce qu'il a rapporté pendant qu'on était à bord.
func _draw_mission() -> void:
	if not Game.mission_open():
		_draw_objective()
		return
	var c := _mission
	var r := Rect2(Vector2.ZERO, c.size)
	var sb := UI.box(Color("0d1733", 0.92), Color(UI.ACCENT, 0.4), 36, 0)
	sb.set_border_width_all(2)
	c.draw_style_box(sb, r)
	# vignette : arène en perspective, trois héros qui sautillent, voyant rouge
	var v := Rect2(16, 16, 96, 96)
	c.draw_style_box(UI.box(Color("101a3a"), Color(0, 0, 0, 0), 20, 0), v)
	for k in 4:
		var yy := v.position.y + 44.0 + k * 14.0
		c.draw_line(Vector2(v.position.x + 10 - k * 3, yy), Vector2(v.end.x - 10 + k * 3, yy), Color(UI.ACCENT, 0.25), 1.5)
	var cols := [Color("4fa8ff"), Color("ffb142"), Color("b388ff")]
	for k in 3:
		var hx := v.position.x + 26.0 + k * 22.0
		var hy := v.position.y + 62.0 - absf(sin(_t * 4.0 + k * 1.3)) * 6.0
		c.draw_circle(Vector2(hx, hy), 8, cols[k])
		c.draw_rect(Rect2(hx - 6, hy + 6, 12, 12), Color(cols[k], 0.8))
	c.draw_circle(Vector2(v.position.x + 14, v.position.y + 14), 6, Color(UI.RED, 0.5 + 0.5 * absf(sin(_t * 3.0))))
	var stg := int(Game.stage)
	var sec := Sector.info(stg)
	var boss := Data.boss_type(stg)
	var where := String(sec.name) if not sec.is_empty() else "Trou de verre"
	M3.text(c, Vector2(132, 40), where.to_upper() + " · EN COURS", 20, UI.ACCENT, true, 330)
	var title := "Secteur %d%s" % [stg, " · gros boss" if boss == "big" else (" · mini-boss" if boss != "" else "")]
	M3.text(c, Vector2(132, 76), title, 28, UI.TEXT, true, 330)
	var line := "Combat auto · +%s/min" % UI.short(Game.offline_rate_per_minute())
	if mission_gain >= 1.0:
		line = "Combat auto · +%s à bord" % UI.short(mission_gain)
	M3.text(c, Vector2(132, 108), line, 22, UI.MUTED, false, 330)


## Chapitre 1 (maquette SC) : objectif de bord en cours et frise du voyage Terre → Altopia.
func _draw_objective() -> void:
	var c := _mission
	var sb := UI.box(Color("0d1733", 0.92), Color(UI.GREEN, 0.45), 36, 0)
	sb.set_border_width_all(2)
	c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size))
	var done := Game.voyage_done()
	var n := Story.OBJECTIVES.size()
	if done >= n:
		M3.text(c, Vector2(28, 40), "CHAPITRE 1 · ARRIVÉE", 20, UI.GREEN, true)
		M3.text(c, Vector2(28, 80), "La Ceinture d’Altopia est en vue", 28, UI.TEXT, true, 600)
	else:
		var o: Dictionary = Story.OBJECTIVES[done]
		M3.text(c, Vector2(28, 40), "CHAPITRE 1 · OBJECTIF %d / %d" % [done + 1, n], 20, UI.GREEN, true)
		M3.text(c, Vector2(28, 78), String(o.title), 28, UI.TEXT, true, 430)
		M3.text(c, Vector2(28, 108), String(o.sub), 22, UI.MUTED, false, 430)
	draw_voyage(c, Rect2(28, 118, 616, 36), done)


## Frise du voyage : Terre, objectifs remplis, Altopia, et le jour du trajet.
static func draw_voyage(ci: CanvasItem, r: Rect2, done: int) -> void:
	var n := Story.OBJECTIVES.size()
	var y := r.position.y + 10.0
	var x0 := r.position.x + 10.0
	var x1 := r.end.x - 12.0
	var k := float(done) / float(n)
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), M3.S3, 3.0)
	ci.draw_line(Vector2(x0, y), Vector2(lerpf(x0, x1, k), y), UI.GREEN, 3.0)
	for i in range(1, n):
		ci.draw_circle(Vector2(lerpf(x0, x1, float(i) / n), y), 5, UI.GREEN if i <= done else M3.S3)
	ci.draw_circle(Vector2(x0, y), 9, Color("4fa8ff"))
	ci.draw_circle(Vector2(x1, y), 12, UI.GOLD)
	var sx := lerpf(x0, x1, k)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(sx + 12, y), Vector2(sx - 6, y - 8), Vector2(sx - 2, y), Vector2(sx - 6, y + 8)]), UI.TEXT)
	var day := int(round(k * Story.VOYAGE_DAYS))
	M3.text(ci, Vector2(r.position.x, r.end.y), "Terre", 20, UI.MUTED)
	M3.text(ci, Vector2(r.position.x, r.end.y), "Jour %d / %d" % [day, Story.VOYAGE_DAYS], 20, UI.MUTED, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(ci, Vector2(r.position.x, r.end.y), "Altopia", 20, UI.GOLD, false, r.size.x, HORIZONTAL_ALIGNMENT_RIGHT)


## « Y aller » : ouvre l'écran de l'objectif en cours.
func _objective_go() -> void:
	var done := Game.voyage_done()
	if done >= Story.OBJECTIVES.size():
		return
	var go := String(Story.OBJECTIVES[done].go)
	match go:
		"recruit":
			recruit_requested.emit()
		"signal":
			pass
		_:
			room_requested.emit(go)


## Chantier conseillé (maquette RC) : le Pont d'abord, sinon la salle la moins chère.
func _draw_advice() -> void:
	if _adv.is_empty():
		return
	var c := _advice
	var s: ShipState = Game.ship
	var r := String(_adv.room)
	var col: Color = Ship.ROOMS[r].color
	var sb := UI.box(Color("0d1733", 0.92), Color(UI.GREEN, 0.4), 36, 0)
	sb.set_border_width_all(2)
	c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size))
	c.draw_style_box(UI.box(Color("0a1424"), col, 20, 0), Rect2(16, 18, 88, 88))
	RoomScreen._room_glyph(c, r, Vector2(60, 62), col, 0.8)
	var lv := s.room_level(r)
	var cost := s.cost_of(Game, r)
	M3.text(c, Vector2(124, 40), "CHANTIER CONSEILLÉ", 20, UI.GREEN, true, 316)
	M3.text(c, Vector2(124, 76), ("Construire : %s" % Ship.ROOMS[r].short) if lv <= 0 else ("%s → niveau %d" % [Ship.ROOMS[r].short, lv + 1]), 28, UI.TEXT, true, 316)
	# le prix est dans le bouton (maquette E3) ; reste la durée
	M3.text(c, Vector2(124, 108), "⏱ " + UI.duration(float(cost.time)), 22, UI.MUTED, false, 316)


## Ce que fait chaque salle, pour la proposer à la construction.
const BLURB := {
	"atelier": "Fabrique des jetons d’objet",
	"serre": "Produit des crédits en continu",
	"quartiers": "Les héros au repos y gagnent des niveaux",
	"hangar": "Navettes et expéditions",
	"antenne": "Capte des jetons de recrutement",
	"labo": "Recherches permanentes pour l’escouade",
	"observatoire": "Plus de butin dans les zones générées",
}


## Fiche d'une salle pas encore construite : ce qu'elle fait, le coût, le bouton Construire.
func _draw_build_sheet(c: Control, r: String) -> void:
	var s: ShipState = Game.ship
	var info: Dictionary = Ship.ROOMS[r]
	_sheet_btns[0].visible = false
	_sheet_btns[1].visible = false
	var b: Button = _sheet_btns[2]
	var to_build := s.is_buildable(r)
	b.visible = to_build
	M3.text(c, Vector2(144, 88), "%s · %s" % [info.name, "à construire" if to_build else "scellée"], 32, UI.TEXT, true, 540)
	if not to_build:
		M3.text(c, Vector2(144, 126), "S’ouvre au niveau %d du vaisseau" % int(info.unlock), 24, UI.MUTED, false, 540)
		return
	M3.text(c, Vector2(144, 126), String(BLURB.get(r, "")), 24, UI.MUTED, false, 540)
	var run := s.building(r)
	if not run.is_empty():
		M3.text(c, Vector2(32, 200), "⏱ Construction · %s" % UI.duration(s.remaining(int(run.end))), 26, UI.GOLD, true, 656)
		M3.price(b, "Chantier en cours", [])
		b.disabled = true
		return
	var cost := s.cost_of(Game, r)
	var x := 32.0
	for it in [["coin", UI.num(float(cost.credits)) if float(cost.credits) > 0.0 else "offert", Game.credits >= float(cost.credits)], ["shard", str(int(cost.shards)), Game.shards >= int(cost.shards)], ["", "⏱ " + UI.duration(float(cost.time)), true]]:
		var w := M3.text_w(String(it[1]), 24, true) + (64.0 if it[0] != "" else 32.0)
		c.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 30, 0), Rect2(x, 180, w, 60))
		if it[0] != "":
			c.draw_texture(UI.icon(String(it[0]), 28), Vector2(x + 14, 196))
		M3.text(c, Vector2(x + (52.0 if it[0] != "" else 16.0), 220), String(it[1]), 24, UI.TEXT if it[2] else UI.RED, true)
		x += w + 12.0
	var block := s.upgrade_block(Game, r)
	b.disabled = block != ""
	if block == "" or block == "Pas assez de ressources":
		M3.price(b, "Construire", RoomScreen.price_items(cost))
	else:
		M3.price(b, block, [])


func _build_selected() -> void:
	if _sel == "" or not Game.ship.is_buildable(_sel):
		return
	if Game.ship.start_upgrade(Game, _sel):
		Sfx.play("coin")
		Game.save_game()
		Game.changed.emit()
		_sheet.queue_redraw()


func _launch_advice() -> void:
	if _adv.is_empty():
		return
	if Game.ship.start_upgrade(Game, String(_adv.room)):
		Sfx.play("coin")
		Game.save_game()
		Game.changed.emit()


func _n(v: float, res: String) -> String:
	return UI.num(v) if res == "credits" else str(int(v))


## Ce que fait la salle en une ligne.
static func room_line(r: String) -> String:
	var s: ShipState = Game.ship
	var lv := s.room_level(r)
	if lv <= 0:
		return "S’ouvre au niveau %d du vaisseau" % int(Ship.ROOMS[r].unlock)
	match r:
		"pont":
			return "Niveau du vaisseau · +%d %% de production partout" % int(round(Ship.PONT_BONUS * s.level * 100.0))
		"centrale":
			return "Autonomie %d h (production et gains hors ligne)" % int(round(s.autonomy_hours()))
		"raffinerie", "atelier", "antenne", "serre":
			var rate := s.rate(r, Game.best_stage)
			var res := String(Ship.ROOMS[r].res)
			if res == "credits":
				return "%s crédits / h, même jeu fermé" % UI.num(rate)
			if rate >= 1.0:
				return "%s %s / h" % [str(snappedf(rate, 0.1)), Ship.RES_NAMES[res]]
			return "1 %s toutes les %s" % [Ship.RES_NAMES[res].trim_suffix("s").replace("jetons", "jeton"), UI.duration(3600.0 / maxf(0.001, rate))]
		"labo":
			if not s.research_job.is_empty():
				return "Recherche %s · %s" % [Ship.RESEARCH[s.research_job.id].name, UI.duration(s.remaining(int(s.research_job.end)))]
			return "Recherches permanentes · rang max %d" % mini(Ship.RESEARCH_MAX, lv)
		"quartiers":
			return "+1 niveau toutes les %s · %d lit%s" % [UI.duration(Ship.train_hours(lv) * 3600.0), Ship.beds(lv), "s" if Ship.beds(lv) > 1 else ""]
		"hangar":
			return "%d navette%s · expéditions" % [s.fleet().size(), "s" if s.fleet().size() > 1 else ""]
		"observatoire":
			return "Zones générées : +%d %% de butin" % int(round(Ship.observatory_bonus(lv) * (1.0 + s.workers_bonus("observatoire")) * 100.0))
	return ""


func _harvest_one() -> void:
	var got := Game.ship.collect(Game, _sel)
	if not got.is_empty():
		Sfx.play("coin")
		Wallet.fly(get_tree(), _sheet_btns[0].global_position + _sheet_btns[0].size * 0.5, String(got.res))
		Game.changed.emit()


func _harvest_all() -> void:
	var got := Game.ship.collect_all(Game)
	if not got.is_empty():
		Sfx.play("coin")
		for res in got:
			Wallet.fly(get_tree(), _harvest.global_position + _harvest.size * 0.5, String(res))
		Game.changed.emit()
