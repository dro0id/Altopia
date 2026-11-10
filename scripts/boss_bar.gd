class_name BossBar
extends Control
## Barre du boss (maquettes BB et BX) : barre de vie en haut du terrain, nom et phase (ou pourcentage) dessous.

var title := ""
var phase := ""
var frac := 1.0
var col := UI.RED
var wait := false            # le boss n'est pas encore arrivé : barre pleine, atténuée


func _draw() -> void:
	var track := Rect2(0, 0, size.x, 28)
	draw_style_box(UI.box(Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 14, 0), track)
	if frac > 0.0:
		draw_style_box(UI.box(Color(col, 0.45) if wait else col, Color(0, 0, 0, 0), 14, 0), Rect2(0, 0, maxf(28.0, size.x * clampf(frac, 0.0, 1.0)), 28))
	var tail := (phase if wait else phase.to_lower()) if phase != "" else "%d %%" % int(round(frac * 100.0))
	var lab := "%s · %s" % [title, tail]
	draw_string(UI.bold_font(), Vector2(0, 64), lab, HORIZONTAL_ALIGNMENT_LEFT, size.x, M3.fs(24), Color(1.0, 0.61, 0.61) if col == UI.RED else Color("ffcf8a"))
