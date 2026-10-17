extends Control
## Personnages « chibi » dessinés en code : grosse tête, visage, accessoires par rôle.
##   setup_captain(look)        le Capitaine (combinaison, cheveux, coupe personnalisables)
##   setup_crew(hero_id, stars) une carte d'équipage (accessoire selon la classe)
##   setup_enemy(kind)          un ennemi (astéroïdes, étoile, planète)
##   setup_empty(class_id)      un poste vide

const Data = preload("res://scripts/game_data.gd")

const SKIN := Color(0.97, 0.82, 0.7)
const OUTLINE := Color(0.08, 0.08, 0.14)

var kind := "empty"
var look := {"suit": 0, "hair": 0, "style": 0}
var role := "pilot"
var rarity_col := Color(0.7, 0.75, 0.9)
var stars := 0
var enemy_kind := "asteroids"
var animate := true
var dimmed := false
var _t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup_captain(p_look: Dictionary) -> void:
	kind = "captain"
	look = p_look
	role = "captain"
	queue_redraw()


func setup_crew(hero_id: String, star_count: int, is_dimmed: bool = false) -> void:
	if hero_id == "":
		setup_empty(role)
		return
	kind = "crew"
	var h: Dictionary = Data.HEROES[hero_id]
	role = h["class"]
	rarity_col = Data.RARITY[h.rarity].color
	stars = star_count
	dimmed = is_dimmed
	# chaque équipier a sa propre coiffure/couleur, déterminées par son identité
	var idx: int = Data.HERO_ORDER.find(hero_id)
	look = {"suit": Data.CREW_ORDER.find(role) * 2 % Data.LOOK_SUITS.size(), "hair": idx % Data.LOOK_HAIRS.size(), "style": idx % Data.LOOK_STYLES}
	queue_redraw()


func setup_drone() -> void:
	kind = "drone"
	queue_redraw()


func setup_enemy(p_kind: String) -> void:
	kind = "enemy"
	enemy_kind = p_kind
	queue_redraw()


func setup_empty(class_id: String) -> void:
	kind = "empty"
	role = class_id
	queue_redraw()


func _process(delta: float) -> void:
	if animate and kind != "empty" and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _fan(center: Vector2, r: float, a0: float, a1: float, steps: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array([center])
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func _ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var bob := sin(_t * 3.0) * s * 0.012 if animate else 0.0
	var c := Vector2(size.x / 2.0, size.y / 2.0 + bob)
	match kind:
		"captain":
			_draw_human(c, s, Data.LOOK_SUITS[look.suit], Data.LOOK_HAIRS[look.hair], look.style, "captain")
		"crew":
			_draw_human(c, s, Data.CREW[role].color.darkened(0.15), Data.LOOK_HAIRS[look.hair], look.style, role)
		"enemy":
			_draw_enemy(c, s)
		"drone":
			_draw_drone(c, s)
		_:
			var col: Color = Data.CREW[role].color if Data.CREW.has(role) else Color(0.4, 0.5, 0.8)
			col.a = 0.45
			draw_arc(size / 2.0, s * 0.36, 0.0, TAU, 40, col, 3.0)
			draw_line(size / 2.0 + Vector2(-s * 0.1, 0), size / 2.0 + Vector2(s * 0.1, 0), col, 3.0)
			draw_line(size / 2.0 + Vector2(0, -s * 0.1), size / 2.0 + Vector2(0, s * 0.1), col, 3.0)


func _draw_human(c: Vector2, s: float, suit: Color, hair: Color, style: int, who: String) -> void:
	var a := 0.5 if dimmed else 1.0
	suit.a = a
	hair.a = a
	var skin := SKIN
	skin.a = a
	var dark := suit.darkened(0.45)
	dark.a = a
	var head := c + Vector2(0, -s * 0.14)
	var hr := s * 0.27
	# ombre au sol
	_ellipse(c + Vector2(0, s * 0.42), s * 0.2, s * 0.04, Color(0, 0, 0, 0.28 * a))
	# jambes
	draw_rect(Rect2(c.x - s * 0.11, c.y + s * 0.26, s * 0.09, s * 0.15), dark)
	draw_rect(Rect2(c.x + s * 0.02, c.y + s * 0.26, s * 0.09, s * 0.15), dark)
	# corps (blouse blanche pour le Scientifique)
	var body := suit
	if who == "scientist":
		body = Color(0.95, 0.96, 1.0, a)
	draw_rect(Rect2(c.x - s * 0.17, c.y + s * 0.02, s * 0.34, s * 0.27), body)
	if who == "scientist":
		draw_rect(Rect2(c.x - s * 0.06, c.y + s * 0.02, s * 0.12, s * 0.27), suit)
	draw_rect(Rect2(c.x - s * 0.17, c.y + s * 0.21, s * 0.34, s * 0.04), dark)
	# bras + mains
	draw_rect(Rect2(c.x - s * 0.24, c.y + s * 0.04, s * 0.07, s * 0.2), body)
	draw_rect(Rect2(c.x + s * 0.17, c.y + s * 0.04, s * 0.07, s * 0.2), body)
	draw_circle(c + Vector2(-s * 0.205, s * 0.26), s * 0.04, skin)
	draw_circle(c + Vector2(s * 0.205, s * 0.26), s * 0.04, skin)
	# cheveux derrière la tête
	if style == 2:
		draw_rect(Rect2(head.x - hr * 1.08, head.y - hr * 0.2, hr * 0.5, hr * 1.5), hair)
		draw_rect(Rect2(head.x + hr * 0.58, head.y - hr * 0.2, hr * 0.5, hr * 1.5), hair)
	# tête
	draw_circle(head, hr, skin)
	# frange / coiffure
	draw_colored_polygon(_fan(head + Vector2(0, -hr * 0.04), hr * 1.04, PI * 1.02, PI * 1.98), hair)
	if style == 1:
		for i in 5:
			var ang := lerpf(PI * 1.12, PI * 1.88, i / 4.0)
			var base := head + Vector2(cos(ang), sin(ang)) * hr * 0.98
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(-hr * 0.17, 0), base + Vector2(cos(ang), sin(ang)) * hr * 0.5 + Vector2(0, -hr * 0.12),
				base + Vector2(hr * 0.17, 0)]), hair)
	# accessoires par rôle
	match who:
		"captain":
			var gold := Color(1.0, 0.82, 0.25, a)
			if style == 1:
				# cheveux en pointes : pas de casquette, un bandeau doré avec l'insigne
				draw_rect(Rect2(head.x - hr * 1.0, head.y - hr * 0.42, hr * 2.0, hr * 0.2), Color(0.12, 0.17, 0.4, a))
				draw_circle(head + Vector2(0, -hr * 0.32), hr * 0.15, gold)
			else:
				var hat := Color(0.12, 0.17, 0.4, a)
				draw_colored_polygon(_fan(head + Vector2(0, -hr * 0.05), hr * 1.1, PI * 1.0, PI * 2.0), hat)
				draw_rect(Rect2(head.x - hr * 1.15, head.y - hr * 0.1, hr * 2.3, hr * 0.16), hat.lightened(0.15))
				draw_circle(head + Vector2(0, -hr * 0.62), hr * 0.17, gold)
			draw_circle(c + Vector2(-s * 0.17, s * 0.03), s * 0.045, Color(1.0, 0.82, 0.25, a))
			draw_circle(c + Vector2(s * 0.17, s * 0.03), s * 0.045, Color(1.0, 0.82, 0.25, a))
		"pilot":
			var rim := Color(0.35, 0.9, 1.0, a)
			draw_circle(head + Vector2(-hr * 0.36, -hr * 0.42), hr * 0.24, rim)
			draw_circle(head + Vector2(hr * 0.36, -hr * 0.42), hr * 0.24, rim)
			draw_circle(head + Vector2(-hr * 0.36, -hr * 0.42), hr * 0.14, Color(0.1, 0.2, 0.35, a))
			draw_circle(head + Vector2(hr * 0.36, -hr * 0.42), hr * 0.14, Color(0.1, 0.2, 0.35, a))
			draw_line(head + Vector2(-hr * 0.95, -hr * 0.3), head + Vector2(hr * 0.95, -hr * 0.3), Color(0.25, 0.25, 0.3, a), 3.0)
		"engineer":
			var hat := Color(1.0, 0.8, 0.15, a)
			draw_colored_polygon(_fan(head + Vector2(0, -hr * 0.1), hr * 1.08, PI * 1.0, PI * 2.0), hat)
			draw_rect(Rect2(head.x - hr * 1.2, head.y - hr * 0.16, hr * 2.4, hr * 0.14), hat.darkened(0.15))
			draw_circle(head + Vector2(0, -hr * 0.78), hr * 0.14, Color(1.0, 1.0, 0.8, a))
	# visage
	var eye_y := head.y + hr * 0.12
	for sx in [-1.0, 1.0]:
		var ex: float = head.x + sx * hr * 0.4
		_ellipse(Vector2(ex, eye_y), hr * 0.17, hr * 0.22, Color(1, 1, 1, a))
		_ellipse(Vector2(ex + sx * hr * 0.02, eye_y + hr * 0.02), hr * 0.12, hr * 0.17, Color(0.12, 0.14, 0.25, a))
		draw_circle(Vector2(ex - hr * 0.04, eye_y - hr * 0.06), hr * 0.045, Color(1, 1, 1, a))
		draw_circle(Vector2(ex + sx * hr * 0.28, eye_y + hr * 0.36), hr * 0.12, Color(1.0, 0.55, 0.55, 0.45 * a))
	draw_arc(Vector2(head.x, head.y + hr * 0.5), hr * 0.14, PI * 0.15, PI * 0.85, 8, Color(0.5, 0.2, 0.2, a), 2.0)
	if who == "scientist":
		for sx in [-1.0, 1.0]:
			draw_arc(Vector2(head.x + sx * hr * 0.4, eye_y), hr * 0.27, 0.0, TAU, 18, Color(0.9, 0.95, 1.0, a), 2.5)
		draw_line(Vector2(head.x - hr * 0.13, eye_y), Vector2(head.x + hr * 0.13, eye_y), Color(0.9, 0.95, 1.0, a), 2.5)
	if kind == "crew":
		var rc := rarity_col
		rc.a = a
		draw_arc(Vector2(size.x / 2.0, size.y / 2.0), s * 0.47, 0.0, TAU, 48, rc, 3.0)
		for i in stars:
			var sx2 := size.x / 2.0 + (i - (stars - 1) / 2.0) * s * 0.11
			draw_circle(Vector2(sx2, size.y - s * 0.05), s * 0.035, Color(1.0, 0.85, 0.3, a))


func _draw_drone(c: Vector2, s: float) -> void:
	var hover := sin(_t * 3.0) * s * 0.03 if animate else 0.0
	var cc := c + Vector2(0, hover - s * 0.05)
	_ellipse(c + Vector2(0, s * 0.42), s * 0.18, s * 0.04, Color(0, 0, 0, 0.25))
	draw_circle(cc, s * 0.3, Color(0.62, 0.68, 0.8))
	draw_circle(cc, s * 0.22, Color(0.2, 0.26, 0.42))
	draw_circle(cc + Vector2(0, -s * 0.01), s * 0.1, Color(0.45, 0.95, 1.0))
	draw_circle(cc + Vector2(-s * 0.03, -s * 0.04), s * 0.03, Color(1, 1, 1))
	draw_line(cc + Vector2(-s * 0.3, -s * 0.2), cc + Vector2(-s * 0.46, -s * 0.28), Color(0.62, 0.68, 0.8), 4.0)
	draw_line(cc + Vector2(s * 0.3, -s * 0.2), cc + Vector2(s * 0.46, -s * 0.28), Color(0.62, 0.68, 0.8), 4.0)
	draw_circle(cc + Vector2(-s * 0.46, -s * 0.28), s * 0.05, Color(1.0, 0.6, 0.25))
	draw_circle(cc + Vector2(s * 0.46, -s * 0.28), s * 0.05, Color(1.0, 0.6, 0.25))


func _draw_enemy(c: Vector2, s: float) -> void:
	var wob := sin(_t * 4.0) * s * 0.01 if animate else 0.0
	_ellipse(c + Vector2(0, s * 0.4), s * 0.22, s * 0.04, Color(0, 0, 0, 0.28))
	match enemy_kind:
		"star":
			var fire := Color(1.0, 0.5, 0.15)
			for i in 5:
				var x: float = c.x + (i - 2) * s * 0.11
				var h: float = s * (0.3 + 0.1 * sin(_t * 6.0 + i)) if animate else s * 0.32
				draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.07, c.y - s * 0.05), Vector2(x, c.y - s * 0.05 - h), Vector2(x + s * 0.07, c.y - s * 0.05)]), Color(1.0, 0.75, 0.2))
			draw_circle(c + Vector2(0, s * 0.06 + wob), s * 0.3, fire)
			draw_circle(c + Vector2(0, s * 0.08 + wob), s * 0.2, Color(1.0, 0.82, 0.3))
		"planet":
			var skin := Color(0.55, 0.25, 0.7)
			for i in 3:
				var x2: float = c.x + (i - 1) * s * 0.17
				draw_line(Vector2(x2, c.y + s * 0.2), Vector2(x2 + sin(_t * 3.0 + i) * s * 0.05, c.y + s * 0.4), skin.darkened(0.2), s * 0.07)
			draw_circle(c + Vector2(0, wob), s * 0.3, skin)
			draw_circle(c + Vector2(0, -s * 0.08 + wob), s * 0.07, Color(1.0, 0.95, 0.4))
		_:
			var rock := Color(0.5, 0.42, 0.36)
			var pts := PackedVector2Array()
			for i in 10:
				var ang := TAU * i / 10.0
				var rr: float = s * (0.3 + 0.04 * sin(i * 2.3))
				pts.append(c + Vector2(cos(ang) * rr, sin(ang) * rr * 0.9 + wob))
			draw_colored_polygon(pts, rock)
			draw_circle(c + Vector2(s * 0.1, s * 0.1), s * 0.06, rock.darkened(0.25))
			draw_circle(c + Vector2(-s * 0.14, s * 0.14), s * 0.04, rock.darkened(0.25))
	# yeux en colère (communs à tous)
	var eye_y := c.y - s * 0.02 + wob
	for sx in [-1.0, 1.0]:
		var ex: float = c.x + sx * s * 0.11
		draw_circle(Vector2(ex, eye_y), s * 0.06, Color(1, 1, 1))
		draw_circle(Vector2(ex + sx * s * 0.01, eye_y + s * 0.01), s * 0.03, Color(0.1, 0.1, 0.15))
		draw_line(Vector2(ex - sx * s * 0.07, eye_y - s * 0.1), Vector2(ex + sx * s * 0.06, eye_y - s * 0.05), OUTLINE, 3.0)
	draw_arc(Vector2(c.x, c.y + s * 0.13 + wob), s * 0.07, PI * 1.15, PI * 1.85, 8, OUTLINE, 2.5)
