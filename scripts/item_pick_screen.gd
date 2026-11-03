class_name ItemPickScreen
extends ItemScreen
## Choisir un objet pour un emplacement (maquette T) : l'objet porté, la liste triée par gain de puissance, la comparaison et un bouton pour équiper.

signal changed

var _hero := ""
var _slot := ""
var _cands: Array = []
var _sel := 0
var _list: Control
var _cmp: Control
var _go: Button
var _note: Label
var _eq: Control


func _init(hero_id: String, slot: String) -> void:
	super._init("%s · %s" % [Items.SLOT_NAMES[slot], String(Data.HEROES[hero_id].name).split(" ")[0]])
	_hero = hero_id
	_slot = slot
	_build_candidates()
	_eq = canvas(Vector2(32, 150), Vector2(656, 108), _draw_equipped)
	lab("Trié par gain de puissance", 22, UI.MUTED, Vector2(32, 290))
	var fl := HudButton.new()
	fl.font_size = 20
	fl.bold = true
	fl.radius = 20.0
	fl.set_texts("Tri : gain ▾")
	fl.size = Vector2(170, 44)
	fl.position = Vector2(518, 280)
	fl.tappable = false
	st.add_child(fl)
	_list = canvas(Vector2(32, 336), Vector2(656, 600), _draw_list)
	_list.gui_input.connect(_list_input)
	_cmp = canvas(Vector2(32, 976), Vector2(656, 80), _draw_cmp)
	_go = button("", "main", Vector2(32, 1083), Vector2(656, 104), 32)
	_go.pressed.connect(_equip)
	_note = lab("L'objet retiré revient dans l'inventaire. Un objet équipé est lié au héros.", 22, UI.MUTED, Vector2(32, 1200), 656.0, false, HORIZONTAL_ALIGNMENT_CENTER)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh()


func _build_candidates() -> void:
	_cands = []
	var cur: Dictionary = Game.slot_item(_hero, _slot)
	for it in Game.items:
		if it.slot != _slot or (not cur.is_empty() and it.id == cur.id):
			continue
		if it.on != "" and it.on != _hero:
			continue
		_cands.append(it)
	_cands.sort_custom(func(a, b): return Game.power_gain(a, _hero) > Game.power_gain(b, _hero))


func _refresh() -> void:
	if _cands.is_empty():
		_go.text = "Aucun objet pour cet emplacement"
		_go.disabled = true
		return
	var it: Dictionary = _cands[_sel]
	var g: float = Game.power_gain(it, _hero)
	var cost: int = Game.equip_cost(it, _hero)
	if cost > 0:
		_go.text = "Délier et équiper · ¢ %d" % cost
	else:
		_go.text = "Équiper · %s%d de puissance" % ["+" if g >= 0.0 else "−", int(absf(g))]
	_go.disabled = false
	_list.queue_redraw()
	_cmp.queue_redraw()


func _equip() -> void:
	if _cands.is_empty():
		return
	var msg: String = Game.equip(int(_cands[_sel].id), _hero)
	if msg != "":
		_note.text = msg
		return
	Game.save_game()
	Sfx.play("chest", -4.0)
	changed.emit()
	close()


func _draw_equipped(c: Control) -> void:
	c.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 24, 0), Rect2(Vector2.ZERO, c.size))
	var cur: Dictionary = Game.slot_item(_hero, _slot)
	var f := ThemeDB.fallback_font
	if cur.is_empty():
		ItemUI.empty(c, Rect2(24, 10, 88, 88))
		c.draw_string(f, Vector2(132, 44), "ÉQUIPÉ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.MUTED)
		c.draw_string(UI.bold_font(), Vector2(132, 78), "Emplacement vide", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.MUTED)
		return
	ItemUI.tile(c, Rect2(24, 10, 88, 88), cur, false)
	c.draw_string(f, Vector2(132, 44), "ÉQUIPÉ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.MUTED)
	c.draw_string(UI.bold_font(), Vector2(132, 78), cur.name, HORIZONTAL_ALIGNMENT_LEFT, 360.0, 26, ItemUI.color(cur.rarity))
	c.draw_string(f, Vector2(0, 44), "Puissance", HORIZONTAL_ALIGNMENT_RIGHT, 632.0, 20, UI.MUTED)
	c.draw_string(UI.bold_font(), Vector2(0, 84), UI.num(Items.power(cur)), HORIZONTAL_ALIGNMENT_RIGHT, 632.0, 30, Color.WHITE)


func _draw_list(c: Control) -> void:
	var f := ThemeDB.fallback_font
	for i in mini(_cands.size(), 4):
		var it: Dictionary = _cands[i]
		var y := i * 140.0
		var on := i == _sel
		var other: bool = it.bound != "" and it.bound != _hero
		var sb := UI.box(Color("1a2a55") if on else UI.PANEL, UI.ACCENT if on else UI.LINE2, 24, 0)
		sb.set_border_width_all(3)
		c.draw_style_box(sb, Rect2(0, y, 656, 110))
		ItemUI.tile(c, Rect2(20, y + 9, 92, 92), it, false, other)
		var col := ItemUI.color(it.rarity)
		var nx := 132.0
		c.draw_string(UI.bold_font(), Vector2(nx, y + 48), it.name, HORIZONTAL_ALIGNMENT_LEFT, 330.0, 26, col)
		if it.set != "":
			var nw := UI.bold_font().get_string_size(it.name, HORIZONTAL_ALIGNMENT_LEFT, 330.0, 26).x
			ItemUI.set_badge(c, Vector2(nx + nw + 12.0, y + 24.0), it.set)
		c.draw_string(f, Vector2(nx, y + 80), Items.summary(it), HORIZONTAL_ALIGNMENT_LEFT, 410.0, 20, UI.MUTED)
		var g: float = Game.power_gain(it, _hero)
		ItemUI.delta(c, 632.0, y + 66.0, g)


func _draw_cmp(c: Control) -> void:
	c.draw_style_box(UI.box(UI.PANEL2, Color(0, 0, 0, 0), 24, 0), Rect2(Vector2.ZERO, c.size))
	if _cands.is_empty():
		return
	var it: Dictionary = _cands[_sel]
	var cur: Dictionary = Game.slot_item(_hero, _slot)
	var a := Items.stats(cur) if not cur.is_empty() else Items.stats({"slot": _slot, "rarity": "commun", "level": 1, "scale": 0.0, "subs": []})
	var b := Items.stats(it)
	var cols: Array = []
	match _slot:
		"arme":
			cols.append(["ATQ", "%d → %d" % [int(round(a.atk)), int(round(b.atk))]])
		"armure":
			cols.append(["PV", "%d → %d" % [int(round(a.hp)), int(round(b.hp))]])
		"module":
			cols.append(["Pouvoir", "+%d → +%d %%" % [int(round(a.skill * 100.0)), int(round(b.skill * 100.0))]])
		_:
			cols.append(["PV", "%d → %d" % [int(round(a.hp)), int(round(b.hp))]])
	for k in ["speed", "crit", "boss", "heal", "cdr"]:
		if float(a[k]) > 0.0 or float(b[k]) > 0.0:
			cols.append([String(Items.BONUS[k][0]).split(" ")[0], "%d → %d %%" % [int(round(a[k] * 100.0)), int(round(b[k] * 100.0))]])
	for i in mini(cols.size(), 3):
		var x := 24.0 + i * 208.0
		c.draw_string(ThemeDB.fallback_font, Vector2(x, 32), cols[i][0], HORIZONTAL_ALIGNMENT_LEFT, 190.0, 20, UI.MUTED)
		c.draw_string(UI.bold_font(), Vector2(x, 64), cols[i][1], HORIZONTAL_ALIGNMENT_LEFT, 190.0, 26, Color.WHITE)


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
		if pos.distance_to(_lpress) > 14.0:
			return
		var i := int(pos.y / 140.0)
		if i >= 0 and i < mini(_cands.size(), 4):
			_sel = i
			Sfx.play("click", -8.0)
			_refresh()
