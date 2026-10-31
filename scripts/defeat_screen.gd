class_name DefeatScreen
extends Overlay

## Escouade tombée : un conseil concret et trois choix. Jamais de blocage : on peut toujours farmer l'étage d'avant.

signal retry_pressed
signal farm_pressed
signal upgrade_pressed


func _init(stage: int) -> void:
	super._init(620.0)
	centered("ESCOUADE TOMBÉE", 38, UI.RED)
	centered("Étage %d" % stage, 24, UI.MUTED)
	var need: int = Data.recommended_level(stage)
	var avg := 0.0
	for id in Data.HERO_ORDER:
		avg += float(Game.levels[id])
	avg /= Data.HERO_ORDER.size()
	var tip := "Niveau conseillé : %d. Ton escouade est en moyenne niveau %.0f." % [need, avg]
	if avg < need:
		tip += "\nAméliore tes héros ou farme l'étage précédent pour gagner des crédits."
	else:
		tip += "\nVous êtes au bon niveau : retente, en lançant les pouvoirs au bon moment."
	centered(tip, 22, Color(0.85, 0.92, 1.0))
	var r := UI.button(box, "Réessayer l'étage %d" % stage, 28, "main")
	r.custom_minimum_size = Vector2(0, 68)
	r.pressed.connect(func():
		retry_pressed.emit()
		close())
	if stage > 1:
		var f := UI.button(box, "Farmer l'étage %d" % (stage - 1), 24, "ghost")
		f.custom_minimum_size = Vector2(0, 60)
		f.pressed.connect(func():
			farm_pressed.emit()
			close())
	var u := UI.button(box, "Améliorer mes héros", 24, "ghost")
	u.custom_minimum_size = Vector2(0, 60)
	u.pressed.connect(func():
		upgrade_pressed.emit()
		close())
	Sfx.play("lose")
