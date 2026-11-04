class_name M3Seg
extends Control
## Boutons segmentés (40 dp) : contour, segment choisi teinté avec une coche.

signal changed(index: int)

var labels: Array = []
var sel := 0


func _init(lbls: Array = [], selected := 0) -> void:
	labels = lbls
	sel = selected
	size = Vector2(656, 80)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	var n := labels.size()
	var w := size.x / n
	var sb := UI.box(Color(0, 0, 0, 0), M3.OUT, int(size.y * 0.5), 0)
	for i in n:
		if i == sel:
			var r := Rect2(i * w, 0, w, size.y)
			var s2 := StyleBoxFlat.new()
			s2.bg_color = M3.TONAL
			var rad := int(size.y * 0.5)
			s2.corner_radius_top_left = rad if i == 0 else 0
			s2.corner_radius_bottom_left = rad if i == 0 else 0
			s2.corner_radius_top_right = rad if i == n - 1 else 0
			s2.corner_radius_bottom_right = rad if i == n - 1 else 0
			draw_style_box(s2, r)
		if i > 0:
			draw_line(Vector2(i * w, 0), Vector2(i * w, size.y), M3.OUT, 2.0)
		var txt: String = ("✓ " if i == sel else "") + String(labels[i])
		M3.text(self, Vector2(i * w, size.y * 0.5 + M3.fs(28) * 0.36), txt, 28, UI.TEXT if i == sel else UI.MUTED, true, w, HORIZONTAL_ALIGNMENT_CENTER)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))


func _gui_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		var i := clampi(int(ev.position.x / (size.x / labels.size())), 0, labels.size() - 1)
		if i != sel:
			sel = i
			Sfx.play("click", -6.0)
			queue_redraw()
			changed.emit(i)
