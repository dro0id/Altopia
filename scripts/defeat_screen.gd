class_name DefeatScreen
extends Overlay
## Équipe à terre (maquette BL) : persévérance, portraits, un conseil concret et trois choix. Jamais de blocage.

signal retry_pressed
signal farm_pressed
signal upgrade_pressed
signal recruit_pressed

var _st: Control
var _stage := 1
var _t := 0.0
var _body: Control


func _init(stage_n: int) -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	_stage = stage_n
	_body = Control.new()
	_body.size = Vector2(720, 800)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	_st.add_child(_body)
	var h := 1280.0
	var b1 := M3.button(_st, "Réessayer l'étage %d" % stage_n, Rect2(32, h - 32 - 96 - 16 - 96 - 16 - 104, 656, 104), "main", 32)
	b1.pressed.connect(func():
		retry_pressed.emit()
		close())
	var b2 := M3.button(_st, "Farmer l'étage %d" % maxi(1, stage_n - 1), Rect2(32, h - 32 - 96 - 16 - 96, 656, 96), "ghost", 30)
	b2.disabled = stage_n <= 1
	b2.pressed.connect(func():
		farm_pressed.emit()
		close())
	var b3 := M3.button(_st, "Améliorer l'équipe", Rect2(32, h - 32 - 96, 656, 96), "outline", 30)
	b3.pressed.connect(func():
		upgrade_pressed.emit()
		close())
	Sfx.play("lose", -4.0)


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()


## Conseil concret : le meilleur achat de niveau, sinon un héros à faire évoluer, sinon recruter.
func _advice() -> String:
	var id := Game.best_buy()
	if id != "":
		var lv: int = int(Game.levels[id])
		var gain := int(round((Data.hero_mult(lv + 1) / Data.hero_mult(lv) - 1.0) * 100.0))
		return "%s peut passer au niveau %d : +%d %% de puissance pour %s ¢." % [String(Data.HEROES[id].name).split(" ")[0], lv + 1, gain, UI.num(Game.level_cost(id))]
	for hid in Game.squad_ids():
		if Game.can_evolve(hid):
			return "%s doit évoluer pour continuer à monter de niveau." % String(Data.HEROES[hid].name).split(" ")[0]
	if Game.tokens >= Data.RECRUIT_COST:
		return "Tu as %d jetons : recrute un nouveau héros." % Game.tokens
	return "Farme l'étage précédent pour gagner des crédits."


func _draw_body() -> void:
	var c := _body
	for i in 10:
		c.draw_circle(Vector2(360, 160), 320.0 - i * 28.0, Color(1.0, 0.42, 0.42, 0.012))
	var fb := UI.bold_font()
	var txt := "ÉTAGE %d" % _stage
	var tw := 0.0
	for ch in txt:
		tw += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(24)).x + 3.0
	var x := (720.0 - tw) * 0.5
	for ch in txt:
		c.draw_string(fb, Vector2(x, 104), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(24), UI.RED)
		x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(24)).x + 3.0
	M3.text(c, Vector2(0, 168), "Équipe à terre", 56, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(32, 222), "Ta persévérance monte : +%d %% de puissance" % Game.perseverance_pct(), 28, UI.MUTED, false, 656, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(32, 260), "au prochain essai (max +%d %%)." % int(round(Data.PERSEVERANCE_STEP * Data.PERSEVERANCE_MAX * 100.0)), 28, UI.MUTED, false, 656, HORIZONTAL_ALIGNMENT_CENTER)
	var ids := Game.squad_ids()
	var x0 := 360.0 - (ids.size() * 104.0 + (ids.size() - 1) * 20.0) * 0.5
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in ids.size():
		var cc := Vector2(x0 + 52.0 + i * 124.0, 362)
		M3.avatar(c, Data.HEROES[ids[i]], cc, 52.0, UI.RED, _t)
		c.draw_circle(cc, 50.0, Color(0.04, 0.06, 0.12, 0.45))
	var r := Rect2(32, 452, 656, 168)
	M3.card(c, r)
	M3.text(c, r.position + Vector2(32, 52), "CONSEIL", 24, UI.GREEN, true)
	M3.para(c, r.position + Vector2(32, 96), _advice(), 28, UI.TEXT, 592)
