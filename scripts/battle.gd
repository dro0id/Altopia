class_name BattleView
extends Node2D
## Champ de bataille : joue la simulation (sim.gd) et l'anime (combattants, projectiles, chiffres, décor).
## Le rectangle du champ fait 720 x 560 ; l'origine du nœud est son coin haut-gauche.

signal stage_cleared(credits: float)
signal stage_failed
signal wave_started(wave: int, total: int, boss: bool)

const Data = preload("res://scripts/data.gd")
const SIZE := Vector2(720, 560)
const ALLY_POS := [Vector2(320, 470), Vector2(240, 380), Vector2(240, 545), Vector2(140, 425), Vector2(140, 520)]
const ENEMY_POS := [Vector2(440, 470), Vector2(510, 380), Vector2(510, 545), Vector2(600, 425), Vector2(600, 520), Vector2(670, 470)]

var sim: BattleSim
var speed := 1.0
var fighters := {}                 # Unit -> Fighter
var shots: Array = []              # projectiles en vol
var texts: Array = []              # chiffres flottants
var fx: Array = []                 # effets (ondes, éclats)
var stars := PackedVector2Array()
var clock := 0.0
var boss_wave := false
var banner := ""
var banner_t := 0.0
var _result_timer := 0.0
var _done := false
var _ov: Node2D


func _ready() -> void:
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
		pos = Vector2(530, 490)
	f.setup(u, pos)
	add_child(f)
	fighters[u] = f


func _center(u: BattleSim.Unit) -> Vector2:
	var f: Fighter = fighters.get(u)
	if f == null:
		return Vector2.ZERO
	return f.home + Vector2(0, -85.0 * (1.9 if u.boss else 1.0))


func _process(delta: float) -> void:
	clock += delta
	if sim == null:
		return
	var dt := minf(delta, 0.1) * speed
	var steps := maxi(1, int(ceil(dt / 0.05)))
	for i in steps:
		sim.step(dt / steps)
		_consume()
	for s in shots:
		s.t += delta * speed
	shots = shots.filter(func(s): return s.t < s.dur)
	for x in texts:
		x.t += delta
	texts = texts.filter(func(x): return x.t < 0.9)
	for e in fx:
		e.t += delta
	fx = fx.filter(func(e): return e.t < e.dur)
	banner_t = maxf(0.0, banner_t - delta)
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


func _consume() -> void:
	for e in sim.events:
		match e.type:
			"spawn":
				_add_fighter(e.unit)
			"wave":
				boss_wave = e.boss
				banner = "BOSS !" if e.boss else "Vague %d / %d" % [e.wave, e.total]
				banner_t = 1.6
				wave_started.emit(e.wave, e.total, e.boss)
			"attack":
				var src: BattleSim.Unit = e.src
				var f: Fighter = fighters.get(src)
				if f != null:
					f.play_attack(not e.ranged)
				if e.ranged and fighters.has(e.dst):
					var col := Color(0.5, 1.0, 0.7) if e.get("heal", false) else (Color(1.0, 0.9, 0.5) if src.side == 0 else Color(1.0, 0.45, 0.3))
					shots.append({"from": _center(src) + Vector2(36 * (1 if src.side == 0 else -1), -8), "to": _center(e.dst), "t": 0.0, "dur": e.delay, "col": col, "kind": "bolt"})
			"hit":
				var u: BattleSim.Unit = e.unit
				var f2: Fighter = fighters.get(u)
				if f2 != null:
					f2.play_hurt()
				texts.append({"pos": _center(u) + Vector2(randf_range(-14, 14), -40), "txt": str(int(round(e.amount))), "col": Color(1, 0.95, 0.6) if u.side == 1 else Color(1, 0.5, 0.45), "t": 0.0})
				fx.append({"pos": _center(u), "t": 0.0, "dur": 0.25, "kind": "spark"})
			"heal":
				var u2: BattleSim.Unit = e.unit
				if e.amount >= 1.0:
					texts.append({"pos": _center(u2) + Vector2(randf_range(-14, 14), -50), "txt": "+" + str(int(round(e.amount))), "col": Color(0.5, 1, 0.65), "t": 0.0})
					fx.append({"pos": _center(u2), "t": 0.0, "dur": 0.5, "kind": "heal"})
			"cast":
				var cu: BattleSim.Unit = e.unit
				var cf: Fighter = fighters.get(cu)
				if cf != null:
					cf.play_cast()
				banner = String(cu.data.get("skill", {}).get("name", "")) if cu.side == 0 else "Écrasement !"
				banner_t = 1.0
				_cast_fx(e)
			"death":
				fx.append({"pos": _center(e.unit), "t": 0.0, "dur": 0.4, "kind": "boom"})
	sim.events.clear()


func _cast_fx(e: Dictionary) -> void:
	var u: BattleSim.Unit = e.unit
	match e.kind:
		"volley":
			var i := 0
			for t in e.targets:
				shots.append({"from": _center(u), "to": _center(t), "t": -0.08 * i, "dur": 0.45, "col": Color(1.0, 0.6, 0.3), "kind": "missile"})
				i += 1
		"pierce":
			shots.append({"from": _center(u), "to": _center(e.target), "t": 0.0, "dur": 0.4, "col": Color(0.9, 0.6, 1.0), "kind": "beam"})
		"gravity":
			fx.append({"pos": Vector2(540, 400), "t": 0.0, "dur": 0.8, "kind": "wave"})
		"shield", "repair":
			for a in sim.allies():
				if a.alive:
					fx.append({"pos": _center(a), "t": 0.0, "dur": 0.7, "kind": "heal" if e.kind == "repair" else "shield"})
		"slam":
			fx.append({"pos": Vector2(230, 470), "t": 0.0, "dur": 0.6, "kind": "wave"})


func _draw() -> void:
	Art.draw_background(self, Rect2(Vector2.ZERO, SIZE), clock, stars, boss_wave)
	# ordre de dessin : de haut en bas pour les chevauchements
	var order := fighters.values()
	order.sort_custom(func(a, b): return a.home.y < b.home.y)
	for f in order:
		f.z_index = int(f.home.y)


func _draw_overlay() -> void:
	for s in shots:
		if s.t < 0.0:
			continue
		var k: float = clampf(s.t / s.dur, 0.0, 1.0)
		var p: Vector2 = s.from.lerp(s.to, k)
		match s.kind:
			"bolt":
				_ov.draw_line(p - (s.to - s.from).normalized() * 18.0, p, s.col, 5.0, true)
				_ov.draw_circle(p, 5, Color(1, 1, 1, 0.9))
			"missile":
				var arc := p + Vector2(0, -sin(PI * k) * 60.0)
				_ov.draw_circle(arc, 6, s.col)
				_ov.draw_circle(arc - (s.to - s.from).normalized() * 12.0, 4, Color(1, 0.9, 0.5, 0.6))
			"beam":
				_ov.draw_line(s.from, p, Color(s.col.r, s.col.g, s.col.b, 1.0 - k * 0.5), 10.0 * (1.0 - k * 0.5), true)
				_ov.draw_line(s.from, p, Color(1, 1, 1, 0.9), 3.0)
	for e in fx:
		var k2: float = e.t / e.dur
		match e.kind:
			"spark":
				Art.star(_ov, e.pos, 14.0 * (1.0 - k2), Color(1, 0.95, 0.7, 1.0 - k2), k2 * 3.0)
			"boom":
				_ov.draw_circle(e.pos, 14 + 36 * k2, Color(1.0, 0.6, 0.25, 0.7 * (1.0 - k2)))
			"heal":
				_ov.draw_arc(e.pos, 24 + 10 * k2, 0, TAU, 20, Color(0.5, 1.0, 0.7, 1.0 - k2), 4.0)
				_ov.draw_line(e.pos + Vector2(0, -20 - 30 * k2), e.pos + Vector2(0, -34 - 30 * k2), Color(0.5, 1.0, 0.7, 1.0 - k2), 4.0)
			"shield":
				_ov.draw_arc(e.pos, 52, 0, TAU, 28, Color(0.5, 0.85, 1.0, 0.9 * (1.0 - k2)), 5.0)
			"wave":
				_ov.draw_arc(e.pos, 20 + 300 * k2, 0, TAU, 40, Color(0.7, 0.5, 1.0, 0.8 * (1.0 - k2)), 6.0)
	for x in texts:
		var k3: float = x.t / 0.9
		var pos: Vector2 = x.pos + Vector2(0, -34 * k3)
		var c: Color = x.col
		_ov.draw_string(ThemeDB.fallback_font, pos + Vector2(1, 1), x.txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 24, Color(0, 0, 0, 1.0 - k3))
		_ov.draw_string(ThemeDB.fallback_font, pos, x.txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 24, Color(c.r, c.g, c.b, 1.0 - k3 * 0.8))
	if banner_t > 0.0:
		var a := minf(1.0, banner_t * 2.0)
		_ov.draw_string(ThemeDB.fallback_font, Vector2(0, 90) + Vector2(2, 2), banner, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 54, Color(0, 0, 0, a))
		_ov.draw_string(ThemeDB.fallback_font, Vector2(0, 90), banner, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 54, Color(1.0, 0.85, 0.4, a) if not boss_wave else Color(1, 0.45, 0.4, a))
	if sim != null and sim.state != "fighting":
		var txt := "SECTEUR VAINCU" if sim.state == "clear" else "ESCOUADE TOMBÉE"
		_ov.draw_string(ThemeDB.fallback_font, Vector2(0, 250) + Vector2(2, 2), txt, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 56, Color(0, 0, 0))
		_ov.draw_string(ThemeDB.fallback_font, Vector2(0, 250), txt, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 56, Color(0.5, 1, 0.7) if sim.state == "clear" else Color(1, 0.5, 0.45))
