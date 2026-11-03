class_name ForgeScreen
extends ItemScreen
## Forge (maquette X) : fusion de trois objets en un objet de rareté supérieure, et recyclage en éclats.

signal changed

var _tab := 0
var _tabs: Control
var _body: Control
var _sel: Array = []                  # identifiants choisis
var _threshold := 0                   # recyclage : rareté maximale sélectionnée par le raccourci
var _grid_scroll: ScrollContainer
var _grid: Control
var _go: Button
var _auto: Button
var _gpress := Vector2.ZERO
var _gdown := false
var _small: Array = []


func _init() -> void:
	super._init("Forge")
	_tabs = canvas(Vector2(32, 138), Vector2(656, 72), _draw_tabs)
	_tabs.gui_input.connect(func(ev: InputEvent):
		if tap(ev):
			var i := clampi(int(ev.position.x / (_tabs.size.x * 0.5)), 0, 1)
			if i != _tab:
				_tab = i
				_sel = []
				Sfx.play("click", -6.0)
				_refresh())
	_body = canvas(Vector2(0, 0), Vector2(720, 1280), _draw_body)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.gui_input.connect(_body_input)
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.position = Vector2(0, 330)
	_grid_scroll.size = Vector2(720, 640)
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	st.add_child(_grid_scroll)
	DragScroll.attach(_grid_scroll)
	_grid = Control.new()
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_grid_input)
	_grid_scroll.add_child(_grid)
	_auto = button("Auto", "ghost", Vector2(32, 1160), Vector2(240, 96), 28)
	_auto.pressed.connect(_auto_pick)
	_go = button("Fusionner", "main", Vector2(288, 1160), Vector2(400, 96), 32)
	_go.pressed.connect(_do)
	_refresh()


func _free_items() -> Array:
	return Game.items.filter(func(it): return it.on == "" and not it.locked)


func _refresh() -> void:
	_sel = _sel.filter(func(id): return not Game.item_by_id(int(id)).is_empty())
	_grid_scroll.visible = _tab == 1
	_auto.text = "Auto" if _tab == 0 else "Tout cocher"
	_go.text = "Fusionner" if _tab == 0 else "Recycler"
	_go.position = Vector2(288, 1160)
	_go.size = Vector2(400, 96)
	if _tab == 1:
		var items := _free_items()
		_grid.custom_minimum_size = Vector2(720, 12.0 + ceili(float(items.size()) / 4.0) * 156.0 + 20.0)
	_grid.queue_redraw()
	_tabs.queue_redraw()
	_body.mouse_filter = Control.MOUSE_FILTER_STOP if _tab == 0 else Control.MOUSE_FILTER_IGNORE
	_body.queue_redraw()
	var ok := false
	if _tab == 0:
		ok = _valid_fusion()
	else:
		ok = not _sel.is_empty()
	_go.disabled = not ok


func _valid_fusion() -> bool:
	if _sel.size() != 3:
		return false
	var a := Game.item_by_id(int(_sel[0]))
	if a.is_empty() or a.rarity == "ultime":
		return false
	for id in _sel:
		var it := Game.item_by_id(int(id))
		if it.is_empty() or it.slot != a.slot or it.rarity != a.rarity:
			return false
	return Game.credits >= Items.fuse_cost(Items.RARITIES[Items.rarity_index(a.rarity) + 1])


## Groupes de trois objets ou plus (même emplacement, même rareté), les plus rares d'abord.
func _fusion_groups() -> Array:
	var groups := {}
	for it in _free_items():
		if it.rarity == "ultime":
			continue
		var k := "%s|%s" % [it.slot, it.rarity]
		if not groups.has(k):
			groups[k] = []
		groups[k].append(it)
	var out: Array = []
	for k in groups:
		out.append(groups[k])
	out.sort_custom(func(a, b): return (a.size() >= 3 and b.size() < 3) or ((a.size() >= 3) == (b.size() >= 3) and Items.rarity_index(a[0].rarity) > Items.rarity_index(b[0].rarity)))
	return out


func _auto_pick() -> void:
	if _tab == 0:
		for g in _fusion_groups():
			if g.size() >= 3:
				g.sort_custom(func(a, b): return int(a.level) < int(b.level))
				_sel = [int(g[0].id), int(g[1].id), int(g[2].id)]
				break
	else:
		_sel = []
		var lim := Items.rarity_index("rare")
		for it in _free_items():
			if Items.rarity_index(it.rarity) <= (0 if _threshold == 0 else (1 if _threshold == 1 else lim)):
				_sel.append(int(it.id))
		_threshold = (_threshold + 1) % 3
	_refresh()


func _do() -> void:
	if _tab == 0:
		var out: Dictionary = Game.fuse_items(_sel)
		if out.is_empty():
			return
		Sfx.play("chest")
		_sel = []
	else:
		var res: Dictionary = Game.recycle_items(_sel)
		Sfx.play("coin")
		_sel = []
		if int(res.count) > 0:
			pass
	Game.save_game()
	changed.emit()
	_refresh()


func _draw_tabs(c: Control) -> void:
	c.draw_style_box(UI.box(UI.PANEL2, Color(0, 0, 0, 0), 28, 0), Rect2(Vector2.ZERO, c.size))
	var w := (c.size.x - 12.0) * 0.5
	for i in 2:
		var r := Rect2(6.0 + i * w, 6, w, 60)
		var on: bool = i == _tab
		if on:
			c.draw_style_box(UI.box(UI.ACCENT, Color(0, 0, 0, 0), 20, 0), r)
		c.draw_string(UI.bold_font(), Vector2(r.position.x, 46), ["Fusion", "Recyclage"][i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, UI.DARK if on else UI.MUTED)


func _small_rect(i: int) -> Rect2:
	return Rect2(32.0 + i * 104.0, 968, 92, 92)


func _body_input(ev: InputEvent) -> void:
	if not tap(ev) or _tab != 0:
		return
	var pos: Vector2 = ev.position
	for i in _small.size():
		if _small_rect(i).has_point(pos):
			var id: int = int(_small[i].id)
			if _sel.has(id):
				_sel.erase(id)
			else:
				var first: Dictionary = Game.item_by_id(int(_sel[0])) if not _sel.is_empty() else {}
				if not first.is_empty() and (first.slot != _small[i].slot or first.rarity != _small[i].rarity):
					_sel = []
				if _sel.size() < 3:
					_sel.append(id)
			Sfx.play("click", -8.0)
			_refresh()
			return


func _draw_body(c: Control) -> void:
	var f := ThemeDB.fallback_font
	var fb := UI.bold_font()
	if _tab == 1:
		_draw_recycle(c)
		return
	c.draw_string(f, Vector2(32, 262), "Trois objets de même emplacement et même rareté", HORIZONTAL_ALIGNMENT_LEFT, 656, 22, UI.MUTED)
	c.draw_string(f, Vector2(32, 292), "donnent un objet de rareté supérieure.", HORIZONTAL_ALIGNMENT_LEFT, 656, 22, UI.MUTED)
	var first: Dictionary = Game.item_by_id(int(_sel[0])) if not _sel.is_empty() else {}
	for i in 3:
		var r := Rect2(124.0 + i * 164.0, 320, 144, 144)
		if i < _sel.size():
			ItemUI.tile(c, r, Game.item_by_id(int(_sel[i])), true)
		else:
			ItemUI.empty(c, r)
	var k := 1.0 + 0.1 * sin(_t * 5.0)
	c.draw_string(f, Vector2(0, 520 + 4.0 * k), "↓", HORIZONTAL_ALIGNMENT_CENTER, 720, 44, UI.ACCENT)
	var rr := Rect2(256, 535, 208, 208)
	var nr := ""
	if not first.is_empty() and first.rarity != "ultime":
		nr = Items.RARITIES[Items.rarity_index(first.rarity) + 1]
	if nr != "" and _sel.size() == 3:
		var col := ItemUI.color(nr)
		c.draw_circle(rr.position + rr.size * 0.5, 130.0, Color(col.r, col.g, col.b, 0.12))
		ItemUI.tile(c, rr, {"slot": first.slot, "rarity": nr, "level": 1}, false)
	else:
		ItemUI.empty(c, rr)
	var lab := "Choisis trois objets" if nr == "" else "%s %s" % [String(Items.SLOT_NAMES[first.slot]).to_upper(), String(Data.RARITY_NAMES[nr]).to_upper()]
	c.draw_string(fb, Vector2(0, 778), lab, HORIZONTAL_ALIGNMENT_CENTER, 720, 28, ItemUI.color(nr) if nr != "" else UI.MUTED)
	c.draw_string(f, Vector2(0, 810), "Statistiques tirées au sort · niveau moyen conservé", HORIZONTAL_ALIGNMENT_CENTER, 720, 22, UI.MUTED)
	var cost := Items.fuse_cost(nr) if nr != "" else 0
	var w1 := 200.0
	var w2 := 230.0
	var x0 := (720.0 - w1 - w2 - 12.0) * 0.5
	c.draw_style_box(UI.box(UI.HUD, UI.LINE, 24, 0), Rect2(x0, 838, w1, 48))
	c.draw_string(fb, Vector2(x0 + 22, 871), "Coût", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	c.draw_texture(UI.icon("coin"), Vector2(x0 + 96, 848))
	c.draw_string(fb, Vector2(x0 + 134, 871), UI.num(cost) if cost > 0 else "–", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE if Game.credits >= cost else UI.RED)
	c.draw_style_box(UI.box(UI.HUD, UI.LINE, 24, 0), Rect2(x0 + w1 + 12.0, 838, w2, 48))
	c.draw_string(fb, Vector2(x0 + w1 + 34.0, 871), "+1 bonus garanti", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var msg := "Choisis les objets : ceux du même type sont proposés en premier."
	var msg_col := UI.MUTED
	if _sel.size() == 3 and not _valid_fusion():
		msg = "Fusion impossible : il faut trois objets de même emplacement et même rareté, et assez de crédits."
		msg_col = UI.RED
	elif not _sel.is_empty() and _sel.size() < 3:
		msg = "Fusion impossible pour l'instant : il faut trois objets de même emplacement et même rareté. Tu en as %d." % _sel.size()
	c.draw_string(f, Vector2(32, 936), msg, HORIZONTAL_ALIGNMENT_LEFT, 656, 22, msg_col)
	# objets proposés : les groupes de trois ou plus d'abord
	_small = []
	for g in _fusion_groups():
		for it in g:
			_small.append(it)
	_small = _small.slice(0, 6)
	for i in _small.size():
		var r2 := _small_rect(i)
		ItemUI.tile(c, r2, _small[i], true, not _sel.has(int(_small[i].id)) and _sel.size() > 0 and (first.slot != _small[i].slot or first.rarity != _small[i].rarity))
		if _sel.has(int(_small[i].id)):
			c.draw_arc(r2.position + r2.size * 0.5, 54.0, 0, TAU, 40, UI.ACCENT, 3.0, true)
	if _small.is_empty():
		c.draw_string(f, Vector2(0, 1020), "Aucun objet libre à fusionner pour l'instant.", HORIZONTAL_ALIGNMENT_CENTER, 720, 24, UI.MUTED)


func _recycle_totals() -> Dictionary:
	var sh := 0
	var cr := 0
	for id in _sel:
		var it := Game.item_by_id(int(id))
		if not it.is_empty():
			sh += int(Items.RECYCLE_SHARDS[it.rarity])
			cr += Items.recycle_credits(it)
	return {"shards": sh, "credits": cr}


func _draw_recycle(c: Control) -> void:
	var f := ThemeDB.fallback_font
	var fb := UI.bold_font()
	c.draw_string(f, Vector2(32, 262), "Recycle les objets choisis en éclats de verre", HORIZONTAL_ALIGNMENT_LEFT, 656, 22, UI.MUTED)
	c.draw_string(f, Vector2(32, 292), "et en crédits. Les objets verrouillés sont protégés.", HORIZONTAL_ALIGNMENT_LEFT, 656, 22, UI.MUTED)
	var t := _recycle_totals()
	c.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 24, 0), Rect2(32, 984, 656, 150))
	c.draw_string(fb, Vector2(56, 1030), "Recyclage", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	c.draw_string(f, Vector2(0, 1028), "%d objet%s choisi%s" % [_sel.size(), "s" if _sel.size() > 1 else "", "s" if _sel.size() > 1 else ""], HORIZONTAL_ALIGNMENT_RIGHT, 664.0, 22, UI.MUTED)
	c.draw_style_box(UI.box(UI.HUD, UI.LINE, 24, 0), Rect2(56, 1056, 150, 48))
	c.draw_texture(UI.icon("shard"), Vector2(72, 1066))
	c.draw_string(fb, Vector2(110, 1090), "+%d" % int(t.shards), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	c.draw_style_box(UI.box(UI.HUD, UI.LINE, 24, 0), Rect2(222, 1056, 180, 48))
	c.draw_texture(UI.icon("coin"), Vector2(238, 1066))
	c.draw_string(fb, Vector2(276, 1090), "+%s" % UI.num(float(t.credits)), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)


func _cell(i: int) -> Rect2:
	return Rect2(32.0 + (i % 4) * 168.0, 12.0 + (i / 4) * 156.0, 140, 140)


func _draw_grid() -> void:
	var items := _free_items()
	for i in items.size():
		var r := _cell(i)
		ItemUI.tile(_grid, r, items[i], true, not _sel.has(int(items[i].id)))
		if _sel.has(int(items[i].id)):
			ItemUI.dot(_grid, r.position + Vector2(r.size.x - 4.0, 4.0), "✓", UI.ACCENT)


func _grid_input(ev: InputEvent) -> void:
	var pos := Vector2.ZERO
	var pressed := false
	var released := false
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
		pressed = ev.pressed
		released = not ev.pressed
	elif ev is InputEventScreenTouch:
		pos = ev.position
		pressed = ev.pressed
		released = not ev.pressed
	else:
		return
	if pressed:
		_gpress = pos
		_gdown = true
	elif released and _gdown:
		_gdown = false
		if pos.distance_to(_gpress) > 14.0:
			return
		var items := _free_items()
		for i in items.size():
			if _cell(i).has_point(pos):
				var id: int = int(items[i].id)
				if _sel.has(id):
					_sel.erase(id)
				else:
					_sel.append(id)
				Sfx.play("click", -8.0)
				_refresh()
				return


func _process(delta: float) -> void:
	_t += delta
	if _tab == 0:
		_body.queue_redraw()
