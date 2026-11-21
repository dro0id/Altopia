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
var _builds: Button
var _todo: Button
var _ticker: Control
var _bubbles := {}
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
	view.position = Vector2(0, 300)
	view.size = Vector2(720, _row_y() - 8.0 - 300.0)
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
	# grade du Capitaine (maquette WN) : le titre s'affiche sous l'Aurore, on le touche pour la doctrine
	var cap := Button.new()
	cap.flat = true
	cap.position = Vector2(24, 60)
	cap.size = Vector2(360, 44)
	UI.no_focus(cap)
	cap.pressed.connect(func():
		Sfx.play("click", -6.0)
		add_child(CaptainScreen.new()))
	bar.add_child(cap)
	# rangée du bas (maquette XA) : vue en coupe, chantiers, mémo à gauche ; « À faire » à droite
	_cut = _round_button("◐", Vector2(32, _row_y()))
	_cut.pressed.connect(func():
		view.set_cut(not view.cut_mode)
		_cut.text = "◐" if view.cut_mode else "●"
		_close_sheet())
	_builds = _round_button("⚒", Vector2(136, _row_y()))
	_builds.pressed.connect(func(): builds_requested.emit())
	_builds.draw.connect(func():
		var nb := Game.ship.buildable().size()
		if nb > 0:
			_badge(_builds, nb))
	# mémo de l'écran (maquette E5)
	var b3 := _round_button("?", Vector2(240, _row_y()))
	if not Help.seen("L’Aurore"):
		b3.add_theme_color_override("font_color", UI.GOLD)
	b3.pressed.connect(func():
		b3.add_theme_color_override("font_color", UI.TEXT)
		Help.show(self, "L’Aurore"))
	# succès, peintures et tenues (maquette YG)
	var b4 := _round_button("★", Vector2(344, _row_y()))
	b4.pressed.connect(func(): add_child(CosmeticsScreen.new()))
	# « À faire » (maquettes XA et XB) : tout ce qui attend ; pastille rouge = ce qui se réclame
	_todo = M3.button(_st, "À faire", Rect2(448, _row_y(), 240, 88), "gold", 28)
	_todo.pressed.connect(func(): todo_requested.emit())
	_todo.draw.connect(func():
		var n := TodoScreen.claim_count()
		if n > 0:
			_badge(_todo, n))
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
	# fil du bord (maquette XA)
	_ticker = Control.new()
	_ticker.position = Vector2(24, 248)
	_ticker.size = Vector2(672, 44)
	_ticker.clip_contents = true
	_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticker.draw.connect(_draw_ticker)
	_st.add_child(_ticker)
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


## Haut de la rangée de boutons au-dessus de « Tout récolter ».
static func _row_y() -> float:
	return UI.H - NavBar.total() - 32.0 - 96.0 - 16.0 - 88.0


## Pastille rouge chiffrée au coin d'un bouton.
static func _badge(b: Control, n: int) -> void:
	var c := Vector2(b.size.x - 12.0, 12.0)
	b.draw_circle(c, 18, UI.BAR)
	b.draw_circle(c, 15, UI.RED)
	b.draw_string(UI.bold_font(), c + Vector2(-16, 8), str(mini(n, 9)), HORIZONTAL_ALIGNMENT_CENTER, 32, 20, Color.WHITE)


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
	if view.level != s.level or view.opened != s.rooms.duplicate() or view.paint != Game.paint:
		view.setup(s.level, s.posts, s.rooms)
	# titres gagnés : Amiral de l'Aurore (niveau 20), sinon Héros de la Ceinture (fin de l'histoire)
	var gr: int = Game.captain_grade()
	_sub.text = "%s · grade %d · niv. %d%s" % [Captain.title(gr), gr, s.level, "  ●" if Game.captain_unspent() > 0 else "  ›"]
	_sub.add_theme_color_override("font_color", UI.GOLD if Game.captain_unspent() > 0 else UI.MUTED)
	var n := s.ready_rooms().size()
	_harvest.text = "Tout récolter · %d salle%s" % [n, "s" if n > 1 else ""] if n > 0 else "Rien à récolter pour l’instant"
	_harvest.disabled = n == 0
	var voyage := not Game.mission_open()
	_mission.size.y = 184.0 if voyage else 128.0
	_join.text = "Y aller" if voyage else "Rejoindre"
	# la plaque de verre déborde (lueur) : en voyage, plus petite et plus haute pour libérer la frise
	_join.position.y = 26.0 if voyage else 24.0
	_join.size.y = 72.0 if voyage else 80.0
	var od := Game.voyage_done()
	_join.visible = not voyage or (od < Story.OBJECTIVES.size() and String(Story.OBJECTIVES[od].go) != "signal")
	var todo_n := TodoScreen.entries().size()
	M3.price(_todo, "À faire · %d" % todo_n if todo_n > 0 else "À faire", [])
	_builds.queue_redraw()
	_ticker.position.y = _mission.position.y + _mission.size.y + 8.0
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
const CREW_LINES := ["Cap tenu.", "Rien à signaler, Capitaine.", "Le verre chante, ce soir.", "Café froid, moteurs chauds.", "Les réserves se remplissent.", "Altopia est encore loin. On y sera."]


## Étiquettes de part et d'autre de la coque (maquette XA) : à gauche les salles de gauche, à droite celles
## de droite, reliées à leur salle par un trait ; elles s'écartent verticalement au lieu de se recouvrir.
func _side_layout() -> Array:
	var sides := {-1: [], 1: []}
	for r in view.anchors.keys():
		var lp := view.label_pos(r)
		if lp.is_empty() or not lp.visible:
			continue
		var a: Vector2 = lp.pos
		sides[-1 if a.x < 360.0 else 1].append({"r": r, "a": a, "y": a.y, "side": -1 if a.x < 360.0 else 1})
	var out := []
	for sd in sides:
		var lst: Array = sides[sd]
		lst.sort_custom(func(p, q): return p.y < q.y)
		for i in lst.size():
			if i > 0:
				lst[i].y = maxf(float(lst[i].y), float(lst[i - 1].y) + 76.0)
			lst[i].y = clampf(float(lst[i].y), 40.0, _labels.size.y - 50.0)
		out += lst
	return out


func _status(r: String) -> Array:
	var s: ShipState = Game.ship
	var lv := s.room_level(r)
	var b := s.building(r)
	if not b.is_empty():
		return ["⏱ " + UI.duration(s.remaining(int(b.end))), UI.GOLD]
	if lv <= 0:
		return ["Construire", UI.GREEN] if s.is_buildable(r) else ["niv. %d" % int(Ship.ROOMS[r].unlock), UI.MUTED]
	if String(Ship.ROOMS[r].res) != "":
		var cap := s.capacity(r, Game.best_stage)
		var v := float(s.stock.get(r, 0.0))
		if v >= cap - 0.01:
			return ["pleine" if not OfflineScreen._masc(String(Ship.ROOMS[r].short)) else "plein", UI.GOLD]
		return ["%d %%" % int(v / maxf(0.001, cap) * 100.0), UI.GREEN]
	return ["", UI.MUTED]


func _draw_labels() -> void:
	var c := _labels
	_lab_rects = {}
	_bubbles = {}
	var s: ShipState = Game.ship
	var items := _side_layout()
	var top_anchor := Vector2(-1, -1)
	for it in items:
		var r: String = it.r
		var a: Vector2 = it.a
		if top_anchor.x < 0.0 or a.y < top_anchor.y:
			top_anchor = a
		var col: Color = Ship.ROOMS[r].color
		var lv := s.room_level(r)
		var sealed := lv <= 0 and not s.is_buildable(r)
		var name := String(Ship.ROOMS[r].short)
		var lvtxt := "" if lv <= 0 else str(lv)
		var w := 44.0 + M3.text_w(name, 22, true) + (M3.text_w(lvtxt, 22, true) + 10.0 if lvtxt != "" else 0.0) + (26.0 if sealed else 0.0)
		var y: float = it.y
		var left: bool = int(it.side) < 0
		var rect := Rect2(12.0 if left else 708.0 - w, y - 22.0, w, 44.0)
		# trait vers la salle
		var from := Vector2(rect.end.x if left else rect.position.x, y)
		c.draw_line(from, a, Color(col, 0.0 if sealed else 0.55), 2.0, true)
		c.draw_circle(a, 4.0, Color(col, 0.0 if sealed else 0.9))
		var sb := UI.box(Color(0.04, 0.07, 0.15, 0.88), col if not sealed else UI.MUTED, 10, 0)
		if s.is_buildable(r) and s.building(r).is_empty():
			sb.border_color = Color(col, 0.55 + 0.45 * absf(sin(_t * 3.0)))
		sb.set_border_width_all(2)
		c.draw_style_box(sb, rect)
		var dc := rect.position + Vector2(20, 22)
		c.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -8), dc + Vector2(8, 0), dc + Vector2(0, 8), dc + Vector2(-8, 0)]), col if not sealed else UI.MUTED)
		var x := rect.position.x + 36.0
		if sealed:
			M3.lock(c, Vector2(x + 8, rect.position.y + 22), UI.MUTED, 0.8)
			x += 26.0
		M3.text(c, Vector2(x, rect.position.y + 30), name, 22, UI.TEXT if not sealed else UI.MUTED, true)
		x += M3.text_w(name, 22, true) + 10.0
		if lvtxt != "":
			M3.text(c, Vector2(x, rect.position.y + 30), lvtxt, 22, col, true)
		var st := _status(r)
		if String(st[0]) != "":
			M3.text(c, Vector2(rect.position.x + (0.0 if left else 0.0), rect.end.y + 22.0), String(st[0]), 20, st[1], true, w, HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT)
		# événement à bord (maquette WK) : un « ! » doré au coin de l'étiquette
		if not Game.board.at_room(r).is_empty():
			var ec := Vector2(rect.position.x + 2.0 if left else rect.end.x - 2.0, rect.position.y + 2.0)
			var pulse := 1.0 + 0.12 * sin(_t * 5.0)
			c.draw_circle(ec, 21.0 * pulse, Color(UI.GOLD, 0.25))
			c.draw_circle(ec, 17.0, UI.GOLD)
			M3.text(c, ec + Vector2(-17, 9), "!", 24, Color("06101f"), true, 34, HORIZONTAL_ALIGNMENT_CENTER)
		_lab_rects[r] = Rect2(rect.position + c.position, rect.size + Vector2(0, 28)).grow(6)
		# bulle de récolte sur la salle (toucher : récolter)
		var ready := floorf(float(s.stock.get(r, 0.0)))
		if ready >= 1.0 and lv > 0:
			var txt := "+" + (UI.num(ready) if String(Ship.ROOMS[r].res) == "credits" else str(int(ready)))
			var bw := M3.text_w(txt, 22, true) + 28.0
			var bc := a + Vector2(-float(it.side) * (bw * 0.5 + 10.0), -4.0 + sin(_t * 2.0 + a.y) * 3.0)
			var br := Rect2(bc - Vector2(bw * 0.5, 20), Vector2(bw, 40))
			c.draw_style_box(UI.box(col.lightened(0.15), Color(0, 0, 0, 0), 20, 0), br)
			M3.text(c, br.position + Vector2(0, 28), txt, 22, Color("06101f"), true, bw, HORIZONTAL_ALIGNMENT_CENTER)
			_bubbles[r] = Rect2(br.position + c.position, br.size).grow(8)
	# bulle d'équipage au-dessus du vaisseau
	if top_anchor.x >= 0.0:
		var who := "vance" if s.post_of("vance") != "" else ""
		if who == "":
			for rr in s.posts:
				if not (s.posts[rr] as Array).is_empty():
					who = String(s.posts[rr][0])
					break
		if who != "":
			var k := int(_t / 9.0)
			var line := "%s : « %s »" % [String(Data.HEROES[who].name).split(" ")[0], CREW_LINES[k % CREW_LINES.size()]]
			var ph := fmod(_t, 9.0)
			var alpha := clampf(minf(ph / 0.4, (9.0 - ph) / 0.4), 0.0, 1.0)
			var lw := M3.text_w(line, 20, true) + 32.0
			var qr := Rect2(clampf(top_anchor.x - lw * 0.5, 12.0, 708.0 - lw), maxf(4.0, top_anchor.y - 92.0), lw, 40)
			c.draw_style_box(UI.box(Color(0.92, 0.95, 1.0, 0.92 * alpha), Color(0, 0, 0, 0), 20, 0), qr)
			M3.text(c, qr.position + Vector2(0, 27), line, 20, Color(0.04, 0.07, 0.15, alpha), true, lw, HORIZONTAL_ALIGNMENT_CENTER)


## Fil du bord (maquette XA) : ce qui arrive bientôt, en une ligne qui défile.
func _ticker_text() -> String:
	var s: ShipState = Game.ship
	var parts := []
	if Boarding.available(Game):
		parts.append("⚠ Abordage : un essaim approche (« À faire »)")
	var best := ""
	var bt := 1.0e12
	for r in s.producers():
		var cap := s.capacity(r, Game.best_stage)
		var v := float(s.stock.get(r, 0.0))
		var rate := s.rate(r, Game.best_stage)
		if v < cap and rate > 0.0:
			var left := (cap - v) / rate * 3600.0
			if left < bt:
				bt = left
				best = String(r)
	if best != "":
		var nm := String(Ship.ROOMS[best].short)
		parts.append("%s %s dans %s" % [nm, "plein" if OfflineScreen._masc(nm) else "pleine", UI.duration(bt)])
	for b in s.builds:
		parts.append("%s niv. %d dans %s" % [Ship.ROOMS[b.room].short, int(b.to), UI.duration(s.remaining(int(b.end)))])
	if not s.research_job.is_empty():
		parts.append("Labo : %s dans %s" % [Ship.RESEARCH[s.research_job.id].name, UI.duration(s.remaining(int(s.research_job.end)))])
	for sh in s.shuttles:
		var d: Dictionary = s.shuttles[sh]
		if not d.is_empty() and not bool(d.get("back", false)):
			parts.append("%s de retour dans %s" % [Ship.SHUTTLES[sh].name, UI.duration(s.remaining(int(d.end)))])
	if not Game.board.pending.is_empty():
		parts.append("%d événement%s à bord" % [Game.board.pending.size(), "s" if Game.board.pending.size() > 1 else ""])
	return "   ·   ".join(parts) if not parts.is_empty() else "Tout est calme à bord."


func _draw_ticker() -> void:
	var c := _ticker
	c.draw_style_box(UI.box(Color(0.06, 0.1, 0.2, 0.85), Color(0, 0, 0, 0), 12, 0), Rect2(Vector2.ZERO, c.size))
	var txt := _ticker_text()
	var tw := M3.text_w(txt, 22, false)
	var room := c.size.x - 180.0
	var off := 0.0
	if tw > room:
		off = fmod(_t * 40.0, tw + 80.0)
	# le texte défile sous le titre « FIL DU BORD », coupé à gauche
	for k in 2:
		var x := 172.0 - off + k * (tw + 80.0)
		if x < c.size.x and x + tw > 160.0:
			M3.text(c, Vector2(x, 30), txt, 22, UI.TEXT)
		if tw <= room:
			break
	c.draw_rect(Rect2(0, 0, 166, c.size.y), Color(0.06, 0.1, 0.2, 1.0))
	M3.text(c, Vector2(16, 30), "FIL DU BORD", 20, UI.ACCENT, true)


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or not M3.is_tap(ev):
		return
	# coordonnées de la scène (sous l'encoche), comme les rectangles des étiquettes
	var p: Vector2 = _st.get_global_transform_with_canvas().affine_inverse() * ev.position
	if _sheet.visible and Rect2(_sheet.position, _sheet.size).has_point(p):
		return
	for r in _bubbles:
		if (_bubbles[r] as Rect2).has_point(p):
			var got := Game.ship.collect(Game, r)
			if not got.is_empty():
				Sfx.play("coin")
				Wallet.fly(get_tree(), _st.get_global_transform_with_canvas() * (_bubbles[r] as Rect2).get_center(), String(got.res))
				Game.changed.emit()
			get_viewport().set_input_as_handled()
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
