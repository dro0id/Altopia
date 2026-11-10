class_name QuitDialog
extends Overlay
## Boîte de dialogue de confirmation (maquettes AH et BK) : « Quitter Altopia ? » par défaut, ou toute autre confirmation.

signal quit_pressed


func _init(title := "Quitter Altopia ?", body := "Ta progression est sauvegardée. Tes héros gagnent des crédits hors ligne (8 h max).", ok := "Quitter", cancel := "Rester") -> void:
	super._init(600.0)
	var qg := GlassBox.make("sheet")
	qg.flat = true
	qg.corner = 28.0
	qg.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", qg)
	box.add_theme_constant_override("separation", 20)
	var t := UI.label(box, title, M3.fs(40), UI.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var d := UI.label(box, body, M3.fs(28), UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var q := UI.button(row, ok, M3.fs(30), "text")
	q.custom_minimum_size = Vector2(180, 96)
	q.pressed.connect(func(): quit_pressed.emit())
	var r := UI.button(row, cancel, M3.fs(30), "main")
	r.custom_minimum_size = Vector2(220, 96)
	r.pressed.connect(close)
