class_name ItemDetailScreen
extends ItemScreen
## Détail d'un objet (maquette BR) : en-tête (rareté, lien, puissance), statistiques, niveau, améliorer, changer de héros, recycler.
## Le cadenas de la barre du haut verrouille l'objet (il ne peut plus être recyclé).

signal changed
signal who_requested(id: int)

var _id := 0
var _body: Control
var _up: Button
var _lock: Button
var _swap: Button
var _rec: Button


func _init(item_id: int) -> void:
	_id = item_id
	var it: Dictionary = Game.item_by_id(item_id)
	super._init(String(it.get("name", "Objet")), [["", func(): pass], ["⋮", func(): _menu()]])
	for ch in st.get_node("TopBar").get_children():
		if ch is Button and (ch as Button).text == "":
			_lock = ch
	_lock.pressed.connect(func():
		var i2 := Game.item_by_id(_id)
		i2.locked = not i2.locked
		Game.save_game()
		changed.emit()
		_refresh())
	var lk := Control.new()
	lk.size = Vector2(96, 96)
	lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lk.draw.connect(func():
		var i3 := Game.item_by_id(_id)
		M3.lock(lk, Vector2(48, 50), UI.GOLD if bool(i3.get("locked", false)) else UI.MUTED, 1.4))
	_lock.add_child(lk)
	_body = canvas(Vector2(0, 0), Vector2(720, 1100), _draw_body)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_up = button("", "main", Vector2(32, UI.H - 32 - 96 - 16 - 104), Vector2(656, 104), 32)
	_up.pressed.connect(func():
		if Game.upgrade_item(_id):
			Game.save_game()
			Sfx.play("chest", -4.0)
			changed.emit()
		_refresh())
	_swap = button("", "ghost", Vector2(32, UI.H - 32 - 96), Vector2(320, 96), 26)
	_swap.pressed.connect(func():
		who_requested.emit(_id)
		close())
	_rec = button("", "outline", Vector2(368, UI.H - 32 - 96), Vector2(320, 96), 26)
	_rec.pressed.connect(func():
		var res: Dictionary = Game.recycle_items([_id])
		M3.toast(self, "Recyclé · +%d éclats" % int(res.shards), Color("7fdcff"))
		Game.save_game()
		changed.emit()
		close())
	_refresh()


func _menu() -> void:
	var it := Game.item_by_id(_id)
	var items: Array = [["À qui l'équiper ?", func():
		who_requested.emit(_id)
		close()]]
	if it.on != "":
		items.append(["Retirer du héros", func():
			Game.unequip(_id)
			M3.toast(self, "Objet retiré", UI.MUTED)
			Game.save_game()
			changed.emit()
			_refresh()])
	M3.menu(st, Vector2(704, 96), items)


func _refresh() -> void:
	var it: Dictionary = Game.item_by_id(_id)
	if it.is_empty():
		close()
		return
	var cap: int = Game.item_cap(it)
	var at_cap: bool = int(it.level) >= cap
	var cost: int = Items.upgrade_cost(it)
	_up.text = "Niveau maximum atteint" if at_cap else "Améliorer · %s ¢" % UI.num(cost)
	_up.disabled = at_cap or Game.credits < cost
	_swap.text = "Équiper sur un héros" if it.bound == "" else ("Changer de héros" if int(it.moves) < 1 else "Changer · %d ¢" % Items.REBIND_COST)
	_rec.text = "Recycler · %d éclats" % int(Items.RECYCLE_SHARDS[it.rarity])
	_rec.disabled = bool(it.locked) or it.on != ""
	_lock.queue_redraw()
	for ch in _lock.get_children():
		(ch as Control).queue_redraw()
	_body.queue_redraw()


func _draw_body(c: Control) -> void:
	var it: Dictionary = Game.item_by_id(_id)
	if it.is_empty():
		return
	var col := ItemUI.color(it.rarity)
	ItemUI.tile(c, Rect2(32, 120, 168, 168), it, true)
	var fb := UI.bold_font()
	var x := 232.0
	for ch in "%s %s" % [String(Items.SLOT_NAMES[it.slot]).to_upper(), String(Data.RARITY_NAMES[it.rarity]).to_upper()]:
		c.draw_string(fb, Vector2(x, 168), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(24), col)
		x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(24)).x + 2.5
	var who := ("Lié à %s" % String(Data.HEROES[it.bound].name).split(" ")[0]) if it.bound != "" else "Non lié"
	if it.set != "":
		var cnt: int = int(Items.set_counts(Game.hero_items(it.bound)).get(it.set, 0)) if it.bound != "" else 0
		who += " · Ensemble %s %d/4" % [Items.SETS[it.set].name, cnt]
	M3.text(c, Vector2(232, 210), who, 26, UI.MUTED, false, 456)
	M3.text(c, Vector2(232, 256), "Puissance", 26, UI.TEXT)
	M3.text(c, Vector2(232 + M3.text_w("Puissance ", 26), 256), "+" + UI.num(Items.power(it)), 26, UI.TEXT, true)
	# statistiques
	var rows: Array = []
	var s := Items.stats(it)
	match it.slot:
		"arme":
			rows.append(["ATQ", "+%d" % int(round(s.atk))])
		"armure":
			rows.append(["PV", "+%d" % int(round(s.hp))])
			rows.append(["DÉF", "+%d" % int(round(s.def))])
		"module":
			rows.append(["Pouvoir", "+%d %%" % int(round(s.skill * 100.0))])
		_:
			rows.append(["PV", "+%d" % int(round(s.hp))])
	for sub in it.subs:
		rows.append([String(Items.BONUS[sub.k][0]), "+%s %%" % Items._num(float(sub.v))])
	if Items.rarity_index(it.rarity) >= 4:
		rows.append(["Effet de pouvoir", "+%d %%" % int(round((0.06 if it.rarity == "legendaire" else 0.10) * 100.0))])
	var y := 320.0
	for r in rows:
		M3.row(c, Rect2(32, y, 656, 96))
		M3.text(c, Vector2(64, y + 58), r[0], 28, UI.TEXT, true)
		M3.text(c, Vector2(0, y + 58), r[1], 28, UI.TEXT, true, 656, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 108.0
	# niveau
	var cap: int = Game.item_cap(it)
	var mx: int = Items.max_level(it)
	var lr := Rect2(32, y + 8, 656, 128)
	M3.card(c, lr)
	M3.text(c, lr.position + Vector2(32, 52), "Niveau %d / %d" % [int(it.level), mx], 26, UI.TEXT)
	var note := ""
	if it.bound != "" and cap < mx:
		note = "plafonné par %s" % String(Data.HEROES[it.bound].name).split(" ")[0]
	elif int(it.level) >= mx:
		note = "niveau maximum"
	M3.text(c, lr.position + Vector2(0, 52), note, 24, UI.MUTED, false, 624, HORIZONTAL_ALIGNMENT_RIGHT)
	M3.bar(c, Rect2(lr.position + Vector2(32, 80), Vector2(592, 12)), float(it.level) / float(mx))
