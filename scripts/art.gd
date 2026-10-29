class_name Art
extends RefCounted
## Dessin 2D animé des héros et des ennemis, en formes vectorielles (aucune image) : tout bouge par paramètres.
## Origine = pieds du personnage, il regarde vers la droite (les ennemis sont retournés par le nœud).
## p : {t: temps, atk: 0..1 progression de l'attaque, cast: 0..1 pouvoir, hurt: 0..1, dead: 0..1, stun: bool}

const OUTLINE := Color(0.05, 0.07, 0.12)


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0, n: int = 28) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var v := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		pts.append(c + v)
	ci.draw_colored_polygon(pts, col)


static func rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.position.x + rad, r.position.y + rad), PI],
		[Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
	]
	for c in corners:
		for k in 5:
			var a: float = c[1] + (PI * 0.5) * k / 4.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(pts, col)


static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, OUTLINE, w + 4.0, true)
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, rot: float = 0.0) -> void:
	if r < 0.8:
		return
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


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
	ci.draw_circle(Vector2(-4 + lean * 0.4, -71 + bob), 2.2, accent)
	ci.draw_circle(Vector2(4 + lean * 0.4, -71 + bob), 2.2, Color(1, 0.4, 0.4) if p.get("hurt", 0.0) > 0.0 else accent)
	# tête
	var hc := Vector2(2 + lean * 0.8, -112 + bob * 1.2 + breathe)
	_draw_head(ci, h, look, hc, t, atk, cast, stun)
	# bras avant + arme
	_draw_front_arm(ci, look, suit, accent, Vector2(16 + lean * 0.4, -68 + bob), atk, cast, t)
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
			ci.draw_circle(Vector2(c.x + 4, c.y - 47), 4.5, accent)
			ellipse(ci, Vector2(c.x - 33, c.y), 5, 10, _shade(suit, 0.7))
			ellipse(ci, Vector2(c.x + 33, c.y), 5, 10, _shade(suit, 0.7))
		"alien":
			var skin: Color = look.skin
			ellipse(ci, c + Vector2(0, 2), 38, 35, OUTLINE)
			ellipse(ci, c + Vector2(0, 2), 36, 33, skin)
			# antennes
			for s in [-1, 1]:
				ci.draw_line(c + Vector2(s * 16, -28), c + Vector2(s * 26, -46 + sin(t * 3.0 + s) * 2), OUTLINE, 3)
				ci.draw_circle(c + Vector2(s * 26, -46 + sin(t * 3.0 + s) * 2), 4.5, accent)
			# grands yeux
			for s in [-1, 1]:
				var ec := c + Vector2(s * 15 + 1, 2)
				ellipse(ci, ec, 11, 14 * blink + 1.0, Color(0.04, 0.04, 0.08), s * 0.35)
				ellipse(ci, ec + Vector2(-2, -3), 5, 6 * blink + 0.5, Color(eye.r, eye.g, eye.b, 1.0), s * 0.35)
				ci.draw_circle(ec + Vector2(-4, -6), 2.2, Color(1, 1, 1, 0.9))
			ci.draw_arc(c + Vector2(0, 20), 7, 0.4, PI - 0.4, 8, _shade(skin, 0.6), 2.0)
			# bulle de casque
			ci.draw_circle(c + Vector2(0, 2), 40, Color(0.7, 0.9, 1.0, 0.13))
			ci.draw_arc(c + Vector2(0, 2), 40, 0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.8), 3.0)
			ci.draw_arc(c + Vector2(-4, -2), 33, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.55), 3.0)
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
			ci.draw_arc(c + Vector2(4, 2), 28, PI * 1.05, PI * 1.38, 8, Color(1, 1, 1, 0.5), 3.0)
			ci.draw_circle(c + Vector2(-26, 8), 5, accent)
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
				ci.draw_arc(c, 36 + cast * 26.0, -1.2, 1.2, 14, Color(0.6, 0.9, 1.0, 0.8 * cast), 4.0)
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
				ci.draw_arc(Vector2(hand.x + 9, hand.y - 6), 18 + 18 * maxf(cast, atk), 0, TAU, 20, Color(accent.r, accent.g, accent.b, 0.6), 3.0)
		_:
			var hand := sh + Vector2(18, 4 + raise - sin(PI * atk) * 6)
			limb(ci, sh, hand, 11, arm)
			var oc := hand + Vector2(10, -24 + sin(t * 3.0) * 3.0)
			ci.draw_circle(oc, 15 + cast * 8, Color(accent.r, accent.g, accent.b, 0.25))
			ci.draw_circle(oc, 10, accent)
			ci.draw_circle(oc + Vector2(-3, -3), 3.4, Color(1, 1, 1, 0.9))
			if atk > 0.05 and atk < 0.5:
				ci.draw_arc(oc, 14 + atk * 30.0, 0, TAU, 20, Color(accent.r, accent.g, accent.b, 1.0 - atk * 2.0), 3.0)


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
			ci.draw_circle(Vector2(7, -69 + hover), 3, Color(1, 1, 1, 0.9))
			var recoil := sin(PI * atk) * 8.0
			rrect(ci, Rect2(20 - recoil, -52 + hover, 30 if gun else 18, 11 if gun else 8), 3, Color(0.22, 0.24, 0.3))
			for s in [-1, 1]:
				ci.draw_line(Vector2(s * 22, -86 + hover), Vector2(s * 30, -98 + hover), OUTLINE, 3)
			ci.draw_circle(Vector2(-22, -88 + hover), 4, Color(1.0, 0.8, 0.2))
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
			ci.draw_circle(Vector2(-30, -136 + shake), 7, Color(1.0, 0.3 + 0.3 * sin(t * 6.0), 0.2))
	if stun:
		for k in 3:
			var a := t * 4.0 + k * TAU / 3.0
			var top := -120.0 if kind == "titan" else -110.0
			star(ci, Vector2(cos(a) * 26, top + sin(a) * 6), 5, Color(1, 0.9, 0.3))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- icône et décor

## Portrait rond d'un héros (boutons de pouvoir, liste) : on dessine la tête agrandie, sans le corps.
static func draw_portrait(ci: CanvasItem, h: Dictionary, center: Vector2, radius: float, t: float = 0.0) -> void:
	var s := radius / 38.0
	ci.draw_set_transform(center + Vector2(-2, 112) * s, 0.0, Vector2(s, s))
	_draw_head(ci, h, h.look, Vector2(2, -112), t, 0.0, 0.0, false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_background(ci: CanvasItem, rect: Rect2, t: float, stars: PackedVector2Array, boss: bool) -> void:
	var top := Color(0.02, 0.03, 0.09)
	var bot := Color(0.09, 0.07, 0.2) if not boss else Color(0.18, 0.05, 0.1)
	var bands := 14
	for i in bands:
		var k := float(i) / bands
		ci.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * k, rect.size.x, rect.size.y / bands + 1.0), top.lerp(bot, k))
	for i in stars.size():
		var s := stars[i]
		var x := fposmod(s.x * rect.size.x - t * (6.0 + (i % 3) * 5.0), rect.size.x)
		var y := s.y * rect.size.y * 0.8
		var a := 0.4 + 0.5 * (0.5 + 0.5 * sin(t * 1.5 + i))
		ci.draw_circle(rect.position + Vector2(x, y), 1.2 + (i % 3) * 0.5, Color(1, 1, 1, a))
	# planète
	var pc := rect.position + Vector2(rect.size.x * 0.78, rect.size.y * 0.3)
	ci.draw_circle(pc, 90, Color(0.12, 0.3, 0.6) if not boss else Color(0.55, 0.18, 0.15))
	ci.draw_arc(pc, 90, 0, TAU, 40, Color(0.5, 0.8, 1.0, 0.35), 3.0)
	ci.draw_circle(pc + Vector2(-26, -22), 56, Color(1, 1, 1, 0.05))
	# astéroïdes lointains
	for k in 4:
		var x := fposmod(120.0 + k * 210.0 - t * 14.0, rect.size.x + 80.0) - 40.0
		var y := rect.position.y + rect.size.y * (0.15 + 0.16 * k)
		ellipse(ci, Vector2(rect.position.x + x, y), 18 + k * 4, 12 + k * 2, Color(0.2, 0.18, 0.26))
	# sol : plateforme métallique
	var fy := rect.position.y + rect.size.y * 0.62
	ci.draw_rect(Rect2(rect.position.x, fy, rect.size.x, rect.size.y - rect.size.y * 0.62), Color(0.07, 0.1, 0.17))
	ci.draw_line(Vector2(rect.position.x, fy), Vector2(rect.end.x, fy), Color(0.3, 0.8, 1.0, 0.7), 3.0)
	for k in 12:
		var x := rect.position.x + k * 70.0 - fposmod(t * 20.0, 70.0)
		ci.draw_line(Vector2(x, fy), Vector2(x - 60, rect.end.y), Color(0.3, 0.8, 1.0, 0.12), 2.0)
	for k in 5:
		var y := fy + (rect.end.y - fy) * pow(float(k + 1) / 5.0, 1.6)
		ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.3, 0.8, 1.0, 0.12), 2.0)
