class_name ItemUI
extends RefCounted
## Dessin des objets (maquette branche 4) : icône par emplacement, tuile à cadre de rareté, emplacement vide ou verrouillé, pastilles.

const Data = preload("res://scripts/data.gd")


static func color(rarity: String) -> Color:
	return Data.CHEST_COLORS[rarity]


static func slot_icon(ci: CanvasItem, slot: String, c: Vector2, s: float, col: Color) -> void:
	var k := s / 24.0
	var P := func(x: float, y: float) -> Vector2: return c + (Vector2(x, y) - Vector2(12, 12)) * k
	match slot:
		"arme":
			ci.draw_colored_polygon(PackedVector2Array([P.call(20, 3), P.call(21, 6), P.call(11, 16), P.call(8, 15)]), col)
			ci.draw_line(P.call(6, 13), P.call(11, 18), col, 2.4 * k, true)
			ci.draw_line(P.call(8, 16), P.call(4, 20), col, 2.8 * k, true)
		"armure":
			ci.draw_colored_polygon(PackedVector2Array([P.call(12, 3), P.call(20, 6), P.call(20, 12), P.call(18, 16), P.call(12, 21), P.call(6, 16), P.call(4, 12), P.call(4, 6)]), col)
			ci.draw_line(P.call(12, 7), P.call(12, 18), Color(0.04, 0.07, 0.15, 0.45), 1.6 * k)
		"module":
			ci.draw_style_box(UI.box(col, Color(0, 0, 0, 0), maxi(1, int(3.0 * k)), 0), Rect2(P.call(5, 5), Vector2(14, 14) * k))
			ci.draw_style_box(UI.box(Color(0.04, 0.07, 0.15, 0.55), Color(0, 0, 0, 0), 1, 0), Rect2(P.call(9, 9), Vector2(6, 6) * k))
			for q in [[3, 9, 5, 9], [3, 15, 5, 15], [19, 9, 21, 9], [19, 15, 21, 15], [9, 3, 9, 5], [15, 3, 15, 5], [9, 19, 9, 21], [15, 19, 15, 21]]:
				ci.draw_line(P.call(q[0], q[1]), P.call(q[2], q[3]), col, 1.6 * k)
		_:
			ci.draw_colored_polygon(PackedVector2Array([P.call(12, 2), P.call(17, 8), P.call(12, 22), P.call(7, 8)]), col)
			ci.draw_line(P.call(7, 8), P.call(17, 8), Color(0.04, 0.07, 0.15, 0.4), 1.4 * k)


## Tuile d'objet : cadre et fond à la couleur de la rareté, icône, niveau en bas à droite.
static func tile(ci: CanvasItem, r: Rect2, item: Dictionary, show_level := true, dim := false) -> void:
	var c := color(item.rarity)
	var a := 0.45 if dim else 1.0
	var sb := UI.box(Color(c.r, c.g, c.b, 0.12 * a), Color(c.r, c.g, c.b, a), int(r.size.x * 0.19), 0)
	sb.set_border_width_all(3)
	ci.draw_style_box(sb, r)
	slot_icon(ci, item.slot, r.position + r.size * 0.5, r.size.x - 40.0 * (r.size.x / 124.0) - 4.0, Color(c.r, c.g, c.b, a))
	if show_level:
		var fs := maxi(14, int(r.size.x * 0.14))
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
