extends Control
## Arène du combat en direct : dessine l'état d'un LiveSim (couloirs, vaisseaux, tirs annoncés, projectiles) et lit les gestes du joueur.
## L'arène garde le rapport 360 x 520 ; tout est dessiné en coordonnées d'arène puis mis à l'échelle.

const Sim = preload("res://scripts/live_sim.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

signal lane_chosen(lane: int)

var sim: RefCounted
var running := true
var speed := 1
var _time := 0.0
var _stars: Array = []
var _font: Font
var _mono: Font
var _drag_x := -1.0

const HULL_A := Color("3fb4d8")
const HULL_B := Color("0e4560")
const WING_A := Color("2379a0")
const WING_B := Color("082a3b")
const DARK_A := Color("16435a")
const DARK_B := Color("06141d")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var r := RandomNumberGenerator.new()
	r.seed = 424242
	for i in 46:
		_stars.append([r.randf() * Sim.W, r.randf() * Sim.H, r.randf() * 1.4 + 0.4, r.randf() * 3.0])


func _ready() -> void:
	_font = UiTheme.font(true)
	_mono = UiTheme.mono()
	custom_minimum_size = Vector2(0, 300)


func attach(s: RefCounted) -> void:
	sim = s
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if sim != null and running and not sim.over:
		var dt := minf(delta, 0.05)
		for i in speed:
			sim.step(dt)
	elif sim != null and sim.over:
		sim.step(minf(delta, 0.05))         # les effets de fin s'éteignent
	queue_redraw()


# ---------- gestes ----------

func _lane_at(x: float) -> int:
	return clampi(int((x - _origin().x) / _sc() / 120.0), 0, 2)


func _gui_input(ev: InputEvent) -> void:
	if sim == null or sim.over or not running:
		return
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		if ev.pressed:
			_drag_x = ev.position.x
			sim.set_lane(_lane_at(ev.position.x))
			lane_chosen.emit(sim.lane)
		else:
			_drag_x = -1.0
	elif (ev is InputEventMouseMotion and ev.button_mask != 0) or ev is InputEventScreenDrag:
		if _drag_x >= 0.0 and absf(ev.position.x - _drag_x) > 10.0:
			sim.set_lane(_lane_at(ev.position.x))
			lane_chosen.emit(sim.lane)


# ---------- dessin ----------

func _sc() -> float:
	return minf(size.x / Sim.W, size.y / Sim.H)


func _origin() -> Vector2:
	return (size - Vector2(Sim.W, Sim.H) * _sc()) / 2.0


func _P(x: float, y: float) -> Vector2:
	return Vector2(x, y)


func _grad(pts: PackedVector2Array, a: Color, b: Color) -> PackedColorArray:
	var y0 := 1.0e9
	var y1 := -1.0e9
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(a.lerp(b, (p.y - y0) / maxf(1.0, y1 - y0)))
	return cols


func _poly(pts: PackedVector2Array, a: Color, b: Color, edge: Color, lw: float = 3.0, glow: bool = true) -> void:
	if a.a > 0.0:
		draw_polygon(pts, _grad(pts, a, b))
	var closed := pts.duplicate()
	closed.append(pts[0])
	if glow:
		draw_polyline(closed, Color(edge.r, edge.g, edge.b, 0.2), lw * 3.0, true)
	draw_polyline(closed, edge, lw, true)


func _sym(cx: float, cy: float, off: Array, a: Color, b: Color, edge: Color, lw: float = 2.5) -> void:
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	for p in off:
		l.append(Vector2(cx + p[0], cy + p[1]))
		r.append(Vector2(cx - p[0], cy + p[1]))
	_poly(l, a, b, edge, lw, false)
	_poly(r, a, b, edge, lw, false)


func _abs(cx: float, cy: float, off: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in off:
		out.append(Vector2(cx + p[0], cy + p[1]))
	return out


func _line(pts: Array, col: Color, w: float = 1.5) -> void:
	var a := PackedVector2Array()
	for p in pts:
		a.append(p)
	draw_polyline(a, col, w, true)


func _flame(x: float, y: float, length: float, col: Color, w: float = 6.0) -> void:
	var pts := PackedVector2Array([Vector2(x - w, y), Vector2(x + w, y), Vector2(x, y + length * 1.1)])
	var cols := PackedColorArray([Color(1, 0.96, 0.82, 0.95), Color(1, 0.96, 0.82, 0.95), Color(col.r, col.g, col.b, 0.0)])
	draw_polygon(pts, cols)
	var inner := PackedVector2Array([Vector2(x - w * 0.5, y), Vector2(x + w * 0.5, y), Vector2(x, y + length * 0.7)])
	draw_polygon(inner, PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.9), Color(col.r, col.g, col.b, 0.0)]))


func _nozzle(x: float, y: float, w: float) -> void:
	draw_rect(Rect2(x - w, y - 2.0, w * 2.0, 7.0), Color("0a1520"))
	draw_rect(Rect2(x - w, y - 2.0, w * 2.0, 7.0), Color("4f7384"), false, 1.5)


func _engine(x: float, y: float, length: float, w: float, col: Color) -> void:
	_nozzle(x, y, w)
	_flame(x, y + 5.0, length, col, w * 0.85)


func _cannon(x: float, y: float, length: float) -> void:
	draw_rect(Rect2(x - 3.0, y - length, 6.0, length), Color("2f566a"))
	draw_rect(Rect2(x - 3.0, y - length, 6.0, length), Sim.C_CYAN, false, 1.5)
	draw_rect(Rect2(x - 1.5, y - length - 2.0, 3.0, 3.0), Sim.C_CYAN)


func _dome(x: float, y: float, r: float) -> void:
	draw_circle(Vector2(x, y), r, Color("9fe6ff"))
	draw_circle(Vector2(x - r * 0.25, y - r * 0.3), r * 0.5, Color(1, 1, 1, 0.85))
	draw_arc(Vector2(x, y), r, 0.0, TAU, 20, Color(0.9, 0.98, 1.0, 0.8), 1.5, true)


func _navlight(x: float, y: float, col: Color) -> void:
	var a := 0.5 + 0.5 * sin(_time * 6.0 + x)
	draw_circle(Vector2(x, y), 2.0, Color(col.r, col.g, col.b, a))


func _text(s: String, pos: Vector2, size_px: int, col: Color, outline: bool = false, mono: bool = false) -> void:
	var f: Font = _mono if mono else _font
	if outline:
		draw_string_outline(f, pos - Vector2(100, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 200, size_px, 4, Color(0.02, 0.04, 0.1))
	draw_string(f, pos - Vector2(100, 0), s, HORIZONTAL_ALIGNMENT_CENTER, 200, size_px, col)


func _hatch(rect: Rect2, col: Color, spacing: float = 14.0) -> void:
	var d := -rect.size.y
	while d < rect.size.x:
		var x0 := rect.position.x + d
		var y0 := rect.position.y + rect.size.y
		var x1 := x0 + rect.size.y
		var y1 := rect.position.y
		# on coupe le segment au rectangle
		var ax := x0
		var ay := y0
		var bx := x1
		var by := y1
		if ax < rect.position.x:
			ay -= rect.position.x - ax
			ax = rect.position.x
		if bx > rect.end.x:
			by += bx - rect.end.x
			bx = rect.end.x
		if ax < bx and ay > by:
			draw_line(Vector2(ax, ay), Vector2(bx, by), col, 2.0)
		d += spacing


func _dashed_rect(rect: Rect2, col: Color, w: float = 2.0) -> void:
	var dash := 9.0
	var gap := 6.0
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var len := a.distance_to(b)
		var dir := (b - a) / maxf(len, 0.001)
		var p := 0.0
		while p < len:
			draw_line(a + dir * p, a + dir * minf(p + dash, len), col, w)
			p += dash + gap


func _draw() -> void:
	if sim == null:
		return
	var s := _sc()
	var shake_off := Vector2.ZERO
	if sim.shake > 0.0:
		shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * sim.shake * 0.4
	draw_rect(Rect2(Vector2.ZERO, size), Color("05091a"))
	draw_set_transform(_origin() + shake_off * s, 0.0, Vector2(s, s))
	_draw_arena()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var org := _origin()
	draw_rect(Rect2(org, Vector2(Sim.W, Sim.H) * s), Color(0.22, 0.9, 1.0, 0.42), false, 2.0)


func _draw_arena() -> void:
	var t: float = sim.t
	# fond
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(Sim.W, 0), Vector2(Sim.W, Sim.H), Vector2(0, Sim.H)]),
		PackedColorArray([Color("2a1f6e"), Color("1a1650"), Color("05091a"), Color("070d26")]))
	for st in _stars:
		var a := 0.35 + 0.35 * sin(t * 1.5 + st[3])
		var yy := fmod(st[1] + t * (8.0 + st[2] * 6.0), Sim.H)
		draw_rect(Rect2(st[0], yy, st[2], st[2]), Color(0.81, 0.91, 0.94, a))
	# couloirs
	for i in 3:
		var r := Rect2(6.0 + i * 120.0, 6.0, 108.0, Sim.H - 12.0)
		draw_rect(r, Color(0.5, 0.95, 1.0, 0.09) if i == sim.lane else Color(0.06, 0.16, 0.24, 0.45))
		draw_rect(r, Color(0.5, 0.95, 1.0, 0.14), false, 1.0)
	# tirs annoncés
	for b in sim.beams:
		for l in b.lanes:
			var r := Rect2(6.0 + l * 120.0, 6.0, 108.0, Sim.H - 12.0)
			if not b.fired:
				var p := minf(1.0, b.t / b.dur)
				draw_rect(r, Color(1.0, 0.42, 0.48, 0.18))
				_hatch(r, Color(1.0, 0.42, 0.48, 0.5))
				var fh := (Sim.H - 12.0) * p
				draw_rect(Rect2(r.position.x + 2.0, r.end.y - fh, 104.0, fh), Color(1.0, 0.42, 0.48, 0.38))
				_dashed_rect(r, Sim.C_RED)
			else:
				draw_rect(r, Color(1.0, 0.9, 0.9, clampf(b.flash / 0.35, 0.0, 1.0) * 0.85))
		if not b.fired:
			var lanes: Array = b.lanes
			var cx: float = Sim.LANES[lanes[0]] + ((Sim.LANES[lanes[1]] - Sim.LANES[lanes[0]]) / 2.0 if lanes.size() > 1 else 0.0)
			draw_rect(Rect2(cx - 62.0, 160.0, 124.0, 26.0), Sim.C_RED)
			var rem := maxf(0.0, b.dur - b.t)
			_text("%s %s s" % [b.label, ("%.1f" % rem).replace(".", ",")], Vector2(cx, 179.0), 14, Color("1a0610"), false, true)
	if sim.boss.size() > 0 and not sim.boss.dead and not sim.beams.is_empty() and not sim.beams[0].fired:
		var sl: int = sim.boss.safe
		var sr := Rect2(6.0 + sl * 120.0, 6.0, 108.0, Sim.H - 12.0)
		draw_rect(sr, Color(0.43, 1.0, 0.61, 0.14))
		draw_rect(sr, Sim.C_GREEN, false, 2.5)
		_text("✓ SÛR", Vector2(Sim.LANES[sl], 290.0), 20, Sim.C_GREEN)
	# ennemis
	for e in sim.enemies:
		if e.dead:
			continue
		_draw_enemy(e)
		if e.k == "boss":
			draw_rect(Rect2(40, 10, 280, 9), Color("12304a"))
			draw_rect(Rect2(40, 10, maxf(0.0, 280.0 * e.hp / e.max), 9), Sim.C_PINK)
			_text("FOREUSE DES ANNEAUX", Vector2(180, 32), 12, Color("cfe8ef"))
		else:
			_hp_arc(e)
		if sim.scan > 0.0 and e.k != "boss":
			var a := 0.6 + 0.4 * sin(t * 8.0)
			draw_arc(Vector2(e.x, e.y), e.r + 18.0, 0.0, TAU, 24, Color(0.43, 1.0, 0.61, a), 2.5, true)
	# projectiles du joueur
	for b in sim.pbullets:
		draw_line(Vector2(b.x, b.y), Vector2(b.x, b.y + 16.0), Color(0.5, 0.95, 1.0, 0.25), 9.0)
		draw_line(Vector2(b.x, b.y), Vector2(b.x, b.y + 16.0), Sim.C_CYAN, 4.0)
	# projectiles ennemis
	for b in sim.ebullets:
		match b.kind:
			"slow":
				draw_circle(Vector2(b.x, b.y + 6.0), 9.0, Color(1.0, 0.7, 0.42, 0.25))
				draw_circle(Vector2(b.x, b.y + 6.0), 6.0, Color("ffd0a0"))
				draw_arc(Vector2(b.x, b.y + 6.0), 9.0, 0.0, TAU, 16, Sim.C_ORANGE, 2.0, true)
			"fast":
				_trail(b, 34.0, Sim.C_RED, Color("ffd0d6"), 3.0)
			"accel":
				_trail(b, 10.0 + minf(30.0, (b.v - 90.0) / 8.0), Sim.C_PINK, Color("ffe0f8"), 4.5)
			_:
				draw_line(Vector2(b.x, b.y), Vector2(b.x, b.y + 14.0), Sim.C_RED, 4.0)
	# effets
	for f in sim.fx:
		match f.k:
			"col":
				var a: float = 1.0 - f.t / 0.5
				draw_rect(Rect2(f.x - 40.0, 0.0, 80.0, Sim.H), Color(1.0, 0.82, 0.35, a * 0.6))
				draw_rect(Rect2(f.x - 8.0, 0.0, 16.0, Sim.H), Color(1, 1, 1, a))
			"ring":
				var a2: float = 1.0 - f.t / 0.5
				draw_arc(Vector2(f.x, f.y), 20.0 + f.t * 110.0, 0.0, TAU, 32, Color(f.c.r, f.c.g, f.c.b, a2), 3.0, true)
			_:
				var a3: float = 1.0 - f.t / 0.7
				draw_rect(Rect2(f.x, f.y, 3, 3), Color(f.c.r, f.c.g, f.c.b, a3))
	# joueur
	_draw_player()
	# textes
	for tx in sim.texts:
		var a4: float = 1.0 - tx.t / 0.9
		var col: Color = tx.c
		_text(tx.s, Vector2(tx.x, tx.y), tx.z, Color(col.r, col.g, col.b, a4), true)
	# combo
	if sim.combo >= 2:
		draw_circle(Vector2(334, Sim.H - 26.0), 20.0, Color("0a1f33"))
		draw_arc(Vector2(334, Sim.H - 26.0), 20.0, 0.0, TAU, 24, Sim.C_GOLD, 2.5, true)
		_text("x%d" % sim.combo, Vector2(334, Sim.H - 21.0), 17, Sim.C_GOLD, false, true)
		_text("COMBO", Vector2(334, Sim.H - 10.0), 8, Color("a9d3de"))
	# bannière
	if sim.banner_t > 0.0:
		var ba := minf(1.0, sim.banner_t * 2.0)
		var bc: Color = Sim.C_PINK if (sim.banner == "GARDIEN" or sim.banner == "PHASE 3") else Sim.C_CYAN
		_text(sim.banner, Vector2(180, Sim.H / 2.0 - 30.0), 40, Color(bc.r, bc.g, bc.b, ba), true)


func _trail(b: Dictionary, length: float, col: Color, head: Color, w: float) -> void:
	var pts := PackedVector2Array([Vector2(b.x - w * 0.5, b.y - length), Vector2(b.x + w * 0.5, b.y - length), Vector2(b.x + w * 0.5, b.y + 6.0), Vector2(b.x - w * 0.5, b.y + 6.0)])
	var cols := PackedColorArray([Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g, col.b, 0.0), head, head])
	draw_polygon(pts, cols)


func _hp_arc(e: Dictionary) -> void:
	var c := Vector2(e.x, e.y - 4.0)
	var r: float = e.r + 10.0
	draw_arc(c, r, PI * 1.15, PI * 1.85, 16, Color("12304a"), 4.0, true)
	var frac := maxf(0.0, e.hp / e.max)
	if frac > 0.0:
		draw_arc(c, r, PI * 1.15, PI * (1.15 + 0.7 * frac), 16, Sim.C_ORANGE, 4.0, true)


func _draw_player() -> void:
	var x: float = sim.px
	var y: float = Sim.PY
	var tier: int = sim.tier
	var fl := 8.0 + sin(_time * 40.0) * 3.0
	var T := Sim.C_CYAN
	var G := Sim.C_GOLD
	var ghost := 0.45 + 0.3 * sin(_time * 30.0) if sim.dodge > 0.0 else 1.0
	if tier == 4:
		draw_circle(Vector2(x, y), 78.0, Color(1.0, 0.82, 0.35, 0.08))
		draw_arc(Vector2(x, y), 68.0, _time * 0.6, _time * 0.6 + TAU * 0.8, 40, Color(1.0, 0.82, 0.35, 0.45), 2.0, true)
	var engines: Array = [
		[[0, 16, 6]],
		[[-7, 20, 5], [7, 20, 5]],
		[[-28, 32, 6], [28, 32, 6], [0, 22, 7]],
		[[-10, 24, 5], [10, 24, 5], [0, 26, 7], [-38, 36, 5], [38, 36, 5]],
		[[-10, 27, 6], [10, 27, 6], [0, 29, 8], [-35, 38, 6], [35, 38, 6]],
	][tier]
	for e in engines:
		_engine(x + e[0], y + e[1], fl + 6.0 + tier * 2.0, e[2], G if e[2] >= 7 else Sim.C_ORANGE)
	var ha := HULL_A
	var hb := HULL_B
	ha.a = ghost
	hb.a = ghost
	var wa := WING_A
	var wb := WING_B
	wa.a = ghost
	wb.a = ghost
	var edge := Color(T.r, T.g, T.b, ghost)
	match tier:
		0:
			_sym(x, y, [[7, -2], [27, 24], [10, 18], [8, 6]], wa, wb, edge)
			_poly(_abs(x, y, [[0, -38], [8, -12], [11, 18], [0, 12], [-11, 18], [-8, -12]]), ha, hb, edge, 3.0)
			_cannon(x, y - 26.0, 10.0)
			_dome(x, y - 8.0, 5.5)
			_navlight(x - 26.0, y + 23.0, Color("ff5a6a"))
			_navlight(x + 26.0, y + 23.0, Sim.C_GREEN)
		1:
			_sym(x, y, [[9, -10], [35, 26], [14, 19], [10, 4]], wa, wb, edge)
			_sym(x, y, [[11, 8], [20, 31], [11, 25]], DARK_A, DARK_B, edge, 2.0)
			_poly(_abs(x, y, [[0, -44], [10, -14], [13, 22], [0, 15], [-13, 22], [-10, -14]]), ha, hb, edge, 3.0)
			_cannon(x - 14.0, y - 6.0, 16.0)
			_cannon(x + 14.0, y - 6.0, 16.0)
			_dome(x, y - 10.0, 6.0)
			_navlight(x - 34.0, y + 25.0, Color("ff5a6a"))
			_navlight(x + 34.0, y + 25.0, Sim.C_GREEN)
		2:
			_sym(x, y, [[12, -6], [28, 0], [28, 22], [12, 16]], wa, wb, edge)
			_poly(_abs(x, y, [[-33, -8], [-23, -8], [-23, 32], [-33, 32]]), DARK_A, DARK_B, Sim.C_ORANGE, 2.5, false)
			_poly(_abs(x, y, [[23, -8], [33, -8], [33, 32], [23, 32]]), DARK_A, DARK_B, Sim.C_ORANGE, 2.5, false)
			_poly(_abs(x, y, [[0, -48], [12, -18], [15, 27], [0, 19], [-15, 27], [-12, -18]]), ha, hb, edge, 3.0)
			_cannon(x - 10.0, y - 14.0, 18.0)
			_cannon(x + 10.0, y - 14.0, 18.0)
			draw_arc(Vector2(x, y - 36.0), 5.0, 0.0, TAU, 14, Sim.C_ORANGE, 2.0, true)
			_dome(x, y - 8.0, 6.5)
			_navlight(x - 33.0, y - 8.0, Color("ff5a6a"))
			_navlight(x + 33.0, y - 8.0, Sim.C_GREEN)
		3:
			_sym(x, y, [[14, -18], [47, 8], [45, 37], [14, 29]], wa, wb, edge)
			_sym(x, y, [[20, -6], [40, 10], [39, 28], [20, 22]], DARK_A, DARK_B, G, 1.5)
			_poly(_abs(x, y, [[0, -54], [14, -22], [17, 31], [0, 22], [-17, 31], [-14, -22]]), ha, hb, edge, 3.0)
			_line([Vector2(x, y - 44.0), Vector2(x, y + 12.0)], G, 2.0)
			_cannon(x - 9.0, y - 22.0, 18.0)
			_cannon(x + 9.0, y - 22.0, 18.0)
			_cannon(x - 34.0, y - 2.0, 18.0)
			_cannon(x + 34.0, y - 2.0, 18.0)
			_dome(x, y - 14.0, 7.5)
			_navlight(x - 44.0, y + 34.0, Color("ff5a6a"))
			_navlight(x + 44.0, y + 34.0, Sim.C_GREEN)
		_:
			_sym(x, y, [[17, -6], [30, -4], [30, 14], [17, 12]], wa, wb, edge, 2.0)
			_sym(x, y, [[28, -34], [41, -8], [41, 38], [30, 32], [24, -4]], wa, wb, G, 2.5)
			_sym(x, y, [[11, 24], [19, 50], [8, 38]], DARK_A, DARK_B, G, 2.0)
			_poly(_abs(x, y, [[0, -60], [16, -26], [20, 36], [0, 26], [-20, 36], [-16, -26]]), ha, hb, edge, 3.5)
			_line([Vector2(x, y - 50.0), Vector2(x, y + 16.0)], G, 2.5)
			for off in [-10.0, 10.0]:
				_cannon(x + off, y - 26.0, 20.0)
			for off in [-35.0, 35.0]:
				_cannon(x + off, y - 10.0, 20.0)
			for off in [-23.0, 23.0]:
				_cannon(x + off, y - 16.0, 16.0)
			_dome(x, y - 16.0, 8.5)
			draw_arc(Vector2(x, y - 16.0), 13.0, 0.0, TAU, 20, G, 2.0, true)
			_navlight(x - 41.0, y + 36.0, Color("ff5a6a"))
			_navlight(x + 41.0, y + 36.0, Sim.C_GREEN)
	# nacelles d'équipage
	var sp := tier * 5.0
	var pods := [["R", Sim.C_CYAN, -50.0 - sp, -4.0], ["G", Sim.C_ORANGE, -38.0 - sp, 36.0], ["L", Sim.C_GREEN, 50.0 + sp, -4.0]]
	for p in pods:
		var q := Vector2(x + p[2], y + p[3])
		draw_circle(q, 13.0, Color("0a1f33"))
		draw_arc(q, 13.0, 0.0, TAU, 20, Color("12304a"), 3.0, true)
		draw_arc(q, 13.0, -PI / 2.0, -PI / 2.0 + TAU * maxf(0.05, sim.hull / sim.hull_max), 20, p[1], 3.0, true)
		_text(p[0], q + Vector2(0, 4.5), 13, p[1])
	if sim.shield > 0.0:
		var sr := 44.0 + tier * 5.0
		var pts := PackedVector2Array()
		for k in 6:
			var an: float = k * PI / 3.0 + sim.t
			pts.append(Vector2(x + cos(an) * sr, y + sin(an) * sr))
		draw_polygon(pts, PackedColorArray([Color(1.0, 0.7, 0.42, 0.1)]))
		pts.append(pts[0])
		draw_polyline(pts, Sim.C_ORANGE, 3.0, true)


func _draw_enemy(e: Dictionary) -> void:
	var x: float = e.x
	var y: float = e.y
	var w: bool = e.flash > 0.0
	var t: float = sim.t
	match e.k:
		"drone":
			_flame(x, y - 20.0, -(12.0 + sin(t * 30.0) * 3.0), Sim.C_ORANGE, 4.0)
			var a := Color.WHITE if w else Color("3a4f70")
			var b := Color.WHITE if w else Color("0e1828")
			_poly(_abs(x, y, [[0, 26], [7, 4], [29, -15], [14, -4], [8, -22], [0, -16], [-8, -22], [-14, -4], [-29, -15], [-7, 4]]), a, b, Sim.C_SAND, 3.0)
			_line([Vector2(x, y - 14.0), Vector2(x, y + 20.0)], Color(0.8, 0.7, 0.62, 0.5), 1.5)
			draw_circle(Vector2(x, y + 6.0), 5.0, Color("2a0f10"))
			draw_circle(Vector2(x, y + 6.0), 3.0, Sim.C_ORANGE)
		"swarm":
			var a2 := Color.WHITE if w else Color("3a4f70")
			var b2 := Color.WHITE if w else Color("101c2e")
			_poly(_abs(x, y, [[0, 12], [9, 1], [3, -9], [-3, -9], [-9, 1]]), a2, b2, Sim.C_GOLD, 2.5)
			_line([Vector2(x - 9.0, y - 1.0), Vector2(x - 17.0, y - 9.0)], Sim.C_GOLD, 2.0)
			_line([Vector2(x + 9.0, y - 1.0), Vector2(x + 17.0, y - 9.0)], Sim.C_GOLD, 2.0)
			draw_circle(Vector2(x, y + 2.0), 2.6, Sim.C_GOLD)
		"tireur":
			var charging: bool = not sim.beams.is_empty() and not sim.beams[0].fired
			var pc: float = (sim.beams[0].t / sim.beams[0].dur) if charging else 0.0
			var a3 := Color.WHITE if w else Color("4a2030")
			var b3 := Color.WHITE if w else Color("180810")
			_poly(_abs(x, y, [[-30, -20], [30, -20], [41, 4], [18, 23], [-18, 23], [-41, 4]]), a3, b3, Sim.C_RED, 3.5)
			_poly(_abs(x, y, [[-41, 4], [-54, -10], [-45, -26], [-30, -20]]), Color("331626"), Color("12060d"), Sim.C_RED, 2.5, false)
			_poly(_abs(x, y, [[41, 4], [54, -10], [45, -26], [30, -20]]), Color("331626"), Color("12060d"), Sim.C_RED, 2.5, false)
			draw_rect(Rect2(x - 8.0, y + 10.0, 16.0, 31.0), Color("5a2a3a"))
			draw_rect(Rect2(x - 8.0, y + 10.0, 16.0, 31.0), Sim.C_RED, false, 3.0)
			var core := Color(1.0, (107.0 + pc * 120.0) / 255.0, 0.48) if charging else Sim.C_RED
			draw_circle(Vector2(x, y - 2.0), 12.0 + pc * 6.0, Color(core.r, core.g, core.b, 0.35))
			draw_circle(Vector2(x, y - 2.0), 8.0 + pc * 3.0, core)
			if charging:
				draw_arc(Vector2(x, y + 43.0), 6.0 + pc * 16.0, 0.0, TAU, 20, Color(1.0, 0.42, 0.48, 0.4 + pc * 0.6), 2.0, true)
			_flame(x - 18.0, y - 22.0, -12.0, Sim.C_ORANGE, 5.0)
			_flame(x + 18.0, y - 22.0, -12.0, Sim.C_ORANGE, 5.0)
		"boss":
			var f1 := Color("6a5a8a") if w else Color("3b2468")
			var f2 := Color("6a5a8a") if w else Color("150b2a")
			_poly(_abs(x, y, [[-150, -4], [-120, -26], [-106, 40], [-146, 48]]), f1, f2, Sim.C_PINK, 3.5)
			_poly(_abs(x, y, [[150, -4], [120, -26], [106, 40], [146, 48]]), f1, f2, Sim.C_PINK, 3.5)
			_poly(_abs(x, y, [[-110, -30], [-60, -48], [60, -48], [110, -30], [120, 30], [70, 50], [-70, 50], [-120, 30]]), f1, f2, Sim.C_PINK, 4.0)
			_poly(_abs(x, y, [[-30, 44], [30, 44], [0, 106]]), Color("4a2c78"), Color("1a0e30"), Sim.C_PINK, 3.5)
			for i in 4:
				var ph := fposmod(t * 1.6 + float(i) / 4.0, 1.0)
				var yy := y + 46.0 + ph * 52.0
				var hw := 28.0 * (1.0 - ph * 0.95)
				_line([Vector2(x - hw, yy), Vector2(x, yy + hw * 0.5), Vector2(x + hw, yy)], Color(1.0, 0.61, 0.93, 0.75), 2.5)
			_line([Vector2(x - 60.0, y - 48.0), Vector2(x - 40.0, y + 46.0)], Color(1.0, 0.61, 0.93, 0.3), 2.0)
			_line([Vector2(x + 60.0, y - 48.0), Vector2(x + 40.0, y + 46.0)], Color(1.0, 0.61, 0.93, 0.3), 2.0)
			draw_circle(Vector2(x, y), 30.0, Color("2a1848"))
			draw_arc(Vector2(x, y), 30.0, 0.0, TAU, 28, Sim.C_PINK, 4.0, true)
			draw_circle(Vector2(x, y), 16.0, Color(1.0, 0.61, 0.93, 0.3))
			draw_circle(Vector2(x, y), 11.0 + sin(t * 4.0) * 1.5, Color("ffd8f6"))
			for wx in [Sim.LANES[0], Sim.LANES[2]]:
				_flame(wx, y - 50.0, -(14.0 + sin(t * 25.0) * 3.0), Sim.C_ORANGE, 7.0)
				_poly(_abs(wx, y - 4.0, [[0, -13], [13, 0], [0, 13], [-13, 0]]), Color("05091a"), Color("05091a"), Sim.C_GREEN, 3.5, false)
				draw_circle(Vector2(wx, y - 4.0), 4.0, Sim.C_GREEN)
				_text("x2", Vector2(wx, y + 34.0), 11, Sim.C_GREEN, false, true)
