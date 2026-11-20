class_name PetsScreen
extends Overlay
## Familiers de verre (maquette WI) : l'éclosoir de la Serre, les six familiers, celui qui suit l'escouade.

const BAND := Rect2(24, 128, 672, 330)
const GRID_Y := 482.0
const CARD := Vector2(216, 176)

var _st: Control
var _body: Control
var _feed: Button
var _t := 0.0
var _figs := {}            # kind -> Node2D
var _big: Node2D


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	set_backdrop(Color("7dffb0"))
	M3.top_bar(_st, "Familiers", close)
	_body = Control.new()
	_body.size = Vector2(720, UI.H)
	_body.draw.connect(_draw_body)
	_body.gui_input.connect(_input)
	_st.add_child(_body)
	for i in Pets.ORDER.size():
		var kind := String(Pets.ORDER[i])
		var fig := Node2D.new()
		fig.position = _card(i).position + Vector2(CARD.x * 0.5, 84)
		fig.scale = Vector2(0.9, 0.9)
		var k := kind
		fig.draw.connect(func(): EnemyArt.draw(fig, "mite", {"t": _t + float(Pets.ORDER.find(k)), "pal": Pets.palette(k)}))
		_body.add_child(fig)
		_figs[kind] = fig
	_big = Node2D.new()
	_big.position = BAND.position + Vector2(500, 250)
	_big.scale = Vector2(1.7, 1.7)
	_big.draw.connect(func():
		var f: Dictionary = Game.follower()
		if not f.is_empty():
			EnemyArt.draw(_big, "mite", {"t": _t, "pal": Pets.palette(String(f.kind)), "move": 0.3}))
	_body.add_child(_big)
	_feed = M3.button(_st, "", Rect2(32, UI.H - 136, 656, 104), "success", 28)
	_feed.pressed.connect(func():
		if Game.feed_pet(Game.pet_follow):
			Sfx.play("star", -4.0)
			Game.save_game()
			Game.changed.emit()
		_refresh())
	_refresh()


func _card(i: int) -> Rect2:
	return Rect2(24 + (i % 3) * (CARD.x + 12.0), GRID_Y + (i / 3) * (CARD.y + 12.0), CARD.x, CARD.y)


func _refresh() -> void:
	var f: Dictionary = Game.follower()
	if f.is_empty():
		_feed.visible = false
	else:
		_feed.visible = true
		var lv := int(f.lv)
		if lv >= Pets.MAX_LV:
			M3.price(_feed, "%s · niveau maximum" % Pets.KINDS[f.kind].name, [])
			_feed.disabled = true
		else:
			M3.price(_feed, "Nourrir %s · %d éclats" % [Pets.KINDS[f.kind].name, Pets.feed_cost(lv)], [])
			_feed.disabled = Game.shards < Pets.feed_cost(lv)
	for k in _figs:
		(_figs[k] as Node2D).modulate = Color.WHITE if Game.pet_index(String(k)) >= 0 else Color(0.14, 0.16, 0.26)


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()
	_big.queue_redraw()
	for k in _figs:
		(_figs[k] as Node2D).queue_redraw()


func _draw_body() -> void:
	var c := _body
	# l'éclosoir : un œuf qui couve à gauche, le familier qui suit l'escouade à droite
	c.draw_style_box(UI.box(Color("0f2a20"), Color(UI.GREEN, 0.35), 24, 0), BAND)
	c.draw_rect(Rect2(BAND.position + Vector2(8, 210), Vector2(BAND.size.x - 16, 112)), Color("143a2a"))
	for k in 7:
		var x := BAND.position.x + 30 + k * 96.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, BAND.end.y - 8), Vector2(x + 20, BAND.end.y - 40 - (k % 3) * 10), Vector2(x + 40, BAND.end.y - 8)]), Color("3a9a6a", 0.6))
	var now := int(Time.get_unix_time_from_system())
	if not Game.eggs.is_empty():
		var e: Dictionary = Game.eggs[0]
		var at := BAND.position + Vector2(150, 160)
		_egg(c, at, 1.0)
		var left := int(e.end) - now
		var lab := "Éclosion · %s" % UI.duration(float(maxi(0, left))) if Game.ship.room_level("serre") > 0 else "Il faut une Serre"
		if Game.eggs.size() > 1:
			lab += " · +%d" % (Game.eggs.size() - 1)
		_pill(c, at + Vector2(0, 110), lab, UI.ACCENT)
	else:
		M3.text(c, BAND.position + Vector2(40, 150), "Aucun œuf", 26, UI.MUTED, true, 220, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(c, BAND.position + Vector2(40, 186), "en expédition et\nsur les gros boss", 20, UI.MUTED, false, 220, HORIZONTAL_ALIGNMENT_CENTER)
	var f: Dictionary = Game.follower()
	if not f.is_empty():
		_pill(c, BAND.position + Vector2(500, 56), "%s · niv. %d" % [Pets.KINDS[f.kind].name, int(f.lv)], Pets.KINDS[f.kind].col)
		M3.text(c, BAND.position + Vector2(340, 300), Pets.effect_text(String(f.kind), int(f.lv)), 20, UI.TEXT, true, 320, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		M3.text(c, BAND.position + Vector2(340, 170), "Aucun familier", 26, UI.MUTED, true, 320, HORIZONTAL_ALIGNMENT_CENTER)
	# les six familiers
	for i in Pets.ORDER.size():
		var kind := String(Pets.ORDER[i])
		var r := _card(i)
		var idx := Game.pet_index(kind)
		var info: Dictionary = Pets.KINDS[kind]
		var sel := idx >= 0 and idx == Game.pet_follow
		c.draw_style_box(UI.box(M3.S2, UI.ACCENT if sel else Color(0, 0, 0, 0), 20, 0), r)
		M3.text(c, r.position + Vector2(0, 126), String(info.name) + ((" · %d" % int(Game.pets[idx].lv)) if idx >= 0 else ""), 24, info.col if idx >= 0 else UI.MUTED, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(c, r.position + Vector2(6, 156), Pets.effect_text(kind, int(Game.pets[idx].lv)) if idx >= 0 else String(info.desc), 18, UI.MUTED, false, r.size.x - 12, HORIZONTAL_ALIGNMENT_CENTER)
		if sel:
			M3.text(c, r.position + Vector2(0, 30), "suit l’escouade", 16, UI.ACCENT, true, r.size.x - 12, HORIZONTAL_ALIGNMENT_RIGHT)
	var y := GRID_Y + 2 * (CARD.y + 12.0) + 34
	M3.text(c, Vector2(32, y), "Un familier suit l’escouade : c’est lui qui agit. Toucher pour changer.", 20, UI.MUTED, false, 656)
	M3.text(c, Vector2(32, y + 32), "Un œuf d’une espèce qu’on a déjà fait grandir son familier.", 20, UI.MUTED, false, 656)


func _pill(c: Control, center: Vector2, txt: String, col: Color) -> void:
	var w := M3.text_w(txt, 22, true) + 36.0
	var r := Rect2(center.x - w * 0.5, center.y - 22, w, 44)
	c.draw_style_box(UI.box(Color(0.03, 0.05, 0.12, 0.85), Color(0, 0, 0, 0), 22, 0), r)
	M3.text(c, r.position + Vector2(0, 31), txt, 22, col, true, w, HORIZONTAL_ALIGNMENT_CENTER)


## Œuf de verre : cristal à facettes, cœur lumineux qui bat.
func _egg(c: Control, at: Vector2, k: float) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -78), at + Vector2(40, -36), at + Vector2(46, 22), at + Vector2(14, 60), at + Vector2(-30, 54), at + Vector2(-46, 6), at + Vector2(-34, -44)])
	for s in [3.0, 1.8]:
		c.draw_circle(at, 70.0 * s / 3.0 + 20.0, Color(0.5, 0.9, 1.0, 0.08))
	c.draw_colored_polygon(pts, Color("9fe6ff"))
	c.draw_colored_polygon(PackedVector2Array([at, pts[1], pts[2], pts[3]]), Color("4f9ad8"))
	c.draw_colored_polygon(PackedVector2Array([at, pts[6], pts[0], pts[1]]), Color("dff6ff"))
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, Color(0.03, 0.05, 0.12), 4.0, true)
	c.draw_circle(at + Vector2(0, 2), 12.0 + 3.0 * sin(_t * 3.0), Color(1, 1, 1, 0.9))


func _input(ev: InputEvent) -> void:
	if not M3.is_tap(ev):
		return
	for i in Pets.ORDER.size():
		if _card(i).has_point(ev.position):
			var idx := Game.pet_index(String(Pets.ORDER[i]))
			if idx >= 0:
				Game.pet_follow = idx
				Sfx.play("star", -6.0)
				Game.save_game()
				Game.changed.emit()
				_refresh()
			else:
				Sfx.play("click", -10.0)
				M3.toast(self, "Pas encore éclos : des œufs en expédition et sur les gros boss", UI.GOLD)
			accept_event()
			return
