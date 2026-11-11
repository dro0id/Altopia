class_name BondsScreen
extends Overlay
## Liens d'équipage (maquette WH) : chaque lien, son niveau, son bonus, ses conversations.

const CARD_H := 300.0

var _st: Control
var _scroll: ScrollContainer
var _list: Control
var _t := 0.0
var _press := Vector2.ZERO


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	set_backdrop(UI.GOLD)
	M3.top_bar(_st, "Liens d’équipage", close)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 112)
	_scroll.size = Vector2(720, UI.H - 112)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_st.add_child(_scroll)
	DragScroll.attach(_scroll)
	_list = Control.new()
	_list.custom_minimum_size = Vector2(720, 96 + Bonds.LIST.size() * (CARD_H + 16.0))
	_list.draw.connect(_draw_list)
	_list.gui_input.connect(_list_input)
	_scroll.add_child(_list)


func _process(delta: float) -> void:
	_t += delta
	_list.queue_redraw()


func _card_y(i: int) -> float:
	return 96.0 + i * (CARD_H + 16.0)


func _convo_rect(i: int, lv: int) -> Rect2:
	return Rect2(56 + (lv - 1) * 204.0, _card_y(i) + 210, 192, 70)


func _draw_list() -> void:
	var c := _list
	M3.para(c, Vector2(32, 36), "Un lien monte quand ses héros combattent ou travaillent ensemble. Chaque niveau renforce leurs pouvoirs et ouvre une conversation.", 22, UI.MUTED, 656, 1.35)
	for i in Bonds.LIST.size():
		var b: Dictionary = Bonds.LIST[i]
		var y := _card_y(i)
		var xp := int(Game.bond_xp.get(b.id, 0))
		var lv := Bonds.level_of(xp)
		var r := Rect2(32, y, 656, CARD_H)
		M3.glass_card(c, r, lv > 0, 20.0)
		if lv > 0:
			c.draw_style_box(UI.box(Color(0, 0, 0, 0), Color(UI.GOLD, 0.55), 20, 0), r)
		# visages
		var mem: Array = b.members
		for k in mem.size():
			var h: Dictionary = Data.HEROES[mem[k]]
			var owned := Game.is_owned(String(mem[k]))
			M3.avatar(c, h, Vector2(84 + k * 52, y + 60), 30.0, Data.RARITY_COLORS[h.rarity] if owned else M3.OUT, _t)
			if not owned:
				c.draw_circle(Vector2(84 + k * 52, y + 60), 28, Color(0.04, 0.06, 0.12, 0.7))
		var x0 := 84.0 + mem.size() * 52.0
		M3.text(c, Vector2(x0, y + 50), String(b.name), 30, UI.TEXT, true, 600 - x0)
		var names := ", ".join(mem.map(func(m): return String(Data.HEROES[m].name).split(" ")[0]))
		M3.text(c, Vector2(x0, y + 84), "%s · niveau %d / 3" % [names, lv], 22, UI.MUTED, false, 640 - x0)
		# progression vers le niveau suivant
		var lo := 0 if lv == 0 else int(Bonds.LEVELS[lv - 1])
		var hi := int(Bonds.LEVELS[mini(lv, 2)])
		var frac := 1.0 if lv >= 3 else float(xp - lo) / float(maxi(1, hi - lo))
		M3.bar(c, Rect2(56, y + 112, 608, 12), frac, UI.GOLD)
		M3.text(c, Vector2(56, y + 160), Bonds.bonus_text(maxi(1, lv), mem.size()) if lv > 0 else "Combattez ensemble pour ouvrir le lien (%d / %d)." % [xp, hi], 22, UI.TEXT if lv > 0 else UI.MUTED, lv > 0, 608)
		# conversations, une par niveau
		for k in 3:
			var cr := _convo_rect(i, k + 1)
			var open := lv >= k + 1
			var read := Game.bond_read.has("%s:%d" % [b.id, k + 1])
			c.draw_style_box(UI.box(Color("0b1226", 0.8) if open else M3.S2, Color(UI.GOLD, 0.6) if open and not read else Color(0, 0, 0, 0), 14, 0), cr)
			if open:
				c.draw_colored_polygon(PackedVector2Array([cr.position + Vector2(18, 22), cr.position + Vector2(36, 35), cr.position + Vector2(18, 48)]), UI.GOLD)
				M3.text(c, cr.position + Vector2(46, 32), String(b.convos[k].title), 20, UI.TEXT, true, cr.size.x - 54)
				M3.text(c, cr.position + Vector2(46, 58), "nouveau" if not read else "lu", 18, UI.GOLD if not read else UI.MUTED, not read)
			else:
				M3.lock(c, cr.position + Vector2(30, 35), UI.MUTED, 0.8)
				M3.text(c, cr.position + Vector2(50, 42), "niveau %d" % (k + 1), 20, UI.MUTED)


func _list_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_press = ev.position
	elif M3.is_release(ev) and ev.position.distance_to(_press) < 14.0:
		for i in Bonds.LIST.size():
			var b: Dictionary = Bonds.LIST[i]
			for k in 3:
				if _convo_rect(i, k + 1).has_point(ev.position) and Game.bond_level(String(b.id)) >= k + 1:
					_open_convo(b, k)
					return


func _open_convo(b: Dictionary, k: int) -> void:
	Sfx.play("click", -6.0)
	var key := "%s:%d" % [b.id, k + 1]
	if not Game.bond_read.has(key):
		Game.bond_read.append(key)
		Game.save_game()
	add_child(ConvoSheet.new(b, k))


## Feuille d'une conversation : trois répliques avec les visages.
class ConvoSheet extends Overlay:
	var _b := {}
	var _k := 0
	var _sh: Control
	var _t := 0.0

	func _init(b: Dictionary, k: int) -> void:
		super._init(720.0)
		_b = b
		_k = k
		var st := use_stage(0.7)
		_sh = Control.new()
		var h := 200.0 + 3 * 150.0
		_sh.size = Vector2(720, h)
		_sh.position = Vector2(0, UI.H - h)
		_sh.mouse_filter = Control.MOUSE_FILTER_STOP
		_sh.draw.connect(_draw_sheet)
		st.add_child(_sh)
		st.gui_input.connect(func(ev: InputEvent):
			if M3.is_tap(ev):
				close())
		_sh.gui_input.connect(func(ev: InputEvent):
			if M3.is_tap(ev):
				close())

	func _process(delta: float) -> void:
		_t += delta
		_sh.queue_redraw()

	func _draw_sheet() -> void:
		var c := _sh
		M3.sheet(c, Rect2(Vector2.ZERO, c.size))
		M3.text(c, Vector2(32, 72), String(_b.name).to_upper(), 22, UI.GOLD, true)
		M3.text(c, Vector2(32, 120), "« %s »" % String(_b.convos[_k].title), 34, UI.TEXT, true, 656)
		var lines: Array = _b.convos[_k].lines
		for i in lines.size():
			var who := String(lines[i][0])
			var h: Dictionary = Data.HEROES[who]
			var y := 176.0 + i * 150.0
			var left := i % 2 == 0
			var cx := 84.0 if left else 636.0
			M3.avatar(c, h, Vector2(cx, y + 56), 40.0, Data.RARITY_COLORS[h.rarity], _t)
			var br := Rect2(144 if left else 32, y + 8, 544, 120)
			M3.glass_card(c, br, false, 16.0)
			M3.text(c, br.position + Vector2(20, 34), String(h.name).split(" ")[0], 22, Data.RARITY_COLORS[h.rarity].lightened(0.3), true)
			M3.para(c, br.position + Vector2(20, 70), String(lines[i][1]), 24, UI.TEXT, 504, 1.3)
		M3.text(c, Vector2(0, c.size.y - 24), "Touche pour fermer", 20, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)
