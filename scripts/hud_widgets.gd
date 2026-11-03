class_name HudButton
extends Control
## Pastille ou bouton posé sur le terrain (fond sombre translucide, bordure fine), dessiné comme dans la maquette.

signal pressed

var text := ""
var sub := ""
var font_size := 22
var text_color := UI.TEXT
var sub_color := UI.MUTED
var border := UI.LINE
var radius := 24.0
var icon := ""          # "coin", "shard" ou ""
var tappable := true
var bold := false
var fill := UI.HUD


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_texts(t: String, s: String = "") -> void:
	if t != text or s != sub:
		text = t
		sub = s
		queue_redraw()


## Largeur automatique d'une pastille (marges 20 px, icône 24 px + 10 px).
func fit_chip() -> void:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	size = Vector2(w + 40.0 + (34.0 if icon != "" else 0.0), 52.0)


func _gui_input(ev: InputEvent) -> void:
	if not tappable:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		Sfx.play("click", -6.0)
		pressed.emit()


func _draw() -> void:
	var sb := UI.box(fill, border, int(minf(radius, size.y * 0.5)), 0)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var f: Font = UI.bold_font() if (bold or icon != "" or sub != "") else ThemeDB.fallback_font
	if icon != "":
		var c := Vector2(32, size.y * 0.5)
		if icon == "coin":
			draw_circle(c, 12, UI.GOLD)
			draw_string(f, c + Vector2(-12, 8), "¢", HORIZONTAL_ALIGNMENT_CENTER, 24, 20, Color("6b4a00"))
		elif icon == "crystal":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(12, 0), c + Vector2(0, 14), c + Vector2(-12, 0)]), Color("ff7ad9"))
		elif icon == "token":
			draw_style_box(UI.box(Color("b388ff"), Color(0, 0, 0, 0), 5, 0), Rect2(c + Vector2(-14, -10), Vector2(28, 20)))
			draw_circle(c, 4.5, Color("2a1450"))
		else:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(13, -2), c + Vector2(8, 13), c + Vector2(-8, 13), c + Vector2(-13, -2)]), Color("7fdcff"))
		draw_string(f, Vector2(54, size.y * 0.5 + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	elif sub == "":
		draw_string(f, Vector2(0, size.y * 0.5 + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
	else:
		draw_string(f, Vector2(0, size.y * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
		draw_string(f, Vector2(0, size.y * 0.5 + 26.0), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, sub_color)
