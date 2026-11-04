class_name ShopScreen
extends Overlay
## Boutique (maquette BG) : barre du haut avec cristaux, puces d'onglet, offre du jour, cartes en deux colonnes.
## Les cristaux se gagnent sur les gros boss ; leur achat contre de l'argent réel viendra avec la publication.

signal bought(text: String)

const TABS := [["Offres", ""], ["Coffres", "chests"], ["Jetons", "tokens"], ["Boosts", "boosts"]]
const CHEST_COLS := {
	"rare": [Color("2f6fc4"), Color("1f4a8a"), Color("4fa8ff")],
	"epique": [Color("7a46d6"), Color("4f2a94"), Color("b388ff")],
	"legendaire": [Color("b86e0f"), Color("8a4f08"), Color("ffb142")],
}

var _tab := 0
var _stage: Control
var _scroll: ScrollContainer
var _content: Control
var _chip: HudButton
var _chips: M3Chips
var _timer := 0.0
var _live: Array = []          # éléments qui changent avec le temps : [Control, Callable]


func _init() -> void:
	super._init(720.0)
	panel.custom_minimum_size = Vector2(720, 1120)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 0))
	box.add_theme_constant_override("separation", 0)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(720, 1120)
	box.add_child(_stage)
	_chip = M3.cur_chip("crystal", str(Game.crystals))
	M3.top_bar(_stage, "Boutique", Callable(), [_chip])
	var labels: Array = []
	for t in TABS:
		labels.append(t[0])
	_chips = M3Chips.new(labels, 0)
	_chips.position = Vector2(32, 96)
	_chips.changed.connect(func(i: int):
		_tab = i
		_rebuild())
	_stage.add_child(_chips)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 192)
	_scroll.size = Vector2(720, 928)
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
	var y := 0.0
	var tab_id: String = TABS[_tab][1]
	if tab_id == "":
		y = _daily(y) + 16.0
	var list: Array = []
	for it in Data.SHOP_ITEMS:
		if tab_id == "" or it.tab == tab_id:
			list.append(it)
	var col := 0
	for it in list:
		_card(it, Vector2(32.0 + col * 336.0, y), Vector2(320, 316))
		col += 1
		if col == 2:
			col = 0
			y += 332.0
	if col != 0:
		y += 332.0
	if tab_id == "" or tab_id == "chests":
		y = _free_row(y) + 16.0
	if tab_id == "":
		y = _crystals_row(y) + 16.0
	_content.custom_minimum_size = Vector2(720, y + 24.0)
	_refresh()


# ---------------------------------------------------------------- éléments

func _price_button(parent: Control, rect: Rect2, cost: int, kind: String, on_press: Callable) -> Button:
	var b := M3.button(parent, "", rect, kind, 30)
	UI.set_button_parts(b, [UI.icon("crystal"), str(cost)], M3.fs(30), Color("1a1004") if kind == "gold" else UI.TEXT)
	b.pressed.connect(on_press)
	return b


func _daily(y: float) -> float:
	var it: Dictionary = Data.DAILY_OFFER
	var c := Control.new()
	c.position = Vector2(32, y)
	c.size = Vector2(656, 296)
	c.draw.connect(func():
		UI.draw_gradient_box(c, Rect2(Vector2.ZERO, c.size), 40.0, Color("3a2a0a"), Color("1a1004"), Color("ffb142"), 3.0)
		M3.text(c, Vector2(32, 52), "OFFRE DU JOUR", 24, Color("ffb142"), true)
		var avail := Game.daily_available()
		M3.text(c, Vector2(0, 52), ("-30 %% · %s" % _hm(Game.daily_remaining())) if avail else "Revient demain", 24, Color("ffb142"), false, 624, HORIZONTAL_ALIGNMENT_RIGHT)
		M3.text(c, Vector2(32, 100), String(it.name), 36, UI.TEXT, true)
		M3.text(c, Vector2(32, 136), String(it.desc), 26, UI.MUTED))
	_content.add_child(c)
	var b := _price_button(c, Rect2(24, 168, 608, 104), int(it.cost), "gold", func(): _buy(it.id))
	b.set_meta("avail_on", true)
	_live.append([c, func():
		var avail := Game.daily_available()
		if avail != b.has_meta("avail_on"):
			UI.set_button_parts(b, [UI.icon("crystal"), str(int(it.cost))] if avail else ["Acheté"], M3.fs(30), Color("1a1004"))
			if avail:
				b.set_meta("avail_on", true)
			else:
				b.remove_meta("avail_on")
		b.disabled = not avail or Game.crystals < int(it.cost)])
	return y + 296.0


func _card(it: Dictionary, pos: Vector2, sz: Vector2) -> void:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.draw.connect(_draw_card.bind(c, it))
	_content.add_child(c)
	var d := UI.label(c, String(it.desc), M3.fs(24), UI.MUTED)
	d.position = Vector2(32, 152)
	d.size = Vector2(256, 34)
	d.clip_text = true
	var b := _price_button(c, Rect2(32, 196, 256, 96), int(it.cost), "ghost", func(): _buy(it.id))
	_live.append([c, func():
		b.disabled = Game.crystals < int(it.cost)
		if it.has("boost") and Game.boost_active():
			d.text = "Actif : encore %s" % UI.duration(Game.boost_remaining())
		elif it.has("boost"):
			d.text = String(it.desc)])


func _draw_card(c: Control, it: Dictionary) -> void:
	M3.card(c, Rect2(Vector2.ZERO, c.size))
	var ctr := Vector2(c.size.x * 0.5, 64.0)
	match String(it.id):
		"chest_rare":
			_mini_chest(c, ctr + Vector2(0, 30), 96.0, CHEST_COLS.rare)
		"chest_epic":
			_mini_chest(c, ctr + Vector2(0, 30), 96.0, CHEST_COLS.epique)
		"tokens6":
			_token(c, ctr)
		"itokens6":
			_token(c, ctr, true)
		"boost2":
			c.draw_circle(ctr, 36, M3.S3)
			SkillButton.draw_glyph(c, 0, ctr, UI.GOLD, 0.8)
	M3.text(c, Vector2(32, 144), String(it.name), 30, UI.TEXT, true, 270)
	if it.has("badge"):
		c.draw_style_box(UI.box(UI.GOLD, Color(0, 0, 0, 0), 16, 0), Rect2(c.size.x - 168.0, 16, 152, 40))
		M3.text(c, Vector2(c.size.x - 168.0, 44), String(it.badge), 20, Color("1a1004"), true, 152, HORIZONTAL_ALIGNMENT_CENTER)


func _free_row(y: float) -> float:
	var c := Control.new()
	c.position = Vector2(32, y)
	c.size = Vector2(656, 144)
	c.draw.connect(func():
		M3.card(c, Rect2(Vector2.ZERO, c.size), M3.S2, 32, Color(UI.GREEN, 0.4) if Game.free_chest_ready() else Color(0, 0, 0, 0))
		_gift(c, Vector2(72, 76))
		M3.text(c, Vector2(136, 64), "Coffre gratuit", 30, UI.TEXT, true)
		M3.text(c, Vector2(136, 104), "Prêt à ouvrir" if Game.free_chest_ready() else "Prochain dans %s" % UI.duration(Game.free_chest_remaining()), 24, UI.GREEN if Game.free_chest_ready() else UI.MUTED))
	_content.add_child(c)
	var b := M3.button(c, "Ouvrir", Rect2(456, 24, 176, 96), "main", 28)
	b.pressed.connect(func():
		var ch: Dictionary = Game.claim_free_chest()
		if not ch.is_empty():
			Sfx.play("chest")
			Game.save_game()
			bought.emit("Coffre %s : + %s crédits, + %d éclats" % [String(Data.RARITY_NAMES[ch.rarity]).to_lower(), Data.fmt(ch.credits), int(ch.shards)])
		_refresh())
	_live.append([c, func(): b.disabled = not Game.free_chest_ready()])
	return y + 144.0


func _crystals_row(y: float) -> float:
	var c := Control.new()
	c.position = Vector2(32, y)
	c.size = Vector2(656, 144)
	c.draw.connect(func():
		M3.card(c, Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0), 32, M3.OUT)
		c.draw_colored_polygon(PackedVector2Array([Vector2(72, 44), Vector2(100, 72), Vector2(72, 100), Vector2(44, 72)]), Color("ff7ad9"))
		M3.text(c, Vector2(136, 64), "Acheter des cristaux", 30, UI.TEXT, true)
		M3.text(c, Vector2(136, 104), "Paiement bientôt disponible", 24, UI.MUTED))
	_content.add_child(c)
	var b := M3.button(c, "Bientôt", Rect2(456, 24, 176, 96), "outline", 26)
	b.disabled = true
	return y + 144.0


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


func _token(ci: Control, c: Vector2, orange := false) -> void:
	ci.draw_style_box(UI.box(Color("ffb142") if orange else Color("9b6bf0"), Color("ffe2a8") if orange else Color("e6d6ff"), 14, 0), Rect2(c + Vector2(-44, -30), Vector2(88, 60)))
	ci.draw_circle(c, 12.0, Color("3a2000") if orange else Color("2a1450"))


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
	_chip.set_texts(UI.short(float(Game.crystals)))
	_chip.fit_chip()
	_chip.size.y = 64.0
	_chip.position.x = 704.0 - _chip.size.x - 8.0
	for pair in _live:
		(pair[1] as Callable).call()
		(pair[0] as Control).queue_redraw()
