class_name BossBar
extends Control
## Barre du boss (maquette L) : titre, phase, barre de vie.

var title := ""
var phase := ""
var frac := 1.0
var col := UI.RED


func _draw() -> void:
	var sb := UI.box(Color(0.051, 0.082, 0.188, 0.87), col, 24, 0)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var f := ThemeDB.fallback_font
	draw_string(UI.bold_font(), Vector2(20, 38), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 160.0, 24, col)
	if phase != "":
		draw_string(UI.bold_font(), Vector2(0, 38), phase, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 20.0, 24, UI.MUTED)
	var track := Rect2(20, 52, size.x - 40.0, 20)
	draw_style_box(UI.box(Color("3a1620"), Color(0, 0, 0, 0), 10, 0), track)
	if frac > 0.0:
		var w := maxf(20.0, track.size.x * clampf(frac, 0.0, 1.0))
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(10)
		draw_style_box(fill, Rect2(track.position, Vector2(w, 20)))
		# dégradé simple : moitié droite plus claire
		var light := StyleBoxFlat.new()
		light.bg_color = Color(col.r, minf(1.0, col.g + 0.25), minf(1.0, col.b + 0.2), 0.5)
		light.set_corner_radius_all(10)
		draw_style_box(light, Rect2(track.position + Vector2(w * 0.5, 0), Vector2(w * 0.5, 20)))
