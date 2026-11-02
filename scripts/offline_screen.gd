class_name OfflineScreen
extends Overlay

## Retour hors ligne : durée d'absence, plafond, crédits gagnés, coffre gratuit s'il est prêt.

signal chest_claimed(chest: Dictionary)


func _init(report: Dictionary) -> void:
	super._init(620.0)
	centered("Bon retour, Commandant", 34, UI.ACCENT)
	centered("Ton escouade a continué à patrouiller pendant ton absence.", 22, UI.MUTED)
	var g := VBoxContainer.new()
	g.add_theme_constant_override("separation", 6)
	box.add_child(g)
	_row(g, "Durée comptée", UI.duration(report.seconds), Color.WHITE)
	_row(g, "Plafond", "%d h" % int(Data.OFFLINE_CAP_HOURS), UI.MUTED)
	_row(g, "Crédits gagnés", "+ %s" % Data.fmt(report.credits), UI.GOLD)
	if Game.free_chest_ready():
		var fb := UI.button(box, "Ouvrir mon coffre gratuit", 26, "gold")
		fb.custom_minimum_size = Vector2(0, 64)
		fb.pressed.connect(func():
			var c: Dictionary = Game.claim_free_chest()
			if not c.is_empty():
				chest_claimed.emit(c)
			fb.queue_free())
	var ok := UI.button(box, "Récupérer", 28, "main")
	ok.custom_minimum_size = Vector2(0, 68)
	ok.pressed.connect(close)
	Sfx.play("coin")


func _row(parent: Node, a: String, b: String, col: Color) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := UI.label(h, a, 26, Color(0.85, 0.92, 1.0))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(h, b, 28, col)
