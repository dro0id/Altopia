extends Control
## Anneau de progression (0 à 1) : fond sombre et arc coloré qui part du haut.

var value := 0.0 : set = set_value
var color := Color(1.0, 0.61, 0.93)
var track := Color(0.07, 0.19, 0.29)
var thickness := 10.0


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - thickness / 2.0
	draw_arc(c, r, 0.0, TAU, 72, track, thickness, true)
	if value > 0.001:
		draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * value, 72, color, thickness, true)
