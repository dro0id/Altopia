class_name TowerView
extends Control
## La montée du Trou de verre : un chemin en zigzag, étage 1 en bas, avec mini-boss et gros boss plus gros. Un appui sélectionne un étage débloqué.

signal selected(stage: int)

const Data = preload("res://scripts/data.gd")
const STEP := 118.0
const MARGIN := 70.0

var top_stage := 3
var sel := 1
var t := 0.0
var _press := Vector2.ZERO
var _down := false


func setup(p_top: int, p_sel: int) -> void:
	top_stage = p_top
	sel = p_sel
	custom_minimum_size = Vector2(0, MARGIN * 2.0 + STEP * (top_stage - 1))
	queue_redraw()


func center_of(n: int) -> Vector2:
	var y := MARGIN + STEP * (top_stage - n)
	var x := 360.0 + 150.0 * sin(float(n) * 0.95) + 40.0 * sin(float(n) * 2.1)
	return Vector2(x, y)


func _radius(n: int) -> float:
	match Data.boss_type(n):
		"big":
			return 46.0
		"mini":
			return 38.0
	return 30.0 if n != sel else 36.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
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
	# chemin : plein jusqu'à l'étage débloqué, pointillé au-delà
	for n in range(1, top_stage):
		var a := center_of(n)
		var b := center_of(n + 1)
		if n < Game.best_stage:
			draw_line(a, b, Color(0.3, 0.9, 0.7, 0.55), 6.0, true)
		else:
			draw_dashed_line(a, b, Color(0.3, 0.55, 0.7, 0.6), 4.0, 12.0, true)
	for n in range(1, top_stage + 1):
		_node(n)


func _node(n: int) -> void:
	var c := center_of(n)
	var r := _radius(n)
	var locked := n > Game.best_stage
	var bt: String = Data.boss_type(n)
	var done := n < Game.best_stage
	var col := Color(0.17, 0.23, 0.42)
	var fg := Color.WHITE
	if bt == "mini":
		col = Color(1.0, 0.69, 0.26)
		fg = Color(0.1, 0.06, 0.02)
	elif bt == "big":
		col = Color(1.0, 0.42, 0.42)
		fg = Color(0.1, 0.03, 0.03)
	elif done:
		col = UI.GREEN
		fg = Color(0.02, 0.1, 0.06)
	if n == Game.best_stage and bt == "":
		col = UI.ACCENT
		fg = Color(0.02, 0.08, 0.12)
	if locked:
		col = col.darkened(0.45)
		fg = Color(0.7, 0.75, 0.85, 0.8)
	if n == sel:
		var k := 0.5 + 0.5 * sin(t * 4.0)
		draw_arc(c, r + 10.0 + 3.0 * k, 0, TAU, 40, Color(0.5, 0.95, 1.0, 0.6 + 0.4 * k), 4.0, true)
	draw_circle(c, r, col)
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.25), 2.0, true)
	var fs := 28 if r > 33.0 else 24
	draw_string(ThemeDB.fallback_font, c + Vector2(-r, fs * 0.36), str(n), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, fg)
	# étiquette du côté libre
	var right := c.x < 360.0
	var lx := c.x + r + 14.0 if right else c.x - r - 14.0
	var label := ""
	var sub := ""
	if bt != "":
		label = Data.boss_name(n)
		sub = "Gros boss" if bt == "big" else "Mini-boss"
	elif n == Game.best_stage:
		label = "Étage en cours"
	if label != "":
		_text(Vector2(lx, c.y - 4.0), label, 22, Color.WHITE, right)
		if sub != "":
			_text(Vector2(lx, c.y + 22.0), sub, 18, UI.MUTED, right)
	var s := int(Game.stars.get(n, 0))
	if s > 0:
		_text(Vector2(lx, c.y + (22.0 if label == "" else 46.0)), "★".repeat(s) + "☆".repeat(3 - s), 20, UI.GOLD, right)


func _text(pos: Vector2, txt: String, fs: int, col: Color, left_aligned: bool) -> void:
	var w := 260.0
	if left_aligned:
		draw_string(ThemeDB.fallback_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, w, fs, col)
	else:
		draw_string(ThemeDB.fallback_font, pos - Vector2(w, 0), txt, HORIZONTAL_ALIGNMENT_RIGHT, w, fs, col)
