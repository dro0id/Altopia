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

## Phases d'une attaque (atk 0..1) : préparation 0..0.3, frappe 0.3..0.45, retour ensuite.
static func _wind(atk: float) -> float:
	if atk <= 0.0:
		return 0.0
	if atk < 0.3:
		return smoothstep(0.0, 0.3, atk)
	return 1.0 - smoothstep(0.3, 0.42, atk)


static func _strike(atk: float) -> float:
	if atk < 0.3:
		return 0.0
	return pow(1.0 - smoothstep(0.3, 0.75, atk), 1.5)


static func draw_hero_back(ci: CanvasItem, h: Dictionary, p: Dictionary) -> void:
	var look: Dictionary = h.look
	var t: float = p.get("t", 0.0)
	var atk: float = p.get("atk", 0.0)
	var cast: float = p.get("cast", 0.0)
	var fall: float = p.get("dead", 0.0)
	var stun: bool = p.get("stun", false)
	var hurt: float = p.get("hurt", 0.0)
	var stride: float = p.get("stride", 0.0)
	var move: float = p.get("move", 0.0)
	var suit: Color = look.suit
	var accent: Color = look.accent
	var dark := _shade(suit, 0.62)
	var wind := _wind(atk)
	var hit := _strike(atk)
	var breathe := sin(t * 2.2)
	var sway := sin(t * 1.3) * 1.6 * (1.0 - move)
	var lean_x := sway + sin(t * 45.0) * hurt * 2.5
	var jump := cast * -16.0
	var body_y := breathe * 1.2 + wind * 5.0 - hit * 6.0 + jump + hurt * 3.0 + absf(sin(stride)) * -2.5 * move
	var weapon: String = look.weapon
	# écrasement à la mort : le héros s'affaisse
	ci.draw_set_transform(Vector2(0, 0), fall * 0.25, Vector2(1.0 + fall * 0.35, 1.0 - fall * 0.7))
	ellipse(ci, Vector2(0, 2), 32.0 * (1.0 - cast * 0.35), 9.0 * (1.0 - cast * 0.3), Color(0, 0, 0, 0.35))
	# jambes : pas alternés quand ça avance, appui sur une jambe sinon
	for s in [-1, 1]:
		var ph := stride + (0.0 if s < 0 else PI)
		var lift := maxf(0.0, sin(ph)) * 10.0 * move + (maxf(0.0, sin(t * 1.3 + (0.0 if s < 0 else PI))) * 1.5 * (1.0 - move))
		var x: float = s * 11 - 8 + lean_x * 0.3
		var top := -34.0 + body_y * 0.5
		rrect(ci, Rect2(x, top, 16, -top - lift * 0.5), 6, _shade(suit, 0.8))
		rrect(ci, Rect2(x - 2, -10 - lift, 20, 12), 5, dark)
	# bras (dessinés derrière le torse) : position de repos puis pose de l'arme
	var swing := sin(stride) * 8.0 * move
	var idle := sin(t * 2.2 + 1.0) * 2.0
	var lh := Vector2(-33 + lean_x * 1.2, -46 + body_y + idle - swing)
	var rh := Vector2(33 + lean_x * 1.2, -46 + body_y - idle + swing)
	var gun_len := 44.0 if weapon == "sniper" else 28.0
	if weapon in ["shield", "tablet"]:
		lh = Vector2(-37 + lean_x, -66 + body_y + wind * 8.0 - hit * 16.0)
	else:
		rh = Vector2(36 + lean_x, -70 + body_y + wind * 7.0 - hit * 4.0)
	lh = lh.lerp(Vector2(-24, -122 + body_y), cast)
	rh = rh.lerp(Vector2(24, -122 + body_y), cast)
	limb(ci, Vector2(-27 + lean_x, -74 + body_y), lh, 11, _shade(suit, 0.8))
	limb(ci, Vector2(27 + lean_x, -74 + body_y), rh, 11, _shade(suit, 0.8))
	# torse et sac à dos
	rrect(ci, Rect2(-25 + lean_x - breathe * 0.4, -90 + body_y, 50 + breathe * 0.8, 60 - wind * 2.0), 16, suit)
	rrect(ci, Rect2(-25 + lean_x, -52 + body_y, 50, 7), 3, accent)
	rrect(ci, Rect2(-17 + lean_x, -84 + body_y, 34, 38), 8, dark)
	rrect(ci, Rect2(-11 + lean_x, -76 + body_y, 8, 4), 2, accent)
	rrect(ci, Rect2(3 + lean_x, -76 + body_y, 8, 4), 2, accent)
	rrect(ci, Rect2(-2 + lean_x, -70 + body_y, 4, 18), 2, _shade(suit, 0.5))
	# réacteur du sac à dos quand on avance ou qu'on lance un pouvoir
	var thrust := maxf(move, cast)
	if thrust > 0.2:
		var fl := 8.0 + sin(t * 40.0) * 3.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-8 + lean_x, -44 + body_y), Vector2(8 + lean_x, -44 + body_y), Vector2(lean_x, -44 + body_y + fl * thrust * 2.0)]), Color(1.0, 0.65, 0.25, 0.85 * thrust))
	match weapon:
		"shield":
			var c := lh + Vector2(-8, -14)
			var sk := 1.0 + hit * 0.3
			ellipse(ci, c, 20 * sk, 28 * sk, OUTLINE)
			ellipse(ci, c, 17.5 * sk, 25.5 * sk, accent)
			ellipse(ci, c, 12 * sk, 19 * sk, _shade(suit, 0.9))
			star(ci, c, 8 * sk, accent, t)
			if hit > 0.3:
				ci.draw_arc(c, 30 + (1.0 - hit) * 24.0, PI * 1.1, PI * 1.9, 5, Color(1, 1, 1, hit), 4.0)
			if cast > 0.0:
				ci.draw_arc(c, 36 + cast * 26.0, PI * 0.9, PI * 2.1, 5, Color(0.6, 0.9, 1.0, 0.8 * cast), 4.0)
		"blaster", "sniper":
			var kick := hit * 9.0
			rrect(ci, Rect2(rh.x - 7, rh.y - gun_len + kick, 14, gun_len + 6), 4, OUTLINE)
			rrect(ci, Rect2(rh.x - 5, rh.y - gun_len + 2 + kick, 10, gun_len), 3, Color(0.2, 0.24, 0.32))
			rrect(ci, Rect2(rh.x - 5, rh.y - gun_len + 2 + kick, 10, 6), 2, accent)
			# chargeur : la lueur monte pendant la préparation
			if wind > 0.0:
				rrect(ci, Rect2(rh.x - 3, rh.y - gun_len * wind, 6, gun_len * wind), 2, Color(accent.r, accent.g, accent.b, 0.9))
			if hit > 0.6:
				var tip := Vector2(rh.x, rh.y - gun_len - 2 + kick)
				var fk := (hit - 0.55) / 0.45
				ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, 4), tip + Vector2(0, -34 * fk), tip + Vector2(9, 4)]), Color(1.0, 0.85, 0.4, 0.9))
				star(ci, tip, 18.0 * fk, Color(1, 1, 1, 0.95), t * 10.0)
		"tablet":
			var c2 := lh + Vector2(-6, -26 + sin(t * 2.5) * 2.0)
			var a := 0.32 + 0.3 * maxf(wind, hit)
			var pts := PackedVector2Array([c2 + Vector2(-14, 14), c2 + Vector2(-10, -18), c2 + Vector2(14, -18), c2 + Vector2(18, 14)])
			ci.draw_colored_polygon(pts, Color(accent.r, accent.g, accent.b, a))
			pts.append(pts[0])
			ci.draw_polyline(pts, accent, 2.5)
			for k in 3:
				var yy := fposmod(t * 24.0 + k * 10.0, 30.0) - 16.0
				ci.draw_line(c2 + Vector2(-9, yy), c2 + Vector2(11, yy), Color(accent.r, accent.g, accent.b, 0.8), 2)
			if wind > 0.0 or hit > 0.0:
				ci.draw_arc(c2, 14 + 26.0 * maxf(wind * 0.6, 1.0 - hit), 0, TAU, 6, Color(accent.r, accent.g, accent.b, 0.7), 3.0)
		_:
			var charge := 15.0 + wind * 11.0 + cast * 8.0
			var oc := rh + Vector2(0, -22 + sin(t * 3.0) * 3.0 - hit * 6.0)
			disc(ci, oc, charge + 5.0, Color(accent.r, accent.g, accent.b, 0.25))
			disc(ci, oc, charge * (1.0 - hit * 0.6) * 0.7, accent)
			disc(ci, oc + Vector2(-3, -3), 3.4, Color(1, 1, 1, 0.9))
			for k in 4:
				var ang := t * 5.0 + k * TAU / 4.0
				shard(ci, oc + Vector2(cos(ang), sin(ang)) * (charge + 6.0), 4.0 + wind * 3.0, ang * 2.0, Color(accent.r, accent.g, accent.b, 0.7))
			if hit > 0.2:
				ci.draw_arc(oc, 14 + (1.0 - hit) * 34.0, 0, TAU, 6, Color(accent.r, accent.g, accent.b, hit), 3.0)
	_draw_head_back(ci, h, look, Vector2(lean_x * 1.3, -112 + body_y * 1.1 - hit * 2.0 + wind * 2.0), t, hit - wind * 0.6 + hurt)
	aura(ci, Vector2(0, -70), cast, t, accent)
	shatter(ci, Vector2(0, -60), accent, fall)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_head_back(ci: CanvasItem, h: Dictionary, look: Dictionary, c: Vector2, t: float, lag: float) -> void:
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
			var ax := 4.0 + lag * 7.0 + sin(t * 3.0) * 1.5
			ci.draw_line(c + Vector2(0, -32), c + Vector2(ax, -46 + absf(lag) * 3.0), OUTLINE, 3)
			disc(ci, c + Vector2(ax, -47 + absf(lag) * 3.0), 4.5, accent)
		"alien":
			var skin: Color = look.skin
			for s in [-1, 1]:
				var tip := c + Vector2(s * 26 + lag * 7.0 * s * 0.5 + lag * 4.0, -46 + sin(t * 3.0 + s) * 2 + absf(lag) * 3.0)
				ci.draw_line(c + Vector2(s * 16, -28), tip, OUTLINE, 3)
				disc(ci, tip, 4.5, accent)
			ellipse(ci, c + Vector2(0, 2), 38, 35, OUTLINE)
			ellipse(ci, c + Vector2(0, 2), 36, 33, skin)
			for k in 3:
				shard(ci, c + Vector2(-14 + k * 14, -6), 12, -PI * 0.5, _shade(skin, 0.7))
			ellipse(ci, c + Vector2(0, 2), 41, 38, Color(0.7, 0.9, 1.0, 0.13))
			ci.draw_arc(c + Vector2(0, 2), 40, 0, TAU, 8, Color(accent.r, accent.g, accent.b, 0.8), 3.0)
		_:
			var hair: Color = look.hair
			var skin: Color = look.skin
			# les cheveux suivent le mouvement avec du retard
			var fl := lag * 6.0 + sin(t * 2.0) * 1.5
			match int(look.style):
				1:
					ellipse(ci, c + Vector2(fl * 0.5, 24), 17, 10, hair)
				2:
					ellipse(ci, c + Vector2(fl, 28), 8, 17, hair)
					ellipse(ci, c + Vector2(fl * 0.3, 14), 6, 5, _shade(hair, 1.4))
				_:
					for k in 5:
						shard(ci, c + Vector2(-16 + k * 8 + fl * 0.3, -30), 11, -PI * 0.5, hair)
			ellipse(ci, c, 37, 36, OUTLINE)
			ellipse(ci, c, 35, 34, _shade(suit, 1.12))
			rrect(ci, Rect2(c.x - 11, c.y + 2, 22, 16), 5, _shade(suit, 0.65))
			disc(ci, c + Vector2(0, 10), 3.0, accent)
			ci.draw_arc(c + Vector2(-4, -2), 28, PI * 1.05, PI * 1.38, 3, Color(1, 1, 1, 0.5), 3.0)
			ellipse(ci, c + Vector2(-34, 4), 5, 9, skin)
			ellipse(ci, c + Vector2(34, 4), 5, 9, skin)


## Pince de crabe : deux mâchoires qui s'ouvrent et se referment.
static func _claw(ci: CanvasItem, at: Vector2, side: float, open: float, col: Color) -> void:
	var a := open * 0.7
	for k in [-1, 1]:
		var ang: float = PI * 0.5 + k * a * side
		var tip: Vector2 = at + Vector2(cos(ang), sin(ang)) * 17.0
		var left: Vector2 = at + Vector2(cos(ang + 1.9), sin(ang + 1.9)) * 6.0
		var right: Vector2 = at + Vector2(cos(ang - 1.9), sin(ang - 1.9)) * 6.0
		ci.draw_colored_polygon(PackedVector2Array([left, tip, right]), OUTLINE)
		ci.draw_colored_polygon(PackedVector2Array([left * 0.92 + at * 0.08, tip * 0.94 + at * 0.06, right * 0.92 + at * 0.08]), col)


static func draw_enemy_front(ci: CanvasItem, kind: String, p: Dictionary) -> void:
	var t: float = p.get("t", 0.0)
	var atk: float = p.get("atk", 0.0)
	var cast: float = p.get("cast", 0.0)
	var dead: float = p.get("dead", 0.0)
	var stun: bool = p.get("stun", false)
	var hurt: float = p.get("hurt", 0.0)
	var wind := _wind(atk)
	var hit := _strike(atk)
	ci.draw_set_transform(Vector2(0, -dead * 6.0), dead * -0.6, Vector2(1.0 + dead * 0.3, 1.0 - dead * 0.7))
	var air := cast * 34.0 if kind == "titan" else 0.0
	ellipse(ci, Vector2(0, 2), 30.0 * (1.0 - air * 0.008), 8.0 * (1.0 - air * 0.008), Color(0, 0, 0, 0.3))
	match kind:
		"mite":
			var scut: float = 1.0 + float(p.get("move", 0.0)) * 2.0
			var bob := absf(sin(t * 6.0 * scut)) * 4.0 - wind * 3.0
			# pattes : chaque patte lève et pose le pied en décalé
			for s in [-1, 1]:
				for k in 3:
					var ph: float = t * 9.0 * scut + k * 2.1 + (0.0 if s < 0 else PI)
					var hip := Vector2(s * 12, -14 - bob)
					var foot := Vector2(s * (28 + k * 8) + cos(ph) * 4.0, -2 - k * 3 - maxf(0.0, sin(ph)) * 6.0)
					var knee := (hip + foot) * 0.5 + Vector2(s * 6, -10)
					ci.draw_line(hip, knee, OUTLINE, 5)
					ci.draw_line(knee, foot, OUTLINE, 5)
			var sq := wind * 3.0
			ellipse(ci, Vector2(0, -22 - bob + sq), 27, 20 - sq * 0.5, OUTLINE)
			ellipse(ci, Vector2(0, -22 - bob + sq), 25, 18 - sq * 0.5, Color(0.55, 0.42, 0.3))
			ellipse(ci, Vector2(-6, -28 - bob + sq), 12, 5, Color(0.7, 0.58, 0.42))
			var ey := 6.0 + wind * 2.0
			ellipse(ci, Vector2(-9, -20 - bob + sq), 5.5, ey, Color(1, 0.25, 0.2))
			ellipse(ci, Vector2(9, -20 - bob + sq), 5.5, ey, Color(1, 0.25, 0.2))
			# pinces : grandes ouvertes à la préparation, claquent à la frappe
			var open := wind * 1.0 + 0.15 + (1.0 - hit) * 0.0
			if hit > 0.0 and atk > 0.3:
				open = 0.15 + (1.0 - hit) * 0.0
			for s in [-1, 1]:
				_claw(ci, Vector2(s * 14, -6 - bob + hit * 4.0), s, open, Color(0.85, 0.8, 0.7))
		"drone", "gunner":
			var gun := kind == "gunner"
			var hover := sin(t * 2.6) * 5.0 + wind * 6.0 - hit * 4.0
			var body := Color(0.38, 0.4, 0.5) if not gun else Color(0.5, 0.3, 0.3)
			var wob := sin(t * 40.0) * hurt * 3.0
			# réacteur : la flamme grandit à la préparation
			var fl := 8.0 + sin(t * 30.0) * 3.0 + wind * 8.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-10 + wob, -30 + hover), Vector2(10 + wob, -30 + hover), Vector2(wob, -30 + hover + fl * 2.0)]), Color(1.0, 0.6, 0.2, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-5 + wob, -30 + hover), Vector2(5 + wob, -30 + hover), Vector2(wob, -30 + hover + fl)]), Color(1.0, 0.95, 0.6, 0.9))
			# canons qui reculent à chaque tir
			for s in [-1, 1]:
				var barrel := (30.0 if gun else 20.0) - hit * 8.0 + wind * 5.0
				rrect(ci, Rect2(s * 36 - 5 + wob, -66 + hover, 10, barrel), 3, Color(0.22, 0.24, 0.3))
			# hélices latérales : fines ellipses qui oscillent
			for s in [-1, 1]:
				ellipse(ci, Vector2(s * 42 + wob, -86 + hover), 4.0 + 10.0 * absf(cos(t * 28.0 + s)), 2.5, Color(0.7, 0.75, 0.85, 0.7))
			ellipse(ci, Vector2(wob, -60 + hover), 36, 30, OUTLINE)
			ellipse(ci, Vector2(wob, -60 + hover), 34, 28, body)
			rrect(ci, Rect2(-34 + wob, -64 + hover, 68, 9), 4, _shade(body, 0.7))
			ellipse(ci, Vector2(wob, -50 + hover), 14, 14, Color(0.05, 0.05, 0.1))
			# l'œil se charge (rouge vif) avant le tir
			var eye := Color(1.0, 0.2 + 0.4 * wind, 0.2 + 0.3 * wind)
			ellipse(ci, Vector2(wob, -50 + hover), 9 + wind * 3.0, 9 + wind * 3.0, eye)
			disc(ci, Vector2(-3 + wob, -53 + hover), 3, Color(1, 1, 1, 0.9))
			for s in [-1, 1]:
				ci.draw_line(Vector2(s * 20, -86 + hover), Vector2(s * 28, -98 + hover), OUTLINE, 3)
				disc(ci, Vector2(s * 28, -99 + hover), 4, Color(1.0, 0.8, 0.2))
			if hit > 0.6:
				var fk := (hit - 0.5) / 0.5
				for s in [-1, 1]:
					var mz := Vector2(s * 36, -66 + hover + (30 if gun else 20))
					ci.draw_colored_polygon(PackedVector2Array([mz + Vector2(-7, 0), mz + Vector2(0, 26 * fk), mz + Vector2(7, 0)]), Color(1.0, 0.6, 0.3, 0.9))
					star(ci, mz, 13.0 * fk, Color(1, 0.9, 0.6), t * 9.0)
		_:
			var stomp := maxf(0.0, sin(t * 2.0))
			var crouch := wind * 9.0 + cast * 0.0
			var sy := 1.0 - 0.03 * stomp - wind * 0.08 + hit * 0.04
			var by := -air + crouch * 0.5
			for s in [-1, 1]:
				var lift := maxf(0.0, sin(t * 2.0 + (0.0 if s < 0 else PI))) * 4.0
				rrect(ci, Rect2(s * 44 - 20, -24 - lift + by * 0.2, 40, 24), 8, OUTLINE)
				rrect(ci, Rect2(s * 44 - 18, -22 - lift + by * 0.2, 36, 20), 7, Color(0.25, 0.27, 0.32))
			var shake := sin(t * 30.0) * 1.2 + sin(t * 50.0) * hurt * 3.0
			rrect(ci, Rect2(-62, -118 * sy + shake + by + crouch, 124, 98 * sy), 22, OUTLINE)
			rrect(ci, Rect2(-59, -115 * sy + shake + by + crouch, 118, 92 * sy), 20, Color(0.46, 0.34, 0.24))
			rrect(ci, Rect2(-59, -70 + shake + by + crouch, 118, 12), 4, Color(0.8, 0.55, 0.2))
			for k in 3:
				var ex := -30.0 + k * 30.0
				var glow := 0.25 + 0.1 * sin(t * 3.0 + k) + wind * 0.5
				ellipse(ci, Vector2(ex, -92 + shake + by + crouch), 9, 9, Color(0.05, 0.03, 0.05))
				ellipse(ci, Vector2(ex, -92 + shake + by + crouch), 5.5 + wind * 2.0, 5.5 + wind * 2.0, Color(1.0, glow, 0.2))
			# foreuse : tourne en permanence, s'enfonce à la frappe
			var spin := 1.0 + wind * 2.0
			var tip := 8.0 + hit * 22.0 - wind * 10.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-26, -56 + shake + by + crouch), Vector2(26, -56 + shake + by + crouch), Vector2(0, tip + shake + by + crouch)]), OUTLINE)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-21, -54 + shake + by + crouch), Vector2(21, -54 + shake + by + crouch), Vector2(0, tip - 8.0 + shake + by + crouch)]), Color(0.72, 0.74, 0.8))
			for k in 5:
				var f := fposmod(t * 1.2 * spin + k * 0.2, 1.0)
				var yy := lerpf(-52.0, tip - 12.0, f) + shake + by + crouch
				var half := 21.0 * (1.0 - f) * 0.95
				ci.draw_line(Vector2(-half, yy), Vector2(half, yy), Color(0.35, 0.37, 0.44), 3)
			ci.draw_line(Vector2(0, -118 * sy + shake + by + crouch), Vector2(sin(t * 2.0) * 4.0, -138 + shake + by + crouch), OUTLINE, 5)
			disc(ci, Vector2(sin(t * 2.0) * 4.0, -140 + shake + by + crouch), 7, Color(1.0, 0.3 + 0.3 * sin(t * 6.0), 0.2))
			# poussière sous les chenilles à l'atterrissage
			if cast > 0.0 and cast < 0.15:
				for s in [-1, 1]:
					shard(ci, Vector2(s * 70, -4), 12, -PI * 0.5 + s * 0.8, Color(0.6, 0.55, 0.5, 0.7))
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
