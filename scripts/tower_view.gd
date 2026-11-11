class_name TowerView
extends Control
## La montée du Trou de verre (maquette D) : chemin en pointillés en zigzag, étage 1 en bas ; mini-boss et gros boss plus gros. Un appui sélectionne un étage débloqué.

signal selected(stage: int)

const Data = preload("res://scripts/data.gd")
const XS := [200.0, 130.0, 190.0, 150.0, 215.0, 165.0, 115.0, 170.0]     # abscisses (maquette, en px de 360) qui se répètent
const MARGIN := 70.0

var top_stage := 3
var sel := 1
var t := 0.0
var _press := Vector2.ZERO
var _down := false
var _pos := {}


func setup(p_top: int, p_sel: int) -> void:
	top_stage = p_top
	sel = p_sel
	# du bas (étage 1) vers le haut : écart = rayons des deux ronds + 40 px
	var y := 0.0
	var ys := {}
	var prev_r := 0.0
	for n in range(1, top_stage + 1):
		var r := _radius(n)
		if n > 1:
			y += prev_r + r + 40.0
		ys[n] = y
		prev_r = r
	var total: float = y + MARGIN * 2.0
	for n in range(1, top_stage + 1):
		_pos[n] = Vector2(XS[(top_stage - n) % XS.size()] * 2.0, MARGIN + (y - float(ys[n])))
	custom_minimum_size = Vector2(0, total)
	queue_redraw()


func center_of(n: int) -> Vector2:
	return _pos.get(n, Vector2(360, 100))


func _radius(n: int) -> float:
	match Data.boss_type(n):
		"big":
			return 58.0
		"mini":
			return 52.0
	return 48.0 if n == Game.best_stage else 36.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and not UI.emulated(ev) and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed = ev.pressed
		released = not ev.pressed
		pos = ev.position
	elif ev is InputEventScreenTouch:
		pressed = ev.pressed
		released = not ev.pressed
		pos = ev.position
	else:
		return
	if pressed:
		_press = pos
		_down = true
	elif released and _down:
		_down = false
		if pos.distance_to(_press) > 14.0:
			return
		for n in range(1, top_stage + 1):
			if pos.distance_to(center_of(n)) <= _radius(n) + 18.0 and n <= Game.best_stage:
				sel = n
				selected.emit(n)
				Sfx.play("click", -8.0)
				return


func _draw() -> void:
	# pointillés qui traversent les ronds
	for n in range(1, top_stage):
		var a := center_of(n)
		var b := center_of(n + 1)
		var len := a.distance_to(b)
		var k := 0.0
		while k < len:
			draw_circle(a.lerp(b, k / len), 3.5, Color("2b6a80"))
			k += 22.0
	for n in range(1, top_stage + 1):
		_node(n)


func _node(n: int) -> void:
	var c := center_of(n)
	var r := _radius(n)
	var bt: String = Data.boss_type(n)
	var locked := n > Game.best_stage
	var cur := n == Game.best_stage
	var col := UI.GREEN
	var fg := UI.DARK
	if bt == "mini":
		col = Color("ffb142")
		fg = Color("1a1004")
	elif bt == "big":
		col = UI.RED
		fg = Color("1a0a0a")
	if cur and bt == "":
		col = UI.ACCENT
		fg = UI.DARK
	if locked:
		col = Color(0.169, 0.227, 0.42, 0.55)
		fg = UI.MUTED
	if cur:
		var k := 0.5 + 0.5 * sin(t * 3.9)
		draw_circle(c, r + 6.0 + 8.0 * k, Color(col.r, col.g, col.b, 0.10 + 0.20 * k))
	if n == sel and n != Game.best_stage:
		draw_arc(c, r + 8.0, 0, TAU, 40, Color(0.5, 0.95, 1.0, 0.9), 4.0, true)
	draw_circle(c, r, col)
	var fs := 32 if r > 40.0 else 26
	var f := ThemeDB.fallback_font
	draw_string(UI.bold_font(), c + Vector2(-r, fs * 0.36), str(n), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, fg)
	# étiquette du côté libre (à gauche quand le rond est dans la moitié droite)
	var left := c.x >= 400.0
	var label := ""
	var sub := ""
	if bt != "":
		label = Data.boss_name(n)
		sub = "%s · ◆ %d cristaux" % ["Gros boss", int(Data.BIG_BOSS_CRYSTALS[3])] if bt == "big" else "Mini-boss"
	elif cur:
		label = "Secteur %d · en cours" % n
		sub = "Reco %d · toi %d %s" % [int(Data.recommended_power(n)), int(Game.power()), "✓" if Game.power() >= Data.recommended_power(n) else ""]
	var s := int(Game.stars.get(n, 0))
	var x := c.x - r - 16.0 if left else c.x + r + 16.0
	if label != "":
		_text(Vector2(x, c.y - 4.0), label, 24, Color.WHITE, left, true)
		_text(Vector2(x, c.y + 22.0), sub, 20, UI.MUTED, left, false)
	elif s > 0 and not locked:
		_text(Vector2(x, c.y + 8.0), "★".repeat(s) + "☆".repeat(3 - s), 24, UI.TEXT, left, false)


func _text(pos: Vector2, txt: String, fs: int, col: Color, to_left: bool, bold: bool) -> void:
	var w := 330.0
	var f: Font = UI.bold_font() if bold else ThemeDB.fallback_font
	var p := pos - Vector2(w, 0) if to_left else pos
	var al := HORIZONTAL_ALIGNMENT_RIGHT if to_left else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(f, p, txt, al, w, fs, col)
