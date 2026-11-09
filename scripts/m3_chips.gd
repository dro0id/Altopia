class_name M3Chips
extends Control
## Rangée de puces de filtre (32 dp, zone d'appui 48 dp) : la puce choisie est teintée avec une coche.

signal changed(index: int)

var labels: Array = []
var sel := 0
var _rects: Array = []


func _init(lbls: Array = [], selected := 0) -> void:
	labels = lbls
	sel = selected
	size = Vector2(688, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	_rects.clear()
	var x := 0.0
	for i in labels.size():
		var on := i == sel
		var lab := String(labels[i])
		var locked := lab.begins_with("🔒 ")
		if locked:
			lab = lab.substr(2)
		var txt: String = ("✓ " if on else "") + lab
		var w := M3.text_w(txt, 26, true) + 48.0 + (32.0 if locked else 0.0)
		var r := Rect2(x, 16, w, 64)
		_rects.append(r)
		var plate := GlassBox.make("tab" if on else "chip", "normal", 0.3)
		plate.glow_on = false
		draw_style_box(plate, r)
		if locked:
			M3.lock(self, Vector2(x + 34, 48), UI.MUTED, 1.0)
			M3.text(self, Vector2(x + 56.0, 48 + M3.fs(26) * 0.36), txt, 26, UI.MUTED, true)
		else:
			M3.text(self, Vector2(x, 48 + M3.fs(26) * 0.36), txt, 26, UI.TEXT if on else UI.MUTED, true, w, HORIZONTAL_ALIGNMENT_CENTER)
		x += w + 12.0


func _gui_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		for i in _rects.size():
			if (_rects[i] as Rect2).grow_individual(6, 16, 6, 16).has_point(ev.position):
				if i != sel:
					sel = i
					Sfx.play("click", -6.0)
					queue_redraw()
					changed.emit(i)
				return
