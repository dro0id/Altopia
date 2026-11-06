class_name ShipScreen
extends Overlay
## Onglet Vaisseau (maquettes KB, JE, PA) : l'Aurore en coupe 3D, étiquettes des salles, fiche d'une salle touchée,
## « Tout récolter ». Les écrans de salle, d'amélioration et du Hangar s'ouvrent par-dessus (signal room_requested).

signal room_requested(room: String)
signal builds_requested


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
var _chips: Array = []
var _sub: Label
var _lab_rects := {}


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.draw.connect(_draw_bg)
	_st.add_child(_bg)
	view = ShipView.new()
	view.position = Vector2(0, 112)
	view.size = Vector2(720, 1280 - 112 - NavBar.total())
	_st.add_child(view)
	view.setup(Game.ship.level, Game.ship.posts)
	view.room_tapped.connect(_select)
	_labels = Control.new()
	_labels.position = view.position
	_labels.size = view.size
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.draw.connect(_draw_labels)
	_st.add_child(_labels)
	var cr := M3.cur_chip("coin", UI.num(Game.credits))
	var sh := M3.cur_chip("shard", str(Game.shards))
	_chips = [cr, sh]
	var bar := M3.top_bar(_st, "L’Aurore", Callable(), [cr, sh])
	var title: Label = bar.get_node("Title")
	title.position.y = 18
	_sub = UI.label(bar, "", M3.fs(22), UI.MUTED)
	_sub.position = Vector2(32, 66)
	_sub.size = Vector2(340, 32)
	_sub.clip_text = true
	_cut = _round_button("◐", Vector2(720 - 32 - 88, 136))
	_cut.pressed.connect(func():
		view.set_cut(not view.cut_mode)
		_cut.text = "◐" if view.cut_mode else "●"
		_close_sheet())
	var b2 := _round_button("🛠", Vector2(720 - 32 - 88, 240))
	b2.text = "⚒"
	b2.pressed.connect(func(): builds_requested.emit())
	_harvest = M3.button(_st, "Tout récolter", Rect2(32, 1280 - NavBar.total() - 32 - 96, 656, 96), "main", 30)
	_harvest.pressed.connect(_harvest_all)
	_sheet = Control.new()
	_sheet.size = Vector2(720, 420)
	_sheet.position = Vector2(0, 1280 - NavBar.total() - 420)
	_sheet.visible = false
	_sheet.draw.connect(_draw_sheet)
	_sheet.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev):
			accept_event())
	_st.add_child(_sheet)
	var b_open := M3.button(_sheet, "Ouvrir la salle", Rect2(368, 300, 320, 96), "tonal", 28)
	b_open.pressed.connect(func(): room_requested.emit(_sel))
	var b_col := M3.button(_sheet, "Récolter", Rect2(32, 300, 320, 96), "main", 28)
	b_col.pressed.connect(_harvest_one)
	_sheet_btns = [b_col, b_open]
	_labels.gui_input.connect(func(_e): pass)
	move_child(_st, get_child_count() - 1)
	Game.changed.connect(_refresh)
	_refresh()


func _round_button(glyph: String, p: Vector2) -> Button:
	var b := M3.icon_button(_st, glyph, 34)
	b.size = Vector2(88, 88)
	b.custom_minimum_size = Vector2(88, 88)
	b.position = p
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, UI.box(Color(M3.S3, 0.85), Color(0, 0, 0, 0), 44, 0))
	return b


func _exit_tree() -> void:
	if Game.changed.is_connected(_refresh):
		Game.changed.disconnect(_refresh)


func _refresh() -> void:
	var s: ShipState = Game.ship
	if view.level != s.level:
		view.setup(s.level, s.posts)
	var ti := Ship.tier_info(s.level)
	_sub.text = ("Niveau %d · Amiral de l’Aurore" % s.level) if Game.tips.has("prestige") else ("Niveau %d · %s" % [s.level, ti.name])
	(_chips[0] as HudButton).set_texts(UI.num(Game.credits))
	(_chips[1] as HudButton).set_texts(str(Game.shards))
	var n := s.ready_rooms().size()
	_harvest.text = "Tout récolter · %d salle%s" % [n, "s" if n > 1 else ""] if n > 0 else "Rien à récolter pour l’instant"
	_harvest.disabled = n == 0
	_sheet.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_labels.queue_redraw()
	if _sheet.visible:
		_sheet.queue_redraw()
	if fmod(_t, 1.0) < delta:
		_refresh()


func _draw_bg() -> void:
	var c := _bg
	c.draw_rect(Rect2(0, 0, 720, 1280), Color("070b1a"))
	for k in 18:
		c.draw_circle(Vector2(110, 1060), 520.0 - k * 28.0, Color(0.7, 0.53, 1.0, 0.012))
	for k in 14:
		c.draw_circle(Vector2(360, 520), 420.0 - k * 28.0, Color(0.1, 0.17, 0.35, 0.03))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 110:
		var p := Vector2(rng.randf() * 720.0, rng.randf() * 1280.0)
		var a := 0.25 + rng.randf() * 0.55 + sin(_t * 1.3 + i) * 0.1
		c.draw_circle(p, 1.2 + (2.0 if i % 9 == 0 else 0.0) * 0.6, Color(1, 1, 1, a))


## Étiquettes des salles : nom court, niveau, réserve prête (maquette KB).
func _draw_labels() -> void:
	var c := _labels
	_lab_rects = {}
	var s: ShipState = Game.ship
	for r in view.anchors:
		var lp := view.label_pos(r)
		if lp.is_empty() or not lp.visible:
			continue
		var col: Color = Ship.ROOMS[r].color
		var lv := s.room_level(r)
		var sealed := lv <= 0
		var name := String(Ship.ROOMS[r].short)
		var txt := name
		var w := M3.text_w(txt, 22, true) + 32.0 + (30.0 if sealed else 0.0)
		var lvtxt := "" if sealed else str(lv)
		w += M3.text_w(lvtxt, 22, true) + (10.0 if lvtxt != "" else 0.0)
		var ready := floorf(float(s.stock.get(r, 0.0)))
		var rtxt := ""
		if ready >= 1.0:
			rtxt = "+" + (UI.num(ready) if String(Ship.ROOMS[r].res) == "credits" else str(int(ready)))
			w += M3.text_w(rtxt, 20, true) + 28.0
		var p: Vector2 = lp.pos
		var rect := Rect2(p.x, p.y - 22.0, w, 44.0)
		rect.position.x = clampf(rect.position.x, 8.0, 712.0 - w)
		var sb := UI.box(Color(0.04, 0.07, 0.15, 0.85), col if not sealed else UI.MUTED, 22, 0)
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
			var rr := Rect2(x, rect.position.y + 6, M3.text_w(rtxt, 20, true) + 20.0, 32)
			c.draw_style_box(UI.box(col, Color(0, 0, 0, 0), 16, 0), rr)
			M3.text(c, Vector2(rr.position.x + 10, rr.position.y + 23), rtxt, 20, Color("06101f"), true)
		_lab_rects[r] = Rect2(rect.position + c.position, rect.size)


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or not M3.is_tap(ev):
		return
	var p: Vector2 = ev.position
	if _sheet.visible and Rect2(_sheet.position, _sheet.size).has_point(p):
		return
	for r in _lab_rects:
		if (_lab_rects[r] as Rect2).has_point(p):
			_select(r)
			get_viewport().set_input_as_handled()
			return


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
	var sb := UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	c.draw_style_box(sb, Rect2(0, 0, 720, 460))
	c.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, 16, 64, 8))
	var lv := s.room_level(r)
	c.draw_style_box(UI.box(Color("0a1424"), col, 24, 0), Rect2(32, 48, 88, 88))
	RoomScreen._room_glyph(c, r, Vector2(76, 92), col, 0.9)
	M3.text(c, Vector2(144, 88), "%s · niv. %d" % [info.name, lv] if lv > 0 else "%s · scellée" % info.name, 32, UI.TEXT, true, 540)
	M3.text(c, Vector2(144, 126), room_line(r), 24, UI.MUTED, false, 540)
	var res := String(info.res)
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
			return "Secteurs générés : +%d %% de butin" % int(round(Ship.observatory_bonus(lv) * (1.0 + s.workers_bonus("observatoire")) * 100.0))
	return ""


func _harvest_one() -> void:
	var got := Game.ship.collect(Game, _sel)
	if not got.is_empty():
		Sfx.play("coin")
		Game.changed.emit()


func _harvest_all() -> void:
	var got := Game.ship.collect_all(Game)
	if not got.is_empty():
		Sfx.play("coin")
		Game.changed.emit()
