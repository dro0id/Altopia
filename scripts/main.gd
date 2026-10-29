extends Control
## Point d'entrée vide : le projet repart de zéro (voir docs/GDD.md).

func _ready() -> void:
	var l := Label.new()
	l.text = "ALTOPIA\nNouveau départ"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 48)
	add_child(l)
