class_name SectorScreen
extends Overlay
## Nouveau secteur généré (maquette FB) : nom, décor, règle du secteur, boss du 10e étage, difficulté et butin.

var _info: Dictionary
var _t := 0.0
var _body: Control


func _init(stage: int) -> void:
	super._init(720.0)
	_info = Sector.info(stage)
	var st := use_stage(1.0)
	_body = Control.new()
	_body.size = Vector2(720, 1100)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	st.add_child(_body)
	var go := M3.button(st, "Entrer dans le secteur", Rect2(32, UI.H - 32 - 104, 656, 104), "main", 32)
	go.pressed.connect(close)
	Sfx.play("win", -6.0)


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()


func _draw_body() -> void:
	var c := _body
	var pal: Array = _info.palette
	var accent := Color(pal[6])
	c.draw_rect(Rect2(0, 0, 720, UI.H), Color(pal[0]))
	for k in 14:
		c.draw_circle(Vector2(360, 300), 420.0 - k * 26.0, Color(accent, 0.02))
	M3.text(c, Vector2(0, 104), "NOUVEAU SECTEUR · ÉTAGES %d À %d" % [int(_info.from), int(_info.to)], 24, accent, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(0, 176), String(_info.name), 60, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	# vignette du décor
	var r := Rect2(140, 220, 440, 300)
	var sky := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	c.draw_polygon(sky, PackedColorArray([Color(pal[0]), Color(pal[0]), Color(pal[1]), Color(pal[1])]))
	c.draw_circle(Vector2(r.position.x + 330, r.position.y + 80), 40, Color(pal[7]))
	var ridge := PackedVector2Array([Vector2(r.position.x, r.end.y)])
	for i in 9:
		ridge.append(Vector2(r.position.x + i * 55.0, r.end.y - 70.0 - (40.0 if i % 2 == 0 else 0.0) - 6.0 * sin(_t + i)))
	ridge.append(r.end)
	c.draw_colored_polygon(ridge, Color(pal[3]))
	c.draw_style_box(UI.box(Color(0, 0, 0, 0), Color(accent, 0.4), 48, 0), r)
	# règle du secteur
	var rr := Rect2(32, 560, 656, 200)
	M3.card(c, rr)
	M3.text(c, rr.position + Vector2(32, 52), "RÈGLE DU SECTEUR", 24, UI.ACCENT, true)
	var rc: Color = _info.rule_color
	var txt := "%s %s" % [String(_info.rule_glyph), String(_info.rule_text)]
	var w := minf(M3.text_w(txt, 24, true) + 40.0, 592.0)
	c.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 28, 0), Rect2(rr.position + Vector2(32, 76), Vector2(w, 56)))
	M3.text(c, rr.position + Vector2(52, 104 + M3.fs(24) * 0.36), txt, 24, rc, true, w - 40.0)
	M3.text(c, rr.position + Vector2(32, 172), "La règle s'applique à tous les combats du secteur.", 24, UI.MUTED, false, rr.size.x - 64.0)
	# boss
	var br := Rect2(32, 784, 656, 200)
	M3.card(c, br)
	M3.text(c, br.position + Vector2(32, 52), "BOSS DE L'ÉTAGE %d" % int(_info.to), 24, Color("ff9b9b"), true)
	M3.text(c, br.position + Vector2(32, 100), Data.boss_name(int(_info.to)), 30, UI.TEXT, true, 592)
	M3.text(c, br.position + Vector2(32, 140), "Trait : %s · %s" % [String(_info.boss_trait), String(Sector.TRAIT_TEXT[_info.boss_trait])], 24, UI.MUTED, false, 592)
	M3.text(c, br.position + Vector2(32, 178), ("Difficulté adaptée ×%.2f · butin ×%.2f" % [Sector.factor, Sector.factor]).replace(".", ","), 24, UI.GOLD, false, 592)
