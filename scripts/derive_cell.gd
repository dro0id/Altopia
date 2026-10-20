extends Button
## Une case de la grille de la dérive : le bouton affiche le symbole, cette classe dessine par-dessus
## le météore annoncé (hachures et compte à rebours), la progression de l'extraction, le coût du scan et les anneaux de repère.

var meteor_left := -1.0           # secondes avant l'impact ; négatif : aucun météore annoncé
var meteor_total := 2.2
var progress := -1.0              # progression de l'extraction (0 à 1) ; négatif : aucune
var cost := ""
var target := false               # la ressource connue la plus proche
var selected := false
var near := false                 # case voisine du vaisseau, pas encore scannée


func _init() -> void:
	clip_contents = true


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if near:
		_dashed(r.grow(-1.0), Color("80f2ff"), 2.0)
	if meteor_left >= 0.0:
		var d := -r.size.y
		while d < r.size.x:
			draw_line(Vector2(d, r.size.y), Vector2(d + r.size.y, 0.0), Color(1.0, 0.42, 0.48, 0.55), 3.0)
			d += 14.0
		_dashed(r.grow(-1.0), Color("ff6b7a"), 3.0)
		var f := ThemeDB.fallback_font
		var txt := ("%.1f" % maxf(0.0, meteor_left)).replace(".", ",")
		draw_string_outline(f, Vector2(r.size.x - 44.0, 20.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 40.0, 17, 5, Color(0, 0, 0))
		draw_string(f, Vector2(r.size.x - 44.0, 20.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 40.0, 17, Color.WHITE)
	if progress >= 0.0:
		draw_rect(Rect2(8.0, r.size.y - 14.0, r.size.x - 16.0, 7.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(8.0, r.size.y - 14.0, (r.size.x - 16.0) * clampf(progress, 0.0, 1.0), 7.0), Color("ffb26b"))
	if cost != "":
		var f2 := ThemeDB.fallback_font
		draw_string(f2, Vector2(7.0, 20.0), cost, HORIZONTAL_ALIGNMENT_LEFT, 30.0, 17, Color("c79bff"))
	if target:
		draw_rect(r.grow(-1.0), Color("ffd159"), false, 4.0)
		draw_rect(r.grow(3.0), Color(1.0, 0.82, 0.35, 0.3), false, 4.0)
	if selected:
		draw_rect(r.grow(-1.0), Color("ffd159"), false, 5.0)


func _dashed(rect: Rect2, col: Color, w: float) -> void:
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
