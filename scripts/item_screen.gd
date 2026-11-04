class_name ItemScreen
extends Overlay
## Base des écrans d'équipement plein écran : barre du haut de la refonte (retour, titre, actions), puis placement libre en 720 × 1280.

var st: Control
var _t := 0.0


func _init(title: String, actions: Array = []) -> void:
	super._init(720.0)
	st = use_stage(1.0)
	M3.top_bar(st, title, close, actions)


func _process(delta: float) -> void:
	_t += delta


func set_title(txt: String) -> void:
	(st.get_node("TopBar/Title") as Label).text = txt


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
	return M3.button(st, text, Rect2(pos, sz), kind, fs)


func tap(ev: InputEvent) -> bool:
	return (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
