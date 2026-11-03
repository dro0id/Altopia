class_name ShopScreen
extends Overlay
## Boutique (maquette I) : on dépense des cristaux d'Altopia (gagnés sur les gros boss). L'achat de cristaux contre de l'argent réel viendra avec la publication.

signal bought(text: String)

const TABS := [["Offres", ""], ["Coffres", "chests"], ["Jetons", "tokens"], ["Boosts", "boosts"]]
const CHEST_COLS := {
	"rare": [Color("2f6fc4"), Color("1f4a8a"), Color("4fa8ff")],
	"epique": [Color("7a46d6"), Color("4f2a94"), Color("b388ff")],
	"legendaire": [Color("b86e0f"), Color("8a4f08"), Color("ffb142")],
}

var _tab := 0
var _stage: Control            # 720 × 1152 : tout est placé à la position de la maquette
var _scroll: ScrollContainer
var _content: Control
var _chips: Array = []
var _tab_btns: Array = []
var _timer := 0.0
var _live: Array = []          # éléments qui changent avec le temps : [Control, Callable]


func _init() -> void:
	super._init(720.0)
	panel.custom_minimum_size = Vector2(720, 1152)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 0))
	box.add_theme_constant_override("separation", 0)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(720, 1152)
	box.add_child(_stage)
	var t := UI.label(_stage, "Boutique", 32, Color.WHITE, true)
	t.position = Vector2(24, 20)
	var icons := ["crystal", "token", "coin"]
	for i in 3:
		var ch := HudButton.new()
		ch.icon = icons[i]
		ch.font_size = 24
		ch.tappable = false
		ch.z_index = 1
		_stage.add_child(ch)
		_chips.append(ch)
	var xx := 24.0
	for i in TABS.size():
		var b := HudButton.new()
		b.font_size = 24
		b.bold = true
		b.radius = 34.0
		b.set_texts(TABS[i][0])
		b.size = Vector2(UI.bold_font().get_string_size(TABS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 56.0, 68)
		b.position = Vector2(xx, 82)
		xx += b.size.x + 16.0
		var idx := i
		b.pressed.connect(func():
			_tab = idx
			_rebuild())
		_stage.add_child(b)
		_tab_btns.append(b)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 156)
	_scroll.size = Vector2(720, 996)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_stage.add_child(_scroll)
	DragScroll.attach(_scroll)
	_rebuild()


func _rebuild() -> void:
	if _content != null:
		_content.queue_free()
	_live.clear()
	_content = Control.new()
	_scroll.add_child(_content)
	var y := 10.0
	var tab_id: String = TABS[_tab][1]
	if tab_id == "":
		y = _free_banner(y) + 16.0
		y = _daily(y) + 16.0
	var list: Array = []
	for it in Data.SHOP_ITEMS:
		if tab_id == "" or it.tab == tab_id:
			list.append(it)
	var col := 0
	var row_h := 288.0
	for it in list:
		_card(it, Vector2(24.0 + col * 344.0, y), Vector2(328, row_h))
		col += 1
		if col == 2:
			col = 0
			y += row_h + 16.0
	if col != 0:
		y += row_h + 16.0
	if tab_id == "":
		y = _crystals_row(y)
	_content.custom_minimum_size = Vector2(720, y + 24.0)
	for i in _tab_btns.size():
		var b: HudButton = _tab_btns[i]
		b.fill = UI.ACCENT if i == _tab else UI.HUD
		b.border = UI.ACCENT if i == _tab else UI.LINE
		b.text_color = UI.DARK if i == _tab else UI.TEXT
		b.queue_redraw()
	_refresh()


# ---------------------------------------------------------------- éléments

func _free_banner(y: float) -> float:
	var c := Control.new()
	c.position = Vector2(24, y)
	c.size = Vector2(672, 116)
	c.draw.connect(func():
		UI.draw_gradient_box(c, Rect2(Vector2.ZERO, c.size), 28.0, Color("10331f"), UI.PANEL, UI.GREEN, 2.0)
		_gift(c, Vector2(76, 64)))
	_content.add_child(c)
	var t := UI.label(c, "Coffre gratuit prêt", 26, Color.WHITE, true)
	t.position = Vector2(100, 20)
	var s := UI.label(c, "", 22, UI.MUTED)
	s.position = Vector2(100, 56)
	var b := UI.button(c, "Ouvrir", 28, "main")
	b.position = Vector2(508, 17)
	b.size = Vector2(140, 82)
	b.custom_minimum_size = Vector2(140, 82)
	b.pressed.connect(func():
		var ch: Dictionary = Game.claim_free_chest()
		if not ch.is_empty():
			Sfx.play("chest")
			Game.save_game()
			bought.emit("Coffre gratuit : +%s crédits, +%d éclats" % [Data.fmt(ch.credits), int(ch.shards)])
		_refresh())
	_live.append([c, func():
		var ready := Game.free_chest_ready()
		t.text = "Coffre gratuit prêt" if ready else "Coffre gratuit"
		s.text = "Prochain dans 4 h après ouverture" if ready else "Prochain dans %s" % UI.duration(Game.free_chest_remaining())
		b.disabled = not ready])
	return y + 116.0


func _daily(y: float) -> float:
	var it: Dictionary = Data.DAILY_OFFER
	var c := Control.new()
	c.position = Vector2(24, y)
	c.size = Vector2(672, 138)
	c.draw.connect(func():
		UI.draw_gradient_box(c, Rect2(Vector2.ZERO, c.size), 32.0, Color("3a2a0a"), Color("1a1004"), Color("ffb142"), 2.0)
		_mini_chest(c, Vector2(80, 95), 108.0, CHEST_COLS.legendaire))
	_content.add_child(c)
	var e := UI.label(c, "OFFRE DU JOUR", 22, Color("ffb142"), true)
	e.position = Vector2(158, 22)
	var n := UI.label(c, it.name, 30, Color.WHITE, true)
	n.position = Vector2(158, 46)
	var d := UI.label(c, it.desc, 22, UI.MUTED)
	d.position = Vector2(158, 90)
	var badge := Label.new()
	badge.add_theme_font_override("font", UI.bold_font())
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color("1a1004"))
	badge.add_theme_stylebox_override("normal", UI.box(Color("ffb142"), Color(0, 0, 0, 0), 20, 0))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.size = Vector2(176, 32)
	badge.position = Vector2(470, -14)
	c.add_child(badge)
	var b := UI.button(c, "", 28, "gold")
	b.position = Vector2(526, 26)
	b.size = Vector2(120, 88)
	b.custom_minimum_size = Vector2(120, 88)
	b.pressed.connect(func(): _buy(it.id))
	var old := Control.new()
	old.position = Vector2(526, 26)
	old.size = Vector2(120, 88)
	old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	old.draw.connect(func():
		var f := ThemeDB.fallback_font
		draw_string_old(old, f, "%d" % int(it.base)))
	c.add_child(old)
	_live.append([c, func():
		var avail := Game.daily_available()
		badge.text = "-30 %% · %s" % _hm(Game.daily_remaining()) if avail else "Revient demain"
		b.text = "%d" % int(it.cost) if avail else "Acheté"
		b.icon = UI.icon("crystal") if avail else null
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.disabled = not avail or Game.crystals < int(it.cost)
		old.visible = avail])
	return y + 138.0


func draw_string_old(ci: Control, f: Font, txt: String) -> void:
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var x := (120.0 - w) * 0.5
	ci.draw_string(f, Vector2(x, 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("6b5320"))
	ci.draw_line(Vector2(x, 21), Vector2(x + w, 21), Color("6b5320"), 2.0)


func _card(it: Dictionary, pos: Vector2, sz: Vector2) -> void:
	var c := Control.new()
	c.position = pos
	c.size = sz
	var feat: bool = it.has("badge")
	c.draw.connect(_draw_card.bind(c, it))
	_content.add_child(c)
	var n := UI.label(c, it.name, 26, Color.WHITE, true)
	n.position = Vector2(0, 116)
	n.size = Vector2(c.size.x, 34)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d := UI.label(c, it.desc, 22, UI.MUTED)
	d.position = Vector2(0, 150)
	d.size = Vector2(c.size.x, 30)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := UI.button(c, "%d" % int(it.cost), 28, "gold")
	b.icon = UI.icon("crystal")
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("h_separation", 10)
	b.position = Vector2(16, 186)
	b.size = Vector2(c.size.x - 32.0, 80)
	b.custom_minimum_size = Vector2(0, 80)
	b.pressed.connect(func(): _buy(it.id))
	if feat:
		var tag := Label.new()
		tag.text = it.badge
		tag.add_theme_font_override("font", UI.bold_font())
		tag.add_theme_font_size_override("font_size", 20)
		tag.add_theme_color_override("font_color", Color("1a1004"))
		tag.add_theme_stylebox_override("normal", UI.box(Color("b388ff"), Color(0, 0, 0, 0), 20, 0))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.size = Vector2(142, 32)
		tag.position = Vector2(16, -14)
		c.add_child(tag)
	_live.append([c, func():
		b.disabled = Game.crystals < int(it.cost)
		if it.has("boost") and Game.boost_active():
			d.text = "Actif : encore %s" % UI.duration(Game.boost_remaining())
		elif it.has("boost"):
			d.text = it.desc])


func _draw_card(c: Control, it: Dictionary) -> void:
	c.draw_style_box(UI.box(UI.PANEL, UI.LINE2, 28, 0), Rect2(Vector2.ZERO, c.size))
	var ctr := Vector2(c.size.x * 0.5, 70.0)
	match String(it.id):
		"chest_rare":
			_mini_chest(c, ctr + Vector2(0, 30), 108.0, CHEST_COLS.rare)
		"chest_epic":
			_mini_chest(c, ctr + Vector2(0, 30), 108.0, CHEST_COLS.epique)
		"tokens6":
			_token(c, ctr)
		"boost2":
			c.draw_circle(ctr, 40, Color("1d2a52"))
			c.draw_arc(ctr, 39, 0, TAU, 40, UI.ACCENT, 4.0, true)
			SkillButton.draw_glyph(c, 0, ctr, UI.ACCENT, 0.85)


func _crystals_row(y: float) -> float:
	var c := Control.new()
	c.position = Vector2(24, y)
	c.size = Vector2(672, 96)
	c.draw.connect(func():
		c.draw_style_box(UI.box(UI.PANEL2, Color(0, 0, 0, 0), 24, 0), Rect2(Vector2.ZERO, c.size))
		_dashed(c, Rect2(1, 1, c.size.x - 2.0, c.size.y - 2.0), UI.LINE)
		c.draw_colored_polygon(PackedVector2Array([Vector2(54, 24), Vector2(80, 48), Vector2(54, 72), Vector2(28, 48)]), Color("ff7ad9")))
	_content.add_child(c)
	var n := UI.label(c, "Acheter des cristaux", 26, Color.WHITE, true)
	n.position = Vector2(100, 16)
	var d := UI.label(c, "Paiement bientôt disponible", 22, UI.MUTED)
	d.position = Vector2(100, 50)
	var soon := HudButton.new()
	soon.font_size = 24
	soon.radius = 30.0
	soon.tappable = false
	soon.set_texts("Bientôt")
	soon.size = Vector2(128, 60)
	soon.position = Vector2(c.size.x - 148.0, 18)
	c.add_child(soon)
	return y + 96.0


# ---------------------------------------------------------------- dessin

func _gift(ci: Control, c: Vector2) -> void:
	var k := 0.78
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
	ci.draw_rect(Rect2(P.call(-24, -4), Vector2(48, 32) * k), Color("d9512c"))
	ci.draw_rect(Rect2(P.call(-28, -16), Vector2(56, 16) * k), Color("ff7a45"))
	ci.draw_rect(Rect2(P.call(-5, -16), Vector2(10, 44) * k), Color("ffd166"))
	ci.draw_colored_polygon(PackedVector2Array([P.call(0, -16), P.call(-16, -30), P.call(-6, -32)]), Color("ffd166"))
	ci.draw_colored_polygon(PackedVector2Array([P.call(0, -16), P.call(16, -30), P.call(6, -32)]), Color("ffd166"))


## Petit coffre plat (couvercle, corps, ferrures), centré sur `base` (milieu du bas), largeur `w`.
func _mini_chest(ci: Control, base: Vector2, w: float, pal: Array) -> void:
	var k := w / 160.0
	var o := base - Vector2(80.0, 126.0) * k
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
	ci.draw_colored_polygon(PackedVector2Array([P.call(20, 56), P.call(140, 56), P.call(146, 112), P.call(14, 112)]), pal[1])
	ci.draw_colored_polygon(PackedVector2Array([P.call(20, 56), P.call(80, 56), P.call(80, 112), P.call(14, 112)]), pal[0])
	ci.draw_colored_polygon(PackedVector2Array([P.call(24, 22), P.call(136, 22), P.call(148, 56), P.call(12, 56)]), pal[2])
	ci.draw_colored_polygon(PackedVector2Array([P.call(24, 22), P.call(80, 22), P.call(80, 56), P.call(12, 56)]), pal[2].lightened(0.15))
	ci.draw_rect(Rect2(P.call(12, 52), Vector2(136, 9) * k), Color("ffd166"))
	ci.draw_colored_polygon(PackedVector2Array([P.call(68, 54), P.call(92, 54), P.call(96, 76), P.call(80, 86), P.call(64, 76)]), Color("ffd166"))


func _token(ci: Control, c: Vector2) -> void:
	ci.draw_style_box(UI.box(Color("9b6bf0"), Color("e6d6ff"), 14, 0), Rect2(c + Vector2(-44, -30), Vector2(88, 60)))
	ci.draw_circle(c, 12.0, Color("2a1450"))


func _dashed(ci: Control, r: Rect2, col: Color) -> void:
	var rad := 22.0
	var pts := PackedVector2Array()
	var corners := [[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5], [Vector2(r.end.x - rad, r.end.y - rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5], [Vector2(r.position.x + rad, r.position.y + rad), PI]]
	for cn in corners:
		for i in 7:
			pts.append(cn[0] + Vector2.from_angle(cn[1] + (PI * 0.5) * float(i) / 6.0) * rad)
	pts.append(pts[0])
	var acc := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var d := 0.0
		while d < seg:
			var d2 := minf(seg, d + 4.0)
			if int((acc + d) / 10.0) % 2 == 0:
				ci.draw_line(a.lerp(b, d / seg), a.lerp(b, d2 / seg), col, 2.0)
			d = d2
		acc += seg


func _hm(sec: float) -> String:
	var s := int(sec)
	return "%d h %02d" % [s / 3600, (s % 3600) / 60]


# ---------------------------------------------------------------- logique

func _buy(id: String) -> void:
	var msg: String = Game.buy(id)
	if msg != "":
		Sfx.play("coin")
		Game.save_game()
		bought.emit(msg)
	_refresh()


func _process(delta: float) -> void:
	_timer += delta
	if _timer > 0.5:
		_timer = 0.0
		_refresh()


func _refresh() -> void:
	var vals := [UI.short(float(Game.crystals)), str(Game.tokens), UI.short(Game.credits)]
	var xr := 696.0
	for i in [2, 1, 0]:
		var ch: HudButton = _chips[i]
		ch.set_texts(vals[i])
		ch.fit_chip()
		ch.position = Vector2(xr - ch.size.x, 20)
		xr -= ch.size.x + 12.0
	for pair in _live:
		(pair[1] as Callable).call()
		(pair[0] as Control).queue_redraw()
