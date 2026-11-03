extends Control
## Écran principal : champ de bataille animé, pouvoirs, liste des héros, et les fenêtres (carte, résultat, réglages, hors ligne, entrée, défaite).

const Data = preload("res://scripts/data.gd")

var battle: BattleView
var skill_buttons: Array = []
var cards: Array = []
var _credits_chip: HudButton
var _shards_chip: HudButton
var _stage_btn: HudButton
var _auto_btn: HudButton
var _speed_btn: HudButton
var _field: Control
var _boss_bar: BossBar
var _warn: HudButton
var _advice_icon: Control
var _tip: PanelContainer
var _tip_label: Label
var _head: Label
var _cards_row: HBoxContainer
var _boss := ""
var _fh := 600.0
var _item_toast: Control
var _equip_row: Control
var _equip_hero := ""
var _equip_btn: Button
var _nav: NavBar
var _tab_modal := false
var _skill_row: HBoxContainer
var _syn_label: Label
var _up_panel: PanelContainer
var _up_icon: HeroIcon
var _up_name: Label
var _up_info: Label
var _up_btn: Button
var _up_coin: Control
var _sel := -1                      # carte choisie ; -1 = le meilleur achat
var _up_slot := 0
var _toast: Label
var _toast_t := 0.0
var _claimed := 0.0
var _refresh_t := 0.0
var _modal: Control
var _buffs: Label
# tutoriel
var _hint: PanelContainer
var _hint_label: Label
var _hl: Control
var _tuto := 0
var _tuto_t := 0.0
var _manual_cast := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	battle = BattleView.new()
	# le terrain occupe 600 px de haut comme dans la maquette (le combat est dessiné en 720 × 560 puis agrandi)
	_field = Control.new()
	_field.position = Vector2.ZERO
	_field.size = Vector2(720, 600)
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	battle.scale = Vector2.ONE * (600.0 / 560.0)
	battle.position = Vector2(-(720.0 * 600.0 / 560.0 - 720.0) * 0.5, 0.0)
	_field.add_child(battle)
	var shade := TextureRect.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(UI.BG, 0.9), Color(UI.BG, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	shade.texture = gt
	shade.size = Vector2(720, 130)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(shade)
	battle.stage_cleared.connect(_on_cleared)
	battle.stage_failed.connect(_on_failed)
	_build_top()
	_build_skills()
	_build_squad()
	_build_equip_row()
	_build_tip()
	_build_nav()
	_build_toast()
	_build_hint()
	_build_buffs()
	resized.connect(_layout)
	_layout()
	_start_battle()
	_tuto = 4 if Game.tutorial_done else 0
	if not Game.intro_seen:
		var intro := IntroScreen.new()
		add_child(intro)
		get_tree().paused = true
		_nav.visible = false
		intro.finished.connect(func():
			Game.intro_seen = true
			_nav.visible = true
			get_tree().paused = false)
	elif not Game.offline_report.is_empty():
		_open_offline()


# ---------------------------------------------------------------- construction

func _build_top() -> void:
	_credits_chip = HudButton.new()
	_credits_chip.icon = "coin"
	_credits_chip.font_size = 24
	_credits_chip.text_color = UI.TEXT
	_credits_chip.tappable = false
	_credits_chip.position = Vector2(24, 20)
	_credits_chip.z_index = 3000
	add_child(_credits_chip)
	_shards_chip = HudButton.new()
	_shards_chip.icon = "shard"
	_shards_chip.font_size = 24
	_shards_chip.tappable = false
	_shards_chip.position = Vector2(24, 20)
	_shards_chip.z_index = 3000
	add_child(_shards_chip)
	var sb := HudButton.new()
	sb.set_texts("⚙")
	sb.font_size = 32
	sb.radius = 40.0
	sb.position = Vector2(628, 20)
	sb.size = Vector2(80, 80)
	sb.z_index = 3000
	sb.pressed.connect(_open_settings)
	add_child(sb)
	# l'étage en cours ouvre la carte
	_stage_btn = HudButton.new()
	_stage_btn.font_size = 30
	_stage_btn.radius = 24.0
	_stage_btn.z_index = 3000
	_stage_btn.pressed.connect(_open_map)
	add_child(_stage_btn)
	_auto_btn = HudButton.new()
	_auto_btn.font_size = 22
	_auto_btn.bold = true
	_auto_btn.radius = 24.0
	_auto_btn.position = Vector2(612, 300)
	_auto_btn.size = Vector2(88, 88)
	_auto_btn.z_index = 3000
	_auto_btn.pressed.connect(func():
		Game.auto_cast = not Game.auto_cast
		battle.sim.auto_cast = Game.auto_cast
		_refresh())
	add_child(_auto_btn)
	_speed_btn = HudButton.new()
	_speed_btn.font_size = 26
	_speed_btn.bold = true
	_speed_btn.radius = 24.0
	_speed_btn.position = Vector2(612, 404)
	_speed_btn.size = Vector2(88, 88)
	_speed_btn.z_index = 3000
	_speed_btn.pressed.connect(func():
		Game.speed = 1.0 if Game.speed >= 3.0 else Game.speed + 1.0
		battle.speed = Game.speed
		_refresh())
	add_child(_speed_btn)
	_boss_bar = BossBar.new()
	_boss_bar.position = Vector2(24, 116)
	_boss_bar.size = Vector2(672, 84)
	_boss_bar.z_index = 3000
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_boss_bar.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_open_map())
	_boss_bar.visible = false
	add_child(_boss_bar)
	_warn = HudButton.new()
	_warn.fill = UI.RED
	_warn.border = UI.RED
	_warn.text_color = Color("1a0a0a")
	_warn.bold = true
	_warn.font_size = 24
	_warn.radius = 30.0
	_warn.tappable = false
	_warn.z_index = 3000
	_warn.visible = false
	add_child(_warn)


func _build_skills() -> void:
	# cinq ronds de 92 px posés au bas du terrain (écart 24 px, à 16 px du bas)
	_skill_row = HBoxContainer.new()
	_skill_row.position = Vector2(82, 492)
	_skill_row.size = Vector2(556, 92)
	_skill_row.add_theme_constant_override("separation", 24)
	_skill_row.z_index = 3000
	add_child(_skill_row)
	for i in Data.SQUAD_SIZE:
		var b := SkillButton.new()
		b.slot = i
		b.hero = Data.HEROES[Game.squad[i]]
		b.pressed.connect(func(slot: int):
			if battle.sim != null and battle.sim.cast(slot):
				_manual_cast = true)
		_skill_row.add_child(b)
		skill_buttons.append(b)


func _build_squad() -> void:
	_head = UI.label(self, "Escouade", 32, Color.WHITE)
	_head.position = Vector2(24, 614)
	_syn_label = UI.label(self, "", 22, UI.GREEN)
	_syn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_syn_label.position = Vector2(300, 622)
	_syn_label.size = Vector2(396, 30)
	_advice_icon = Control.new()
	_advice_icon.size = Vector2(28, 28)
	_advice_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_advice_icon.draw.connect(func(): SkillButton.draw_glyph(_advice_icon, 3, Vector2(14, 14), Color("ff9b6b"), 0.5))
	add_child(_advice_icon)
	_cards_row = HBoxContainer.new()
	_cards_row.position = Vector2(24, 664)
	_cards_row.size = Vector2(672, 170)
	_cards_row.add_theme_constant_override("separation", 12)
	add_child(_cards_row)
	for slot in Data.SQUAD_SIZE:
		var c := SquadCard.new()
		c.slot = slot
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.pressed.connect(func(sl: int):
			_sel = sl
			Sfx.play("click", -8.0)
			_refresh())
		_cards_row.add_child(c)
		cards.append(c)
	# une seule action d'achat : le héros choisi, ou le meilleur achat
	_up_panel = PanelContainer.new()
	_up_panel.position = Vector2(24, 854)
	_up_panel.size = Vector2(672, 128)
	_up_panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, Color(0, 0, 0, 0), 24, 16))
	add_child(_up_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_up_panel.add_child(hb)
	_up_icon = HeroIcon.new()
	_up_icon.custom_minimum_size = Vector2(80, 80)
	hb.add_child(_up_icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)
	_up_name = UI.label(vb, "", 26, Color.WHITE)
	_up_info = UI.label(vb, "", 22, UI.MUTED)
	_up_btn = UI.button(hb, "", 28, "main")
	_up_btn.icon = UI.icon("coin")
	_up_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_up_btn.add_theme_constant_override("h_separation", 10)
	_up_btn.custom_minimum_size = Vector2(0, 96)
	_up_btn.pressed.connect(func():
		var id: String = Game.squad[_up_slot]
		if Game.can_evolve(id):
			_open_evolve(id)
		elif Game.level_up(id):
			Sfx.play("coin", -4.0)
		_refresh())


func _build_equip_row() -> void:
	_equip_row = Control.new()
	_equip_row.position = Vector2(24, 998)
	_equip_row.size = Vector2(672, 118)
	_equip_row.visible = false
	_equip_row.draw.connect(func():
		if _equip_hero == "":
			return
		var hd: Dictionary = Data.HEROES[_equip_hero]
		_equip_row.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 24, 0), Rect2(Vector2.ZERO, _equip_row.size))
		UI.portrait(_equip_row, hd, Vector2(64, 59), 40.0, 0.0)
		var sg := _equip_suggestion()
		var nm: String = String(hd.name).split(" ")[0]
		var bare: bool = Game.hero_items(_equip_hero).is_empty()
		_equip_row.draw_string(UI.bold_font(), Vector2(124, 52), "%s · %s" % [nm, "aucun équipement" if bare else "mieux équipé possible"], HORIZONTAL_ALIGNMENT_LEFT, 380.0, 26, Color.WHITE)
		_equip_row.draw_string(ThemeDB.fallback_font, Vector2(124, 86), "%d objet%s de ton inventaire lui conviennent" % [int(sg.count), "s" if int(sg.count) > 1 else ""], HORIZONTAL_ALIGNMENT_LEFT, 390.0, 22, UI.MUTED))
	add_child(_equip_row)
	_equip_btn = UI.button(_equip_row, "Équiper", 26, "main")
	_equip_btn.position = Vector2(528, 11)
	_equip_btn.size = Vector2(130, 96)
	_equip_btn.custom_minimum_size = Vector2(0, 96)
	_equip_btn.pressed.connect(func():
		if _equip_hero == "":
			return
		var n: int = Game.equip_best(_equip_hero)
		Game.save_game()
		Sfx.play("chest" if n > 0 else "click", -4.0)
		_start_battle()
		_show_toast("%d objet%s équipé%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""], 2.0))


## Héros qui gagnerait le plus à être rééquipé : {hero, gain, count}.
func _equip_suggestion() -> Dictionary:
	var best := {"hero": "", "gain": 0.0, "count": 0}
	for hid in Game.squad_ids():
		var total := 0.0
		var cnt := 0
		for slot in Items.SLOTS:
			if not Game.slot_unlocked(hid, slot):
				continue
			var top := 0.0
			for it in Game.inventory_items():
				if it.slot == slot and (it.bound == "" or it.bound == hid):
					var g := Game.power_gain(it, hid)
					if g > 0.0:
						cnt += 1
						top = maxf(top, g)
			total += top
		if total > float(best.gain):
			best = {"hero": hid, "gain": total, "count": cnt}
	return best


func _build_tip() -> void:
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", UI.box(Color("2a1626"), Color(1.0, 0.42, 0.42, 0.4), 24, 18))
	_tip.size = Vector2(672, 98)
	_tip.visible = false
	add_child(_tip)
	_tip_label = UI.label(_tip, "", 24, Color("ffb3b3"))
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_constant_override("line_spacing", -7)


func _build_nav() -> void:
	_nav = NavBar.new()
	_nav.z_index = 4095
	add_child(_nav)
	_nav.tab_pressed.connect(_on_tab)


## La barre est accrochée au bas de l'écran ; le reste suit la maquette depuis le haut (terrain de 600 px, 660 px contre un boss).
func _layout() -> void:
	var h := size.y if size.y > 0.0 else 1280.0
	_nav.position = Vector2(0, h - NavBar.HEIGHT)
	_nav.size = Vector2(720, NavBar.HEIGHT)
	_boss = Data.boss_type(Game.stage)
	_fh = 660.0 if _boss != "" else 600.0
	var k := _fh / 560.0
	_field.size = Vector2(720, _fh)
	battle.scale = Vector2.ONE * k
	battle.position = Vector2(-(720.0 * k - 720.0) * 0.5, 0.0)
	battle._base = battle.position
	_skill_row.position = Vector2(82, _fh - 108.0)
	_head.position = Vector2(24, _fh + 14.0)
	_syn_label.position = Vector2(300, _fh + 22.0)
	_cards_row.position = Vector2(24, _fh + 64.0)
	_tip.position = Vector2(24, _fh + 254.0)
	_up_panel.position = Vector2(24, _fh + 254.0 + (110.0 if _boss != "" else 0.0))
	_boss_bar.visible = _boss != ""
	_tip.visible = _boss != ""
	_shards_chip.visible = _boss == ""
	_stage_btn.visible = _boss == ""


func _on_tab(i: int) -> void:
	if i == 0:
		if _modal != null and is_instance_valid(_modal) and _tab_modal:
			(_modal as Overlay).close()
		return
	match i:
		1:
			_open_collection()
		2:
			_open_recruit()
		3:
			_open_shop()


func _build_toast() -> void:
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", UI.GOLD)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.position = Vector2(30, 440)
	_toast.size = Vector2(660, 120)
	_toast.modulate.a = 0.0
	add_child(_toast)


## Bulle d'aide du tutoriel, avec un cadre qui pulse autour de l'élément à utiliser.
func _build_hint() -> void:
	_hl = Control.new()
	_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hl.draw.connect(func():
		if _hl.has_meta("rect"):
			var r: Rect2 = _hl.get_meta("rect")
			var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			_hl.draw_rect(r.grow(4.0 + 3.0 * k), Color(1.0, 0.85, 0.3, 0.5 + 0.5 * k), false, 4.0))
	_hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hl.z_index = 3000
	add_child(_hl)
	_hint = PanelContainer.new()
	_hint.position = Vector2(30, 476)
	_hint.size = Vector2(660, 64)
	_hint.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.16, 0.3, 0.96), UI.GOLD, 12, 14))
	_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_tuto = mini(_tuto + 1, 4)
			if _tuto == 4:
				Game.tutorial_done = true
			_tuto_t = 0.0)
	_hint.visible = false
	_hint.z_index = 3000
	add_child(_hint)
	_hint_label = UI.label(_hint, "", 22, Color.WHITE)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_buffs() -> void:
	_buffs = UI.label(self, "", 19, UI.GOLD)
	_buffs.position = Vector2(24, 1124)
	_buffs.size = Vector2(688, 60)
	_buffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buffs.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_buffs.add_theme_constant_override("outline_size", 6)
	_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buffs.z_index = 3000


func _show_toast(text: String, secs: float = 2.5) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = secs


# ---------------------------------------------------------------- fenêtres

## Ouvre une fenêtre. `tab` (1 à 3) : écran de la barre du bas, qui reste visible et permet de changer d'écran.
func _open_modal(ov: Control, tab: int = -1) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = ov
	_tab_modal = tab > 0
	if _tab_modal:
		(ov as Overlay).reserve_bottom(NavBar.HEIGHT)
		_nav.active = tab
	_nav.visible = _tab_modal
	add_child(ov)
	# la barre doit rester au-dessus de la fenêtre pour recevoir les appuis (le z_index ne suffit pas pour les clics)
	move_child(_nav, get_child_count() - 1)
	var tr := get_tree()
	tr.paused = true
	ov.tree_exited.connect(func():
		if _modal == ov:
			_modal = null
			_tab_modal = false
			_nav.active = 0
			_nav.visible = true
			tr.paused = false)


func _open_map() -> void:
	var m := MapScreen.new()
	m.stage_chosen.connect(func(n: int):
		Game.go_to(n)
		_start_battle())
	m.chest_claimed.connect(_show_chest_toast)
	_open_modal(m)


func _open_settings() -> void:
	var s := SettingsScreen.new()
	s.changed.connect(func():
		battle.speed = Game.speed
		battle.sim.auto_cast = Game.auto_cast
		_refresh())
	s.tutorial_requested.connect(func():
		_tuto = 0)
	s.erase_requested.connect(func():
		Game.reset()
		Game.save_game()
		_tuto = 0
		_start_battle())
	_open_modal(s)


func _open_evolve(id: String) -> void:
	var e := EvolveScreen.new(id)
	e.evolved.connect(func():
		_start_battle())
	_open_modal(e)


func _open_collection(tab: int = 0) -> void:
	var c := CollectionScreen.new()
	c.squad_changed.connect(_start_battle)
	c.hero_requested.connect(func(id: String):
		var hs := HeroScreen.new(id)
		hs.changed.connect(_start_battle)
		hs.evolve_requested.connect(func(eid: String):
			hs.close()
			_open_evolve.call_deferred(eid))
		hs.item_slot_requested.connect(func(slot: String):
			_open_pick(id, slot))
		# fiche en plein écran ; en la quittant on revient à la collection
		hs.closed.connect(func(): _open_collection.call_deferred())
		_open_modal(hs))
	c.item_requested.connect(func(iid: int): _open_item(iid))
	c.forge_requested.connect(_open_forge)
	_open_modal(c, 1)
	if tab > 0:
		c.show_tab(tab)


## Détail d'un objet (plein écran) ; en le quittant on revient à l'onglet Objets.
func _open_item(iid: int) -> void:
	var d := ItemDetailScreen.new(iid)
	d.changed.connect(_start_battle)
	d.who_requested.connect(func(id: int): _open_who(id, "À qui l'équiper ?"))
	d.closed.connect(func(): _open_collection.call_deferred(1))
	_open_modal(d)


func _open_who(iid: int, title: String, back_to_items := true) -> void:
	var w := ItemWhoScreen.new(iid, title)
	w.changed.connect(_start_battle)
	if back_to_items:
		w.closed.connect(func(): _open_collection.call_deferred(1))
	_open_modal(w)


func _open_pick(hero_id: String, slot: String) -> void:
	var p := ItemPickScreen.new(hero_id, slot)
	p.changed.connect(_start_battle)
	p.closed.connect(func():
		var hs := HeroScreen.new(hero_id, 1)
		hs.changed.connect(_start_battle)
		hs.item_slot_requested.connect(func(sl: String): _open_pick(hero_id, sl))
		hs.closed.connect(func(): _open_collection.call_deferred())
		_open_modal.call_deferred(hs))
	_open_modal(p)


func _open_forge() -> void:
	var f := ForgeScreen.new()
	f.changed.connect(_start_battle)
	f.closed.connect(func(): _open_collection.call_deferred(1))
	_open_modal(f)


func _open_recruit() -> void:
	_open_modal(RecruitScreen.new(), 2)


func _open_shop() -> void:
	var sh := ShopScreen.new()
	sh.bought.connect(_show_toast.bind(3.0))
	_open_modal(sh, 3)


func _open_offline() -> void:
	var o := OfflineScreen.new(Game.offline_report)
	Game.offline_report = {}
	o.chest_claimed.connect(_show_chest_toast)
	_open_modal(o)


func _show_chest_toast(c: Dictionary) -> void:
	Sfx.play("chest")
	_show_toast("Coffre %s : +%s crédits, +%d éclats" % [String(Data.RARITY_NAMES[c.rarity]).to_lower(), Data.fmt(c.credits), int(c.shards)], 3.0)


# ---------------------------------------------------------------- combat

## Alerte « Objet trouvé » (planche du combat équipé) : l'objet, et un bouton pour l'équiper sur le héros qui en profite le plus.
func _show_item_toast(drop: Dictionary) -> void:
	if _item_toast != null and is_instance_valid(_item_toast):
		_item_toast.queue_free()
	var it: Dictionary = drop.item
	var col := ItemUI.color(it.rarity)
	var best: Dictionary = Game.best_hero_for(it) if drop.status == "added" else {"hero": "", "gain": 0.0}
	var can: bool = best.hero != "" and float(best.gain) > 0.0
	var c := Control.new()
	c.position = Vector2(24, 120)
	c.size = Vector2(672, 104)
	c.z_index = 3000
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var age := [0.0]
	c.draw.connect(func():
		c.draw_style_box(UI.box(Color(0.051, 0.082, 0.188, 0.87), col, 24, 0), Rect2(Vector2.ZERO, c.size))
		ItemUI.tile(c, Rect2(16, 16, 72, 72), it, false)
		var title := "Objet %s trouvé" % String(Data.RARITY_NAMES[it.rarity]).to_lower()
		var sub: String = Items.summary(it)
		if drop.status == "recycled":
			title = "Objet commun recyclé"
			sub = "+%d éclat · le recyclage automatique est activé" % int(Items.RECYCLE_SHARDS[it.rarity])
		elif drop.status == "stash":
			title = "Inventaire plein"
			sub = "L'objet attend de côté : fais de la place"
		c.draw_string(UI.bold_font(), Vector2(108, 46), title, HORIZONTAL_ALIGNMENT_LEFT, 360.0, 24, col)
		c.draw_string(ThemeDB.fallback_font, Vector2(108, 78), "%s · %s" % [it.name, sub] if drop.status == "added" else sub, HORIZONTAL_ALIGNMENT_LEFT, 380.0, 20, UI.MUTED)
		if can:
			c.draw_style_box(UI.box(Color(UI.GREEN, 0.08), Color(UI.GREEN, 0.4), 24, 0), Rect2(498, 26, 150, 52))
			c.draw_string(UI.bold_font(), Vector2(498, 62), "Équiper", HORIZONTAL_ALIGNMENT_CENTER, 130.0, 22, UI.GREEN)
			c.draw_colored_polygon(PackedVector2Array([Vector2(620, 60), Vector2(636, 60), Vector2(628, 44)]), UI.GREEN))
	c.gui_input.connect(func(ev: InputEvent):
		if ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)) and can:
			if Game.equip(int(it.id), best.hero) == "":
				Game.save_game()
				Sfx.play("chest", -4.0)
				_start_battle()
				_show_toast("%s équipé sur %s" % [it.name, String(Data.HEROES[best.hero].name).split(" ")[0]], 2.4)
				c.queue_free())
	add_child(c)
	_item_toast = c
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(c):
			c.queue_free())


func _start_battle() -> void:
	_layout()
	battle.speed = Game.speed
	battle.start(Game.team(), Game.stage, Game.auto_cast)
	_claimed = 0.0
	_tuto_t = 0.0
	for i in skill_buttons.size():
		skill_buttons[i].unit = null
	for u in battle.sim.units:
		if u.side == 0:
			skill_buttons[u.slot].unit = u
			skill_buttons[u.slot].hero = Data.HEROES[u.id]
			if _tuto < 2 and u.slot == 0:
				u.skill_cd = 0.5        # pendant le tutoriel, le premier pouvoir est prêt tout de suite
	_refresh()


func _on_cleared(_credits: float) -> void:
	var stage := Game.stage
	var stars: int = battle.sim.stars
	var frontier := Game.is_frontier()
	var shows_chest := frontier or Data.is_boss_stage(stage)
	var chest: Dictionary = Game.stage_cleared(stars, battle.sim.max_combo, shows_chest)
	Game.save_game()
	if _tuto == 3:
		_tuto = 4
		Game.tutorial_done = true
	if shows_chest:
		var next_label := "Monter à l'étage %d" % (stage + 1) if Game.best_stage > stage else "Rejouer l'étage %d" % stage
		var r := ResultScreen.new(stage, stars, chest, next_label, battle.sim.max_combo)
		var go_next := func():
			_pick_boost(func():
				if Game.best_stage > stage:
					Game.advance()
				_start_battle())
		r.who_requested.connect(func(iid: int):
			var w := ItemWhoScreen.new(iid, "Nouvel objet")
			w.changed.connect(_start_battle)
			w.closed.connect(go_next)
			_open_modal(w))
		# après un étage de progression, on choisit un renfort avant de repartir
		r.next_pressed.connect(func():
			_pick_boost(func():
				if Game.best_stage > stage:
					Game.advance()
				_start_battle()))
		r.replay_pressed.connect(func(): _pick_boost(_start_battle))
		r.map_pressed.connect(func():
			_pick_boost(func():
				_start_battle()
				_open_map.call_deferred()))
		_open_modal(r)
	else:
		_show_toast("Étage %d vaincu · coffre %s : +%s" % [stage, String(Data.RARITY_NAMES[chest.rarity]).to_lower(), Data.fmt(chest.credits)], 1.8)
		if not Game.last_drop.is_empty():
			_show_item_toast(Game.last_drop)
		Sfx.play("coin", -6.0)
		_start_battle()


## Propose trois renforts puis continue ; `then` est appelé après le choix.
func _pick_boost(then: Callable) -> void:
	var next_boss := Game.stage + 1
	while not Data.is_boss_stage(next_boss):
		next_boss += 1
	var offer: Array = Game.offer_boosts()
	# la fenêtre de résultat se ferme juste après ce signal : on ouvre le choix à l'image suivante
	var open := func():
		var bs := BoostScreen.new(offer, next_boss)
		bs.picked.connect(func(id: String):
			Game.add_boost(id)
			Game.save_game()
			then.call())
		_open_modal(bs)
	open.call_deferred()


func _on_failed() -> void:
	Game.defeated()
	Game.save_game()
	var d := DefeatScreen.new(Game.stage)
	d.retry_pressed.connect(_start_battle)
	d.farm_pressed.connect(func():
		Game.retreat()
		_start_battle())
	d.upgrade_pressed.connect(func():
		Game.retreat()
		_start_battle())
	d.recruit_pressed.connect(func():
		Game.retreat()
		_start_battle()
		_open_recruit.call_deferred())
	_open_modal(d)


# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	if battle.sim != null:
		var diff := battle.sim.credits - _claimed
		if diff > 0.0:
			Game.credits += diff * (Data.BOOST_MULT if Game.boost_active() else 1.0)
			_claimed = battle.sim.credits
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = 0.0 if _toast_t <= 0.0 else minf(1.0, _toast_t * 2.0)
	_tuto_update(delta)
	_refresh_t += delta
	if _refresh_t > 0.15:
		_refresh_t = 0.0
		_refresh()


func _tuto_update(delta: float) -> void:
	var text := ""
	var target := Rect2()
	_tuto_t += delta
	match _tuto:
		0:
			text = "Tes héros combattent tout seuls. Regarde-les faire !"
			if _tuto_t > 2.5:
				_tuto = 1
		1:
			var ready := false
			for b in skill_buttons:
				if b.unit != null and b.unit.alive and b.unit.skill_cd <= 0.0:
					ready = true
			if ready:
				text = "Touche un portrait pour lancer son pouvoir au bon moment."
				target = Rect2(82, 492, 556, 92)
			if _manual_cast:
				_tuto = 2
		2:
			var cheapest := 1.0e18
			for id in Game.squad_ids():
				cheapest = minf(cheapest, float(Game.level_cost(id)))
			if Game.credits >= cheapest:
				text = "Tu as assez de crédits : améliore un héros pour devenir plus fort."
				target = Rect2(_up_panel.position, _up_panel.size)
			var total := 0
			for id in Game.squad_ids():
				total += int(Game.levels[id])
			if total > Game.squad_ids().size():
				_tuto = 3
		3:
			text = "Bien joué ! Monte les étages : un mini-boss t'attend à l'étage 5."
	_hint.visible = text != ""
	_hint_label.text = text
	if target.size != Vector2.ZERO:
		_hl.set_meta("rect", target)
	elif _hl.has_meta("rect"):
		_hl.remove_meta("rect")
	_hl.queue_redraw()


const BOSS_INFO := {
	"titan": {"attack": "Écrasement", "kind": "shield", "tip": "Le boss cible la ligne avant. Garde un pouvoir de soin prêt pour la phase 2."},
	"sentinelle": {"attack": "Faisceau prismatique", "kind": "gravity", "tip": "La Sentinelle tire un faisceau sur toute une ligne. Étourdis-la avec l'onde gravitationnelle."},
	"reine": {"attack": "Appel des mites", "kind": "volley", "tip": "La Reine appelle des mites. Une salve de missiles les nettoie d'un coup."},
	"foreur": {"attack": "Forage", "kind": "shield", "tip": "Le Foreur frappe un héros puis charge lentement. Garde le bouclier pour le coup."},
}
const KIND_NAMES := {"shield": "Bouclier", "gravity": "Onde", "volley": "Salve", "pierce": "Tir perforant", "repair": "Soin"}


## Contenu propre aux combats de boss : barre de vie, avertissement, conseil.
func _refresh_boss() -> void:
	if _boss == "":
		_warn.visible = false
		return
	var bu: BattleSim.Unit = null
	for u in battle.sim.units:
		if u.side == 1 and u.boss and u.alive:
			bu = u
	var big := _boss == "big"
	_boss_bar.col = UI.RED if big else Color("ffb142")
	_boss_bar.title = "%s · %s" % ["GROS BOSS" if big else "MINI-BOSS", Data.boss_name(Game.stage)]
	_boss_bar.phase = ""
	_boss_bar.frac = 0.0
	var info: Dictionary = BOSS_INFO.get(Data.boss_kind(Game.stage), BOSS_INFO.titan)
	if bu != null:
		_boss_bar.frac = bu.hp_frac()
		if big:
			_boss_bar.phase = "Phase 2" if bu.phase2 else "Phase 1"
		var warning: bool = bu.skill_cd > 0.0 and bu.skill_cd <= 2.0 and battle.sim.state == "fighting"
		_warn.visible = warning
		if warning:
			_warn.set_texts("⚠ %s dans %d s" % [info.attack, int(ceil(bu.skill_cd))])
			var ww: float = ThemeDB.fallback_font.get_string_size(_warn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 56.0
			_warn.size = Vector2(ww, 48)
			_warn.position = Vector2((720.0 - ww) * 0.5, 236)
	else:
		_warn.visible = false
	_boss_bar.queue_redraw()
	_tip_label.text = info.tip


func _refresh() -> void:
	var tag := ""
	match Data.boss_type(Game.stage):
		"mini":
			tag = "Mini-boss"
		"big":
			tag = "Gros boss"
	if not Game.is_frontier() and tag == "":
		tag = "Farm"
	var sub := "Vague %d/%d" % [mini(battle.sim.wave, battle.sim.waves_total), battle.sim.waves_total]
	if battle.sim.combo > 1:
		sub += " · Combo ×%d" % battle.sim.combo
	_stage_btn.set_texts("Étage %d" % Game.stage, sub)
	var pw: float = maxf(ThemeDB.fallback_font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, 150.0) + 56.0
	_stage_btn.size = Vector2(pw, 84.0)
	_stage_btn.position = Vector2((720.0 - pw) * 0.5, 112.0)
	_credits_chip.set_texts(UI.num(Game.credits))
	_credits_chip.fit_chip()
	_shards_chip.set_texts(str(Game.shards))
	_shards_chip.fit_chip()
	_shards_chip.position.x = _credits_chip.position.x + _credits_chip.size.x + 12.0
	_auto_btn.set_texts("AUTO")
	_auto_btn.text_color = UI.ACCENT if Game.auto_cast else UI.MUTED
	_auto_btn.border = UI.ACCENT if Game.auto_cast else UI.LINE
	_speed_btn.set_texts("×%d" % int(Game.speed))
	_speed_btn.font_size = 26
	_refresh_boss()
	var parts: Array = []
	if Game.perseverance > 0:
		parts.append("Persévérance + %d %%" % Game.perseverance_pct())
	if not Game.boosts.is_empty():
		var names: Array = []
		for b in Game.boosts:
			names.append(Data.BOOSTS[b].name)
		parts.append("Renforts : " + ", ".join(names))
	_buffs.text = "\n".join(parts)
	var syn: Array = Game.synergy().list
	var eq_total := 0.0
	for eid in Game.squad_ids():
		eq_total += Game.hero_item_power(eid)
	var eq_pct := int(round(eq_total / maxf(1.0, Data.team_power(Game.levels, Game.squad_ids())) * 100.0)) if eq_total > 0.0 else 0
	_syn_label.add_theme_color_override("font_color", UI.GREEN)
	if _boss != "":
		var binfo: Dictionary = BOSS_INFO.get(Data.boss_kind(Game.stage), BOSS_INFO.titan)
		_syn_label.text = "Pouvoir conseillé :     %s" % KIND_NAMES[binfo.kind]
		_syn_label.add_theme_color_override("font_color", Color("ff9b6b"))
		var aw: float = ThemeDB.fallback_font.get_string_size(KIND_NAMES[binfo.kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_advice_icon.position = Vector2(_syn_label.position.x + _syn_label.size.x - aw - 34.0, _syn_label.position.y - 2.0)
		_advice_icon.visible = true
	elif eq_pct > 0:
		_syn_label.text = "Équipement +%d %% puissance" % eq_pct
		_advice_icon.visible = false
	elif syn.is_empty():
		_syn_label.text = ""
		_advice_icon.visible = false
	else:
		_syn_label.text = "Synergie %s %s" % [syn[0].name, syn[0].desc]
		_advice_icon.visible = false
	# achat : héros choisi, sinon le meilleur achat
	var best := Game.best_buy()
	var up_id := ""
	if _sel >= 0 and _sel < Data.SQUAD_SIZE and Game.squad[_sel] != "":
		up_id = Game.squad[_sel]
		_up_slot = _sel
	else:
		up_id = best
		if up_id == "":
			# rien d'abordable : on montre le héros le moins cher à améliorer
			var cheapest := 1.0e18
			for id in Game.squad_ids():
				var c: float = float(Game.level_cost(id))
				if c < cheapest:
					cheapest = c
					up_id = id
		_up_slot = Game.squad.find(up_id)
	var affordable := 0
	for slot in Data.SQUAD_SIZE:
		var id: String = Game.squad[slot]
		var c: SquadCard = cards[slot]
		c.visible = id != ""
		if id == "":
			continue
		var can := Game.credits >= Game.level_cost(id) and not Game.can_evolve(id)
		if can:
			affordable += 1
		c.hero = Data.HEROES[id]
		c.level = int(Game.levels[id])
		c.affordable = id == best and Game.credits >= Game.level_cost(id)
		var pp: Array = []
		for sl in Items.SLOTS:
			var eqi: Dictionary = Game.slot_item(id, sl)
			pp.append(ItemUI.color(eqi.rarity) if not eqi.is_empty() else null)
		c.pips = pp
	var sug := _equip_suggestion()
	_equip_hero = String(sug.hero)
	_equip_row.visible = _equip_hero != "" and _boss == ""
	_equip_row.queue_redraw()
	var ready_items := 0
	for it in Game.inventory_items():
		var bh: Dictionary = Game.best_hero_for(it)
		if bh.hero != "" and float(bh.gain) > 0.0 and (it.bound == "" or it.bound == bh.hero):
			ready_items += 1
	_nav.badges = [0, affordable + (1 if ready_items > 0 else 0), Game.tokens / Data.RECRUIT_COST, 0]
	if up_id == "":
		_up_panel.visible = false
		return
	_up_panel.visible = true
	var h: Dictionary = Data.HEROES[up_id]
	var lv: int = Game.levels[up_id]
	var base: float = Data.star_mult(Game.hero_stars[up_id]) * Data.EVO_STAT_MULT[Game.tier(up_id)]
	var m0: float = Data.hero_mult(lv) * base
	var m1: float = Data.hero_mult(lv + 1) * base
	_up_icon.hero = h
	_up_name.text = "%s%s · Nv %d → %d" % [h.name.split(" ")[0], ["", " II", " III"][Game.tier(up_id)], lv, lv + 1]
	_up_info.text = "PV +%d · ATQ +%d" % [h.hp * (m1 - m0), h.atk * (m1 - m0)]
	var cost := Game.level_cost(up_id)
	if Game.can_evolve(up_id):
		var ec: Dictionary = Game.evolve_cost(up_id)
		_up_name.text = "%s · palier d'évolution" % h.name
		_up_info.text = "%s ¢ · %d ◆" % [Data.fmt(ec.credits), int(ec.shards)]
		_up_btn.text = "Évoluer"
		_up_btn.icon = null
		_up_btn.disabled = false
		_up_btn.modulate = Color(1.0, 0.85, 0.35) if Game.can_afford_evolve(up_id) else Color(0.8, 0.8, 0.85)
	else:
		_up_btn.text = UI.num(cost)
		_up_btn.icon = UI.icon("coin")
		_up_btn.disabled = Game.credits < cost
		_up_btn.modulate = Color.WHITE
