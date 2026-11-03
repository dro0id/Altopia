class_name SettingsScreen
extends Overlay

## Réglages (maquette P) : son (curseurs), confort (interrupteurs), compte (revoir le tuto, réinitialiser).

signal changed
signal erase_requested
signal tutorial_requested

var _confirm := false
var _stage: Control
var _drag := ""


func _init() -> void:
	super._init(720.0)
	_stage = use_stage(1.0)
	# bandeau
	var band := ColorRect.new()
	band.color = UI.BG
	band.size = Vector2(720, 128)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(band)
	var back := Button.new()
	back.text = "←"
	back.position = Vector2(16, 16)
	back.size = Vector2(96, 96)
	back.add_theme_font_size_override("font_size", 36)
	for st in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(st, UI.box(Color(0, 0, 0, 0) if st == "normal" else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 48, 0))
	back.pressed.connect(func():
		changed.emit()
		close())
	_stage.add_child(back)
	var title := UI.label(_stage, "Réglages", 36, Color.WHITE, true)
	title.position = Vector2(128, 40)
	# zone dessinée : étiquettes, curseurs, interrupteurs
	var body := Control.new()
	body.size = Vector2(720, 1280)
	body.draw.connect(_draw_body.bind(body))
	body.gui_input.connect(_input_body.bind(body))
	_stage.add_child(body)
	# boutons du compte
	var tuto := UI.button(_stage, "Revoir le tuto", 28, "ghost")
	tuto.position = Vector2(24, 944)
	tuto.size = Vector2(320, 96)
	tuto.pressed.connect(func():
		Game.tutorial_done = false
		tutorial_requested.emit()
		changed.emit()
		close())
	var erase := UI.button(_stage, "Réinitialiser", 28, "ghost")
	erase.position = Vector2(360, 944)
	erase.size = Vector2(336, 96)
	erase.add_theme_color_override("font_color", Color("ff9b9b"))
	erase.add_theme_color_override("font_hover_color", Color("ff9b9b"))
	erase.add_theme_color_override("font_pressed_color", Color("ff9b9b"))
	erase.pressed.connect(func():
		if not _confirm:
			_confirm = true
			erase.text = "Touche encore"
		else:
			erase_requested.emit()
			close())
	var foot := UI.label(_stage, "Altopia · version de développement", 22, UI.MUTED)
	foot.position = Vector2(0, 1216)
	foot.size = Vector2(720, 30)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


const SLIDERS := [["Musique", 218.0, "music_vol"], ["Effets", 322.0, "sfx_vol"]]
const TOGGLES := [["Vibrations", 500.0, "haptics"], ["Chiffres de dégâts", 605.0, "dmg_numbers"], ["Économie de batterie (30 FPS)", 712.0, "battery_saver"], ["Réduire les secousses d'écran", 817.0, "reduce_shake"]]


func _draw_body(c: Control) -> void:
	var f := ThemeDB.fallback_font
	c.draw_string(f, Vector2(24, 176), "SON", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)
	for s in SLIDERS:
		var y: float = s[1]
		var v: float = float(Game.get(s[2]))
		c.draw_string(f, Vector2(24, y + 10), s[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("e8eefc"))
		c.draw_string(f, Vector2(0, y + 6), "%d %%" % int(round(v * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, 696.0, 22, UI.MUTED)
		c.draw_style_box(UI.box(UI.LINE2, Color(0, 0, 0, 0), 6, 0), Rect2(24, y + 36, 672, 12))
		c.draw_style_box(UI.box(UI.ACCENT, Color(0, 0, 0, 0), 6, 0), Rect2(24, y + 36, maxf(12.0, 672.0 * v), 12))
		c.draw_circle(Vector2(24.0 + 672.0 * v - (22.0 if v >= 0.99 else 0.0), y + 42), 22.0, Color.WHITE)
		c.draw_line(Vector2(24, y + 74), Vector2(696, y + 74), UI.LINE2, 2.0)
	c.draw_string(f, Vector2(24, 440), "CONFORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)
	for tg in TOGGLES:
		var y: float = tg[1]
		var on: bool = bool(Game.get(tg[2]))
		c.draw_string(f, Vector2(24, y + 10), tg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("e8eefc"))
		c.draw_style_box(UI.box(UI.ACCENT if on else UI.LINE, Color(0, 0, 0, 0), 28, 0), Rect2(600, y - 26, 96, 56))
		c.draw_circle(Vector2(672.0 if on else 624.0, y + 2), 22.0, Color.WHITE)
		c.draw_line(Vector2(24, y + 50), Vector2(696, y + 50), UI.LINE2, 2.0)
	c.draw_string(f, Vector2(24, 918), "COMPTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)


func _input_body(ev: InputEvent, c: Control) -> void:
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var move := false
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
		down = ev.pressed
		up = not ev.pressed
	elif ev is InputEventScreenTouch:
		pos = ev.position
		down = ev.pressed
		up = not ev.pressed
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = ev.position
		move = true
	elif ev is InputEventScreenDrag:
		pos = ev.position
		move = true
	else:
		return
	if down:
		_drag = ""
		for s in SLIDERS:
			if absf(pos.y - (float(s[1]) + 42.0)) < 46.0:
				_drag = s[2]
		if _drag == "":
			for tg in TOGGLES:
				if absf(pos.y - (float(tg[1]) + 2.0)) < 50.0:
					Game.set(tg[2], not bool(Game.get(tg[2])))
					if tg[2] == "battery_saver":
						Game.apply_performance()
					Sfx.play("click", -6.0)
					changed.emit()
					c.queue_redraw()
					return
	if (down or move) and _drag != "":
		var v := clampf((pos.x - 24.0) / 672.0, 0.0, 1.0)
		Game.set(_drag, v)
		if _drag == "music_vol":
			Game.music_on = v > 0.01
			Sfx.refresh_music()
		elif up or down:
			Sfx.play("coin", -8.0)
		changed.emit()
		c.queue_redraw()
	if up:
		_drag = ""
