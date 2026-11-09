class_name SkillButton
extends Control
## Bouton de pouvoir : hexagone de verre de 96 px, portrait, anneau de recharge qui se remplit le long du contour.
## Un appui déclenche le pouvoir.

signal pressed(slot: int)

# glyphe et couleur par type de pouvoir (ordre de la maquette : ⚡ ✚ ✹ ❖ ☄)
const LOOK := {
	"shield": {"glyph": 0, "col": Color("4fd8ff")},
	"volley": {"glyph": 1, "col": Color("7dffb0")},
	"pierce": {"glyph": 2, "col": Color("ffb142")},
	"repair": {"glyph": 3, "col": Color("b388ff")},
	"gravity": {"glyph": 4, "col": Color("ff6b6b")},
}

var slot := 0
var hero: Dictionary = {}
var unit: BattleSim.Unit
var t := 0.0
var flash := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(112, 136)
	size = Vector2(112, 136)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 3.0)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		flash = 1.0
		pressed.emit(slot)


## Portrait de 48 dp (maquette BB) : anneau de pouvoir (recharge), barre de vie dessous ; un appui lance le pouvoir.
func _draw() -> void:
	if hero.is_empty():
		return
	var look: Dictionary = LOOK.get(hero.skill.kind, LOOK.shield)
	var col: Color = look.col
	var c := Vector2(56, 52)
	var alive := unit != null and unit.alive
	var ready := alive and unit.skill_cd <= 0.0 and unit.stun_t <= 0.0
	var frac := 1.0
	if alive:
		frac = 1.0 - clampf(unit.skill_cd / unit.skill_max, 0.0, 1.0)
	if ready:
		# lueur d'un pouvoir prêt
		var gl := 0.5 + 0.5 * sin(t * 6.0)
		draw_colored_polygon(_hex(c, 56.0 + gl * 2.0), Color(col, 0.16 + 0.1 * gl))
	draw_colored_polygon(_hex(c, 50.0), Color("0f1a36"))
	draw_colored_polygon(_hex(c, 43.0), Color("0a1424"))
	Art.draw_portrait(self, hero, c, 38.0, t)
	draw_polyline(_closed_hex(c, 46.0), Color(col, 0.28), 5.0, true)
	if frac >= 1.0:
		draw_polyline(_closed_hex(c, 46.0), col, 5.0, true)
	elif frac > 0.0:
		draw_polyline(_hex_progress(c, 46.0, frac), col, 5.0, true)
	if ready:
		draw_circle(c + Vector2(36, -34), 15, col)
		draw_arc(c + Vector2(36, -34), 15, 0, TAU, 20, Color("070b1a"), 2.0, true)
		draw_glyph(self, int(look.glyph), c + Vector2(36, -34), Color("06101f"), 0.32)
	if not alive:
		draw_colored_polygon(_hex(c, 47.0), Color(0, 0, 0, 0.6))
	if flash > 0.0:
		draw_colored_polygon(_hex(c, 47.0), Color(1, 1, 1, flash * 0.5))
	# barre de vie
	var hp := unit.hp_frac() if alive else 0.0
	draw_style_box(UI.box(Color("1d2a52"), Color(0, 0, 0, 0), 6, 0), Rect2(0, 112, 112, 12))
	if hp > 0.0:
		draw_style_box(UI.box(UI.GREEN if hp > 0.35 else UI.RED, Color(0, 0, 0, 0), 6, 0), Rect2(0, 112, maxf(12.0, 112.0 * hp), 12))


## Hexagone à pointe en haut, de rayon `r`.
static func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 6.0) * r)
	return pts


static func _closed_hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := _hex(c, r)
	pts.append(pts[0])
	return pts


## Partie du contour de l'hexagone parcourue depuis la pointe du haut, dans le sens des aiguilles d'une montre.
static func _hex_progress(c: Vector2, r: float, frac: float) -> PackedVector2Array:
	var pts := _closed_hex(c, r)
	var out := PackedVector2Array([pts[0]])
	var left := clampf(frac, 0.0, 1.0) * 6.0
	for i in 6:
		if left <= 0.0:
			break
		var k := minf(left, 1.0)
		out.append(pts[i].lerp(pts[i + 1], k))
		left -= 1.0
	return out


func _glyph(g: int, c: Vector2, col: Color) -> void:
	draw_glyph(self, g, c, col, 1.0)


## Glyphe de pouvoir (⚡ ✚ ✹ ❖ ☄) dessiné en vectoriel, à l'échelle voulue.
static func draw_glyph(ci: CanvasItem, g: int, c: Vector2, col: Color, s: float) -> void:
	match g:
		0:    # ⚡
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(4, -26) * s, c + Vector2(-14, 4) * s, c + Vector2(-1, 4) * s, c + Vector2(-5, 26) * s, c + Vector2(15, -6) * s, c + Vector2(2, -6) * s]), col)
		1:    # ✚
			ci.draw_rect(Rect2(c + Vector2(-5, -22) * s, Vector2(10, 44) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-22, -5) * s, Vector2(44, 10) * s), col)
		2:    # ✹
			var pts := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0 - PI * 0.5
				pts.append(c + Vector2.from_angle(a) * (24.0 if i % 2 == 0 else 11.0) * s)
			ci.draw_colored_polygon(pts, col)
		3:    # ❖
			for d in [Vector2(0, -15), Vector2(15, 0), Vector2(0, 15), Vector2(-15, 0)]:
				var m: Vector2 = c + d * s
				ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -9) * s, m + Vector2(9, 0) * s, m + Vector2(0, 9) * s, m + Vector2(-9, 0) * s]), col)
		4:    # ☄
			ci.draw_circle(c + Vector2(9, 9) * s, 9.0 * s, col)
			for k in 3:
				ci.draw_line(c + (Vector2(5 - k * 5, 5 - k * 5) + Vector2(-2, 6)) * s, c + (Vector2(-22 + k * 2, -22 + k * 6) + Vector2(0, 4)) * s, col, 4.0 * s, true)
