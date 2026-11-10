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
var icon := ""          # "coin", "shard", "crystal", "token", "itoken", "copies" ou ""
var tappable := true
var bold := false
var fill := UI.HUD
var ring := false       # liseré or : monnaie de l'écran (porte-monnaie, maquette I3)
var role := ""          # rôle de verre (GlassBox) ; vide : secondaire si on peut appuyer, plaquette sinon
var _glass := {}


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


## Zone d'appui d'au moins 96 px (48 dp) autour du dessin, même pour les petites pastilles.
func _has_point(point: Vector2) -> bool:
	var grow := Vector2(maxf(0.0, 96.0 - size.x), maxf(0.0, 96.0 - size.y)) * 0.5
	return Rect2(-grow, size + grow * 2.0).has_point(point)


func _gui_input(ev: InputEvent) -> void:
	if not tappable:
		return
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		Sfx.play("click", -6.0)
		pressed.emit()


func _draw() -> void:
	var r := role if role != "" else ("secondary" if tappable else "chip")
	if not _glass.has(r):
		_glass[r] = GlassBox.make(r, "normal", 0.3)
		(_glass[r] as GlassBox).glow_on = false
	draw_style_box(_glass[r], Rect2(Vector2.ZERO, size))
	if ring:
		var k := minf(16.0, size.y * 0.3)
		var w := size.x
		var h := size.y
		draw_polyline(PackedVector2Array([Vector2(k, 1), Vector2(w - k, 1), Vector2(w - 1, k), Vector2(w - 1, h - k), Vector2(w - k, h - 1), Vector2(k, h - 1), Vector2(1, h - k), Vector2(1, k), Vector2(k, 1)]), UI.GOLD, 3.0, true)
	var f: Font = UI.bold_font() if (bold or icon != "" or sub != "") else ThemeDB.fallback_font
	if icon != "":
		draw_icon(self, Vector2(32, size.y * 0.5))
		draw_string(f, Vector2(54, size.y * 0.5 + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	elif sub == "":
		draw_string(f, Vector2(0, size.y * 0.5 + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
	else:
		draw_string(f, Vector2(0, size.y * 0.5 - 4.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
		draw_string(f, Vector2(0, size.y * 0.5 + 26.0), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, sub_color)


## Icône de monnaie centrée en `c` (aussi utilisée par le porte-monnaie pour ses explications).
func draw_icon(ci: CanvasItem, c: Vector2) -> void:
	var f: Font = UI.bold_font()
	if icon == "coin":
		ci.draw_circle(c, 12, UI.GOLD)
		ci.draw_string(f, c + Vector2(-12, 8), "¢", HORIZONTAL_ALIGNMENT_CENTER, 24, 20, Color("6b4a00"))
	elif icon == "crystal":
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(12, 0), c + Vector2(0, 14), c + Vector2(-12, 0)]), Color("ff7ad9"))
	elif icon == "copies":
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (14.0 if i % 2 == 0 else 6.0))
		ci.draw_colored_polygon(pts, UI.GOLD)
	elif icon == "token":
		ci.draw_style_box(UI.box(Color("b388ff"), Color(0, 0, 0, 0), 5, 0), Rect2(c + Vector2(-14, -10), Vector2(28, 20)))
		ci.draw_circle(c, 4.5, Color("2a1450"))
	elif icon == "itoken":
		ci.draw_style_box(UI.box(Color("ffb142"), Color(0, 0, 0, 0), 7, 0), Rect2(c + Vector2(-14, -12), Vector2(28, 24)))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), Color("3a2000"))
	else:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(13, -2), c + Vector2(8, 13), c + Vector2(-8, 13), c + Vector2(-13, -2)]), Color("7fdcff"))
