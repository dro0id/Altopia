extends Control
## Scène de combat 2D animée : les héros (gauche) affrontent les ennemis (droite).
## play(battle) rejoue les coups enregistrés par Battle.simulate ; advance(dt) fait avancer l'animation.

const Data = preload("res://scripts/game_data.gd")
const Portrait = preload("res://scripts/portrait.gd")

const UNIT := 76.0

var playing := false
var _allies: Array = []
var _enemies: Array = []
var _events: Array = []
var _ev_i := 0
var _ev_t := 0.0
var _step := 0.5
var _applied := false
var _floats: Array = []
var _banner_t := 0.0
var _banner := ""
var _banner_col := Color.WHITE


func _init() -> void:
	custom_minimum_size = Vector2(0, 350)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	resized.connect(_layout)


func play(b: Dictionary) -> void:
	for u in _allies:
		u.node.queue_free()
	_allies.clear()
	_enemies.clear()
	_floats.clear()
	for info in b.allies:
		var node: Control = Portrait.new()
		node.custom_minimum_size = Vector2(UNIT, UNIT)
		node.size = Vector2(UNIT, UNIT)
		add_child(node)
		node.setup(info.id, info.stars)
		_allies.append({"node": node, "base": Vector2.ZERO, "off": Vector2.ZERO, "hp": info.max_hp,
			"shown": info.max_hp, "max": info.max_hp, "alive": true, "flash": 0.0})
	for info in b.enemies:
		_enemies.append({"base": Vector2.ZERO, "off": Vector2.ZERO, "hp": info.max_hp,
			"shown": info.max_hp, "max": info.max_hp, "alive": true, "flash": 0.0})
	_events = b.events
	_step = 0.5 if _events.size() <= 24 else (0.3 if _events.size() <= 60 else 0.18)
	_ev_i = 0
	_ev_t = 0.0
	_applied = false
	_banner_t = 0.0
	_banner = "VICTOIRE !" if b.win else "DÉFAITE..."
	_banner_col = Color(0.5, 1.0, 0.6) if b.win else Color(1.0, 0.5, 0.45)
	playing = true
	_layout()
	_sync_nodes()
	queue_redraw()


func _layout() -> void:
	for i in _allies.size():
		_allies[i].base = Vector2(size.x * 0.2, size.y * (0.18 + 0.31 * i))
	for i in _enemies.size():
		_enemies[i].base = Vector2(size.x * 0.8, size.y * (0.18 + 0.31 * i))
	_sync_nodes()


func _unit(side: int, idx: int) -> Dictionary:
	return _allies[idx] if side == 0 else _enemies[idx]


func _process(delta: float) -> void:
	if playing and is_visible_in_tree():
		advance(delta)


func advance(dt: float) -> void:
	if not playing:
		return
	for f in _floats:
		f.t += dt
	_floats = _floats.filter(func(f): return f.t < 0.9)
	for u in _allies + _enemies:
		u.shown = move_toward(u.shown, u.hp, u.max * dt * 1.6)
		u.flash = maxf(0.0, u.flash - dt * 3.0)
	if _ev_i < _events.size():
		_ev_t += dt
		var ev: Dictionary = _events[_ev_i]
		var att := _unit(ev.s, ev.a)
		var tgt := _unit(1 - ev.s, ev.t)
		var ph := clampf(_ev_t / _step, 0.0, 1.0)
		att.off = (tgt.base - att.base) * 0.42 * sin(ph * PI)
		if ph >= 0.5 and not _applied:
			_applied = true
			tgt.hp = maxf(0.0, tgt.hp - ev.d)
			tgt.flash = 1.0
			if ev.ko:
				tgt.alive = false
			_floats.append({"pos": tgt.base + Vector2(0, -52), "text": str(int(ev.d)), "t": 0.0,
				"col": Color(1.0, 0.85, 0.4) if ev.s == 0 else Color(1.0, 0.5, 0.45)})
		if _ev_t >= _step:
			att.off = Vector2.ZERO
			_ev_i += 1
			_ev_t = 0.0
			_applied = false
	else:
		_banner_t += dt
		if _banner_t > 1.8:
			playing = false
	_sync_nodes()
	queue_redraw()


func _sync_nodes() -> void:
	for u in _allies:
		u.node.position = u.base + u.off - Vector2(UNIT, UNIT) / 2.0
		var a := 1.0 if u.alive else 0.25
		u.node.modulate = Color(1.0, 1.0 - u.flash * 0.6, 1.0 - u.flash * 0.6, a)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.13, 0.95))
	draw_line(Vector2(0, size.y * 0.92), Vector2(size.x, size.y * 0.92), Color(0.2, 0.3, 0.6, 0.6), 2.0)
	for u in _enemies:
		_draw_enemy(u)
	for u in _allies + _enemies:
		_draw_hp(u)
	var font := ThemeDB.fallback_font
	for f in _floats:
		var p: Vector2 = f.pos + Vector2(0, -60.0 * f.t)
		var col: Color = f.col
		col.a = 1.0 - f.t / 0.9
		draw_string(font, p + Vector2(-30, 0), "-" + f.text, HORIZONTAL_ALIGNMENT_CENTER, 60, 28, col)
	if _ev_i >= _events.size() and playing:
		draw_string(font, Vector2(0, size.y * 0.52), _banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 54, _banner_col)


func _draw_hp(u: Dictionary) -> void:
	var c: Vector2 = u.base + u.off + Vector2(0, UNIT / 2.0 + 10.0)
	var w := 70.0
	draw_rect(Rect2(c + Vector2(-w / 2.0, 0), Vector2(w, 8)), Color(0.1, 0.12, 0.2))
	var ratio := clampf(u.shown / u.max, 0.0, 1.0)
	var col := Color(0.4, 0.95, 0.5) if u.has("node") else Color(1.0, 0.45, 0.4)
	draw_rect(Rect2(c + Vector2(-w / 2.0, 0), Vector2(w * ratio, 8)), col)


func _draw_enemy(u: Dictionary) -> void:
	var c: Vector2 = u.base + u.off
	var a := 1.0 if u.alive else 0.25
	var body := Color(0.55, 0.12, 0.16, a).lerp(Color(1, 1, 1, a), u.flash * 0.7)
	for i in 8:
		var ang := TAU * i / 8.0
		draw_line(c + Vector2(cos(ang), sin(ang)) * 24.0, c + Vector2(cos(ang), sin(ang)) * 40.0, body, 7.0)
	draw_circle(c, 28.0, body)
	draw_circle(c + Vector2(-9, -5), 5.0, Color(1.0, 0.9, 0.3, a))
	draw_circle(c + Vector2(9, -5), 5.0, Color(1.0, 0.9, 0.3, a))
