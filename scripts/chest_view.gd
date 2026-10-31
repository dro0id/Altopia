class_name ChestView
extends Control
## Coffre animé : tremble, puis s'ouvre dans la lumière. Émet `opened` à l'ouverture.

signal opened

var rarity := "commun"
var t := 0.0
var open_at := 1.0
var _fired := false


func _init() -> void:
	custom_minimum_size = Vector2(520, 300)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	t += delta
	if t >= open_at and not _fired:
		_fired = true
		Sfx.play("chest")
		opened.emit()
	queue_redraw()


func _draw() -> void:
	var shake := clampf(t / open_at, 0.0, 1.0) * 4.0 if t < open_at else 0.0
	var open := clampf((t - open_at) / 0.5, 0.0, 1.0)
	Art.draw_chest(self, Vector2(size.x * 0.5, size.y - 26.0), 1.15, rarity, t, open, shake)
