extends Control
## Interface de la V1 : 3 onglets (Équipage, Expéditions, Vaisseau), construite en code.

const Data = preload("res://scripts/game_data.gd")
const Starfield = preload("res://scripts/starfield.gd")

const COL_CARD := Color(0.07, 0.10, 0.22, 0.88)
const COL_TEXT_DIM := Color(0.62, 0.70, 0.88)
const COL_ACCENT := Color(0.49, 0.95, 1.0)

var _res_labels := {}
var _rate_label: Label
var _pages := {}
var _tab_buttons := {}
var _crew_ui := {}
var _synergy_label: Label
var _slot_ui: Array = []
var _dest_help := {}
var _upgrade_ui := {}
var _dirty := true
var _timer := 0.0


func _ready() -> void:
	_build_ui()
	GameState.changed.connect(func(): _dirty = true)
	_show_tab("crew")
	_refresh()
	if not GameState.last_offline_report.is_empty():
		_show_offline_report(GameState.last_offline_report)


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
	_pages["crew"] = _make_page(holder)
	_pages["exp"] = _make_page(holder)
	_pages["ship"] = _make_page(holder)
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
	bar.add_theme_constant_override("separation", 10)
	parent.add_child(bar)
	var group := ButtonGroup.new()
	for entry in [["crew", "Équipage"], ["exp", "Expéditions"], ["ship", "Vaisseau"]]:
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


func _build_crew_page(page: VBoxContainer) -> void:
	_label(page, "Votre équipage", 30, COL_ACCENT)
	_synergy_label = _label(page, "", 22, COL_TEXT_DIM)
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for id in Data.CREW_ORDER:
		var card := _card(page)
		var name_l := _label(card, "", 28)
		var desc_l := _label(card, "", 21, COL_TEXT_DIM)
		var eff_l := _label(card, "", 21, COL_TEXT_DIM)
		var b := _button(card, "", 100)
		b.pressed.connect(func(): GameState.buy_crew(id))
		_crew_ui[id] = {"name": name_l, "desc": desc_l, "eff": eff_l, "btn": b}


func _build_expedition_page(page: VBoxContainer) -> void:
	_label(page, "Expéditions", 30, COL_ACCENT)
	for i in Data.MAX_SLOTS:
		var card := _card(page)
		var title := _label(card, "", 26)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 34)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.add_theme_stylebox_override("fill", _flat(COL_ACCENT, 8))
		bar.add_theme_stylebox_override("background", _flat(Color(0.1, 0.14, 0.28), 8))
		card.add_child(bar)
		var status := _label(card, "", 21, COL_TEXT_DIM)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var last := _label(card, "", 20, COL_ACCENT)
		last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var auto := CheckButton.new()
		auto.text = "Relance automatique"
		auto.add_theme_font_size_override("font_size", 22)
		auto.toggled.connect(func(v: bool): GameState.set_auto(i, v))
		card.add_child(auto)
		var recall := _button(card, "Rappeler le vaisseau", 70)
		recall.pressed.connect(func(): GameState.recall(i))
		var dest_btns := {}
		for d in Data.DEST_ORDER:
			var b := _button(card, "", 110)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func(): GameState.launch(i, d))
			dest_btns[d] = b
		_slot_ui.append({
			"card": card, "title": title, "bar": bar, "status": status, "last": last,
			"auto": auto, "recall": recall, "dest": dest_btns,
		})
	_dest_help["locked"] = _label(page, "", 22, COL_TEXT_DIM)
	_dest_help["locked"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_ship_page(page: VBoxContainer) -> void:
	_label(page, "Vaisseau", 30, COL_ACCENT)
	for id in Data.UPGRADE_ORDER:
		var card := _card(page)
		var name_l := _label(card, "", 27)
		var desc_l := _label(card, "", 21, COL_TEXT_DIM)
		var b := _button(card, "", 100)
		b.pressed.connect(func(): GameState.buy_upgrade(id))
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
	parent.add_child(b)
	return b


func _card(parent: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	sb.border_color = Color(0.25, 0.4, 0.8, 0.5)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb


func _show_tab(tab: String) -> void:
	for id in _pages:
		_pages[id].get_meta("scroll").visible = (id == tab)
	_tab_buttons[tab].button_pressed = true


## ---------- Rafraîchissement ----------

func _refresh() -> void:
	for id in Data.RES_ORDER:
		_res_labels[id].text = "%s  %s" % [Data.RES_NAMES[id], Data.fmt(GameState.res[id])]
	_rate_label.text = "+%s crédits/s    +%s données/s    Expéditions : %d" % [
		Data.fmt(GameState.credits_per_sec()), Data.fmt(GameState.data_per_sec()),
		GameState.expeditions_done]
	_refresh_crew()
	_refresh_expeditions()
	_refresh_ship()


func _refresh_crew() -> void:
	var mult := GameState.synergy_multiplier()
	_synergy_label.text = "Synergie d'équipage : x%.2f  (chaque paire de rôles +10 %%, équipage complet +25 %%)" % mult
	for id in Data.CREW_ORDER:
		var c: Dictionary = Data.CREW[id]
		var u: Dictionary = _crew_ui[id]
		var lvl: int = GameState.crew_levels[id]
		u.name.text = "%s  —  niveau %d" % [c.name, lvl]
		u.desc.text = c.desc
		var eff := "+%s crédits/s par niveau" % Data.fmt(c.rate)
		if c.data_rate > 0.0:
			eff += ", +%s données/s" % Data.fmt(c.data_rate)
		u.eff.text = eff
		var cost: float = GameState.crew_cost(id)
		u.btn.text = "%s — %s crédits" % ["Recruter" if lvl == 0 else "Améliorer", Data.fmt(cost)]
		u.btn.disabled = GameState.res["credits"] < cost


func _refresh_expeditions() -> void:
	var count := GameState.slot_count()
	for i in Data.MAX_SLOTS:
		var u: Dictionary = _slot_ui[i]
		u.card.get_parent().visible = i < count
		if i >= count:
			continue
		var slot: Dictionary = GameState.slots[i]
		var busy: bool = slot.dest != ""
		u.title.text = "Vaisseau %d" % (i + 1)
		u.auto.set_pressed_no_signal(slot.auto)
		u.recall.visible = busy
		u.last.text = ("Dernier butin — " + slot.last) if slot.last != "" else ""
		u.last.visible = slot.last != ""
		if busy:
			var total := GameState.duration_of(slot.dest)
			u.bar.value = clampf(1.0 - slot.remaining / total, 0.0, 1.0)
			u.status.text = "En route : %s — reste %s" % [Data.DEST[slot.dest].name, Data.fmt_time(slot.remaining)]
		else:
			u.bar.value = 0.0
			u.status.text = "Vaisseau au repos. Choisissez une destination :"
		for d in Data.DEST_ORDER:
			var b: Button = u.dest[d]
			var info: Dictionary = Data.DEST[d]
			var reason := GameState.launch_block_reason(d)
			var head := "%s — %s" % [info.name, Data.fmt_time(GameState.duration_of(d))]
			if reason != "":
				b.text = "%s\n%s" % [info.name, reason]
			else:
				b.text = "%s\n%s" % [head, Data.fmt_amounts(GameState.rewards_of(d))]
			b.disabled = busy or reason != ""
			b.visible = not busy
	var next := ""
	for d in Data.DEST_ORDER:
		if not GameState.is_unlocked(d):
			next = "Prochaine destination : %s à %s données cumulées (vous : %s)." % [
				Data.DEST[d].name, Data.fmt(Data.DEST[d].unlock_data), Data.fmt(GameState.data_total)]
			break
	_dest_help["locked"].text = next


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
