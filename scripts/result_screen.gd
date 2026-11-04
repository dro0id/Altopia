class_name ResultScreen
extends Overlay
## Étage vaincu (maquettes BW puis BH) : on touche le coffre pour l'ouvrir, puis l'écran de victoire montre étoiles, objet et butin.

signal next_pressed
signal replay_pressed
signal map_pressed
signal who_requested(item_id: int)

var _t := 0.0
var _star_count := 3
var _stars_shown := 0
var _st: Control
var _cv: ChestView
var _open_btn: Button
var _rays: Control
var _rcol := Color("ffb142")
var _chest: Dictionary = {}
var _rarity := "commun"
var _bt := ""
var _stage := 1
var _next_label := ""
var _combo := 0
var _opened := false
var _phase1: Array = []
var _victory: Control
var _drop: Dictionary = {}
var _best := {}


func _init(stage: int, star_count: int, chest: Dictionary, next_label: String, combo := 0) -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	_stage = stage
	_star_count = star_count
	_next_label = next_label
	_combo = combo
	_chest = chest
	_rarity = chest.rarity
	_bt = Data.boss_type(stage)
	_rcol = Data.CHEST_COLORS[_rarity]
	_rays = Control.new()
	_rays.size = Vector2(720, 1280)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	_st.add_child(_rays)
	# phase 1 : le coffre (BW)
	_cv = ChestView.new()
	_cv.setup(_rarity)
	_cv.chest_scale = 1.55
	_cv.position = Vector2(100, 410)
	_cv.size = Vector2(520, 300)
	_st.add_child(_cv)
	var lab := Control.new()
	lab.size = Vector2(720, 140)
	lab.position = Vector2(0, 760)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.draw.connect(func():
		_spaced(lab, 48, "COFFRE %s" % String(Data.RARITY_NAMES[_rarity]).to_upper(), 24, _rcol)
		if not _cv.armed:
			M3.text(lab, Vector2(0, 100), "Touche pour ouvrir", 28, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER))
	_st.add_child(lab)
	_open_btn = M3.button(_st, "Ouvrir", Rect2(32, 1280 - 32 - 112, 656, 112), "main", 32)
	_open_btn.pressed.connect(func(): _cv.arm())
	_cv.armed_changed.connect(func(): _open_btn.disabled = true)
	_phase1 = [_cv, lab, _open_btn]
	_cv.opened.connect(func():
		Game.claim_pending()
		_opened = true
		_drop = Game.last_drop
		get_tree().create_timer(0.9).timeout.connect(_show_victory))
	_st.resized.connect(_layout)
	Sfx.play("win")


func _layout() -> void:
	var h := _st.size.y if _st.size.y > 0.0 else 1280.0
	_open_btn.position.y = h - 32.0 - 112.0


func close() -> void:
	Game.claim_pending()    # si on quitte l'écran avant l'ouverture, le butin est quand même versé
	super.close()


func _spaced(ci: CanvasItem, y: float, txt: String, size: int, col: Color) -> void:
	var fb := UI.bold_font()
	var fs := M3.fs(size)
	var tw := 0.0
	for ch in txt:
		tw += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3.0
	var x := (720.0 - tw) * 0.5
	for ch in txt:
		ci.draw_string(fb, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3.0


## Phase 2 : victoire (BH).
func _show_victory() -> void:
	if _victory != null:
		return
	for n in _phase1:
		n.visible = false
	var it: Dictionary = _drop.get("item", {})
	if not it.is_empty():
		_rcol = ItemUI.color(it.rarity)
	_best = Game.best_hero_for(it) if (not it.is_empty() and _drop.status == "added") else {"hero": "", "gain": 0.0}
	_victory = Control.new()
	_victory.size = Vector2(720, 900)
	_victory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory.draw.connect(_draw_victory)
	_st.add_child(_victory)
	_t = 0.0
	_stars_shown = 0
	var h := _st.size.y if _st.size.y > 0.0 else 1280.0
	var nxt_txt := "Monter à l'étage %d" % (_stage + 1) if _next_label.begins_with("Monter") else _next_label
	var can: bool = _best.get("hero", "") != "" and float(_best.get("gain", 0.0)) > 0.0
	var main_txt := ("Équiper sur %s" % String(Data.HEROES[_best.hero].name).split(" ")[0]) if can else nxt_txt
	var b1 := M3.button(_st, main_txt, Rect2(32, h - 32 - 96 - 16 - 104, 656, 104), "main", 32)
	b1.pressed.connect(func():
		if can:
			Game.equip(int(it.id), _best.hero)
			Game.save_game()
			Sfx.play("chest", -4.0)
		next_pressed.emit()
		close())
	var second := nxt_txt if can else ("À qui l'équiper ?" if (not it.is_empty() and _drop.status == "added") else "Rejouer l'étage %d" % _stage)
	var b2 := M3.button(_st, second, Rect2(32, h - 32 - 96, 656, 96), "ghost", 30)
	b2.pressed.connect(func():
		if can:
			next_pressed.emit()
		elif not it.is_empty() and _drop.status == "added":
			who_requested.emit(int(it.id))
		else:
			replay_pressed.emit()
		close())


func _draw_victory() -> void:
	var c := _victory
	var title := "ÉTAGE %d · %s" % [_stage, "GROS BOSS VAINCU" if _bt == "big" else ("MINI-BOSS VAINCU" if _bt == "mini" else "ÉTAGE VAINCU")]
	_spaced(c, 88, title, 24, Color("ffb142"))
	M3.text(c, Vector2(0, 160), "Victoire", 56, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 3:
		var appear := clampf((_t - 0.1 - i * 0.3) / 0.3, 0.0, 1.0)
		if appear <= 0.0:
			continue
		var pop := 1.0 + 0.35 * sin(appear * PI)
		Art.star(c, Vector2(360.0 + (i - 1) * 76.0, 214.0), 28.0 * pop * appear, UI.GOLD if i < _star_count else M3.OUT, 0.0)
	# carte du coffre
	var r := Rect2(32, 272, 656, 404)
	c.draw_style_box(UI.box(Color(_rcol, 0.0), Color(_rcol, 0.25), 56, 0), r.grow(10))
	M3.card(c, r, M3.S2, 48, _rcol, 4)
	_spaced(c, r.position.y + 56, "COFFRE %s" % String(Data.RARITY_NAMES[_rarity]).to_upper(), 24, Data.CHEST_COLORS[_rarity])
	var it: Dictionary = _drop.get("item", {})
	if not it.is_empty():
		ItemUI.tile(c, Rect2(272, r.position.y + 84, 176, 176), it, false)
		M3.text(c, Vector2(32, r.position.y + 310), String(it.name), 32, _rcol, true, 656, HORIZONTAL_ALIGNMENT_CENTER)
		var sub := Items.summary_short(it, 3)
		if _drop.status == "recycled":
			sub = "Recyclé : +%d éclat" % int(Items.RECYCLE_SHARDS[it.rarity])
		elif _drop.status == "stash":
			sub = "Inventaire plein : l'objet attend en réserve"
		M3.text(c, Vector2(56, r.position.y + 352), sub, 24, UI.MUTED, false, 608, HORIZONTAL_ALIGNMENT_CENTER)
		if _best.get("hero", "") != "" and float(_best.gain) > 0.0:
			M3.text(c, Vector2(56, r.position.y + 386), "▲ +%s de puissance sur %s" % [UI.num(_best.gain), String(Data.HEROES[_best.hero].name).split(" ")[0]], 24, UI.GREEN, true, 608, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		M3.text(c, Vector2(32, r.position.y + 200), "+ %s crédits" % UI.num(_chest.credits), 40, UI.GOLD, true, 656, HORIZONTAL_ALIGNMENT_CENTER)
	# butin
	var chips := [["coin", "+" + UI.short(_chest.credits)], ["shard", "+%d" % int(_chest.shards)], ["token", "+%d" % int(_chest.get("tokens", 0))]]
	if int(_chest.get("item_tokens", 0)) > 0:
		chips.append(["itoken", "+%d" % int(_chest.item_tokens)])
	if int(_chest.get("crystals", 0)) > 0:
		chips.append(["crystal", "+%d" % int(_chest.crystals)])
	var x := 32.0
	for ch in chips:
		var w := M3.text_w(ch[1], 26, true) + 40.0 + 34.0
		c.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 32, 0), Rect2(x, 704, w, 64))
		_icon(c, ch[0], Vector2(x + 32, 736))
		M3.text(c, Vector2(x + 54, 736 + M3.fs(26) * 0.36), ch[1], 26, UI.TEXT, true)
		x += w + 12.0


func _icon(ci: CanvasItem, kind: String, c: Vector2) -> void:
	match kind:
		"coin":
			ci.draw_circle(c, 12, UI.GOLD)
			ci.draw_string(UI.bold_font(), c + Vector2(-12, 8), "¢", HORIZONTAL_ALIGNMENT_CENTER, 24, 20, Color("6b4a00"))
		"shard":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(13, -2), c + Vector2(8, 13), c + Vector2(-8, 13), c + Vector2(-13, -2)]), Color("7fdcff"))
		"token":
			ci.draw_style_box(UI.box(Color("b388ff"), Color(0, 0, 0, 0), 5, 0), Rect2(c + Vector2(-14, -10), Vector2(28, 20)))
			ci.draw_circle(c, 4.5, Color("2a1450"))
		"itoken":
			ci.draw_style_box(UI.box(Color("ffb142"), Color(0, 0, 0, 0), 7, 0), Rect2(c + Vector2(-14, -12), Vector2(28, 24)))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), Color("3a2000"))
		_:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(12, 0), c + Vector2(0, 14), c + Vector2(-12, 0)]), Color("ff7ad9"))


func _process(delta: float) -> void:
	_t += delta
	if _victory != null:
		var shown := int(floor((_t - 0.1) / 0.3)) + 1
		while _stars_shown < mini(shown, 3):
			_stars_shown += 1
			if _stars_shown <= _star_count:
				Sfx.play("star", -4.0, 1.0 + 0.15 * _stars_shown)
		_victory.queue_redraw()
	_rays.queue_redraw()


func _draw_rays() -> void:
	var c := Vector2(360, 470 if _victory != null else 560)
	var rot := _t * 0.26
	for i in 12:
		var a0 := rot + TAU * i / 12.0
		var a1 := a0 + deg_to_rad(11.0)
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a0) * 340.0, c + Vector2.from_angle(a1) * 340.0])
		var cols := PackedColorArray([Color(_rcol, 0.24), Color(_rcol, 0.0), Color(_rcol, 0.0)])
		_rays.draw_polygon(pts, cols)
	_rays.draw_circle(c, 170.0, Color(_rcol, 0.08))
