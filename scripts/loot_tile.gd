class_name LootTile
extends Control
## Case de butin (maquette E) : bordure en pointillés et « ? » tant que le coffre est fermé, puis la valeur.

var title := ""
var value := ""
var col := UI.MUTED
var revealed := false
var pop := 0.0


func _draw() -> void:
	draw_style_box(UI.box(Color("0d1530"), Color(0, 0, 0, 0), 24, 0), Rect2(Vector2.ZERO, size))
	var line := Color("2b3a6b") if not revealed else Color(col.r, col.g, col.b, 0.7)
	_dashed_round_rect(Rect2(1.5, 1.5, size.x - 3.0, size.y - 3.0), 22.0, line, 3.0, not revealed)
	var f := UI.bold_font()
	var fs := 40
	var txt := value if revealed else "?"
	var c := col if revealed else Color("2b3a6b")
	draw_string(f, Vector2(0, size.y * 0.5 + 6.0 - pop * 4.0), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs if not revealed else 34, c)
	draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 22.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, UI.MUTED)


func _dashed_round_rect(r: Rect2, rad: float, c: Color, w: float, dashed: bool) -> void:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI],
	]
	for cn in corners:
		for i in 7:
			var a: float = cn[1] + (PI * 0.5) * float(i) / 6.0
			pts.append(cn[0] + Vector2.from_angle(a) * rad)
	pts.append(pts[0])
	if not dashed:
		draw_polyline(pts, c, w, true)
		return
	# pointillés : 8 px tracés, 8 px vides, le long du contour
	var acc := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var d := 0.0
		while d < seg:
			var on := int((acc + d) / 8.0) % 2 == 0
			var d2 := minf(seg, d + 4.0)
			if on:
				draw_line(a.lerp(b, d / seg), a.lerp(b, d2 / seg), c, w)
			d = d2
		acc += seg
