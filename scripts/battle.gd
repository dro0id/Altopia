class_name BattleView
extends Node2D
## Champ de bataille : joue la simulation (sim.gd) et l'anime (combattants, projectiles, chiffres, décor).
## Le rectangle du champ fait 720 x 560 ; l'origine du nœud est son coin haut-gauche.

signal stage_cleared(credits: float)
signal stage_failed
signal wave_started(wave: int, total: int, boss: bool)

const Data = preload("res://scripts/data.gd")
const SIZE := Vector2(720, 560)
const ALLY_POS := [Vector2(360, 445), Vector2(185, 455), Vector2(535, 455), Vector2(270, 538), Vector2(450, 538)]
const ENEMY_POS := [Vector2(360, 262), Vector2(210, 256), Vector2(510, 256), Vector2(285, 196), Vector2(435, 196), Vector2(140, 198)]

var sim: BattleSim
var speed := 1.0
var fighters := {}                 # Unit -> Fighter
var shots: Array = []              # projectiles en vol
var texts: Array = []              # chiffres flottants
var fx: Array = []                 # effets (ondes, dômes, flashs), peuvent démarrer en différé (t < 0)
var parts: Array = []              # particules (étincelles, fumée, poussière, croix de soin)
var stars := PackedVector2Array()
var clock := 0.0
var boss_wave := false
var banner := ""
var banner_t := 0.0
var shake := 0.0
var _base := Vector2.ZERO
var _result_timer := 0.0
var _done := false
var _ov: Node2D


func _ready() -> void:
	_base = position
	_ov = Node2D.new()
	_ov.z_index = 4000
	add_child(_ov)
	_ov.draw.connect(_draw_overlay)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 70:
		stars.append(Vector2(rng.randf(), rng.randf()))


func start(team: Array, stage: int, auto_cast: bool) -> void:
	for f in fighters.values():
		f.queue_free()
	fighters.clear()
	shots.clear()
	texts.clear()
	fx.clear()
	parts.clear()
	_done = false
	_result_timer = 0.0
	sim = BattleSim.new(team, stage, int(Time.get_ticks_msec()))
	sim.auto_cast = auto_cast
	for u in sim.units:
		if u.side == 0:
			_add_fighter(u)
	_consume()


func _add_fighter(u: BattleSim.Unit) -> void:
	var f := Fighter.new()
	var pos: Vector2 = ALLY_POS[u.slot] if u.side == 0 else ENEMY_POS[mini(u.slot, ENEMY_POS.size() - 1)]
	if u.boss:
		pos = Vector2(360, 272)
	f.setup(u, pos)
	add_child(f)
	fighters[u] = f


func _center(u: BattleSim.Unit) -> Vector2:
	var f: Fighter = fighters.get(u)
	if f == null:
		return Vector2.ZERO
	return f.home + Vector2(0, -62.0 * f.scale_k)


# ---------------------------------------------------------------- particules et effets

func _burst(pos: Vector2, n: int, col: Color, speed_min: float, speed_max: float, life: float, grav: float = 500.0, size: float = 3.0) -> void:
	for i in n:
		if parts.size() > 320:
			return
		var a := randf() * TAU
		parts.append({"kind": "spark", "pos": pos, "vel": Vector2(cos(a), sin(a) * 0.8) * randf_range(speed_min, speed_max), "t": 0.0, "dur": life * randf_range(0.7, 1.2), "col": col, "size": size, "grav": grav})


func _smoke(pos: Vector2, col: Color, size: float, life: float, vel: Vector2 = Vector2.ZERO) -> void:
	if parts.size() > 320:
		return
	parts.append({"kind": "smoke", "pos": pos, "vel": vel + Vector2(randf_range(-12, 12), randf_range(-24, -6)), "t": 0.0, "dur": life, "col": col, "size": size, "grav": 0.0})


func _ring_fx(pos: Vector2, col: Color, max_r: float, dur: float, delay: float = 0.0, kick: float = 0.0) -> void:
	fx.append({"kind": "ring", "pos": pos, "t": -delay, "dur": dur, "col": col, "r": max_r, "shake": kick})


func _impact(u: BattleSim.Unit, amount: float, kind: String) -> void:
	var c := _center(u)
	var ally := u.side == 0
	var col := Color(1.0, 0.55, 0.4) if ally else Color(1.0, 0.9, 0.55)
	var big := kind in ["missile", "pierce", "slam", "gravity"]
	fx.append({"kind": "flash", "pos": c, "t": 0.0, "dur": 0.16, "r": 26.0 if big else 16.0})
	_burst(c, 12 if big else 7, col, 120.0, 300.0 if big else 220.0, 0.4)
	_ring_fx(c + Vector2(0, 30), col, 46.0 if big else 30.0, 0.3)
	if big:
		for i in 3:
			_smoke(c, Color(0.35, 0.3, 0.3), 12.0, 0.7)
		shake = maxf(shake, 4.0 if kind != "slam" else 7.0)
	elif ally and u.role != "enemy":
		shake = maxf(shake, 1.5)


func _consume() -> void:
	for e in sim.events:
		match e.type:
			"spawn":
				_add_fighter(e.unit)
				var f: Fighter = fighters.get(e.unit)
				if f != null:
					fx.append({"kind": "ring", "pos": f.home + Vector2(0, 2), "t": -0.25, "dur": 0.35, "col": Color(1.0, 0.4, 0.3), "r": 40.0 * f.scale_k, "shake": 1.0 if e.unit.boss else 0.0})
					_burst(f.home, 5, Color(0.7, 0.6, 0.5), 40.0, 110.0, 0.5, 200.0, 2.5)
			"wave":
				boss_wave = e.boss
				var bt: String = e.get("boss_type", "")
				banner = ("GROS BOSS !" if bt == "big" else "MINI-BOSS !") if e.boss else "Vague %d / %d" % [e.wave, e.total]
				banner_t = 1.6
				wave_started.emit(e.wave, e.total, e.boss)
				if e.boss:
					shake = maxf(shake, 6.0)
			"warn":
				fx.append({"kind": "warn", "pos": Vector2(360, 480), "t": 0.0, "dur": 0.9, "col": Color(1.0, 0.3, 0.25), "r": 300.0})
				banner = "Attention !"
				banner_t = 0.9
				Sfx.play("warn")
			"phase":
				banner = "PHASE 2 !"
				banner_t = 1.6
				boss_wave = true
				shake = maxf(shake, 9.0)
				var bf: Fighter = fighters.get(e.unit)
				if bf != null:
					fx.append({"kind": "flash", "pos": _center(e.unit), "t": 0.0, "dur": 0.4, "r": 90.0})
				Sfx.play("boom")
			"attack":
				var src: BattleSim.Unit = e.src
				var f2: Fighter = fighters.get(src)
				if f2 != null:
					f2.play_attack(not e.ranged)
				if e.ranged and fighters.has(e.dst):
					var col := Color(0.5, 1.0, 0.7) if e.get("heal", false) else (Color(1.0, 0.9, 0.5) if src.side == 0 else Color(1.0, 0.45, 0.3))
					var sc: float = f2.scale_k if f2 != null else 1.0
					var origin := _center(src)
					if src.side == 0:
						origin += Vector2(0, -34.0 * sc)
					else:
						origin += Vector2((36.0 if src.slot % 2 == 0 else -36.0) * sc, 10.0 * sc)
					var lead := 0.15
					Sfx.play("shoot", -8.0, randf_range(0.9, 1.15))
					shots.append({"from": origin, "to": _center(e.dst), "t": -lead, "dur": maxf(0.1, e.delay - lead), "col": col, "kind": "bolt"})
			"hit":
				var u: BattleSim.Unit = e.unit
				var f3: Fighter = fighters.get(u)
				if f3 != null:
					f3.play_hurt()
				texts.append({"pos": _center(u) + Vector2(randf_range(-14, 14), -40), "txt": str(int(round(e.amount))), "col": Color(1, 0.95, 0.6) if u.side == 1 else Color(1, 0.5, 0.45), "t": 0.0, "dx": randf_range(-18, 18)})
				_impact(u, e.amount, String(e.get("fx", "")))
				Sfx.play("hit", -10.0, randf_range(0.85, 1.2))
			"heal":
				var u2: BattleSim.Unit = e.unit
				if e.amount >= 1.0:
					texts.append({"pos": _center(u2) + Vector2(randf_range(-14, 14), -50), "txt": "+" + str(int(round(e.amount))), "col": Color(0.5, 1, 0.65), "t": 0.0, "dx": 0.0})
					for i in 3:
						parts.append({"kind": "cross", "pos": _center(u2) + Vector2(randf_range(-22, 22), randf_range(-10, 20)), "vel": Vector2(0, -40 - randf() * 30), "t": -i * 0.1, "dur": 0.8, "col": Color(0.5, 1.0, 0.7), "size": 7.0, "grav": 0.0})
			"cast":
				var cu: BattleSim.Unit = e.unit
				var cf: Fighter = fighters.get(cu)
				if cf != null:
					cf.play_cast()
				banner = String(cu.data.get("skill", {}).get("name", "")) if cu.side == 0 else "Écrasement !"
				banner_t = 1.0
				Sfx.play("cast", -4.0)
				_cast_fx(e)
			"death":
				var dc := _center(e.unit)
				var boss: bool = e.unit.boss
				Sfx.play("boom", -4.0 if boss else -9.0, 1.0 if boss else randf_range(0.9, 1.2))
				fx.append({"kind": "flash", "pos": dc, "t": 0.0, "dur": 0.3, "r": 60.0 if boss else 34.0})
				_burst(dc, 22 if boss else 12, Color(1.0, 0.6, 0.25), 80.0, 340.0 if boss else 240.0, 0.7)
				for i in (7 if boss else 3):
					_smoke(dc + Vector2(randf_range(-20, 20), randf_range(-20, 20)), Color(0.3, 0.28, 0.3), 16.0 if boss else 10.0, 1.0)
				_ring_fx(dc + Vector2(0, 40), Color(1.0, 0.6, 0.3), 110.0 if boss else 60.0, 0.5, 0.0, 10.0 if boss else 2.5)
	sim.events.clear()


func _cast_fx(e: Dictionary) -> void:
	var u: BattleSim.Unit = e.unit
	match e.kind:
		"volley":
			var i := 0
			var from := _center(u) + Vector2(0, -30)
			_burst(from, 8, Color(1.0, 0.75, 0.4), 60.0, 200.0, 0.4, 200.0)
			for t in e.targets:
				shots.append({"from": from, "to": _center(t), "t": -0.08, "dur": 0.45 + i * 0.1, "col": Color(1.0, 0.6, 0.3), "kind": "missile", "side": 1.0 if i % 2 == 0 else -1.0})
				i += 1
		"pierce":
			shots.append({"from": _center(u) + Vector2(0, -30), "to": _center(e.target), "t": 0.0, "dur": 0.62, "col": Color(0.9, 0.6, 1.0), "kind": "beam"})
		"gravity":
			var c := Vector2(360, 235)
			for k in 3:
				fx.append({"kind": "pull", "pos": c, "t": -k * 0.15, "dur": 0.6, "col": Color(0.75, 0.5, 1.0), "r": 200.0 - k * 30.0})
			for i in 14:
				var a := randf() * TAU
				parts.append({"kind": "mote", "pos": c + Vector2(cos(a) * 220.0, sin(a) * 90.0), "vel": -Vector2(cos(a) * 340.0, sin(a) * 140.0), "t": 0.0, "dur": 0.6, "col": Color(0.8, 0.55, 1.0), "size": 5.0, "grav": 0.0})
		"shield":
			for a in sim.allies():
				if a.alive:
					fx.append({"kind": "dome", "pos": _center(a), "t": 0.0, "dur": 0.9, "col": Color(0.5, 0.85, 1.0), "r": 52.0})
		"repair":
			for a in sim.allies():
				if a.alive:
					for i in 4:
						parts.append({"kind": "cross", "pos": _center(a) + Vector2(randf_range(-26, 26), randf_range(0, 40)), "vel": Vector2(randf_range(-10, 10), -50 - randf() * 40), "t": -i * 0.12, "dur": 0.9, "col": Color(0.5, 1.0, 0.7), "size": 8.0, "grav": 0.0})
		"slam":
			# le Titan bondit puis retombe : l'onde de choc et les secousses partent à l'atterrissage
			_ring_fx(Vector2(360, 480), Color(1.0, 0.5, 0.35), 340.0, 0.7, 0.5, 12.0)
			_ring_fx(Vector2(360, 480), Color(1.0, 0.8, 0.5), 220.0, 0.55, 0.55)
			for i in 12:
				parts.append({"kind": "dust", "pos": Vector2(360 + randf_range(-60, 60), 300), "vel": Vector2(randf_range(-260, 260), randf_range(-30, 30)), "t": -0.5, "dur": 0.9, "col": Color(0.65, 0.58, 0.5), "size": 14.0, "grav": 0.0})


func _process(delta: float) -> void:
	clock += delta
	if sim == null:
		return
	var dt := minf(delta, 0.1) * speed
	var steps := maxi(1, int(ceil(dt / 0.05)))
	for i in steps:
		sim.step(dt / steps)
		_consume()
	var ds := delta * speed
	for s in shots:
		s.t += ds
		if s.kind == "missile" and s.t > 0.0 and s.t < s.dur:
			_smoke(_shot_pos(s), Color(0.8, 0.75, 0.7), 5.0, 0.45)
	shots = shots.filter(func(s): return s.t < s.dur)
	for x in texts:
		x.t += delta
	texts = texts.filter(func(x): return x.t < 0.9)
	for e in fx:
		e.t += delta
		if e.t >= 0.0 and not e.get("fired", false):
			e.fired = true
			if e.get("shake", 0.0) > 0.0:
				shake = maxf(shake, e.shake)
	fx = fx.filter(func(e): return e.t < e.dur)
	for p in parts:
		p.t += ds
		if p.t > 0.0:
			p.pos += p.vel * ds
			p.vel.y += p.grav * ds
			if p.kind == "spark":
				p.vel *= maxf(0.0, 1.0 - 2.2 * ds)
	parts = parts.filter(func(p): return p.t < p.dur)
	banner_t = maxf(0.0, banner_t - delta)
	shake = maxf(0.0, shake - delta * 30.0)
	position = _base + (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake if shake > 0.0 else Vector2.ZERO)
	if sim.state != "fighting" and not _done:
		_result_timer += delta
		if _result_timer > 1.4:
			_done = true
			if sim.state == "clear":
				stage_cleared.emit(sim.credits)
			else:
				stage_failed.emit()
	queue_redraw()
	_ov.queue_redraw()


func _shot_pos(s: Dictionary) -> Vector2:
	var k: float = clampf(s.t / s.dur, 0.0, 1.0)
	var p: Vector2 = s.from.lerp(s.to, k)
	if s.kind == "missile":
		var lateral: Vector2 = Vector2(s.get("side", 1.0) * sin(PI * k) * 46.0, -sin(PI * k) * 70.0)
		p += lateral
	return p


func _draw() -> void:
	Art.draw_background(self, Rect2(Vector2.ZERO, SIZE), clock, stars, boss_wave)
	var order := fighters.values()
	order.sort_custom(func(a, b): return a.home.y < b.home.y)
	for f in order:
		f.z_index = int(f.home.y)


func _ellipse_line(c: Vector2, r: float, col: Color, w: float, flat: float = 0.4) -> void:
	if r < 3.0 or col.a <= 0.01:
		return
	var pts := PackedVector2Array()
	for i in 17:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * flat))
	_ov.draw_polyline(pts, col, w)


func _draw_overlay() -> void:
	for s in shots:
		if s.t < 0.0:
			continue
		var k: float = clampf(s.t / s.dur, 0.0, 1.0)
		var p := _shot_pos(s)
		var dir: Vector2 = (s.to - s.from).normalized()
		if dir.length() < 0.5:
			continue
		match s.kind:
			"bolt":
				var len := 46.0
				var n := Vector2(-dir.y, dir.x)
				var tail: Vector2 = p - dir * len
				var col: Color = s.col
				_ov.draw_colored_polygon(PackedVector2Array([p + n * 9.0, p - n * 9.0, tail]), Color(col.r, col.g, col.b, 0.25))
				_ov.draw_colored_polygon(PackedVector2Array([p + n * 4.5, p - n * 4.5, tail]), col)
				_ov.draw_colored_polygon(PackedVector2Array([p + n * 2.0, p - n * 2.0, p - dir * len * 0.6]), Color(1, 1, 1, 0.95))
				Art.disc(_ov, p, 6.0, Color(1, 1, 1, 0.95))
			"missile":
				var ahead := _shot_pos({"from": s.from, "to": s.to, "t": minf(s.t + 0.02, s.dur), "dur": s.dur, "kind": "missile", "side": s.get("side", 1.0)})
				var d2: Vector2 = (ahead - p).normalized()
				if d2.length() < 0.5:
					continue
				var n2 := Vector2(-d2.y, d2.x)
				_ov.draw_colored_polygon(PackedVector2Array([p - d2 * 8.0 + n2 * 5.0, p + d2 * 10.0, p - d2 * 8.0 - n2 * 5.0]), Color(0.85, 0.85, 0.9))
				_ov.draw_colored_polygon(PackedVector2Array([p - d2 * 8.0 + n2 * 3.0, p - d2 * (16.0 + randf() * 8.0), p - d2 * 8.0 - n2 * 3.0]), Color(1.0, 0.65, 0.2, 0.9))
			"beam":
				var col2: Color = s.col
				if k < 0.45:
					var ck := k / 0.45
					Art.disc(_ov, s.from, 8.0 + 22.0 * ck, Color(col2.r, col2.g, col2.b, 0.35))
					Art.disc(_ov, s.from, 4.0 + 10.0 * ck, Color(1, 1, 1, 0.9))
					for i in 5:
						var a := clock * 9.0 + i * TAU / 5.0
						Art.shard(_ov, s.from + Vector2(cos(a), sin(a)) * (34.0 * (1.0 - ck) + 10.0), 4.0, a, col2)
				else:
					var bk := (k - 0.45) / 0.55
					var w := 20.0 * (1.0 - bk * 0.7) * (0.8 + 0.2 * sin(clock * 60.0))
					_ov.draw_line(s.from, s.to, Color(col2.r, col2.g, col2.b, 0.4 * (1.0 - bk)), w * 2.0)
					_ov.draw_line(s.from, s.to, col2, w)
					_ov.draw_line(s.from, s.to, Color(1, 1, 1, 1.0 - bk * 0.5), w * 0.35)
					Art.star(_ov, s.to, 24.0 * (1.0 - bk), Color(1, 1, 1, 0.9), clock * 8.0)
	for e in fx:
		if e.t < 0.0:
			continue
		var k2: float = e.t / e.dur
		match e.kind:
			"ring":
				_ellipse_line(e.pos, e.r * (1.0 - pow(1.0 - k2, 2.0)), Color(e.col.r, e.col.g, e.col.b, 0.85 * (1.0 - k2)), 6.0 * (1.0 - k2) + 1.0)
			"flash":
				Art.ellipse(_ov, e.pos, e.r * (0.6 + k2), e.r * (0.6 + k2), Color(1, 0.95, 0.8, 0.8 * (1.0 - k2)), clock * 3.0, 8)
			"dome":
				var rise := minf(1.0, k2 * 4.0)
				if rise < 0.08:
					continue
				var fade := 1.0 - maxf(0.0, (k2 - 0.6) / 0.4)
				var pts := PackedVector2Array()
				for i in 7:
					var a := PI + PI * i / 6.0
					pts.append(e.pos + Vector2(cos(a) * e.r, sin(a) * e.r * 1.1) * rise + Vector2(0, 14))
				pts.append(e.pos + Vector2(e.r * rise, 14))
				pts.append(e.pos + Vector2(-e.r * rise, 14))
				_ov.draw_colored_polygon(pts, Color(e.col.r, e.col.g, e.col.b, 0.18 * fade))
				pts.append(pts[0])
				_ov.draw_polyline(pts, Color(e.col.r, e.col.g, e.col.b, 0.9 * fade), 3.0)
				_ellipse_line(e.pos + Vector2(0, 26), e.r * rise, Color(e.col.r, e.col.g, e.col.b, 0.7 * fade), 3.0)
			"warn":
				var wk := sin(k2 * PI * 5.0)
				_ellipse_line(e.pos, e.r, Color(e.col.r, e.col.g, e.col.b, 0.35 + 0.35 * wk), 8.0, 0.32)
				Art.ellipse(_ov, e.pos, e.r, e.r * 0.32, Color(e.col.r, e.col.g, e.col.b, 0.10 + 0.08 * wk), 0.0, 12)
			"pull":
				_ellipse_line(e.pos, e.r * (1.0 - k2), Color(e.col.r, e.col.g, e.col.b, 0.8 * (1.0 - k2 * 0.5)), 5.0, 0.38)
	for p in parts:
		if p.t < 0.0:
			continue
		var pk: float = p.t / p.dur
		var pc: Color = p.col
		match p.kind:
			"spark":
				_ov.draw_line(p.pos, p.pos - p.vel * 0.045, Color(pc.r, pc.g, pc.b, 1.0 - pk), maxf(1.0, p.size * (1.0 - pk)))
			"smoke":
				Art.ellipse(_ov, p.pos, p.size * (1.0 + pk * 1.6), p.size * (1.0 + pk * 1.6), Color(pc.r, pc.g, pc.b, 0.5 * (1.0 - pk)), pk * 2.0, 8)
			"dust":
				Art.ellipse(_ov, p.pos, p.size * (1.0 + pk), p.size * 0.6 * (1.0 + pk), Color(pc.r, pc.g, pc.b, 0.5 * (1.0 - pk)), 0.0, 8)
			"cross":
				var cs: float = p.size * (1.0 - pk * 0.3)
				_ov.draw_line(p.pos + Vector2(-cs, 0), p.pos + Vector2(cs, 0), Color(pc.r, pc.g, pc.b, 1.0 - pk), 4.0)
				_ov.draw_line(p.pos + Vector2(0, -cs), p.pos + Vector2(0, cs), Color(pc.r, pc.g, pc.b, 1.0 - pk), 4.0)
			"mote":
				Art.shard(_ov, p.pos, p.size, clock * 6.0 + pk * 8.0, Color(pc.r, pc.g, pc.b, 1.0 - pk * 0.7))
	for x in texts:
		var k3: float = x.t / 0.9
		var pop := maxf(0.0, 1.0 - x.t / 0.18)
		var pos: Vector2 = x.pos + Vector2(x.dx * k3, -44 * k3 + 24 * k3 * k3)
		var c: Color = x.col
		var fs := int(22 + 18 * pop)
		_ov.draw_string(ThemeDB.fallback_font, pos + Vector2(1, 1), x.txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color(0, 0, 0, 1.0 - k3))
		_ov.draw_string(ThemeDB.fallback_font, pos, x.txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color(c.r, c.g, c.b, 1.0 - k3 * 0.8))
	if banner_t > 0.0:
		var a := minf(1.0, banner_t * 2.0)
		var slide := (1.0 - minf(1.0, (1.6 - banner_t) * 6.0)) * 40.0 if banner_t > 1.0 else 0.0
		_ov.draw_string(ThemeDB.fallback_font, Vector2(slide, 90) + Vector2(2, 2), banner, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 54, Color(0, 0, 0, a))
		_ov.draw_string(ThemeDB.fallback_font, Vector2(slide, 90), banner, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 54, Color(1.0, 0.85, 0.4, a) if not boss_wave else Color(1, 0.45, 0.4, a))
	if sim != null and sim.state != "fighting":
		var txt := "SECTEUR VAINCU" if sim.state == "clear" else "ESCOUADE TOMBÉE"
		_ov.draw_string(ThemeDB.fallback_font, Vector2(0, 250) + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 56, Color(0, 0, 0))
		_ov.draw_string(ThemeDB.fallback_font, Vector2(0, 250), txt, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 56, Color(0.5, 1, 0.7) if sim.state == "clear" else Color(1, 0.5, 0.45))
