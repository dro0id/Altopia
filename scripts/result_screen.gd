class_name ResultScreen
extends Overlay

## Étage vaincu (maquette E) : étoiles, coffre à toucher, rareté annoncée, garantie, butin caché puis révélé, bouton pour continuer.

signal next_pressed
signal replay_pressed
signal map_pressed
signal who_requested(item_id: int)

const FOOT := "Le butin se révèle à l'ouverture, puis « %s »."

var _t := 0.0
var _star_count := 3
var _stars_shown := 0
var _stage_ctrl: Control
var _cv: ChestView
var _hint: Label
var _tiles: Array = []
var _main_btn: Button
var _foot: Label
var _after: HBoxContainer
var _opened := false
var _next_label := ""
var _rays: Control
var _rcol := Color("ffb142")
var _chest: Dictionary = {}
var _item_phase := false
var _hint_nodes: Array = []
var _eyebrow: Control
var _rarity := "commun"
var _bt := ""
var _loot_actions: Control
var _banner_ctrl: Control
var _item_card: Control
var _drop: Dictionary = {}
var _best := {}
var _note_lab: Label


func _init(stage: int, star_count: int, chest: Dictionary, next_label: String, combo := 0) -> void:
	super._init(720.0)
	_star_count = star_count
	_next_label = next_label
	panel.custom_minimum_size = Vector2(720, 1280)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 0))
	box.add_theme_constant_override("separation", 0)
	_stage_ctrl = Control.new()
	_stage_ctrl.custom_minimum_size = Vector2(720, 1280)
	box.add_child(_stage_ctrl)
	var bt: String = Data.boss_type(stage)
	var rarity: String = chest.rarity
	_chest = chest
	_rarity = rarity
	_bt = bt
	_rcol = Data.CHEST_COLORS[rarity]
	# titre, étoiles, légende
	var title := "ÉTAGE %d · %s" % [stage, "GROS BOSS VAINCU" if bt == "big" else ("MINI-BOSS VAINCU" if bt == "mini" else "ÉTAGE VAINCU")]
	var eb := Control.new()
	eb.position = Vector2(0, 38)
	eb.size = Vector2(720, 40)
	eb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eb.draw.connect(func():
		var fb := UI.bold_font()
		var tw := 0.0
		for ch in title:
			tw += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0
		var x := (720.0 - tw) * 0.5
		for ch in title:
			eb.draw_string(fb, Vector2(x, 28), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("ffb142"))
			x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0)
	_stage_ctrl.add_child(eb)
	_eyebrow = eb
	var note := "Aucun héros tombé" if star_count == 3 else ("Un héros est tombé" if star_count == 2 else "Plusieurs héros sont tombés")
	if combo > 1:
		note += " · combo max ×%d" % combo
	_note_lab = _lab(note, 22, UI.MUTED, Vector2(0, 148), 720.0)
	# rayons qui tournent derrière le coffre
	_rays = Control.new()
	_rays.position = Vector2(0, 0)
	_rays.size = Vector2(720, 1280)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	_stage_ctrl.add_child(_rays)
	_cv = ChestView.new()
	_cv.setup(rarity)
	_cv.chest_scale = 1.55
	_cv.position = Vector2(100, 306)
	_cv.size = Vector2(520, 300)
	_stage_ctrl.add_child(_cv)
	_cv.armed_changed.connect(func(): _hint.visible = false)
	# doigt
	var fin := Control.new()
	fin.position = Vector2(316, 590)
	fin.size = Vector2(88, 88)
	fin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fin.draw.connect(func():
		if _cv.armed:
			return
		var k := 1.0 + 0.05 * sin(_t * 5.2)
		fin.draw_arc(Vector2(44, 44), 42.0 * k, 0, TAU, 40, Color(1, 1, 1, 0.55), 4.0, true)
		var hc := Color("ffd166")
		fin.draw_style_box(UI.box(hc, Color("a07a1e"), 7, 0), Rect2(38, 20, 13, 30))   # index
		fin.draw_style_box(UI.box(hc, Color("a07a1e"), 10, 0), Rect2(28, 42, 34, 26))   # paume
		fin.draw_style_box(UI.box(hc, Color("a07a1e"), 6, 0), Rect2(22, 46, 12, 16)))   # pouce
	_stage_ctrl.add_child(fin)
	_hint = _lab("Touche le coffre pour l'ouvrir", 22, UI.MUTED, Vector2(0, 806), 720.0)
	# pastille de rareté
	var pill := Label.new()
	pill.text = "COFFRE %s" % String(Data.RARITY_NAMES[rarity]).to_upper()
	pill.add_theme_font_override("font", UI.bold_font())
	pill.add_theme_font_size_override("font_size", 26)
	pill.add_theme_color_override("font_color", _rcol)
	pill.add_theme_stylebox_override("normal", UI.box(Color("0d1530"), _rcol, 40, 0))
	pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pw := UI.bold_font().get_string_size(pill.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 64.0
	pill.size = Vector2(pw, 60)
	pill.position = Vector2((720.0 - pw) * 0.5, 738)
	_stage_ctrl.add_child(pill)
	# garantie légendaire (gros boss)
	if bt == "big":
		var gc := Control.new()
		gc.position = Vector2(32, 862)
		gc.size = Vector2(656, 88)
		gc.draw.connect(func():
			gc.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 24, 0), Rect2(Vector2.ZERO, gc.size))
			var fb := UI.bold_font()
			gc.draw_string(fb, Vector2(24, 40), "Garantie légendaire", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
			var v := mini(int(Game.pity.get("leg", 0)), Data.LEGENDARY_PITY)
			gc.draw_string(ThemeDB.fallback_font, Vector2(0, 38), "%d / %d gros boss" % [v, Data.LEGENDARY_PITY], HORIZONTAL_ALIGNMENT_RIGHT, gc.size.x - 24.0, 22, UI.MUTED)
			var sw := (gc.size.x - 48.0 - 8.0 * (Data.LEGENDARY_PITY - 1)) / float(Data.LEGENDARY_PITY)
			for i in Data.LEGENDARY_PITY:
				var col: Color = Color("ffb142") if i < v else UI.LINE2
				gc.draw_style_box(UI.box(col, Color(0, 0, 0, 0), 8, 0), Rect2(24.0 + i * (sw + 8.0), 58, sw, 16)))
		_stage_ctrl.add_child(gc)
	# butin caché
	var vals := [["Crédits", "+%s" % UI.num(chest.credits), UI.GOLD], ["Éclats", "+%d" % int(chest.shards), Color("7fdcff")], ["Jetons", "+%d" % int(chest.get("tokens", 0)), Color("b388ff")], ["Cristaux", "+%d" % int(chest.get("crystals", 0)), Color("ff7ad9")]]
	for i in 4:
		var tl := LootTile.new()
		tl.title = vals[i][0]
		tl.value = vals[i][1]
		tl.col = vals[i][2]
		tl.position = Vector2(32.0 + i * (156.0 + 16.0), 972)
		tl.size = Vector2(156, 108)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage_ctrl.add_child(tl)
		_tiles.append(tl)
	if chest.get("combo_bonus", 0.0) > 0.0:
		_lab("Bonus de combo : + %d %% de crédits" % int(round(chest.combo_bonus * 100.0)), 20, UI.GREEN, Vector2(0, 1086), 720.0)
	# bouton principal
	_main_btn = UI.button(_stage_ctrl, "Ouvrir le coffre", 32, "gold")
	_main_btn.position = Vector2(32, 1100)
	_main_btn.size = Vector2(656, 104)
	_main_btn.pressed.connect(func():
		if not _opened:
			_cv.arm()
		elif _item_phase and _best.get("hero", "") != "" and _drop.status == "added":
			Game.equip(int(_drop.item.id), _best.hero)
			Game.save_game()
			Sfx.play("chest", -4.0)
			next_pressed.emit()
			close()
		else:
			next_pressed.emit()
			close())
	_foot = _lab(FOOT % ("Étage suivant" if next_label.begins_with("Monter") else next_label), 22, UI.MUTED, Vector2(0, 1216), 720.0)
	_after = HBoxContainer.new()
	_after.position = Vector2(32, 1214)
	_after.size = Vector2(656, 56)
	_after.add_theme_constant_override("separation", 16)
	_after.visible = false
	_stage_ctrl.add_child(_after)
	var rb := UI.button(_after, "Rejouer cet étage", 22, "ghost")
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.custom_minimum_size = Vector2(0, 56)
	rb.pressed.connect(func():
		replay_pressed.emit()
		close())
	var mb := UI.button(_after, "Carte des étages", 22, "ghost")
	mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mb.custom_minimum_size = Vector2(0, 56)
	mb.pressed.connect(func():
		map_pressed.emit()
		close())
	_cv.opened.connect(func():
		Game.claim_pending()
		_opened = true
		_main_btn.text = "Étage suivant" if next_label.begins_with("Monter") else next_label
		_foot.visible = false
		_after.visible = true
		_reveal()
		_drop = Game.last_drop
		if not _drop.is_empty():
			get_tree().create_timer(1.1).timeout.connect(_show_item))
	Sfx.play("win")


func close() -> void:
	Game.claim_pending()    # si on quitte l'écran avant l'ouverture, le butin est quand même versé
	super.close()


func _lab(text: String, size: int, col: Color, pos: Vector2, width: float, bold := false) -> Label:
	var l := UI.label(_stage_ctrl, text, size, col, bold)
	l.position = pos
	l.size = Vector2(width, size + 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _reveal() -> void:
	var i := 0
	for tl in _tiles:
		var d: float = 0.12 * i
		i += 1
		var tw := create_tween()
		tw.tween_interval(d)
		tw.tween_callback(func():
			tl.revealed = true
			tl.pop = 1.0
			Sfx.play("coin", -8.0, 1.0 + 0.1 * i))
		tw.tween_property(tl, "pop", 0.0, 0.25)


## Après l'ouverture : l'objet du coffre prend la place du coffre (maquette Y), avec le héros qui en profite le plus.
func _show_item() -> void:
	if _drop.is_empty() or _item_phase:
		return
	_item_phase = true
	_cv.visible = false
	_note_lab.text = "Coffre %s ouvert" % String(Data.RARITY_NAMES[_rarity]).to_lower()
	_note_lab.position.y = 76.0
	_hint.visible = false
	for n in _stage_ctrl.get_children():
		if n is Label and n != _hint and n.position.y > 700.0 and n.position.y < 900.0:
			n.visible = false
		elif n is Control and n.size == Vector2(656, 88):
			n.visible = false
		elif n is Control and n.size == Vector2(656, 60) or (n is Label and n.text.begins_with("COFFRE")):
			n.visible = false
	for tl in _tiles:
		tl.position.y = 130.0
	_foot.visible = false
	_after.visible = false
	var it: Dictionary = _drop.item
	_item_card = Control.new()
	_item_card.position = Vector2(110, 330)
	_item_card.size = Vector2(500, 520)
	var col := ItemUI.color(it.rarity)
	_item_card.draw.connect(func():
		var k := 1.0 + 0.012 * sin(_t * 4.0)
		var cc := _item_card
		cc.draw_set_transform(cc.size * 0.5, 0.0, Vector2(k, k))
		cc.draw_style_box(UI.box(UI.PANEL, col, 36, 0), Rect2(-cc.size * 0.5, cc.size))
		cc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var tw := 0.0
		for ch in "NOUVEL OBJET":
			tw += UI.bold_font().get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 2.5
		var x := (cc.size.x - tw) * 0.5
		for ch in "NOUVEL OBJET":
			cc.draw_string(UI.bold_font(), Vector2(x, 62), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
			x += UI.bold_font().get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 2.5
		ItemUI.tile(cc, Rect2((cc.size.x - 168.0) * 0.5, 88, 168, 168), it, false)
		cc.draw_string(UI.bold_font(), Vector2(0, 306), it.name, HORIZONTAL_ALIGNMENT_CENTER, cc.size.x, 30, col)
		if it.set != "":
			var info: Dictionary = Items.SETS[it.set]
			var sw := UI.bold_font().get_string_size(it.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			ItemUI.set_badge(cc, Vector2(cc.size.x * 0.5 + sw * 0.5 + 10.0, 280), it.set)
		cc.draw_string(ThemeDB.fallback_font, Vector2(0, 340), "%s %s" % [Items.SLOT_NAMES[it.slot], String(Data.RARITY_NAMES[it.rarity]).to_lower()], HORIZONTAL_ALIGNMENT_CENTER, cc.size.x, 22, UI.MUTED)
		var lines: Array = [Items.main_text(it)]
		lines.append_array(Items.sub_lines(it))
		var y := 388.0
		var half := ceili(lines.size() / 2.0)
		for i in lines.size():
			var line: String = lines[i]
			cc.draw_string(UI.bold_font() if i == 0 else ThemeDB.fallback_font, Vector2(0, y + (i % half) * 36.0 if false else y + i * 34.0), line, HORIZONTAL_ALIGNMENT_CENTER, cc.size.x, 24, Color.WHITE if i == 0 else UI.MUTED))
	_stage_ctrl.add_child(_item_card)
	_rcol = col
	# bandeau du meilleur héros
	_best = Game.best_hero_for(it)
	_banner_ctrl = Control.new()
	_banner_ctrl.position = Vector2(32, 880)
	_banner_ctrl.size = Vector2(656, 104)
	_banner_ctrl.draw.connect(func():
		var c2 := _banner_ctrl
		var ok: bool = _drop.status == "added" and _best.get("hero", "") != ""
		var bc := UI.GREEN if (ok and float(_best.gain) > 0.0) else (UI.RED if _drop.status != "added" else UI.LINE)
		c2.draw_style_box(UI.box(Color(bc.r * 0.18, bc.g * 0.3, bc.b * 0.2, 1.0) if bc != UI.LINE else UI.PANEL, Color(bc.r, bc.g, bc.b, 0.4), 24, 0), Rect2(Vector2.ZERO, c2.size))
		if _drop.status == "recycled":
			c2.draw_string(UI.bold_font(), Vector2(28, 62), "Objet commun recyclé : +%d éclat" % int(Items.RECYCLE_SHARDS[it.rarity]), HORIZONTAL_ALIGNMENT_LEFT, 600.0, 24, UI.MUTED)
		elif _drop.status == "stash":
			c2.draw_string(UI.bold_font(), Vector2(28, 62), "Inventaire plein : l'objet attend de côté", HORIZONTAL_ALIGNMENT_LEFT, 600.0, 24, UI.RED)
		elif ok:
			UI.portrait(c2, Data.HEROES[_best.hero], Vector2(64, 52), 40.0, _t)
			var nm: String = String(Data.HEROES[_best.hero].name).split(" ")[0]
			c2.draw_string(ThemeDB.fallback_font, Vector2(124, 62), "Meilleur sur", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
			var w := ThemeDB.fallback_font.get_string_size("Meilleur sur ", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			c2.draw_string(UI.bold_font(), Vector2(124 + w, 62), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
			ItemUI.delta(c2, 632.0, 62.0, float(_best.gain))
		else:
			c2.draw_string(UI.bold_font(), Vector2(28, 62), "Aucun héros ne peut le porter pour l'instant", HORIZONTAL_ALIGNMENT_LEFT, 600.0, 22, UI.MUTED))
	_stage_ctrl.add_child(_banner_ctrl)
	# boutons
	var can_equip: bool = _drop.status == "added" and _best.get("hero", "") != ""
	if can_equip:
		_main_btn.text = "Équiper sur %s" % String(Data.HEROES[_best.hero].name).split(" ")[0]
	else:
		_main_btn.text = "Étage suivant" if _next_label.begins_with("Monter") else _next_label
	_main_btn.position = Vector2(32, 1032)
	_loot_actions = HBoxContainer.new()
	_loot_actions.position = Vector2(32, 1152)
	_loot_actions.size = Vector2(656, 96)
	_loot_actions.add_theme_constant_override("separation", 16)
	_stage_ctrl.add_child(_loot_actions)
	if _drop.status == "added":
		var who := UI.button(_loot_actions, "À qui ?", 26, "ghost")
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.custom_minimum_size = Vector2(0, 96)
		who.pressed.connect(func():
			who_requested.emit(int(_drop.item.id))
			close())
	var nxt := UI.button(_loot_actions, "Étage suivant" if _next_label.begins_with("Monter") else _next_label, 26, "ghost")
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.custom_minimum_size = Vector2(0, 96)
	nxt.pressed.connect(func():
		next_pressed.emit()
		close())


func _process(delta: float) -> void:
	_t += delta
	var shown := int(floor((_t - 0.3) / 0.35)) + 1
	while _stars_shown < mini(shown, 3):
		_stars_shown += 1
		if _stars_shown <= _star_count:
			Sfx.play("star", -4.0, 1.0 + 0.15 * _stars_shown)
	_rays.queue_redraw()
	_stage_ctrl.queue_redraw()
	for tl in _tiles:
		tl.queue_redraw()
	queue_redraw()


func _draw() -> void:
	pass


## Trois grandes étoiles dorées sous le titre (celles non gagnées restent éteintes).
func _draw_stars_on(ci: CanvasItem) -> void:
	for i in 3:
		var appear := clampf((_t - 0.3 - i * 0.35) / 0.3, 0.0, 1.0)
		if appear <= 0.0:
			continue
		var pop := 1.0 + 0.4 * sin(appear * PI)
		var pulse := 1.0 + 0.04 * sin(_t * 3.9 + i * 0.5)
		var col := UI.GOLD if i < _star_count else UI.LINE
		var c := Vector2(360.0 + (i - 1) * 100.0, 98.0)
		if i < _star_count:
			ci.draw_circle(c, 40.0 * appear, Color(1.0, 0.69, 0.26, 0.12))
		Art.star(ci, c, 34.0 * pop * appear * pulse, col, 0.0)


func _draw_rays() -> void:
	if not _item_phase:
		_draw_stars_on(_rays)
	var c := Vector2(360, 590 if _item_phase else 470)
	var rot := _t * 0.26
	for i in 12:
		var a0 := rot + TAU * i / 12.0
		var a1 := a0 + deg_to_rad(11.0)
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a0) * 340.0, c + Vector2.from_angle(a1) * 340.0])
		var cols := PackedColorArray([Color(_rcol.r, _rcol.g, _rcol.b, 0.28), Color(_rcol.r, _rcol.g, _rcol.b, 0.0), Color(_rcol.r, _rcol.g, _rcol.b, 0.0)])
		_rays.draw_polygon(pts, cols)
	_rays.draw_circle(c, 150.0, Color(_rcol.r, _rcol.g, _rcol.b, 0.07))
