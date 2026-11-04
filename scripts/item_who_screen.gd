class_name ItemWhoScreen
extends ItemScreen
## À qui l'équiper ? (maquette U) : le gain de puissance de chaque héros, du meilleur au moins bon.

signal changed

var _item_id := 0
var _rows: Array = []        # {hero, gain, note, locked}
var _sel := 0
var _go: Button
var _list: Control
var _msg := ""


func _init(item_id: int, title := "Nouvel objet") -> void:
	super._init(title, [["⋮", func(): _menu()]])
	_item_id = item_id
	var it: Dictionary = Game.item_by_id(item_id)
	for hid in Game.squad_ids():
		var cur: Dictionary = Game.slot_item(hid, it.slot)
		var row := {"hero": hid, "gain": Game.power_gain(it, hid), "locked": not Game.slot_unlocked(hid, it.slot), "note": ""}
		if row.locked:
			row.note = "Emplacement verrouillé jusqu'au niveau %d" % int(Items.SLOT_UNLOCK[it.slot])
		elif cur.is_empty():
			row.note = "Emplacement vide"
		elif cur.id == it.id:
			row.note = "Porte déjà cet objet"
		elif it.slot == "arme" and Data.HEROES[hid].role == "tank":
			row.note = "Ce héros frappe peu : l'arme compte moins"
		else:
			row.note = "Remplace %s" % cur.name
		_rows.append(row)
	_rows.sort_custom(func(a, b): return (not a.locked and b.locked) or (a.locked == b.locked and a.gain > b.gain))
	canvas(Vector2(32, 112), Vector2(656, 160), _draw_preview)
	var sec := canvas(Vector2(0, 280), Vector2(720, 60), func(c: Control): M3.section(c, Vector2(32, 44), "GAIN DE PUISSANCE PAR HÉROS"))
	sec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list = canvas(Vector2(32, 344), Vector2(656, 680), _draw_list)
	_list.gui_input.connect(_list_input)
	_go = button("", "main", Vector2(32, 1280 - 32 - 96 - 16 - 104), Vector2(656, 104), 32)
	_go.pressed.connect(_equip)
	var keep := button("Garder dans l'inventaire", "ghost", Vector2(32, 1280 - 32 - 96), Vector2(656, 96), 30)
	keep.pressed.connect(close)
	_refresh()


func _refresh() -> void:
	if _rows.is_empty():
		_go.text = "Aucun héros dans l'escouade"
		_go.disabled = true
		return
	var row: Dictionary = _rows[_sel]
	_go.text = "Équiper sur %s" % String(Data.HEROES[row.hero].name).split(" ")[0]
	_go.disabled = bool(row.locked)
	_list.queue_redraw()


func _equip() -> void:
	var row: Dictionary = _rows[_sel]
	var msg: String = Game.equip(_item_id, row.hero)
	if msg != "":
		_msg = msg
		_go.text = msg
		return
	Game.save_game()
	Sfx.play("chest", -4.0)
	changed.emit()
	close()


func _menu() -> void:
	var it: Dictionary = Game.item_by_id(_item_id)
	if it.on != "" or it.locked:
		M3.menu(st, Vector2(704, 96), [["Objet verrouillé ou porté : pas de recyclage", func(): pass]])
		return
	M3.menu(st, Vector2(704, 96), [["Recycler · %d éclats" % int(Items.RECYCLE_SHARDS[it.rarity]), func():
		Game.recycle_items([_item_id])
		Game.save_game()
		changed.emit()
		close()]])


func _draw_preview(c: Control) -> void:
	var it: Dictionary = Game.item_by_id(_item_id)
	var col := ItemUI.color(it.rarity)
	UI.draw_gradient_box(c, Rect2(Vector2.ZERO, c.size), 40.0, Color(col.r * 0.25, col.g * 0.18, col.b * 0.05), M3.S2, col, 3.0)
	ItemUI.tile(c, Rect2(24, 24, 112, 112), it, true)
	M3.text(c, Vector2(160, 68), String(it.name), 30, col, true, 470)
	M3.text(c, Vector2(160, 108), Items.summary_short(it), 24, UI.MUTED, false, 470)


func _draw_list(c: Control) -> void:
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var r := Rect2(0, i * 128.0, 656, 112)
		M3.row(c, r, i == _sel)
		M3.avatar(c, Data.HEROES[row.hero], r.position + Vector2(64, 56), 40.0, Color("4fb8c8"), _t)
		M3.text(c, r.position + Vector2(128, 50), String(Data.HEROES[row.hero].name).split(" ")[0], 30, UI.MUTED if row.locked else UI.TEXT, true)
		M3.text(c, r.position + Vector2(128, 86), String(row.note), 24, UI.MUTED, false, 380)
		if not row.locked:
			ItemUI.delta(c, 632.0, r.position.y + 68.0, float(row.gain), M3.fs(26))


var _lpress := Vector2.ZERO
var _ldown := false


func _list_input(ev: InputEvent) -> void:
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
		_lpress = pos
		_ldown = true
	elif released and _ldown:
		_ldown = false
		var i := int(pos.y / 128.0)
		if i >= 0 and i < _rows.size():
			_sel = i
			Sfx.play("click", -8.0)
			_refresh()


func _process(delta: float) -> void:
	_t += delta
	_list.queue_redraw()
