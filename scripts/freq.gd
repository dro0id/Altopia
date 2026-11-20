class_name Freq
extends RefCounted
## Fréquences du verre (maquette WE) : pastille hexagonale à facettes, et compte des héros avantagés.

const Data = preload("res://scripts/data.gd")


static func hex(ci: CanvasItem, f: String, at: Vector2, r: float, dim := false) -> void:
	if not Data.FREQ_COLORS.has(f):
		return
	var col: Color = Data.FREQ_COLORS[f]
	if dim:
		col = col.darkened(0.55)
	var pts := PackedVector2Array()
	for k in 6:
		var a := -PI / 2.0 + k * PI / 3.0
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_colored_polygon(pts, col)
	# facettes : moitié basse plus sombre, haut éclairé
	ci.draw_colored_polygon(PackedVector2Array([at, pts[2], pts[3], pts[4]]), col.darkened(0.25))
	ci.draw_colored_polygon(PackedVector2Array([at, pts[5], pts[0], pts[1]]), col.lightened(0.3))
	ci.draw_polyline(outline, Color(0.03, 0.05, 0.12), maxf(1.5, r * 0.14), true)


## Héros de l'escouade avantagés à cet étage.
static func advantaged(g: Node, stage: int) -> int:
	var n := 0
	for id in g.squad_ids():
		if Data.freq_advantaged(String(id), stage):
			n += 1
	return n
