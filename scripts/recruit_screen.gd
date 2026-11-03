class_name RecruitScreen
extends Overlay
## Recrutement (maquette H) : bannière en cours, garanties, derniers boosters et deux boutons d'ouverture.

var _tokens_chip: HudButton
var _banner: Control
var _pity: Array = []
var _last: Control
var _ten: Button
var _one: Button
var _ten_sub: Label
var _busy := false
var _t := 0.0
var _results: Control
var _mode := 0
var _seg: Array = []
var _hero_nodes: Array = []
var _view: ItemBoosterView
signal inventory_requested
signal equipped


func _init() -> void:
	super._init(720.0)
	panel.custom_minimum_size = Vector2(720, 1120)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 0))
	box.add_theme_constant_override("separation", 0)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(720, 1120)
	box.add_child(stage)
	var t := UI.label(stage, "Recrutement", 40, Color.WHITE, true)
	t.position = Vector2(32, 26)
	_tokens_chip = HudButton.new()
	_tokens_chip.icon = "token"
	_tokens_chip.font_size = 26
	_tokens_chip.tappable = false
	stage.add_child(_tokens_chip)
	_banner = Control.new()
	_banner.position = Vector2(32, 140)
	_banner.size = Vector2(656, 385)
	_banner.clip_contents = true
	_banner.draw.connect(_draw_banner)
	stage.add_child(_banner)
	for i in 2:
		var c := Control.new()
		c.position = Vector2(32.0 + i * 336.0, 553)
		c.size = Vector2(320, 117)
		var idx := i
		c.draw.connect(func(): _draw_pity(c, idx))
		stage.add_child(c)
		_pity.append(c)
	var cap := UI.label(stage, "Derniers boosters", 24, UI.MUTED)
	cap.position = Vector2(32, 696)
	_last = Control.new()
	_last.position = Vector2(32, 742)
	_last.size = Vector2(656, 112)
	_last.draw.connect(_draw_last)
	stage.add_child(_last)
	# boutons d'ouverture
	_ten = UI.button(stage, "", 32, "main")
	_ten.position = Vector2(32, 880)
	_ten.size = Vector2(656, 112)
	_ten.custom_minimum_size = Vector2(0, 112)
	_ten.pressed.connect(_pull.bind(10))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ten.add_child(tv)
	var tl := UI.label(tv, "Ouvrir ×10 boosters", 32, UI.DARK, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trow := HBoxContainer.new()
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.add_theme_constant_override("separation", 8)
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(trow)
	var ti := TextureRect.new()
	ti.texture = UI.icon("token")
	ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(ti)
	_ten_sub = UI.label(trow, "%d · 1 gratuit" % Data.RECRUIT_COST_10, 24, UI.DARK, true)
	_ten_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_one = UI.button(stage, "", 28, "ghost")
	_one.position = Vector2(32, 1008)
	_one.size = Vector2(656, 96)
	var orow := HBoxContainer.new()
	orow.alignment = BoxContainer.ALIGNMENT_CENTER
	orow.add_theme_constant_override("separation", 10)
	orow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_one.add_child(orow)
	var o1 := UI.label(orow, "Ouvrir ×1 booster ·", 28, Color("e8eefc"), true)
	o1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var oi := TextureRect.new()
	oi.texture = UI.icon("token")
	oi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	orow.add_child(oi)
	var o2 := UI.label(orow, str(Data.RECRUIT_COST), 28, Color("e8eefc"), true)
	o2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_one.pressed.connect(_pull.bind(1))
	_hero_nodes = [_banner, cap, _last, _ten, _one]
	_hero_nodes.append_array(_pity)
	_view = ItemBoosterView.new()
	_view.visible = false
	_view.inventory_requested.connect(func(): inventory_requested.emit())
	_view.equipped.connect(func(): equipped.emit())
	stage.add_child(_view)
	for i in 2:
		var sb := HudButton.new()
		sb.font_size = 26
		sb.radius = 24.0
		sb.set_texts(["Héros", "Objets"][i])
		sb.size = Vector2(324, 56)
		sb.position = Vector2(32.0 + i * 332.0, 76)
		var idx := i
		sb.pressed.connect(func(): _set_mode(idx))
		stage.add_child(sb)
		_seg.append(sb)
	_set_mode(0)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_banner.queue_redraw()
	_refresh()


func _set_mode(m: int) -> void:
	if _busy and m != _mode:
		return
	_mode = m
	for n in _hero_nodes:
		(n as Control).visible = m == 0
	_view.visible = m == 1
	for i in _seg.size():
		var b: HudButton = _seg[i]
		b.fill = UI.ACCENT if i == m else UI.HUD
		b.border = UI.ACCENT if i == m else UI.LINE
		b.text_color = UI.DARK if i == m else UI.TEXT
		b.queue_redraw()
	_tokens_chip.icon = "token" if m == 0 else "itoken"
	_refresh()


func _refresh() -> void:
	_tokens_chip.set_texts(str(Game.tokens if _mode == 0 else Game.item_tokens))
	_tokens_chip.fit_chip()
	_tokens_chip.position = Vector2(688.0 - _tokens_chip.size.x, 28)
	_ten.disabled = Game.tokens < Data.RECRUIT_COST_10 or _busy
	_tokens_chip.queue_redraw()
	_one.disabled = Game.tokens < Data.RECRUIT_COST or _busy
	if _mode == 0:
		for c in _pity:
			c.queue_redraw()
		_last.queue_redraw()


# ---------------------------------------------------------------- dessin

func _spaced(ci: Control, font: Font, pos: Vector2, txt: String, fs: int, col: Color, gap: float, centered := false) -> void:
	var tw := 0.0
	for ch in txt:
		tw += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + gap
	var x := pos.x - (tw * 0.5 if centered else 0.0)
	for ch in txt:
		ci.draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + gap


func _draw_banner() -> void:
	var b := _banner
	UI.draw_gradient_box(b, Rect2(Vector2.ZERO, b.size), 32.0, Color("1f1040"), Color("3d2185"), Color(0.7, 0.53, 1.0, 0.5), 2.0)
	# rayons discrets derrière les cartes
	for i in 10:
		var a := TAU * i / 10.0 + _t * 0.1
		b.draw_polygon(PackedVector2Array([Vector2(480, 200), Vector2(480, 200) + Vector2.from_angle(a) * 420.0, Vector2(480, 200) + Vector2.from_angle(a + 0.12) * 420.0]), PackedColorArray([Color(0.7, 0.55, 1, 0.16), Color(0.7, 0.55, 1, 0.0), Color(0.7, 0.55, 1, 0.0)]))
	var fb := UI.bold_font()
	var f := ThemeDB.fallback_font
	_spaced(b, fb, Vector2(30, 52), "BANNIÈRE EN COURS", 22, Color("b388ff"), 2.5)
	b.draw_string(fb, Vector2(30, 112), "Signal de", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("e8eefc"))
	b.draw_string(fb, Vector2(30, 158), "recrutement", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("e8eefc"))
	var fh: String = Data.featured_hero(int(Time.get_unix_time_from_system() / 86400.0))
	b.draw_string(f, Vector2(30, 206), "En vedette : %s" % String(Data.HEROES[fh].name).split(" ")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.MUTED)
	# barre des taux
	var rates: Dictionary = Data.RECRUIT_RATES
	var cols := [Color("7dffb0"), Color("4fa8ff"), Color("b388ff")]
	var parts := [1.0 - float(rates.rare) - float(rates.epic), float(rates.rare), float(rates.epic)]
	var x := 30.0
	for i in 3:
		var w: float = 280.0 * parts[i]
		var sbx := StyleBoxFlat.new()
		sbx.bg_color = cols[i]
		sbx.corner_radius_top_left = 10 if i == 0 else 0
		sbx.corner_radius_bottom_left = 10 if i == 0 else 0
		sbx.corner_radius_top_right = 10 if i == 2 else 0
		sbx.corner_radius_bottom_right = 10 if i == 2 else 0
		b.draw_style_box(sbx, Rect2(x, 260, maxf(w, 6.0), 20))
		x += w
	b.draw_string(fb, Vector2(30, 322), "Normal %d %%" % int(round(parts[0] * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, cols[0])
	var rt := "Rare %d %%" % int(round(parts[1] * 100.0))
	b.draw_string(fb, Vector2(30, 358), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, cols[1])
	var w1 := fb.get_string_size(rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	b.draw_string(f, Vector2(30 + w1, 358), " · ", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.MUTED)
	b.draw_string(fb, Vector2(30 + w1 + 24, 358), "Épique %d %%" % int(round(parts[2] * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, cols[2])
	# trois cartes inclinées
	_ticket(b, Vector2(470, 190), 230.0, 330.0, -0.12, Color("3a1f78"), Color("5a38b0"), fh, false)
	_ticket(b, Vector2(500, 200), 230.0, 330.0, 0.08, Color("4a2a9a"), Color("6a44c8"), fh, false)
	_ticket(b, Vector2(478, 214), 230.0, 330.0, -0.04, Color("7a4de0"), Color("3b1f78"), fh, true)
	# liseré du bas
	b.draw_polygon(PackedVector2Array([Vector2(24, b.size.y - 8.0), Vector2(b.size.x - 24, b.size.y - 8.0), Vector2(b.size.x - 24, b.size.y), Vector2(24, b.size.y)]), PackedColorArray([Color("b388ff"), Color("4fa8ff"), Color("4fa8ff"), Color("b388ff")]))


func _ticket(ci: Control, c: Vector2, w: float, h: float, rot: float, c_top: Color, c_bot: Color, hero_id: String, front: bool) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := int(w / 14.0)
	for i in n + 1:
		var x := -w * 0.5 + w * i / n
		pts.append(Vector2(x, -h * 0.5 + (8.0 if i % 2 == 0 else 0.0)))
		cols.append(c_top)
	for i in n + 1:
		var x := w * 0.5 - w * i / n
		pts.append(Vector2(x, h * 0.5 - (8.0 if i % 2 == 0 else 0.0)))
		cols.append(c_bot)
	ci.draw_polygon(pts, cols)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(0.75, 0.6, 1.0, 0.55), 2.0, true)
	if front:
		ci.draw_style_box(UI.box(Color("1a0f35"), Color(0, 0, 0, 0), 12, 0), Rect2(-100, -140, 200, 46))
		_spaced(ci, UI.bold_font(), Vector2(0, -107), "SIGNAL", 26, Color("e8eefc"), 3.0, true)
		for k in range(-9, 10, 2):
			ci.draw_line(Vector2(k * 10.0, -72), Vector2(k * 10.0 + 8.0, -72), Color(1, 1, 1, 0.5), 2.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Art.draw_portrait(ci, Data.HEROES[hero_id], c + Vector2(0, 18).rotated(rot), 62.0, _t)
		ci.draw_set_transform(c, rot, Vector2.ONE)
		for k in 28:
			var a := TAU * k / 28.0
			ci.draw_circle(Vector2(0, 18) + Vector2.from_angle(a) * 74.0, 2.5, Color("ffd166"))
		var dcols := [Color("9aa7c7"), Color("7dffb0"), Color("4fa8ff"), Color("b388ff"), Color("ffb142")]
		for k in 5:
			var p := Vector2((k - 2) * 28.0, 108)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(8, 0), p + Vector2(0, 8), p + Vector2(-8, 0)]), dcols[k])
		ci.draw_style_box(UI.box(Color("1a0f35"), Color(0, 0, 0, 0), 10, 0), Rect2(-92, 126, 190, 44))
		_spaced(ci, UI.bold_font(), Vector2(0, 158), "5 CARTES", 28, Color("ffd166"), 2.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pity(c: Control, idx: int) -> void:
	c.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 28, 0), Rect2(Vector2.ZERO, c.size))
	var col := Color("4fa8ff") if idx == 0 else Color("b388ff")
	var maxv: int = Data.PITY_RARE if idx == 0 else Data.PITY_EPIC
	var v: int = int(Game.recruit_pity.get("rare" if idx == 0 else "epic", 0))
	var ctr := Vector2(60, 58)
	c.draw_arc(ctr, 33, 0, TAU, 48, UI.LINE2, 9.0, true)
	if v > 0:
		c.draw_arc(ctr, 33, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(v) / float(maxv), 0.0, 1.0), 48, col, 9.0, true)
	c.draw_string(UI.bold_font(), Vector2(118, 50), "Rare garanti" if idx == 0 else "Épique garanti", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	c.draw_string(UI.bold_font(), Vector2(118, 90), "%d / %d" % [v, maxv], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)


func _draw_last() -> void:
	for i in 5:
		var r := Rect2(i * 128.0, 0, 112, 112)
		if i < Game.last_pulls.size():
			var lp: Dictionary = Game.last_pulls[i]
			var rc: Color = Data.RARITY_COLORS[lp.rarity]
			var sb := UI.box(UI.PANEL, rc, 24, 0)
			sb.set_border_width_all(3)
			_last.draw_style_box(sb, r)
			UI.portrait(_last, Data.HEROES[lp.id], r.position + Vector2(56, 56), 44.0, _t)
		else:
			_last.draw_style_box(UI.box(UI.PANEL2, UI.LINE2, 24, 0), r)


# ---------------------------------------------------------------- tirages

func _pull(count: int) -> void:
	if _busy:
		return
	var res: Array = Game.recruit(count)
	if res.is_empty():
		return
	Game.save_game()
	Sfx.play("chest", -2.0)
	_show_results(res)
	_refresh()


## Résultat des tirages : une ligne par héros obtenu (les meilleurs d'abord pour dix tirages), puis le total.
func _show_results(res: Array) -> void:
	_busy = true
	if _results != null:
		_results.queue_free()
	_results = Control.new()
	_results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_results)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.03, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results.add_child(dim)
	var order: Array = res.duplicate()
	order.sort_custom(func(a, b): return Data.RARITIES_HERO.find(a.rarity) > Data.RARITIES_HERO.find(b.rarity))
	var shown: Array = order.slice(0, 7)
	var p := PanelContainer.new()
	p.position = Vector2(32, 180)
	p.size = Vector2(656, 800)
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.LINE, 28, 20))
	_results.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	UI.label(v, "Boosters ouverts", 32, Color.WHITE, true)
	var delay := 0.0
	for r in shown:
		var row := _result_row(r)
		row.modulate.a = 0.0
		v.add_child(row)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func(): Sfx.play("star" if r.rarity != "epic" else "chest", -2.0, 0.9 + 0.15 * float(Data.RARITIES_HERO.find(r.rarity))))
		tw.tween_property(row, "modulate:a", 1.0, 0.25)
		delay += 0.35
	if res.size() > 1:
		var news := 0
		var frags := 0
		for r in res:
			if r.new:
				news += 1
			frags += int(r.fragments)
		var sm := UI.label(v, "Total : %d nouveau(x), + %d fragments" % [news, frags], 24, UI.GREEN, true)
		sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ok := UI.button(v, "Continuer", 30, "main")
	ok.custom_minimum_size = Vector2(0, 88)
	ok.pressed.connect(func():
		_busy = false
		_results.queue_free()
		_results = null)


func _result_row(r: Dictionary) -> Control:
	var h: Dictionary = Data.HEROES[r.id]
	var rc: Color = Data.RARITY_COLORS[r.rarity]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, rc, 20, 8))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	p.add_child(hb)
	var ic := HeroIcon.new()
	ic.hero = h
	ic.custom_minimum_size = Vector2(72, 72)
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	UI.label(vb, String(h.name), 28, rc, true)
	UI.label(vb, "%s · %s" % [Data.RARITY_NAMES_HERO[r.rarity], Data.ROLE_NAMES[h.role]], 20, UI.MUTED)
	var tag := UI.label(hb, "NOUVEAU !" if r.new else "+ %d fragments" % int(r.fragments), 24, UI.GREEN if r.new else UI.GOLD, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return p
