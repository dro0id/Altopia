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
	var h := 1280.0
	var go := M3.button(self, "Commencer", Rect2(32, h - 32 - 40 - 112, 656, 112), "main", 32)
	go.pressed.connect(func():
		finished.emit()
		queue_free())


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Écran d'entrée (maquette BP) : halo, emblème, nom du jeu, deux lignes d'histoire, bouton Commencer.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	var hc := Vector2(360, size.y * 0.4)
	for i in 16:
		draw_circle(hc, 420.0 - i * 24.0, Color(0.31, 0.85, 1.0, 0.012))
	for i in _stars.size():
		var s := _stars[i]
		var a := 0.15 + 0.35 * (0.5 + 0.5 * sin(t * 1.6 + i))
		draw_circle(Vector2(s.x * size.x, s.y * size.y * 0.8), 1.5 + (i % 3) * 0.6, Color(1, 1, 1, a))
	# emblème ◈ (losange creux et losange plein)
	var e := hc + Vector2(0, -120)
	var k := 1.0 + 0.03 * sin(t * 2.0)
	draw_polyline(PackedVector2Array([e + Vector2(0, -56) * k, e + Vector2(56, 0) * k, e + Vector2(0, 56) * k, e + Vector2(-56, 0) * k, e + Vector2(0, -56) * k]), UI.TEXT, 6.0, true)
	draw_colored_polygon(PackedVector2Array([e + Vector2(0, -26), e + Vector2(26, 0), e + Vector2(0, 26), e + Vector2(-26, 0)]), UI.TEXT)
	var fb := UI.bold_font()
	var name := "ALTOPIA"
	var fs := M3.fs(68)
	var tw := 0.0
	for ch in name:
		tw += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
	var x := 360.0 - tw * 0.5
	for ch in name:
		draw_string(fb, Vector2(x, hc.y + 40), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)
		x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
	var a1 := clampf((t - 0.5) / 0.8, 0.0, 1.0)
	var a2 := clampf((t - 1.2) / 0.8, 0.0, 1.0)
	M3.text(self, Vector2(0, hc.y + 104), "Un signal venu du Trou de verre.", 28, Color(UI.MUTED, a1), false, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(self, Vector2(0, hc.y + 146), "Ton équipage répond.", 28, Color(UI.MUTED, a2), false, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(self, Vector2(0, size.y - 40), "Sauvegarde automatique", 24, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)
