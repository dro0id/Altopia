class_name OrdersScreen
extends Overlay
## Ordres de l'Amirauté (maquette WJ) : solde de la semaine (paliers), puis les trois ordres du jour.

var _st: Control
var _body: Control
var _btns: Array = []


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	set_backdrop(UI.GOLD)
	Game.orders.refresh()
	M3.top_bar(_st, "Ordres de l’Amirauté", close)
	_body = Control.new()
	_body.position = Vector2(0, 120)
	_body.size = Vector2(720, 900)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	_st.add_child(_body)
	_build_buttons()


func _build_buttons() -> void:
	for b in _btns:
		b.queue_free()
	_btns = []
	var o: Orders = Game.orders
	for i in o.list.size():
		var ord: Dictionary = o.list[i]
		if o.is_done(ord) and not bool(ord.claimed):
			var b := M3.button(_body, "Réclamer", Rect2(476, _row_y(i) + 20, 188, 80), "success", 26)
			var idx := i
			b.pressed.connect(func():
				var rw := Game.orders.claim(idx, Game)
				if not rw.is_empty():
					Sfx.play("coin")
					M3.toast(self, Orders.reward_text(rw), UI.GREEN)
					Game.save_game()
					Game.changed.emit()
				_build_buttons()
				_body.queue_redraw())
			_btns.append(b)


func _row_y(i: int) -> float:
	return 300.0 + i * 136.0


func _draw_body() -> void:
	var c := _body
	var o: Orders = Game.orders
	# solde de la semaine
	var r := Rect2(32, 0, 656, 232)
	M3.glass_card(c, r, false, 20.0)
	c.draw_style_box(UI.box(Color(0, 0, 0, 0), Color(UI.GOLD, 0.45), 20, 0), r)
	M3.text(c, Vector2(64, 48), "SOLDE DE LA SEMAINE", 22, UI.GOLD, true)
	var left := (7 - posmod(Orders.today() + 3, 7)) * 86400.0 - fmod(Time.get_unix_time_from_system(), 86400.0)
	M3.text(c, Vector2(64, 48), "%d ordres sur 15 · %s" % [o.week_done, UI.duration(left)], 22, UI.MUTED, false, 592, HORIZONTAL_ALIGNMENT_RIGHT)
	M3.bar(c, Rect2(64, 72, 592, 14), float(o.week_done) / 15.0, UI.GOLD)
	for j in Orders.WEEK.size():
		var w: Dictionary = Orders.WEEK[j]
		var cx := 104.0 + j * 128.0
		var got := o.week_claimed.has(int(w.at))
		var hex := PackedVector2Array()
		for k in 6:
			var a := k * PI / 3.0
			hex.append(Vector2(cx, 140) + Vector2(cos(a), sin(a)) * 34.0)
		c.draw_colored_polygon(hex, UI.GOLD if got else M3.S3)
		_reward_icon(c, w.reward, Vector2(cx, 140), Color("06101f") if got else UI.MUTED)
		M3.text(c, Vector2(cx - 40, 204), str(int(w.at)), 22, UI.TEXT if got else UI.MUTED, true, 80, HORIZONTAL_ALIGNMENT_CENTER)
	# ordres du jour
	var done := 0
	for ord in o.list:
		if bool(ord.claimed):
			done += 1
	M3.text(c, Vector2(32, 280), "ORDRES DU JOUR · %d / %d" % [done, o.list.size()], 22, UI.GREEN, true)
	for i in o.list.size():
		var ord: Dictionary = o.list[i]
		var t := Orders.template(String(ord.id))
		var y := _row_y(i)
		var rr := Rect2(32, y, 656, 120)
		var ok := o.is_done(ord)
		M3.glass_card(c, rr, ok and not bool(ord.claimed), 18.0)
		var box := Rect2(52, y + 38, 44, 44)
		c.draw_style_box(UI.box(UI.GREEN if bool(ord.claimed) or ok else M3.S3, Color(0, 0, 0, 0), 12, 0), box)
		if bool(ord.claimed):
			c.draw_polyline(PackedVector2Array([box.get_center() + Vector2(-11, 0), box.get_center() + Vector2(-3, 9), box.get_center() + Vector2(12, -9)]), Color("06101f"), 5.0, true)
		M3.text(c, Vector2(116, y + 50), String(t.text), 28, UI.MUTED if bool(ord.claimed) else UI.TEXT, true, 340)
		var frac := float(ord.progress) / maxf(1.0, float(t.goal))
		M3.bar(c, Rect2(116, y + 76, 300, 12), frac, UI.GREEN if ok else UI.ACCENT)
		M3.text(c, Vector2(428, y + 90), "%d / %d" % [int(ord.progress), int(t.goal)], 22, UI.MUTED, false)
		if bool(ord.claimed):
			M3.text(c, Vector2(0, y + 70), "réclamé", 22, UI.GREEN, true, 656, HORIZONTAL_ALIGNMENT_RIGHT)
		elif not ok:
			M3.text(c, Vector2(0, y + 70), Orders.reward_text(t.reward), 22, UI.GOLD, true, 656, HORIZONTAL_ALIGNMENT_RIGHT)
	var ny := _row_y(o.list.size()) + 8.0
	M3.para(c, Vector2(32, ny + 24), "Les ordres changent chaque jour. Chaque ordre réclamé fait avancer la solde de la semaine.", 22, UI.MUTED, 656)


func _reward_icon(c: Control, rw: Dictionary, at: Vector2, col: Color) -> void:
	var k := "crystal"
	if int(rw.get("tokens", 0)) > 0:
		k = "token"
	elif int(rw.get("copies", 0)) > 0:
		k = "copies"
	elif int(rw.get("item_tokens", 0)) > 0 and int(rw.get("crystals", 0)) > 0:
		k = "chest"
	match k:
		"crystal":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -14), at + Vector2(12, 0), at + Vector2(0, 14), at + Vector2(-12, 0)]), col)
		"token":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -15), at + Vector2(4, -4), at + Vector2(15, 0), at + Vector2(4, 4), at + Vector2(0, 15), at + Vector2(-4, 4), at + Vector2(-15, 0), at + Vector2(-4, -4)]), col)
		"copies":
			Art.star(c, at, 15.0, col, 0.0)
		_:
			c.draw_rect(Rect2(at - Vector2(13, 11), Vector2(26, 22)), col, false, 3.0)
			c.draw_rect(Rect2(at - Vector2(7, 5), Vector2(14, 10)), col)
