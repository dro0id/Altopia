class_name BoostIcon
extends Control
## Icône low poly d'un renfort.

const Data = preload("res://scripts/data.gd")

var boost := "tir"
var t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(84, 84)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col: Color = Data.BOOSTS[boost].color
	var pulse := 1.0 + 0.06 * sin(t * 3.0)
	Art.ellipse(self, c, 38 * pulse, 38 * pulse, Color(col.r, col.g, col.b, 0.22), t * 0.3, 8)
	match boost:
		"tir":
			Art.ellipse(self, c, 24, 24, col, 0.4, 4)
			Art.ellipse(self, c, 12, 12, Color(0.3, 0.2, 0.05), 0.4, 4)
		"bouclier":
			Art.ellipse(self, c, 26, 28, col, 0.0, 6)
			Art.ellipse(self, c + Vector2(0, 2), 14, 16, Color(0.1, 0.35, 0.5), 0.0, 6)
		"pouvoirs":
			for i in 5:
				var a := t * 1.5 + i * TAU / 5.0
				Art.shard(self, c + Vector2(cos(a), sin(a)) * 18.0, 11.0, a * 2.0, col)
			Art.disc(self, c, 8.0, Color(1, 1, 1, 0.9))
		"vitalite":
			draw_rect(Rect2(c.x - 6, c.y - 22, 12, 44), col)
			draw_rect(Rect2(c.x - 22, c.y - 6, 44, 12), col)
		_:
			Art.disc(self, c, 22.0, col)
			Art.disc(self, c + Vector2(-5, -5), 8.0, Color(1, 0.97, 0.75))
