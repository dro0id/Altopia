class_name ItemBoosterView
extends Control
## Onglet « Objets » du recrutement (maquette AD/AE) : caisse d'équipement, garanties, derniers objets, ouverture ×1 et ×10, résultat.

const Data = preload("res://scripts/data.gd")

signal inventory_requested
signal equipped

var _t := 0.0
var _ten: Button
var _one: Button
var _busy := false
var _results: Control
var _res: Array = []
var _reveal := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(720, 1120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_one = _pack_button("Ouvrir ×1", Data.ITEM_PACK_COST, "", 32.0, "main")
	_one.pressed.connect(_pull.bind(1))
	_ten = _pack_button("Ouvrir ×10", Data.ITEM_PACK_COST_10, " · 1 offert", 368.0, "gold")
	_ten.pressed.connect(_pull.bind(10))


func _pack_button(title: String, cost: int, extra: String, x: float, kind: String) -> Button:
	var b := UI.button(self, "", 30, kind)
	b.position = Vector2(x, 988)
	b.size = Vector2(320, 112)
	b.custom_minimum_size = Vector2(0, 112)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := UI.label(v, title, 30, UI.DARK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var ic := TextureRect.new()
	ic.texture = UI.icon("itoken")
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var s := UI.label(row, "%d%s" % [cost, extra], 24, UI.DARK, true)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_one.disabled = Game.item_tokens < Data.ITEM_PACK_COST or _busy
	_ten.disabled = Game.item_tokens < Data.ITEM_PACK_COST_10 or _busy
	if _results != null:
		var before := int(_reveal)
		_reveal = minf(_reveal + delta * 7.0, float(_res.size()))
		if int(_reveal) != before:
			var it: Dictionary = _res[int(_reveal) - 1].item
			Sfx.play("star" if Items.rarity_index(it.rarity) < 3 else "chest", -3.0, 0.9 + 0.08 * float(Items.rarity_index(it.rarity)))
		_results.queue_redraw()
	queue_redraw()


func _spaced_center(font: Font, y: float, txt: String, fs: int, col: Color, gap: float) -> void:
	var tw := 0.0
	for ch in txt:
		tw += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + gap
	var x := 360.0 - tw * 0.5
	for ch in txt:
		draw_string(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + gap


func _draw() -> void:
	draw_set_transform(Vector2(0, -32), 0.0, Vector2.ONE)
	var fb := UI.bold_font()
	var f := ThemeDB.fallback_font
	var ctr := Vector2(360, 470)
	for i in 14:
		draw_circle(ctr, 330.0 - i * 20.0, Color(1.0, 0.69, 0.26, 0.018))
	# anneau pointillé qui tourne
	for i in 36:
		var a := TAU * i / 36.0 + _t * 0.15
		draw_arc(ctr, 230.0, a, a + TAU / 72.0, 6, Color(1.0, 0.69, 0.26, 0.45), 4.0, true)
	var bob := sin(_t * 2.6) * 8.0
	var cr := Rect2(ctr + Vector2(-120, -150 + bob), Vector2(240, 300))
	UI.draw_gradient_box(self, cr, 36.0, Color("ffe2a8"), Color("5a3000"), Color("ffd78a"), 3.0)
	ItemUI.slot_icon(self, "module", cr.get_center(), 128.0, Color("3a2000"))
	draw_string(f, Vector2(0, 776), "Caisse d'équipement · %d jetons d'objet l'ouverture" % Data.ITEM_PACK_COST, HORIZONTAL_ALIGNMENT_CENTER, 720, 22, UI.MUTED)
	# garanties
	var cols := [Color("b388ff"), Color("ffb142")]
	var names := ["Épique garanti", "Légendaire garanti"]
	var vals := [int(Game.item_pack_pity.epic), int(Game.item_pack_pity.leg)]
	var maxs := [Data.ITEM_PITY_EPIC, Data.ITEM_PITY_LEG]
	for i in 2:
		var x := 32.0 + i * 344.0
		draw_string(fb, Vector2(x, 828), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, cols[i])
		draw_string(f, Vector2(x, 828), "%d/%d" % [vals[i], maxs[i]], HORIZONTAL_ALIGNMENT_RIGHT, 312, 22, UI.MUTED)
		draw_style_box(UI.box(UI.LINE2, Color(0, 0, 0, 0), 8, 0), Rect2(x, 842, 312, 16))
		var w := 312.0 * clampf(float(vals[i]) / float(maxs[i]), 0.0, 1.0)
		if w > 0.0:
			draw_style_box(UI.box(cols[i], Color(0, 0, 0, 0), 8, 0), Rect2(x, 842, maxf(w, 16.0), 16))
	# derniers objets
	draw_string(f, Vector2(32, 928), "Derniers", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)
	for i in 6:
		var r := Rect2(140.0 + i * 92.0, 884, 76, 76)
		if i < Game.item_pulls.size():
			ItemUI.tile(self, r, {"slot": Game.item_pulls[i].slot, "rarity": Game.item_pulls[i].rarity, "level": 1}, false)
		else:
			draw_style_box(UI.box(UI.PANEL2, UI.LINE2, 14, 0), r)
	draw_string(f, Vector2(0, 996), "Jetons d'objet : gros boss, quêtes du jour, boutique", HORIZONTAL_ALIGNMENT_CENTER, 720, 22, UI.MUTED)


# ---------------------------------------------------------------- tirages

func _pull(count: int) -> void:
	if _busy:
		return
	var res: Array = Game.open_item_packs(count)
	if res.is_empty():
		return
	Game.save_game()
	Sfx.play("chest", -2.0)
	_show_results(res, count)


func _best(res: Array) -> Dictionary:
	var best: Dictionary = res[0].item
	for r in res:
		var it: Dictionary = r.item
		if Items.rarity_index(it.rarity) > Items.rarity_index(best.rarity) or (it.rarity == best.rarity and Items.power(it) > Items.power(best)):
			best = it
	return best


func _show_results(res: Array, count: int) -> void:
	_busy = true
	_res = res
	_reveal = 0.0
	if _results != null:
		_results.queue_free()
	_results = Control.new()
	_results.size = Vector2(720, 1120)
	_results.mouse_filter = Control.MOUSE_FILTER_STOP
	_results.z_index = 20
	add_child(_results)
	var best := _best(res)
	var bg: Dictionary = Game.best_hero_for(best)
	var cost: int = Data.ITEM_PACK_COST_10 if count == 10 else Data.ITEM_PACK_COST
	_results.draw.connect(func(): _draw_results(best, bg, count))
	var eq := UI.button(_results, "Équiper au mieux", 32, "main")
	eq.position = Vector2(32, 912)
	eq.size = Vector2(656, 96)
	eq.custom_minimum_size = Vector2(0, 96)
	eq.pressed.connect(func():
		var n: int = Game.equip_best_all()
		Game.save_game()
		Sfx.play("chest" if n > 0 else "click", -4.0)
		equipped.emit()
		_close_results())
	var inv := UI.button(_results, "Voir l'inventaire", 28, "ghost")
	inv.position = Vector2(32, 1024)
	inv.size = Vector2(320, 88)
	inv.custom_minimum_size = Vector2(0, 88)
	inv.pressed.connect(func():
		_close_results()
		inventory_requested.emit())
	var again := UI.button(_results, "", 28, "gold")
	again.position = Vector2(368, 1024)
	again.size = Vector2(320, 88)
	again.custom_minimum_size = Vector2(0, 88)
	again.text = "Encore ×%d · %d" % [count, cost]
	again.icon = UI.icon("itoken")
	again.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	again.disabled = Game.item_tokens < cost
	again.pressed.connect(func():
		_close_results()
		_pull.call_deferred(count))


func _close_results() -> void:
	_busy = false
	if _results != null:
		_results.queue_free()
		_results = null


func _draw_results(best: Dictionary, bg: Dictionary, count: int) -> void:
	var c := _results
	var fb := UI.bold_font()
	var f := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, c.size), UI.BG)
	var gold := Color("ffb142")
	c.draw_string(fb, Vector2(0, 74), "OUVERTURE ×%d" % count, HORIZONTAL_ALIGNMENT_CENTER, 720, 26, gold)
	c.draw_string(f, Vector2(0, 112), "Puissance selon ton meilleur étage (%d)" % Game.best_stage, HORIZONTAL_ALIGNMENT_CENTER, 720, 22, UI.MUTED)
	var n := _res.size()
	var cols := mini(n, 5)
	var x0 := 360.0 - (cols * 112.0 + (cols - 1) * 16.0) * 0.5
	for i in mini(n, int(_reveal) + (1 if int(_reveal) < n else 0)):
		var it: Dictionary = _res[i].item
		var r := Rect2(x0 + (i % 5) * 128.0, 150.0 + (i / 5) * 128.0, 112, 112)
		var grow := 1.0
		if i == int(_reveal):
			grow = 0.6 + 0.4 * (_reveal - float(i))
		var rr := Rect2(r.get_center() - r.size * 0.5 * grow, r.size * grow)
		ItemUI.tile(c, rr, it, false)
		if i < int(_reveal):
			if Game.best_hero_for(it).gain > 0.0:
				ItemUI.dot(c, r.position + Vector2(r.size.x - 6.0, 6.0), "▲")
			if _res[i].status != "added":
				c.draw_string(fb, r.position + Vector2(0, r.size.y + 22.0), "réserve" if _res[i].status == "stash" else "recyclé", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, UI.MUTED)
	var y := 150.0 + (((n - 1) / 5) + 1) * 128.0 + 16.0
	var rc := ItemUI.color(best.rarity)
	UI.draw_gradient_box(c, Rect2(32, y, 656, 150), 28.0, Color(rc.r * 0.3, rc.g * 0.3, rc.b * 0.3), UI.PANEL, rc, 3.0)
	ItemUI.tile(c, Rect2(52, y + 20, 110, 110), best, false)
	c.draw_string(fb, Vector2(182, y + 46), "MEILLEUR OBJET", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, rc)
	c.draw_string(fb, Vector2(182, y + 84), String(best.name), HORIZONTAL_ALIGNMENT_LEFT, 360, 30, rc)
	c.draw_string(f, Vector2(182, y + 118), Items.summary(best), HORIZONTAL_ALIGNMENT_LEFT, 490, 18, UI.MUTED)
	if bg.hero != "" and bg.gain > 0.0:
		c.draw_string(fb, Vector2(500, y + 84), "▲ +%s" % UI.num(bg.gain), HORIZONTAL_ALIGNMENT_RIGHT, 170, 28, UI.GREEN)
	y += 170.0
	# bilan par rareté
	var counts := {}
	for r in _res:
		counts[r.item.rarity] = int(counts.get(r.item.rarity, 0)) + 1
	var x := 32.0
	for k in range(Items.RARITIES.size() - 1, -1, -1):
		var rar: String = Items.RARITIES[k]
		if not counts.has(rar):
			continue
		var col := ItemUI.color(rar)
		var txt := "%d %s" % [counts[rar], String(Data.RARITY_NAMES[rar]).to_lower()]
		var w := fb.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 32.0
		var sb := UI.box(Color(0.05, 0.08, 0.19, 0.8), Color(col.r, col.g, col.b, 0.6), 22, 0)
		sb.set_border_width_all(2)
		c.draw_style_box(sb, Rect2(x, y, w, 44))
		c.draw_string(fb, Vector2(x + 16, y + 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		x += w + 10.0
	y += 64.0
	c.draw_style_box(UI.box(UI.PANEL2, Color(0, 0, 0, 0), 24, 0), Rect2(32, y, 656, 92))
	c.draw_string(f, Vector2(52, y + 36), "Inventaire %d / %d" % [Game.inventory_count(), Items.INVENTORY_MAX], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e8eefc"))
	var note := "S'il est plein, le surplus part en réserve." if Game.stash.is_empty() else "%d objet(s) en réserve : libère de la place pour les récupérer." % Game.stash.size()
	c.draw_string(f, Vector2(52, y + 70), note, HORIZONTAL_ALIGNMENT_LEFT, 616, 20, UI.MUTED)
