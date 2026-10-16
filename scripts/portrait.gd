extends Control
## Portrait 2D d'un héros, dessiné en code : cadre de rareté, emblème de classe, étoiles.

const Data = preload("res://scripts/game_data.gd")

var hero_id := ""
var stars := 0
var dimmed := false


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)


func setup(id: String, star_count: int, is_dimmed: bool = false) -> void:
	hero_id = id
	stars = star_count
	dimmed = is_dimmed
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 5.0
	if hero_id == "":
		draw_arc(c, r, 0.0, TAU, 40, Color(0.3, 0.38, 0.6, 0.6), 3.0)
		draw_line(c + Vector2(-r * 0.3, 0), c + Vector2(r * 0.3, 0), Color(0.3, 0.38, 0.6, 0.6), 4.0)
		draw_line(c + Vector2(0, -r * 0.3), c + Vector2(0, r * 0.3), Color(0.3, 0.38, 0.6, 0.6), 4.0)
		return
	var h: Dictionary = Data.HEROES[hero_id]
	var rar: Dictionary = Data.RARITY[h.rarity]
	var col: Color = Data.CREW[h["class"]].color
	var alpha := 0.45 if dimmed else 1.0
	draw_circle(c, r, Color(0.05, 0.08, 0.2, alpha))
	draw_circle(c, r * 0.82, Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, alpha))
	col.a = alpha
	match h["class"]:
		"pilot":     # vaisseau : triangle pointé vers le haut
			var pts := PackedVector2Array([
				c + Vector2(0, -r * 0.5), c + Vector2(r * 0.38, r * 0.4),
				c + Vector2(0, r * 0.18), c + Vector2(-r * 0.38, r * 0.4)])
			draw_colored_polygon(pts, col)
		"engineer":  # engrenage : disque + dents
			draw_circle(c, r * 0.32, col)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.3, c + Vector2(cos(a), sin(a)) * r * 0.52, col, 7.0)
			draw_circle(c, r * 0.13, Color(0.05, 0.08, 0.2, alpha))
		"scientist": # atome : noyau + orbites
			draw_circle(c, r * 0.14, col)
			for i in 3:
				var pts := PackedVector2Array()
				var rot := PI * i / 3.0
				for k in 25:
					var t := TAU * k / 24.0
					var p := Vector2(cos(t) * r * 0.55, sin(t) * r * 0.2)
					pts.append(c + p.rotated(rot))
				draw_polyline(pts, col, 2.5)
	var rc: Color = rar.color
	rc.a = alpha
	draw_arc(c, r, 0.0, TAU, 48, rc, 4.0)
	for i in stars:
		var sx := c.x + (i - (stars - 1) / 2.0) * 13.0
		draw_circle(Vector2(sx, size.y - 8.0), 4.5, Color(1.0, 0.85, 0.3, alpha))
