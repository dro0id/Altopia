extends Control
## Scène de combat 2D animée : le Capitaine (ou le drone) et son équipage à gauche, les ennemis à droite.
## play(battle) rejoue les coups enregistrés par Battle.simulate ; advance(dt) fait avancer l'animation.

const Data = preload("res://scripts/game_data.gd")
const Chibi = preload("res://scripts/chibi.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const UNIT := 76.0

var playing := false
var _allies: Array = []      # 1 combattant : le Capitaine (ou le drone)
var _enemies: Array = []
var _crew_nodes: Array = []  # l'équipage, en décor derrière le Capitaine
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


func _clear() -> void:
	for u in _allies + _enemies:
		u.node.queue_free()
	for n in _crew_nodes:
		n.queue_free()
	_allies.clear()
	_enemies.clear()
	_crew_nodes.clear()
	_floats.clear()


func _make_node(px: float) -> Control:
	var node: Control = Chibi.new()
	node.custom_minimum_size = Vector2(px, px)
	node.size = Vector2(px, px)
	add_child(node)
	return node


func play(b: Dictionary) -> void:
	_clear()
	for info in b.allies:
		var node := _make_node(UNIT * 1.5)
		if info.id == "captain":
			node.setup_captain(info.look)
		else:
			node.setup_drone()
		_allies.append({"node": node, "ally": true, "base": Vector2.ZERO, "off": Vector2.ZERO, "hp": info.max_hp,
			"shown": info.max_hp, "max": info.max_hp, "alive": true, "flash": 0.0})
		for cid in info.crew:
			var cn := _make_node(UNIT * 0.8)
			cn.setup_crew(cid, 0)
			_crew_nodes.append(cn)
	for info in b.enemies:
		var node := _make_node(UNIT * (1.3 if b.enemies.size() <= 2 else 1.05))
		node.setup_enemy(info.kind)
		_enemies.append({"node": node, "ally": false, "base": Vector2.ZERO, "off": Vector2.ZERO, "hp": info.max_hp,
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
	for u in _allies:
		u.base = Vector2(size.x * 0.34, size.y * 0.55)
	for i in _crew_nodes.size():
		_crew_nodes[i].position = Vector2(size.x * 0.06, size.y * (0.1 + 0.28 * i))
	for i in _enemies.size():
		var many := _enemies.size() > 2
		_enemies[i].base = Vector2(size.x * 0.8, size.y * ((0.2 + 0.25 * i) if many else (0.27 + 0.27 * i)))
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
			if ev.get("h", 0.0) > 0.0:
				att.hp = minf(att.max, att.hp + ev.h)
			tgt.flash = 1.0
			if ev.ko:
				tgt.alive = false
			_floats.append({"unit": tgt, "text": Data.fmt(ev.d), "t": 0.0, "crit": ev.get("c", false),
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
	for u in _allies + _enemies:
		var n: Control = u.node
		n.position = u.base + u.off - n.size / 2.0
		u.fade = move_toward(u.get("fade", 1.0), 1.0 if u.alive else (0.0 if not u.ally else 0.35), 0.04)
		var a: float = u.fade
		n.modulate = Color(1.0, 1.0 - u.flash * 0.6, 1.0 - u.flash * 0.6, a)


func _draw() -> void:
	# fond : dégradé nuit -> halo cyan à l'horizon, grille de sol
	var h := size.y
	var top := Color(0.02, 0.04, 0.1)
	var mid := Color(0.04, 0.12, 0.2)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, h * 0.92), Vector2(0, h * 0.92)]),
		PackedColorArray([top, top, mid, mid]))
	draw_rect(Rect2(0, h * 0.92, size.x, h * 0.08), Color(0.02, 0.05, 0.09))
	draw_line(Vector2(0, h * 0.92), Vector2(size.x, h * 0.92), UiTheme.LINE, 2.0)
	for i in range(1, 8):
		var x := size.x * i / 8.0
		draw_line(Vector2(x, h * 0.92), Vector2(size.x * 0.5 + (x - size.x * 0.5) * 1.8, h), Color(0.22, 0.9, 1.0, 0.12), 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.LINE, false, 1.0)
	for u in _allies + _enemies:
		_draw_hp(u)
	var bold := UiTheme.font(true)
	for f in _floats:
		var u: Dictionary = f.unit
		var p: Vector2 = u.base + Vector2(0, -u.node.size.y * 0.5 - 4.0) + Vector2(0, -40.0 * f.t)
		p.y = maxf(p.y, 34.0)
		var col: Color = f.col
		col.a = 1.0 - f.t / 0.9
		var txt: String = "-" + String(f.text)
		var fs: int = 34 if f.crit else 28
		draw_string_outline(bold, p + Vector2(-40, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 5, Color(0, 0, 0, col.a * 0.8))
		draw_string(bold, p + Vector2(-40, 0), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, col)
	if _ev_i >= _events.size() and playing:
		var pos := Vector2(0, size.y * 0.2)
		draw_string_outline(bold, pos, _banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 58, 8, Color(0, 0, 0, 0.8))
		draw_string(bold, pos, _banner, HORIZONTAL_ALIGNMENT_CENTER, size.x, 58, _banner_col)


func _draw_hp(u: Dictionary) -> void:
	if not u.alive and u.get("fade", 1.0) < 0.05:
		return
	var half: float = u.node.size.y / 2.0
	var c: Vector2 = u.base + u.off + Vector2(0, half - 4.0)
	var w := 92.0 if u.ally else 76.0
	var left := c + Vector2(-w / 2.0, 0)
	var ratio := clampf(u.shown / u.max, 0.0, 1.0)
	var col := Color(0.43, 1.0, 0.61) if u.ally else Color(1.0, 0.45, 0.4)
	if ratio < 0.3:
		col = Color(1.0, 0.7, 0.3)
	draw_rect(Rect2(left - Vector2(2, 2), Vector2(w + 4, 14)), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(left, Vector2(w, 10)), Color(0.07, 0.1, 0.16))
	draw_rect(Rect2(left, Vector2(w * ratio, 10)), col)
	draw_rect(Rect2(left, Vector2(w * ratio, 4)), col.lightened(0.35))
	draw_rect(Rect2(left - Vector2(2, 2), Vector2(w + 4, 14)), UiTheme.LINE, false, 1.0)
	draw_string(UiTheme.mono(), left + Vector2(-20, 28), "%s / %s" % [Data.fmt(ceilf(u.shown)), Data.fmt(u.max)], HORIZONTAL_ALIGNMENT_CENTER, w + 40, 14, UiTheme.DIM)
