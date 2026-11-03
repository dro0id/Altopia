class_name ItemDetailScreen
extends ItemScreen
## Détail d'un objet (maquette Z) : rareté, niveau, bonus, ensemble, amélioration, changement de héros, recyclage.

signal changed
signal who_requested(id: int)

var _id := 0
var _body: Control
var _up: Button
var _lock: HudButton
var _swap: Button
var _rec: Button


func _init(item_id: int) -> void:
	super._init("Objet")
	_id = item_id
	_body = canvas(Vector2(0, 0), Vector2(720, 1280), _draw_body)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock = HudButton.new()
	_lock.font_size = 22
	_lock.bold = true
	_lock.radius = 24.0
	_lock.size = Vector2(190, 56)
	_lock.position = Vector2(498, 36)
	_lock.pressed.connect(func():
		var it := Game.item_by_id(_id)
		it.locked = not it.locked
		Game.save_game()
		changed.emit()
		_refresh())
	st.add_child(_lock)
	_up = button("", "main", Vector2(32, 1040), Vector2(656, 104), 32)
	_up.pressed.connect(func():
		if Game.upgrade_item(_id):
			Game.save_game()
			Sfx.play("chest", -4.0)
			changed.emit()
		_refresh())
	_swap = button("", "ghost", Vector2(32, 1160), Vector2(320, 96), 24)
	_swap.pressed.connect(func():
		who_requested.emit(_id)
		close())
	_rec = button("", "ghost", Vector2(368, 1160), Vector2(320, 96), 26)
	_rec.pressed.connect(func():
		var it := Game.item_by_id(_id)
		if it.on != "":
			Game.unequip(_id)
		else:
			Game.recycle_items([_id])
		Game.save_game()
		changed.emit()
		close())
	_refresh()


func _refresh() -> void:
	var it: Dictionary = Game.item_by_id(_id)
	if it.is_empty():
		close()
		return
	var cap: int = Game.item_cap(it)
	var at_cap: bool = int(it.level) >= cap
	var cost: int = Items.upgrade_cost(it)
	if at_cap:
		UI.set_button_parts(_up, ["Niveau maximum atteint"], 32, UI.DARK)
	else:
		UI.set_button_parts(_up, ["Améliorer ·", UI.icon("coin"), UI.num(cost)], 32, UI.DARK)
	_up.disabled = at_cap or Game.credits < cost
	var swap_txt := "Changer de héros · %s" % ("gratuit" if int(it.moves) < 1 else "¢ %d" % Items.REBIND_COST)
	if it.bound == "":
		swap_txt = "Équiper sur un héros"
	UI.set_button_parts(_swap, [swap_txt], 24, Color("e8eefc"))
	if it.on != "":
		UI.set_button_parts(_rec, ["Retirer"], 26, Color("e8eefc"))
	else:
		UI.set_button_parts(_rec, ["Recycler ·", UI.icon("shard"), str(int(Items.RECYCLE_SHARDS[it.rarity]))], 26, Color("ff9b9b"))
	_rec.disabled = bool(it.locked) and it.on == ""
	_lock.set_texts("🔒 Verrouillé" if it.locked else "Verrouiller")
	_lock.text_color = UI.GOLD if it.locked else UI.TEXT
	_lock.queue_redraw()
	_body.queue_redraw()


func _draw_body(c: Control) -> void:
	var it: Dictionary = Game.item_by_id(_id)
	if it.is_empty():
		return
	var col := ItemUI.color(it.rarity)
	var f := ThemeDB.fallback_font
	var fb := UI.bold_font()
	UI.draw_gradient_box(c, Rect2(32, 148, 656, 228), 32.0, Color(col.r * 0.2, col.g * 0.16, col.b * 0.3, 1.0).lerp(UI.PANEL, 0.2), UI.PANEL, col, 3.0)
	ItemUI.tile(c, Rect2(60, 176, 168, 168), it, true)
	var x := 256.0
	var lab_txt := "%s %s" % [String(Items.SLOT_NAMES[it.slot]).to_upper(), String(Data.RARITY_NAMES[it.rarity]).to_upper()]
	for ch in lab_txt:
		c.draw_string(fb, Vector2(x, 206), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 2.5
	c.draw_string(fb, Vector2(256, 250), it.name, HORIZONTAL_ALIGNMENT_LEFT, 420.0, 34, Color.WHITE)
	var who := "Lié à %s" % String(Data.HEROES[it.bound].name).split(" ")[0] if it.bound != "" else "Non lié"
	if it.set != "":
		var cnt: int = int(Items.set_counts(Game.hero_items(it.bound)).get(it.set, 0)) if it.bound != "" else 0
		who += " · Ensemble %s %d/4" % [Items.SETS[it.set].name, cnt]
	c.draw_string(f, Vector2(256, 286), who, HORIZONTAL_ALIGNMENT_LEFT, 420.0, 22, UI.MUTED)
	var cap: int = Game.item_cap(it)
	var mx: int = Items.max_level(it)
	c.draw_style_box(UI.box(UI.LINE2, Color(0, 0, 0, 0), 8, 0), Rect2(256, 308, 400, 16))
	c.draw_style_box(UI.box(col, Color(0, 0, 0, 0), 8, 0), Rect2(256, 308, maxf(16.0, 400.0 * float(it.level) / float(mx)), 16))
	c.draw_string(f, Vector2(256, 350), "Niveau %d / %d" % [int(it.level), mx], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.MUTED)
	# lignes de statistiques
	var rows: Array = []
	var s := Items.stats(it)
	var nxt: Dictionary = it.duplicate(true)
	nxt.level = int(it.level) + 1
	var s2 := Items.stats(nxt)
	var up_ok: bool = int(it.level) < cap
	match it.slot:
		"arme":
			rows.append(["Principal · ATQ", "+%d" % int(round(s.atk)), "+%d" % int(round(s2.atk)) if up_ok else "", s.atk, s2.atk])
		"armure":
			rows.append(["Principal · PV", "+%d" % int(round(s.hp)), "+%d" % int(round(s2.hp)) if up_ok else "", s.hp, s2.hp])
			rows.append(["Principal · DÉF", "+%d" % int(round(s.def)), "", 0.0, 0.0])
		"module":
			rows.append(["Principal · pouvoir", "+%d %%" % int(round(Items.stats(it).skill * 100.0)), "", 0.0, 0.0])
		_:
			rows.append(["Principal · PV", "+%d" % int(round(s.hp)), "+%d" % int(round(s2.hp)) if up_ok else "", s.hp, s2.hp])
	for sub in it.subs:
		rows.append([String(Items.BONUS[sub.k][0]), "+%s %%" % Items._num(float(sub.v)), "", 0.0, 0.0])
	if Items.rarity_index(it.rarity) >= 4:
		rows.append(["Effet de pouvoir", "+%d %%" % int(round((0.06 if it.rarity == "legendaire" else 0.10) * 100.0)), "", 0.0, 0.0])
	var y := 421.0
	for r in rows:
		c.draw_string(f, Vector2(32, y + 8), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.MUTED)
		if r[2] != "":
			c.draw_string(fb, Vector2(0, y + 8), "%s → %s" % [r[1], r[2]], HORIZONTAL_ALIGNMENT_RIGHT, 560.0, 26, UI.RED if it.slot == "arme" else UI.GREEN)
			ItemUI.delta(c, 688.0, y + 8.0, float(r[4]) - float(r[3]), 22)
		else:
			c.draw_string(fb, Vector2(0, y + 8), r[1], HORIZONTAL_ALIGNMENT_RIGHT, 688.0, 26, Color("e8eefc"))
		c.draw_line(Vector2(32, y + 32), Vector2(688, y + 32), UI.LINE2, 2.0)
		y += 62.0
	c.draw_string(f, Vector2(32, y + 16), "Chaque niveau renforce toutes les statistiques.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.MUTED)
	# carte d'amélioration
	var cy := 706.0
	c.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 24, 0), Rect2(32, cy, 656, 140))
	var at_cap: bool = int(it.level) >= cap
	c.draw_string(fb, Vector2(56, cy + 46), "Améliorer au niveau %d" % (int(it.level) + 1) if not at_cap else "Niveau maximum", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	if not at_cap:
		var chip_w := 150.0
		c.draw_style_box(UI.box(UI.HUD, UI.LINE, 24, 0), Rect2(688 - 24 - chip_w, cy + 18, chip_w, 48))
		c.draw_texture(UI.icon("coin"), Vector2(688 - 24 - chip_w + 16, cy + 28))
		c.draw_string(fb, Vector2(688 - 24 - chip_w + 52, cy + 52), UI.num(Items.upgrade_cost(it)), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var who_cap := ""
	if it.bound != "" and cap < mx:
		who_cap = "Niveau maximum : celui de %s (%d). Monte d'abord le héros." % [String(Data.HEROES[it.bound].name).split(" ")[0], cap]
	elif at_cap:
		who_cap = "Cet objet ne peut pas monter plus haut."
	else:
		who_cap = "Niveau maximum de cet objet : %d." % mx
	c.draw_string(f, Vector2(56, cy + 90), who_cap, HORIZONTAL_ALIGNMENT_LEFT, 600.0, 22, UI.MUTED)
