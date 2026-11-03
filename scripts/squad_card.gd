class_name SquadCard
extends Control

const Data = preload("res://scripts/data.gd")
## Carte compacte d'un héros de l'escouade : portrait, nom, niveau. Un appui la sélectionne ; la pastille verte signale une amélioration possible.

signal pressed(slot: int)

var slot := 0
var hero: Dictionary = {}
var level := 1
var stars := 1
var affordable := false
var selected := false
var t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(128, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		pressed.emit(slot)


func _draw() -> void:
	if hero.is_empty():
		return
	var rc: Color = Data.RARITY_COLORS[hero.rarity]
	var r := Rect2(Vector2.ZERO, size)
	var sb := UI.box(Color(0.08, 0.14, 0.26, 0.98) if selected else UI.PANEL, rc if selected else rc.darkened(0.35), 14, 0)
	sb.set_border_width_all(4 if selected else 2)
	draw_style_box(sb, r)
	var c := Vector2(size.x * 0.5, 66)
	draw_circle(c, 50, Color(0.04, 0.08, 0.14))
	Art.draw_portrait(self, hero, c, 44.0, t)
	draw_string(ThemeDB.fallback_font, Vector2(0, 140), hero.name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(0, 168), "Nv %d  %s" % [level, "★".repeat(stars)], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, UI.GOLD)
	if affordable:
		var b := Vector2(size.x - 20, 18)
		var k := 1.0 + 0.08 * sin(t * 6.0)
		draw_circle(b, 15 * k, UI.GREEN)
		draw_colored_polygon(PackedVector2Array([b + Vector2(0, -7), b + Vector2(8, 5), b + Vector2(-8, 5)]), Color(0.02, 0.1, 0.06))
