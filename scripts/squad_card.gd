class_name SquadCard
extends Control
## Carte d'un héros de l'escouade (maquette C) : cadre de rareté, portrait, nom, niveau ; pastille verte ▲ sur le meilleur achat.

signal pressed(slot: int)

const Data = preload("res://scripts/data.gd")

var slot := 0
var hero: Dictionary = {}
var level := 1
var affordable := false
var t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(124.8, 170)
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
	var sb := UI.box(UI.PANEL, rc, 20, 0)
	sb.set_border_width_all(3)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var c := Vector2(size.x * 0.5, 10.0 + 48.0)
	UI.portrait(self, hero, c, 47.0, t)
	var f := ThemeDB.fallback_font
	var nm: String = hero.name.split(" ")[0]
	draw_string(UI.bold_font(), Vector2(0, 131), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color.WHITE)
	draw_string(f, Vector2(0, 153), "Nv %d" % level, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, UI.GOLD)
	if affordable:
		var b := Vector2(size.x - 12.0, 4.0)
		draw_circle(b, 20, UI.BG)
		draw_circle(b, 18, UI.GREEN)
		draw_colored_polygon(PackedVector2Array([b + Vector2(0, -8), b + Vector2(9, 6), b + Vector2(-9, 6)]), UI.DARK)
