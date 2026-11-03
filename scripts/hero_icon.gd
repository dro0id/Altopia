class_name HeroIcon
extends Control
## Portrait rond d'un héros dans la liste.

var hero: Dictionary = {}
var t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(80, 80)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	if not hero.is_empty():
		UI.portrait(self, hero, c, r - 2.0, t)
