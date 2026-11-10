class_name SettingsScreen
extends Overlay
## Réglages (maquette BJ) : son, affichage (taille du texte), batterie ; tutoriel et réinitialisation dans le menu ⋮.

signal changed
signal erase_requested
signal tutorial_requested

const STEPS := [1.0, 0.8, 0.6, 0.4, 0.2]

var _st: Control
var _body: Control
var _rows: Array = []        # [y, titre, sous-titre (Callable), clé on/off, clé volume]


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	set_backdrop(Color("6f7fa8"))
	M3.top_bar(_st, "Réglages", func():
		changed.emit()
		close(), [["⋮", _menu]])
	_rows = [
		[168.0, "Effets sonores", func(): return "Volume %d %%" % int(round(Game.sfx_vol * 100.0)), "sfx_on", "sfx_vol"],
		[262.0, "Musique", func(): return "Volume %d %%" % int(round(Game.music_vol * 100.0)), "music_on", "music_vol"],
		[356.0, "Vibrations", func(): return "Retour haptique", "haptics", ""],
		[588.0, "Chiffres de dégâts", func(): return "Au-dessus des ennemis", "dmg_numbers", ""],
		[698.0, "Réduire les animations", func(): return "Tremblements, fond mouvant, envols", "reduce_shake", ""],
		[850.0, "Économie de batterie", func(): return "30 images par seconde", "battery_saver", ""],
		[958.0, "Économie auto sous 20 %", func(): return "" if Game.battery_level() >= 0 else "Niveau de batterie illisible sur ce téléphone", "battery_auto", ""],
	]
	_body = Control.new()
	_body.size = Vector2(720, UI.H)
	_body.draw.connect(_draw_body)
	_body.gui_input.connect(_input_body)
	_st.add_child(_body)
	var seg := M3Seg.new(["Normal", "Grand", "Très grand"], Game.text_size)
	seg.position = Vector2(32, 524)
	seg.changed.connect(func(i: int):
		Game.text_size = i
		Game.apply_performance()
		Game.save_game()
		changed.emit()
		_body.queue_redraw())
	_st.add_child(seg)
	# la zone des réglages couvre l'écran : la barre du haut doit rester au-dessus pour recevoir les appuis
	_st.move_child(_st.get_node("TopBar"), -1)


func _menu() -> void:
	M3.menu(_st, Vector2(704, 96), [["Revoir le tutoriel", func():
		Game.tutorial_done = false
		tutorial_requested.emit()
		changed.emit()
		close()], ["Réinitialiser la partie", _confirm_erase]])


func _confirm_erase() -> void:
	var d := QuitDialog.new("Réinitialiser la partie ?", "Toute ta progression sera effacée : héros, objets, secteurs et monnaies.", "Effacer", "Annuler")
	d.quit_pressed.connect(func():
		d.close()
		erase_requested.emit()
		close())
	add_child(d)


func _draw_body() -> void:
	M3.section(_body, Vector2(32, 152), "SON")
	M3.section(_body, Vector2(32, 506), "AFFICHAGE")
	M3.section(_body, Vector2(32, 838), "BATTERIE")
	for r in _rows:
		var y: float = r[0]
		var on: bool = bool(Game.get(r[3]))
		var sub: String = (r[2] as Callable).call()
		if sub == "":
			M3.text(_body, Vector2(32, y + 62), r[1], 30, UI.TEXT)
		else:
			M3.text(_body, Vector2(32, y + 44), r[1], 30, UI.TEXT)
			M3.text(_body, Vector2(32, y + 80), sub, 24, UI.MUTED, false, 520)
		# interrupteur (52 × 32 dp)
		var sr := Rect2(584, y + 20, 104, 64)
		_body.draw_style_box(UI.box(UI.ACCENT if on else M3.S3, UI.ACCENT if on else M3.OUT, 32, 0), sr)
		_body.draw_circle(Vector2(sr.end.x - 32.0, sr.get_center().y) if on else Vector2(sr.position.x + 32.0, sr.get_center().y), 20.0 if on else 16.0, UI.DARK if on else UI.MUTED)
	M3.text(_body, Vector2(32, _body.size.y - 32.0), "Altopia 0.1.0 · sauvegarde automatique", 24, UI.MUTED)


func _input_body(ev: InputEvent) -> void:
	if not M3.is_tap(ev):
		return
	var p: Vector2 = ev.position
	for r in _rows:
		var y: float = r[0]
		if p.y < y or p.y > y + 100.0:
			continue
		if p.x < 540.0 and String(r[4]) != "":
			# toucher le texte change le volume par paliers
			var v: float = float(Game.get(r[4]))
			var i := 0
			for k in STEPS.size():
				if absf(STEPS[k] - v) < 0.05:
					i = (k + 1) % STEPS.size()
			Game.set(r[4], STEPS[i])
			Game.set(r[3], true)
		else:
			Game.set(r[3], not bool(Game.get(r[3])))
		if r[3] == "battery_saver" or r[3] == "battery_auto":
			Game.apply_performance()
		if r[3] == "music_on" or r[4] == "music_vol":
			Sfx.refresh_music()
		Sfx.play("click", -6.0)
		Game.save_game()
		changed.emit()
		_body.queue_redraw()
		return
