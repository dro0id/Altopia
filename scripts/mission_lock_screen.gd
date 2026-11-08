class_name MissionLockScreen
extends Overlay
## Onglet Mission pendant le voyage (maquette SF) : le combat se joue dans le Trou de verre, à l'arrivée.

signal home_requested

var _t := 0.0
var _body: Control


func _init() -> void:
	super._init(720.0)
	var st := use_stage(1.0)
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	st.add_child(_body)
	var b := M3.button(st, "Retour à l’Aurore", Rect2(64, 860, 592, 104), "main", 30)
	b.pressed.connect(func():
		home_requested.emit()
		close())


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()


func _draw_body() -> void:
	var c := _body
	c.draw_rect(Rect2(0, 0, 720, UI.H), Color("070b1a"))
	for k in 14:
		c.draw_circle(Vector2(360, 360), 380.0 - k * 26.0, Color(1.0, 0.82, 0.4, 0.012))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 80:
		var p := Vector2(rng.randf() * 720.0, rng.randf() * UI.H)
		c.draw_circle(p, 1.3, Color(1, 1, 1, 0.3 + 0.25 * sin(_t * 1.4 + i)))
	c.draw_circle(Vector2(360, 330), 96, M3.S2)
	M3.lock(c, Vector2(360, 340), UI.GOLD, 3.0)
	M3.text(c, Vector2(0, 500), "TROU DE VERRE · EN ROUTE", 24, UI.GOLD, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(0, 560), "Le Trou de verre t’attend à l’arrivée", 38, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.para(c, Vector2(72, 620), "Le combat se joue dans le Trou de verre, au cœur de la Ceinture d’Altopia. Termine les objectifs de bord pour y arriver.", 26, UI.MUTED, 576)
	ShipScreen.draw_voyage(c, Rect2(96, 760, 528, 60), Game.voyage_done())
