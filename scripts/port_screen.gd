class_name PortScreen
extends Overlay
## Port-Altopia (maquette WO) : l'île de la Base vue de biais, ses districts, l'Aurore à quai au-dessus.

const ISLE_Y := 150.0

var _st: Control
var _isle: Control
var _view: PortView
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
	_view = PortView.new()
	_view.position = Vector2(0, ISLE_Y)
	_view.size = Vector2(720, avail)
	_st.add_child(_view)
	_view.build_port(Game.port.get("lv", {}))
	_view.district_tapped.connect(_pick)
	_isle = Control.new()
	_isle.position = Vector2(0, ISLE_Y)
	_isle.size = Vector2(720, avail)
	_isle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_isle.draw.connect(_draw_isle)
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
			_view.build_port(Game.port.get("lv", {}))
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
	# noms des districts posés sur la vue 3D
	for d in Port.ORDER:
		var sp := _view.spot_pos(d)
		if sp.is_empty():
			continue
		var l := Port.lv(Game, d)
		var col: Color = Port.DISTRICTS[d].col
		var lab := String(Port.DISTRICTS[d].name) + (" · %d" % l if l > 0 else " · à bâtir")
		var lw := M3.text_w(lab, 18, true) + 20.0
		var at: Vector2 = sp.pos - _isle.position + _view.position
		var r := Rect2(at.x - lw * 0.5, at.y, lw, 30)
		c.draw_style_box(UI.box(Color(0.03, 0.05, 0.12, 0.8), UI.ACCENT if d == _sel else Color(0, 0, 0, 0), 15, 0), r)
		M3.text(c, r.position + Vector2(0, 22), lab, 18, col if l > 0 else UI.MUTED, true, lw, HORIZONTAL_ALIGNMENT_CENTER)


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


func _pick(d: String) -> void:
	_sel = d
	Sfx.play("click", -6.0)
	_refresh()
