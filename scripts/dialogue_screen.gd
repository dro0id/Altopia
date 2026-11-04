class_name DialogueScreen
extends Overlay
## Scène d'histoire (maquettes CE, CF, CG) : feuille du bas par-dessus le combat, une réplique par appui,
## réponse du Capitaine au besoin, « Passer » en haut. Avant un gros boss qui parle, le boss occupe le haut de l'écran.

signal finished(scene_id: String)

var _scene: Dictionary
var _lines: Array = []
var _i := 0
var _choice := -1
var _replay := false
var _st: Control
var _sheet: Control
var _btn: Button
var _opts: Array = []
var _t := 0.0


func _init(scene: Dictionary, replay := false) -> void:
	super._init(720.0)
	_scene = scene
	_replay = replay
	_lines = scene.lines.duplicate(true)
	if replay and Game.story_choices.has(scene.id):
		_choice = int(Game.story_choices[scene.id])
		for k in _lines.size():
			if _lines[k].has("choice"):
				var reply: Dictionary = _lines[k].replies[clampi(_choice, 0, 1)]
				_lines = _lines.slice(0, k + 1)
				_lines.append(reply)
				break
	var boss := _has_boss()
	_st = use_stage(1.0 if boss else 0.7)
	if boss:
		var top := Control.new()
		top.size = Vector2(720, 700)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.draw.connect(func():
			for k in 14:
				top.draw_circle(Vector2(360, 330), 360.0 - k * 24.0, Color(1.0, 0.42, 0.42, 0.018))
			var bob := sin(_t * 2.2) * 8.0
			_crystal(top, Vector2(360, 330 + bob), 2.6)
			top.draw_style_box(UI.box(Color("3a1620"), Color(0, 0, 0, 0), 40, 0), Rect2(32, 32, 336, 80))
			M3.text(top, Vector2(32, 72 + M3.fs(28) * 0.36), "☠ Étage %d · Gros boss" % int(_scene.stage), 28, Color("ff9b9b"), true, 336, HORIZONTAL_ALIGNMENT_CENTER))
		_st.add_child(top)
	var skip := M3.button(_st, "Passer ›", Rect2(520, 32, 168, 80), "ghost", 26)
	skip.pressed.connect(_finish)
	_sheet = Control.new()
	_sheet.size = Vector2(720, 720)
	_sheet.draw.connect(_draw_sheet)
	_sheet.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and _opts.is_empty():
			_next())
	_st.add_child(_sheet)
	_btn = M3.button(_st, "Continuer", Rect2(32, 1280 - 40 - 104, 656, 104), "main", 32)
	_btn.pressed.connect(_next)
	for k in 2:
		var o := M3.button(_st, "", Rect2(32, 0, 656, 112), "outline", 30)
		o.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for k2 in ["font_color", "font_hover_color", "font_pressed_color"]:
			o.add_theme_color_override(k2, UI.TEXT)
		var idx := k
		o.pressed.connect(func(): _pick(idx))
		_opts.append(o)
	_opts_hide()
	_layout()


func _has_boss() -> bool:
	for l in _lines:
		if Story.SPEAKERS.has(String(l.who)):
			return true
	return false


func _process(delta: float) -> void:
	_t += delta
	_st.queue_redraw()
	for c in _st.get_children():
		if c is Control:
			(c as Control).queue_redraw()


func _cur() -> Dictionary:
	return _lines[_i]


## Hauteur de la feuille selon la réplique (choix ou non, réplique suivante en aperçu).
func _layout() -> void:
	var l := _cur()
	var has_choice: bool = l.has("choice") and _choice < 0
	var text_h := _text_height(String(l.text))
	var h := 72.0 + 144.0 + 24.0 + text_h + 32.0
	if has_choice:
		h += 64.0 + 2 * 128.0 + 96.0
	else:
		if _peek() != {}:
			h += _peek_height() + 16.0
		h += 104.0 + 56.0
	_sheet.position = Vector2(0, 1280.0 - h)
	_sheet.size = Vector2(720, h)
	_btn.visible = not has_choice
	var last := _i >= _lines.size() - 1 and (not l.has("choice") or _choice >= 0)
	_btn.text = "Continuer"
	if _has_boss():
		_restyle(_btn, Color("ff6b6b"), Color("1a0505"))
		if last:
			_btn.text = "Combattre le %s" % String(Story.SPEAKERS.gardien.name).split(" ")[0]
	if has_choice:
		var y0 := _sheet.position.y + 72.0 + 144.0 + 24.0 + text_h + 32.0 + 64.0
		for k in 2:
			var o: Button = _opts[k]
			o.visible = true
			o.text = "« %s »" % String(l.choice[k])
			o.position = Vector2(32, y0 + k * 128.0)
	else:
		_opts_hide()


func _restyle(b: Button, fill: Color, fg: Color) -> void:
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.bg_color = fill
		sb.border_color = fill
		b.add_theme_stylebox_override(st, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fg)


func _opts_hide() -> void:
	for o in _opts:
		(o as Button).visible = false


func _text_height(s: String) -> float:
	var f := ThemeDB.fallback_font
	var words := s.split(" ")
	var line := ""
	var n := 1
	for w in words:
		var tryl := w if line == "" else line + " " + w
		if f.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(32)).x > 656.0 and line != "":
			n += 1
			line = w
		else:
			line = tryl
	return n * M3.fs(32) * 1.45


## Réplique suivante montrée en petit sous la réplique en cours (maquette CE).
func _peek() -> Dictionary:
	var l := _cur()
	if l.has("choice") or _i + 1 >= _lines.size():
		return {}
	return _lines[_i + 1]


func _draw_sheet() -> void:
	var c := _sheet
	var sb := UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size + Vector2(0, 40)))
	c.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, 16, 64, 8))
	var l := _cur()
	var sp := Story.speaker(String(l.who))
	_face(c, String(l.who), Vector2(104, 72 + 72), 72.0, sp.color)
	M3.text(c, Vector2(208, 132), String(sp.name), 32, sp.color, true, 360)
	M3.text(c, Vector2(208, 172), String(sp.role), 24, UI.MUTED, false, 360)
	M3.text(c, Vector2(0, 132), _step_label(), 24, UI.MUTED, false, 688, HORIZONTAL_ALIGNMENT_RIGHT)
	var y := 72.0 + 144.0 + 24.0
	y += M3.para(c, Vector2(32, y + M3.fs(32)), String(l.text), 32, UI.TEXT, 656) + 16.0
	if l.has("choice") and _choice < 0:
		M3.section(c, Vector2(32, y + 40), "TA RÉPONSE")
		M3.para(c, Vector2(32, y + 64 + 2 * 128.0 + 40.0), "Ta réponse change la réplique suivante, pas la suite de l'histoire.", 24, UI.MUTED, 656)
		return
	var pk := _peek()
	if not pk.is_empty():
		var ps := Story.speaker(String(pk.who))
		_face(c, String(pk.who), Vector2(68, y + 44), 36.0, ps.color)
		var nm := String(ps.name).split(" ")[0]
		M3.text(c, Vector2(120, y + 54), nm, 28, UI.TEXT, true)
		var first_w := 560.0 - M3.text_w(nm + " ", 28, true)
		# texte en aperçu sur plusieurs lignes : la première à côté du nom, les suivantes dessous
		var words := ("· " + String(pk.text)).split(" ")
		var line := ""
		var lines: Array = []
		var width := first_w
		for w in words:
			var tryl := w if line == "" else line + " " + w
			if M3.text_w(tryl, 28) > width and line != "":
				lines.append(line)
				line = w
				width = 560.0
			else:
				line = tryl
		lines.append(line)
		for k in lines.size():
			var x := 120.0 + (M3.text_w(nm + " ", 28, true) if k == 0 else 0.0)
			M3.text(c, Vector2(x, y + 54 + k * M3.fs(28) * 1.4), lines[k], 28, UI.MUTED)


func _peek_height() -> float:
	var pk := _peek()
	if pk.is_empty():
		return 0.0
	var f := ThemeDB.fallback_font
	var nm := String(Story.speaker(String(pk.who)).name).split(" ")[0]
	var w := f.get_string_size(nm + " · " + String(pk.text), HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(28)).x
	return maxf(80.0, ceilf(w / 560.0) * M3.fs(28) * 1.4 + 24.0)


func _step_label() -> String:
	if int(_scene.stage) > 0 and _lines.size() > 1:
		return "%d/%d" % [_i + 1, _lines.size()]
	return "Étage %d" % int(_scene.stage)


## Portrait d'un personnage : héros dessiné, ou le cristal du Gardien.
func _face(ci: CanvasItem, who: String, c: Vector2, r: float, ring: Color) -> void:
	if Story.SPEAKERS.has(who):
		ci.draw_circle(c, r, Color("0a1424"))
		_crystal(ci, c, r / 64.0)
		ci.draw_arc(c, r - 2.0, 0, TAU, 56, ring, 4.0, true)
	else:
		M3.avatar(ci, Data.HEROES[who], c, r, ring, _t)


## Le Gardien de verre : un cristal à facettes avec un cœur rouge.
static func _crystal(ci: CanvasItem, c: Vector2, k: float) -> void:
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x - 24.0, y - 24.0) * k * 2.0
	ci.draw_colored_polygon(PackedVector2Array([P.call(24, 2), P.call(38, 14), P.call(34, 42), P.call(14, 42), P.call(10, 14)]), Color(0.5, 0.86, 1.0, 0.9))
	ci.draw_colored_polygon(PackedVector2Array([P.call(24, 2), P.call(38, 14), P.call(24, 20), P.call(10, 14)]), Color("c9f2ff"))
	ci.draw_circle(P.call(24, 24), 5.0 * k * 2.0, Color("ff6b6b"))
	ci.draw_polyline(PackedVector2Array([P.call(14, 42), P.call(24, 20), P.call(34, 42)]), Color(0.04, 0.07, 0.15, 0.5), 1.5 * k * 2.0, true)


func _pick(k: int) -> void:
	_choice = k
	Sfx.play("click", -6.0)
	var l := _cur()
	# la réponse du Capitaine remplace la suite par la réplique qui lui répond
	var reply: Dictionary = l.replies[k]
	_lines = _lines.slice(0, _i + 1)
	_lines.append(reply)
	_i += 1
	_layout()


func _next() -> void:
	var l := _cur()
	if l.has("choice") and _choice < 0:
		return
	if _i >= _lines.size() - 1:
		_finish()
		return
	_i += 1
	Sfx.play("click", -10.0)
	_layout()


func _finish() -> void:
	if not _replay:
		Game.see_scene(String(_scene.id), _choice)
		Game.save_game()
	finished.emit(String(_scene.id))
	close()
