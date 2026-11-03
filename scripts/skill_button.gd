class_name SkillButton
extends Control
## Bouton de pouvoir : rond de 92 px, bordure de couleur, glyphe, anneau de recharge. Un appui déclenche le pouvoir.

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
	custom_minimum_size = Vector2(92, 92)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 3.0)
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		flash = 1.0
		pressed.emit(slot)


func _draw() -> void:
	if hero.is_empty():
		return
	var look: Dictionary = LOOK.get(hero.skill.kind, LOOK.shield)
	var col: Color = look.col
	var c := Vector2(46, 46)
	var ready := unit != null and unit.alive and unit.skill_cd <= 0.0 and unit.stun_t <= 0.0
	draw_circle(c, 46, Color("0d1530"))
	draw_arc(c, 44, 0, TAU, 48, col if ready else Color(col.r, col.g, col.b, 0.45), 4.0, true)
	var frac := 1.0
	if unit != null and unit.alive:
		frac = 1.0 - clampf(unit.skill_cd / unit.skill_max, 0.0, 1.0)
	if frac < 1.0:
		draw_arc(c, 51, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, col, 6.0, true)
	var gcol := col if ready else Color(col.r, col.g, col.b, 0.35)
	_glyph(int(look.glyph), c, gcol)
	if unit != null and unit.alive and not ready:
		draw_string(ThemeDB.fallback_font, c + Vector2(-30, 12), "%.0f" % ceil(unit.skill_cd), HORIZONTAL_ALIGNMENT_CENTER, 60, 34, Color(1, 1, 1, 0.95))
	elif ready:
		draw_arc(c, 49 + sin(t * 6.0) * 1.5, 0, TAU, 40, Color(col.r, col.g, col.b, 0.35), 3.0, true)
	if unit == null or not unit.alive:
		draw_circle(c, 44, Color(0, 0, 0, 0.55))
	if flash > 0.0:
		draw_circle(c, 46, Color(1, 1, 1, flash * 0.5))


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
