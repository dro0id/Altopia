class_name CollectionScreen
extends Overlay
## Héros (maquette BC) : barre du haut (recherche, menu), segments Héros / Objets / Ensembles, puces de rôle, grille de cartes.
## La formation (glisser pour échanger) s'ouvre depuis le menu ⋮, dans une feuille du bas.

signal squad_changed
signal hero_requested(id: String)
signal item_requested(id: int)
signal forge_requested

const ROLE_CHIPS := [["Tous", ""], ["Tireurs", "dps"], ["Tanks", "tank"], ["Soigneurs", "healer"], ["Contrôle", "control"]]
const TAB_NAMES := ["Héros", "Objets", "Ensembles"]

var _stage: Control
var _bar: Control
var _seg: M3Seg
var _chips: M3Chips
var _scroll: ScrollContainer
var _grid: Control
var _info: Control
var _search: LineEdit
var _query := ""
var _role := ""
var _cells: Array = []
var _t := 0.0
var _tab := 0
var _hero_nodes: Array = []
var _items_view: ItemsView
var _sets_view: SetsView
var _sheet: Control
var _form: Control
var _drag_slot := -1
var _drag_pos := Vector2.ZERO
var _press := Vector2.ZERO
var _gpress := Vector2.ZERO
var _gdown := false
var _figs: Array = []


func _init() -> void:
	super._init(720.0)
	panel.custom_minimum_size = Vector2(720, (UI.H - 160.0))
	panel.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	dim.color = UI.BG
	set_backdrop(Color("58c98f"))
	box.add_theme_constant_override("separation", 0)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(720, (UI.H - 160.0))
	box.add_child(_stage)
	_bar = M3.top_bar(_stage, "Héros", Callable(), [["⌕", _toggle_search], ["⋮", _open_menu]])
	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher"
	_search.position = Vector2(24, 16)
	_search.size = Vector2(480, 80)
	_search.add_theme_font_size_override("font_size", M3.fs(30))
	_search.add_theme_stylebox_override("normal", UI.box(M3.S3, Color(0, 0, 0, 0), 40, 24))
	_search.add_theme_stylebox_override("focus", UI.box(M3.S3, UI.ACCENT, 40, 24))
	_search.visible = false
	_search.text_changed.connect(func(s: String):
		_query = s.strip_edges().to_lower()
		_rebuild()
		if _items_view.visible:
			_items_view.query = _query
			_items_view.refresh())
	_bar.add_child(_search)
	_seg = M3Seg.new(TAB_NAMES, 0)
	_seg.position = Vector2(32, 112)
	_seg.changed.connect(_show_tab)
	_stage.add_child(_seg)
	# onglet Héros
	var labels: Array = []
	for c in ROLE_CHIPS:
		labels.append(c[0])
	_chips = M3Chips.new(labels, 0)
	_chips.position = Vector2(32, 328)
	_chips.changed.connect(func(i: int):
		_role = ROLE_CHIPS[i][1]
		_rebuild())
	_stage.add_child(_chips)
	# escouade épinglée (maquette XG) : les cinq visages, la puissance, le nombre de héros possédés
	_info = Control.new()
	_info.position = Vector2(32, 196)
	_info.size = Vector2(656, 120)
	_info.mouse_filter = Control.MOUSE_FILTER_STOP
	_info.draw.connect(_draw_squad_row)
	_info.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev):
			var i := clampi(int((ev.position.x - 8.0) / 128.0), 0, Data.SQUAD_SIZE - 1)
			if Game.squad[i] != "":
				hero_requested.emit(Game.squad[i]))
	_stage.add_child(_info)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 416)
	_scroll.size = Vector2(720, (UI.H - 160.0) - 416.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_stage.add_child(_scroll)
	DragScroll.attach(_scroll)
	_grid = Control.new()
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_grid_input)
	_scroll.add_child(_grid)
	_hero_nodes = [_chips, _info, _scroll]
	_items_view = ItemsView.new()
	_items_view.item_requested.connect(func(id: int): item_requested.emit(id))
	_items_view.changed.connect(func(): squad_changed.emit())
	_stage.add_child(_items_view)
	_sets_view = SetsView.new()
	_stage.add_child(_sets_view)
	_stage.move_child(_bar, _stage.get_child_count() - 1)
	_rebuild()
	_show_tab(0)


func show_tab(i: int) -> void:
	_seg.sel = i
	_seg.queue_redraw()
	_show_tab(i)


func _show_tab(i: int) -> void:
	_tab = i
	for n in _hero_nodes:
		n.visible = i == 0
	_items_view.visible = i == 1
	_sets_view.visible = i == 2
	if i == 1:
		_items_view.query = _query
		_items_view.refresh()


func _toggle_search() -> void:
	_search.visible = not _search.visible
	(_bar.get_node("Title") as Label).visible = not _search.visible
	if _search.visible:
		_search.grab_focus()
	else:
		_search.text = ""
		_query = ""
		_items_view.query = ""
		_rebuild()
		_items_view.refresh()


func _open_menu() -> void:
	var unread: int = Game.bond_unread()
	M3.menu(_stage, Vector2(704, 96), [["Formation de l'escouade", _open_sheet], ["Liens d’équipage" + (" · %d nouvelle%s" % [unread, "s" if unread > 1 else ""] if unread > 0 else ""), func(): add_child(BondsScreen.new())], ["Forge", func(): forge_requested.emit()]])


# ---------------------------------------------------------------- grille

func _rebuild() -> void:
	var ids: Array = []
	for id in Data.ALL_HEROES:
		var h: Dictionary = Data.HEROES[id]
		if _role != "" and h.role != _role:
			continue
		if _query != "" and String(h.name).to_lower().find(_query) < 0:
			continue
		ids.append(id)
	var squad := Game.squad_ids()
	ids.sort_custom(func(a, b):
		var sa := squad.has(a)
		var sb := squad.has(b)
		if sa != sb:
			return sa
		var oa := Game.is_owned(a)
		var ob := Game.is_owned(b)
		if oa != ob:
			return oa
		if oa and int(Game.levels[a]) != int(Game.levels[b]):
			return int(Game.levels[a]) > int(Game.levels[b])
		return Data.RARITIES_HERO.find(Data.HEROES[a].rarity) > Data.RARITIES_HERO.find(Data.HEROES[b].rarity))
	_cells = ids
	var rows := ceili(float(_cells.size()) / float(COLS))
	_grid.custom_minimum_size = Vector2(720, rows * (CARD.y + 12.0) + 24.0)
	# héros en pied : un nœud par carte (comme sur la fiche)
	for f in _figs:
		f.queue_free()
	_figs = []
	for i in _cells.size():
		var id: String = _cells[i]
		var h: Dictionary = Data.HEROES[id]
		var r := _cell_rect(i)
		var fig := Node2D.new()
		fig.position = r.position + Vector2(r.size.x * 0.5, 176)
		fig.scale = Vector2(0.88, 0.88)
		if not Game.is_owned(id):
			fig.modulate = Color(0.05, 0.07, 0.14)       # ombre : à recruter
		fig.draw.connect(func(): Art.draw_hero(fig, h, {"t": _t}))
		_grid.add_child(fig)
		_figs.append(fig)
	_grid.queue_redraw()
	_info.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_grid.queue_redraw()
	for f in _figs:
		f.queue_redraw()
	if _form != null:
		_form.queue_redraw()


const COLS := 4
const CARD := Vector2(155, 248)


func _cell_rect(i: int) -> Rect2:
	return Rect2(32.0 + (i % COLS) * (CARD.x + 12.0), (i / COLS) * (CARD.y + 12.0), CARD.x, CARD.y)


## Rangée de l'escouade épinglée en haut de l'onglet (maquette XG).
func _draw_squad_row() -> void:
	var c := _info
	M3.glass_card(c, Rect2(Vector2.ZERO, c.size), false, 20.0)
	var owned := 0
	for id in Data.ALL_HEROES:
		if Game.is_owned(id):
			owned += 1
	for i in Data.SQUAD_SIZE:
		var id: String = Game.squad[i]
		var cc := Vector2(72 + i * 128.0, 60)
		if id == "":
			c.draw_circle(cc, 40, M3.S3)
			continue
		var h: Dictionary = Data.HEROES[id]
		M3.avatar(c, h, cc, 42.0, Data.RARITY_COLORS[h.rarity], _t)


func _draw_grid() -> void:
	var squad := Game.squad_ids()
	for i in _cells.size():
		var id: String = _cells[i]
		var h: Dictionary = Data.HEROES[id]
		var have := Game.is_owned(id)
		var r := _cell_rect(i)
		var rc: Color = Data.RARITY_COLORS[h.rarity]
		# carte : fond teinté par la rareté, liseré de la rareté si possédé
		M3.glass_card(_grid, r, false, 16.0)
		if have:
			_grid.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 170)), Color(rc, 0.16))
			_grid.draw_style_box(UI.box(Color(0, 0, 0, 0), Color(rc, 0.8), 14, 0), r)
		# rôle en haut à gauche, escouade en haut à droite
		_role_glyph(_grid, String(h.role), r.position + Vector2(22, 22), rc if have else UI.MUTED)
		if squad.has(id):
			var tag := Rect2(r.end.x - 62, r.position.y + 6, 56, 28)
			_grid.draw_style_box(UI.box(UI.ACCENT, Color(0, 0, 0, 0), 8, 0), tag)
			M3.text(_grid, tag.position + Vector2(0, 21), "ESC.", 18, Color("06101f"), true, tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		# bas de carte : nom, étoiles et niveau
		_grid.draw_rect(Rect2(r.position.x + 2, r.position.y + 180, r.size.x - 4, r.size.y - 182), Color("0b1226", 0.85))
		M3.text(_grid, r.position + Vector2(0, 210), String(h.name).split(" ")[0], 26, UI.TEXT if have else UI.MUTED, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var sub := "à recruter"
		var col := UI.GOLD
		if have:
			var st := int(Game.hero_stars.get(id, 1))
			sub = "%s · niv. %d" % ["★".repeat(mini(st, 5)), int(Game.levels[id])]
			col = UI.TEXT
			if Game.can_star_up(id):
				sub = "▲ étoile · niv. %d" % int(Game.levels[id])
				col = UI.GREEN
		M3.text(_grid, r.position + Vector2(4, 238), sub, 20, col if have else Color(UI.GOLD, 0.7), true, r.size.x - 8.0, HORIZONTAL_ALIGNMENT_CENTER)


## Pictogramme du rôle : bouclier (rempart), épées (dégâts), croix (soins), ondes (contrôle).
static func _role_glyph(ci: CanvasItem, role: String, c: Vector2, col: Color) -> void:
	match role:
		"tank":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-10, -10), c + Vector2(10, -10), c + Vector2(10, 1), c + Vector2(0, 12), c + Vector2(-10, 1), c + Vector2(-10, -10)]), col, 3.0, true)
		"dps":
			ci.draw_line(c + Vector2(-10, 10), c + Vector2(10, -10), col, 3.0, true)
			ci.draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), col, 3.0, true)
		"healer":
			ci.draw_rect(Rect2(c + Vector2(-3, -11), Vector2(6, 22)), col)
			ci.draw_rect(Rect2(c + Vector2(-11, -3), Vector2(22, 6)), col)
		_:
			for k in 3:
				ci.draw_arc(c + Vector2(0, -6 + k * 6), 10, PI * 1.1, PI * 1.9, 10, col, 2.5, true)


func _grid_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_gpress = ev.position
		_gdown = true
	elif M3.is_release(ev) and _gdown:
		_gdown = false
		if ev.position.distance_to(_gpress) > 14.0:
			return
		for i in _cells.size():
			if _cell_rect(i).has_point(ev.position):
				hero_requested.emit(_cells[i])
				return


# ---------------------------------------------------------------- formation (feuille du bas)

func _open_sheet() -> void:
	if _sheet != null:
		return
	_sheet = Control.new()
	_sheet.size = Vector2(720, (UI.H - 160.0))
	_sheet.z_index = 40
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_sheet)
	var y0 := (UI.H - 160.0) - 640.0
	_sheet.draw.connect(func():
		_sheet.draw_rect(Rect2(0, 0, 720, (UI.H - 160.0)), Color(0, 0, 0, 0.6))
		M3.sheet(_sheet, Rect2(0, y0, 720, 640))
		_sheet.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, y0 + 16, 64, 8))
		M3.text(_sheet, Vector2(32, y0 + 88), "Formation de l'escouade", 40, UI.TEXT, true)
		M3.text(_sheet, Vector2(32, y0 + 128), "Glisse un héros pour échanger les places", 26, UI.MUTED))
	_sheet.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and ev.position.y < y0:
			_close_sheet())
	_form = Control.new()
	_form.position = Vector2(24, y0 + 152)
	_form.size = Vector2(672, 330)
	_form.draw.connect(_draw_form)
	_form.gui_input.connect(_form_input)
	_sheet.add_child(_form)
	var ok := M3.button(_sheet, "Terminé", Rect2(32, y0 + 504, 656, 104), "main")
	ok.pressed.connect(_close_sheet)


func _close_sheet() -> void:
	if _sheet != null:
		_sheet.queue_free()
		_sheet = null
		_form = null


func _slot_rect(i: int) -> Rect2:
	if i < 3:
		return Rect2(336.0 - 186.0 + i * 128.0, 0, 108, 124)
	return Rect2(336.0 - 122.0 + (i - 3) * 128.0, 140, 108, 124)


func _draw_form() -> void:
	for i in Data.SQUAD_SIZE:
		var r := _slot_rect(i)
		var id: String = Game.squad[i]
		var hot := _drag_slot >= 0 and r.has_point(_drag_pos) and i != _drag_slot
		M3.card(_form, r, M3.S2, 24, UI.ACCENT if hot else M3.OUT, 2)
		if id != "" and _drag_slot != i:
			M3.avatar(_form, Data.HEROES[id], r.position + Vector2(54, 54), 44.0, Data.RARITY_COLORS[Data.HEROES[id].rarity], _t)
		M3.text(_form, Vector2(r.position.x, r.end.y - 8), "Avant" if i < 3 else "Arrière", 20, UI.MUTED, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var x := 0.0
	for s in Game.synergy().list:
		var txt := "%s %s" % [s.name, s.desc]
		var w := M3.text_w(txt, 22, true) + 40.0
		if x + w > _form.size.x:
			break
		_form.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 16, 0), Rect2(x, 280, w, 48))
		M3.text(_form, Vector2(x + 20, 312), txt, 22, UI.GREEN, true)
		x += w + 12.0
	if _drag_slot >= 0 and Game.squad[_drag_slot] != "":
		M3.avatar(_form, Data.HEROES[Game.squad[_drag_slot]], _drag_pos, 52.0, UI.ACCENT, _t)


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
	if ev is InputEventMouseButton and not UI.emulated(ev) and ev.button_index == MOUSE_BUTTON_LEFT:
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
		if target >= 0 and target != from:
			var a: String = Game.squad[from]
			Game.squad[from] = Game.squad[target]
			Game.squad[target] = a
			Game.save_game()
			Sfx.play("click", -4.0)
			squad_changed.emit()
		_rebuild()
