extends Control
## Cadre en pointillés (salle vide, poste libre) : se place par-dessus un panneau, sans capter les touches.

var color := Color(1.0, 0.7, 0.42)
var radius := 18.0
var dash := 14.0
var gap := 10.0
var width := 2.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	paint(self, size, color, radius, dash, gap, width)


## Dessine le cadre en pointillés sur n'importe quel élément (appelé depuis son _draw).
static func paint(ci: CanvasItem, area: Vector2, col: Color, rad: float, dash_len: float, gap_len: float, line_w: float) -> void:
	var w := area.x
	var h := area.y
	var r := minf(rad, minf(w, h) / 2.0)
	_dashed(ci, Vector2(r, 0), Vector2(w - r, 0), col, dash_len, gap_len, line_w)
	_dashed(ci, Vector2(w, r), Vector2(w, h - r), col, dash_len, gap_len, line_w)
	_dashed(ci, Vector2(w - r, h), Vector2(r, h), col, dash_len, gap_len, line_w)
	_dashed(ci, Vector2(0, h - r), Vector2(0, r), col, dash_len, gap_len, line_w)
	for corner in [[Vector2(w - r, r), -PI / 2.0], [Vector2(w - r, h - r), 0.0], [Vector2(r, h - r), PI / 2.0], [Vector2(r, r), PI]]:
		ci.draw_arc(corner[0], r, corner[1], corner[1] + PI / 2.0, 8, col, line_w, true)


static func _dashed(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, dash_len: float, gap_len: float, line_w: float) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 0.001)
	var t := 0.0
	while t < length:
		var e := minf(t + dash_len, length)
		ci.draw_line(a + dir * t, a + dir * e, col, line_w, true)
		t += dash_len + gap_len
