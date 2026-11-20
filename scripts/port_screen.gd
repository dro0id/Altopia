class_name PortScreen
extends Overlay
## Port-Altopia (maquette WO) : l'île de la Base vue de biais, ses districts, l'Aurore à quai au-dessus.

const ISLE_Y := 150.0
const EMPTY := [Vector2(486, 420), Vector2(596, 450)]

var _st: Control
var _isle: Control
var _sheet: Control
var _build: Button
var _act: Button
var _sel := "domes"
var _t := 0.0


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	set_backdrop(Color("4fd8ff"))
	M3.top_bar(_st, "Port-Altopia", close)
	var sheet_h := 340.0
	var avail := UI.H - ISLE_Y - sheet_h
	_isle = Control.new()
	_isle.position = Vector2(0, ISLE_Y + maxf(0.0, (avail - 600.0) * 0.5))
	_isle.size = Vector2(720, 600)
	_isle.draw.connect(_draw_isle)
	_isle.gui_input.connect(_isle_input)
	_st.add_child(_isle)
	_sheet = Control.new()
	_sheet.position = Vector2(0, UI.H - sheet_h)
	_sheet.size = Vector2(720, sheet_h)
	_sheet.draw.connect(_draw_sheet)
	_st.add_child(_sheet)
	_build = M3.button(_sheet, "", Rect2(32, _sheet.size.y - 128, 316, 104), "main", 26)
	_build.pressed.connect(func():
		if Port.build(Game, _sel):
			Sfx.play("coin")
			Game.save_game()
			Game.changed.emit()
		_refresh())
	_act = M3.button(_sheet, "", Rect2(364, _sheet.size.y - 128, 324, 104), "success", 26)
	_act.pressed.connect(_on_act)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_isle.queue_redraw()
	_sheet.queue_redraw()


func _refresh() -> void:
	var l := Port.lv(Game, _sel)
	if l >= Port.MAX_LV:
		M3.price(_build, "Niveau maximum", [])
		_build.disabled = true
	else:
		var c := Port.cost(Game, _sel)
		M3.price(_build, ("Bâtir" if l == 0 else "Niveau %d" % (l + 1)) + " · %d verre" % int(c.glass), [])
		_build.disabled = not Port.can_build(Game, _sel)
	_act.visible = l > 0 and _sel in ["fonderie", "marche", "arene"]
	match _sel:
		"fonderie":
			var n := Port.forge_ready(Game)
			M3.price(_act, "Récupérer %d jeton%s" % [n, "s" if n > 1 else ""] if n > 0 else "Forge en cours", [])
			_act.disabled = n <= 0
		"marche":
			M3.price(_act, "40 éclats → 1 jeton · %d" % Port.trades_left(Game), [])
			_act.disabled = Port.trades_left(Game) <= 0 or Game.shards < 40
		"arene":
			M3.price(_act, "Défier les rivaux" if Port.arena_ready(Game) else "Revenez demain", [])
			_act.disabled = not Port.arena_ready(Game)


func _on_act() -> void:
	match _sel:
		"fonderie":
			var n := Port.forge_claim(Game)
			if n > 0:
				Sfx.play("chest", -4.0)
				M3.toast(self, "+%d jeton%s d’objet" % [n, "s" if n > 1 else ""], UI.GREEN)
		"marche":
			if Port.trade(Game):
				Sfx.play("coin")
				M3.toast(self, "+1 jeton de recrutement", UI.GREEN)
		"arene":
			var r := Port.arena_fight(Game)
			if not r.is_empty():
				Sfx.play("star" if r.ok else "warn")
				M3.toast(self, ("Victoire · +%d ◆ · +%d verre" % [int(r.rw.crystals), int(r.rw.glass)]) if r.ok else "Les rivaux l’emportent · +1 verre", UI.GREEN if r.ok else UI.RED)
	Game.save_game()
	Game.changed.emit()
	_refresh()


func _draw_isle() -> void:
	var c := _isle
	# repères en haut : districts bâtis et verre brut
	var chip := "Districts %d / %d" % [Port.built(Game), Port.SLOTS]
	var w := M3.text_w(chip, 22, true) + 32.0
	c.draw_style_box(UI.box(Color(0.05, 0.2, 0.3, 0.8), Color(UI.ACCENT, 0.7), 20, 0), Rect2(24, 8, w, 44))
	M3.text(c, Vector2(24, 38), chip, 22, UI.ACCENT, true, w, HORIZONTAL_ALIGNMENT_CENTER)
	var gl := "%d verre brut" % int(Game.glass)
	var w2 := M3.text_w(gl, 22, true) + 32.0
	c.draw_style_box(UI.box(Color(0.1, 0.14, 0.26, 0.8), Color(UI.MUTED, 0.5), 20, 0), Rect2(36 + w, 8, w2, 44))
	M3.text(c, Vector2(36 + w, 38), gl, 22, UI.TEXT, true, w2, HORIZONTAL_ALIGNMENT_CENTER)
	# l'Aurore à quai, reliée à l'île
	c.draw_set_transform(Vector2(0, 40), 0.0, Vector2.ONE)
	var sh := Vector2(560, 136 + sin(_t * 1.2) * 6.0)
	c.draw_line(sh + Vector2(-20, 70), Vector2(482, 236), Color(0.85, 0.95, 1.0, 0.6), 6.0, true)
	c.draw_rect(Rect2(sh + Vector2(-26, -50), Vector2(52, 110)), Color("dfe6f5"))
	c.draw_circle(sh + Vector2(0, -50), 26, Color("dfe6f5", 0.9))
	for i in 5:
		c.draw_rect(Rect2(sh + Vector2(-26, -40 + i * 20), Vector2(52, 5)), [Color("ffd166"), Color("4fd8ff"), Color("ff9f6b"), Color("b388ff"), Color("9dff6b")][i])
	c.draw_arc(sh + Vector2(0, -6), 52, PI * 0.05, PI * 0.95, 20, Color(1, 1, 1, 0.7), 3.0, true)
	c.draw_colored_polygon(PackedVector2Array([sh + Vector2(-12, 60), sh + Vector2(12, 60), sh + Vector2(0, 86)]), Color(UI.ACCENT, 0.8))
	# l'île : plateau à facettes
	var top := PackedVector2Array([Vector2(60, 340), Vector2(160, 262), Vector2(320, 240), Vector2(500, 246), Vector2(640, 318), Vector2(600, 470), Vector2(400, 520), Vector2(200, 500), Vector2(100, 440)])
	c.draw_colored_polygon(PackedVector2Array([Vector2(100, 440), Vector2(200, 500), Vector2(400, 520), Vector2(600, 470), Vector2(560, 540), Vector2(380, 556), Vector2(220, 548)]), Color("14203e"))
	c.draw_colored_polygon(top, Color("1e3260"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(160, 262), Vector2(320, 240), Vector2(500, 246), Vector2(400, 330), Vector2(220, 330)]), Color("2a4a86"))
	# districts
	for d in Port.ORDER:
		_district(c, d, Port.DISTRICTS[d].at, Port.lv(Game, d))
	for e in EMPTY:
		var r := Rect2(e - Vector2(44, 26), Vector2(88, 52))
		for k in 10:
			var a := float(k) / 10.0
			var b := float(k + 0.5) / 10.0
			c.draw_line(r.position + Vector2(r.size.x * a, 0), r.position + Vector2(r.size.x * b, 0), UI.MUTED, 2.0)
			c.draw_line(r.position + Vector2(r.size.x * a, r.size.y), r.position + Vector2(r.size.x * b, r.size.y), UI.MUTED, 2.0)
		M3.text(c, r.position + Vector2(0, 36), "+", 28, UI.MUTED, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _district(c: Control, d: String, at: Vector2, l: int) -> void:
	var col: Color = Port.DISTRICTS[d].col
	var k := 1.0 if l > 0 else 0.35
	var cc := Color(col, k)
	var sel := d == _sel
	if sel:
		c.draw_circle(at + Vector2(0, -10), 64, Color(UI.ACCENT, 0.12 + 0.06 * sin(_t * 3.0)))
	match d:
		"domes":
			c.draw_arc(at, 46, PI, TAU, 24, cc, 5.0, true)
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				pts.append(at + Vector2(cos(a), sin(a)) * 44.0)
			c.draw_colored_polygon(pts, Color(col, 0.5 * k))
		"fonderie":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-34, 20), at + Vector2(-24, -44), at + Vector2(24, -44), at + Vector2(34, 20)]), cc)
			c.draw_rect(Rect2(at + Vector2(-8, -82), Vector2(16, 40)), Color(0.2, 0.15, 0.1, k))
			c.draw_circle(at + Vector2(0, -90), 12, Color(0.85, 0.7, 0.4, k))
		"academie":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-20, 20), at + Vector2(-20, -60), at + Vector2(0, -92), at + Vector2(20, -60), at + Vector2(20, 20)]), cc)
		"marche":
			c.draw_rect(Rect2(at + Vector2(-34, -20), Vector2(68, 36)), cc)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-44, -20), at + Vector2(0, -50), at + Vector2(44, -20)]), Color(col.darkened(0.3), k))
		"phare":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-10, 30), at + Vector2(-6, -80), at + Vector2(6, -80), at + Vector2(10, 30)]), Color(0.92, 0.95, 1.0, k))
			c.draw_circle(at + Vector2(0, -88), 12, cc)
			if l > 0:
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -88), at + Vector2(150, -120 + sin(_t) * 20.0), at + Vector2(150, -70 + sin(_t) * 20.0)]), Color(col, 0.15))
		"arene":
			Art.ellipse(c, at, 60, 22, Color(0.3, 0.08, 0.12, 0.8 * k + 0.2))
			_ring(c, at, 60, 22, cc)
	M3.text(c, at + Vector2(-80, 52), String(Port.DISTRICTS[d].name) + (" · %d" % l if l > 0 else ""), 20, cc if l > 0 else UI.MUTED, true, 160, HORIZONTAL_ALIGNMENT_CENTER)


static func _ring(c: Control, at: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_polyline(pts, col, 4.0, true)


func _draw_sheet() -> void:
	var c := _sheet
	M3.sheet(c, Rect2(Vector2.ZERO, c.size))
	var info: Dictionary = Port.DISTRICTS[_sel]
	var l := Port.lv(Game, _sel)
	M3.text(c, Vector2(32, 62), String(info.name), 34, info.col, true)
	M3.text(c, Vector2(0, 62), ("niveau %d / %d" % [l, Port.MAX_LV]) if l > 0 else "à bâtir", 24, UI.MUTED, true, 688, HORIZONTAL_ALIGNMENT_RIGHT)
	M3.text(c, Vector2(32, 104), String(info.desc), 22, UI.TEXT, false, 656)
	var c2 := Port.cost(Game, _sel)
	if l < Port.MAX_LV:
		M3.text(c, Vector2(32, 150), "Prochain niveau : %d verre brut · %s crédits" % [int(c2.glass), UI.num(float(c2.credits))], 20, UI.MUTED, false, 656)
	M3.text(c, Vector2(32, 186), "Le verre brut vient des secteurs générés (Ceinture sans fin) et de l’Arène.", 20, UI.MUTED, false, 656)


func _isle_input(ev: InputEvent) -> void:
	if not M3.is_tap(ev):
		return
	var best := ""
	var bd := 80.0
	for d in Port.ORDER:
		var dist: float = (Port.DISTRICTS[d].at as Vector2).distance_to(ev.position - Vector2(0, 40) + Vector2(0, 20))
		if dist < bd:
			bd = dist
			best = d
	if best != "":
		_sel = best
		Sfx.play("click", -6.0)
		_refresh()
		accept_event()
