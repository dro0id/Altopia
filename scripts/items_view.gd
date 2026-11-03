class_name ItemsView
extends Control
## Onglet Objets de la collection (maquette V) : jauge d'inventaire, filtres par emplacement, tri, grille d'objets, « Équiper au mieux » et la forge.

signal item_requested(id: int)
signal forge_requested
signal changed

const SORTS := ["puissance", "rareté", "niveau"]

var _filter := ""                 # "" = tous, sinon un emplacement
var _sort := 0
var _chips: Array = []
var _sort_chip: HudButton
var _scroll: ScrollContainer
var _grid: Control
var _list: Array = []
var _better := {}
var _press := Vector2.ZERO
var _down := false
var _auto_btn: Button
var _toggle_y := 0.0


func _init() -> void:
	size = Vector2(720, 1120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := 32.0
	var labels := ["Tous", "Arme", "Armure", "Module", "Relique"]
	for i in labels.size():
		var b := HudButton.new()
		b.font_size = 24
		b.bold = true
		b.radius = 24.0
		b.set_texts(labels[i])
		b.size = Vector2(UI.bold_font().get_string_size(labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 44.0, 48)
		b.position = Vector2(x, 244)
		x += b.size.x + 12.0
		var idx := i
		b.pressed.connect(func():
			_filter = "" if idx == 0 else Items.SLOTS[idx - 1]
			refresh())
		add_child(b)
		_chips.append(b)
	_sort_chip = HudButton.new()
	_sort_chip.font_size = 22
	_sort_chip.bold = true
	_sort_chip.radius = 20.0
	_sort_chip.size = Vector2(202, 44)
	_sort_chip.position = Vector2(486, 308)
	_sort_chip.pressed.connect(func():
		_sort = (_sort + 1) % SORTS.size()
		refresh())
	add_child(_sort_chip)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 364)
	_scroll.size = Vector2(720, 676)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	DragScroll.attach(_scroll)
	_grid = Control.new()
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_grid_input)
	_scroll.add_child(_grid)
	_auto_btn = UI.button(self, "Équiper au mieux", 26, "main")
	_auto_btn.position = Vector2(32, 1016)
	_auto_btn.size = Vector2(402, 88)
	_auto_btn.custom_minimum_size = Vector2(0, 88)
	_auto_btn.pressed.connect(func():
		var n: int = Game.equip_best_all()
		Game.save_game()
		Sfx.play("chest" if n > 0 else "click", -4.0)
		changed.emit()
		refresh())
	var forge := UI.button(self, "Forge", 26, "ghost")
	forge.position = Vector2(450, 1016)
	forge.size = Vector2(238, 88)
	forge.custom_minimum_size = Vector2(0, 88)
	forge.pressed.connect(func(): forge_requested.emit())
	refresh()


func refresh() -> void:
	_list = Game.inventory_items()
	if _filter != "":
		_list = _list.filter(func(it): return it.slot == _filter)
	_better = {}
	for it in Game.inventory_items():
		var b: Dictionary = Game.best_hero_for(it)
		if b.hero != "" and b.gain > 0.0 and (it.bound == "" or it.bound == b.hero):
			_better[int(it.id)] = b.gain
	var sorter: Callable
	match _sort:
		0:
			sorter = func(a, b): return Items.power(a) > Items.power(b)
		1:
			sorter = func(a, b): return Items.rarity_index(a.rarity) > Items.rarity_index(b.rarity) or (Items.rarity_index(a.rarity) == Items.rarity_index(b.rarity) and int(a.level) > int(b.level))
		_:
			sorter = func(a, b): return int(a.level) > int(b.level)
	_list.sort_custom(sorter)
	for i in _chips.size():
		var b: HudButton = _chips[i]
		var on: bool = (i == 0 and _filter == "") or (i > 0 and _filter == Items.SLOTS[i - 1])
		b.fill = UI.ACCENT if on else UI.HUD
		b.border = UI.ACCENT if on else UI.LINE
		b.text_color = UI.DARK if on else UI.TEXT
		b.queue_redraw()
	_sort_chip.set_texts("Tri : %s ▾" % SORTS[_sort])
	var rows := ceili(float(_list.size()) / 4.0)
	_grid.custom_minimum_size = Vector2(720, 12.0 + rows * 156.0 + 20.0)
	_grid.queue_redraw()
	queue_redraw()


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var n: int = Game.inventory_count()
	draw_string(f, Vector2(32, 204), "Inventaire", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)
	draw_string(UI.bold_font(), Vector2(0, 204), "%d / %d" % [n, Items.INVENTORY_MAX], HORIZONTAL_ALIGNMENT_RIGHT, 688.0, 24, Color.WHITE)
	draw_style_box(UI.box(UI.LINE2, Color(0, 0, 0, 0), 6, 0), Rect2(32, 216, 656, 12))
	var full := n >= Items.INVENTORY_MAX
	draw_style_box(UI.box(UI.RED if full else (Color("ffb142") if n >= 54 else UI.ACCENT), Color(0, 0, 0, 0), 6, 0), Rect2(32, 216, maxf(12.0, 656.0 * float(n) / float(Items.INVENTORY_MAX)), 12))
	draw_colored_polygon(PackedVector2Array([Vector2(34, 338), Vector2(46, 338), Vector2(40, 326)]), UI.MUTED)
	draw_string(f, Vector2(60, 338), "meilleur que ce que porte un héros", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)
	# avertissements d'inventaire (planche des états)
	if n >= 54 or not Game.stash.is_empty():
		var col := UI.RED if (full or not Game.stash.is_empty()) else Color("ffb142")
		var msg := "Inventaire plein : %d objet%s gardé%s de côté" % [Game.stash.size(), "s" if Game.stash.size() > 1 else "", "s" if Game.stash.size() > 1 else ""] if not Game.stash.is_empty() else "Inventaire presque plein · %d / %d" % [n, Items.INVENTORY_MAX]
		draw_style_box(UI.box(Color(col.r, col.g, col.b, 0.12), Color(col.r, col.g, col.b, 0.6), 24, 0), Rect2(32, 968, 656, 64))
		draw_string(UI.bold_font(), Vector2(56, 976), msg, HORIZONTAL_ALIGNMENT_LEFT, 600.0, 24, col)


func _cell(i: int) -> Rect2:
	return Rect2(32.0 + (i % 4) * 168.0, 12.0 + (i / 4) * 156.0, 140, 140)


func _draw_grid() -> void:
	for i in _list.size():
		var it: Dictionary = _list[i]
		var r := _cell(i)
		ItemUI.tile(_grid, r, it)
		if _better.has(int(it.id)):
			ItemUI.dot(_grid, r.position + Vector2(r.size.x - 4.0, 4.0), "▲")
		if it.locked:
			_grid.draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 30), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if _list.is_empty():
		_grid.draw_string(ThemeDB.fallback_font, Vector2(0, 120), "Aucun objet ici : les coffres en donnent à chaque étage.", HORIZONTAL_ALIGNMENT_CENTER, 720, 24, UI.MUTED)


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
		_press = pos
		_down = true
	elif released and _down:
		_down = false
		if pos.distance_to(_press) > 14.0:
			return
		for i in _list.size():
			if _cell(i).has_point(pos):
				item_requested.emit(int(_list[i].id))
				return
