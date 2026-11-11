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
var _rep := {}
var _fig: Node2D          # bilan du combat (sim.report) : dégâts, soutien, pouvoirs, coup de grâce


func _init(stage: int, star_count: int, chest: Dictionary, next_label: String, combo := 0, report := {}) -> void:
	super._init(720.0)
	_rep = report
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
	_rays.size = Vector2(720, UI.H)
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
	_open_btn = M3.button(_st, "Ouvrir", Rect2(32, UI.H - 32 - 112, 656, 112), "main", 32)
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
	var h := _st.size.y if _st.size.y > 0.0 else UI.H
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
	_victory.size = Vector2(720, 1200)
	_victory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory.draw.connect(_draw_victory)
	_st.add_child(_victory)
	_t = 0.0
	_stars_shown = 0
	var h := _st.size.y if _st.size.y > 0.0 else UI.H
	var nxt_txt := "Descendre au secteur %d" % (_stage + 1) if _next_label.begins_with("Monter") else _next_label
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
	var second := nxt_txt if can else ("À qui l'équiper ?" if (not it.is_empty() and _drop.status == "added") else "Rejouer le secteur %d" % _stage)
	var b2 := M3.button(_st, second, Rect2(32, h - 32 - 96, 656, 96), "ghost", 30)
	b2.pressed.connect(func():
		if can:
			next_pressed.emit()
		elif not it.is_empty() and _drop.status == "added":
			who_requested.emit(int(it.id))
		else:
			replay_pressed.emit()
		close())


## Grand écran (maquette XD) : on montre aussi la part de chacun ; sinon le coffre remonte.
func _tall() -> bool:
	return _h() >= 1400.0 and not _rep.is_empty()


func _h() -> float:
	return _st.size.y if _st.size.y > 0.0 else UI.H


## Place du héros à la plus grosse part de dégâts, ou -1.
func _mvp() -> int:
	var best := -1
	var bv := 0.0
	var dealt: Dictionary = _rep.get("dealt", {})
	for k in dealt:
		if float(dealt[k]) > bv:
			bv = float(dealt[k])
			best = int(k)
	return best


func _draw_victory() -> void:
	var c := _victory
	var title := "SECTEUR %d · %s" % [_stage, "GROS BOSS VAINCU" if _bt == "big" else ("MINI-BOSS VAINCU" if _bt == "mini" else "SECTEUR VAINCU")]
	_spaced(c, 64, title, 24, Color("ffb142"))
	M3.text(c, Vector2(0, 134), "Victoire", 56, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 3:
		var appear := clampf((_t - 0.1 - i * 0.3) / 0.3, 0.0, 1.0)
		if appear <= 0.0:
			continue
		var pop := 1.0 + 0.35 * sin(appear * PI)
		Art.star(c, Vector2(360.0 + (i - 1) * 76.0, 186.0), 28.0 * pop * appear, UI.GOLD if i < _star_count else M3.OUT, 0.0)
	# conditions des étoiles (règle du jeu : héros tombés pendant le secteur)
	var fallen := int(_rep.get("fallen", 3 - _star_count))
	var conds := [["vaincu", true], ["1 héros à terre au plus", fallen <= 1], ["aucun héros à terre", fallen == 0]]
	var tw := 0.0
	for cd in conds:
		tw += M3.text_w(String(cd[0]), 20, true) + 52.0 + 10.0
	var x := (720.0 - (tw - 10.0)) * 0.5
	for cd in conds:
		var w := M3.text_w(String(cd[0]), 20, true) + 52.0
		var ok: bool = cd[1]
		var col := UI.GREEN if ok else UI.MUTED
		c.draw_style_box(UI.box(Color(col, 0.12), Color(col, 0.55), 22, 0), Rect2(x, 222, w, 44))
		M3.text(c, Vector2(x + 16, 252), "✓" if ok else "×", 20, col, true)
		M3.text(c, Vector2(x + 38, 252), String(cd[0]), 20, col, true)
		x += w + 10.0
	var y := 290.0
	if not _rep.is_empty():
		y = _draw_mvp(c, y) + 16.0
	if _tall():
		y = _draw_shares(c, y) + 16.0
	_draw_chest(c, y)


## Figure du combat : héros en pied, part des dégâts, pouvoirs lancés, coup de grâce.
func _draw_mvp(c: Control, y: float) -> float:
	var slot := _mvp()
	var ids: Dictionary = _rep.get("ids", {})
	if slot < 0 or not ids.has(slot):
		return y - 16.0
	var hid := String(ids[slot])
	var h: Dictionary = Data.HEROES[hid]
	var r := Rect2(32, y, 656, 168)
	M3.glass_card(c, r, true, 20.0)
	if _fig == null:
		# le héros en pied, dessiné par un nœud à part (comme sur la fiche de héros)
		_fig = Node2D.new()
		_fig.position = Vector2(126, y + 160)
		_fig.scale = Vector2(0.95, 0.95)
		_fig.draw.connect(func(): Art.draw_hero(_fig, h, {"t": _t}))
		_victory.add_child(_fig)
	_spaced_at(c, Vector2(232, y + 44), "FIGURE DU COMBAT", 20, Color("ffb142"))
	M3.text(c, Vector2(232, y + 86), String(h.name).split(" ")[0], 34, UI.TEXT, true, 430)
	var dealt: Dictionary = _rep.get("dealt", {})
	var tot := 0.0
	for v in dealt.values():
		tot += float(v)
	var n := int(_rep.get("casts", {}).get(slot, 0))
	var line := "%d %% des dégâts" % int(round(float(dealt.get(slot, 0.0)) / maxf(1.0, tot) * 100.0))
	if n > 0:
		line += " · %d × %s" % [n, String(h.skill.name)]
	M3.text(c, Vector2(232, y + 120), line, 22, UI.MUTED, false, 430)
	if int(_rep.get("finisher", -1)) == slot and _bt != "":
		M3.text(c, Vector2(232, y + 150), "coup de grâce sur %s" % Data.boss_name(_stage), 22, UI.MUTED, false, 430)
	return r.end.y


## Part de chacun : dégâts en rouge, soins et boucliers en vert.
func _draw_shares(c: Control, y: float) -> float:
	var ids: Dictionary = _rep.get("ids", {})
	var dealt: Dictionary = _rep.get("dealt", {})
	var sup: Dictionary = _rep.get("support", {})
	var tot := 0.0
	for v in dealt.values():
		tot += float(v)
	for v in sup.values():
		tot += float(v)
	var slots := ids.keys()
	slots.sort()
	var r := Rect2(32, y, 656, 56 + 48.0 * slots.size())
	M3.glass_card(c, r, false, 20.0)
	c.draw_rect(Rect2(56, y + 22, 14, 14), UI.RED)
	M3.text(c, Vector2(78, y + 36), "dégâts", 20, UI.RED, true)
	c.draw_rect(Rect2(176, y + 22, 14, 14), UI.GREEN)
	M3.text(c, Vector2(198, y + 36), "soins et boucliers", 20, UI.GREEN, true)
	var top := 0.0
	for s in slots:
		top = maxf(top, (float(dealt.get(s, 0.0)) + float(sup.get(s, 0.0))) / maxf(1.0, tot))
	var yy := y + 76.0
	for s in slots:
		var h: Dictionary = Data.HEROES[String(ids[s])]
		Art.draw_portrait(c, h, Vector2(72, yy), 19.0, _t)
		var d := float(dealt.get(s, 0.0)) / maxf(1.0, tot)
		var g := float(sup.get(s, 0.0)) / maxf(1.0, tot)
		var full := 440.0 / maxf(0.01, top)
		var x0 := 108.0
		if d > 0.0:
			c.draw_style_box(UI.box(UI.RED, Color(0, 0, 0, 0), 6, 0), Rect2(x0, yy - 7, maxf(10.0, d * full), 14))
			x0 += maxf(10.0, d * full) + 4.0
		if g > 0.0:
			c.draw_style_box(UI.box(UI.GREEN, Color(0, 0, 0, 0), 6, 0), Rect2(x0, yy - 7, maxf(10.0, g * full), 14))
		M3.text(c, Vector2(560, yy + 8), "%d %%" % int(round((d + g) * 100.0)), 22, UI.TEXT, true, 104, HORIZONTAL_ALIGNMENT_RIGHT)
		yy += 48.0
	return r.end.y


## Le coffre : objet gagné et butin.
func _draw_chest(c: Control, y: float) -> void:
	var it: Dictionary = _drop.get("item", {})
	var tall := not _rep.is_empty()
	var r := Rect2(32, y, 656, (236.0 if tall else 404.0))
	c.draw_style_box(UI.box(Color(_rcol, 0.0), Color(_rcol, 0.25), 40, 0), r.grow(8))
	M3.card(c, r, M3.S2, 40, _rcol, 3)
	if tall:
		# version compacte : tuile à gauche, nom et effet à droite, butin dessous
		_spaced_at(c, Vector2(176, y + 44), "COFFRE %s" % String(Data.RARITY_NAMES[_rarity]).to_upper(), 20, Data.CHEST_COLORS[_rarity])
		if not it.is_empty():
			ItemUI.tile(c, Rect2(56, y + 24, 104, 104), it, false)
			M3.text(c, Vector2(176, y + 84), String(it.name), 28, _rcol, true, 488)
			M3.text(c, Vector2(176, y + 118), _item_line(it), 22, UI.GREEN if _gain_line() != "" else UI.MUTED, _gain_line() != "", 488)
		else:
			M3.text(c, Vector2(176, y + 90), "+ %s crédits" % UI.num(_chest.credits), 34, UI.GOLD, true, 488)
		_draw_loot(c, Vector2(56, y + 152))
		return
	_spaced(c, r.position.y + 56, "COFFRE %s" % String(Data.RARITY_NAMES[_rarity]).to_upper(), 24, Data.CHEST_COLORS[_rarity])
	if not it.is_empty():
		ItemUI.tile(c, Rect2(272, r.position.y + 84, 176, 176), it, false)
		M3.text(c, Vector2(32, r.position.y + 310), String(it.name), 32, _rcol, true, 656, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(c, Vector2(56, r.position.y + 352), _item_line(it), 24, UI.MUTED, false, 608, HORIZONTAL_ALIGNMENT_CENTER)
		if _gain_line() != "":
			M3.text(c, Vector2(56, r.position.y + 386), _gain_line(), 24, UI.GREEN, true, 608, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		M3.text(c, Vector2(32, r.position.y + 200), "+ %s crédits" % UI.num(_chest.credits), 40, UI.GOLD, true, 656, HORIZONTAL_ALIGNMENT_CENTER)
	_draw_loot(c, Vector2(32, r.end.y + 28))


func _item_line(it: Dictionary) -> String:
	if _drop.status == "recycled":
		return "Recyclé : +%d éclat" % int(Items.RECYCLE_SHARDS[it.rarity])
	if _drop.status == "stash":
		return "Inventaire plein : l'objet attend en réserve"
	if _gain_line() != "" and not _rep.is_empty():
		return _gain_line()
	return Items.summary_short(it, 3)


func _gain_line() -> String:
	if _best.get("hero", "") != "" and float(_best.get("gain", 0.0)) > 0.0:
		return "▲ +%s de puissance sur %s" % [UI.num(_best.gain), String(Data.HEROES[_best.hero].name).split(" ")[0]]
	return ""


func _draw_loot(c: Control, at: Vector2) -> void:
	var chips := [["coin", "+" + UI.short(_chest.credits)], ["shard", "+%d" % int(_chest.shards)]]
	if int(_chest.get("tokens", 0)) > 0:
		chips.append(["token", "+%d" % int(_chest.tokens)])
	if int(_chest.get("item_tokens", 0)) > 0:
		chips.append(["itoken", "+%d" % int(_chest.item_tokens)])
	if int(_chest.get("crystals", 0)) > 0:
		chips.append(["crystal", "+%d" % int(_chest.crystals)])
	if int(_chest.get("copies", 0)) > 0:
		chips.append(["copies", "+%d doublons" % int(_chest.copies)])
	var x := at.x
	for ch in chips:
		var w := M3.text_w(ch[1], 24, true) + 40.0 + 30.0
		if x + w > 680.0:
			break
		c.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 28, 0), Rect2(x, at.y, w, 56))
		_icon(c, ch[0], Vector2(x + 30, at.y + 28))
		M3.text(c, Vector2(x + 50, at.y + 28 + M3.fs(24) * 0.36), ch[1], 24, UI.TEXT, true)
		x += w + 10.0


## Texte espacé aligné à gauche.
func _spaced_at(ci: CanvasItem, at: Vector2, txt: String, size: int, col: Color) -> void:
	var fb := UI.bold_font()
	var fs := M3.fs(size)
	var x := at.x
	for ch in txt:
		ci.draw_string(fb, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3.0


func _icon(ci: CanvasItem, kind: String, c: Vector2) -> void:
	match kind:
		"coin":
			ci.draw_circle(c, 12, UI.GOLD)
			ci.draw_string(UI.bold_font(), c + Vector2(-12, 8), "¢", HORIZONTAL_ALIGNMENT_CENTER, 24, 20, Color("6b4a00"))
		"shard":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(13, -2), c + Vector2(8, 13), c + Vector2(-8, 13), c + Vector2(-13, -2)]), Color("7fdcff"))
		"copies":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (15.0 if i % 2 == 0 else 6.5))
			ci.draw_colored_polygon(pts, UI.GOLD)
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
		if _fig != null:
			_fig.queue_redraw()
	_rays.queue_redraw()


func _draw_rays() -> void:
	var c := Vector2(360, (240 if _tall() else 470) if _victory != null else 560)
	var rot := _t * 0.26
	for i in 12:
		var a0 := rot + TAU * i / 12.0
		var a1 := a0 + deg_to_rad(11.0)
		var pts := PackedVector2Array([c, c + Vector2.from_angle(a0) * 340.0, c + Vector2.from_angle(a1) * 340.0])
		var cols := PackedColorArray([Color(_rcol, 0.24), Color(_rcol, 0.0), Color(_rcol, 0.0)])
		_rays.draw_polygon(pts, cols)
	_rays.draw_circle(c, 170.0, Color(_rcol, 0.08))
