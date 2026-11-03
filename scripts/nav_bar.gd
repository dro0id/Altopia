class_name NavBar
extends Control
## Barre de navigation du bas : Combat, Héros, Recruter, Boutique, avec pastilles de notification.

signal tab_pressed(index: int)

const LABELS := ["Combat", "Héros", "Recruter", "Boutique"]
const HEIGHT := 128.0

var active := 0
var badges: Array = [0, 0, 0, 0]
var t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(720, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pos = ev.position
	else:
		return
	var i := clampi(int(pos.x / (size.x / 4.0)), 0, 3)
	Sfx.play("click", -6.0)
	tab_pressed.emit(i)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.08, 0.16, 0.98))
	draw_rect(Rect2(0, 0, size.x, 2), Color(0.3, 0.85, 1.0, 0.35))
	var w := size.x / 4.0
	for i in 4:
		var on := i == active
		var col := UI.ACCENT if on else UI.MUTED
		var c := Vector2(w * (i + 0.5), 46)
		if on:
			draw_rect(Rect2(w * i + 24, 0, w - 48, 5), UI.ACCENT)
		_icon(i, c, col)
		draw_string(ThemeDB.fallback_font, Vector2(w * i, 96), LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, w, 24, col)
		var n: int = badges[i]
		if n > 0:
			var bc := c + Vector2(28, -22)
			draw_circle(bc, 15, Color(1.0, 0.42, 0.42))
			draw_arc(bc, 15, 0, TAU, 24, Color(0.04, 0.08, 0.16), 3.0, true)
			draw_string(ThemeDB.fallback_font, bc + Vector2(-15, 8), str(mini(n, 9)), HORIZONTAL_ALIGNMENT_CENTER, 30, 22, Color.WHITE)


func _icon(i: int, c: Vector2, col: Color) -> void:
	match i:
		0:    # épées croisées
			draw_line(c + Vector2(-17, 17), c + Vector2(17, -17), col, 5.0, true)
			draw_line(c + Vector2(-17, -17), c + Vector2(17, 17), col, 5.0, true)
			draw_line(c + Vector2(-20, 6), c + Vector2(-6, 20), col, 4.0, true)
			draw_line(c + Vector2(20, 6), c + Vector2(6, 20), col, 4.0, true)
		1:    # bouclier
			var pts := PackedVector2Array([c + Vector2(-18, -18), c + Vector2(18, -18), c + Vector2(18, 2), c + Vector2(0, 22), c + Vector2(-18, 2)])
			draw_colored_polygon(pts, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -10), c + Vector2(9, -10), c + Vector2(9, 0), c + Vector2(0, 11), c + Vector2(-9, 0)]), Color(0.04, 0.08, 0.16))
		2:    # étoile
			Art.star(self, c, 22.0, col)
		3:    # cristal
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22), c + Vector2(19, 0), c + Vector2(0, 22), c + Vector2(-19, 0)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -22), c + Vector2(19, 0), c + Vector2(0, 0)]), col.lightened(0.35))
