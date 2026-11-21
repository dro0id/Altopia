class_name DiveScreen
extends Overlay
## La Plongée (maquette WL) : la carte à embranchements, les reliques, l'escouade et ses blessures.

const ROW_H := 116.0
const COLS := {0: 150.0, 1: 360.0, 2: 570.0}
const MAP_TOP := 70.0

var _st: Control
var _scroll: ScrollContainer
var _map: Control
var _head: Control
var _foot: Control
var _pop: Control
var _pop_btns: Array = []
var _t := 0.0
var _report := {}
var _press := Vector2.ZERO
var _figs: Array = []


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	set_backdrop(Color("8468d0"))
	M3.top_bar(_st, "La Plongée", close)
	_head = Control.new()
	_head.position = Vector2(0, 108)
	_head.size = Vector2(720, 96)
	_head.draw.connect(_draw_head)
	_st.add_child(_head)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 204)
	_scroll.size = Vector2(720, UI.H - 204 - 200)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_st.add_child(_scroll)
	DragScroll.attach(_scroll)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(720, MAP_TOP * 2 + (Dive.DEPTHS - 1) * ROW_H)
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_map_input)
	_scroll.add_child(_map)
	_foot = Control.new()
	_foot.position = Vector2(0, UI.H - 196)
	_foot.size = Vector2(720, 196)
	_foot.draw.connect(_draw_foot)
	_st.add_child(_foot)
	_pop = Control.new()
	_pop.size = Vector2(720, UI.H)
	_pop.visible = false
	_pop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pop.draw.connect(_draw_pop)
	_st.add_child(_pop)
	_follow.call_deferred()


func _dive() -> Dive:
	return Game.current_dive()


func _process(delta: float) -> void:
	_t += delta
	_map.queue_redraw()
	_head.queue_redraw()
	_foot.queue_redraw()
	if _pop.visible:
		_pop.queue_redraw()


## Fait défiler la carte jusqu'à la profondeur en cours.
func _follow() -> void:
	var y := MAP_TOP + maxf(0.0, float(_dive().depth) - 1.0) * ROW_H - 80.0
	_scroll.scroll_vertical = int(maxf(0.0, y))


func _npos(d: int, c: int) -> Vector2:
	return Vector2(float(COLS.get(c, 360.0)), MAP_TOP + d * ROW_H)


func _draw_head() -> void:
	var c := _head
	var dv := _dive()
	M3.glass_card(c, Rect2(24, 8, 672, 80), false, 20.0)
	M3.text(c, Vector2(48, 58), ("Descente terminée" if dv.done else "Profondeur %d / %d" % [dv.depth, Dive.DEPTHS]), 28, UI.GOLD if dv.done else UI.TEXT, true)
	var x := 672.0 - 24.0
	M3.text(c, Vector2(0, 58), "%d relique%s" % [dv.relics.size(), "s" if dv.relics.size() > 1 else ""], 22, UI.MUTED, true, 672 - 8, HORIZONTAL_ALIGNMENT_RIGHT)
	x = 672.0 - M3.text_w("%d reliques" % dv.relics.size(), 22, true) - 40.0
	for i in range(dv.relics.size() - 1, -1, -1):
		var col: Color = Dive.RELICS[dv.relics[i]].col
		_relic_hex(c, Vector2(x, 48), 20.0, col)
		x -= 50.0
		if x < 360.0:
			break


static func _relic_hex(c: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 6:
		var a := k * PI / 3.0
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, col)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r * 0.45), at + Vector2(r * 0.4, 0), at + Vector2(0, r * 0.45), at + Vector2(-r * 0.4, 0)]), Color(0.05, 0.07, 0.14, 0.85))


func _hex(at: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		var a := -PI / 2.0 + k * PI / 3.0
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_map() -> void:
	var c := _map
	var dv := _dive()
	var nexts := dv.next_cols()
	# liens
	for d in dv.rows.size() - 1:
		for nd in dv.rows[d]:
			var a := _npos(d, int(nd.col))
			for l in nd.links:
				var b := _npos(d + 1, int(l))
				var walked: bool = d + 1 < dv.path.size() and int(dv.path[d]) == int(nd.col) and int(dv.path[d + 1]) == int(l)
				var open: bool = d == dv.depth - 1 and int(nd.col) == dv.pos and nexts.has(int(l))
				if walked:
					c.draw_line(a, b, UI.GREEN, 6.0, true)
				elif open:
					var n := 10
					for i in n:
						if i % 2 == 0:
							c.draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), UI.ACCENT, 5.0, true)
				else:
					c.draw_line(a, b, Color(M3.OUT, 0.8), 3.0, true)
	# nœuds
	for d in dv.rows.size():
		for nd in dv.rows[d]:
			var col := int(nd.col)
			var at := _npos(d, col)
			var kind := String(nd.kind)
			var boss := kind == "boss"
			var r := 46.0 if boss else 36.0
			var passed: bool = d < dv.path.size() and int(dv.path[d]) == col
			var current: bool = passed and d == dv.depth - 1
			var reach: bool = d == dv.depth and nexts.has(col)
			if current:
				var k := 0.5 + 0.5 * sin(_t * 3.0)
				c.draw_circle(at, r + 16.0, Color(UI.GOLD, 0.12 + 0.1 * k))
				c.draw_arc(at, r + 14.0, 0, TAU, 40, Color(UI.GOLD, 0.8), 4.0, true)
			var fill := Color("3a1620") if boss else (Color("123a2a") if passed else Color("16203c"))
			var edge := UI.GREEN if passed else (UI.ACCENT if reach else Color(M3.OUT, 1.0))
			if current:
				edge = UI.GOLD
			if not passed and not reach:
				fill = fill.darkened(0.25)
			var pts := _hex(at, r)
			c.draw_colored_polygon(pts, fill)
			var cl := pts.duplicate()
			cl.append(pts[0])
			c.draw_polyline(cl, Color(edge, 0.6 + 0.4 * sin(_t * 4.0)) if reach else edge, 4.0, true)
			var ink := Color("ff6b6b") if boss else (UI.TEXT if (passed or reach) else UI.MUTED)
			_glyph(c, kind, at, ink, r)


func _glyph(c: Control, kind: String, at: Vector2, col: Color, r: float) -> void:
	match kind:
		"repos":
			c.draw_rect(Rect2(at + Vector2(-5, -15), Vector2(10, 30)), col)
			c.draw_rect(Rect2(at + Vector2(-15, -5), Vector2(30, 10)), col)
		"cache":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -15), at + Vector2(13, 0), at + Vector2(0, 15), at + Vector2(-13, 0)]), col)
		"elite":
			Art.star(c, at, 16.0, col, 0.0)
		_:
			var g := String(Dive.KINDS[kind].glyph)
			M3.text(c, at + Vector2(-r, M3.fs(30 if kind != "boss" else 36) * 0.36), g, 30 if kind != "boss" else 36, col, true, r * 2.0, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_foot() -> void:
	var c := _foot
	var dv := _dive()
	M3.glass_card(c, Rect2(24, 8, 672, 172), false, 20.0)
	var ids := dv.team_ids(Game)
	for i in Data.SQUAD_SIZE:
		var x := 96.0 + i * 132.0
		if i >= ids.size():
			c.draw_circle(Vector2(x, 70), 38, M3.S3)
			continue
		var id := String(ids[i])
		var h: Dictionary = Data.HEROES[id]
		var f := dv.hp_of(id)
		M3.avatar(c, h, Vector2(x, 70), 38.0, UI.GREEN if f > 0.5 else (UI.GOLD if f > 0.25 else UI.RED), _t)
		M3.bar(c, Rect2(x - 52, 122, 104, 10), f, UI.GREEN if f > 0.5 else (UI.GOLD if f > 0.25 else UI.RED))
		if not Game.squad_ids().has(id):
			M3.text(c, Vector2(x - 60, 160), "remplaçant", 16, UI.MUTED, false, 120, HORIZONTAL_ALIGNMENT_CENTER)
	if not dv.fallen.is_empty():
		M3.text(c, Vector2(48, 30), "%d à terre" % dv.fallen.size(), 18, UI.RED, true)


func _map_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_press = ev.position
		return
	if not M3.is_release(ev) or ev.position.distance_to(_press) > 14.0 or _pop.visible:
		return
	var dv := _dive()
	if dv.stuck(Game):
		M3.toast(self, "Plus personne pour descendre cette semaine", UI.RED)
		return
	for col in dv.next_cols():
		if _npos(dv.depth, int(col)).distance_to(ev.position) < 50.0:
			if dv.is_fight(int(col)) and Game.dive_fight.get_connections().size() > 0:
				# le combat se joue à l'écran de combat ; la descente reprend ensuite
				Sfx.play("warn", -6.0)
				close()
				Game.dive_fight.emit(int(col))
				return
			var rep := dv.enter(Game, int(col), int(Time.get_ticks_msec()))
			if rep.is_empty():
				return
			Sfx.play("coin" if rep.ok else "warn", -4.0)
			Game.save_game()
			Game.changed.emit()
			_show(rep)
			return


func show_report(rep: Dictionary) -> void:
	_show(rep)


func _show(rep: Dictionary) -> void:
	_report = rep
	for b in _pop_btns:
		b.queue_free()
	_pop_btns = []
	_pop.visible = true
	var dv := _dive()
	var box := _box()
	if not dv.offer.is_empty():
		for i in dv.offer.size():
			var id := String(dv.offer[i])
			var b := M3.button(_pop, "", Rect2(box.position.x + 32, box.position.y + 232 + i * 104, box.size.x - 64, 92), "secondary", 24)
			M3.price(b, "%s · %s" % [Dive.RELICS[id].name, Dive.RELICS[id].desc], [])
			var rid := id
			b.pressed.connect(func():
				dv.take_relic(rid)
				Sfx.play("star", -4.0)
				Game.save_game()
				_pop.visible = false)
			_pop_btns.append(b)
	else:
		var ok := M3.button(_pop, "Continuer", Rect2(box.position.x + 32, box.end.y - 128, box.size.x - 64, 96), "main", 28)
		ok.pressed.connect(func():
			_pop.visible = false
			_follow())
		_pop_btns.append(ok)


func _box() -> Rect2:
	var h := 580.0 if not _dive().offer.is_empty() else 420.0
	return Rect2(40, UI.H * 0.5 - h * 0.5, 640, h)


func _draw_pop() -> void:
	var c := _pop
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.6))
	var r := _box()
	M3.dialog(c, r)
	var kind := String(_report.get("kind", "combat"))
	M3.text(c, Vector2(r.position.x, r.position.y + 64), String(Dive.KINDS[kind].name), 34, UI.TEXT if _report.get("ok", true) else UI.RED, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(r.position.x + 32, r.position.y + 110), String(_report.get("text", "")), 22, UI.MUTED, false, r.size.x - 64, HORIZONTAL_ALIGNMENT_CENTER)
	var rw: Dictionary = _report.get("rw", {})
	var parts := []
	for k in rw:
		if float(rw[k]) > 0.0:
			parts.append(_rw_text(String(k), float(rw[k])))
	if not parts.is_empty() and _report.get("ok", true):
		M3.text(c, Vector2(r.position.x, r.position.y + 160), " · ".join(parts), 24, UI.GOLD, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if not _dive().offer.is_empty():
		M3.text(c, Vector2(r.position.x, r.position.y + 210), "Choisis une relique pour la descente", 22, UI.ACCENT, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	elif _dive().done:
		M3.text(c, Vector2(r.position.x, r.position.y + 220), "Le fond est atteint. Nouvelle descente lundi.", 22, UI.GREEN, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


static func _rw_text(k: String, v: float) -> String:
	match k:
		"credits":
			return "+%s crédits" % UI.num(v)
		"shards":
			return "+%d éclats" % int(v)
		"crystals":
			return "+%d ◆" % int(v)
		"tokens":
			return "+%d jeton" % int(v)
		"item_tokens":
			return "+%d jeton d’objet" % int(v)
	return ""
