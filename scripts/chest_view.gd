class_name ChestView
extends Control
## Coffre animé : tremble de plus en plus fort (suspense proportionnel à la rareté), puis s'ouvre avec une mise en scène propre à sa rareté.

signal opened
signal armed_changed

const Data = preload("res://scripts/data.gd")
const SUSPENSE := [1.0, 1.1, 1.3, 1.6, 2.0, 2.6]

var rarity := "commun"
var t := 0.0
var open_at := 1.0
var _fired := false
var _tier := 0
var _parts: Array = []        # étincelles, éclats, flammes : {pos, vel, t, dur, kind, col, size}
var _rings: Array = []        # ondes de choc : {t, dur, col, r}
var _flash := 0.0
var _bolts: Array = []        # éclairs de l'ultime
var chest_scale := 1.15
var armed := false             # le coffre reste immobile jusqu'à ce qu'on le touche
var _t0 := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(520, 300)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_rarity: String) -> void:
	rarity = p_rarity
	_tier = Data.RARITIES.find(rarity)
	open_at = SUSPENSE[_tier]


func arm() -> void:
	if not armed:
		armed = true
		_t0 = t
		Sfx.play("click", -4.0)
		armed_changed.emit()


func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and not UI.emulated(ev) and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		arm()


func _process(delta: float) -> void:
	t += delta
	if armed and t - _t0 >= open_at and not _fired:
		_fired = true
		_burst()
		opened.emit()
	for p in _parts:
		p.t += delta
		p.pos += p.vel * delta
		p.vel.y += (p.get("grav", 400.0)) * delta
	_parts = _parts.filter(func(p): return p.t < p.dur)
	for r in _rings:
		r.t += delta
	_rings = _rings.filter(func(r): return r.t < r.dur)
	_flash = maxf(0.0, _flash - delta * 1.6)
	queue_redraw()


## Mise en scène de l'ouverture : de plus en plus spectaculaire avec la rareté.
func _burst() -> void:
	var col: Color = Data.CHEST_COLORS[rarity]
	var c := Vector2(size.x * 0.5, size.y - 120.0)
	var n := 16 + _tier * 12
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(120.0, 260.0 + _tier * 70.0)
		_parts.append({"pos": c, "vel": Vector2(cos(a), sin(a) * 0.9 - 0.6) * sp, "t": 0.0, "dur": randf_range(0.7, 1.4), "kind": "spark", "col": col.lightened(randf() * 0.4), "size": randf_range(2.5, 4.5), "grav": 380.0})
	for k in _tier + 1:
		_rings.append({"t": -0.12 * k, "dur": 0.6 + 0.1 * k, "col": col, "r": 140.0 + 70.0 * k + 25.0 * _tier})
	Sfx.play("chest", 0.0, 0.85 + 0.06 * _tier)
	if _tier >= 3:
		for i in 10:
			var a2 := randf() * TAU
			_parts.append({"pos": c, "vel": Vector2(cos(a2), sin(a2)) * randf_range(180.0, 360.0), "t": 0.0, "dur": 1.2, "kind": "shard", "col": col, "size": randf_range(9.0, 15.0), "grav": 200.0})
		Sfx.play("star", -2.0, 0.8)
	if _tier >= 4:
		_flash = 0.9
		for i in 28:
			_parts.append({"pos": c + Vector2(randf_range(-60.0, 60.0), 0.0), "vel": Vector2(randf_range(-60.0, 60.0), randf_range(-420.0, -180.0)), "t": 0.0, "dur": randf_range(0.8, 1.5), "kind": "flame", "col": col, "size": randf_range(10.0, 20.0), "grav": -60.0})
		Sfx.play("boom", -6.0, 1.1)
		Sfx.play("win", -2.0)
	if _tier >= 5:
		_flash = 1.0
		for i in 6:
			var pts := PackedVector2Array()
			var p := c
			var dir := Vector2.from_angle(randf() * TAU)
			for j in 7:
				pts.append(p)
				p += dir * randf_range(30.0, 60.0) + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
			_bolts.append({"pts": pts, "t": -0.05 * i})
		Sfx.play("boom", 0.0, 0.7)


func _draw() -> void:
	var col: Color = Data.CHEST_COLORS[rarity]
	var tt := (t - _t0) if armed else 0.0
	var k := clampf(tt / open_at, 0.0, 1.0)
	# avant l'ouverture : l'énergie monte, d'autant plus fort que le coffre est rare
	if tt < open_at and _tier >= 2:
		var charge := k * k
		Art.ellipse(self, Vector2(size.x * 0.5, size.y - 90.0), 90.0 + 90.0 * charge, 50.0 + 40.0 * charge, Color(col.r, col.g, col.b, 0.1 + 0.4 * charge), t * 2.0, 8)
	if _tier == 5 and tt < open_at:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.0, 0.0, 0.35 * k))
	var shake := (2.0 + _tier * 1.6) * k if tt < open_at else 0.0
	var open := clampf((tt - open_at) / 0.5, 0.0, 1.0)
	Art.draw_chest(self, Vector2(size.x * 0.5, size.y - 26.0), chest_scale, rarity, t, open, shake)
	var c := Vector2(size.x * 0.5, size.y - 120.0)
	for r in _rings:
		if r.t < 0.0:
			continue
		var kk: float = r.t / r.dur
		var rad: float = r.r * (1.0 - pow(1.0 - kk, 2.0))
		if rad > 3.0:
			var pts := PackedVector2Array()
			for i in 17:
				var a := TAU * i / 16.0
				pts.append(c + Vector2(cos(a) * rad, sin(a) * rad * 0.4))
			draw_polyline(pts, Color(r.col.r, r.col.g, r.col.b, 0.9 * (1.0 - kk)), 5.0 * (1.0 - kk) + 1.0)
	for p in _parts:
		var pk: float = p.t / p.dur
		var pc: Color = p.col
		match p.kind:
			"spark":
				draw_line(p.pos, p.pos - p.vel * 0.04, Color(pc.r, pc.g, pc.b, 1.0 - pk), p.size * (1.0 - pk) + 1.0)
			"shard":
				Art.shard(self, p.pos, p.size * (1.0 - pk * 0.5), t * 6.0 + p.pos.x * 0.1, Color(pc.r, pc.g, pc.b, 1.0 - pk))
			"flame":
				Art.shard(self, p.pos, p.size * (1.0 - pk), -PI * 0.5, Color(pc.r, pc.g * 0.85, pc.b * 0.6, 0.85 * (1.0 - pk)))
	for b in _bolts:
		b.t += get_process_delta_time()
		if b.t >= 0.0 and b.t < 0.35:
			draw_polyline(b.pts, Color(1.0, 0.45, 0.4, 1.0 - b.t / 0.35), 4.0)
			draw_polyline(b.pts, Color(1, 1, 1, 0.8 * (1.0 - b.t / 0.35)), 1.5)
	if _flash > 0.0:
		draw_rect(Rect2(-40, -40, size.x + 80, size.y + 80), Color(1.0, 0.95, 0.85, 0.55 * _flash))
