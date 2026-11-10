class_name EvolveScreen
extends Overlay
## Nouvelle étoile (maquette BN refaite), plein écran : portrait, étoile visée, ce qu'elle apporte,
## doublons demandés (ceux du héros, puis ceux « au choix »), bouton pour monter d'une étoile.

signal evolved

var _t := 0.0
var _hero: Dictionary
var _head: Control


func _init(id: String) -> void:
	super._init(720.0)
	_hero = Data.HEROES[id]
	var rank: int = int(Game.hero_stars[id])
	var nxt := rank + 1
	var lv: int = Game.levels[id]
	var st := use_stage(1.0)
	set_backdrop(UI.GOLD)
	M3.top_bar(st, "Nouvelle étoile", close)
	_head = Control.new()
	_head.position = Vector2(0, 112)
	_head.size = Vector2(720, 380)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.draw.connect(func():
		for i in 12:
			_head.draw_circle(Vector2(360, 140), 300.0 - i * 22.0, Color(1.0, 0.82, 0.4, 0.02))
		M3.avatar(_head, _hero, Vector2(360, 140), 112.0, Color("ffd166"), _t)
		M3.text(_head, Vector2(0, 312), "%s · %s" % [String(_hero.name).split(" ")[0], HeroScreen.star_text(nxt)], 44, UI.GOLD if nxt >= Data.MAX_STARS else UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(_head, Vector2(0, 352), "Niveau %d atteint" % lv, 26, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER))
	st.add_child(_head)
	# ce que l'étoile apporte
	var rows: Array = []
	if nxt <= 5:
		rows.append(["Niveaux %d à %d" % [Data.level_cap(rank) + 1, Data.level_cap(nxt)], "La limite de niveau monte", "up"])
	else:
		rows.append(["Étoile maximale", "La limite reste le niveau %d" % Data.level_cap(rank), "star"])
	var stat_gain := int(round((Data.star_mult(nxt) * Data.EVO_STAT_MULT[clampi(nxt - 1, 0, 2)] / (Data.star_mult(rank) * Data.EVO_STAT_MULT[clampi(rank - 1, 0, 2)]) - 1.0) * 100.0))
	rows.append(["Statistiques", "+%d %%" % stat_gain, "heart"])
	if clampi(nxt - 1, 0, 2) > clampi(rank - 1, 0, 2):
		rows.append(["Pouvoir ×%s" % String.num(Data.EVO_SKILL_MULT[clampi(nxt - 1, 0, 2)], 1).replace(".", ","), "Dégâts et soins", "power"])
	var body := Control.new()
	body.position = Vector2(0, 496)
	body.size = Vector2(720, 420)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.draw.connect(func():
		for i in rows.size():
			var r := Rect2(32, i * 120.0, 656, 104)
			M3.row(body, r)
			var c0 := r.position + Vector2(56, 52)
			match String(rows[i][2]):
				"heart":
					_heart(body, c0)
				"power":
					body.draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, -18), c0 + Vector2(5, -5), c0 + Vector2(18, 0), c0 + Vector2(5, 5), c0 + Vector2(0, 18), c0 + Vector2(-5, 5), c0 + Vector2(-18, 0), c0 + Vector2(-5, -5)]), UI.TEXT)
				"star":
					_star(body, c0, UI.GOLD)
				_:
					body.draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, -16), c0 + Vector2(16, 6), c0 + Vector2(6, 6), c0 + Vector2(6, 16), c0 + Vector2(-6, 16), c0 + Vector2(-6, 6), c0 + Vector2(-16, 6)]), UI.TEXT)
			M3.text(body, r.position + Vector2(104, 44), String(rows[i][0]), 30, UI.TEXT, true, 420)
			M3.text(body, r.position + Vector2(104, 80), String(rows[i][1]), 24, UI.MUTED, false, 420)
			body.draw_colored_polygon(PackedVector2Array([r.position + Vector2(608, 62), r.position + Vector2(632, 62), r.position + Vector2(620, 42)]), UI.GREEN)
		M3.text(body, Vector2(32, rows.size() * 120.0 + 28), "DOUBLONS", 24, UI.MUTED))
	st.add_child(body)
	var cost := Game.star_cost(id)
	var own := mini(int(Game.fragments[id]), cost)
	var from_wild := mini(Game.wild, cost - own)
	var yy := 496.0 + rows.size() * 120.0 + 56.0
	var cc := M3.cur_chip("copies", "%d / %d" % [own, cost])
	cc.position = Vector2(32, yy)
	cc.text_color = UI.TEXT if own >= cost else UI.MUTED
	st.add_child(cc)
	var wc := M3.cur_chip("copies", "au choix %d" % Game.wild)
	wc.position = Vector2(32 + cc.size.x + 16, yy)
	wc.text_color = UI.TEXT if from_wild > 0 else UI.MUTED
	st.add_child(wc)
	var go := M3.button(st, "Monter à %s" % HeroScreen.star_text(nxt), Rect2(32, UI.H - 32 - 104, 656, 104), "premium", 32)
	go.disabled = not Game.can_star_up(id)
	if go.disabled:
		go.text = "Il manque %d doublon%s" % [cost - Game.copies_for(id), "s" if cost - Game.copies_for(id) > 1 else ""]
	go.pressed.connect(func():
		if Game.star_up(id):
			Sfx.play("chest")
			evolved.emit()
			close())


func _process(delta: float) -> void:
	_t += delta
	_head.queue_redraw()


func _star(ci: CanvasItem, c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (20.0 if i % 2 == 0 else 8.5))
	ci.draw_colored_polygon(pts, col)


func _heart(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c + Vector2(-8, -5), 10, UI.TEXT)
	ci.draw_circle(c + Vector2(8, -5), 10, UI.TEXT)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-17, -1), c + Vector2(17, -1), c + Vector2(0, 17)]), UI.TEXT)
