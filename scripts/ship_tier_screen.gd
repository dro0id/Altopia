class_name ShipTierScreen
extends Overlay
## Nouvelle version de l'Aurore (maquette PE) et niveau maximum (maquette QC) : le vaisseau tourne en 3D,
## avec ce que la version apporte. Au niveau 20, récompense unique : 300 cristaux et le titre « Amiral de l'Aurore ».

signal visit_requested

const NEWS := {
	2: ["4e module : le Labo s’ouvre (niveau 6)", "Couronne vitrée et dôme d’antennes", "Propulseur à fusion, radiateurs, Hangar au niveau 10"],
	3: ["5e module : la Serre s’ouvre au niveau 12", "Dôme vitré : l’Observatoire au niveau 14", "Double anneau de fusion, 4 propulseurs d’appoint"],
	4: ["Anneau de gravité tournant", "Finitions et propulseur dorés", "6 panneaux radiateurs"],
	5: ["Flèche de cristal et sphère armillaire", "Voiles de lumière, fusion prismatique", "Coque nacre et poussière d’or"],
}
const PRESTIGE_CRYSTALS := 300

var _tier := 2
var _t := 0.0
var _body: Control


func _init(level: int) -> void:
	super._init(720.0)
	_tier = Ship.tier_of(level)
	var st := use_stage(1.0)
	var view := ShipView.new()
	view.position = Vector2(0, 150)
	view.size = Vector2(720, 640)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(view)
	view.setup(level, Game.ship.posts)
	view.yaw = -0.5
	view.anims.append(func(t): view.yaw = -0.5 + t * 0.25)
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	st.add_child(_body)
	st.move_child(_body, 0)
	var label := "Admirer l’Aurore" if _tier == 5 else "Voir l’Aurore"
	var b := M3.button(st, label, Rect2(32, 1280 - 40 - 104, 656, 104), "gold" if _tier == 5 else "main", 32)
	b.pressed.connect(func():
		visit_requested.emit()
		close())
	if _tier == 5 and not Game.tips.has("prestige"):
		Game.tips.append("prestige")
		Game.crystals += PRESTIGE_CRYSTALS
		Game.save_game()
	Sfx.play("win")


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()


func _draw_body() -> void:
	var c := _body
	var ti: Dictionary = Ship.TIERS[_tier - 1]
	var prem := _tier == 5
	var accent: Color = UI.GOLD if prem else ti.color
	c.draw_rect(Rect2(0, 0, 720, 1280), Color("05060f") if prem else Color("070b1a"))
	for k in 16:
		c.draw_circle(Vector2(360, 470), 440.0 - k * 26.0, Color(accent, 0.012))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 90:
		var p := Vector2(rng.randf() * 720.0, rng.randf() * 1280.0)
		c.draw_circle(p, 1.4, Color(1, 1, 1, 0.3 + 0.3 * sin(_t * 1.5 + i)))
	if prem:
		for i in 26:
			var p := Vector2(fmod(i * 97.0, 700.0) + 10.0, 1280.0 - fmod(_t * (30.0 + i * 3.0) + i * 130.0, 1280.0))
			c.draw_circle(p, 3.0 + i % 3, Color(UI.GOLD, 0.7))
		c.draw_style_box(_frame(), Rect2(20, 20, 680, 1240))
	var eyebrow := "NIVEAU MAXIMUM" if prem else "L’AURORE PASSE AU NIVEAU %d" % int(ti.from)
	M3.text(c, Vector2(0, 76), eyebrow, 24, accent, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(0, 132), "L’Aurore est éternelle" if prem else "%s · %s" % [ti.name, ti.sub], 44, UI.GOLD if prem else UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	var r := Rect2(32, 800, 656, 300)
	c.draw_style_box(UI.box(Color("120f24") if prem else M3.SHEET, Color(UI.GOLD, 0.5) if prem else Color(0, 0, 0, 0), 40, 0), r)
	M3.text(c, r.position + Vector2(32, 52), "RÉCOMPENSES" if prem else "NOUVEAU", 24, accent, true)
	var lines: Array = NEWS.get(_tier, [])
	if prem:
		lines = ["Titre « Amiral de l’Aurore »", "+%d cristaux" % PRESTIGE_CRYSTALS, "Design unique : " + String(NEWS[5][0]).to_lower()]
	for i in lines.size():
		M3.text(c, r.position + Vector2(32, 112 + i * 60), "✦  " + String(lines[i]), 28, UI.TEXT, false, 600)


func _frame() -> StyleBoxFlat:
	var sb := UI.box(Color(0, 0, 0, 0), Color(UI.GOLD, 0.35), 44, 0)
	sb.set_border_width_all(2)
	return sb
