class_name TodoScreen
extends Overlay
## « À faire » (maquette XB) : tout ce qui attend, en une feuille. Trié par valeur : ce qui se réclame,
## puis ce qui fait progresser, puis ce qui informe. Chaque ligne agit.

signal open_shop
signal open_room(r: String)
signal open_evolve(id: String)
signal open_items
signal open_orders
signal open_event(e: Dictionary)

const ROW := 108.0

var _st: Control
var _sheet: Control
var _rows: Array = []
var _btns: Array = []


## Ce qui attend : {kind, title, sub, action, rank, data} ; rank 0 = se réclame, 1 = fait progresser, 2 = informe.
static func entries() -> Array:
	var out := []
	var o: Orders = Game.orders
	o.refresh()
	if Game.free_chest_ready():
		out.append({"kind": "chest", "title": "Coffre gratuit prêt", "sub": "crédits et éclats", "action": "Ouvrir", "rank": 0, "role": "success"})
	for i in o.list.size():
		var ord: Dictionary = o.list[i]
		if o.is_done(ord) and not bool(ord.claimed):
			var t := Orders.template(String(ord.id))
			out.append({"kind": "order", "title": "Ordre du jour rempli", "sub": "%s · %s" % [t.text, Orders.reward_text(t.reward)], "action": "Réclamer", "rank": 0, "role": "success", "data": i})
	if Game.ship.unlocked:
		var ready: Array = Game.ship.ready_rooms()
		if not ready.is_empty():
			out.append({"kind": "harvest", "title": "%d salle%s à récolter" % [ready.size(), "s" if ready.size() > 1 else ""], "sub": ", ".join(ready.map(func(r): return String(Ship.ROOMS[r].short))), "action": "Récolter", "rank": 0, "role": "success"})
		for sh in Game.ship.shuttles:
			if bool(Game.ship.shuttles[sh].get("back", false)):
				out.append({"kind": "shuttle", "title": "%s est rentrée" % String(Ship.SHUTTLES[sh].name) if Ship.SHUTTLES.has(sh) else "Navette rentrée", "sub": "rapport d’expédition au Hangar", "action": "Lire", "rank": 0, "role": "main"})
	for e in Game.board.pending:
		var t := BoardEvents.template(String(e.id))
		out.append({"kind": "event", "title": "Événement · %s" % String(t.title), "sub": String(Ship.ROOMS[e.room].name), "action": "Voir", "rank": 1, "role": "main", "data": e})
	for id in Game.squad_ids():
		if Game.talents_open(id) > 0:
			out.append({"kind": "talent", "title": "%s : talent à choisir" % String(Data.HEROES[id].name).split(" ")[0], "sub": "un choix à chaque étoile", "action": "Choisir", "rank": 1, "role": "gold", "data": id})
		if Game.can_star_up(id):
			out.append({"kind": "star", "title": "%s peut monter en étoile" % String(Data.HEROES[id].name).split(" ")[0], "sub": "assez de doublons", "action": "Monter", "rank": 1, "role": "gold", "data": id})
	var better := 0
	for it in Game.inventory_items():
		var bh: Dictionary = Game.best_hero_for(it)
		if bh.hero != "" and float(bh.gain) > 0.0 and (it.bound == "" or it.bound == bh.hero):
			better += 1
	if better > 0:
		out.append({"kind": "items", "title": "%d objet%s meilleur%s en stock" % [better, "s" if better > 1 else "", "s" if better > 1 else ""], "sub": "pour l’escouade", "action": "Équiper", "rank": 1, "role": "main"})
	var left := 0
	for ord in o.list:
		if not o.is_done(ord):
			left += 1
	if left > 0:
		out.append({"kind": "orders", "title": "Ordres du jour en cours", "sub": "%d sur %d à remplir · solde %d / 15" % [left, o.list.size(), o.week_done], "action": "Voir", "rank": 2, "role": "secondary"})
	out.sort_custom(func(a, b): return int(a.rank) < int(b.rank))
	return out


## Nombre de choses qui se réclament (pastille rouge).
static func claim_count() -> int:
	var n := 0
	for e in entries():
		if int(e.rank) == 0:
			n += 1
	return n


func _init() -> void:
	super._init(720.0)
	z_index = 0                   # la barre du bas reste visible par-dessus
	_st = use_stage(0.7)
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.draw.connect(_draw_sheet)
	_st.add_child(_sheet)
	_st.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and ev.position.y < _sheet.position.y:
			close())
	_build()


func _build() -> void:
	for b in _btns:
		b.queue_free()
	_btns = []
	_rows = entries()
	var n := maxi(1, _rows.size())
	var bottom := UI.H - NavBar.total()
	var h := minf(bottom - 120.0, 168.0 + n * ROW + 24.0)
	_sheet.size = Vector2(720, h)
	_sheet.position = Vector2(0, bottom - h)
	var claim := _rows.filter(func(e): return e.kind in ["order", "harvest"])
	if claim.size() > 1:
		var all := M3.button(_sheet, "Tout réclamer", Rect2(420, 40, 268, 88), "success", 26)
		all.pressed.connect(_claim_all)
		_btns.append(all)
	for i in _rows.size():
		var e: Dictionary = _rows[i]
		var y := 156.0 + i * ROW
		if y + ROW > h:
			break
		var b := M3.button(_sheet, String(e.action), Rect2(492, y + 12, 196, 80), String(e.role), 26)
		var row := e
		b.pressed.connect(func(): _act(row))
		_btns.append(b)
	_sheet.queue_redraw()


func _draw_sheet() -> void:
	var c := _sheet
	M3.sheet(c, Rect2(Vector2.ZERO, c.size))
	c.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, 16, 64, 8))
	M3.text(c, Vector2(32, 98), "À faire · %d" % _rows.size() if not _rows.is_empty() else "À faire", 40, UI.TEXT, true)
	if _rows.is_empty():
		M3.text(c, Vector2(32, 190), "Rien n’attend pour l’instant. Bon vol, Capitaine.", 26, UI.MUTED)
		return
	for i in _rows.size():
		var e: Dictionary = _rows[i]
		var y := 156.0 + i * ROW
		if y + ROW > c.size.y:
			break
		M3.glass_card(c, Rect2(24, y, 672, ROW - 8), false, 16.0)
		var col := {0: UI.GREEN, 1: UI.GOLD, 2: UI.ACCENT}[int(e.rank)] as Color
		var ic := Vector2(76, y + 50)
		var hex := PackedVector2Array()
		for k in 6:
			var a := PI / 6.0 + k * PI / 3.0
			hex.append(ic + Vector2(cos(a), sin(a)) * 30.0)
		c.draw_colored_polygon(hex, Color(col, 0.22))
		_glyph(c, String(e.kind), ic, col)
		M3.text(c, Vector2(124, y + 44), String(e.title), 28, UI.TEXT, true, 356)
		M3.text(c, Vector2(124, y + 78), String(e.sub), 22, UI.MUTED, false, 356)


func _glyph(c: Control, kind: String, at: Vector2, col: Color) -> void:
	match kind:
		"chest":
			c.draw_rect(Rect2(at - Vector2(13, 10), Vector2(26, 20)), col, false, 3.0)
			c.draw_rect(Rect2(at - Vector2(6, 4), Vector2(12, 8)), col)
		"order", "orders":
			c.draw_polyline(PackedVector2Array([at + Vector2(-11, 0), at + Vector2(-3, 9), at + Vector2(12, -9)]), col, 5.0, true)
		"harvest":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -13), at + Vector2(13, -2), at + Vector2(8, 13), at + Vector2(-8, 13), at + Vector2(-13, -2)]), col)
		"shuttle":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, -12), at + Vector2(14, 0), at + Vector2(-10, 12), at + Vector2(-4, 0)]), col)
		"star", "talent":
			Art.star(c, at, 15.0, col, 0.0)
		"event":
			M3.text(c, at + Vector2(-20, 10), "!", 30, col, true, 40, HORIZONTAL_ALIGNMENT_CENTER)
		_:
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -14), at + Vector2(13, 2), at + Vector2(5, 2), at + Vector2(5, 13), at + Vector2(-5, 13), at + Vector2(-5, 2), at + Vector2(-13, 2)]), col)


func _act(e: Dictionary) -> void:
	match String(e.kind):
		"chest":
			close()
			open_shop.emit()
		"order":
			var rw := Game.orders.claim(int(e.data), Game)
			if not rw.is_empty():
				Sfx.play("coin")
				M3.toast(self, Orders.reward_text(rw), UI.GREEN)
			_after()
		"harvest":
			var got := Game.ship.collect_all(Game)
			if not got.is_empty():
				Sfx.play("coin")
			_after()
		"shuttle":
			close()
			open_room.emit("hangar")
		"star":
			close()
			open_evolve.emit(String(e.data))
		"talent":
			var ts := TalentScreen.new(String(e.data))
			ts.closed.connect(_build)
			add_child(ts)
		"items":
			var n := Game.equip_best_all()
			if n > 0:
				Sfx.play("chest", -4.0)
				M3.toast(self, "%d objet%s équipé%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""], UI.GREEN)
			_after()
		"orders":
			close()
			open_orders.emit()
		"event":
			close()
			open_event.emit(e.data)


func _claim_all() -> void:
	var o: Orders = Game.orders
	for i in o.list.size():
		o.claim(i, Game)
	Game.ship.collect_all(Game)
	Sfx.play("coin")
	_after()


func _after() -> void:
	Game.save_game()
	Game.changed.emit()
	_build()
