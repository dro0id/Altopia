extends Control
## Interface : 4 onglets (Capitaine, Équipage, Expéditions, Vaisseau), construite en code.

const Data = preload("res://scripts/game_data.gd")
const Starfield = preload("res://scripts/starfield.gd")
const Chibi = preload("res://scripts/chibi.gd")
const BaseView = preload("res://scripts/base_view.gd")
const BaseUI = preload("res://scripts/base_ui.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const UiIcons = preload("res://scripts/ui_icons.gd")
const SpaceView = preload("res://scripts/space_view.gd")
const BattleView = preload("res://scripts/battle_view.gd")
const LiveUI = preload("res://scripts/live_ui.gd")
const DeriveUI = preload("res://scripts/derive_ui.gd")
const DeriveSim = preload("res://scripts/derive_sim.gd")
const RouteUI = preload("res://scripts/route_ui.gd")
const RouteSim = preload("res://scripts/route_sim.gd")

const COL_CARD := UiTheme.PANEL
const COL_TEXT_DIM := UiTheme.DIM
const COL_ACCENT := UiTheme.ACCENT
const COL_GOOD := UiTheme.GOOD

var _res_labels := {}
var _rate_label: Label
var _exp_count: Label
var _sector_label: Label
var _mode_btns := {}
var _exp_mode := "combat"        # mode choisi pour les expéditions du vaisseau 1 : "combat", "derive" ou "random"
var _live: Control               # combat en direct en cours
var _pages := {}
var _base_ui
var _title: Label
var _subnav: Control
var _ship_info: Label
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
var _afk_loot: Label
# Anomalies
var _an_sel := 1
var _an_info: Label
var _an_label: Label
var _an_preview: Label
var _an_view: Control
var _an_result: Label
var _an_btn: Button
var _an_minus: Button
var _an_plus: Button
var _afk_rates := {}
const UPGRADE_ICONS := {"laser": "minerals", "solar": "energy", "scanner": "data", "engines": "exp", "docks": "ship"}
const UpgradeColors := {"laser": Color(0.8, 0.7, 0.62), "solar": Color(0.75, 0.55, 1.0), "scanner": Color(0.5, 0.95, 1.0),
	"engines": Color(0.43, 1.0, 0.61), "docks": Color(1.0, 0.82, 0.35)}
const DEST_ICONS := {"asteroids": "minerals", "star": "energy", "planet": "data"}
var _goal_title: Label
var _goal_bar: ProgressBar
var _goal_info: Label
var _goal_btn: Button
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
# Base
# Labo


func _ready() -> void:
	_build_ui()
	GameState.changed.connect(func(): _dirty = true)
	GameState.battle_finished.connect(_on_battle_finished)
	GameState.anomaly_finished.connect(_on_anomaly_finished)
	_show_tab("captain")
	_refresh()
	if not GameState.last_offline_report.is_empty():
		_base_ui.show_offline_report(GameState.last_offline_report)


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
	theme = UiTheme.build()
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

	_base_ui = BaseUI.new(self)
	_build_header(root)
	_subnav = _base_ui.build_subnav(root)

	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(holder)
	for id in ["captain", "crew", "exp", "base"]:
		_pages[id] = _make_page(holder)
	_build_captain_page(_pages["captain"])
	_build_crew_page(_pages["crew"])
	_build_expedition_page(_pages["exp"])
	_base_ui.build_sections(_pages["base"])
	_build_ship_page(_base_ui.sections["ship"])

	_build_tabs(root)


func _build_header(parent: Control) -> void:
	_title = _label(parent, "ALTOPIA", 46, COL_ACCENT)
	_title.add_theme_font_override("font", UiTheme.font(true))
	_title.add_theme_constant_override("outline_size", 0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var colors: Dictionary = UiTheme.RES_COLORS
	var short := {"credits": "cr", "minerals": "min", "data": "don", "energy": "én"}
	for id in ["credits", "minerals", "data", "energy"]:
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.12, 0.2, 1.0), colors[id], 14, 1, 10))
		row.add_child(chip)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 6)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(inner)
		_label(inner, short[id], 23, colors[id])
		var l := _label(inner, "", 23, UiTheme.TEXT)
		l.add_theme_font_override("font", UiTheme.mono())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.clip_text = true
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
	for entry in [["captain", "Capitaine"], ["crew", "Équipage"], ["exp", "Expéditions"], ["base", "Base"]]:
		var b := Button.new()
		b.text = entry[1]
		b.icon = UiIcons.icon(entry[0], 40, Color.WHITE)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_constant_override("icon_max_width", 40)
		b.add_theme_constant_override("h_separation", 0)
		b.pressed.connect(_show_tab.bind(entry[0]))
		bar.add_child(b)
		_tab_buttons[entry[0]] = b


func _build_captain_page(page: VBoxContainer) -> void:
	var goal := _card(page)
	_goal_title = _label(goal, "", 24, UiTheme.MAGENTA)
	_goal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_bar = _bar(goal, 14, UiTheme.MAGENTA)
	_goal_info = _label(goal, "", 20, COL_TEXT_DIM)
	_goal_btn = _button(goal, "", 60)
	_goal_btn.add_theme_font_size_override("font_size", 22)
	_goal_btn.pressed.connect(_tap(func(): GameState.claim_goal()))
	var card := _card_h(page)
	_cap_chibi = BaseView.new()
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

	_section(page, "Anomalies")
	var an := _card(page)
	_label(an, "Le contenu actif du Capitaine : XP et crédits. Une défaite rend la charge.", 19, COL_TEXT_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_an_info = _label(an, "", 22, UiTheme.MAGENTA)
	_an_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 10)
	an.add_child(sel)
	_an_minus = _button(sel, "−", 70)
	_an_minus.custom_minimum_size = Vector2(90, 70)
	_an_minus.pressed.connect(_tap(func(): _an_sel = maxi(1, _an_sel - 1); _dirty = true))
	_an_label = _label(sel, "", 30)
	_an_label.add_theme_font_override("font", UiTheme.font(true))
	_an_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_an_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_an_plus = _button(sel, "+", 70)
	_an_plus.custom_minimum_size = Vector2(90, 70)
	_an_plus.pressed.connect(_tap(func(): _an_sel = mini(GameState.anomaly_unlocked_max(), _an_sel + 1); _dirty = true))
	_an_view = BattleView.new()
	_an_view.visible = false
	an.add_child(_an_view)
	_an_preview = _label(an, "", 20, COL_TEXT_DIM)
	_an_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_an_result = _label(an, "", 21, COL_ACCENT)
	_an_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_an_btn = _button(an, "", 84)
	UiTheme.style_primary(_an_btn)
	_an_btn.add_theme_font_size_override("font_size", 26)
	_an_btn.pressed.connect(_tap(func(): if not _an_view.playing: GameState.enter_anomaly(_an_sel)))
	_section(page, "Équipement")
	for slot in Data.EQUIP_SLOTS:
		var panel := _rarity_panel(page, COL_TEXT_DIM)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var tile := _icon_tile(row, slot, COL_TEXT_DIM, 84)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 6)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(c)
		var kind := _label(c, Data.EQUIP[slot].name.to_upper(), 16, COL_TEXT_DIM)
		var title := _label(c, "", 24)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stats := _label(c, "", 19, COL_TEXT_DIM)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := _button(c, "Retirer", 50)
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_tap(func(): GameState.unequip(slot)))
		_slot_cards[slot] = {"title": title, "stats": stats, "btn": b, "panel": panel, "tile": tile, "kind": kind}
	var best := _button(page, "Équiper automatiquement le meilleur", 66)
	best.add_theme_font_size_override("font_size", 20)
	best.pressed.connect(_tap(func(): GameState.auto_equip()))
	_recycle_btn = _button(page, "", 62)
	_recycle_btn.add_theme_font_size_override("font_size", 19)
	_recycle_btn.pressed.connect(_tap(func(): GameState.cycle_auto_recycle()))
	_useless_btn = _button(page, "Recycler tous les objets inutiles", 62)
	_useless_btn.add_theme_font_size_override("font_size", 19)
	_useless_btn.pressed.connect(_tap(func(): GameState.recycle_useless()))
	_inv_title = _section(page, "")
	_inv_box = VBoxContainer.new()
	_inv_box.add_theme_constant_override("separation", 10)
	_inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_inv_box)


func _build_crew_page(page: VBoxContainer) -> void:
	_collection_label = _section(page, "")
	_synergy_label = _label(page, "", 21, COL_TEXT_DIM)
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var afk_card := _card(page)
	_label(afk_card, "AFK : l'équipage aux postes travaille même hors ligne (ressources, XP des équipiers, objets du Capitaine)", 21, COL_GOOD).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var afk_grid := GridContainer.new()
	afk_grid.columns = 2
	afk_grid.add_theme_constant_override("h_separation", 10)
	afk_grid.add_theme_constant_override("v_separation", 8)
	afk_card.add_child(afk_grid)
	for id in Data.RES_ORDER:
		_afk_rates[id] = _rate_chip(afk_grid, id)
	_afk_label = _label(afk_card, "", 19, COL_TEXT_DIM)
	_afk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_afk_loot = _label(afk_card, "", 19, UiTheme.MAGENTA)
	_afk_loot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recruit_btn = _button(page, "", 100)
	UiTheme.style_primary(_recruit_btn)
	_recruit_btn.add_theme_font_size_override("font_size", 26)
	_recruit_btn.pressed.connect(_tap(func(): GameState.recruit()))
	_recruit_label = _label(page, "", 22, COL_ACCENT)
	_recruit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for id in Data.HERO_ORDER:
		var panel := _rarity_panel(page, COL_TEXT_DIM)
		var card := HBoxContainer.new()
		card.add_theme_constant_override("separation", 14)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(card)
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
		UiTheme.style_primary(train)
		_hero_ui[id] = {"panel": panel, "portrait": portrait, "name": name_l, "stats": stats_l, "xp": xp,
			"where": where_l, "train": train}


func _build_expedition_page(page: VBoxContainer) -> void:
	_section(page, "Expéditions")
	_exp_count = _label(page, "", 19, COL_ACCENT)
	_sector_label = _label(page, "", 20, Color("ffd159"))
	_sector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := _label(page, "Les expéditions se jouent en direct : le Capitaine y gagne de l'XP et l'équipage l'accompagne. Elles se mettent en pause quand vous quittez l'appli (l'AFK, lui, continue).", 19, COL_TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
			var head := HBoxContainer.new()
			head.alignment = BoxContainer.ALIGNMENT_CENTER
			head.add_theme_constant_override("separation", 6)
			head.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(head)
			var hic := TextureRect.new()
			hic.texture = UiIcons.icon(Data.CREW_ORDER[k], 26, cls.color)
			hic.custom_minimum_size = Vector2(22, 22)
			hic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			head.add_child(hic)
			_label(head, String(cls.name), 19, cls.color)
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
		auto.mouse_filter = Control.MOUSE_FILTER_PASS      # un glissement sur l'interrupteur fait défiler la page
		auto.toggled.connect(func(v: bool):
			if _dragged:
				auto.set_pressed_no_signal(not v)
			else:
				GameState.set_auto(i, v))
		card.add_child(auto)
		var replay := _button(card, "Revoir le dernier combat", 62)
		replay.add_theme_font_size_override("font_size", 21)
		replay.pressed.connect(_tap(func():
			if not GameState.slots[i].battle.is_empty():
				bv.play(GameState.slots[i].battle)))
		var recall := _button(card, "Rappeler le vaisseau", 70)
		UiTheme.style_danger(recall)
		recall.pressed.connect(_tap(func(): GameState.recall(i)))
		if i == 0:
			_label(card, "Comment explorer ?", 21, COL_TEXT_DIM)
			var mode_row := HBoxContainer.new()
			mode_row.add_theme_constant_override("separation", 6)
			card.add_child(mode_row)
			for m in ["combat", "derive", "route", "random"]:
				var mb := Button.new()
				mb.toggle_mode = true
				mb.custom_minimum_size = Vector2(0, 74)
				mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				mb.add_theme_font_size_override("font_size", 19)
				mb.clip_text = true
				mb.pressed.connect(_tap(func():
					if m == "combat" or m == "derive" or m == "route" or m == "random":
						_exp_mode = m
					_dirty = true))
				mode_row.add_child(mb)
				_mode_btns[m] = mb
		var dest_btns := {}
		for d in Data.DEST_ORDER:
			var b := _button(card, "", 130)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var role_col: Color = Data.CREW[Data.DEST[d].role].color
			UiTheme.style_card_button(b, role_col)
			b.icon = UiIcons.icon(DEST_ICONS[d], 56, role_col)
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 56)
			b.add_theme_constant_override("h_separation", 16)
			b.add_theme_font_size_override("font_size", 21)
			b.pressed.connect(_tap(func():
				if i == 0:
					_start_live(0, d)
				else:
					GameState.launch(i, d)))
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


## Lance un combat en direct sur le vaisseau `slot_i` (le mode Aléatoire tire le mode parmi ceux qui sont prêts).
func _start_live(slot_i: int, dest: String) -> void:
	if _live != null or GameState.live_block_reason(dest, slot_i) != "":
		return
	var random := _exp_mode == "random" and GameState.random_mode_available()
	var mode: String = GameState.pick_random_mode(dest) if random else (_exp_mode if _exp_mode in ["derive", "route"] else "combat")
	var ui: Control
	if mode == "route":
		ui = RouteUI.new()
		_live = ui
		add_child(ui)
		ui.begin(slot_i, dest, GameState.route_config(dest, slot_i), random, GameState.live_mode_mult(dest, random, "route"))
	elif mode == "derive":
		ui = DeriveUI.new()
		_live = ui
		add_child(ui)
		ui.begin(slot_i, dest, GameState.derive_config(dest, slot_i), random, GameState.live_mode_mult(dest, random, "derive"))
	else:
		ui = LiveUI.new()
		_live = ui
		add_child(ui)
		ui.begin(slot_i, dest, GameState.live_config(dest, slot_i), random, GameState.live_mode_mult(dest, random, "combat"), GameState.live_chance(dest, slot_i))
	ui.closed.connect(func(replay: bool):
		ui.queue_free()
		_live = null
		_dirty = true
		if replay:
			_start_live(slot_i, dest))


func _drag_safe_option(opt: OptionButton) -> void:
	opt.fit_to_longest_item = false
	opt.clip_text = true
	opt.mouse_filter = Control.MOUSE_FILTER_PASS         # un glissement dessus fait défiler la page
	opt.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	opt.add_theme_font_size_override("font_size", 19)
	opt.get_popup().about_to_popup.connect(func():
		if _dragged:     # le doigt a glissé : ce n'était pas un tap, on referme la liste
			opt.get_popup().hide.call_deferred())


func _build_ship_page(page: VBoxContainer) -> void:
	_section(page, "Vaisseau")
	_ship_info = _label(page, "Améliorations du vaisseau : expéditions et revenus.", 20, COL_TEXT_DIM)
	_ship_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for id in Data.UPGRADE_ORDER:
		var icon_name: String = UPGRADE_ICONS[id]
		var color: Color = UpgradeColors.get(id, UiTheme.ACCENT)
		var panel := _rarity_panel(page, color)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		_icon_tile(row, icon_name, color, 84)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 6)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card)
		var name_l := _label(card, "", 26)
		var lvl_bar := _bar(card, 10, color)
		var desc_l := _label(card, "", 20, COL_TEXT_DIM)
		var b := _button(card, "", 76)
		UiTheme.style_primary(b)
		b.pressed.connect(_tap(func(): GameState.buy_upgrade(id)))
		_upgrade_ui[id] = {"name": name_l, "desc": desc_l, "btn": b, "bar": lvl_bar}


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
	bar.add_theme_stylebox_override("fill", UiTheme.box(color, Color(0, 0, 0, 0), 4, 0, 0))
	bar.add_theme_stylebox_override("background", UiTheme.box(Color(0.03, 0.08, 0.14), Color(0.22, 0.9, 1.0, 0.25), 4, 1, 0))
	parent.add_child(bar)
	return bar


func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb


func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card_box())
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS    # laisse le doigt faire défiler la page
	parent.add_child(p)
	return p


## Titre de section : texte en gras suivi d'un filet cyan.
func _section(parent: Node, text: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var l := _label(box, text, 32, COL_ACCENT)
	l.add_theme_font_override("font", UiTheme.font(true))
	var line := ColorRect.new()
	line.color = Color(0.22, 0.9, 1.0, 0.45)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	return l


## Puce « icône + valeur » pour une ressource ; retourne le Label de la valeur.
func _rate_chip(parent: Node, id: String) -> Label:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = UiTheme.RES_COLORS[id]
	var sb := UiTheme.box(Color(0.04, 0.12, 0.2, 0.9), Color(0.22, 0.9, 1.0, 0.3), 5, 1, 8)
	sb.border_width_bottom = 2
	sb.border_color = color
	chip.add_theme_stylebox_override("panel", sb)
	parent.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var ic := TextureRect.new()
	ic.texture = UiIcons.icon(id, 30, color)
	ic.custom_minimum_size = Vector2(26, 26)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := _label(row, "", 24, UiTheme.GOOD)
	l.add_theme_font_override("font", UiTheme.mono())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## Panneau à cadre de rareté : filet épais à gauche, fin tout autour, teinte de fond légère.
func _rarity_panel(parent: Node, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(p)
	_set_rarity_style(p, color)
	return p


func _set_rarity_style(p: PanelContainer, color: Color) -> void:
	var sb := UiTheme.box(UiTheme.PANEL.lerp(color, 0.07), color.lerp(Color(0, 0, 0, 1), 0.25), 6, 1, 14)
	sb.border_width_left = 6
	sb.border_color = color
	sb.shadow_color = Color(color.r, color.g, color.b, 0.18)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)


## Tuile carrée avec l'icône de l'emplacement, teintée à la couleur de rareté.
func _icon_tile(parent: Node, icon_name: String, color: Color, size: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(size, size)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tile)
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(ic)
	tile.set_meta("icon", ic)
	tile.set_meta("size", size)
	_set_tile_color(tile, icon_name, color)
	return tile


func _set_tile_color(tile: PanelContainer, icon_name: String, color: Color) -> void:
	var sb := UiTheme.box(Color(0.02, 0.06, 0.11, 0.9), color.lerp(Color(0, 0, 0, 1), 0.3), 6, 1, 8)
	tile.add_theme_stylebox_override("panel", sb)
	var px: int = int(tile.get_meta("size")) - 16
	var ic: TextureRect = tile.get_meta("icon")
	ic.texture = UiIcons.icon(icon_name, px, color)


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
	var sub := ""
	if tab in ["salles", "atelier", "lab", "ship", "rang"]:
		sub = tab
		tab = "base"
	for id in _pages:
		_pages[id].get_meta("scroll").visible = (id == tab)
	_tab_buttons[tab].button_pressed = true
	if sub != "":
		_base_ui.show_section(sub)
	_subnav.visible = (tab == "base")
	_title.visible = (tab != "base")
	_rate_label.visible = (tab != "base")
	_dirty = true


## Appelé par la Base quand on change de sous-page : on repart du haut de la page.
func _base_section_changed(_id: String) -> void:
	_pages["base"].get_meta("scroll").scroll_vertical = 0
	_dirty = true


func _on_battle_finished(slot_i: int) -> void:
	# On n'anime que si le joueur regarde l'onglet Expéditions.
	_pending_battle[slot_i] = _pages["exp"].get_meta("scroll").visible


func _on_station_pick(index: int, slot_i: int, station_i: int) -> void:
	var ids: Array = _slot_ui[slot_i].members[station_i].ids
	GameState.set_squad_member(slot_i, station_i, ids[index] if index < ids.size() else "")


## ---------- Rafraîchissement ----------

func _refresh() -> void:
	for id in Data.RES_ORDER:
		_res_labels[id].text = Data.fmt(GameState.res[id])
	var prod := GameState.production_per_sec()
	_rate_label.text = "Équipage /h : +%s cr  +%s min.  +%s én.  +%s don." % [
		Data.fmt(prod.credits * 3600.0), Data.fmt(prod.minerals * 3600.0), Data.fmt(prod.energy * 3600.0),
		Data.fmt(prod.data * 3600.0)]
	_refresh_goal()
	_refresh_captain()
	_refresh_crew()
	_exp_count.text = "Expéditions terminées : %d" % GameState.expeditions_done
	_refresh_expeditions()
	_base_ui.refresh()
	_refresh_ship()


func _stat_text(st: Dictionary, sign: String = "") -> String:
	var parts: Array[String] = []
	for entry in [["hp", "PV"], ["atk", "ATQ"], ["def", "DÉF"], ["spd", "VIT"]]:
		if st.get(entry[0], 0.0) > 0.4:
			parts.append("%s %s%d" % [entry[1], sign, int(round(st[entry[0]]))])
	return "  ".join(parts)


func _refresh_goal() -> void:
	var g: Dictionary = GameState.next_goal()
	if g.is_empty():
		_goal_title.text = "Objectifs : tous accomplis"
		_goal_bar.value = 1.0
		_goal_info.text = "Bravo ! De nouveaux objectifs arrivent avec les prochaines mises à jour."
		_goal_btn.visible = false
		return
	var prog: float = GameState.goal_progress(g)
	var target: float = float(g.target)
	_goal_title.text = "Objectif %d/%d : %s" % [GameState.goals_claimed.size() + 1, Data.GOALS.size(), g.name]
	_goal_bar.value = clampf(prog / target, 0.0, 1.0)
	_goal_info.text = "%s / %s   —   Récompense : %s" % [Data.fmt(minf(prog, target)), Data.fmt(target), Data.fmt_amounts(g.reward)]
	_goal_btn.visible = true
	var ready: bool = GameState.goal_ready(g)
	_goal_btn.disabled = not ready
	_goal_btn.text = "Récupérer la récompense" if ready else "En cours…"


func _on_anomaly_finished() -> void:
	var a: Dictionary = GameState.last_anomaly
	if a.win and a.first:
		_an_sel = GameState.anomaly_unlocked_max()
	_an_view.play(a)
	_dirty = true


## Chance de victoire lisible : « sûr » à partir de 80 % (risque d'échec ≤ 20 %), sinon « risqué ».
func _chance_text(p: float, extra: String) -> String:
	var pct := int(round(p * 100.0))
	var label := "sûr" if p >= Data.WIN_CHANCE_SAFE else ("risqué" if p >= 0.5 else "très risqué")
	return "chance de victoire ~%d %% (%s)%s" % [pct, label, (" · " + extra) if extra != "" else ""]


func _refresh_anomalies() -> void:
	_an_sel = clampi(_an_sel, 1, GameState.anomaly_unlocked_max())
	var ch := GameState.anomaly_charges
	var nxt := GameState.anomaly_next_charge_in()
	_an_info.text = "Charges : %d / %d  ·  %d par faille (%d entrées)%s" % [int(floor(ch)), Data.ANOMALY_CHARGES_MAX, int(Data.ANOMALY_COST),
		GameState.anomaly_runs_available(), ("   (prochaine charge dans %s)" % Data.fmt_time(nxt)) if nxt > 0.0 else "   (pleines)"]
	_an_label.text = "Faille %d" % _an_sel
	_an_minus.disabled = _an_sel <= 1 or _an_view.playing
	_an_plus.disabled = _an_sel >= GameState.anomaly_unlocked_max() or _an_view.playing
	_an_view.visible = _an_view.playing
	var prev := GameState.anomaly_preview(_an_sel)
	var left := int(100.0 * maxf(0.0, prev.allies[0].hp) / prev.allies[0].max_hp)
	var first := _an_sel > GameState.anomaly_max
	var best: int = int(GameState.anomaly_best.get(_an_sel, 0))
	_an_preview.text = "Ennemis niv. %d  ·  %s\nRécompense : +%s XP  +%s crédits%s\n%s" % [
		GameState.anomaly_enemy_level(_an_sel),
		_chance_text(GameState.anomaly_chance(_an_sel), "il vous resterait ~%d %% de PV" % left if prev.win else "la moitié des charges serait rendue"),
		Data.fmt(GameState.anomaly_xp(_an_sel, first)), Data.fmt(GameState.anomaly_credits(_an_sel)),
		"  +ressources (1re réussite)" if first else "",
		("Record : %d tours" % best) if best > 0 else "Pas encore de record"]
	var la: Dictionary = GameState.last_anomaly
	if la.is_empty() or _an_view.playing:
		_an_result.text = ""
	elif la.win:
		_an_result.text = "Faille %d réussie en %d tours : +%s XP, +%s crédits%s%s%s" % [la.n, la.rounds, Data.fmt(la.xp), Data.fmt(la.credits),
			"  —  %d niveau(x) !" % la.levels if la.levels > 0 else "", "  —  NOUVEAU RECORD !" if la.record else "",
			("  —  " + Data.fmt_amounts(la.found)) if not la.found.is_empty() else ""]
	else:
		_an_result.text = "Faille %d : défaite. La moitié des charges vous est rendue." % la.n
	var can_enter: bool = ch >= Data.ANOMALY_COST
	_an_btn.text = "Entrer dans la faille %d  (−%d charges)" % [_an_sel, int(Data.ANOMALY_COST)] if can_enter else "Pas assez de charges (prochaine entrée dans %s)" % Data.fmt_time(GameState.anomaly_next_run_in())
	_an_btn.disabled = ch < Data.ANOMALY_COST or _an_view.playing


func _refresh_captain() -> void:
	var cap: Dictionary = GameState.captain
	_cap_chibi.setup_captain(cap.look)
	_cap_name.text = cap.name
	if GameState.captain_maxed():
		_cap_level.text = "Niveau %d (maximum)" % cap.level
		_cap_xp.value = 1.0
	else:
		_cap_level.text = "Niveau %d   ·   XP : anomalies" % cap.level
		_cap_xp.value = float(cap.xp) / float(Data.captain_xp_needed(cap.level))
	var cs := GameState.captain_stats(0)
	_cap_stats.text = "PV %d   ATQ %d\nDÉF %d   VIT %d\nÉquipement : %s\nÉquipage : %s" % [
		cs.hp, cs.atk, cs.def, cs.spd, _stat_text(cs.gear, "+"), _stat_text(cs.crew, "+")]
	var tc := GameState.captain_train_cost()
	if GameState.captain_maxed():
		_cap_train.text = "Niveau maximum"
		_cap_train.disabled = true
	else:
		_cap_train.text = "Entraîner (+1 niveau) — %s crédits" % Data.fmt(tc)
		_cap_train.disabled = GameState.res["credits"] < tc
	_refresh_anomalies()
	for slot in Data.EQUIP_SLOTS:
		var u: Dictionary = _slot_cards[slot]
		var it := GameState.equipped_item(slot)
		if it.is_empty():
			u.title.text = "Emplacement vide"
			u.title.add_theme_color_override("font_color", COL_TEXT_DIM)
			u.stats.text = "Looter ou équiper un objet."
			u.btn.visible = false
			_set_rarity_style(u.panel, COL_TEXT_DIM)
			_set_tile_color(u.tile, slot, COL_TEXT_DIM)
			u.kind.text = Data.EQUIP[slot].name.to_upper()
		else:
			var rc: Color = Data.ITEM_RARITY[it.rarity].color
			u.kind.text = "%s  ·  %s  ·  NIV. %d" % [Data.EQUIP[slot].name.to_upper(), String(Data.ITEM_RARITY[it.rarity].name).to_upper(), it.ilvl]
			u.title.text = it.name
			u.title.add_theme_color_override("font_color", rc)
			u.stats.text = _item_text(it)
			u.btn.visible = true
			_set_rarity_style(u.panel, rc)
			_set_tile_color(u.tile, slot, rc)
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
		var rar: Dictionary = Data.ITEM_RARITY[it.rarity]
		var panel := _rarity_panel(_inv_box, rar.color)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		_icon_tile(row, it.slot, rar.color, 64)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		var t := _label(info, "%s%s" % [it.name, " (équipé)" if is_eq else ""], 21, rar.color)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(info, "%s · %s · niv. %d" % [Data.EQUIP[it.slot].name, rar.name, it.ilvl], 16, COL_TEXT_DIM)
		var d := _label(info, _item_text(it), 17, Color(0.85, 0.92, 1.0))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not is_eq:
			var delta := GameState.power_delta(it)
			_label(info, ("▲ +%d puissance" % delta) if delta > 0.0 else ("▼ %d puissance" % delta), 18,
				COL_GOOD if delta > 0.0 else Color(1.0, 0.55, 0.5))
		var btns := VBoxContainer.new()
		btns.custom_minimum_size = Vector2(190, 0)
		btns.mouse_filter = Control.MOUSE_FILTER_PASS
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
	for id in Data.RES_ORDER:
		_afk_rates[id].text = "+%s /h" % Data.fmt(prod[id] * 3600.0)
	_afk_label.text = "Rendement hors ligne : %d %%   ·   Durée max comptée : %s" % [
		int(round(GameState.offline_efficiency() * 100.0)), Data.fmt_time(GameState.offline_cap_seconds())]
	var w := GameState.drop_weights(1)
	var wsum := 0.0
	for r in w:
		wsum += w[r]
	var parts: Array[String] = []
	for r in Data.ITEM_RARITY_ORDER:
		if Data.ITEM_RARITY_ORDER.find(r) >= 2:
			parts.append("%s %s %%" % [Data.ITEM_RARITY[r].name, String.num(100.0 * w[r] / wsum, 1)])
	var per_hour := GameState.afk_drops_per_hour()
	_afk_loot.text = "Le travail aux postes fabrique des objets pour le Capitaine : environ 1 toutes les %d min (niv. ~%d). Niveau d'AFK : %d. Chances : %s. Montez l'équipage et les postes pour un butin plus puissant." % [
		int(round(60.0 / per_hour)), GameState.loot_level(), GameState.afk_level(), "  ·  ".join(parts)]
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
			_set_rarity_style(u.panel, Data.RARITY[tpl.rarity].color.darkened(0.55))
			u.xp.visible = false
			u.where.text = ""
			u.train.visible = false
			continue
		var h: Dictionary = GameState.heroes[id]
		var st := Data.hero_stats(id, h.level, h.stars)
		u.portrait.setup_crew(id, h.stars)
		u.name.text = "%s  —  niv. %d  %s" % [tpl.name, h.level, "★".repeat(h.stars)]
		u.name.add_theme_color_override("font_color", Data.RARITY[tpl.rarity].color)
		_set_rarity_style(u.panel, Data.RARITY[tpl.rarity].color)
		u.stats.text = "%s · %s · %s\nPV %d  ATQ %d  DÉF %d  VIT %d" % [
			cls.name, Data.SPECIES[tpl.get("species", "human")], Data.RARITY[tpl.rarity].name, st.hp, st.atk, st.def, st.spd]
		u.xp.visible = true
		u.xp.value = float(h.xp) / float(Data.xp_needed(h.level))
		u.where.text = _hero_work_text(id)
		u.train.visible = true
		if h.level >= Data.MAX_LEVEL:
			u.train.text = "Niveau maximum"
			u.train.disabled = true
		else:
			var tc := GameState.train_cost(id)
			u.train.text = "Entraîner (+1 niveau) — %s crédits" % Data.fmt(tc)
			u.train.disabled = GameState.res["credits"] < tc


func _hero_work_text(id: String) -> String:
	var room := GameState.hero_room(id)
	var spec: String = Data.HEROES[id].get("specialty", "")
	var spec_name: String = Data.ROOMS[spec].name if Data.ROOMS.has(spec) else "?"
	if room != "":
		return "Au travail : %s%s. %s" % [Data.ROOMS[room].name, " (sa spécialité !)" if room == spec else "", _base_ui._tile_output(room, id)]
	return "Au repos. Spécialité : %s. Place-le dans une salle de la Base pour produire." % spec_name


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
			u.title.text = "Vaisseau 1 — le Capitaine (niv. %d) et son équipage" % GameState.captain.level
		else:
			u.title.text = "Vaisseau 2 (baie d'amarrage) — drone piloté par l'équipage seul"
		var auto_ok := GameState.premium_unlocked("exp_auto")
		u.auto.set_pressed_no_signal(GameState.auto_relaunch(i))
		u.auto.disabled = not auto_ok
		u.auto.text = "Relance automatique" if auto_ok else "Relance automatique (Cristaux, bientôt)"
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
				if i == 0:
					var random_i := _exp_mode == "random" and GameState.random_mode_available()
					var mode_i: String = "combat" if random_i or _exp_mode not in ["combat", "derive", "route"] else _exp_mode
					var mult_i := GameState.live_mode_mult(d, random_i, mode_i)
					var gains: Dictionary = GameState.rewards_of(d, i)
					for r in gains:
						gains[r] *= mult_i
					var mode_txt := "mode au hasard" if random_i else ("dérive" if mode_i == "derive" else ("route" if mode_i == "route" else "combat en direct"))
					var risk_txt := "au moins %d ressources à ramener" % int(DeriveSim.CFG.min_loot) if mode_i == "derive" and not random_i else ("voyage d'étapes : gains selon le secteur" if mode_i == "route" and not random_i else _chance_text(GameState.live_chance(d, i), ""))
					b.text = "%s — %s%s\n%s\nEnnemis niv. %d : %s" % [
						info.name, mode_txt, ("  ·  ★ secteur du jour" if d == GameState.sector_of_day() else ""),
						Data.fmt_amounts(gains) + ("  (x%s)" % ("%.2f" % mult_i).rstrip("0").rstrip(".").replace(".", ",") if mult_i > 1.001 else ""),
						GameState.enemy_level(d), risk_txt]
				else:
					var fight := GameState.preview_battle(d, i)
					b.text = "%s — %s\n%s\nEnnemis niv. %d : %s" % [
						info.name, Data.fmt_time(GameState.duration_of(d, i)),
						Data.fmt_amounts(GameState.rewards_of(d, i)), GameState.enemy_level(d),
						_chance_text(GameState.expedition_chance(d, i), "")]
			b.disabled = busy or reason != ""
			b.visible = not busy
	var sd := GameState.sector_of_day()
	_sector_label.text = "★ Secteur du jour : %s · gains x%s (x%s avec le mode Aléatoire) · encore %s" % [Data.DEST[sd].name,
		str(Data.SECTOR_MULT).replace(".", ","), str(Data.SECTOR_RANDOM_MULT).replace(".", ","), Data.fmt_time(GameState.sector_seconds_left())]
	for m in _mode_btns:
		var mb: Button = _mode_btns[m]
		if m == "random":
			var ok := GameState.random_mode_available()
			mb.text = "Aléatoire\nx%s" % str(Data.RANDOM_MODE_MULT).replace(".", ",") if ok else "Aléatoire\nbientôt"
			mb.disabled = not ok
			mb.set_pressed_no_signal(_exp_mode == "random" and ok)
		else:
			var info_m: Dictionary = Data.MODE_INFO[m]
			var gain := RouteSim.REWARD_BASE if m == "route" else float(Data.MODE_REWARD_MULT.get(m, 1.0))
			mb.text = ("%s\nx%s" % [info_m.name, str(gain).replace(".", ",")]) if (info_m.ready and gain > 1.001) else (info_m.name if info_m.ready else "%s\nbientôt" % info_m.name)
			mb.disabled = not info_m.ready
			mb.set_pressed_no_signal(_exp_mode == m or (m == "combat" and _exp_mode == "random" and not GameState.random_mode_available()))
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
		u.name.text = "%s   %d/%d" % [up.name, lvl, up.max]
		u.bar.value = float(lvl) / float(up.max)
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


