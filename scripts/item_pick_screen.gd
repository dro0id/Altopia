class_name ItemPickScreen
extends ItemScreen
## Choisir un objet (maquette BS) : puces de tri, liste avec gain de puissance, comparaison, bouton Équiper.

signal changed

const SORTS := ["Gain", "Rareté", "Niveau"]

var _hero := ""
var _slot := ""
var _cands: Array = []
var _sel := 0
var _sort := 0
var _scroll: ScrollContainer
var _list: Control
var _cmp: Control
var _go: Button
var _msg := ""
var _lpress := Vector2.ZERO
var _ldown := false


func _init(hero_id: String, slot: String) -> void:
	super._init("%s · %s" % [Items.SLOT_NAMES[slot], String(Data.HEROES[hero_id].name).split(" ")[0]])
	_hero = hero_id
	_slot = slot
	var chips := M3Chips.new(SORTS, 0)
	chips.position = Vector2(32, 96)
	chips.changed.connect(func(i: int):
		_sort = i
		_sel = 0
		_build_candidates()
		_refresh())
	st.add_child(chips)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 192)
	_scroll.size = Vector2(720, UI.H - 192 - 32 - 104 - 96)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	st.add_child(_scroll)
	DragScroll.attach(_scroll)
	_list = Control.new()
	_list.draw.connect(func(): _draw_list(_list))
	_list.gui_input.connect(_list_input)
	_scroll.add_child(_list)
	_cmp = canvas(Vector2(0, UI.H - 32 - 104 - 88), Vector2(720, 80), _draw_cmp)
	_go = button("", "main", Vector2(32, UI.H - 32 - 104), Vector2(656, 104), 32)
	_go.pressed.connect(_equip)
	_build_candidates()
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
	match _sort:
		0:
			_cands.sort_custom(func(a, b): return Game.power_gain(a, _hero) > Game.power_gain(b, _hero))
		1:
			_cands.sort_custom(func(a, b): return Items.rarity_index(a.rarity) > Items.rarity_index(b.rarity))
		_:
			_cands.sort_custom(func(a, b): return int(a.level) > int(b.level))
	_list.custom_minimum_size = Vector2(720, _cands.size() * 144.0 + 16.0)


func _refresh() -> void:
	if _cands.is_empty():
		_go.text = "Aucun objet pour cet emplacement"
		_go.disabled = true
		_list.queue_redraw()
		return
	var it: Dictionary = _cands[_sel]
	var g: float = Game.power_gain(it, _hero)
	var cost: int = Game.equip_cost(it, _hero)
	if cost > 0:
		_go.text = "Délier et équiper · %d ¢" % cost
	else:
		_go.text = "Équiper · %s%s de puissance" % ["+" if g >= 0.0 else "−", UI.num(absf(g))]
	_go.disabled = false
	_list.queue_redraw()
	_cmp.queue_redraw()


func _equip() -> void:
	if _cands.is_empty():
		return
	var msg: String = Game.equip(int(_cands[_sel].id), _hero)
	if msg != "":
		_msg = msg
		_cmp.queue_redraw()
		return
	Game.save_game()
	Sfx.play("chest", -4.0)
	M3.toast(self, "Objet équipé sur %s" % String(Data.HEROES[_hero].name).split(" ")[0])
	changed.emit()
	close()


func _draw_list(c: Control) -> void:
	for i in _cands.size():
		var it: Dictionary = _cands[i]
		var r := Rect2(32, i * 144.0, 656, 128)
		var other: bool = it.bound != "" and it.bound != _hero
		M3.row(c, r, i == _sel)
		ItemUI.tile(c, Rect2(r.position + Vector2(16, 16), Vector2(96, 96)), it, true, other)
		M3.text(c, r.position + Vector2(136, 56), String(it.name), 30, UI.TEXT, true, 340)
		M3.text(c, r.position + Vector2(136, 94), Items.summary_short(it), 24, UI.MUTED, false, 360)
		ItemUI.delta(c, r.end.x - 24.0, r.position.y + 76.0, Game.power_gain(it, _hero), M3.fs(26))
	if _cands.is_empty():
		M3.text(c, Vector2(0, 120), "Aucun objet pour cet emplacement.", 26, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_cmp(c: Control) -> void:
	if _msg != "":
		M3.text(c, Vector2(32, 52), _msg, 26, UI.RED, false, 656)
		return
	if _cands.is_empty():
		return
	var it: Dictionary = _cands[_sel]
	var cur: Dictionary = Game.slot_item(_hero, _slot)
	var a := Items.stats(cur) if not cur.is_empty() else Items.stats({"slot": _slot, "rarity": "commun", "level": 1, "scale": 0.0, "subs": []})
	var b := Items.stats(it)
	var k := "atk" if _slot == "arme" else ("skill" if _slot == "module" else "hp")
	var nm := "ATQ" if k == "atk" else ("Pouvoir" if k == "skill" else "PV")
	var va := int(round(float(a[k]) * (100.0 if k == "skill" else 1.0)))
	var vb := int(round(float(b[k]) * (100.0 if k == "skill" else 1.0)))
	var txt := "%s %d → " % [nm, va]
	M3.text(c, Vector2(32, 52), txt, 26, UI.MUTED)
	var w := M3.text_w(txt, 26)
	M3.text(c, Vector2(32 + w, 52), str(vb), 26, UI.GREEN if vb >= va else UI.RED, true)
	w += M3.text_w(str(vb), 26, true)
	M3.text(c, Vector2(32 + w, 52), " · L'objet retiré revient à l'inventaire", 24, UI.MUTED, false, 640 - w)


func _list_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_lpress = ev.position
		_ldown = true
	elif M3.is_release(ev) and _ldown:
		_ldown = false
		if ev.position.distance_to(_lpress) > 14.0:
			return
		var i := int(ev.position.y / 144.0)
		if i >= 0 and i < _cands.size():
			_sel = i
			_msg = ""
			Sfx.play("click", -8.0)
			_refresh()
