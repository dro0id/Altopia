extends Control
## Interface : 4 onglets (Capitaine, Équipage, Expéditions, Vaisseau), construite en code.

const Data = preload("res://scripts/game_data.gd")
const Starfield = preload("res://scripts/starfield.gd")
const Chibi = preload("res://scripts/chibi.gd")
const SpaceView = preload("res://scripts/space_view.gd")
const BattleView = preload("res://scripts/battle_view.gd")

const COL_CARD := Color(0.07, 0.10, 0.22, 0.88)
const COL_TEXT_DIM := Color(0.62, 0.70, 0.88)
const COL_ACCENT := Color(0.49, 0.95, 1.0)
const COL_GOOD := Color(0.5, 1.0, 0.6)

var _res_labels := {}
var _rate_label: Label
var _pages := {}
var _tab_buttons := {}
var _dirty := true
var _timer := 0.0
var _press_pos := Vector2.ZERO
var _dragged := false       # le doigt a glissé : le relâchement ne doit rien acheter
var _pending_battle := {}   # emplacement -> un combat vient de se terminer, à animer

# Capitaine
var _cap_chibi: Control
var _cap_name: Label
var _cap_level: Label
var _cap_xp: ProgressBar
var _cap_stats: Label
var _cap_train: Button
var _slot_cards := {}       # emplacement d'équipement -> widgets
var _inv_box: VBoxContainer
var _inv_title: Label
var _inv_sig := ""
var _recycle_btn: Button
var _useless_btn: Button
var _afk_label: Label
# Équipage
var _hero_ui := {}
var _recruit_btn: Button
var _recruit_label: Label
var _collection_label: Label
var _synergy_label: Label
# Expéditions
var _slot_ui: Array = []
var _next_label: Label
# Vaisseau
var _upgrade_ui := {}


func _ready() -> void:
	_build_ui()
	GameState.changed.connect(func(): _dirty = true)
	GameState.battle_finished.connect(_on_battle_finished)
	_show_tab("captain")
	_refresh()
	if not GameState.last_offline_report.is_empty():
		_show_offline_report(GameState.last_offline_report)


func _input(event: InputEvent) -> void:
	var pressed_now := false
	var moved_to := Vector2.ZERO
	var is_motion := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed_now = true
		_press_pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed_now = true
		_press_pos = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		is_motion = true
		moved_to = event.position
	elif event is InputEventScreenDrag:
		is_motion = true
		moved_to = event.position
	if pressed_now:
		_dragged = false
	elif is_motion and moved_to.distance_to(_press_pos) > 18.0:
		_dragged = true


## Enveloppe une action de bouton : ignorée si le geste était un glissement (défilement).
func _tap(action: Callable) -> Callable:
	return func():
		if not _dragged:
			action.call()


func _process(delta: float) -> void:
	_timer += delta
	if _dirty and _timer >= 0.1:
		_timer = 0.0
		_dirty = false
		_refresh()


## ---------- Construction ----------

func _build_ui() -> void:
	add_child(Starfield.new())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	_build_header(root)

	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(holder)
	for id in ["captain", "crew", "exp", "ship"]:
		_pages[id] = _make_page(holder)
	_build_captain_page(_pages["captain"])
	_build_crew_page(_pages["crew"])
	_build_expedition_page(_pages["exp"])
	_build_ship_page(_pages["ship"])

	_build_tabs(root)


func _build_header(parent: Control) -> void:
	var title := _label(parent, "ALTOPIA", 44, COL_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for id in Data.RES_ORDER:
		var l := _label(grid, "", 28)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_res_labels[id] = l
	_rate_label = _label(parent, "", 20, COL_TEXT_DIM)
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _make_page(holder: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	holder.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	box.set_meta("scroll", scroll)
	return box


func _build_tabs(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	parent.add_child(bar)
	var group := ButtonGroup.new()
	for entry in [["captain", "Capitaine"], ["crew", "Équipage"], ["exp", "Expéditions"], ["ship", "Vaisseau"]]:
		var b := Button.new()
		b.text = entry[1]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_stylebox_override("pressed", _flat(Color(0.16, 0.32, 0.62), 10))
		b.add_theme_stylebox_override("hover_pressed", _flat(Color(0.16, 0.32, 0.62), 10))
		b.pressed.connect(_show_tab.bind(entry[0]))
		bar.add_child(b)
		_tab_buttons[entry[0]] = b


func _build_captain_page(page: VBoxContainer) -> void:
	var card := _card_h(page)
	_cap_chibi = Chibi.new()
	_cap_chibi.custom_minimum_size = Vector2(190, 230)
	_cap_chibi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_child(_cap_chibi)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	card.add_child(right)
	_cap_name = _label(right, "", 30, COL_ACCENT)
	_cap_level = _label(right, "", 24)
	_cap_xp = _bar(right, 16, COL_GOOD)
	_cap_stats = _label(right, "", 21, COL_TEXT_DIM)
	_cap_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap_train = _button(right, "", 66)
	_cap_train.add_theme_font_size_override("font_size", 21)
	_cap_train.pressed.connect(_tap(func(): GameState.train_captain()))

	var look_row := HBoxContainer.new()
	look_row.add_theme_constant_override("separation", 8)
	page.add_child(look_row)
	for entry in [["suit", "Combinaison"], ["hair", "Cheveux"], ["style", "Coupe"]]:
		var b := _button(look_row, "Changer : " + entry[1], 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_tap(func(): GameState.cycle_look(entry[0])))

	_label(page, "Équipement", 28, COL_ACCENT)
	for slot in Data.EQUIP_SLOTS:
		var c := _card(page)
		var title := _label(c, "", 23)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stats := _label(c, "", 19, COL_TEXT_DIM)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := _button(c, "Retirer", 54)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_tap(func(): GameState.unequip(slot)))
		_slot_cards[slot] = {"title": title, "stats": stats, "btn": b}
	var best := _button(page, "Équiper automatiquement le meilleur", 66)
	best.add_theme_font_size_override("font_size", 20)
	best.pressed.connect(_tap(func(): GameState.auto_equip()))
	_recycle_btn = _button(page, "", 62)
	_recycle_btn.add_theme_font_size_override("font_size", 19)
	_recycle_btn.pressed.connect(_tap(func(): GameState.cycle_auto_recycle()))
	_useless_btn = _button(page, "Recycler tous les objets inutiles", 62)
	_useless_btn.add_theme_font_size_override("font_size", 19)
	_useless_btn.pressed.connect(_tap(func(): GameState.recycle_useless()))
	_inv_title = _label(page, "", 28, COL_ACCENT)
	_inv_box = VBoxContainer.new()
	_inv_box.add_theme_constant_override("separation", 10)
	_inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_inv_box)


func _build_crew_page(page: VBoxContainer) -> void:
	_collection_label = _label(page, "", 30, COL_ACCENT)
	_synergy_label = _label(page, "", 21, COL_TEXT_DIM)
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var afk_card := _card(page)
	_afk_label = _label(afk_card, "", 20, COL_GOOD)
	_afk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recruit_btn = _button(page, "", 100)
	_recruit_btn.add_theme_font_size_override("font_size", 26)
	_recruit_btn.pressed.connect(_tap(func(): GameState.recruit()))
	_recruit_label = _label(page, "", 22, COL_ACCENT)
	_recruit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for id in Data.HERO_ORDER:
		var card := _card_h(page)
		var portrait: Control = Chibi.new()
		portrait.custom_minimum_size = Vector2(112, 112)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.add_child(portrait)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 4)
		card.add_child(right)
		var name_l := _label(right, "", 26)
		var stats_l := _label(right, "", 20, COL_TEXT_DIM)
		stats_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var xp := _bar(right, 16, COL_GOOD)
		var where_l := _label(right, "", 19, COL_TEXT_DIM)
		where_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var train := _button(right, "", 62)
		train.add_theme_font_size_override("font_size", 21)
		train.pressed.connect(_tap(func(): GameState.train(id)))
		_hero_ui[id] = {"portrait": portrait, "name": name_l, "stats": stats_l, "xp": xp,
			"where": where_l, "train": train}


func _build_expedition_page(page: VBoxContainer) -> void:
	_label(page, "Expéditions", 30, COL_ACCENT)
	for i in Data.MAX_SLOTS:
		var card := _card(page)
		var view := SpaceView.new()
		card.add_child(view)
		var bv := BattleView.new()
		bv.visible = false
		card.add_child(bv)
		var title := _label(card, "", 26)
		var bar := _bar(card, 30, COL_ACCENT)
		var status := _label(card, "", 21, COL_TEXT_DIM)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var station_row := HBoxContainer.new()
		station_row.add_theme_constant_override("separation", 8)
		card.add_child(station_row)
		var members: Array = []
		for k in Data.CREW_ORDER.size():
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 2)
			station_row.add_child(col)
			var cls: Dictionary = Data.CREW[Data.CREW_ORDER[k]]
			var lbl := _label(col, "Poste " + String(cls.name), 18, cls.color)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var por: Control = Chibi.new()
			por.custom_minimum_size = Vector2(0, 100)
			por.role = Data.CREW_ORDER[k]
			col.add_child(por)
			var opt := OptionButton.new()
			opt.custom_minimum_size = Vector2(0, 62)
			opt.add_theme_font_size_override("font_size", 19)
			opt.fit_to_longest_item = false
			opt.clip_text = true
			opt.mouse_filter = Control.MOUSE_FILTER_PASS         # un glissement dessus fait défiler la page
			opt.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			opt.get_popup().about_to_popup.connect(func():
				if _dragged:     # le doigt a glissé : ce n'était pas un tap, on referme la liste
					opt.get_popup().hide.call_deferred())
			opt.item_selected.connect(_on_station_pick.bind(i, k))
			col.add_child(opt)
			members.append({"portrait": por, "opt": opt, "ids": []})
		var auto_sq := _button(card, "Placer automatiquement le meilleur équipage", 62)
		auto_sq.add_theme_font_size_override("font_size", 21)
		auto_sq.pressed.connect(_tap(func(): GameState.auto_squad(i)))
		var auto := CheckButton.new()
		auto.text = "Relance automatique"
		auto.add_theme_font_size_override("font_size", 22)
		auto.toggled.connect(func(v: bool): GameState.set_auto(i, v))
		card.add_child(auto)
		var replay := _button(card, "Revoir le dernier combat", 62)
		replay.add_theme_font_size_override("font_size", 21)
		replay.pressed.connect(_tap(func():
			if not GameState.slots[i].battle.is_empty():
				bv.play(GameState.slots[i].battle)))
		var recall := _button(card, "Rappeler le vaisseau", 70)
		recall.pressed.connect(_tap(func(): GameState.recall(i)))
		var dest_btns := {}
		for d in Data.DEST_ORDER:
			var b := _button(card, "", 120)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(_tap(func(): GameState.launch(i, d)))
			dest_btns[d] = b
		var last := _label(card, "", 20, COL_ACCENT)
		last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var log := _label(card, "", 18, COL_TEXT_DIM)
		log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_slot_ui.append({
			"card": card, "view": view, "bv": bv, "replay": replay, "title": title, "bar": bar, "status": status,
			"members": members, "sig": "", "auto": auto, "auto_sq": auto_sq, "recall": recall, "dest": dest_btns,
			"last": last, "log": log,
		})
	_next_label = _label(page, "", 22, COL_TEXT_DIM)
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_ship_page(page: VBoxContainer) -> void:
	_label(page, "Vaisseau", 30, COL_ACCENT)
	for id in Data.UPGRADE_ORDER:
		var card := _card(page)
		var name_l := _label(card, "", 27)
		var desc_l := _label(card, "", 21, COL_TEXT_DIM)
		var b := _button(card, "", 100)
		b.pressed.connect(_tap(func(): GameState.buy_upgrade(id)))
		_upgrade_ui[id] = {"name": name_l, "desc": desc_l, "btn": b}


## ---------- Helpers de widgets ----------

func _label(parent: Node, text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, min_h: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", 23)
	b.mouse_filter = Control.MOUSE_FILTER_PASS     # un glissement sur le bouton fait défiler la page
	parent.add_child(b)
	return b


func _bar(parent: Node, height: int, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = 1.0
	bar.add_theme_stylebox_override("fill", _flat(color, 8))
	bar.add_theme_stylebox_override("background", _flat(Color(0.1, 0.14, 0.28), 8))
	parent.add_child(bar)
	return bar


func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb


func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.border_color = Color(0.25, 0.4, 0.8, 0.5)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS    # laisse le doigt faire défiler la page
	parent.add_child(p)
	return p


func _card(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel(parent).add_child(v)
	return v


func _card_h(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_panel(parent).add_child(h)
	return h


func _show_tab(tab: String) -> void:
	for id in _pages:
		_pages[id].get_meta("scroll").visible = (id == tab)
	_tab_buttons[tab].button_pressed = true


func _on_battle_finished(slot_i: int) -> void:
	# On n'anime que si le joueur regarde l'onglet Expéditions.
	_pending_battle[slot_i] = _pages["exp"].get_meta("scroll").visible


func _on_station_pick(index: int, slot_i: int, station_i: int) -> void:
	var ids: Array = _slot_ui[slot_i].members[station_i].ids
	GameState.set_squad_member(slot_i, station_i, ids[index] if index < ids.size() else "")


## ---------- Rafraîchissement ----------

func _refresh() -> void:
	for id in Data.RES_ORDER:
		_res_labels[id].text = "%s  %s" % [Data.RES_NAMES[id], Data.fmt(GameState.res[id])]
	var prod := GameState.production_per_sec()
	_rate_label.text = "AFK/h : +%s cr  +%s min.  +%s én.  +%s don.    Exp. : %d" % [
		Data.fmt(prod.credits * 3600.0), Data.fmt(prod.minerals * 3600.0), Data.fmt(prod.energy * 3600.0),
		Data.fmt(prod.data * 3600.0), GameState.expeditions_done]
	_refresh_captain()
	_refresh_crew()
	_refresh_expeditions()
	_refresh_ship()


func _stat_text(st: Dictionary, sign: String = "") -> String:
	var parts: Array[String] = []
	for entry in [["hp", "PV"], ["atk", "ATQ"], ["def", "DÉF"], ["spd", "VIT"]]:
		if st.get(entry[0], 0.0) > 0.4:
			parts.append("%s %s%d" % [entry[1], sign, int(round(st[entry[0]]))])
	return "  ".join(parts)


func _refresh_captain() -> void:
	var cap: Dictionary = GameState.captain
	_cap_chibi.setup_captain(cap.look)
	_cap_name.text = cap.name
	_cap_level.text = "Niveau %d / %d" % [cap.level, Data.CAPTAIN_MAX_LEVEL]
	_cap_xp.value = float(cap.xp) / float(Data.xp_needed(cap.level))
	var cs := GameState.captain_stats(0)
	_cap_stats.text = "PV %d   ATQ %d\nDÉF %d   VIT %d\nÉquipement : %s\nÉquipage : %s" % [
		cs.hp, cs.atk, cs.def, cs.spd, _stat_text(cs.gear, "+"), _stat_text(cs.crew, "+")]
	if cap.level >= Data.CAPTAIN_MAX_LEVEL:
		_cap_train.text = "Niveau maximum"
		_cap_train.disabled = true
	else:
		var tc := GameState.captain_train_cost()
		_cap_train.text = "Entraîner (+1 niveau) — %s crédits" % Data.fmt(tc)
		_cap_train.disabled = GameState.res["credits"] < tc
	for slot in Data.EQUIP_SLOTS:
		var u: Dictionary = _slot_cards[slot]
		var it := GameState.equipped_item(slot)
		if it.is_empty():
			u.title.text = "%s : aucun" % Data.EQUIP[slot].name
			u.title.add_theme_color_override("font_color", COL_TEXT_DIM)
			u.stats.text = "Emplacement vide : looter ou équiper un objet."
			u.btn.visible = false
		else:
			u.title.text = "%s : %s — %s (niv. %d)" % [Data.EQUIP[slot].name, it.name, Data.ITEM_RARITY[it.rarity].name, it.ilvl]
			u.title.add_theme_color_override("font_color", Data.ITEM_RARITY[it.rarity].color)
			u.stats.text = _item_text(it)
			u.btn.visible = true
	_recycle_btn.text = "Recyclage automatique : %s" % GameState.auto_recycle_label()
	_refresh_inventory()


func _affix_text(a: Dictionary) -> String:
	var d: Dictionary = Data.AFFIXES[a.k]
	return "+%s%s %s" % [String.num(a.v, 1), d.unit, d.name]


## Stats plates puis une ligne par bonus aléatoire.
func _item_text(it: Dictionary) -> String:
	var lines: Array[String] = [_stat_text(GameState.item_stats(it), "+")]
	for a in it.affixes:
		lines.append(_affix_text(a))
	return "\n".join(lines)


func _refresh_inventory() -> void:
	var sig_parts: Array[String] = []
	for it in GameState.items:
		sig_parts.append("%d.%d.%d" % [it.id, it.ilvl, 1 if GameState.equipped[it.slot] == it.id else 0])
	var sig := ",".join(sig_parts)
	_inv_title.text = "Inventaire (%d / %d)" % [GameState.items.size(), Data.INVENTORY_MAX]
	if sig == _inv_sig:
		return
	_inv_sig = sig
	for c in _inv_box.get_children():
		c.queue_free()
	var sorted: Array = GameState.items.duplicate()
	sorted.sort_custom(func(a, b):
		if a.slot != b.slot:
			return Data.EQUIP_SLOTS.find(a.slot) < Data.EQUIP_SLOTS.find(b.slot)
		return GameState.item_power(a) > GameState.item_power(b))
	for it in sorted:
		var is_eq: bool = GameState.equipped[it.slot] == it.id
		var row := _card_h(_inv_box)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var rar: Dictionary = Data.ITEM_RARITY[it.rarity]
		var t := _label(info, "%s%s" % [it.name, " (équipé)" if is_eq else ""], 20, rar.color)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(info, "%s · %s · niv. %d" % [Data.EQUIP[it.slot].name, rar.name, it.ilvl], 16, COL_TEXT_DIM)
		var d := _label(info, _item_text(it), 16, Color(0.85, 0.92, 1.0))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not is_eq:
			var delta := GameState.power_delta(it)
			_label(info, ("▲ +%d puissance" % delta) if delta > 0.0 else ("▼ %d puissance" % delta), 17,
				COL_GOOD if delta > 0.0 else Color(1.0, 0.55, 0.5))
		var btns := VBoxContainer.new()
		btns.custom_minimum_size = Vector2(200, 0)
		row.add_child(btns)
		if not is_eq:
			var eq := _button(btns, "Équiper", 54)
			eq.add_theme_font_size_override("font_size", 19)
			var item_id: int = it.id
			eq.pressed.connect(_tap(func(): GameState.equip(item_id)))
			var sc := _button(btns, "Recycler +%s cr" % Data.fmt(GameState.scrap_value(it)), 54)
			sc.add_theme_font_size_override("font_size", 16)
			sc.pressed.connect(_tap(func(): GameState.scrap(item_id)))


func _refresh_crew() -> void:
	_collection_label.text = "Équipage : %d / %d cartes" % [GameState.heroes.size(), Data.HERO_ORDER.size()]
	_synergy_label.text = "L'équipage, ce sont des objets à placer aux postes de vos vaisseaux : ils renforcent le Capitaine et rapportent des crédits. Synergie x%.2f (paires de classes +10 %%, les 3 classes +25 %%)." % GameState.synergy_multiplier()
	var prod := GameState.production_per_sec()
	_afk_label.text = "AFK — l'équipage aux postes travaille même hors ligne\n+%s crédits/h   +%s minerais/h\n+%s énergie/h   +%s données/h\nRendement hors ligne : %d %%   ·   Durée max comptée : %s" % [
		Data.fmt(prod.credits * 3600.0), Data.fmt(prod.minerals * 3600.0), Data.fmt(prod.energy * 3600.0),
		Data.fmt(prod.data * 3600.0), int(round(GameState.offline_efficiency() * 100.0)),
		Data.fmt_time(GameState.offline_cap_seconds())]
	var cost := GameState.recruit_cost()
	_recruit_btn.text = "Recruter un équipier — %s crédits" % Data.fmt(cost)
	_recruit_btn.disabled = GameState.res["credits"] < cost
	var lr: Dictionary = GameState.last_recruit
	if lr.is_empty():
		_recruit_label.text = "Doublon = +1 étoile (stats +20 %). Épique : 5 % de chance."
	else:
		var hd: Dictionary = Data.HEROES[lr.id]
		var what := "NOUVELLE carte" if lr.new else ("+1 étoile" if not lr.maxed else "doublon max (remboursé en partie)")
		_recruit_label.text = "Dernier recrutement : %s (%s) — %s" % [hd.name, Data.RARITY[hd.rarity].name, what]
	for id in Data.HERO_ORDER:
		var u: Dictionary = _hero_ui[id]
		var tpl: Dictionary = Data.HEROES[id]
		var cls: Dictionary = Data.CREW[tpl["class"]]
		if not GameState.heroes.has(id):
			u.portrait.role = tpl["class"]
			u.portrait.setup_empty(tpl["class"])
			u.name.text = "???  —  %s %s" % [Data.RARITY[tpl.rarity].name, cls.name]
			u.name.add_theme_color_override("font_color", COL_TEXT_DIM)
			u.stats.text = "Carte non recrutée"
			u.xp.visible = false
			u.where.text = ""
			u.train.visible = false
			continue
		var h: Dictionary = GameState.heroes[id]
		var st := Data.hero_stats(id, h.level, h.stars)
		u.portrait.setup_crew(id, h.stars)
		u.name.text = "%s  —  niv. %d" % [tpl.name, h.level]
		u.name.add_theme_color_override("font_color", Data.RARITY[tpl.rarity].color)
		u.stats.text = "%s · %s\nPV %d  ATQ %d  DÉF %d  VIT %d" % [
			cls.name, Data.RARITY[tpl.rarity].name, st.hp, st.atk, st.def, st.spd]
		u.xp.visible = true
		u.xp.value = float(h.xp) / float(Data.xp_needed(h.level))
		var slot := GameState.hero_slot(id)
		u.where.text = ("Au poste (vaisseau %d) : %s" % [slot + 1, _hero_prod_text(id)]) if slot >= 0 else "Au repos : placez-le à un poste pour produire (%s)" % _hero_prod_text(id)
		u.train.visible = true
		if h.level >= Data.MAX_LEVEL:
			u.train.text = "Niveau maximum"
			u.train.disabled = true
		else:
			var tc := GameState.train_cost(id)
			u.train.text = "Entraîner (+1 niveau) — %s crédits" % Data.fmt(tc)
			u.train.disabled = GameState.res["credits"] < tc


func _hero_prod_text(id: String) -> String:
	var cls: String = Data.HEROES[id]["class"]
	var m := GameState.crew_prod_mult(id) * GameState.synergy_multiplier()
	var parts: Array[String] = []
	for r in Data.CREW_PROD[cls]:
		parts.append("+%s %s/h" % [Data.fmt(Data.CREW_PROD[cls][r] * m), String(Data.RES_NAMES[r]).to_lower()])
	return "  ".join(parts)


func _crew_signature() -> String:
	var parts: Array[String] = []
	for id in GameState.hero_order:
		parts.append("%s%d" % [id, GameState.heroes[id].level])
	return ",".join(parts)


func _refresh_expeditions() -> void:
	var count := GameState.slot_count()
	var crew_sig := _crew_signature()
	for i in Data.MAX_SLOTS:
		var u: Dictionary = _slot_ui[i]
		u.card.get_parent().visible = i < count
		if i >= count:
			continue
		var slot: Dictionary = GameState.slots[i]
		var busy: bool = slot.dest != ""
		u.view.set_dest(slot.dest)
		if _pending_battle.get(i, false) and not u.bv.playing and not slot.battle.is_empty():
			u.bv.play(slot.battle)
		_pending_battle[i] = false
		u.view.visible = not u.bv.playing
		u.bv.visible = u.bv.playing
		u.replay.visible = not slot.battle.is_empty() and not u.bv.playing
		if i == 0:
			u.title.text = "Vaisseau amiral — %s (niv. %d)" % [GameState.captain.name, GameState.captain.level]
		else:
			u.title.text = "Drone d'exploration (équipage seul, sans Capitaine)"
		u.auto.set_pressed_no_signal(slot.auto)
		u.recall.visible = busy
		u.auto_sq.visible = not busy
		u.last.visible = slot.last != ""
		u.last.text = slot.last
		u.log.visible = not slot.log.is_empty()
		u.log.text = "\n".join(slot.log.slice(0, 4)) if not slot.log.is_empty() else ""
		_refresh_stations(u, i, crew_sig + str(busy))
		if busy:
			var total := GameState.duration_of(slot.dest, i)
			u.bar.value = clampf(1.0 - slot.remaining / total, 0.0, 1.0)
			u.status.text = "En route : %s — reste %s" % [Data.DEST[slot.dest].name, Data.fmt_time(slot.remaining)]
		else:
			u.bar.value = 0.0
			if GameState.squad_ids(i).is_empty():
				u.status.text = "Postes vides : touchez « Placer automatiquement le meilleur équipage » ou choisissez une carte par poste."
			else:
				u.status.text = "Équipage en place. Choisissez une destination :"
		for d in Data.DEST_ORDER:
			var b: Button = u.dest[d]
			var info: Dictionary = Data.DEST[d]
			var reason := GameState.launch_block_reason(d, i)
			if reason != "":
				b.text = "%s\n%s" % [info.name, reason]
			else:
				var fight := GameState.preview_battle(d, i)
				b.text = "%s — %s\n%s\nEnnemis niv. %d : %s" % [
					info.name, Data.fmt_time(GameState.duration_of(d, i)),
					Data.fmt_amounts(GameState.rewards_of(d, i)), GameState.enemy_level(d),
					"victoire probable" if fight.win else "DÉFAITE probable"]
			b.disabled = busy or reason != ""
			b.visible = not busy
	var next := ""
	for d in Data.DEST_ORDER:
		if not GameState.is_unlocked(d):
			next = "Prochaine destination : %s à %s données cumulées (vous : %s)." % [
				Data.DEST[d].name, Data.fmt(Data.DEST[d].unlock_data), Data.fmt(GameState.data_total)]
			break
	_next_label.text = next


func _refresh_stations(u: Dictionary, slot_i: int, sig: String) -> void:
	var slot: Dictionary = GameState.slots[slot_i]
	var busy: bool = slot.dest != ""
	var full_sig := sig + str(slot.squad)
	var rebuild: bool = u.sig != full_sig
	u.sig = full_sig
	for k in Data.CREW_ORDER.size():
		var m: Dictionary = u.members[k]
		var cur: String = slot.squad[k]
		m.portrait.role = Data.CREW_ORDER[k]
		m.portrait.setup_crew(cur, GameState.heroes[cur].stars if cur != "" else 0, busy)
		var opt: OptionButton = m.opt
		opt.disabled = busy
		if not rebuild:
			continue
		opt.clear()
		m.ids = [""]
		opt.add_item("— vide —")
		for id in GameState.hero_order:
			if Data.HEROES[id]["class"] != Data.CREW_ORDER[k]:
				continue
			var h: Dictionary = GameState.heroes[id]
			m.ids.append(id)
			var other := GameState.hero_slot(id)
			var tag := "" if other < 0 or (other == slot_i and slot.squad[k] == id) else " (v.%d)" % (other + 1)
			opt.add_item("%s niv.%d%s" % [Data.HEROES[id].name, h.level, tag])
		opt.select(maxi(0, m.ids.find(cur)))


func _refresh_ship() -> void:
	for id in Data.UPGRADE_ORDER:
		var up: Dictionary = Data.UPGRADES[id]
		var u: Dictionary = _upgrade_ui[id]
		var lvl: int = GameState.upgrade_levels[id]
		u.name.text = "%s  —  niveau %d/%d" % [up.name, lvl, up.max]
		u.desc.text = up.desc
		if GameState.upgrade_maxed(id):
			u.btn.text = "Niveau maximum"
			u.btn.disabled = true
		else:
			var cost := GameState.upgrade_cost(id)
			u.btn.text = "Améliorer — " + _cost_text(cost)
			u.btn.disabled = not GameState.can_afford(cost)


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for id in Data.RES_ORDER:
		if cost.has(id):
			parts.append("%s %s" % [Data.fmt(cost[id]), String(Data.RES_NAMES[id]).to_lower()])
	return ", ".join(parts)


func _show_offline_report(r: Dictionary) -> void:
	var d := AcceptDialog.new()
	d.title = "Bon retour, Commandant !"
	var txt := "Absent %s (comptés : %s, rendement %d %%)\n%s\nExpéditions terminées : %d" % [
		Data.fmt_time(r.away), Data.fmt_time(r.seconds), int(round(r.efficiency * 100.0)),
		Data.fmt_amounts(r.gains), r.expeditions]
	if r.loot_kept > 0:
		var best: Dictionary = r.loot_best
		txt += "\nButin : %d objet(s) gardé(s), meilleur : %s (%s)" % [r.loot_kept, best.name, Data.ITEM_RARITY[best.rarity].name]
	if r.recycled > 0.0:
		txt += "\nRecyclage automatique : +%s crédits" % Data.fmt(r.recycled)
	d.dialog_text = txt
	d.ok_button_text = "Continuer"
	add_child(d)
	d.popup_centered(Vector2i(640, 420))
