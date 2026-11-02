class_name SettingsScreen
extends Overlay

## Réglages : musique, effets, pouvoirs automatiques, vitesse, effacement de la sauvegarde.

signal changed
signal erase_requested

var _confirm := false


func _init() -> void:
	super._init(620.0)
	centered("Réglages", 36, UI.ACCENT)
	_toggle("Musique", Game.music_on, func(v: bool):
		Game.music_on = v
		Sfx.refresh_music())
	_toggle("Effets sonores", Game.sfx_on, func(v: bool): Game.sfx_on = v)
	_toggle("Pouvoirs automatiques", Game.auto_cast, func(v: bool): Game.auto_cast = v)
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 10)
	box.add_child(sp)
	var l := UI.label(sp, "Vitesse du combat", 26, Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btns := []
	for k in [1, 2, 3]:
		var b := UI.button(sp, "x%d" % k, 24, "main" if int(Game.speed) == k else "ghost")
		b.custom_minimum_size = Vector2(80, 60)
		b.pressed.connect(func():
			Game.speed = float(k)
			changed.emit()
			for i in btns.size():
				btns[i].queue_free()
			close())
		btns.append(b)
	var erase := UI.button(box, "Effacer la sauvegarde", 22, "danger")
	erase.custom_minimum_size = Vector2(0, 60)
	erase.pressed.connect(func():
		if not _confirm:
			_confirm = true
			erase.text = "Appuie encore pour confirmer"
		else:
			erase_requested.emit()
			close())
	var cl := UI.button(box, "Fermer", 26, "main")
	cl.custom_minimum_size = Vector2(0, 64)
	cl.pressed.connect(func():
		changed.emit()
		close())
	centered("Altopia · version de développement", 16, UI.MUTED)


func _toggle(text: String, value: bool, setter: Callable) -> void:
	var h := HBoxContainer.new()
	box.add_child(h)
	var l := UI.label(h, text, 26, Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UI.button(h, "Activé" if value else "Coupé", 22, "main" if value else "ghost")
	b.custom_minimum_size = Vector2(150, 56)
	var state := [value]
	b.pressed.connect(func():
		state[0] = not state[0]
		setter.call(state[0])
		b.text = "Activé" if state[0] else "Coupé"
		changed.emit())
