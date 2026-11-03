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
	super._init(title)
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
	canvas(Vector2(32, 148), Vector2(656, 156), _draw_preview)
	lab("GAIN DE PUISSANCE PAR HÉROS", 22, UI.MUTED, Vector2(32, 332))
	_list = canvas(Vector2(32, 372), Vector2(656, 640), _draw_list)
	_list.gui_input.connect(_list_input)
	_go = button("", "main", Vector2(32, 1040), Vector2(656, 104), 32)
	_go.pressed.connect(_equip)
	var keep := button("Garder en inventaire", "ghost", Vector2(32, 1160), Vector2(320, 96), 26)
	keep.pressed.connect(close)
	var rec := button("", "ghost", Vector2(368, 1160), Vector2(320, 96), 26)
	UI.set_button_parts(rec, ["Recycler ·", UI.icon("shard"), str(int(Items.RECYCLE_SHARDS[it.rarity]))], 26, Color("ff9b9b"))
	rec.disabled = it.on != "" or it.locked
	rec.pressed.connect(func():
		Game.recycle_items([item_id])
		Game.save_game()
		changed.emit()
		close())
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


func _draw_preview(c: Control) -> void:
	var it: Dictionary = Game.item_by_id(_item_id)
	var col := ItemUI.color(it.rarity)
	UI.draw_gradient_box(c, Rect2(Vector2.ZERO, c.size), 32.0, Color(col.r * 0.25, col.g * 0.2, col.b * 0.15, 1.0).lerp(Color("141d3a"), 0.35), UI.PANEL, col, 3.0)
	ItemUI.tile(c, Rect2(24, 14, 128, 128), it, true)
	var lab_txt := "%s %s" % [String(Items.SLOT_NAMES[it.slot]).to_upper(), String(Data.RARITY_NAMES[it.rarity]).to_upper()]
	var x := 176.0
	for ch in lab_txt:
		c.draw_string(UI.bold_font(), Vector2(x, 54), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		x += UI.bold_font().get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 2.5
	c.draw_string(UI.bold_font(), Vector2(176, 92), it.name, HORIZONTAL_ALIGNMENT_LEFT, 460.0, 30, Color.WHITE)
	c.draw_string(ThemeDB.fallback_font, Vector2(176, 126), Items.summary(it), HORIZONTAL_ALIGNMENT_LEFT, 460.0, 22, UI.MUTED)


func _draw_list(c: Control) -> void:
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		var y := i * 126.0
		var on := i == _sel
		var sb := UI.box(Color("1a2a55") if on else UI.PANEL, UI.ACCENT if on else UI.LINE2, 24, 0)
		sb.set_border_width_all(3)
		c.draw_style_box(sb, Rect2(0, y, 656, 98))
		UI.portrait(c, Data.HEROES[row.hero], Vector2(64, y + 49), 44.0, _t)
		var nm: String = String(Data.HEROES[row.hero].name).split(" ")[0]
		c.draw_string(UI.bold_font(), Vector2(120, y + 42), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE if not row.locked else UI.MUTED)
		if i == 0 and not row.locked:
			var w := UI.bold_font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
			c.draw_style_box(UI.box(Color(0, 0, 0, 0), Color(UI.GREEN, 0.5), 16, 0), Rect2(132 + w, y + 18, 104, 30))
			c.draw_string(UI.bold_font(), Vector2(144 + w, y + 40), "Meilleur", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.GREEN)
		c.draw_string(ThemeDB.fallback_font, Vector2(120, y + 76), row.note, HORIZONTAL_ALIGNMENT_LEFT, 380.0, 20, UI.MUTED)
		if not row.locked:
			ItemUI.delta(c, 632.0, y + 58.0, float(row.gain))


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
		var i := int(pos.y / 126.0)
		if i >= 0 and i < _rows.size():
			_sel = i
			Sfx.play("click", -8.0)
			_refresh()


func _process(delta: float) -> void:
	_t += delta
	_list.queue_redraw()
