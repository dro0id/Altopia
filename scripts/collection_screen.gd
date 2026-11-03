class_name CollectionScreen
extends Overlay
## Collection (maquette F) : formation en 3 + 2 emplacements (glisser pour échanger), synergies, filtres et grille des héros.

signal squad_changed
signal hero_requested(id: String)
signal item_requested(id: int)
signal forge_requested

const FILTERS := ["Tous", "Rareté", "Rôle", "Espèce"]
const PREVIEW := 7                  # nombre de cartes montrées avant la case « + N »

var _form: Control
var _grid: Control
var _stage: Control
var _scroll: ScrollContainer
var _chip_btns: Array = []
var _tokens_chip: HudButton
var _title_sub: Label
var _fkind := 0                     # 0 tous, 1 rareté, 2 rôle, 3 espèce
var _fval := 0
var _expanded := false
var _cells: Array = []              # ids affichés dans la grille
var _drag_slot := -1
var _drag_pos := Vector2.ZERO
var _press := Vector2.ZERO
var _t := 0.0
var _tab := 0
var _hero_nodes: Array = []
var _items_view: ItemsView
var _sets_view: SetsView
var _tabs: Control

const TAB_NAMES := ["Héros", "Objets", "Ensembles"]


func _init() -> void:
	super._init(720.0)
	panel.custom_minimum_size = Vector2(720, 1152)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 0))
	box.add_theme_constant_override("separation", 0)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(720, 1152)
	box.add_child(stage)
	_stage = stage
	var t := UI.label(stage, "Héros", 36, Color.WHITE, true)
	t.position = Vector2(32, 18)
	_title_sub = UI.label(stage, "", 24, UI.MUTED, true)
	_title_sub.position = Vector2(32.0 + UI.bold_font().get_string_size("Héros", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x + 12.0, 28)
	_tokens_chip = HudButton.new()
	_tokens_chip.icon = "token"
	_tokens_chip.font_size = 26
	_tokens_chip.tappable = false
	stage.add_child(_tokens_chip)
	# formation
	_form = Control.new()
	_form.position = Vector2(24, 174)
	_form.size = Vector2(672, 394)
	_form.draw.connect(_draw_form)
	_form.gui_input.connect(_form_input)
	stage.add_child(_form)
	# filtres
	var x := 24.0
	for i in FILTERS.size():
		var b := HudButton.new()
		b.font_size = 26
		b.radius = 25.0
		b.size = Vector2(UI.bold_font().get_string_size(FILTERS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 56.0 + (20.0 if i == 0 else 0.0), 50)
		b.position = Vector2(x, 584)
		x += b.size.x + 12.0
		var idx := i
		b.pressed.connect(func(): _on_filter(idx))
		stage.add_child(b)
		_chip_btns.append(b)
	# grille
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 642)
	_scroll.size = Vector2(720, 510)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	stage.add_child(_scroll)
	DragScroll.attach(_scroll)
	_grid = Control.new()
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_grid_input)
	_scroll.add_child(_grid)
	_rebuild()
	# onglets Héros / Objets / Ensembles
	_tabs = Control.new()
	_tabs.position = Vector2(32, 90)
	_tabs.size = Vector2(656, 76)
	_tabs.draw.connect(_draw_tabs)
	_tabs.gui_input.connect(_tabs_input)
	stage.add_child(_tabs)
	_items_view = ItemsView.new()
	_items_view.item_requested.connect(func(id: int): item_requested.emit(id))
	_items_view.forge_requested.connect(func(): forge_requested.emit())
	_items_view.changed.connect(func(): squad_changed.emit())
	stage.add_child(_items_view)
	_sets_view = SetsView.new()
	stage.add_child(_sets_view)
	for n in [_form, _scroll] + _chip_btns:
		_hero_nodes.append(n)
	_show_tab(0)


func show_tab(i: int) -> void:
	_show_tab(i)


func _show_tab(i: int) -> void:
	_tab = i
	for n in _hero_nodes:
		n.visible = i == 0
	_title_sub.visible = i == 0
	_items_view.visible = i == 1
	_sets_view.visible = i == 2
	if i == 1:
		_items_view.refresh()
	_tabs.queue_redraw()


func _draw_tabs() -> void:
	_tabs.draw_style_box(UI.box(UI.PANEL2, Color(0, 0, 0, 0), 28, 0), Rect2(Vector2.ZERO, _tabs.size))
	var w := (_tabs.size.x - 12.0) / 3.0
	for i in 3:
		var r := Rect2(6.0 + i * w, 6, w, 64)
		var on: bool = i == _tab
		if on:
			_tabs.draw_style_box(UI.box(UI.ACCENT, Color(0, 0, 0, 0), 20, 0), r)
		var col := UI.DARK if on else UI.MUTED
		var label: String = TAB_NAMES[i]
		_tabs.draw_string(UI.bold_font(), Vector2(r.position.x, 48), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, col)


func _tabs_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
		var i := clampi(int(ev.position.x / (_tabs.size.x / 3.0)), 0, 2)
		if i != _tab:
			Sfx.play("click", -6.0)
			_show_tab(i)


# ---------------------------------------------------------------- données

func _on_filter(i: int) -> void:
	if i == 0:
		_fkind = 0
		_fval = 0
	elif _fkind == i:
		_fval += 1
		if _fval >= _values(i).size():
			_fkind = 0
			_fval = 0
	else:
		_fkind = i
		_fval = 0
	_rebuild()


func _values(kind: int) -> Array:
	match kind:
		1:
			return Data.RARITIES_HERO
		2:
			return Data.ROLE_NAMES.keys()
		3:
			return Data.SPECIES_NAMES.keys()
	return []


func _value_name(kind: int, v) -> String:
	match kind:
		1:
			return Data.RARITY_NAMES_HERO[v]
		2:
			return Data.ROLE_NAMES[v]
		3:
			return Data.SPECIES_NAMES[v]
	return ""


func _rebuild() -> void:
	_title_sub.text = "%d / %d" % [Game.owned.size(), Data.ALL_HEROES.size()]
	_tokens_chip.set_texts(str(Game.tokens))
	_tokens_chip.fit_chip()
	_tokens_chip.position = Vector2(688.0 - _tokens_chip.size.x, 24)
	var ids: Array = []
	for id in Data.ALL_HEROES:
		var h: Dictionary = Data.HEROES[id]
		if _fkind == 1 and h.rarity != _values(1)[_fval]:
			continue
		if _fkind == 2 and h.role != _values(2)[_fval]:
			continue
		if _fkind == 3 and h.species != _values(3)[_fval]:
			continue
		ids.append(id)
	ids.sort_custom(func(a, b):
		var oa := Game.is_owned(a)
		var ob := Game.is_owned(b)
		if oa != ob:
			return oa
		if oa:
			if int(Game.hero_stars[a]) != int(Game.hero_stars[b]):
				return int(Game.hero_stars[a]) > int(Game.hero_stars[b])
			return int(Game.levels[a]) > int(Game.levels[b])
		return Data.RARITIES_HERO.find(Data.HEROES[a].rarity) > Data.RARITIES_HERO.find(Data.HEROES[b].rarity))
	_cells = ids
	var rows := ceili(float(_shown_count() + (1 if _has_more() else 0)) / 4.0)
	_grid.custom_minimum_size = Vector2(720, 12.0 + rows * 196.0 + 20.0)
	for i in FILTERS.size():
		var b: HudButton = _chip_btns[i]
		var on: bool = (i == 0 and _fkind == 0) or (i > 0 and _fkind == i)
		var label: String = FILTERS[i]
		if i > 0 and _fkind == i:
			label = _value_name(i, _values(i)[_fval])
		b.set_texts(label)
		b.fill = UI.ACCENT if on else UI.HUD
		b.border = UI.ACCENT if on else UI.LINE
		b.text_color = UI.DARK if on else UI.TEXT
		b.bold = true
		b.queue_redraw()
	_form.queue_redraw()
	_grid.queue_redraw()


func _has_more() -> bool:
	return not _expanded and _cells.size() > PREVIEW


func _shown_count() -> int:
	return _cells.size() if _expanded else mini(_cells.size(), PREVIEW)


func _process(delta: float) -> void:
	_t += delta
	_form.queue_redraw()
	_grid.queue_redraw()
	_tokens_chip.set_texts(str(Game.tokens))


# ---------------------------------------------------------------- formation

func _slot_rect(i: int) -> Rect2:
	# trois emplacements devant, deux derrière ; 108 × 124, écart 20 px
	if i < 3:
		return Rect2(336.0 - 162.0 + i * 128.0 - 24.0, 54, 108, 124)
	return Rect2(336.0 - 64.0 + (i - 3) * 128.0 - 24.0, 190, 108, 124)


func _draw_form() -> void:
	_form.draw_style_box(UI.box(UI.PANEL2, UI.LINE, 28, 0), Rect2(Vector2.ZERO, _form.size))
	var f := ThemeDB.fallback_font
	_form.draw_string(f, Vector2(22, 44), "ESCOUADE · glisse pour échanger", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)
	for i in Data.SQUAD_SIZE:
		var r := _slot_rect(i)
		var id: String = Game.squad[i]
		var hot := _drag_slot >= 0 and r.has_point(_drag_pos) and i != _drag_slot
		_form.draw_style_box(UI.box(Color("0d1530"), Color(0.31, 0.85, 1.0, 0.9 if hot else 0.53), 20, 0), r)
		_dashed_box(_form, r)
		if id != "" and not (_drag_slot == i):
			UI.portrait(_form, Data.HEROES[id], r.position + Vector2(54, 54), 46.0, _t)
		_form.draw_string(f, Vector2(r.position.x, r.end.y - 8), "Avant" if i < 3 else "Arrière", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, UI.MUTED)
	# synergies
	var x := 22.0
	for s in Game.synergy().list:
		var txt := "%s %s" % [s.name, String(s.desc).replace(" ATQ", "").replace(" PV", "").replace(" DÉF", "")]
		var col: Color = UI.GREEN if String(s.name).find("×") >= 0 and not String(s.name).begins_with("Rempart") else Color("b388ff")
		var w := UI.bold_font().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 44.0
		if x + w > _form.size.x - 20.0:
			break
		_form.draw_style_box(UI.box(Color(col.r, col.g, col.b, 0.08), Color(col.r, col.g, col.b, 0.4), 25, 0), Rect2(x, 328, w, 50))
		_form.draw_string(UI.bold_font(), Vector2(x + 22, 361), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
		x += w + 12.0
	# héros tenu au doigt
	if _drag_slot >= 0 and Game.squad[_drag_slot] != "":
		UI.portrait(_form, Data.HEROES[Game.squad[_drag_slot]], _drag_pos, 52.0, _t)


func _dashed_box(ci: Control, r: Rect2) -> void:
	var col := Color(0.31, 0.85, 1.0, 0.53)
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 12.0)
		for k in range(0, n, 2):
			ci.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 2.0)


func _slot_at(p: Vector2) -> int:
	for i in Data.SQUAD_SIZE:
		if _slot_rect(i).grow(8).has_point(p):
			return i
	return -1


func _form_input(ev: InputEvent) -> void:
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var move := false
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
		down = ev.pressed
		up = not ev.pressed
	elif ev is InputEventScreenTouch:
		pos = ev.position
		down = ev.pressed
		up = not ev.pressed
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = ev.position
		move = true
	elif ev is InputEventScreenDrag:
		pos = ev.position
		move = true
	else:
		return
	if down:
		_press = pos
		_drag_slot = _slot_at(pos)
		_drag_pos = pos
		if _drag_slot >= 0 and Game.squad[_drag_slot] == "":
			_drag_slot = -1
	elif move and _drag_slot >= 0:
		_drag_pos = pos
	elif up and _drag_slot >= 0:
		var target := _slot_at(pos)
		var from := _drag_slot
		_drag_slot = -1
		if pos.distance_to(_press) < 16.0:
			hero_requested.emit(Game.squad[from])
		elif target >= 0 and target != from:
			var a: String = Game.squad[from]
			var b: String = Game.squad[target]
			Game.squad[from] = b
			Game.squad[target] = a
			Game.save_game()
			Sfx.play("click", -4.0)
			squad_changed.emit()
		_rebuild()


# ---------------------------------------------------------------- grille

func _cell_rect(i: int) -> Rect2:
	return Rect2(24.0 + (i % 4) * 172.0, 12.0 + (i / 4) * 196.0, 160, 184)


func _draw_grid() -> void:
	var f := ThemeDB.fallback_font
	for i in _shown_count():
		var id: String = _cells[i]
		var h: Dictionary = Data.HEROES[id]
		var have := Game.is_owned(id)
		var r := _cell_rect(i)
		var rc: Color = Data.RARITY_COLORS[h.rarity]
		var sb := UI.box(UI.PANEL, rc if have else Color("2b3a6b"), 20, 0)
		sb.set_border_width_all(3 if have else 2)
		_grid.draw_style_box(sb, r)
		var c := r.position + Vector2(80, 62)
		UI.portrait(_grid, h, c, 48.0, _t)
		if not have:
			_grid.draw_circle(c, 50.0, Color(0.04, 0.06, 0.12, 0.72))
		var nm: String = String(h.name).split(" ")[0]
		_grid.draw_string(UI.bold_font(), r.position + Vector2(0, 140), nm, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color.WHITE if have else UI.MUTED)
		var st: int = int(Game.hero_stars[id]) if have else 0
		_grid.draw_string(f, r.position + Vector2(0, 168), "★".repeat(st) + "☆".repeat(Data.MAX_STARS - st), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, UI.GOLD if have else Color(UI.GOLD, 0.35))
	if _has_more():
		var r := _cell_rect(PREVIEW)
		_grid.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 20, 0), r)
		_dashed_box_grid(r)
		_grid.draw_string(f, r.position + Vector2(0, 100), "+ %d" % (_cells.size() - PREVIEW), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, UI.MUTED)


func _dashed_box_grid(r: Rect2) -> void:
	var col := Color("2b3a6b")
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 12.0)
		for k in range(0, n, 2):
			_grid.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 3.0)


var _gpress := Vector2.ZERO
var _gdown := false


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
		for i in _shown_count():
			if _cell_rect(i).has_point(pos):
				hero_requested.emit(_cells[i])
				return
		if _has_more() and _cell_rect(PREVIEW).has_point(pos):
			_expanded = true
			_rebuild()
