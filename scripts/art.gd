class_name Art
extends RefCounted
## Dessin 2D animé des héros et des ennemis, en formes vectorielles (aucune image) : tout bouge par paramètres.
## Origine = pieds du personnage, il regarde vers la droite (les ennemis sont retournés par le nœud).
## p : {t: temps, atk: 0..1 progression de l'attaque, cast: 0..1 pouvoir, hurt: 0..1, dead: 0..1, stun: bool}

const OUTLINE := Color(0.05, 0.07, 0.12)


const LIGHT := -2.3          # direction de la lumière (haut-gauche) pour les facettes


static func _fan(ci: CanvasItem, c: Vector2, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var mid := ((a + b) * 0.5 - c).angle()
		var k := 0.9 + 0.2 * cos(mid - LIGHT) + (0.04 if i % 2 == 0 else -0.04)
		ci.draw_colored_polygon(PackedVector2Array([c, a, b]), _shade(col, k))


## Disque low poly : quelques facettes éclairées depuis le haut-gauche.
static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, n: int = 7) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	if col.a < 0.99:
		n = 8
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n + 0.3
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	if col.a < 0.99:
		ci.draw_colored_polygon(pts, col)
	else:
		_fan(ci, c, pts, col)


static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ellipse(ci, c, r, r, col)


## Rectangle à pans coupés, facettes en éventail.
static func rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var k := minf(rad * 0.7, minf(r.size.x, r.size.y) * 0.45)
	var p := r.position
	var e := r.end
	var pts := PackedVector2Array([
		Vector2(p.x + k, p.y), Vector2(e.x - k, p.y), Vector2(e.x, p.y + k), Vector2(e.x, e.y - k),
		Vector2(e.x - k, e.y), Vector2(p.x + k, e.y), Vector2(p.x, e.y - k), Vector2(p.x, p.y + k),
	])
	if col.a < 0.99:
		ci.draw_colored_polygon(pts, col)
	else:
		_fan(ci, r.get_center() + Vector2(0, r.size.y * 0.08), pts, col)


static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * (w * 0.5)
	var o := n * (1.0 + 4.0 / w)
	ci.draw_colored_polygon(PackedVector2Array([a + o, b + o, b - o, a - o]), OUTLINE)
	ci.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), _shade(col, 0.82))
	ci.draw_colored_polygon(PackedVector2Array([a + n, b + n, b, a]), _shade(col, 1.12))
	disc(ci, a, w * 0.5, col)
	disc(ci, b, w * 0.5, col)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, rot: float = 0.0) -> void:
	if r < 0.8:
		return
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


static func shard(ci: CanvasItem, c: Vector2, r: float, rot: float, col: Color) -> void:
	if r < 0.8:
		return
	var pts := PackedVector2Array()
	for a in [0.0, 2.5, 3.8]:
		pts.append(c + Vector2(cos(rot + a), sin(rot + a)) * r * (1.0 if a == 0.0 else 0.55))
	ci.draw_colored_polygon(pts, col)


## Cristaux triangulaires qui tournent autour d'un héros qui lance un pouvoir.
static func aura(ci: CanvasItem, c: Vector2, k: float, t: float, col: Color) -> void:
	if k <= 0.0:
		return
	for i in 6:
		var a := t * 3.0 + i * TAU / 6.0
		var rr := 46.0 + k * 22.0 + sin(t * 5.0 + i) * 3.0
		shard(ci, c + Vector2(cos(a) * rr, sin(a) * rr * 0.55), 9.0 * k + 3.0, a * 2.0, Color(col.r, col.g, col.b, 0.85 * k))
	var ring := PackedVector2Array()
	for i in 6:
		var a := t * 1.5 + i * TAU / 6.0
		ring.append(Vector2(0, -2) + Vector2(cos(a) * (34.0 + k * 20.0), sin(a) * (9.0 + k * 5.0)))
	ci.draw_polyline(ring + PackedVector2Array([ring[0]]), Color(col.r, col.g, col.b, 0.8 * k), 3.0)


## Fragments qui s'éparpillent à la mort.
static func shatter(ci: CanvasItem, c: Vector2, col: Color, dead: float) -> void:
	if dead <= 0.0:
		return
	for i in 7:
		var a := i * 0.9 + 0.4
		var d := dead * (30.0 + (i % 3) * 14.0)
		shard(ci, c + Vector2(cos(a) * d, sin(a) * d * 0.7 - dead * 12.0), 11.0 * (1.0 - dead * 0.6), a + dead * 6.0, Color(col.r, col.g, col.b, 1.0 - dead))


static func _shade(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), c.a)


# ---------------------------------------------------------------- héros

static func draw_hero(ci: CanvasItem, h: Dictionary, p: Dictionary) -> void:
	var look: Dictionary = h.look
	var t: float = p.get("t", 0.0)
	var atk: float = p.get("atk", 0.0)
	var cast: float = p.get("cast", 0.0)
	var dead: float = p.get("dead", 0.0)
	var stun: bool = p.get("stun", false)
	var suit: Color = look.suit
	var accent: Color = look.accent
	var dark := _shade(suit, 0.62)
	var bob := sin(t * 2.2) * 2.2 + (sin(t * 11.0) * 1.5 if stun else 0.0)
	var breathe := sin(t * 2.2 + 0.6) * 1.2
	var lean := sin(PI * atk) * 6.0 + cast * -4.0
	var fall := dead
	ci.draw_set_transform(Vector2(0, -fall * 14.0), fall * 1.2, Vector2.ONE)
	# ombre
	ellipse(ci, Vector2(0, 2), 30.0 * (1.0 - fall * 0.4), 8.0, Color(0, 0, 0, 0.35))
	# sac à dos et jambes
	rrect(ci, Rect2(-37, -84 + bob, 18, 44), 6, dark)
	var step := sin(t * 2.2) * 1.0
	for s in [-1, 1]:
		var lx: float = s * 9.0
		rrect(ci, Rect2(lx - 8, -34, 16, 34), 6, _shade(suit, 0.8))
		rrect(ci, Rect2(lx - 9 + step * s * 0.0, -9, 22, 11), 5, dark)
	# bras arrière
	limb(ci, Vector2(-14 + lean * 0.3, -66 + bob), Vector2(-24 + lean * 0.2, -40 + bob * 0.5), 11, _shade(suit, 0.75))
	# torse
	rrect(ci, Rect2(-23 + lean * 0.4, -86 + bob + breathe * 0.3, 46, 58), 16, suit)
	rrect(ci, Rect2(-23 + lean * 0.4, -52 + bob, 46, 8), 3, accent)
	rrect(ci, Rect2(-10 + lean * 0.4, -78 + bob, 20, 14), 4, _shade(suit, 0.7))
	disc(ci, Vector2(-4 + lean * 0.4, -71 + bob), 2.2, accent)
	disc(ci, Vector2(4 + lean * 0.4, -71 + bob), 2.2, Color(1, 0.4, 0.4) if p.get("hurt", 0.0) > 0.0 else accent)
	# tête
	var hc := Vector2(2 + lean * 0.8, -112 + bob * 1.2 + breathe)
	_draw_head(ci, h, look, hc, t, atk, cast, stun)
	# bras avant + arme
	_draw_front_arm(ci, look, suit, accent, Vector2(16 + lean * 0.4, -68 + bob), atk, cast, t)
	aura(ci, Vector2(0, -70), cast, t, accent)
	shatter(ci, Vector2(0, -60), accent, fall)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_head(ci: CanvasItem, h: Dictionary, look: Dictionary, c: Vector2, t: float, atk: float, cast: float, stun: bool) -> void:
	var suit: Color = look.suit
	var accent: Color = look.accent
	var eye: Color = look.eye
	var blink := 1.0
	var ph := fmod(t + float(h.name.length()) * 0.37, 3.4)
	if ph < 0.14:
		blink = 0.1
	match String(h.species):
		"robot":
			rrect(ci, Rect2(c.x - 33, c.y - 33, 66, 62), 18, OUTLINE)
			rrect(ci, Rect2(c.x - 30, c.y - 30, 60, 56), 16, Color(0.72, 0.77, 0.86))
			rrect(ci, Rect2(c.x - 23, c.y - 20, 46, 32), 10, Color(0.06, 0.09, 0.14))
			var glow := Color(eye.r, eye.g, eye.b, 0.95)
			var ey := 5.0 * blink
			ellipse(ci, Vector2(c.x - 9, c.y - 4), 6, ey + 1.0, glow)
			ellipse(ci, Vector2(c.x + 9, c.y - 4), 6, ey + 1.0, glow)
			ci.draw_arc(Vector2(c.x, c.y + 4), 7, 0.3, PI - 0.3, 8, glow, 2.0)
			ci.draw_line(Vector2(c.x, c.y - 33), Vector2(c.x + 4, c.y - 46), OUTLINE, 3)
			disc(ci, Vector2(c.x + 4, c.y - 47), 4.5, accent)
			ellipse(ci, Vector2(c.x - 33, c.y), 5, 10, _shade(suit, 0.7))
			ellipse(ci, Vector2(c.x + 33, c.y), 5, 10, _shade(suit, 0.7))
		"alien":
			var skin: Color = look.skin
			ellipse(ci, c + Vector2(0, 2), 38, 35, OUTLINE)
			ellipse(ci, c + Vector2(0, 2), 36, 33, skin)
			# antennes
			for s in [-1, 1]:
				ci.draw_line(c + Vector2(s * 16, -28), c + Vector2(s * 26, -46 + sin(t * 3.0 + s) * 2), OUTLINE, 3)
				disc(ci, c + Vector2(s * 26, -46 + sin(t * 3.0 + s) * 2), 4.5, accent)
			# grands yeux
			for s in [-1, 1]:
				var ec := c + Vector2(s * 15 + 1, 2)
				ellipse(ci, ec, 11, 14 * blink + 1.0, Color(0.04, 0.04, 0.08), s * 0.35)
				ellipse(ci, ec + Vector2(-2, -3), 5, 6 * blink + 0.5, Color(eye.r, eye.g, eye.b, 1.0), s * 0.35)
				disc(ci, ec + Vector2(-4, -6), 2.2, Color(1, 1, 1, 0.9))
			ci.draw_arc(c + Vector2(0, 20), 7, 0.4, PI - 0.4, 8, _shade(skin, 0.6), 2.0)
			# bulle de casque
			disc(ci, c + Vector2(0, 2), 40, Color(0.7, 0.9, 1.0, 0.13))
			ci.draw_arc(c + Vector2(0, 2), 40, 0, TAU, 8, Color(accent.r, accent.g, accent.b, 0.8), 3.0)
			ci.draw_arc(c + Vector2(-4, -2), 33, PI * 1.1, PI * 1.45, 3, Color(1, 1, 1, 0.55), 3.0)
		_:
			# humain : casque, visière, visage, cheveux
			var skin: Color = look.skin
			var hair: Color = look.hair
			ellipse(ci, c, 37, 36, OUTLINE)
			ellipse(ci, c, 35, 34, _shade(suit, 1.12))
			ellipse(ci, c + Vector2(4, 2), 27, 24, Color(0.08, 0.14, 0.26))
			ellipse(ci, c + Vector2(5, 4), 20, 19, skin)
			# cheveux dans la visière
			var hc := Color(hair)
			match int(look.style):
				1:
					ellipse(ci, c + Vector2(4, -10), 21, 11, hc)
					ellipse(ci, c + Vector2(-12, 2), 7, 15, hc)
				2:
					ellipse(ci, c + Vector2(5, -11), 21, 10, hc)
					ellipse(ci, c + Vector2(-17, 12), 9, 9, hc)
					ellipse(ci, c + Vector2(-17, 12), 5, 5, _shade(hc, 1.4))
				_:
					for k in 5:
						star(ci, c + Vector2(-8 + k * 6, -13), 7, hc, -PI * 0.5)
			var ey := 4.2 * blink + 0.6
			ellipse(ci, c + Vector2(12, 3), 3.2, ey, eye)
			ellipse(ci, c + Vector2(0, 3), 3.2, ey, eye)
			ci.draw_arc(c + Vector2(7, 12), 4.5, 0.2, PI - 0.2, 6, _shade(skin, 0.55), 1.8)
			ci.draw_arc(c + Vector2(4, 2), 28, PI * 1.05, PI * 1.38, 3, Color(1, 1, 1, 0.5), 3.0)
			disc(ci, c + Vector2(-26, 8), 5, accent)
	if stun:
		for k in 3:
			var a := t * 4.0 + k * TAU / 3.0
			star(ci, c + Vector2(cos(a) * 30, -44 + sin(a) * 6), 5, Color(1, 0.9, 0.3))


static func _draw_front_arm(ci: CanvasItem, look: Dictionary, suit: Color, accent: Color, sh: Vector2, atk: float, cast: float, t: float) -> void:
	var weapon: String = look.weapon
	var recoil := sin(PI * atk) * (10.0 if weapon in ["blaster", "sniper"] else 22.0)
	var raise := cast * -26.0
	var arm := _shade(suit, 1.0)
	match weapon:
		"shield":
			var hand := sh + Vector2(22 + recoil, 12 + raise)
			limb(ci, sh, sh + Vector2(10, 14), 11, arm)
			var c := hand + Vector2(10, -4)
			ellipse(ci, c, 22, 30, OUTLINE)
			ellipse(ci, c, 19.5, 27.5, accent)
			ellipse(ci, c, 14, 21, _shade(suit, 0.9))
			star(ci, c, 9, accent, t)
			if cast > 0.0:
				ci.draw_arc(c, 36 + cast * 26.0, -1.2, 1.2, 5, Color(0.6, 0.9, 1.0, 0.8 * cast), 4.0)
		"blaster", "sniper":
			var length := 56.0 if weapon == "sniper" else 34.0
			var hand := sh + Vector2(26 - recoil * 0.6, 14 + raise)
			limb(ci, sh, hand, 11, arm)
			var gun_col := Color(0.2, 0.24, 0.32)
			rrect(ci, Rect2(hand.x - 8, hand.y - 8, length, 13), 4, OUTLINE)
			rrect(ci, Rect2(hand.x - 6, hand.y - 6, length - 4, 9), 3, gun_col)
			rrect(ci, Rect2(hand.x + length - 20, hand.y - 4, 10, 5), 2, accent)
			if weapon == "sniper":
				rrect(ci, Rect2(hand.x + 6, hand.y - 13, 16, 6), 3, gun_col)
			if atk > 0.05 and atk < 0.4:
				star(ci, hand + Vector2(length - 2, -2), 14.0 * (1.0 - atk * 1.4), Color(1.0, 0.85, 0.4), t * 8.0)
		"tablet":
			var hand := sh + Vector2(20, 6 + raise)
			limb(ci, sh, hand, 11, arm)
			rrect(ci, Rect2(hand.x - 4, hand.y - 22, 26, 32), 5, OUTLINE)
			rrect(ci, Rect2(hand.x - 2, hand.y - 20, 22, 28), 4, Color(0.05, 0.12, 0.16))
			ci.draw_line(Vector2(hand.x + 9, hand.y - 15), Vector2(hand.x + 9, hand.y + 3), accent, 3)
			ci.draw_line(Vector2(hand.x + 1, hand.y - 6), Vector2(hand.x + 17, hand.y - 6), accent, 3)
			if cast > 0.0 or atk > 0.1:
				ci.draw_arc(Vector2(hand.x + 9, hand.y - 6), 18 + 18 * maxf(cast, atk), 0, TAU, 6, Color(accent.r, accent.g, accent.b, 0.6), 3.0)
		_:
			var hand := sh + Vector2(18, 4 + raise - sin(PI * atk) * 6)
			limb(ci, sh, hand, 11, arm)
			var oc := hand + Vector2(10, -24 + sin(t * 3.0) * 3.0)
			disc(ci, oc, 15 + cast * 8, Color(accent.r, accent.g, accent.b, 0.25))
			disc(ci, oc, 10, accent)
			disc(ci, oc + Vector2(-3, -3), 3.4, Color(1, 1, 1, 0.9))
			if atk > 0.05 and atk < 0.5:
				ci.draw_arc(oc, 14 + atk * 30.0, 0, TAU, 6, Color(accent.r, accent.g, accent.b, 1.0 - atk * 2.0), 3.0)


# ---------------------------------------------------------------- ennemis

static func draw_enemy(ci: CanvasItem, kind: String, p: Dictionary) -> void:
	var t: float = p.get("t", 0.0)
	var atk: float = p.get("atk", 0.0)
	var dead: float = p.get("dead", 0.0)
	var stun: bool = p.get("stun", false)
	ci.draw_set_transform(Vector2(0, -dead * 10.0), dead * -1.0, Vector2.ONE)
	ellipse(ci, Vector2(0, 2), 28, 7, Color(0, 0, 0, 0.3))
	match kind:
		"mite":
			var bob := absf(sin(t * 6.0)) * 4.0
			for s in [-1, 1]:
				for k in 3:
					var x: float = s * (8 + k * 9)
					ci.draw_line(Vector2(x * 0.5, -14 - bob), Vector2(x + s * 6, 0), OUTLINE, 5)
			ellipse(ci, Vector2(0, -22 - bob), 25, 19, OUTLINE)
			ellipse(ci, Vector2(0, -22 - bob), 23, 17, Color(0.55, 0.42, 0.3))
			ellipse(ci, Vector2(-4, -27 - bob), 10, 5, Color(0.7, 0.58, 0.42))
			ellipse(ci, Vector2(13, -23 - bob), 5.5, 6, Color(1, 0.25, 0.2))
			ellipse(ci, Vector2(3, -23 - bob), 5.5, 6, Color(1, 0.25, 0.2))
			rrect(ci, Rect2(14 + sin(PI * atk) * 8.0, -16 - bob, 14, 8), 3, Color(0.85, 0.8, 0.7))
		"drone", "gunner":
			var hover := sin(t * 2.6) * 5.0
			var gun := kind == "gunner"
			var body := Color(0.38, 0.4, 0.5) if not gun else Color(0.5, 0.3, 0.3)
			# flamme
			var fl := 10.0 + sin(t * 25.0) * 3.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, -40 + hover), Vector2(8, -40 + hover), Vector2(0, -40 + hover + fl + 8)]), Color(1.0, 0.6, 0.2, 0.85))
			ellipse(ci, Vector2(0, -62 + hover), 34, 30, OUTLINE)
			ellipse(ci, Vector2(0, -62 + hover), 32, 28, body)
			rrect(ci, Rect2(-34, -66 + hover, 68, 10), 4, _shade(body, 0.7))
			ellipse(ci, Vector2(8, -66 + hover), 15, 15, Color(0.05, 0.05, 0.1))
			ellipse(ci, Vector2(10, -66 + hover), 9, 9, Color(1.0, 0.2, 0.2))
			disc(ci, Vector2(7, -69 + hover), 3, Color(1, 1, 1, 0.9))
			var recoil := sin(PI * atk) * 8.0
			rrect(ci, Rect2(20 - recoil, -52 + hover, 30 if gun else 18, 11 if gun else 8), 3, Color(0.22, 0.24, 0.3))
			for s in [-1, 1]:
				ci.draw_line(Vector2(s * 22, -86 + hover), Vector2(s * 30, -98 + hover), OUTLINE, 3)
			disc(ci, Vector2(-22, -88 + hover), 4, Color(1.0, 0.8, 0.2))
			if atk > 0.05 and atk < 0.4:
				star(ci, Vector2(52 if gun else 40, -48 + hover), 12.0 * (1.0 - atk * 1.4), Color(1.0, 0.55, 0.3), t * 9.0)
		_:
			# Foreur Titan : grosse machine à foreuse
			var shake := sin(t * 30.0) * 1.2
			for s in [-1, 1]:
				rrect(ci, Rect2(s * 40 - 22, -22, 44, 22), 8, OUTLINE)
				rrect(ci, Rect2(s * 40 - 20, -20, 40, 18), 7, Color(0.25, 0.27, 0.32))
			rrect(ci, Rect2(-62, -112 + shake, 124, 92), 22, OUTLINE)
			rrect(ci, Rect2(-59, -109 + shake, 118, 86), 20, Color(0.46, 0.34, 0.24))
			rrect(ci, Rect2(-59, -72 + shake, 118, 12), 4, Color(0.8, 0.55, 0.2))
			# foreuse
			var lunge := sin(PI * atk) * 20.0
			var tip := Vector2(86 + lunge, -64 + shake)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(52, -92 + shake), Vector2(52, -36 + shake), tip]), OUTLINE)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(54, -88 + shake), Vector2(54, -40 + shake), tip - Vector2(6, 0)]), Color(0.72, 0.74, 0.8))
			for k in 4:
				var x := 58.0 + fposmod(t * 40.0 + k * 9.0, 36.0)
				ci.draw_line(Vector2(x, -88 + shake + (x - 58.0) * 0.55), Vector2(x, -40 + shake - (x - 58.0) * 0.55), Color(0.35, 0.37, 0.44), 3)
			# yeux
			for k in 3:
				var ex := -34.0 + k * 22.0
				ellipse(ci, Vector2(ex, -92 + shake), 8, 8, Color(0.05, 0.03, 0.05))
				ellipse(ci, Vector2(ex + 1, -92 + shake), 5, 5, Color(1.0, 0.25 + 0.1 * sin(t * 3.0 + k), 0.2))
			rrect(ci, Rect2(-40, -54 + shake, 56, 10), 3, Color(0.1, 0.07, 0.07))
			for k in 6:
				ci.draw_line(Vector2(-36 + k * 9, -54 + shake), Vector2(-36 + k * 9, -44 + shake), Color(0.8, 0.8, 0.75), 2)
			ci.draw_line(Vector2(-26, -112 + shake), Vector2(-30, -134 + shake), OUTLINE, 5)
			disc(ci, Vector2(-30, -136 + shake), 7, Color(1.0, 0.3 + 0.3 * sin(t * 6.0), 0.2))
	shatter(ci, Vector2(0, -50 if kind != "titan" else -70), Color(1.0, 0.5, 0.3), dead)
	if stun:
		for k in 3:
			var a := t * 4.0 + k * TAU / 3.0
			var top := -120.0 if kind == "titan" else -110.0
			star(ci, Vector2(cos(a) * 26, top + sin(a) * 6), 5, Color(1, 0.9, 0.3))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- vue de face (caméra 2,5D)
## Les héros sont vus de dos (ils font face aux ennemis, en haut de l'écran), les ennemis de face.

static func draw_hero_back(ci: CanvasItem, h: Dictionary, p: Dictionary) -> void:
	var look: Dictionary = h.look
	var t: float = p.get("t", 0.0)
	var atk: float = p.get("atk", 0.0)
	var cast: float = p.get("cast", 0.0)
	var fall: float = p.get("dead", 0.0)
	var stun: bool = p.get("stun", false)
	var suit: Color = look.suit
	var accent: Color = look.accent
	var dark := _shade(suit, 0.62)
	var bob := sin(t * 2.2) * 2.0 + (sin(t * 11.0) * 1.5 if stun else 0.0)
	var kick := sin(PI * atk) * 5.0
	var raise := cast * -10.0
	ci.draw_set_transform(Vector2(0, -fall * 14.0), fall * 1.0, Vector2.ONE)
	ellipse(ci, Vector2(0, 2), 32.0 * (1.0 - fall * 0.4), 9.0, Color(0, 0, 0, 0.35))
	for s in [-1, 1]:
		rrect(ci, Rect2(s * 11 - 8, -34, 16, 34), 6, _shade(suit, 0.8))
		rrect(ci, Rect2(s * 11 - 10, -10, 20, 12), 5, dark)
	# bras (derrière le torse) et armes tenues vers l'avant
	var weapon: String = look.weapon
	var gun_col := Color(0.2, 0.24, 0.32)
	var lh := Vector2(-33, -46 + bob)
	var rh := Vector2(33, -46 + bob)
	if weapon in ["shield", "tablet"]:
		lh = Vector2(-37, -66 + bob + raise)
	else:
		rh = Vector2(36, -70 + bob + raise - kick)
	limb(ci, Vector2(-27, -74 + bob), lh, 11, _shade(suit, 0.8))
	limb(ci, Vector2(27, -74 + bob), rh, 11, _shade(suit, 0.8))
	rrect(ci, Rect2(-25, -90 + bob, 50, 60), 16, suit)
	rrect(ci, Rect2(-25, -52 + bob, 50, 7), 3, accent)
	rrect(ci, Rect2(-17, -84 + bob, 34, 38), 8, dark)
	rrect(ci, Rect2(-11, -76 + bob, 8, 4), 2, accent)
	rrect(ci, Rect2(3, -76 + bob, 8, 4), 2, accent)
	rrect(ci, Rect2(-2, -70 + bob, 4, 18), 2, _shade(suit, 0.5))
	match weapon:
		"shield":
			var c := lh + Vector2(-8, -14)
			ellipse(ci, c, 20, 28, OUTLINE)
			ellipse(ci, c, 17.5, 25.5, accent)
			ellipse(ci, c, 12, 19, _shade(suit, 0.9))
			star(ci, c, 8, accent, t)
			if cast > 0.0:
				ci.draw_arc(c, 36 + cast * 26.0, PI * 0.9, PI * 2.1, 5, Color(0.6, 0.9, 1.0, 0.8 * cast), 4.0)
		"blaster", "sniper":
			var length := 44.0 if weapon == "sniper" else 28.0
			rrect(ci, Rect2(rh.x - 7, rh.y - length, 14, length + 6), 4, OUTLINE)
			rrect(ci, Rect2(rh.x - 5, rh.y - length + 2, 10, length), 3, gun_col)
			rrect(ci, Rect2(rh.x - 5, rh.y - length + 2, 10, 6), 2, accent)
			if atk > 0.05 and atk < 0.4:
				star(ci, Vector2(rh.x, rh.y - length - 4), 15.0 * (1.0 - atk * 1.4), Color(1.0, 0.85, 0.4), t * 8.0)
		"tablet":
			var c2 := lh + Vector2(-6, -26 + sin(t * 2.5) * 2.0)
			ci.draw_colored_polygon(PackedVector2Array([c2 + Vector2(-14, 14), c2 + Vector2(-10, -18), c2 + Vector2(14, -18), c2 + Vector2(18, 14)]), Color(accent.r, accent.g, accent.b, 0.32))
			ci.draw_polyline(PackedVector2Array([c2 + Vector2(-14, 14), c2 + Vector2(-10, -18), c2 + Vector2(14, -18), c2 + Vector2(18, 14), c2 + Vector2(-14, 14)]), accent, 2.5)
			ci.draw_line(c2 + Vector2(0, -12), c2 + Vector2(2, 8), accent, 3)
			ci.draw_line(c2 + Vector2(-8, -2), c2 + Vector2(12, -2), accent, 3)
			if cast > 0.0 or atk > 0.1:
				ci.draw_arc(c2, 22 + 18 * maxf(cast, atk), 0, TAU, 6, Color(accent.r, accent.g, accent.b, 0.6), 3.0)
		_:
			var oc := rh + Vector2(0, -22 + sin(t * 3.0) * 3.0)
			disc(ci, oc, 15 + cast * 8, Color(accent.r, accent.g, accent.b, 0.25))
			disc(ci, oc, 10, accent)
			disc(ci, oc + Vector2(-3, -3), 3.4, Color(1, 1, 1, 0.9))
			if atk > 0.05 and atk < 0.5:
				ci.draw_arc(oc, 14 + atk * 30.0, 0, TAU, 6, Color(accent.r, accent.g, accent.b, 1.0 - atk * 2.0), 3.0)
	_draw_head_back(ci, h, look, Vector2(0, -112 + bob * 1.2 - kick * 0.4), t)
	aura(ci, Vector2(0, -70), cast, t, accent)
	shatter(ci, Vector2(0, -60), accent, fall)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_head_back(ci: CanvasItem, h: Dictionary, look: Dictionary, c: Vector2, t: float) -> void:
	var suit: Color = look.suit
	var accent: Color = look.accent
	match String(h.species):
		"robot":
			ellipse(ci, c, 35, 33, OUTLINE)
			ellipse(ci, c, 32, 30, Color(0.72, 0.77, 0.86))
			rrect(ci, Rect2(c.x - 18, c.y + 2, 36, 12), 4, Color(0.4, 0.44, 0.54))
			for k in 3:
				disc(ci, c + Vector2(-9 + k * 9, 8), 2.4, accent if int(t * 3.0 + k) % 3 != 0 else Color(0.2, 0.3, 0.3))
			ellipse(ci, c + Vector2(-34, 2), 5, 11, _shade(suit, 0.7))
			ellipse(ci, c + Vector2(34, 2), 5, 11, _shade(suit, 0.7))
			ci.draw_line(c + Vector2(0, -32), c + Vector2(4, -46), OUTLINE, 3)
			disc(ci, c + Vector2(4, -47), 4.5, accent)
		"alien":
			var skin: Color = look.skin
			for s in [-1, 1]:
				ci.draw_line(c + Vector2(s * 16, -28), c + Vector2(s * 26, -46 + sin(t * 3.0 + s) * 2), OUTLINE, 3)
				disc(ci, c + Vector2(s * 26, -46 + sin(t * 3.0 + s) * 2), 4.5, accent)
			ellipse(ci, c + Vector2(0, 2), 38, 35, OUTLINE)
			ellipse(ci, c + Vector2(0, 2), 36, 33, skin)
			for k in 3:
				shard(ci, c + Vector2(-14 + k * 14, -6), 12, -PI * 0.5, _shade(skin, 0.7))
			ellipse(ci, c + Vector2(0, 2), 41, 38, Color(0.7, 0.9, 1.0, 0.13))
			ci.draw_arc(c + Vector2(0, 2), 40, 0, TAU, 8, Color(accent.r, accent.g, accent.b, 0.8), 3.0)
		_:
			var hair: Color = look.hair
			var skin: Color = look.skin
			match int(look.style):
				1:
					ellipse(ci, c + Vector2(0, 24), 17, 10, hair)
				2:
					ellipse(ci, c + Vector2(0, 28), 8, 17, hair)
					ellipse(ci, c + Vector2(0, 14), 6, 5, _shade(hair, 1.4))
				_:
					for k in 5:
						shard(ci, c + Vector2(-16 + k * 8, -30), 11, -PI * 0.5, hair)
			ellipse(ci, c, 37, 36, OUTLINE)
			ellipse(ci, c, 35, 34, _shade(suit, 1.12))
			rrect(ci, Rect2(c.x - 11, c.y + 2, 22, 16), 5, _shade(suit, 0.65))
			disc(ci, c + Vector2(0, 10), 3.0, accent)
			ci.draw_arc(c + Vector2(-4, -2), 28, PI * 1.05, PI * 1.38, 3, Color(1, 1, 1, 0.5), 3.0)
			ellipse(ci, c + Vector2(-34, 4), 5, 9, skin)
			ellipse(ci, c + Vector2(34, 4), 5, 9, skin)


static func draw_enemy_front(ci: CanvasItem, kind: String, p: Dictionary) -> void:
	var t: float = p.get("t", 0.0)
	var atk: float = p.get("atk", 0.0)
	var dead: float = p.get("dead", 0.0)
	var stun: bool = p.get("stun", false)
	var lunge := sin(PI * atk) * 14.0
	ci.draw_set_transform(Vector2(0, -dead * 10.0), dead * -1.0, Vector2.ONE)
	ellipse(ci, Vector2(0, 2), 30, 8, Color(0, 0, 0, 0.3))
	match kind:
		"mite":
			var bob := absf(sin(t * 6.0)) * 4.0
			for s in [-1, 1]:
				for k in 3:
					ci.draw_line(Vector2(s * 12, -14 - bob), Vector2(s * (26 + k * 8), -2 - k * 3), OUTLINE, 5)
			ellipse(ci, Vector2(0, -22 - bob), 27, 20, OUTLINE)
			ellipse(ci, Vector2(0, -22 - bob), 25, 18, Color(0.55, 0.42, 0.3))
			ellipse(ci, Vector2(-6, -28 - bob), 12, 5, Color(0.7, 0.58, 0.42))
			ellipse(ci, Vector2(-9, -20 - bob), 5.5, 6, Color(1, 0.25, 0.2))
			ellipse(ci, Vector2(9, -20 - bob), 5.5, 6, Color(1, 0.25, 0.2))
			for s in [-1, 1]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(s * 10, -8 - bob), Vector2(s * 24, -10 - bob), Vector2(s * 15, 4 + lunge - bob)]), Color(0.85, 0.8, 0.7))
		"drone", "gunner":
			var hover := sin(t * 2.6) * 5.0
			var gun := kind == "gunner"
			var body := Color(0.38, 0.4, 0.5) if not gun else Color(0.5, 0.3, 0.3)
			ellipse(ci, Vector2(0, -18 + hover * 0.3), 22.0 + sin(t * 20.0) * 2.0, 6, Color(1.0, 0.6, 0.2, 0.5))
			for s in [-1, 1]:
				rrect(ci, Rect2(s * 36 - 5, -66 + hover, 10, (30 if gun else 20) + lunge * 0.5), 3, Color(0.22, 0.24, 0.3))
			ellipse(ci, Vector2(0, -60 + hover), 36, 30, OUTLINE)
			ellipse(ci, Vector2(0, -60 + hover), 34, 28, body)
			rrect(ci, Rect2(-34, -64 + hover, 68, 9), 4, _shade(body, 0.7))
			ellipse(ci, Vector2(0, -50 + hover), 14, 14, Color(0.05, 0.05, 0.1))
			ellipse(ci, Vector2(0, -50 + hover), 9, 9, Color(1.0, 0.2, 0.2))
			disc(ci, Vector2(-3, -53 + hover), 3, Color(1, 1, 1, 0.9))
			for s in [-1, 1]:
				ci.draw_line(Vector2(s * 20, -86 + hover), Vector2(s * 28, -98 + hover), OUTLINE, 3)
				disc(ci, Vector2(s * 28, -99 + hover), 4, Color(1.0, 0.8, 0.2))
			if atk > 0.05 and atk < 0.4:
				for s in [-1, 1]:
					star(ci, Vector2(s * 36, -34 + hover + (14 if gun else 0)), 12.0 * (1.0 - atk * 1.4), Color(1.0, 0.55, 0.3), t * 9.0)
		_:
			var shake := sin(t * 30.0) * 1.2
			for s in [-1, 1]:
				rrect(ci, Rect2(s * 44 - 20, -24, 40, 24), 8, OUTLINE)
				rrect(ci, Rect2(s * 44 - 18, -22, 36, 20), 7, Color(0.25, 0.27, 0.32))
			rrect(ci, Rect2(-62, -118 + shake, 124, 98), 22, OUTLINE)
			rrect(ci, Rect2(-59, -115 + shake, 118, 92), 20, Color(0.46, 0.34, 0.24))
			rrect(ci, Rect2(-59, -70 + shake, 118, 12), 4, Color(0.8, 0.55, 0.2))
			for k in 3:
				var ex := -30.0 + k * 30.0
				ellipse(ci, Vector2(ex, -92 + shake), 9, 9, Color(0.05, 0.03, 0.05))
				ellipse(ci, Vector2(ex, -92 + shake), 5.5, 5.5, Color(1.0, 0.25 + 0.1 * sin(t * 3.0 + k), 0.2))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-26, -56 + shake), Vector2(26, -56 + shake), Vector2(0, 8 + lunge + shake)]), OUTLINE)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-21, -54 + shake), Vector2(21, -54 + shake), Vector2(0, 0 + lunge + shake)]), Color(0.72, 0.74, 0.8))
			for k in 4:
				var yy := -50.0 + fposmod(t * 40.0 + k * 11.0, 44.0)
				var half := 21.0 * (1.0 - (yy + 54.0) / 56.0)
				ci.draw_line(Vector2(-half, yy + shake), Vector2(half, yy + shake), Color(0.35, 0.37, 0.44), 3)
			ci.draw_line(Vector2(0, -118 + shake), Vector2(0, -138 + shake), OUTLINE, 5)
			disc(ci, Vector2(0, -140 + shake), 7, Color(1.0, 0.3 + 0.3 * sin(t * 6.0), 0.2))
	shatter(ci, Vector2(0, -50 if kind != "titan" else -70), Color(1.0, 0.5, 0.3), dead)
	if stun:
		for k in 3:
			var a := t * 4.0 + k * TAU / 3.0
			star(ci, Vector2(cos(a) * 26, (-120.0 if kind == "titan" else -110.0) + sin(a) * 6), 5, Color(1, 0.9, 0.3))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- icône et décor

## Portrait rond d'un héros (boutons de pouvoir, liste) : on dessine la tête agrandie, sans le corps.
static func draw_portrait(ci: CanvasItem, h: Dictionary, center: Vector2, radius: float, t: float = 0.0) -> void:
	var s := radius / 38.0
	ci.draw_set_transform(center + Vector2(-2, 112) * s, 0.0, Vector2(s, s))
	_draw_head(ci, h, h.look, Vector2(2, -112), t, 0.0, 0.0, false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _ridge(ci: CanvasItem, rect: Rect2, base: float, h: float, step: float, speed: float, seed_: float, t: float, col: Color) -> void:
	var first := int(floor((rect.position.x + t * speed) / step)) - 1
	var count := int(rect.size.x / step) + 3
	for j in count:
		var idx := first + j
		var x := rect.position.x + idx * step - t * speed - rect.position.x
		var peak := Vector2(x, base - (0.35 + 0.65 * absf(sin(idx * 2.7 + seed_))) * h)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - step * 0.75, base), peak, Vector2(x, base)]), _shade(col, 1.15))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, base), peak, Vector2(x + step * 0.75, base)]), _shade(col, 0.8))


static func draw_background(ci: CanvasItem, rect: Rect2, t: float, stars: PackedVector2Array, boss: bool) -> void:
	var top := Color(0.02, 0.03, 0.09)
	var bot := Color(0.09, 0.07, 0.2) if not boss else Color(0.18, 0.05, 0.1)
	var fy := rect.position.y + 110.0
	var cx := rect.position.x + rect.size.x * 0.5
	for i in 5:
		var k := float(i) / 5.0
		ci.draw_rect(Rect2(rect.position.x, rect.position.y + (fy - rect.position.y) * k, rect.size.x, (fy - rect.position.y) / 5.0 + 1.0), top.lerp(bot, k))
	for i in stars.size():
		var s := stars[i]
		var x := fposmod(s.x * rect.size.x - t * (6.0 + (i % 3) * 5.0), rect.size.x)
		var y := s.y * 95.0
		var a := 0.35 + 0.6 * (0.5 + 0.5 * sin(t * 1.8 + i))
		var r := 1.5 + (i % 3) * 0.8
		var c := rect.position + Vector2(x, y)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.6), c + Vector2(r, 0), c + Vector2(0, r * 1.6), c + Vector2(-r, 0)]), Color(1, 1, 1, a))
	var pc := rect.position + Vector2(rect.size.x * 0.8, 48.0)
	ellipse(ci, pc, 50, 50, Color(0.14, 0.34, 0.66) if not boss else Color(0.6, 0.2, 0.16), t * 0.05, 10)
	var ring := PackedVector2Array()
	for i in 7:
		var a := TAU * i / 7.0 + t * 0.2
		ring.append(pc + Vector2(cos(a) * 80, sin(a) * 16).rotated(-0.35))
	ring.append(ring[0])
	ci.draw_polyline(ring, Color(0.7, 0.85, 1.0, 0.45), 2.5)
	for k in 3:
		var x := fposmod(120.0 + k * 260.0 - t * 14.0, rect.size.x + 80.0) - 40.0
		ellipse(ci, Vector2(rect.position.x + x, rect.position.y + 22 + k * 20 + sin(t * 0.8 + k) * 3.0), 12 + k * 3, 8 + k * 2, Color(0.24, 0.21, 0.31), t * 0.4 + k, 5)
	_ridge(ci, rect, fy - 4, 48.0, 70.0, 5.0, 1.3, t, Color(0.13, 0.12, 0.26) if not boss else Color(0.26, 0.1, 0.16))
	_ridge(ci, rect, fy, 28.0, 46.0, 12.0, 4.1, t, Color(0.09, 0.1, 0.2) if not boss else Color(0.19, 0.07, 0.12))
	# sol en perspective : bandes sombres vers lointain, claires vers la caméra
	var h := rect.end.y - fy
	var floor_far := Color(0.06, 0.08, 0.15)
	var floor_near := Color(0.11, 0.15, 0.27)
	for i in 6:
		var y0 := fy + h * pow(float(i) / 6.0, 1.7)
		var y1 := fy + h * pow(float(i + 1) / 6.0, 1.7)
		ci.draw_rect(Rect2(rect.position.x, y0, rect.size.x, y1 - y0 + 1.0), floor_far.lerp(floor_near, float(i) / 5.0))
	ci.draw_line(Vector2(rect.position.x, fy), Vector2(rect.end.x, fy), Color(0.3, 0.8, 1.0, 0.7), 3.0)
	for k in range(-9, 10):
		ci.draw_line(Vector2(cx + k * 14.0, fy), Vector2(cx + k * 120.0, rect.end.y), Color(0.3, 0.8, 1.0, 0.13), 2.0)
	for k in 8:
		var u := (float(k) + fposmod(t * 0.35, 1.0)) / 8.0
		ci.draw_line(Vector2(rect.position.x, fy + h * u * u), Vector2(rect.end.x, fy + h * u * u), Color(0.3, 0.8, 1.0, 0.05 + 0.2 * u), 2.0)
	# plots d'équipe : ennemis en haut (rouge), escouade en bas (cyan)
	var enemy_col := Color(1.0, 0.35, 0.3, 0.1) if not boss else Color(1.0, 0.35, 0.3, 0.16)
	var ally_col := Color(0.3, 0.85, 1.0, 0.1)
	var ep := PackedVector2Array()
	var ap := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + 0.39
		ep.append(Vector2(cx, fy + 100.0) + Vector2(cos(a) * 300.0, sin(a) * 62.0))
		ap.append(Vector2(cx, fy + 380.0) + Vector2(cos(a) * 330.0, sin(a) * 92.0))
	ci.draw_colored_polygon(ep, enemy_col)
	ci.draw_colored_polygon(ap, ally_col)
	ep.append(ep[0])
	ap.append(ap[0])
	ci.draw_polyline(ep, Color(enemy_col.r, enemy_col.g, enemy_col.b, 0.55), 2.0)
	ci.draw_polyline(ap, Color(ally_col.r, ally_col.g, ally_col.b, 0.55), 2.0)
	var sx := rect.position.x + fposmod(t * 140.0, rect.size.x + 200.0) - 100.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, fy), Vector2(sx + 60, fy), Vector2(sx + 20, rect.end.y), Vector2(sx - 120, rect.end.y)]), Color(0.3, 0.8, 1.0, 0.05))
