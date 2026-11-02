class_name IntroScreen
extends Control

const Data = preload("res://scripts/data.gd")
## Premier lancement : un vaisseau fonce vers le Trou de verre. Texte provisoire (histoire détaillée en branche 2).

signal finished

var t := 0.0
var _stars := PackedVector2Array()
var _lines: Array[Label] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 4090
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 80:
		_stars.append(Vector2(rng.randf(), rng.randf()))
	var col := VBoxContainer.new()
	col.position = Vector2(30, 780)
	col.size = Vector2(660, 440)
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var a := UI.label(col, "CEINTURE D'ALTOPIA", 22, Color(0.5, 0.86, 1.0))
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := UI.label(col, "LE TROU DE VERRE", 52, Color(0.92, 0.95, 1.0))
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for txt in ["Un trou de verre s'est ouvert dans la Ceinture. Au fond, un signal.", "Pour l'atteindre, il faut monter, étage après étage."]:
		var l := UI.label(col, txt, 26, Color(0.82, 0.88, 0.97))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate.a = 0.0
		_lines.append(l)
	var go := UI.button(col, "Entrer dans le Trou de verre", 30, "main")
	go.custom_minimum_size = Vector2(0, 76)
	go.pressed.connect(func():
		finished.emit()
		queue_free())


func _process(delta: float) -> void:
	t += delta
	for i in _lines.size():
		_lines[i].modulate.a = clampf((t - 0.8 - i * 1.2) / 0.8, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.09))
	for i in 6:
		draw_rect(Rect2(0, size.y * i / 6.0, size.x, size.y / 6.0 + 1.0), Color(0.02, 0.03, 0.09).lerp(Color(0.07, 0.14, 0.32), 1.0 - i / 6.0 * 1.1))
	for i in _stars.size():
		var s := _stars[i]
		var y := fposmod(s.y * size.y * 0.7 + t * (20.0 + (i % 4) * 14.0), size.y * 0.7)
		var a := 0.3 + 0.6 * (0.5 + 0.5 * sin(t * 2.0 + i))
		var r := 2.0 + (i % 3)
		var c := Vector2(s.x * size.x, y)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.8), c + Vector2(r, 0), c + Vector2(0, r * 1.8), c + Vector2(-r, 0)]), Color(1, 1, 1, a))
	var hc := Vector2(size.x * 0.5, 360.0)
	# les anneaux du trou de verre
	Art.ellipse(self, hc, 230, 230, Color(0.1, 0.22, 0.45), t * 0.2, 6)
	Art.ellipse(self, hc, 176, 176, Color(0.06, 0.15, 0.34), -t * 0.35, 6)
	var ring := PackedVector2Array()
	for i in 7:
		var a2 := t * 0.2 + i * TAU / 6.0
		ring.append(hc + Vector2(cos(a2), sin(a2)) * 250.0)
	draw_polyline(ring, Color(0.3, 0.7, 0.9, 0.7), 3.0)
	Art.ellipse(self, hc, 110, 110, Color(0.03, 0.08, 0.2), t * 0.6, 6)
	Art.ellipse(self, hc, 34 + sin(t * 2.2) * 6.0, 34 + sin(t * 2.2) * 6.0, Color(0.85, 0.97, 1.0), t, 4)
	# le vaisseau s'enfonce dans le trou, en boucle
	var k := fposmod(t / 6.0, 1.0)
	var sc := lerpf(2.2, 0.25, pow(k, 0.8))
	var pos := hc + Vector2(0, lerpf(420.0, 10.0, pow(k, 0.8)))
	var a3 := clampf(minf(k * 8.0, (1.0 - k) * 6.0), 0.0, 1.0)
	draw_set_transform(pos, 0.0, Vector2(sc, sc))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -34), Vector2(22, 26), Vector2(0, 14), Vector2(-22, 26)]), Color(0.9, 0.93, 1.0, a3))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -34), Vector2(22, 26), Vector2(0, 14)]), Color(0.7, 0.78, 0.92, a3))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, 24), Vector2(8, 24), Vector2(0, 40 + sin(t * 40.0) * 8.0)]), Color(1.0, 0.7, 0.25, a3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
