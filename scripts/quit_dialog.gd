class_name QuitDialog
extends Overlay
## Confirmation avant de quitter (maquette BK/AH) : le geste Retour sur le combat ne ferme pas le jeu sans demander.

signal quit_pressed


func _init() -> void:
	super._init(600.0)
	panel.add_theme_stylebox_override("panel", UI.box(Color("1a2547"), Color(0, 0, 0, 0), 56, 40))
	box.add_theme_constant_override("separation", 20)
	var t := UI.label(box, "Quitter Altopia ?", 40, UI.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var d := UI.label(box, "Ta progression est sauvegardée. Tes héros gagnent des crédits hors ligne (8 h max).", 28, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var q := UI.button(row, "Quitter", 30, "text")
	q.custom_minimum_size = Vector2(180, 96)
	q.pressed.connect(func(): quit_pressed.emit())
	var r := UI.button(row, "Rester", 30, "main")
	r.custom_minimum_size = Vector2(220, 96)
	r.pressed.connect(close)
