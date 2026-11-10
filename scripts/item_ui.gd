class_name ItemUI
extends RefCounted
## Dessin des objets (maquette branche 4) : icône par emplacement, tuile à cadre de rareté, emplacement vide ou verrouillé, pastilles.

const Data = preload("res://scripts/data.gd")


static func color(rarity: String) -> Color:
	return Data.CHEST_COLORS[rarity]


static func slot_icon(ci: CanvasItem, slot: String, c: Vector2, s: float, col: Color, variant := 0) -> void:
	var k := s / 24.0
	var P := func(x: float, y: float) -> Vector2: return c + (Vector2(x, y) - Vector2(12, 12)) * k
	var poly := func(pts: Array, cc: Color) -> void:
		var arr := PackedVector2Array()
		for q in pts:
			arr.append(P.call(q[0], q[1]))
		ci.draw_colored_polygon(arr, cc)
	var lit := col.lightened(0.45)            # facette claire en haut à gauche (maquette G8)
	var dark := Color(0.04, 0.07, 0.15, 0.45)
	match slot:
		"arme":
			match variant:
				0:    # pistolet
					poly.call([[4, 8], [19, 8], [19, 12], [11, 12], [10, 19], [6, 19], [7, 12], [4, 12]], col)
					poly.call([[4, 8], [19, 8], [18, 10], [5, 10]], lit)
					ci.draw_line(P.call(19, 10), P.call(22, 10), col, 2.0 * k)
				1:    # carabine, fusil
					poly.call([[2, 9], [21, 9], [21, 12], [9, 12], [7, 16], [3, 16], [4, 12], [2, 12]], col)
					poly.call([[2, 9], [21, 9], [20, 10.5], [3, 10.5]], lit)
					poly.call([[11, 12], [14, 12], [13, 17], [10, 17]], col)
				_:    # lance, canon
					poly.call([[3, 14], [16, 5], [19, 8], [6, 17]], col)
					poly.call([[3, 14], [16, 5], [17, 6], [4, 15]], lit)
					ci.draw_arc(P.call(19, 6), 3.5 * k, 0, TAU, 14, col.lightened(0.2), 1.8 * k, true)
					poly.call([[6, 17], [9, 20], [5, 22], [3, 19]], col)
		"armure":
			match variant:
				0:    # gilet
					poly.call([[12, 3], [20, 6], [20, 12], [18, 16], [12, 21], [6, 16], [4, 12], [4, 6]], col)
					poly.call([[12, 3], [4, 6], [4, 12], [12, 9]], lit)
					ci.draw_line(P.call(12, 7), P.call(12, 18), dark, 1.6 * k)
				1:    # plastron à épaulières
					poly.call([[7, 6], [17, 6], [18, 18], [12, 21], [6, 18]], col)
					poly.call([[2, 6], [7, 4], [8, 10], [3, 11]], col)
					poly.call([[22, 6], [17, 4], [16, 10], [21, 11]], col)
					poly.call([[7, 6], [12, 6], [12, 12], [7, 11]], lit)
				_:    # égide hexagonale à facettes
					poly.call([[12, 2], [21, 7], [21, 16], [12, 22], [3, 16], [3, 7]], col)
					poly.call([[12, 2], [3, 7], [12, 12]], lit)
					poly.call([[12, 12], [21, 16], [12, 22]], dark)
		"module":
			match variant:
				0:    # puce
					ci.draw_style_box(UI.box(col, Color(0, 0, 0, 0), maxi(1, int(3.0 * k)), 0), Rect2(P.call(5, 5), Vector2(14, 14) * k))
					ci.draw_style_box(UI.box(Color(0.04, 0.07, 0.15, 0.55), Color(0, 0, 0, 0), 1, 0), Rect2(P.call(9, 9), Vector2(6, 6) * k))
					for q in [[3, 9, 5, 9], [3, 15, 5, 15], [19, 9, 21, 9], [19, 15, 21, 15], [9, 3, 9, 5], [15, 3, 15, 5], [9, 19, 9, 21], [15, 19, 15, 21]]:
						ci.draw_line(P.call(q[0], q[1]), P.call(q[2], q[3]), col, 1.6 * k)
				1:    # résonateur
					ci.draw_arc(c, 9.5 * k, 0, TAU, 28, col, 2.2 * k, true)
					ci.draw_arc(c, 6.0 * k, -PI * 0.8, PI * 0.6, 20, col, 2.0 * k, true)
					ci.draw_circle(c, 3.0 * k, lit)
				_:    # cœur, matrice
					poly.call([[12, 3], [20, 8], [20, 16], [12, 21], [4, 16], [4, 8]], col)
					poly.call([[12, 7], [16, 9.5], [16, 14.5], [12, 17], [8, 14.5], [8, 9.5]], dark)
					poly.call([[12, 3], [4, 8], [8, 9.5], [12, 7]], lit)
		_:
			match variant:
				0:    # éclat
					poly.call([[12, 2], [17, 8], [12, 22], [7, 8]], col)
					poly.call([[12, 2], [7, 8], [12, 9]], lit)
				1:    # larme, cristal
					poly.call([[12, 2], [18, 13], [16, 19], [12, 21], [8, 19], [6, 13]], col)
					poly.call([[12, 2], [6, 13], [10, 13]], lit)
				_:    # étoile brisée
					var pts := []
					for i in 10:
						var a := -PI / 2.0 + i * PI / 5.0
						var rr := 10.0 if i % 2 == 0 else 4.2
						pts.append([12.0 + cos(a) * rr, 12.0 + sin(a) * rr])
					poly.call(pts, col)
					ci.draw_line(P.call(12, 4), P.call(13, 13), dark, 1.6 * k)
					ci.draw_line(P.call(13, 13), P.call(10, 20), dark, 1.6 * k)


## Variante de dessin d'après le nom (maquette G5) : trois dessins par emplacement.
static func variant_of(item: Dictionary) -> int:
	var names: Array = Items.NAMES.get(String(item.get("slot", "")), [])
	var i := names.find(String(item.get("name", "")))
	return 0 if i < 0 else i / 2


## Tuile d'objet : cadre et fond à la couleur de la rareté, icône, niveau en bas à droite.
static func tile(ci: CanvasItem, r: Rect2, item: Dictionary, show_level := true, dim := false) -> void:
	var c := color(item.rarity)
	var a := 0.45 if dim else 1.0
	var sb := UI.box(Color(c.r, c.g, c.b, 0.12 * a), Color(c.r, c.g, c.b, a), int(r.size.x * 0.19), 0)
	sb.set_border_width_all(3)
	ci.draw_style_box(sb, r)
	slot_icon(ci, item.slot, r.position + r.size * 0.5, r.size.x - 40.0 * (r.size.x / 124.0) - 4.0, Color(c.r, c.g, c.b, a), variant_of(item))
	if String(item.get("set", "")) != "" and Items.SETS.has(String(item.set)):
		# sceau d'ensemble en coin (maquette G5)
		var sc: Color = Items.SETS[item.set].color
		var q := r.position + Vector2(r.size.x * 0.2, r.size.y * 0.2)
		var h := maxf(7.0, r.size.x * 0.08)
		ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -h), q + Vector2(h, 0), q + Vector2(0, h), q + Vector2(-h, 0)]), Color(sc, a))
	if show_level:
		var fs := maxi(18, int(r.size.x * 0.18))      # lisible (maquette G5)
		ci.draw_string(UI.bold_font(), r.position + Vector2(0, r.size.y - 6), "%d" % int(item.level), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8.0, fs, Color(c.r, c.g, c.b, a))


static func empty(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_style_box(UI.box(Color("0d1530"), Color(0, 0, 0, 0), int(r.size.x * 0.19), 0), r)
	_dashed(ci, r.grow(-1.5), Color("2b3a6b"))
	ci.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, r.size.y * 0.5 + 12.0), "+", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color("2b3a6b"))


static func locked(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_style_box(UI.box(Color("0d1530"), Color("2b3a6b"), int(r.size.x * 0.19), 0), r)
	var c := r.position + r.size * 0.5
	ci.draw_style_box(UI.box(Color("2b3a6b"), Color(0, 0, 0, 0), 4, 0), Rect2(c + Vector2(-14, -2), Vector2(28, 22)))
	ci.draw_arc(c + Vector2(0, -4), 9, PI, TAU, 12, Color("2b3a6b"), 4.0)


## Pastille ronde (▲ vert, nombre rouge) posée sur un coin.
static func dot(ci: CanvasItem, c: Vector2, txt: String, bg: Color = Color("7dffb0"), fg: Color = Color("06101f")) -> void:
	ci.draw_circle(c, 20, UI.BG)
	ci.draw_circle(c, 16, bg)
	if txt == "▲":
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(8, 5), c + Vector2(-8, 5)]), fg)
	else:
		ci.draw_string(UI.bold_font(), c + Vector2(-16, 8), txt, HORIZONTAL_ALIGNMENT_CENTER, 32, 22, fg)


## Delta de puissance : ▲ +640 en vert, ▼ 120 en rouge.
static func delta(ci: CanvasItem, right_x: float, y: float, d: float, fs := 24) -> void:
	var up := d >= 0.0
	var txt := ("+%d" % int(d)) if up else ("%d" % int(absf(d)))
	var col := UI.GREEN if up else UI.RED
	var w := UI.bold_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(UI.bold_font(), Vector2(right_x - w, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var tx := right_x - w - 12.0 - fs * 0.5
	var c := Vector2(tx, y - fs * 0.36)
	var h := fs * 0.38
	if up:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, h), c + Vector2(-h, h)]), col)
	else:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(0, h)]), col)


static func set_badge(ci: CanvasItem, pos: Vector2, set_id: String) -> float:
	var info: Dictionary = Items.SETS[set_id]
	var col: Color = info.color
	var w := UI.bold_font().get_string_size(info.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 20.0
	ci.draw_style_box(UI.box(Color(0, 0, 0, 0), Color(col.r, col.g, col.b, 0.45), 12, 0), Rect2(pos, Vector2(w, 30)))
	ci.draw_string(UI.bold_font(), pos + Vector2(10, 22), info.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	return w


static func _dashed(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 12.0)
		for k in range(0, n, 2):
			ci.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 3.0)
