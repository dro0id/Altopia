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
	draw_rect(Rect2(Vector2.ZERO, size), UI.BAR)
	draw_rect(Rect2(0, 0, size.x, 2), UI.LINE2)
	var w := (size.x - 32.0) / 4.0
	var f := ThemeDB.fallback_font
	for i in 4:
		var on := i == active
		var col := UI.ACCENT if on else UI.MUTED
		var x0 := 16.0 + w * i
		var c := Vector2(x0 + w * 0.5, 38)
		_icon(i, c, col)
		var lab: String = LABELS[i]
		draw_string(UI.bold_font() if on else f, Vector2(x0, 83), lab, HORIZONTAL_ALIGNMENT_CENTER, w, 22, col)
		var n: int = badges[i]
		if n > 0:
			var bc := Vector2(x0 + w - 56.0, 22.0)
			draw_circle(bc, 20, UI.BG)
			draw_circle(bc, 16, UI.RED)
			draw_string(UI.bold_font(), bc + Vector2(-16, 8), str(mini(n, 9)), HORIZONTAL_ALIGNMENT_CENTER, 32, 22, Color.WHITE)


func _icon(i: int, c: Vector2, col: Color) -> void:
	match i:
		0:    # ⚔ épées croisées, trait fin
			draw_line(c + Vector2(-13, 14), c + Vector2(13, -14), col, 3.0, true)
			draw_line(c + Vector2(-13, -14), c + Vector2(13, 14), col, 3.0, true)
			draw_line(c + Vector2(-16, 6), c + Vector2(-6, 16), col, 3.0, true)
			draw_line(c + Vector2(16, 6), c + Vector2(6, 16), col, 3.0, true)
		1:    # 🛡 bouclier (contour)
			var pts := PackedVector2Array([c + Vector2(-16, -16), c + Vector2(16, -16), c + Vector2(16, 2), c + Vector2(0, 19), c + Vector2(-16, 2), c + Vector2(-16, -16)])
			draw_polyline(pts, col, 3.0, true)
		2:    # ✦ étoile à quatre branches
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(4, -4), c + Vector2(16, 0), c + Vector2(4, 4), c + Vector2(0, 16), c + Vector2(-4, 4), c + Vector2(-16, 0), c + Vector2(-4, -4)]), col)
		3:    # ◆ losange plein
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -19), c + Vector2(19, 0), c + Vector2(0, 19), c + Vector2(-19, 0)]), col)
