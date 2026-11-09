class_name EnemyArt
extends RefCounted
## Ennemis de la refonte (maquettes TA à TL) : des créatures de verre facettées, vues de face.
## Même contrat que l'ancien dessin : `draw(ci, kind, p)` avec t, atk, cast, hurt, dead, stun, move ;
## en plus `pal` (teinte du chapitre ou du secteur), `phase2`, `elite`, `gold` (Gardien du dernier seuil).
## Repère : le sol est à y = 0, les pieds de l'ennemi en (0, 0), le dessin monte vers les y négatifs.

const Data = preload("res://scripts/data.gd")

const OUT := Color(0.03, 0.04, 0.11)
const DEEP := Color(0.02, 0.03, 0.08)

## Teintes par chapitre : le verre vire avec l'histoire.
const PALS := {
	2: {"base": Color("4a8fc8"), "acc": Color("4fd8ff"), "core": Color("d4f8ff"), "eye": Color("ff4d4d")},
	3: {"base": Color("8468d0"), "acc": Color("b388ff"), "core": Color("f0e4ff"), "eye": Color("ff5a8a")},
	4: {"base": Color("c4863a"), "acc": Color("ffb142"), "core": Color("fff0c8"), "eye": Color("ff5a3a")},
	5: {"base": Color("d6ad3c"), "acc": Color("ffd166"), "core": Color("ffffff"), "eye": Color("ffffff")},
}


## Teinte d'un étage : chapitres 2 à 5 pour l'histoire, palette du secteur pour les secteurs générés.
static func palette_for(stage: int) -> Dictionary:
	if stage > Data.LAST_STORY_BOSS:
		var pal: Array = Sector.info(stage).get("palette", [])
		if pal.size() >= 8:
			var acc := Color(pal[6])
			return {"base": Color(pal[7]).lerp(Color("4a8fc8"), 0.3).lightened(0.12), "acc": acc, "core": acc.lerp(Color.WHITE, 0.75), "eye": Color("ff4d4d")}
		return PALS[5]
	return PALS[clampi(Data.chapter_of(stage) + 1, 2, 5)]


# ---------------------------------------------------------------- outils de dessin

static func _lite(c: Color, k: float) -> Color:
	return c.lerp(Color.WHITE, k)


static func _dark(c: Color, k: float) -> Color:
	return c.lerp(DEEP, k)


## Teinte d'un plan selon son orientation vers la lumière (haut-gauche) : -2 très clair … 3 très sombre.
static func _sh(c: Color, k: int) -> Color:
	match k:
		-2:
			return _lite(c, 0.55)
		-1:
			return _lite(c, 0.3)
		0:
			return c
		1:
			return _dark(c, 0.22)
		2:
			return _dark(c, 0.42)
	return _dark(c, 0.6)


## Points {x, y} d'un tracé en repère de maquette -> repère du jeu (origine `o`, échelle `s`, décalage `off`).
static func _m(arr: Array, o: Vector2, s: float, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in arr:
		out.append((Vector2(q[0], q[1]) - o) * s + off)
	return out


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, w := 2.0) -> void:
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(_closed(pts), OUT, w, true)


static func _flat(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)


static func _facets(ci: CanvasItem, perim: PackedVector2Array, center: Vector2, ks: Array, base: Color, w := 2.0) -> void:
	var n := perim.size()
	for i in n:
		ci.draw_colored_polygon(PackedVector2Array([perim[i], perim[(i + 1) % n], center]), _sh(base, int(ks[i % ks.size()])))
	ci.draw_polyline(_closed(perim), OUT, w, true)


static func _glow(ci: CanvasItem, c: Vector2, r: float, col: Color, a := 0.5) -> void:
	for i in 6:
		var k := 1.0 - i * 0.15
		ci.draw_circle(c, r * k, Color(col, a * 0.07 * (i + 1)))


static func _eye(ci: CanvasItem, c: Vector2, r: float, col: Color, hl := true) -> void:
	ci.draw_circle(c, r * 1.35, Color(0.04, 0.04, 0.08))
	_glow(ci, c, r * 2.4, col, 0.6)
	ci.draw_circle(c, r, col)
	if hl:
		ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.32, Color(1, 1, 1, 0.9))


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, OUT, w + 2.5, true)
	ci.draw_line(a, b, col, w, true)


static func _ring_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, col: Color, w: float, front: bool) -> void:
	var pts := PackedVector2Array()
	var a0 := 0.0 if front else PI
	for i in 25:
		var a := a0 + PI * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	ci.draw_polyline(pts, col, w, true)


# ---------------------------------------------------------------- point d'entrée

static func draw(ci: CanvasItem, kind: String, p: Dictionary) -> void:
	var t: float = p.get("t", 0.0)
	var atk: float = p.get("atk", 0.0)
	var cast: float = p.get("cast", 0.0)
	var dead: float = p.get("dead", 0.0)
	var stun: bool = p.get("stun", false)
	var pal: Dictionary = p.get("pal", PALS[2])
	var wind := Art._wind(atk)
	var hit := Art._strike(atk)
	var big := kind in ["titan", "foreur", "sentinelle", "reine"]
	# `origin` et `scale` : dessin hors combat (scènes d'histoire) ; en combat, c'est le nœud du combattant qui place et agrandit
	var org: Vector2 = p.get("origin", Vector2.ZERO)
	var sc: float = p.get("scale", 1.0)
	ci.draw_set_transform(org + Vector2(0, -dead * 6.0) * sc, dead * -0.6, Vector2(1.0 + dead * 0.3, 1.0 - dead * 0.7) * sc)
	var air := cast * 34.0 if big else 0.0
	Art.ellipse(ci, Vector2(0, 2), 30.0 * (1.0 - air * 0.008), 8.0 * (1.0 - air * 0.008), Color(0, 0, 0, 0.3))
	if bool(p.get("elite", false)):
		# marque d'élite : anneau doré au sol
		var k := 0.6 + 0.4 * sin(t * 3.0)
		_ring_ellipse(ci, Vector2(0, 3), 40.0 if not big else 62.0, 10.0 if not big else 15.0, 0.0, Color(1.0, 0.82, 0.4, 0.5 + 0.4 * k), 3.0, true)
		_ring_ellipse(ci, Vector2(0, 3), 40.0 if not big else 62.0, 10.0 if not big else 15.0, 0.0, Color(1.0, 0.82, 0.4, 0.35), 3.0, false)
	match kind:
		"mite":
			_mite(ci, p, pal, t, wind, hit)
		"drone", "gunner":
			_drone(ci, p, pal, t, wind, hit, kind == "gunner")
		"foreur":
			_foreur(ci, p, pal, t, wind, hit, cast, air)
		"titan":
			_gardien(ci, p, pal, t, wind, hit, air)
		"sentinelle":
			_sentinelle(ci, p, pal, t, wind, hit, air)
		"reine":
			_reine(ci, p, pal, t, wind, hit, air)
		_:
			_foreur(ci, p, pal, t, wind, hit, cast, air)
	Art.shatter(ci, Vector2(0, -50 if not big else -70), Color(pal.acc).lerp(Color.WHITE, 0.2), dead)
	if stun:
		for k in 3:
			var a := t * 4.0 + k * TAU / 3.0
			Art.star(ci, Vector2(cos(a) * 26, (-150.0 if big else -110.0) + sin(a) * 6), 5, Color(1, 0.9, 0.3))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- mite de verre

static func _mite(ci: CanvasItem, p: Dictionary, pal: Dictionary, t: float, wind: float, hit: float) -> void:
	var b: Color = pal.base
	var scut: float = 1.0 + float(p.get("move", 0.0)) * 2.0
	var bob := absf(sin(t * 6.0 * scut)) * 3.0 - wind * 3.0
	var y0 := -19.0 - bob + wind * 3.0
	# pattes articulées : chaque patte lève et pose le pied en décalé
	for s in [-1, 1]:
		for k in 3:
			var ph: float = t * 9.0 * scut + k * 2.1 + (0.0 if s < 0 else PI)
			var hip := Vector2(s * 14, y0 + 6)
			var foot := Vector2(s * (30 + k * 8) + cos(ph) * 4.0, -2 - k * 3 - maxf(0.0, sin(ph)) * 6.0)
			var knee := (hip + foot) * 0.5 + Vector2(s * 6, -10)
			ci.draw_line(hip, knee, OUT, 5, true)
			ci.draw_line(knee, foot, OUT, 5, true)
			ci.draw_line(hip, knee, _dark(b, 0.35), 2.6, true)
			ci.draw_line(knee, foot, _dark(b, 0.35), 2.6, true)
	# carapace de verre à plans
	var perim := PackedVector2Array([Vector2(-30, 5), Vector2(-22, -12), Vector2(-3, -20), Vector2(20, -14), Vector2(30, 5), Vector2(18, 14), Vector2(-18, 14)])
	for i in perim.size():
		perim[i] += Vector2(0, y0)
	_facets(ci, perim, Vector2(0, y0), [0, -1, -2, -1, 1, 2, 1], b)
	# le cœur bat à travers le verre
	var beat := 1.0 + 0.18 * sin(t * 5.0) + wind * 0.4
	_glow(ci, Vector2(0, y0 - 2), 18.0 * beat, pal.acc, 0.8)
	ci.draw_circle(Vector2(0, y0 - 2), 4.6 * beat, pal.core)
	_flat(ci, PackedVector2Array([Vector2(-22, y0 - 11), Vector2(-4, y0 - 19), Vector2(-9, y0 - 9)]), Color(1, 1, 1, 0.35))
	# mandibules : grandes ouvertes à la préparation, claquent à la frappe
	var open := wind + 0.15
	if hit > 0.0 and atk_hit(p):
		open = 0.15
	for s in [-1, 1]:
		Art._claw(ci, Vector2(s * 11, y0 + 14 + hit * 4.0), s, open, Color(0.91, 0.86, 0.75))
	var ey := 3.2 + wind * 1.2
	_eye(ci, Vector2(-8, y0 + 7), ey, pal.eye)
	_eye(ci, Vector2(8, y0 + 7), ey, pal.eye)


static func atk_hit(p: Dictionary) -> bool:
	return float(p.get("atk", 0.0)) > 0.3


# ---------------------------------------------------------------- drone foreur et canonnier

static func _drone(ci: CanvasItem, p: Dictionary, pal: Dictionary, t: float, wind: float, hit: float, gun: bool) -> void:
	var hover := sin(t * 2.6) * 5.0 + wind * 6.0 - hit * 4.0
	var wob := sin(t * 40.0) * float(p.get("hurt", 0.0)) * 3.0
	var body := Color("56628c") if not gun else Color("9a4a52")
	var cy := -62.0 + hover
	# réacteur : la flamme grandit à la préparation
	var fl := 8.0 + sin(t * 30.0) * 3.0 + wind * 8.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-9 + wob, cy + 22), Vector2(9 + wob, cy + 22), Vector2(wob, cy + 22 + fl * 2.0)]), Color(1.0, 0.6, 0.2, 0.85))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-5 + wob, cy + 22), Vector2(5 + wob, cy + 22), Vector2(wob, cy + 22 + fl)]), Color(1.0, 0.95, 0.6, 0.9))
	# hélice : fines ellipses qui oscillent, antennes à voyants
	var rw := 40.0 + 6.0 * absf(cos(t * 28.0))
	Art.ellipse(ci, Vector2(wob, cy - 32), rw, 5.0, Color(0.7, 0.75, 0.85, 0.3))
	Art.ellipse(ci, Vector2(wob, cy - 32), rw * 0.7, 3.0, Color(0.86, 0.9, 1.0, 0.4))
	ci.draw_line(Vector2(wob, cy - 32), Vector2(wob, cy - 20), OUT, 4, true)
	for s in [-1, 1]:
		_line(ci, Vector2(s * 20 + wob, cy - 18), Vector2(s * 26 + wob, cy - 32), Color(0.4, 0.42, 0.55), 2.2)
		ci.draw_circle(Vector2(s * 26 + wob, cy - 33), 3.2, Color(1.0, 0.8, 0.25))
	# corps hexagonal à plans
	var perim := PackedVector2Array([Vector2(-30, -19), Vector2(30, -19), Vector2(42, 0), Vector2(30, 19), Vector2(-30, 19), Vector2(-42, 0)])
	for i in perim.size():
		perim[i] += Vector2(wob, cy)
	_facets(ci, perim, Vector2(wob, cy), [-1, -1, 0, 2, 2, 1], body)
	for s in [-1, 1]:
		_flat(ci, PackedVector2Array([Vector2(s * 34 + wob, cy - 8), Vector2(s * 40 + wob, cy), Vector2(s * 34 + wob, cy + 8)]), Color(pal.acc, 0.6))
	# lentille : l'œil se charge avant le tir
	ci.draw_circle(Vector2(wob, cy + 2), 15.5, Color(0.04, 0.04, 0.08))
	ci.draw_circle(Vector2(wob, cy + 2), 13.5, Color(0.16, 0.19, 0.31))
	var ec: Color = Color(pal.eye).lerp(Color(1.0, 0.85, 0.55), wind * 0.6)
	_eye(ci, Vector2(wob, cy + 2), 9.0 + wind * 2.5, ec)
	if gun:
		# canons jumelés tournés vers l'escouade, ils reculent à chaque tir
		for s in [-1, 1]:
			var c := Vector2(s * 36 + wob, cy + 16 + hit * 3.0)
			ci.draw_circle(c, 9.5 - hit * 1.5, Color(0.16, 0.14, 0.19))
			ci.draw_arc(c, 9.5, 0, TAU, 14, OUT, 2.0, true)
			ci.draw_circle(c, 5.5, Color(0.04, 0.04, 0.08))
			_glow(ci, c, 11.0 + wind * 6.0, Color(1.0, 0.6, 0.22), 0.5 + wind * 0.4)
		# sangle de danger
		_poly(ci, PackedVector2Array([Vector2(-30 + wob, cy + 19), Vector2(30 + wob, cy + 19), Vector2(26 + wob, cy + 25), Vector2(-26 + wob, cy + 25)]), Color(1.0, 0.78, 0.29), 1.6)
		if hit > 0.6:
			var fk := (hit - 0.5) / 0.5
			for s in [-1, 1]:
				var mz := Vector2(s * 36, cy + 16)
				ci.draw_colored_polygon(PackedVector2Array([mz + Vector2(-6, 0), mz + Vector2(0, 26 * fk), mz + Vector2(6, 0)]), Color(1.0, 0.6, 0.3, 0.9))
				Art.star(ci, mz, 13.0 * fk, Color(1, 0.9, 0.6), t * 9.0)
	else:
		# deux forets sous le corps
		for s in [-1, 1]:
			var cx: float = s * 27 + wob
			var tip := cy + 38 + wind * 4.0 + hit * 6.0
			_poly(ci, PackedVector2Array([Vector2(cx - 6, cy + 19), Vector2(cx + 6, cy + 19), Vector2(cx, tip)]), Color(0.81, 0.84, 0.92), 1.6)
			ci.draw_line(Vector2(cx - 4, cy + 25), Vector2(cx + 4, cy + 25), OUT, 1.5)
			ci.draw_line(Vector2(cx - 3, cy + 31), Vector2(cx + 3, cy + 31), OUT, 1.5)


# ---------------------------------------------------------------- Foreur éclaté (mini-boss)

static func _foreur(ci: CanvasItem, p: Dictionary, pal: Dictionary, t: float, wind: float, hit: float, cast: float, air: float) -> void:
	var b := Color("7a5a46")
	var a: Color = pal.acc
	var stomp := maxf(0.0, sin(t * 2.0))
	var crouch := wind * 9.0
	var sy := 1.0 - 0.03 * stomp - wind * 0.08 + hit * 0.04
	var by := -air + crouch * 0.5
	var shake := sin(t * 30.0) * 1.2 + sin(t * 50.0) * float(p.get("hurt", 0.0)) * 3.0
	var oy := shake + by + crouch
	# chenilles
	for s in [-1, 1]:
		var lift := maxf(0.0, sin(t * 2.0 + (0.0 if s < 0 else PI))) * 4.0
		var r := Rect2(s * 50 - 17, -26 - lift + by * 0.2, 34, 26)
		_poly(ci, PackedVector2Array([r.position + Vector2(5, 0), r.position + Vector2(29, 0), r.position + Vector2(34, 6), r.position + Vector2(34, 20), r.position + Vector2(29, 26), r.position + Vector2(5, 26), r.position + Vector2(0, 20), r.position + Vector2(0, 6)]), Color(0.17, 0.18, 0.27), 2.0)
		for k in 3:
			ci.draw_line(r.position + Vector2(8 + k * 9, 4), r.position + Vector2(8 + k * 9, 22), Color(0.09, 0.1, 0.17), 2.0)
	# coque
	var top := -118.0 * sy
	var perim := PackedVector2Array([Vector2(-40, top + 2), Vector2(40, top + 2), Vector2(58, top + 22), Vector2(54, -26), Vector2(-54, -26), Vector2(-58, top + 22)])
	for i in perim.size():
		perim[i] += Vector2(0, oy)
	_facets(ci, perim, Vector2(0, oy - 74), [-1, -1, 0, 2, 2, 1], b, 2.4)
	_poly(ci, PackedVector2Array([Vector2(-56, -72 + oy), Vector2(56, -72 + oy), Vector2(54, -62 + oy), Vector2(-54, -62 + oy)]), Color(0.88, 0.64, 0.29), 1.8)
	# cristaux qui percent la coque
	for q in [[-36, 30, 8], [-18, 42, 10], [18, 38, 10], [38, 26, 7], [0, 24, 7]]:
		var cx: float = q[0]
		var hh: float = float(q[1]) + sin(t * 2.0 + cx) * 2.0
		var ww: float = q[2]
		_poly(ci, PackedVector2Array([Vector2(cx - ww, top + 4 + oy), Vector2(cx, top - hh + oy), Vector2(cx + ww, top + 4 + oy)]), _lite(a, 0.15), 1.8)
		_flat(ci, PackedVector2Array([Vector2(cx - ww, top + 4 + oy), Vector2(cx, top - hh + oy), Vector2(cx, top + 4 + oy)]), Color(1, 1, 1, 0.35))
	_glow(ci, Vector2(0, -76 + oy), 62.0, a, 0.3)
	# veines lumineuses
	for s in [-1, 1]:
		ci.draw_polyline(PackedVector2Array([Vector2(s * 54, -96 + oy), Vector2(s * 38, -90 + oy), Vector2(s * 44, -76 + oy)]), Color(a, 0.9), 2.0, true)
	# trois yeux
	for k in 3:
		var ex := -30.0 + k * 30.0
		var glow := 0.25 + 0.1 * sin(t * 3.0 + k) + wind * 0.5
		var ec: Color = Color(pal.eye).lerp(Color(1.0, 0.7, 0.3), clampf(glow, 0.0, 1.0) * 0.5)
		_eye(ci, Vector2(ex, -92 + oy), 5.5 + wind * 2.0, ec, false)
	# foreuse : tourne en permanence, s'enfonce à la frappe
	var spin := 1.0 + wind * 2.0
	var tip := 8.0 + hit * 22.0 - wind * 10.0
	_poly(ci, PackedVector2Array([Vector2(-26, -56 + oy), Vector2(26, -56 + oy), Vector2(0, tip + oy)]), Color(0.81, 0.84, 0.92), 2.2)
	_flat(ci, PackedVector2Array([Vector2(-26, -56 + oy), Vector2(0, -56 + oy), Vector2(0, tip + oy)]), Color(1, 1, 1, 0.22))
	for k in 5:
		var f := fposmod(t * 1.2 * spin + k * 0.2, 1.0)
		var yy := lerpf(-52.0, tip - 12.0, f) + oy
		var half := 21.0 * (1.0 - f) * 0.95
		ci.draw_line(Vector2(-half, yy), Vector2(half, yy), Color(0.29, 0.31, 0.44), 3)
	_glow(ci, Vector2(0, tip + oy - 4), 12.0 + hit * 10.0, a, 0.7)
	# gyrophare
	ci.draw_line(Vector2(0, top + oy), Vector2(sin(t * 2.0) * 4.0, top - 22 + oy), OUT, 5)
	var bl := 0.6 + 0.4 * sin(t * 6.0)
	_glow(ci, Vector2(sin(t * 2.0) * 4.0, top - 24 + oy), 14.0, Color(1.0, 0.54, 0.23), bl)
	ci.draw_circle(Vector2(sin(t * 2.0) * 4.0, top - 24 + oy), 5.0, Color(1.0, 0.54, 0.23))
	if air > 0.0 or (float(p.get("cast", 0.0)) > 0.0 and float(p.get("cast", 0.0)) < 0.15):
		for s in [-1, 1]:
			Art.shard(ci, Vector2(s * 70, -4), 12, -PI * 0.5 + s * 0.8, Color(0.6, 0.55, 0.5, 0.7))


# ---------------------------------------------------------------- Gardien de verre (et Gardien du dernier seuil)

static func _gardien(ci: CanvasItem, p: Dictionary, pal: Dictionary, t: float, wind: float, hit: float, air: float) -> void:
	var b: Color = pal.base
	var a: Color = pal.acc
	var gold: bool = bool(p.get("gold", false))
	var ph2: bool = bool(p.get("phase2", false))
	var core: Color = Color("ff5a4a") if ph2 else Color(pal.core)
	var O := Vector2(150, 312)
	var S := 0.5
	var bob := sin(t * 2.0) * 1.2
	var off := Vector2(0, bob - air + wind * 4.0)
	var lift := wind * 70.0 - hit * 6.0            # les poings se lèvent avant l'Écrasement, retombent à la frappe
	_glow(ci, _m([[150, 150]], O, S, off)[0], 74.0, Color("ff5a4a") if ph2 else a, 0.2 if not gold else 0.34)
	# jambes
	for sd in [-1, 1]:
		var x: float = 150.0 + sd * 38.0
		_poly(ci, _m([[x - 30, 230], [x + 30, 230], [x + 26, 312], [x - 26, 312]], O, S, Vector2(0, 0)), _sh(b, 2 if sd < 0 else 3))
		_flat(ci, _m([[x - 30, 230], [x - 8, 230], [x - 8, 312], [x - 26, 312]], O, S), Color(1, 1, 1, 0.12))
	# bras massifs et poings de cristal
	for sd in [-1, 1]:
		var lo := Vector2(0, -lift * 0.9 + (0.0 if sd < 0 else sin(t * 2.0) * 0.0))
		var P := [[150 + sd * 118, 108], [150 + sd * 160, 130], [150 + sd * 150, 236], [150 + sd * 118, 262], [150 + sd * 92, 214], [150 + sd * 98, 124]]
		var arm := _m(P, O, S, off + lo * S)
		_poly(ci, arm, _sh(b, 1 if sd < 0 else 2))
		_flat(ci, PackedVector2Array([arm[0], arm[1], arm[2]]) if sd < 0 else PackedVector2Array([arm[0], arm[5], arm[4]]), Color(1, 1, 1, 0.1))
		_poly(ci, _m([[150 + sd * 112, 250], [150 + sd * 152, 244], [150 + sd * 160, 290], [150 + sd * 130, 308], [150 + sd * 100, 290]], O, S, off + lo * S), _sh(b, 3))
	# torse
	var perim := _m([[70, 96], [230, 96], [214, 224], [150, 246], [86, 224]], O, S, off)
	_facets(ci, perim, _m([[150, 160]], O, S, off)[0], [-1, -2, 1, 2, 1], b, 2.2)
	# épaules cristallines
	for sd in [-1, 1]:
		_poly(ci, _m([[150 + sd * 112, 100], [150 + sd * 150, 70], [150 + sd * 138, 118]], O, S, off), _lite(a, 0.2), 1.8)
		_poly(ci, _m([[150 + sd * 84, 94], [150 + sd * 100, 46], [150 + sd * 116, 98]], O, S, off), _lite(a, 0.3), 1.8)
	# noyau : la cible
	var pulse := 1.0 + 0.12 * sin(t * (6.0 if ph2 else 3.0)) + wind * 0.3
	var cc := _m([[150, 160]], O, S, off)[0]
	_glow(ci, cc, 36.0 * pulse, core, 0.8)
	_poly(ci, _m([[150, 128], [176, 160], [150, 196], [124, 160]], O, S, off), _lite(core, 0.1), 1.8)
	_flat(ci, _m([[150, 128], [150, 196], [124, 160]], O, S, off), Color(1, 1, 1, 0.5))
	# tête
	_poly(ci, _m([[116, 90], [184, 90], [194, 54], [150, 30], [106, 54]], O, S, off), _sh(b, -1), 2.0)
	_flat(ci, _m([[106, 54], [150, 30], [150, 90], [116, 90]], O, S, off), Color(1, 1, 1, 0.22))
	var ec: Color = Color(pal.eye)
	if ph2:
		ec = Color("ff7a5a")
	for sd in [-1, 1]:
		var slit := _m([[150 + sd * 14, 60], [150 + sd * 34, 66], [150 + sd * 30, 74], [150 + sd * 12, 70]], O, S, off)
		ci.draw_colored_polygon(slit, Color(0.04, 0.04, 0.08))
		_flat(ci, _m([[150 + sd * 16, 62], [150 + sd * 30, 66], [150 + sd * 28, 70], [150 + sd * 15, 67]], O, S, off), ec)
	if gold:
		# couronne et halo : le Gardien du dernier seuil
		var hc := _m([[150, 40]], O, S, off)[0]
		_ring_ellipse(ci, hc, 36.0, 7.0, 0.0, Color(a, 0.95), 2.5, true)
		_ring_ellipse(ci, hc, 36.0, 7.0, 0.0, Color(a, 0.5), 2.5, false)
		for i in 5:
			var x: float = 110.0 + i * 20.0
			var hh: float = 30.0 if i == 2 else 20.0
			_poly(ci, _m([[x - 8, 40], [x, 40 - hh], [x + 8, 40]], O, S, off), Color("ffe28a"), 1.6)
	if ph2:
		# fissures qui s'ouvrent dans le torse et la tête
		for P in [[[110, 120], [126, 150], [112, 176], [128, 214]], [[200, 112], [182, 140], [194, 170]], [[142, 36], [150, 60], [146, 82]]]:
			var pl := _m(P, O, S, off)
			ci.draw_polyline(pl, Color("ffb09a"), 2.6, true)
			ci.draw_polyline(pl, Color("ff5a4a"), 1.3, true)


# ---------------------------------------------------------------- Sentinelle prismatique

static func _sentinelle(ci: CanvasItem, p: Dictionary, pal: Dictionary, t: float, wind: float, hit: float, air: float) -> void:
	var b: Color = pal.base
	var a: Color = pal.acc
	var ph2: bool = bool(p.get("phase2", false))
	var O := Vector2(150, 296)
	var S := 0.55
	var hover := sin(t * 2.2) * 5.0 - air * 0.4
	var off := Vector2(0, -34.0 + hover)
	var ctr := _m([[150, 150]], O, S, off)[0]
	_glow(ci, ctr, 76.0, a, 0.22)
	# anneau (moitié arrière)
	var rot := -0.245
	_ring_ellipse(ci, ctr, 122.0 * S, 26.0 * S, rot, Color(a, 0.5), 3.0, false)
	# prisme : octaèdre allongé
	var top := [150, 16]
	var L := [88, 138]
	var R := [212, 138]
	var F := [150, 150]
	var bot := [150, 296]
	var back := [150, 120]
	_poly(ci, _m([top, L, back], O, S, off), _sh(b, 2), 2.2)
	_poly(ci, _m([top, back, R], O, S, off), _sh(b, 3), 2.2)
	_poly(ci, _m([top, L, F], O, S, off), _sh(b, -2), 2.2)
	_poly(ci, _m([top, F, R], O, S, off), _sh(b, 0), 2.2)
	_poly(ci, _m([L, F, bot], O, S, off), _sh(b, 1), 2.2)
	_poly(ci, _m([F, R, bot], O, S, off), _sh(b, 2), 2.2)
	# reflets arc-en-ciel : elle réfracte les voix qu'elle porte
	var sh := 0.5 + 0.5 * sin(t * 1.5)
	_flat(ci, _m([[150, 34], [108, 124], [150, 138]], O, S, off), Color(0.48, 1.0, 0.85, 0.15 + 0.15 * sh))
	_flat(ci, _m([[150, 138], [198, 128], [160, 210]], O, S, off), Color(1.0, 0.54, 0.85, 0.22))
	_flat(ci, _m([[116, 150], [150, 160], [140, 240]], O, S, off), Color(0.54, 0.66, 1.0, 0.25))
	# œil central : la cible
	var ey := _m([[150, 140]], O, S, off)[0]
	ci.draw_circle(ey, 16.0, Color(0.04, 0.04, 0.08))
	ci.draw_circle(ey, 13.5, _lite(a, 0.2))
	ci.draw_arc(ey, 9.0, 0, TAU, 18, Color(1.0, 0.54, 0.85, 0.9), 1.8, true)
	_eye(ci, ey, 6.0 + wind * 2.5, Color(1.0, 0.45, 0.65) if ph2 else Color(pal.eye))
	# éclats en orbite (6 en phase 2)
	var n := 6 if ph2 else 4
	for i in n:
		var an := t * (1.1 if ph2 else 0.8) + i * TAU / n
		var q := ctr + Vector2(cos(an) * 66.0, sin(an) * 15.0).rotated(rot)
		var sz := 7.0
		_poly(ci, PackedVector2Array([q + Vector2(0, -sz * 1.6), q + Vector2(sz * 0.7, 0), q + Vector2(0, sz * 1.6), q + Vector2(-sz * 0.7, 0)]), _lite(a, 0.25), 1.6)
	# anneau (moitié avant)
	_ring_ellipse(ci, ctr, 122.0 * S, 26.0 * S, rot, Color(a, 0.95), 3.0, true)
	# la pointe se charge, puis le rayon part vers le bas
	var tipc := _m([[150, 296]], O, S, off)[0]
	var charge := wind
	_glow(ci, tipc, 20.0 + charge * 18.0, Color(1.0, 0.54, 0.85) if ph2 else a, 0.9)
	ci.draw_circle(tipc, 3.4, Color(1, 1, 1, 0.9))
	if hit > 0.2 or ph2 and charge > 0.0:
		var k := maxf(hit, 0.5 if ph2 else 0.0)
		ci.draw_line(tipc, tipc + Vector2(0, 90.0 * k), Color(1.0, 0.54, 0.85, 0.65), 6.0 * k, true)
		ci.draw_line(tipc, tipc + Vector2(0, 90.0 * k), Color(1, 1, 1, 0.8), 2.0 * k, true)


# ---------------------------------------------------------------- Reine des mites

static func _reine(ci: CanvasItem, p: Dictionary, pal: Dictionary, t: float, wind: float, hit: float, air: float) -> void:
	var b: Color = pal.base
	var a: Color = pal.acc
	var ph2: bool = bool(p.get("phase2", false))
	var O := Vector2(160, 288)
	var S := 0.42
	var bob := absf(sin(t * 2.6)) * 2.0 - air * 0.3
	var off := Vector2(0, bob)
	var scut: float = 1.0 + float(p.get("move", 0.0)) * 2.0
	# ailes de verre ambré : battent à l'appel des mites
	var flap := sin(t * (14.0 if wind > 0.2 else 3.0)) * (0.16 + wind * 0.2) - wind * 0.35
	for sd in [-1, 1]:
		var root := Vector2(160 + sd * 30, 150)
		var P := [[160 + sd * 30, 150], [160 + sd * 150, 30], [160 + sd * 156, 118], [160 + sd * 110, 190]]
		var pts := PackedVector2Array()
		for q in P:
			pts.append((root + (Vector2(q[0], q[1]) - root).rotated(flap * sd) - O) * S + off)
		ci.draw_colored_polygon(pts, Color(_lite(a, 0.1), 0.55))
		ci.draw_polyline(_closed(pts), OUT, 2.0, true)
		_flat(ci, PackedVector2Array([pts[0], pts[1], pts[2]]), Color(1, 1, 1, 0.18))
		ci.draw_line(pts[0], (root + (Vector2(160 + sd * 110, 100) - root).rotated(flap * sd) - O) * S + off, _dark(b, 0.2), 1.4, true)
	# pattes
	for sd in [-1, 1]:
		for k in 3:
			var dx: float = float([70, 92, 110][k])
			var ph: float = t * 9.0 * scut + k * 2.1 + (0.0 if sd < 0 else PI)
			var foot_x: float = 160.0 + sd * (dx + 40.0) + cos(ph) * 10.0 * scut * 0.5
			var P := [[160 + sd * 40, 196 + k * 8], [160 + sd * (dx + 20), 190 + k * 16], [foot_x, 286 - maxf(0.0, sin(ph)) * 10.0]]
			var pl := _m(P, O, S, off)
			ci.draw_polyline(pl, OUT, 4.6, true)
			ci.draw_polyline(pl, _dark(b, 0.3), 2.4, true)
	# abdomen et couvée
	_poly(ci, _m([[110, 210], [210, 210], [200, 262], [160, 284], [120, 262]], O, S, off), _sh(b, 2), 2.0)
	var egg := 0.6 + 0.4 * sin(t * (6.0 if ph2 else 3.0)) + wind * 0.4
	for q in [[140, 240, 9], [168, 246, 8], [154, 264, 7], [186, 236, 6]]:
		var c := _m([[q[0], q[1]]], O, S, off)[0]
		_glow(ci, c, float(q[2]) * S * 2.6, a, 0.7 * egg)
		ci.draw_circle(c, float(q[2]) * S, Color(1.0, 0.94, 0.78))
		ci.draw_arc(c, float(q[2]) * S, 0, TAU, 10, OUT, 1.2, true)
	# thorax à plans
	var perim := _m([[84, 150], [108, 100], [160, 84], [212, 100], [236, 150], [212, 206], [108, 206]], O, S, off)
	_facets(ci, perim, _m([[160, 150]], O, S, off)[0], [-1, -2, -1, 0, 1, 2, 1], b, 2.0)
	var hc := _m([[160, 150]], O, S, off)[0]
	_glow(ci, hc, 25.0 * (1.0 + 0.1 * sin(t * 4.0)), a, 0.5)
	ci.draw_circle(hc, 5.4, pal.core)
	# tête, couronne dorée, quatre yeux
	_poly(ci, _m([[124, 116], [196, 116], [206, 82], [160, 62], [114, 82]], O, S, off), _sh(b, 0), 2.0)
	var xs := [124, 142, 160, 178, 196]
	var hs := [38, 54, 66, 54, 38]
	for i in 5:
		_poly(ci, _m([[xs[i] - 7, 80], [xs[i], 80 - hs[i]], [xs[i] + 7, 80]], O, S, off), Color("ffe28a"), 1.5)
	for e in [[136, 100], [184, 100], [148, 92], [172, 92]]:
		_eye(ci, _m([[e[0], e[1]]], O, S, off)[0], 2.4 + wind * 0.8, Color(pal.eye), false)
	var open := 0.15 + wind
	for sd in [-1, 1]:
		_poly(ci, _m([[160 + sd * 14, 118], [160 + sd * (40 + open * 8), 128], [160 + sd * 30, 168]], O, S, off + Vector2(0, hit * 3.0)), Color(0.94, 0.89, 0.77), 1.8)
