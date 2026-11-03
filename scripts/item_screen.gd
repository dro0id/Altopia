class_name ItemScreen
extends Overlay
## Base des écrans d'équipement plein écran : bandeau avec retour et titre, puis placement libre en 720 × 1280.

var st: Control
var _t := 0.0


func _init(title: String) -> void:
	super._init(720.0)
	st = use_stage(1.0)
	var band := ColorRect.new()
	band.color = UI.BAR
	band.size = Vector2(720, 128)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(band)
	var back := Button.new()
	back.text = "‹"
	back.position = Vector2(32, 24)
	back.size = Vector2(80, 80)
	back.add_theme_font_size_override("font_size", 36)
	for sn in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(sn, UI.box(UI.LINE2, Color(0, 0, 0, 0), 24, 0))
	back.pressed.connect(close)
	st.add_child(back)
	var tl := UI.label(st, title, 32, Color.WHITE, true)
	tl.position = Vector2(132, 40)
	tl.name = "Title"


func _process(delta: float) -> void:
	_t += delta


func set_title(txt: String) -> void:
	(st.get_node("Title") as Label).text = txt


## Étiquette posée à une position absolue.
func lab(text: String, size: int, col: Color, pos: Vector2, width := 0.0, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UI.label(st, text, size, col, bold)
	l.position = pos
	if width > 0.0:
		l.size = Vector2(width, size + 14)
		l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Contrôle dessiné à la main, posé à une position absolue.
func canvas(pos: Vector2, sz: Vector2, drawer: Callable) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.draw.connect(drawer.bind(c))
	st.add_child(c)
	return c


func button(text: String, kind: String, pos: Vector2, sz: Vector2, fs := 28) -> Button:
	var b := UI.button(st, text, fs, kind)
	b.position = pos
	b.size = sz
	b.custom_minimum_size = Vector2(0, sz.y)
	return b


func tap(ev: InputEvent) -> bool:
	return (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
