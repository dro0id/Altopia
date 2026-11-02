class_name SkillButton
extends Control
## Bouton de pouvoir d'un héros : portrait, anneau de recharge ; un appui déclenche le pouvoir.

signal pressed(slot: int)

var slot := 0
var hero: Dictionary = {}
var unit: BattleSim.Unit
var t := 0.0
var flash := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(128, 104)
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
	var c := Vector2(size.x * 0.5, 46)
	var ready := unit != null and unit.alive and unit.skill_cd <= 0.0 and unit.stun_t <= 0.0
	var accent: Color = hero.look.accent if not hero.is_empty() else Color.WHITE
	draw_circle(c, 40, Color(0.04, 0.08, 0.14, 0.95))
	var ring := Color(accent.r, accent.g, accent.b, 0.95) if ready else Color(0.3, 0.4, 0.5, 0.8)
	if hero.is_empty():
		return
	Art.draw_portrait(self, hero, c, 33.0, t)
	if unit != null and unit.alive:
		var frac := 1.0 - clampf(unit.skill_cd / unit.skill_max, 0.0, 1.0)
		draw_arc(c, 40, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, ring, 5.0, true)
		if not ready:
			draw_circle(c, 33, Color(0, 0, 0, 0.45))
			draw_string(ThemeDB.fallback_font, c + Vector2(-30, 9), "%.0f" % ceil(unit.skill_cd), HORIZONTAL_ALIGNMENT_CENTER, 60, 28, Color(1, 1, 1, 0.95))
		else:
			draw_arc(c, 44 + sin(t * 6.0) * 2.0, 0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.5), 3.0)
	else:
		draw_circle(c, 33, Color(0, 0, 0, 0.7))
	if flash > 0.0:
		draw_circle(c, 40, Color(1, 1, 1, flash * 0.5))
	var nm: String = hero.skill.name
	draw_string(ThemeDB.fallback_font, Vector2(0, 100), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.82, 0.92, 1.0))
