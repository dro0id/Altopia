class_name EvolveScreen
extends Overlay
## Évolution (maquette BN), plein écran : portrait, palier visé, ce qu'il apporte, coût, bouton Évoluer.

signal evolved

var _t := 0.0
var _hero: Dictionary
var _head: Control


func _init(id: String) -> void:
	super._init(720.0)
	_hero = Data.HEROES[id]
	var tier: int = Game.tier(id)
	var lv: int = Game.levels[id]
	var st := use_stage(1.0)
	M3.top_bar(st, "Évolution", close)
	_head = Control.new()
	_head.position = Vector2(0, 112)
	_head.size = Vector2(720, 380)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.draw.connect(func():
		for i in 12:
			_head.draw_circle(Vector2(360, 140), 300.0 - i * 22.0, Color(0.7, 0.53, 1.0, 0.02))
		M3.avatar(_head, _hero, Vector2(360, 140), 112.0, Color("b388ff"), _t)
		M3.text(_head, Vector2(0, 312), "%s · Palier %d" % [String(_hero.name).split(" ")[0], tier + 2], 44, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(_head, Vector2(0, 352), "Niveau %d atteint" % lv, 26, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER))
	st.add_child(_head)
	var stat_gain := int(round((Data.EVO_STAT_MULT[tier + 1] / Data.EVO_STAT_MULT[tier] - 1.0) * 100.0))
	var cost: Dictionary = Game.evolve_cost(id)
	var body := Control.new()
	body.position = Vector2(0, 496)
	body.size = Vector2(720, 420)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.draw.connect(func():
		var rows := [["Statistiques", "+%d %%" % stat_gain, 1], ["Pouvoir ×%s" % String.num(Data.EVO_SKILL_MULT[tier + 1], 1).replace(".", ","), "Dégâts et soins", 0], ["Niveau max %d" % Data.level_cap(tier + 1), "Le héros peut continuer à monter", 3]]
		for i in rows.size():
			var r := Rect2(32, i * 128.0, 656, 112)
			M3.row(body, r)
			SkillButton.draw_glyph(body, int(rows[i][2]), r.position + Vector2(56, 56), UI.TEXT, 0.5)
			M3.text(body, r.position + Vector2(104, 48), rows[i][0], 30, UI.TEXT, true)
			M3.text(body, r.position + Vector2(104, 84), rows[i][1], 24, UI.MUTED)
			body.draw_colored_polygon(PackedVector2Array([r.position + Vector2(608, 66), r.position + Vector2(632, 66), r.position + Vector2(620, 46)]), UI.GREEN)
		M3.text(body, Vector2(32, 418), "COÛT", 24, UI.MUTED))
	st.add_child(body)
	var cc := M3.cur_chip("coin", Data.fmt(cost.credits))
	cc.position = Vector2(32, 936)
	cc.text_color = UI.TEXT if Game.credits >= cost.credits else UI.RED
	st.add_child(cc)
	var sc := M3.cur_chip("shard", "%d / %d" % [mini(Game.shards, int(cost.shards)), int(cost.shards)])
	sc.position = Vector2(32 + cc.size.x + 16, 936)
	sc.text_color = UI.TEXT if Game.shards >= cost.shards else UI.RED
	st.add_child(sc)
	var go := M3.button(st, "Évoluer", Rect2(32, 1280 - 32 - 104, 656, 104), "main", 32)
	go.disabled = not (Game.credits >= cost.credits and Game.shards >= cost.shards)
	if go.disabled:
		go.text = "Pas assez de ressources"
	go.pressed.connect(func():
		if Game.evolve(id):
			Sfx.play("chest")
			evolved.emit()
			close())


func _process(delta: float) -> void:
	_t += delta
	_head.queue_redraw()
