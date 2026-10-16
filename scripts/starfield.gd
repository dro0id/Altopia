extends Node2D
## Fond d'étoiles à 3 plans (parallaxe) qui défilent lentement, pour donner du volume.

const LAYERS := [
	{"count": 70, "speed": 6.0, "size": 1.2, "alpha": 0.35},
	{"count": 40, "speed": 14.0, "size": 1.8, "alpha": 0.55},
	{"count": 18, "speed": 30.0, "size": 2.6, "alpha": 0.85},
]

var _stars: Array = []
var _size := Vector2(720, 1280)


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for li in LAYERS.size():
		for i in LAYERS[li].count:
			_stars.append({
				"layer": li,
				"pos": Vector2(rng.randf() * _size.x, rng.randf() * _size.y),
				"tint": rng.randf(),
			})
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _on_resize() -> void:
	_size = get_viewport_rect().size


func _process(delta: float) -> void:
	for s in _stars:
		s.pos.y += LAYERS[s.layer].speed * delta
		if s.pos.y > _size.y:
			s.pos.y -= _size.y
			s.pos.x = randf() * _size.x
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.02, 0.03, 0.08))
	# Grande planète lointaine pour l'ambiance.
	draw_circle(Vector2(_size.x * 0.85, _size.y * 0.12), 90.0, Color(0.10, 0.16, 0.38, 0.55))
	draw_circle(Vector2(_size.x * 0.82, _size.y * 0.10), 70.0, Color(0.16, 0.25, 0.55, 0.35))
	for s in _stars:
		var l: Dictionary = LAYERS[s.layer]
		var c := Color(0.75 + 0.25 * s.tint, 0.85, 1.0, l.alpha)
		draw_circle(s.pos, l.size, c)
