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
	# fond : plaque sombre ; segment choisi : plaque biseautée cyan
	var back := GlassBox.make("chip", "normal", 0.3)
	back.glow_on = false
	draw_style_box(back, Rect2(Vector2.ZERO, size))
	var tab := GlassBox.make("tab", "normal", 0.3)
	tab.glow_on = false
	for i in n:
		if i == sel:
			tab.inset = 6.0
			draw_style_box(tab, Rect2(i * w, 0, w, size.y))
		var txt: String = ("✓ " if i == sel else "") + String(labels[i])
		M3.text(self, Vector2(i * w + 8.0, size.y * 0.5 + M3.fs(28) * 0.36), txt, 28, UI.TEXT if i == sel else UI.MUTED, true, w - 16.0, HORIZONTAL_ALIGNMENT_CENTER)


func _gui_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		var i := clampi(int(ev.position.x / (size.x / labels.size())), 0, labels.size() - 1)
		if i != sel:
			sel = i
			Sfx.play("click", -6.0)
			queue_redraw()
			changed.emit(i)
