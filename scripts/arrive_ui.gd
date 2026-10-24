class_name ArriveUI
extends Control
## Arrivée à destination (maquette « Acte 3 ») : le vaisseau se pose, c'est la première refonte et la Base se débloque.
## Émet `landed` quand le joueur confirme ; c'est main.gd qui récupère alors la dernière mission (et applique la refonte).

signal landed

const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var bg := TextureRect.new()
	bg.texture = load("res://assets/intro/arrive.jpg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.06, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 120
	top.offset_left = 28
	top.offset_right = -28
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_label(top, "FIN DU VOYAGE · PLANÈTE INCONNUE", 22, UiTheme.DIM)
	_label(top, "Le signal\nest là.", 64, Color.WHITE)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	col.anchor_top = 1.0
	col.offset_left = 28
	col.offset_right = -28
	col.offset_top = -70
	col.offset_bottom = -70
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card_box(UiTheme.ACCENT))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	_label(v, "Le vaisseau se pose. L'équipage décharge de quoi bâtir une Base : on y accueillera de nouveaux équipiers et de vraies salles.", 24)
	_label(v, "VOUS GARDEZ", 18, UiTheme.GOOD)
	_label(v, "Équipage · Capitaine · équipement · recherches · objectifs · bonus de refonte", 21, UiTheme.TEXT)
	_label(v, "REPART À ZÉRO", 18, UiTheme.WARN)
	_label(v, "Ressources · niveaux des postes et des améliorations du vaisseau", 21, UiTheme.TEXT)
	_label(v, "+%d points de refonte · Rang 1" % Data.ARRIVAL_SHARDS, 24, Color("ffd159"))
	var b := Button.new()
	b.text = "Atterrir et bâtir la Base"
	b.custom_minimum_size = Vector2(0, 90)
	b.add_theme_font_size_override("font_size", 28)
	UiTheme.style_primary(b)
	b.pressed.connect(func(): landed.emit())
	col.add_child(b)


func _label(parent: Control, text: String, px: int, col: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
