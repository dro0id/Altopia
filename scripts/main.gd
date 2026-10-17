extends Control
## Interface : 3 onglets (Héros, Expéditions, Vaisseau), construite en code.

const Data = preload("res://scripts/game_data.gd")
const Starfield = preload("res://scripts/starfield.gd")
const Portrait = preload("res://scripts/portrait.gd")
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
var _hero_ui := {}
var _recruit_btn: Button
var _recruit_label: Label
var _collection_label: Label
var _synergy_label: Label
var _slot_ui: Array = []
var _next_label: Label
var _upgrade_ui := {}
var _dirty := true
var _timer := 0.0
var _press_pos := Vector2.ZERO
var _pending_battle := {}   # emplacement -> un combat vient de se terminer, à animer
var _dragged := false       # le doigt a glissé : le relâchement ne doit rien acheter


func _ready() -> void:
	_build_ui()
	GameState.changed.connect(func(): _dirty = true)
	GameState.battle_finished.connect(_on_battle_finished)
	_show_tab("heroes")
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
	_pages["heroes"] = _make_page(holder)
	_pages["exp"] = _make_page(holder)
	_pages["ship"] = _make_page(holder)
	_build_heroes_page(_pages["heroes"])
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
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)
	var group := ButtonGroup.new()
	for entry in [["heroes", "Héros"], ["exp", "Expéditions"], ["ship", "Vaisseau"]]:
		var b := Button.new()
		b.text = entry[1]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		b.add_theme_stylebox_override("pressed", _flat(Color(0.16, 0.32, 0.62), 10))
		b.add_theme_stylebox_override("hover_pressed", _flat(Color(0.16, 0.32, 0.62), 10))
		b.pressed.connect(_show_tab.bind(entry[0]))
		bar.add_child(b)
		_tab_buttons[entry[0]] = b


func _build_heroes_page(page: VBoxContainer) -> void:
	_collection_label = _label(page, "", 30, COL_ACCENT)
	_synergy_label = _label(page, "", 21, COL_TEXT_DIM)
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recruit_btn = _button(page, "", 100)
	_recruit_btn.add_theme_font_size_override("font_size", 26)
	_recruit_btn.pressed.connect(_tap(func(): GameState.recruit()))
	_recruit_label = _label(page, "", 22, COL_ACCENT)
	_recruit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for id in Data.HERO_ORDER:
		var card := _card_h(page)
		var portrait: Control = Portrait.new()
		portrait.custom_minimum_size = Vector2(104, 104)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.add_child(portrait)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 4)
		card.add_child(right)
		var name_l := _label(right, "", 26)
		var stats_l := _label(right, "", 20, COL_TEXT_DIM)
		var xp := ProgressBar.new()
		xp.custom_minimum_size = Vector2(0, 16)
		xp.show_percentage = false
		xp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		xp.max_value = 1.0
		xp.add_theme_stylebox_override("fill", _flat(COL_GOOD, 6))
		xp.add_theme_stylebox_override("background", _flat(Color(0.1, 0.14, 0.28), 6))
		right.add_child(xp)
		var where_l := _label(right, "", 19, COL_TEXT_DIM)
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
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 30)
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.max_value = 1.0
		bar.add_theme_stylebox_override("fill", _flat(COL_ACCENT, 8))
		bar.add_theme_stylebox_override("background", _flat(Color(0.1, 0.14, 0.28), 8))
		card.add_child(bar)
		var status := _label(card, "", 21, COL_TEXT_DIM)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var squad_row := HBoxContainer.new()
		squad_row.add_theme_constant_override("separation", 8)
		card.add_child(squad_row)
		var members: Array = []
		for k in Data.SQUAD_SIZE:
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 4)
			squad_row.add_child(col)
			var por: Control = Portrait.new()
			por.custom_minimum_size = Vector2(0, 88)
			col.add_child(por)
			var opt := OptionButton.new()
			opt.custom_minimum_size = Vector2(0, 62)
			opt.add_theme_font_size_override("font_size", 19)
			opt.fit_to_longest_item = false
			opt.clip_text = true
			opt.item_selected.connect(_on_squad_pick.bind(i, k))
			col.add_child(opt)
			members.append({"portrait": por, "opt": opt, "ids": []})
		var auto_sq := _button(card, "Composer l'escouade automatiquement", 62)
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


func _on_squad_pick(index: int, slot_i: int, member_i: int) -> void:
	var ids: Array = _slot_ui[slot_i].members[member_i].ids
	GameState.set_squad_member(slot_i, member_i, ids[index] if index < ids.size() else "")


## ---------- Rafraîchissement ----------

func _refresh() -> void:
	for id in Data.RES_ORDER:
		_res_labels[id].text = "%s  %s" % [Data.RES_NAMES[id], Data.fmt(GameState.res[id])]
	_rate_label.text = "+%s crédits/s    +%s données/s    Expéditions : %d" % [
		Data.fmt(GameState.credits_per_sec()), Data.fmt(GameState.data_per_sec()),
		GameState.expeditions_done]
	_refresh_heroes()
	_refresh_expeditions()
	_refresh_ship()


func _refresh_heroes() -> void:
	_collection_label.text = "Collection : %d / %d héros" % [GameState.heroes.size(), Data.HERO_ORDER.size()]
	_synergy_label.text = "Synergie : x%.2f (chaque paire de classes possédées +10 %%, les 3 classes +25 %%). Les héros rapportent des crédits en continu." % GameState.synergy_multiplier()
	var cost := GameState.recruit_cost()
	_recruit_btn.text = "Recruter un héros — %s crédits" % Data.fmt(cost)
	_recruit_btn.disabled = GameState.res["credits"] < cost
	var lr: Dictionary = GameState.last_recruit
	if lr.is_empty():
		_recruit_label.text = "Doublon = +1 étoile (stats +20 %). Épique : 5 % de chance."
	else:
		var hd: Dictionary = Data.HEROES[lr.id]
		var what := "NOUVEAU héros" if lr.new else ("+1 étoile" if not lr.maxed else "doublon max (remboursé en partie)")
		_recruit_label.text = "Dernier recrutement : %s (%s) — %s" % [hd.name, Data.RARITY[hd.rarity].name, what]
	for id in Data.HERO_ORDER:
		var u: Dictionary = _hero_ui[id]
		var tpl: Dictionary = Data.HEROES[id]
		var cls: Dictionary = Data.CREW[tpl["class"]]
		if not GameState.heroes.has(id):
			u.portrait.setup("", 0)
			u.name.text = "???  —  %s %s" % [Data.RARITY[tpl.rarity].name, cls.name]
			u.name.add_theme_color_override("font_color", COL_TEXT_DIM)
			u.stats.text = "Héros non recruté"
			u.xp.visible = false
			u.where.text = ""
			u.train.visible = false
			continue
		var h: Dictionary = GameState.heroes[id]
		var st := Data.hero_stats(id, h.level, h.stars)
		u.portrait.setup(id, h.stars)
		u.name.text = "%s  —  niv. %d" % [tpl.name, h.level]
		u.name.add_theme_color_override("font_color", Data.RARITY[tpl.rarity].color)
		u.stats.text = "%s · %s\nPV %d  ATQ %d  DÉF %d  VIT %d" % [
			cls.name, Data.RARITY[tpl.rarity].name, st.hp, st.atk, st.def, st.spd]
		u.xp.visible = true
		u.xp.value = float(h.xp) / float(Data.xp_needed(h.level))
		var slot := GameState.hero_slot(id)
		u.where.text = ("En escouade : vaisseau %d" % (slot + 1)) if slot >= 0 else "Disponible"
		u.train.visible = true
		if h.level >= Data.MAX_LEVEL:
			u.train.text = "Niveau maximum"
			u.train.disabled = true
		else:
			var tc := GameState.train_cost(id)
			u.train.text = "Entraîner (+1 niveau) — %s crédits" % Data.fmt(tc)
			u.train.disabled = GameState.res["credits"] < tc


func _hero_signature() -> String:
	var parts: Array[String] = []
	for id in GameState.hero_order:
		parts.append("%s%d" % [id, GameState.heroes[id].level])
	return ",".join(parts)


func _refresh_expeditions() -> void:
	var count := GameState.slot_count()
	var hero_sig := _hero_signature()
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
		u.title.text = "Vaisseau %d" % (i + 1)
		u.auto.set_pressed_no_signal(slot.auto)
		u.recall.visible = busy
		u.auto_sq.visible = not busy
		u.last.visible = slot.last != ""
		u.last.text = slot.last
		u.log.visible = not slot.log.is_empty()
		u.log.text = "\n".join(slot.log.slice(0, 4)) if not slot.log.is_empty() else ""
		_refresh_squad_row(u, i, hero_sig + str(busy))
		if busy:
			var total := GameState.duration_of(slot.dest, i)
			u.bar.value = clampf(1.0 - slot.remaining / total, 0.0, 1.0)
			u.status.text = "En route : %s — reste %s" % [Data.DEST[slot.dest].name, Data.fmt_time(slot.remaining)]
		else:
			u.bar.value = 0.0
			if GameState.squad_ids(i).is_empty():
				u.status.text = "Aucun héros dans l'escouade : touchez « Composer automatiquement » ou choisissez-les dans les listes."
			else:
				u.status.text = "Escouade prête (3 héros max). Choisissez une destination :"
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


func _refresh_squad_row(u: Dictionary, slot_i: int, sig: String) -> void:
	var slot: Dictionary = GameState.slots[slot_i]
	var busy: bool = slot.dest != ""
	var full_sig := sig + str(slot.squad)
	var rebuild: bool = u.sig != full_sig
	u.sig = full_sig
	for k in Data.SQUAD_SIZE:
		var m: Dictionary = u.members[k]
		var cur: String = slot.squad[k]
		m.portrait.setup(cur, GameState.heroes[cur].stars if cur != "" else 0, busy)
		var opt: OptionButton = m.opt
		opt.disabled = busy
		if not rebuild:
			continue
		opt.clear()
		m.ids = [""]
		opt.add_item("— vide —")
		for id in GameState.hero_order:
			var h: Dictionary = GameState.heroes[id]
			m.ids.append(id)
			var other := GameState.hero_slot(id)
			var tag := "" if other < 0 or (other == slot_i and slot.squad[k] == id) else " (v.%d)" % (other + 1)
			opt.add_item("%s %s niv.%d%s" % [Data.HEROES[id].name,
				String(Data.CREW[Data.HEROES[id]["class"]].name).substr(0, 3) + ".", h.level, tag])
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
	d.dialog_text = "Pendant votre absence (%s) :\n%s\nExpéditions terminées : %d" % [
		Data.fmt_time(r.seconds), Data.fmt_amounts(r.gains), r.expeditions]
	d.ok_button_text = "Continuer"
	add_child(d)
	d.popup_centered(Vector2i(600, 340))
