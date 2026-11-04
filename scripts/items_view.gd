class_name ItemsView
extends Control
## Onglet Objets (maquette BE) : jauge d'inventaire, puces d'emplacement, grille de 4 tuiles, bouton flottant « Équiper au mieux ».

signal item_requested(id: int)
signal changed

var query := ""
var _filter := ""                 # "" = tous, sinon un emplacement
var _chips: M3Chips
var _scroll: ScrollContainer
var _grid: Control
var _list: Array = []
var _better := {}
var _press := Vector2.ZERO
var _down := false
var _fab: Button


func _init() -> void:
	size = Vector2(720, 1120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips = M3Chips.new(["Tous", "Arme", "Armure", "Module", "Relique"], 0)
	_chips.position = Vector2(32, 260)
	_chips.changed.connect(func(i: int):
		_filter = "" if i == 0 else Items.SLOTS[i - 1]
		refresh())
	add_child(_chips)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 344)
	_scroll.size = Vector2(720, 776)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	DragScroll.attach(_scroll)
	_grid = Control.new()
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_grid_input)
	_scroll.add_child(_grid)
	# bouton flottant étendu (56 dp, rayon 16 dp)
	_fab = UI.button(self, "✦  Équiper au mieux", M3.fs(30), "main")
	var w := M3.text_w("✦  Équiper au mieux", 30, true) + 80.0
	_fab.position = Vector2(688.0 - w, 1120.0 - 32.0 - 112.0)
	_fab.size = Vector2(w, 112)
	_fab.custom_minimum_size = Vector2(w, 112)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = _fab.get_theme_stylebox(st).duplicate()
		sb.set_corner_radius_all(32)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 16
		sb.shadow_offset = Vector2(0, 8)
		_fab.add_theme_stylebox_override(st, sb)
	_fab.pressed.connect(func():
		var n: int = Game.equip_best_all()
		Game.save_game()
		Sfx.play("chest" if n > 0 else "click", -4.0)
		changed.emit()
		refresh())
	refresh()


func refresh() -> void:
	_list = Game.inventory_items()
	if _filter != "":
		_list = _list.filter(func(it): return it.slot == _filter)
	if query != "":
		_list = _list.filter(func(it): return String(it.name).to_lower().find(query) >= 0)
	_better = {}
	for it in Game.inventory_items():
		var b: Dictionary = Game.best_hero_for(it)
		if b.hero != "" and b.gain > 0.0 and (it.bound == "" or it.bound == b.hero):
			_better[int(it.id)] = b.gain
	_list.sort_custom(func(a, b): return Items.power(a) > Items.power(b))
	var rows := ceili(float(_list.size()) / 4.0)
	_grid.custom_minimum_size = Vector2(720, 16.0 + rows * 168.0 + 160.0)
	_grid.queue_redraw()
	queue_redraw()


func _process(_d: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var n: int = Game.inventory_count()
	var full := n >= Items.INVENTORY_MAX
	var lab := "Inventaire" if Game.stash.is_empty() else "Inventaire · %d en réserve" % Game.stash.size()
	M3.text(self, Vector2(32, 216), lab, 24, UI.MUTED if Game.stash.is_empty() else UI.RED)
	M3.text(self, Vector2(32, 216), "%d / %d" % [n, Items.INVENTORY_MAX], 26, UI.TEXT, true, 656, HORIZONTAL_ALIGNMENT_RIGHT)
	M3.bar(self, Rect2(32, 230, 656, 12), float(n) / float(Items.INVENTORY_MAX), UI.RED if full else (Color("ffb142") if n >= 54 else UI.ACCENT))


func _cell(i: int) -> Rect2:
	return Rect2(32.0 + (i % 4) * 164.0 + 10.0, 16.0 + (i / 4) * 168.0, 144, 144)


func _draw_grid() -> void:
	for i in _list.size():
		var it: Dictionary = _list[i]
		var r := _cell(i)
		ItemUI.tile(_grid, r, it)
		if _better.has(int(it.id)):
			ItemUI.dot(_grid, r.position + Vector2(r.size.x - 8.0, 0.0), "▲")
		if it.locked:
			M3.text(_grid, r.position + Vector2(10, 32), "🔒", 22)
	if _list.is_empty():
		M3.text(_grid, Vector2(0, 120), "📦", 56, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(_grid, Vector2(0, 180), "Aucun objet pour ce filtre.", 26, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(_grid, Vector2(0, 220), "Gagne-en au combat ou ouvre une caisse.", 26, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)


func _grid_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_press = ev.position
		_down = true
	elif M3.is_release(ev) and _down:
		_down = false
		if ev.position.distance_to(_press) > 14.0:
			return
		for i in _list.size():
			if _cell(i).has_point(ev.position):
				item_requested.emit(int(_list[i].id))
				return
