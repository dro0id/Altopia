class_name AboardScreen
extends Overlay
## « Bienvenue à bord » (maquette RF), une seule fois après le déblocage de l'Aurore :
## le jeu s'ouvre désormais sur le vaisseau, et le combat devient sa mission.

signal board_requested

const POINTS := [
	["ship", "L’Aurore est ton port d’attache", "le jeu s’ouvre toujours sur elle"],
	["up", "Prépare-la pendant le voyage", "6 objectifs de bord jusqu’à la Ceinture"],
	["swords", "À l’arrivée, la mission commence", "le combat tourne seul, même jeu fermé"],
]
## Partie déjà arrivée (sauvegarde d'avant le chapitre 1 à bord) : l'Aurore devient l'accueil, le combat sa mission.
const POINTS_HOME := [
	["ship", "Le jeu s’ouvre sur l’Aurore", "ton vaisseau devient l’écran d’accueil"],
	["swords", "Le combat devient ta mission", "il continue seul, même jeu fermé"],
	["up", "Les gains remplissent les soutes", "récolte, puis fais grandir l’Aurore"],
]

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
	var view := ShipView.new()
	view.position = Vector2(110, 150)
	view.size = Vector2(500, 600)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(view)
	view.setup(Game.ship.level, Game.ship.posts, Game.ship.rooms)
	view.yaw = -0.4
	view.anims.append(func(t): view.yaw = -0.4 + t * 0.2)
	var b := M3.button(st, "Monter à bord", Rect2(64, UI.H - 64 - 104, 592, 104), "main", 32)
	b.pressed.connect(func():
		board_requested.emit()
		close())
	Sfx.play("win")


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()


func _draw_body() -> void:
	var c := _body
	c.draw_rect(Rect2(0, 0, 720, UI.H), Color("070b1a"))
	for k in 16:
		c.draw_circle(Vector2(360, 460), 420.0 - k * 25.0, Color(0.31, 0.85, 1.0, 0.012))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 90:
		var p := Vector2(rng.randf() * 720.0, rng.randf() * UI.H)
		c.draw_circle(p, 1.4, Color(1, 1, 1, 0.3 + 0.3 * sin(_t * 1.5 + i)))
	M3.text(c, Vector2(0, 84), "TON PORT D’ATTACHE", 24, UI.ACCENT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(0, 140), "Bienvenue à bord", 48, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	var r := Rect2(36, 770, 648, 296)
	M3.card(c, r, M3.S2, 40)
	var pts: Array = POINTS_HOME if Game.mission_open() else POINTS
	for i in pts.size():
		var y := r.position.y + 32.0 + i * 88.0
		var ib := Rect2(r.position.x + 28, y, 64, 64)
		c.draw_style_box(UI.box(Color("1a1530"), Color(UI.GOLD, 0.4), 20, 0), ib)
		_glyph(c, String(pts[i][0]), ib.get_center())
		M3.text(c, Vector2(r.position.x + 116, y + 28), String(pts[i][1]), 28, UI.TEXT, true, 500)
		M3.text(c, Vector2(r.position.x + 116, y + 60), String(pts[i][2]), 22, UI.MUTED, false, 500)


func _glyph(c: Control, kind: String, p: Vector2) -> void:
	var col := UI.GOLD
	match kind:
		"ship":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -18), p + Vector2(8, -5), p + Vector2(8, 9), p + Vector2(-8, 9), p + Vector2(-8, -5)]), col)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 2), p + Vector2(-14, 13), p + Vector2(-8, 11)]), col)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(8, 2), p + Vector2(14, 13), p + Vector2(8, 11)]), col)
		"swords":
			c.draw_line(p + Vector2(-12, 12), p + Vector2(12, -12), col, 3.0, true)
			c.draw_line(p + Vector2(-12, -12), p + Vector2(12, 12), col, 3.0, true)
		"up":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -15), p + Vector2(13, 2), p + Vector2(5, 2), p + Vector2(5, 14), p + Vector2(-5, 14), p + Vector2(-5, 2), p + Vector2(-13, 2)]), col)
