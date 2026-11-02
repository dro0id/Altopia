class_name Overlay
extends Control

const Data = preload("res://scripts/data.gd")
## Fenêtre modale : fond assombri, panneau centré. Fonctionne même quand le combat est en pause.

signal closed

var panel: PanelContainer
var box: VBoxContainer


func _init(width: float = 640.0) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 4090
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.1, 0.19, 0.98), UI.LINE, 16, 22))
	center.add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)


func close() -> void:
	closed.emit()
	queue_free()


func centered(text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := UI.label(box, text, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
