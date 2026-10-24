class_name IntroUI
extends Control
## Introduction animée (maquette « Acte 1 ») : six écrans, de la Terre au saut vers l'inconnu, puis la première mission du tutoriel.
## Fondu enchaîné, zoom lent, secousse et compte à rebours au décollage. « Passer » saute tout. Émet `finished` à la fin.

signal finished

const UiTheme = preload("res://scripts/ui_theme.gd")
const CrewView = preload("res://scripts/crew_view.gd")
const Data = preload("res://scripts/game_data.gd")

const GOLD := Color("ffd159")
const IMG := "res://assets/intro/%s.jpg"
const VANCE_LINE := "Capitaine, la source du signal est hors de toute carte. Le vaisseau est prêt, l'équipage aussi. La mission Altopia est à vous."
const SIGNAL_LINE := "Un signal régulier, venu d'un point où il n'y a pas d'étoile. Trois impulsions, puis le silence. Comme une invitation."

var _page := -1
var _bg: TextureRect
var _shade: ColorRect
var _layer: Control            # contenu de l'écran courant (reconstruit à chaque page)
var _fade: ColorRect
var _skip: Button
var _count_gen := 0
var _tween: Tween
var _zoom: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.01, 0.02, 0.06, 0.45)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)
	_skip = Button.new()
	_skip.text = "Passer"
	_skip.flat = true
	_skip.add_theme_font_size_override("font_size", 24)
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_left = -170
	_skip.offset_right = -20
	_skip.offset_top = 40
	_skip.offset_bottom = 100
	_skip.pressed.connect(_finish)
	add_child(_skip)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_go(0)


func _finish() -> void:
	_count_gen += 1
	finished.emit()


## Passe à l'écran n : fondu au noir, reconstruction, fondu depuis le noir et zoom lent sur l'image.
func _go(n: int) -> void:
	_count_gen += 1
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	if _page >= 0:
		_tween.tween_property(_fade, "color:a", 1.0, 0.25)
	else:
		_fade.color.a = 1.0
	_tween.tween_callback(_build.bind(n))
	_tween.tween_property(_fade, "color:a", 0.0, 0.8 if n == 0 else 0.5)


func _build(n: int) -> void:
	_page = n
	_count_gen += 1
	for c in _layer.get_children():
		c.queue_free()
	var pages := ["pad", "briefing", "cockpit", "launch", "orbit", "cruise"]
	_bg.texture = load(IMG % pages[n])
	_bg.pivot_offset = size / 2.0
	_bg.scale = Vector2.ONE
	if _zoom != null:
		_zoom.kill()
	_zoom = create_tween()
	_zoom.tween_property(_bg, "scale", Vector2.ONE * (1.12 if n != 3 else 1.25), 10.0)
	_shade.color = Color(0.01, 0.02, 0.06, 0.35 if n in [0, 4, 5] else 0.5)
	_skip.visible = n < 5
	match n:
		0: _page_earth()
		1: _page_mission()
		2: _page_crew()
		3: _page_launch()
		4: _page_orbit()
		5: _page_jump()


# ---------- éléments communs ----------

func _label(parent: Control, text: String, px: int, col: Color = UiTheme.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Colonne ancrée en bas de l'écran (marges de 28), qui contient le texte et le bouton.
func _bottom_column(bottom: float = 70.0) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	col.anchor_top = 1.0
	col.offset_left = 28
	col.offset_right = -28
	col.offset_bottom = -bottom
	col.offset_top = -bottom
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(col)
	return col


func _panel(parent: Control, accent: Color = UiTheme.ACCENT) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card_box(accent))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	return v


func _button(parent: Control, text: String, primary := true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 28)
	if primary:
		UiTheme.style_primary(b)
	parent.add_child(b)
	return b


func _speaker(parent: Control, _hero: String, name_text: String, role_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var n := _label(row, name_text, 34, UiTheme.ACCENT)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	var r := _label(row, role_text, 20, UiTheme.DIM)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.size_flags_vertical = Control.SIZE_SHRINK_END


## Un personnage en 3D, debout au centre de l'écran, qui parle.
func _stage_character(hero: String, clip := "Talk") -> void:
	var v := CrewView.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 80
	v.offset_bottom = -540
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(v)
	v.hero_id = hero
	v._auto = true
	v.call_deferred("show_hero", hero)
	v.call_deferred("play", clip)


# ---------- les six écrans ----------

func _page_earth() -> void:
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 130
	top.offset_left = 28
	top.offset_right = -28
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(top)
	var tv := VBoxContainer.new()
	tv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(tv)
	_label(tv, "TERRE · BASE DE LANCEMENT ORION", 22, UiTheme.DIM)
	_label(tv, "L'aube se lève\nsur le départ.", 60, Color.WHITE)
	var col := _bottom_column()
	var p := _panel(col)
	_label(p, "NARRATION", 18, UiTheme.DIM)
	_label(p, "Un signal est venu des confins du système. Personne n'a su dire d'où. Il a fallu quelqu'un pour aller voir.", 26)
	_button(col, "Suivant").pressed.connect(_go.bind(1))


func _page_mission() -> void:
	_stage_character("vance")
	var col := _bottom_column()
	var p := _panel(col)
	_speaker(p, "vance", "Commandante Vance", "Direction des missions")
	var quote := _label(p, "« %s »" % VANCE_LINE, 26)
	var more := _button(col, "Que sait-on du signal ?", false)
	more.custom_minimum_size = Vector2(0, 64)
	more.add_theme_font_size_override("font_size", 24)
	more.pressed.connect(func():
		quote.text = "« %s »" % SIGNAL_LINE
		more.visible = false)
	_button(col, "J'accepte la mission").pressed.connect(_go.bind(2))


func _page_crew() -> void:
	_stage_character("rex")
	var col := _bottom_column()
	var p := _panel(col)
	_speaker(p, "rex", "Rex", "Pilote · niv. 1")
	_label(p, "« Systèmes verts, Capitaine. Bolt garde les machines, Lumi les données, moi la barre. Il ne reste qu'à s'installer. »", 26)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for e in [["rex", "Rex", "Pilote"], ["bolt", "Bolt", "Ingénieur"], ["lumi", "Lumi", "Scientifique"]]:
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.12, 0.2, 0.9), UiTheme.LINE, 6, 1, 8))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(v)
		_label(v, e[1], 26, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_label(v, e[2], 18, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_button(col, "Décoller").pressed.connect(_go.bind(3))


func _page_launch() -> void:
	_skip.visible = true
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 150
	top.offset_left = 28
	top.offset_right = -28
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(top)
	_label(top, "DÉCOLLAGE DANS", 26, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var num := _label(top, "3", 200, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var col := _bottom_column()
	var p := _panel(col, UiTheme.WARN)
	_label(p, "TOUR DE CONTRÔLE", 18, UiTheme.DIM)
	_label(p, "« Trois… deux… un… Altopia, vous avez l'autorisation. Bon vent, Capitaine. »", 26)
	var thr := _label(p, "poussée 35 %", 22, UiTheme.WARN)
	_countdown(num, thr, _count_gen)


func _countdown(num: Label, thr: Label, gen: int) -> void:
	for k in [3, 2, 1, 0]:
		if gen != _count_gen or not is_inside_tree():
			return
		num.text = "0" if k == 0 else str(k)
		thr.text = "poussée %d %%" % [35, 55, 80, 100][3 - k]
		_shake(10.0 + 6.0 * (3 - k))
		await get_tree().create_timer(0.95).timeout
	if gen == _count_gen and is_inside_tree():
		var w := create_tween()
		w.tween_property(_fade, "color", Color.WHITE, 0.35)       # passage par le blanc : le vaisseau quitte l'atmosphère
		w.tween_callback(_go.bind(4))


func _shake(amount: float) -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(_layer, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.05)
	t.tween_property(_layer, "position", Vector2.ZERO, 0.05)


func _page_orbit() -> void:
	_fade.color = Color(1, 1, 1, 1)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 130
	top.offset_left = 28
	top.offset_right = -28
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(top)
	_label(top, "ORBITE TERRESTRE · 420 KM", 22, UiTheme.DIM)
	_label(top, "Dernier regard\nsur la Terre.", 56, Color.WHITE)
	var col := _bottom_column()
	var p := _panel(col)
	_speaker(p, "bolt", "Bolt", "Ingénieur")
	_label(p, "« Moteur de saut chargé. Après ça, plus de carte, plus de retour direct. On y va quand vous voulez. »", 26)
	_button(col, "Sauter vers l'inconnu").pressed.connect(_jump)


func _jump() -> void:
	_count_gen += 1
	# les étoiles s'étirent une seconde, puis fondu enchaîné vers la croisière
	var t := create_tween()
	t.tween_property(_bg, "scale", Vector2(1.0, 2.6), 0.9).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_fade, "color", Color.WHITE, 0.9)
	t.tween_callback(_go.bind(5))


func _page_jump() -> void:
	_fade.color = Color.WHITE
	create_tween().tween_property(_fade, "color:a", 0.0, 0.9)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 150
	top.offset_left = 28
	top.offset_right = -28
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(top)
	_label(top, "SAUT RÉUSSI · SECTEUR INCONNU", 22, UiTheme.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_label(top, "ALTOPIA", 84, UiTheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_label(top, "Le voyage commence.", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var m: Dictionary = Data.TUTO[0]
	var col := _bottom_column()
	var p := _panel(col, GOLD)
	_label(p, "MISSION 1 / %d · récompense : %s" % [Data.TUTO.size(), Data.fmt_amounts(m.reward)], 20, GOLD)
	_label(p, String(m.title), 36)
	_label(p, String(m.text), 22, UiTheme.DIM)
	_button(col, "Commencer").pressed.connect(_finish)
