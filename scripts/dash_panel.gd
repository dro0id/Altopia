extends PanelContainer
## Panneau dont le cadre peut passer en pointillés (poste libre, emplacement verrouillé).

const DashFrame = preload("res://scripts/dash_frame.gd")

var dash_on := false : set = set_dash_on
var dash_color := Color(1.0, 0.7, 0.42)
var dash_radius := 25.0
var dash_len := 13.0
var dash_gap := 9.0
var dash_width := 2.0


func set_dash_on(v: bool) -> void:
	dash_on = v
	queue_redraw()


func _draw() -> void:
	if dash_on:
		DashFrame.paint(self, size, dash_color, dash_radius, dash_len, dash_gap, dash_width)
